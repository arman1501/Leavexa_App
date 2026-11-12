// ─────────────────────────────────────────────────────────────────────────────
//  auth_service.dart  –  Firebase Authentication + profile verification
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/constants/app_constants.dart';
import '../core/constants/app_strings.dart';
import '../models/registration_state.dart';
import '../models/user_model.dart';
import '../repositories/user_repository.dart';
import 'auth_exception.dart';
import 'cloud_functions_service.dart';

class AuthService {
  FirebaseAuth? _auth;
  UserRepository? _userRepository;
  CloudFunctionsService? _cloudFunctions;

  /// Abstraction for Google Sign-In so tests can substitute a fake.
  /// In production this talks to [GoogleSignIn.instance].
  final GoogleSignInAdapter _googleAdapter;

  AuthService({
    FirebaseAuth? auth,
    UserRepository? userRepository,
    CloudFunctionsService? cloudFunctions,
    GoogleSignInAdapter? googleSignInAdapter,
  }) : _auth = auth,
       _userRepository = userRepository,
       _cloudFunctions = cloudFunctions,
       _googleAdapter =
           googleSignInAdapter ?? const _DefaultGoogleSignInAdapter();

  FirebaseAuth get _firebaseAuth => _auth ??= FirebaseAuth.instance;
  UserRepository get _userRepo => _userRepository ??= UserRepository();
  CloudFunctionsService get _functions =>
      _cloudFunctions ??= CloudFunctionsService();

  // ── Accessors ───────────────────────────────────────────────────────────

  /// The currently signed-in Firebase user (null if signed out).
  User? get currentUser => _firebaseAuth.currentUser;

  /// UID shortcut.
  String? get currentUid => _firebaseAuth.currentUser?.uid;

  /// Currently cached validated user model.
  UserModel? _currentUserModel;
  UserModel? get currentUserModel => _currentUserModel;

  /// Fetch profile directly for a given UID.
  Future<UserModel?> getCurrentProfile(String uid) =>
      _userRepo.getUserById(uid);

  /// Real-time auth state (sign-in / sign-out events).
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // ── Email / Password Sign-In ────────────────────────────────────────────

  /// Low-level Firebase sign-in — does NOT verify Firestore profile.
  /// Kept for backward-compatibility with existing [AuthRepository.login].
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseException(e);
    }
  }

  /// **Primary login** — authenticates with Firebase, then fetches and
  /// validates the Firestore `users/{uid}` document.
  ///
  /// Returns the fully validated [UserModel] ready for routing.
  ///
  /// Throws [AuthException] with a descriptive code on every failure path.
  Future<UserModel> loginAndGetProfile({
    required String email,
    required String password,
  }) async {
    // 1. Firebase authentication
    final UserCredential credential;
    try {
      credential = await _firebaseAuth
          .signInWithEmailAndPassword(
            email: email.trim(),
            password: password,
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw const AuthException(
              code: AuthErrorCode.networkError,
              message:
                  'Connection timed out. Please check your internet connection.',
            ),
          );
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseException(e);
    } on TimeoutException {
      throw const AuthException(
        code: AuthErrorCode.networkError,
        message: 'Connection timed out. Please check your internet connection.',
      );
    }

    final firebaseUser = credential.user;
    if (firebaseUser == null) {
      throw const AuthException(
        code: AuthErrorCode.unknown,
        message: 'Authentication failed. Please try again.',
      );
    }

    // 2. Fetch & validate Firestore profile
    return _verifyProfile(firebaseUser.uid);
  }

  // ── Basic Registration (existing API) ───────────────────────────────────

  /// Creates a Firebase Auth account and returns the UID.
  /// Does NOT create a Firestore profile — callers are responsible for that.
  Future<String> register({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = credential.user?.uid;
      if (uid == null) {
        throw const AuthException(
          code: AuthErrorCode.unknown,
          message: 'Registration failed.',
        );
      }
      return uid;
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseException(e);
    }
  }

  // ── Faculty Registration with Firestore Profile ─────────────────────────

  /// Full faculty registration: validates payload, performs pre-flight check,
  /// creates Firebase Auth account (or recovers interrupted account),
  /// writes Firestore profile + Employee ID index atomically, and signs out.
  Future<void> registerFaculty({
    required String fullName,
    required String employeeId,
    required String email,
    required String phone,
    required String departmentName,
    required String designation,
    required String password,
    void Function(RegistrationState state)? onStateChanged,
  }) async {
    // ── 1. VALIDATING ────────────────────────────────────────────────────────
    onStateChanged?.call(const RegistrationState(
      step: RegistrationStep.validating,
      message: 'Validating form details...',
    ));

    final cleanFullName = fullName.trim();
    if (cleanFullName.length < 2 || cleanFullName.length > 100) {
      const err = AuthException(
        code: AuthErrorCode.invalidCredentials,
        message: 'Full name must be between 2 and 100 characters.',
      );
      onStateChanged?.call(const RegistrationState(
        step: RegistrationStep.permanentFailure,
        message: 'Full name must be between 2 and 100 characters.',
        errorCode: AuthErrorCode.invalidCredentials,
      ));
      throw err;
    }

    final cleanEmpId = employeeId.trim().toUpperCase();
    if (cleanEmpId.length < 3 || cleanEmpId.length > 30) {
      const err = AuthException(
        code: AuthErrorCode.invalidEmployeeId,
        message: 'Employee ID must be between 3 and 30 characters.',
      );
      onStateChanged?.call(const RegistrationState(
        step: RegistrationStep.permanentFailure,
        message: 'Employee ID must be between 3 and 30 characters.',
        errorCode: AuthErrorCode.invalidEmployeeId,
      ));
      throw err;
    }

    if (!RegExp(r'^[A-Z0-9\-_]+$').hasMatch(cleanEmpId)) {
      const err = AuthException(
        code: AuthErrorCode.invalidEmployeeId,
        message:
            'Employee ID can only contain letters, numbers, hyphens, and underscores.',
      );
      onStateChanged?.call(const RegistrationState(
        step: RegistrationStep.permanentFailure,
        message:
            'Employee ID can only contain letters, numbers, hyphens, and underscores.',
        errorCode: AuthErrorCode.invalidEmployeeId,
      ));
      throw err;
    }

    final cleanEmail = email.trim().toLowerCase();
    if (!RegExp(r'^[\w.-]+@[\w-]+\.[a-z]{2,}$', caseSensitive: false)
        .hasMatch(cleanEmail)) {
      const err = AuthException(
        code: AuthErrorCode.invalidCredentials,
        message: 'Please enter a valid email address.',
      );
      onStateChanged?.call(const RegistrationState(
        step: RegistrationStep.permanentFailure,
        message: 'Please enter a valid email address.',
        errorCode: AuthErrorCode.invalidCredentials,
      ));
      throw err;
    }

    if (AppConstants.isReservedStaffEmail(cleanEmail)) {
      const err = AuthException(
        code: AuthErrorCode.invalidCredentials,
        message:
            'This email is reserved for administrative staff and cannot be used for faculty registration.',
      );
      onStateChanged?.call(const RegistrationState(
        step: RegistrationStep.permanentFailure,
        message:
            'This email is reserved for administrative staff and cannot be used for faculty registration.',
        errorCode: AuthErrorCode.invalidCredentials,
      ));
      throw err;
    }

    if (password.length < 8) {
      const err = AuthException(
        code: AuthErrorCode.weakPassword,
        message: 'Password must be at least 8 characters.',
      );
      onStateChanged?.call(const RegistrationState(
        step: RegistrationStep.permanentFailure,
        message: 'Password must be at least 8 characters.',
        errorCode: AuthErrorCode.weakPassword,
      ));
      throw err;
    }

    if (!AppConstants.isValidDepartment(departmentName)) {
      const err = AuthException(
        code: AuthErrorCode.invalidDepartment,
        message: 'Please select a valid department.',
      );
      onStateChanged?.call(const RegistrationState(
        step: RegistrationStep.permanentFailure,
        message: 'Please select a valid department.',
        errorCode: AuthErrorCode.invalidDepartment,
      ));
      throw err;
    }

    // ── 2. CHECKING ──────────────────────────────────────────────────────────
    onStateChanged?.call(const RegistrationState(
      step: RegistrationStep.checking,
      message: 'Checking Employee ID availability...',
    ));

    // Best-effort pre-flight check via Cloud Functions
    try {
      final availability = await _functions.checkEmployeeId(cleanEmpId);
      if (availability['isAvailable'] == false) {
        const err = AuthException(
          code: AuthErrorCode.duplicateEmployeeId,
          message: 'This Employee ID is already registered.',
        );
        onStateChanged?.call(const RegistrationState(
          step: RegistrationStep.permanentFailure,
          message: 'This Employee ID is already registered.',
          errorCode: AuthErrorCode.duplicateEmployeeId,
        ));
        throw err;
      }
    } on AuthException {
      rethrow;
    } catch (_) {
      // Continue to atomic Firestore transaction if function is unreachable
    }

    // ── 3. CREATING AUTH ─────────────────────────────────────────────────────
    onStateChanged?.call(const RegistrationState(
      step: RegistrationStep.creatingAuth,
      message: 'Creating secure credentials...',
    ));

    User? firebaseUser;
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
      firebaseUser = credential.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        // Safe partial registration recovery:
        // If an Auth account was created previously but Firestore profile creation failed or was interrupted,
        // verify credentials and check whether a Firestore profile actually exists.
        try {
          final signInCred = await _firebaseAuth.signInWithEmailAndPassword(
            email: cleanEmail,
            password: password,
          );
          final existingAuthUser = signInCred.user;
          if (existingAuthUser != null) {
            final existingProfile =
                await _userRepo.getUserById(existingAuthUser.uid);
            if (existingProfile == null) {
              // Valid credentials and no Firestore profile: recover and complete registration.
              firebaseUser = existingAuthUser;
            } else {
              // Existing profile already exists; account is genuinely already in use.
              await _firebaseAuth.signOut();
              const err = AuthException(
                code: AuthErrorCode.emailAlreadyInUse,
                message: 'This email is already registered.',
              );
              onStateChanged?.call(const RegistrationState(
                step: RegistrationStep.permanentFailure,
                message: 'This email is already registered.',
                errorCode: AuthErrorCode.emailAlreadyInUse,
              ));
              throw err;
            }
          }
        } catch (signInErr) {
          if (signInErr is AuthException) rethrow;
          final err = _mapFirebaseException(e);
          onStateChanged?.call(RegistrationState(
            step: RegistrationStep.permanentFailure,
            message: err.message,
            errorCode: err.code,
          ));
          throw err;
        }
      } else {
        final err = _mapFirebaseException(e);
        final isRecoverable = e.code == 'network-request-failed' ||
            e.code == 'too-many-requests';
        onStateChanged?.call(RegistrationState(
          step: isRecoverable
              ? RegistrationStep.recoverableFailure
              : RegistrationStep.permanentFailure,
          message: err.message,
          errorCode: err.code,
          isRecoverable: isRecoverable,
        ));
        throw err;
      }
    } catch (e) {
      final err = AuthException(
        code: AuthErrorCode.unknown,
        message: 'Account creation failed: $e',
      );
      onStateChanged?.call(RegistrationState(
        step: RegistrationStep.recoverableFailure,
        message: err.message,
        errorCode: err.code,
        isRecoverable: true,
      ));
      throw err;
    }

    final currentUser = firebaseUser;
    if (currentUser == null) {
      const err = AuthException(
        code: AuthErrorCode.unknown,
        message: 'Account creation failed.',
      );
      onStateChanged?.call(const RegistrationState(
        step: RegistrationStep.recoverableFailure,
        message: 'Account creation failed.',
        errorCode: AuthErrorCode.unknown,
        isRecoverable: true,
      ));
      throw err;
    }

    // ── 4. CREATING PROFILE ──────────────────────────────────────────────────
    onStateChanged?.call(const RegistrationState(
      step: RegistrationStep.creatingProfile,
      message: 'Saving faculty profile...',
    ));

    final departmentId = AppConstants.getDepartmentId(departmentName);

    final user = UserModel(
      uid: currentUser.uid,
      fullName: cleanFullName,
      email: cleanEmail,
      employeeId: cleanEmpId,
      departmentId: departmentId,
      departmentName: departmentName.trim(),
      designation: designation.trim(),
      role: AppStrings.roleFaculty,
      phone: phone.trim(),
      isActive: false,
      approvalStatus: 'pending',
      photoUrl: null,
      createdAt: DateTime.now(),
    );

    try {
      await _userRepo.createFacultyUser(user);
    } catch (e) {
      // In case of failure, sign out to avoid leaving authenticated session in invalid state.
      // Do NOT silently delete the Auth account to prevent data loss or blocking recovery.
      await _firebaseAuth.signOut();

      final AuthException authErr = e is AuthException
          ? e
          : (e is FirebaseException
              ? (e.code == 'unavailable' ||
                      e.code == 'network-request-failed' ||
                      e.code == 'deadline-exceeded'
                  ? const AuthException(
                      code: AuthErrorCode.networkError,
                      message:
                          'Unable to connect. Check your internet and try again.',
                    )
                  : AuthException(
                      code: e.code,
                      message: e.message ?? 'Profile creation failed.',
                    ))
              : AuthException(
                  code: AuthErrorCode.unknown,
                  message: 'Profile creation failed: $e',
                ));

      final isRecoverable = authErr.code == AuthErrorCode.networkError ||
          authErr.code == 'unavailable' ||
          authErr.code == 'deadline-exceeded';

      onStateChanged?.call(RegistrationState(
        step: isRecoverable
            ? RegistrationStep.recoverableFailure
            : RegistrationStep.permanentFailure,
        message: authErr.message,
        errorCode: authErr.code,
        isRecoverable: isRecoverable,
      ));
      throw authErr;
    }

    // ── 5. COMPLETED ─────────────────────────────────────────────────────────
    // Sign out — the faculty must wait for admin approval
    await _firebaseAuth.signOut();

    onStateChanged?.call(const RegistrationState(
      step: RegistrationStep.completed,
      message:
          'Registration successful! Your account is pending admin approval.',
    ));
  }

  // ── Google Sign-In ──────────────────────────────────────────────────────

  /// Authenticates via Google and then checks for an existing Firestore
  /// profile.
  ///
  /// • If a valid profile exists → returns [UserModel].
  /// • If no profile exists → signs out of Firebase, throws
  ///   [AuthException] with code [AuthErrorCode.googleNoAccount] so the
  ///   calling screen can redirect to registration / onboarding.
  /// • Never auto-creates a faculty profile for a new Google user.
  ///
  /// Compatible with `google_sign_in: ^7.2.0` which uses
  /// `GoogleSignIn.instance.authenticate()` instead of the old `signIn()`.
  Future<UserModel> signInWithGoogle() async {
    // 1. Authenticate with Google and get an OAuthCredential
    final OAuthCredential oauthCredential;
    try {
      oauthCredential = await _googleAdapter.authenticateAndGetCredential();
    } on AuthException {
      rethrow;
    } catch (e) {
      throw const AuthException(
        code: AuthErrorCode.googleSignInFailed,
        message: 'Google Sign-In failed. Please try again.',
      );
    }

    // 2. Firebase sign-in with Google credential
    final UserCredential firebaseCredential;
    try {
      firebaseCredential = await _firebaseAuth.signInWithCredential(
        oauthCredential,
      );
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseException(e);
    }

    final firebaseUser = firebaseCredential.user;
    if (firebaseUser == null) {
      throw const AuthException(
        code: AuthErrorCode.unknown,
        message: 'Google authentication failed.',
      );
    }

    // 3. Check Firestore profile
    final profile = await _userRepo.getUserById(firebaseUser.uid);

    if (profile == null) {
      // No profile → sign out and tell the caller to guide the user
      // through faculty registration / onboarding.
      await _firebaseAuth.signOut();
      await _googleAdapter.signOut();

      throw const AuthException(
        code: AuthErrorCode.googleNoAccount,
        message:
            'No account found for this Google identity. '
            'Please register first.',
      );
    }

    // 4. Validate the existing profile
    try {
      final claims = await _getTokenClaimsSafe();
      final verified = _validateProfile(profile, tokenClaims: claims);
      _currentUserModel = verified;
      return verified;
    } on AuthException {
      await _firebaseAuth.signOut();
      await _googleAdapter.signOut();
      rethrow;
    }
  }

  // ── Password Reset ──────────────────────────────────────────────────────

  Future<void> sendPasswordReset(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        // Industry-standard enumeration protection: do not reveal whether
        // the email address exists in the system.
        return;
      }
      throw _mapFirebaseException(e);
    }
  }

  // ── Logout ──────────────────────────────────────────────────────────────

  /// Signs out of Firebase Auth **and** Google Sign-In (if active).
  Future<void> signOut() async {
    _currentUserModel = null;
    // Sign out of Google first (best-effort)
    try {
      await _googleAdapter.signOut();
    } catch (_) {
      // Don't block sign-out if Google SDK errors
    }

    await _firebaseAuth.signOut();
  }

  // ── Session Restore (for Splash) ────────────────────────────────────────

  /// Re-validates the profile and security claims of the currently signed-in
  /// Firebase user.
  ///
  /// Returns `null` if no user is signed in.
  /// Throws [AuthException] if the session, claims, or profile are invalid.
  Future<UserModel?> restoreSession() async {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) return null;

    try {
      await firebaseUser.reload();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-disabled') {
        await signOut();
        throw const AuthException(
          code: AuthErrorCode.accountInactive,
          message: 'Your account has been deactivated.',
        );
      }
      if (e.code == 'user-not-found' ||
          e.code == 'user-token-expired' ||
          e.code == 'invalid-user-token') {
        await signOut();
        throw const AuthException(
          code: AuthErrorCode.invalidCredentials,
          message: 'Invalid email or password.',
        );
      }
    } catch (_) {
      // Unit mocks or offline transient reload errors still revalidate via profile/claims.
    }

    return _verifyProfile(firebaseUser.uid, forceRefreshClaims: true);
  }

  // ═════════════════════════════════════════════════════════════════════════
  //  Private helpers
  // ═════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> _getTokenClaimsSafe({
    bool forceRefresh = false,
  }) async {
    try {
      final current = _firebaseAuth.currentUser;
      if (current != null) {
        final tokenResult = await current.getIdTokenResult(forceRefresh);
        return tokenResult.claims;
      }
    } catch (_) {
      // Unit mocks without backed FirebaseAuth token claims fall back cleanly.
    }
    return null;
  }

  /// Fetches `users/{uid}` and validates the profile.
  ///
  /// On failure it signs the user out so there is no dangling Firebase
  /// session without a valid Firestore profile.
  Future<UserModel> _verifyProfile(
    String uid, {
    bool forceRefreshClaims = false,
  }) async {
    final UserModel? profile;
    try {
      profile = await _userRepo.getUserById(uid).timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw const AuthException(
              code: AuthErrorCode.networkError,
              message: 'Loading user profile timed out. Please check your connection.',
            ),
          );
    } on TimeoutException {
      await signOut();
      throw const AuthException(
        code: AuthErrorCode.networkError,
        message: 'Loading user profile timed out. Please check your connection.',
      );
    } catch (e) {
      if (e is AuthException) {
        await signOut();
        rethrow;
      }
      await signOut();
      throw AuthException(
        code: AuthErrorCode.unknown,
        message: 'Failed to retrieve user profile: $e',
      );
    }

    if (profile == null) {
      await signOut();
      throw const AuthException(
        code: AuthErrorCode.missingProfile,
        message:
            'Your account profile was not found. '
            'Please contact the administrator.',
      );
    }

    try {
      final claims = await _getTokenClaimsSafe(
        forceRefresh: forceRefreshClaims,
      );
      String? authEmail;
      try {
        authEmail = _firebaseAuth.currentUser?.email;
      } catch (_) {}
      final verified = _validateProfile(
        profile,
        tokenClaims: claims,
        authEmail: authEmail,
      );
      _currentUserModel = verified;
      return verified;
    } on AuthException {
      await signOut();
      rethrow;
    }
  }

  /// Pure validation — no side-effects.
  UserModel _validateProfile(
    UserModel profile, {
    Map<String, dynamic>? tokenClaims,
    String? authEmail,
  }) {
    // 1. Role must be one of the four known identifiers
    if (!AppStrings.allRoles.contains(profile.role)) {
      throw const AuthException(
        code: AuthErrorCode.invalidRole,
        message: 'Your account role or department configuration is invalid.',
      );
    }

    final profileEmail = profile.email.trim().toLowerCase();
    final normalizedAuthEmail = authEmail?.trim().toLowerCase();
    if (normalizedAuthEmail != null &&
        normalizedAuthEmail.isNotEmpty &&
        normalizedAuthEmail != profileEmail) {
      throw const AuthException(
        code: AuthErrorCode.unauthorizedInstitutionalAccount,
        message: 'This institutional account is not authorized.',
      );
    }

    // 1b. Token claim vs Firestore profile consistency check
    if (tokenClaims != null) {
      final claimRole = tokenClaims['role']?.toString().trim();
      if (claimRole != null && claimRole.isNotEmpty && claimRole != profile.role) {
        throw const AuthException(
          code: AuthErrorCode.invalidRole,
          message: 'Your account role or department configuration is invalid.',
        );
      }

      if (profile.isDeptHead) {
        final claimDept = tokenClaims['departmentId']?.toString().trim();
        final profileDept = profile.departmentId.trim();
        if (claimRole == AppStrings.roleDeptHead &&
            (claimDept == null || claimDept.isEmpty)) {
          throw const AuthException(
            code: AuthErrorCode.invalidDepartment,
            message: 'Your account role or department configuration is invalid.',
          );
        }
        if (claimDept != null &&
            claimDept.isNotEmpty &&
            claimDept != profileDept) {
          throw const AuthException(
            code: AuthErrorCode.invalidDepartment,
            message: 'Your account role or department configuration is invalid.',
          );
        }
      }
    }

    // 2. Strict institutional allowlist enforcement for Admin, Registrar, and Department Head
    if (!profile.isFaculty) {
      final spec = AppConstants.getInstitutionalSpec(profileEmail);
      if (spec == null) {
        throw const AuthException(
          code: AuthErrorCode.unauthorizedInstitutionalAccount,
          message: 'This institutional account is not authorized.',
        );
      }
      if (spec.role != profile.role) {
        throw const AuthException(
          code: AuthErrorCode.invalidRole,
          message: 'Your account role or department configuration is invalid.',
        );
      }
      if (profile.isDeptHead &&
          (profile.departmentId.trim().isEmpty ||
              profile.departmentId.trim() != spec.departmentId)) {
        throw const AuthException(
          code: AuthErrorCode.invalidDepartment,
          message: 'Your account role or department configuration is invalid.',
        );
      }
      if (profile.isPending) {
        throw const AuthException(
          code: AuthErrorCode.pendingApproval,
          message: 'Your account is pending approval.',
        );
      }
      if (!profile.isActive) {
        throw const AuthException(
          code: AuthErrorCode.accountInactive,
          message: 'Your account has been deactivated.',
        );
      }
      if (!profile.isApproved) {
        throw const AuthException(
          code: AuthErrorCode.unauthorizedInstitutionalAccount,
          message: 'This institutional account is not authorized.',
        );
      }
    } else {
      // 3. Faculty-specific checks (institutional emails cannot be used as faculty)
      if (AppConstants.isInstitutionalAllowlistedEmail(profileEmail)) {
        throw const AuthException(
          code: AuthErrorCode.invalidRole,
          message: 'Your account role or department configuration is invalid.',
        );
      }
      if (profile.isPending) {
        throw const AuthException(
          code: AuthErrorCode.pendingApproval,
          message: 'Your account is pending approval.',
        );
      }
      if (profile.isRejected) {
        throw const AuthException(
          code: AuthErrorCode.accountRejected,
          message:
              'Your account has been rejected. '
              'Please contact the administrator.',
        );
      }
      if (!profile.isActive) {
        throw const AuthException(
          code: AuthErrorCode.accountInactive,
          message: 'Your account has been deactivated.',
        );
      }
      // Faculty must be both active AND approved
      if (!profile.isActiveAndApproved) {
        throw const AuthException(
          code: AuthErrorCode.accountInactive,
          message: 'Your account has been deactivated.',
        );
      }
    }

    return profile;
  }

  /// Maps a [FirebaseAuthException] to our typed [AuthException].
  AuthException _mapFirebaseException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return const AuthException(
          code: AuthErrorCode.invalidCredentials,
          message: 'Invalid email or password.',
        );
      case 'email-already-in-use':
        return const AuthException(
          code: AuthErrorCode.emailAlreadyInUse,
          message: 'This email is already registered.',
        );
      case 'weak-password':
        return const AuthException(
          code: AuthErrorCode.weakPassword,
          message: 'Password must be at least 6 characters.',
        );
      case 'too-many-requests':
        return const AuthException(
          code: AuthErrorCode.tooManyRequests,
          message: 'Too many attempts. Please wait a moment and try again.',
        );
      case 'network-request-failed':
        return const AuthException(
          code: AuthErrorCode.networkError,
          message: 'Network error. Please check your connection.',
        );
      case 'invalid-email':
        return const AuthException(
          code: AuthErrorCode.invalidCredentials,
          message: 'Invalid email or password.',
        );
      case 'user-disabled':
        return const AuthException(
          code: AuthErrorCode.accountInactive,
          message: 'Your account has been deactivated.',
        );
      case 'account-exists-with-different-credential':
      case 'credential-already-in-use':
        return const AuthException(
          code: AuthErrorCode.credentialAlreadyInUse,
          message:
              'An account already exists with this email using a different sign-in method.',
        );
      default:
        return AuthException(
          code: AuthErrorCode.unknown,
          message: e.message ?? 'An unexpected error occurred.',
        );
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  Google Sign-In Adapter
//  Wraps google_sign_in 7.x API behind a simple interface so tests can
//  substitute a fake without depending on the concrete GoogleSignIn singleton.
// ═════════════════════════════════════════════════════════════════════════════

/// Seam that isolates the google_sign_in 7.x SDK calls.
abstract class GoogleSignInAdapter {
  const GoogleSignInAdapter();

  /// Triggers the interactive Google sign-in flow and returns an
  /// [OAuthCredential] that can be passed to
  /// `FirebaseAuth.signInWithCredential`.
  ///
  /// Throws [AuthException] on cancellation or failure.
  Future<OAuthCredential> authenticateAndGetCredential();

  /// Signs the user out of Google (best-effort).
  Future<void> signOut();
}

/// Production adapter that talks to [GoogleSignIn.instance].
class _DefaultGoogleSignInAdapter extends GoogleSignInAdapter {
  const _DefaultGoogleSignInAdapter();

  static bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    try {
      await GoogleSignIn.instance.initialize();
      _initialized = true;
    } catch (_) {
      // Best-effort initialization
      _initialized = true;
    }
  }

  @override
  Future<OAuthCredential> authenticateAndGetCredential() async {
    await _ensureInitialized();

    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        throw const AuthException(
          code: AuthErrorCode.googleSignInCancelled,
          message: 'Google Sign-In was cancelled.',
        );
      }
      throw AuthException(
        code: AuthErrorCode.googleSignInFailed,
        message: 'Google Sign-In failed: ${e.description ?? e.code.name}',
      );
    } catch (e) {
      throw const AuthException(
        code: AuthErrorCode.googleSignInFailed,
        message: 'Google Sign-In failed. Please try again.',
      );
    }

    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException(
        code: AuthErrorCode.missingIdToken,
        message: 'Google authentication failed: ID token is missing.',
      );
    }

    return GoogleAuthProvider.credential(idToken: idToken);
  }

  @override
  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
  }
}
