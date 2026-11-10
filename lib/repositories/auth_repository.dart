// ─────────────────────────────────────────────────────────────────────────────
//  auth_repository.dart  –  Abstraction layer over AuthService
// ─────────────────────────────────────────────────────────────────────────────

import 'package:firebase_auth/firebase_auth.dart';

import '../models/faculty_profile_state.dart';
import '../models/registration_state.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/fcm_service.dart';

class AuthRepository {
  AuthService? _authService;
  FcmService? _fcmService;
  static UserModel? activeUser;

  AuthRepository({
    AuthService? authService,
    FcmService? fcmService,
  })  : _authService = authService,
        _fcmService = fcmService;

  AuthService get _service => _authService ??= AuthService();
  FcmService get _fcm => _fcmService ??= FcmService();

  UserModel? get currentUserModel => _service.currentUserModel ?? activeUser;

  Future<UserModel?> getCurrentUserProfile() async {
    if (activeUser != null) return activeUser;
    final uid = currentUserId;
    if (uid == null) return null;
    final profile = await _service.getCurrentProfile(uid);
    if (profile != null) {
      activeUser = profile;
      _syncFacultyProfile(profile);
    }
    return profile;
  }

  static void _syncFacultyProfile(UserModel user) {
    if (user.isFaculty) {
      FacultyProfileState.instance.notifier.value = FacultyProfileData(
        fullName: user.fullName,
        email: user.email,
        phone: user.phone ?? '',
        employeeId: user.employeeId,
        department: user.departmentName,
        designation: user.designation,
        photoUrl: user.photoUrl,
      );
    }
  }

  // ── Login ───────────────────────────────────────────────────────────────

  /// Legacy login — Firebase sign-in only, no profile verification.
  Future<void> login({required String email, required String password}) =>
      _service.signIn(email: email, password: password);

  /// Full login — Firebase sign-in **+ Firestore profile verification**.
  /// Returns the validated [UserModel] ready for role-based routing.
  Future<UserModel> loginAndGetProfile({
    required String email,
    required String password,
  }) async {
    final user = await _service.loginAndGetProfile(
      email: email,
      password: password,
    );
    activeUser = user;
    _syncFacultyProfile(user);
    try {
      await _fcm.initialize(currentUid: user.uid);
    } catch (_) {}
    return user;
  }

  // ── Google Sign-In ──────────────────────────────────────────────────────

  /// Google authentication + profile verification.
  /// Throws if no Firestore profile exists (user must register first).
  Future<UserModel> signInWithGoogle() async {
    final user = await _service.signInWithGoogle();
    activeUser = user;
    _syncFacultyProfile(user);
    try {
      await _fcm.initialize(currentUid: user.uid);
    } catch (_) {}
    return user;
  }

  // ── Registration ────────────────────────────────────────────────────────

  /// Basic Firebase Auth registration — returns UID.
  Future<String> register({required String email, required String password}) =>
      _service.register(email: email, password: password);

  /// Full faculty registration with Firestore profile and lifecycle updates.
  Future<void> registerFaculty({
    required String fullName,
    required String employeeId,
    required String email,
    required String phone,
    required String departmentName,
    required String designation,
    required String password,
    void Function(RegistrationState state)? onStateChanged,
  }) => _service.registerFaculty(
    fullName: fullName,
    employeeId: employeeId,
    email: email,
    phone: phone,
    departmentName: departmentName,
    designation: designation,
    password: password,
    onStateChanged: onStateChanged,
  );

  // ── Password Reset ──────────────────────────────────────────────────────

  Future<void> forgotPassword(String email) =>
      _service.sendPasswordReset(email);

  // ── Logout ──────────────────────────────────────────────────────────────

  /// Signs out of Firebase Auth **and** Google Sign-In.
  Future<void> logout() async {
    final uid = currentUserId ?? activeUser?.uid;
    if (uid != null) {
      try {
        await _fcm.unregisterDeviceToken(uid);
      } catch (_) {}
    }
    activeUser = null;
    FacultyProfileState.instance.reset();
    await _service.signOut();
  }

  // ── Session ─────────────────────────────────────────────────────────────

  /// Restores the session for the currently signed-in user.
  /// Returns `null` if no user is signed in.
  Future<UserModel?> restoreSession() async {
    final user = await _service.restoreSession();
    activeUser = user;
    if (user != null) {
      _syncFacultyProfile(user);
      try {
        await _fcm.initialize(currentUid: user.uid);
      } catch (_) {}
    }
    return user;
  }

  // ── Auth State ──────────────────────────────────────────────────────────

  /// Current Firebase UID (null if signed out or uninitialized).
  String? get currentUserId {
    try {
      return _service.currentUid;
    } catch (_) {
      return null;
    }
  }

  /// Current Firebase user object.
  User? get currentUser {
    try {
      return _service.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// Real-time authentication state stream.
  Stream<User?> get authStateChanges => _service.authStateChanges;
}
