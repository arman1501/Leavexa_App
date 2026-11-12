import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:leavexa/core/constants/app_constants.dart';
import 'package:leavexa/core/constants/app_strings.dart';
import 'package:leavexa/models/user_model.dart';
import 'package:leavexa/repositories/user_repository.dart';
import 'package:leavexa/services/auth_exception.dart';
import 'package:leavexa/services/auth_service.dart';

class _FakeIdTokenResult implements IdTokenResult {
  @override
  final Map<String, dynamic> claims;

  _FakeIdTokenResult(this.claims);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFirebaseUser implements User {
  @override
  final String uid;

  @override
  final String? email;

  final Map<String, dynamic> claims;
  FirebaseAuthException? reloadException;
  bool reloadCalled = false;
  bool? lastForceRefresh;

  _FakeFirebaseUser(
    this.uid,
    this.claims, {
    this.email,
    this.reloadException,
  });

  @override
  Future<void> reload() async {
    reloadCalled = true;
    if (reloadException != null) {
      throw reloadException!;
    }
  }

  @override
  Future<IdTokenResult> getIdTokenResult([bool forceRefresh = false]) async {
    lastForceRefresh = forceRefresh;
    return _FakeIdTokenResult(claims);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUserCredential implements UserCredential {
  @override
  final User? user;

  _FakeUserCredential(this.user);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFirebaseAuth implements FirebaseAuth {
  User? _current;
  bool signOutCalled = false;
  FirebaseAuthException? nextSignInException;

  _FakeFirebaseAuth([this._current]);

  @override
  User? get currentUser => _current;

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (nextSignInException != null) {
      throw nextSignInException!;
    }
    return _FakeUserCredential(_current);
  }

  @override
  Future<void> signOut() async {
    signOutCalled = true;
    _current = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUserRepository extends UserRepository {
  final Map<String, UserModel> _users = {};

  void seed(UserModel user) => _users[user.uid] = user;

  @override
  Future<UserModel?> getUserById(String uid) async => _users[uid];
}

class _FakeGoogleAdapter extends GoogleSignInAdapter {
  @override
  Future<OAuthCredential> authenticateAndGetCredential() =>
      throw UnimplementedError();

  @override
  Future<void> signOut() async {}
}

UserModel _makeProfile({
  required String uid,
  required String email,
  required String role,
  required String departmentId,
  String approvalStatus = 'approved',
  bool isActive = true,
}) {
  return UserModel(
    uid: uid,
    email: email,
    fullName: 'Test $role',
    employeeId: 'EMP-$uid',
    departmentId: departmentId,
    departmentName: departmentId,
    designation: role,
    role: role,
    approvalStatus: approvalStatus,
    isActive: isActive,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('Strict Institutional Login Authentication (12 Scenarios)', () {
    test('1-5. Allows all 12 allowlisted institutional accounts with matching claims & department', () async {
      for (final entry in AppConstants.institutionalAccountAllowlist.entries) {
        final spec = entry.value;
        final uid = 'uid_${spec.departmentId}';
        final userRepo = _FakeUserRepository()
          ..seed(
            _makeProfile(
              uid: uid,
              email: spec.email,
              role: spec.role,
              departmentId: spec.departmentId,
            ),
          );
        final claims = <String, dynamic>{
          'role': spec.role,
          'approvalStatus': 'approved',
          if (spec.role == AppStrings.roleDeptHead)
            'departmentId': spec.departmentId,
        };
        final fakeAuth = _FakeFirebaseAuth(
          _FakeFirebaseUser(uid, claims, email: spec.email),
        );
        final service = AuthService(
          auth: fakeAuth,
          userRepository: userRepo,
          googleSignInAdapter: _FakeGoogleAdapter(),
        );

        final profile = await service.loginAndGetProfile(
          email: spec.email,
          password: 'ephemeral-test-password',
        );
        expect(profile.email, spec.email);
        expect(profile.role, spec.role);
        expect(profile.departmentId, spec.departmentId);
        expect(fakeAuth.signOutCalled, isFalse);
      }
    });

    test('6. Wrong password or unknown auth email returns generic Invalid email or password', () async {
      for (final code in ['wrong-password', 'user-not-found', 'invalid-credential']) {
        final fakeAuth = _FakeFirebaseAuth()
          ..nextSignInException = FirebaseAuthException(code: code);
        final service = AuthService(
          auth: fakeAuth,
          userRepository: _FakeUserRepository(),
          googleSignInAdapter: _FakeGoogleAdapter(),
        );

        await expectLater(
          service.loginAndGetProfile(
            email: 'admin.lu@gmail.com',
            password: 'wrong',
          ),
          throwsA(
            isA<AuthException>()
                .having((e) => e.code, 'code', AuthErrorCode.invalidCredentials)
                .having((e) => e.message, 'message', 'Invalid email or password.'),
          ),
        );
      }
    });

    test('7. Unknown Gmail with forged admin/registrar/head role is denied and signed out', () async {
      for (final role in [
        AppStrings.roleAdmin,
        AppStrings.roleRegistrar,
        AppStrings.roleDeptHead,
      ]) {
        const rogueEmail = 'rogue.user@gmail.com';
        final uid = 'rogue_$role';
        final userRepo = _FakeUserRepository()
          ..seed(
            _makeProfile(
              uid: uid,
              email: rogueEmail,
              role: role,
              departmentId: role == AppStrings.roleDeptHead ? 'dept_cse' : 'admin_office',
            ),
          );
        final fakeAuth = _FakeFirebaseAuth(
          _FakeFirebaseUser(
            uid,
            {
              'role': role,
              if (role == AppStrings.roleDeptHead) 'departmentId': 'dept_cse',
            },
            email: rogueEmail,
          ),
        );
        final service = AuthService(
          auth: fakeAuth,
          userRepository: userRepo,
          googleSignInAdapter: _FakeGoogleAdapter(),
        );

        await expectLater(
          service.loginAndGetProfile(
            email: rogueEmail,
            password: 'ephemeral-test-password',
          ),
          throwsA(
            isA<AuthException>()
                .having(
                  (e) => e.code,
                  'code',
                  AuthErrorCode.unauthorizedInstitutionalAccount,
                )
                .having(
                  (e) => e.message,
                  'message',
                  'This institutional account is not authorized.',
                ),
          ),
        );
        expect(fakeAuth.signOutCalled, isTrue);
      }
    });

    test('8. Approved and active Faculty account login succeeds normally', () async {
      final userRepo = _FakeUserRepository()
        ..seed(
          _makeProfile(
            uid: 'fac_1',
            email: 'faculty.cse@gmail.com',
            role: AppStrings.roleFaculty,
            departmentId: 'dept_cse',
            approvalStatus: 'approved',
            isActive: true,
          ),
        );
      final fakeAuth = _FakeFirebaseAuth(
        _FakeFirebaseUser(
          'fac_1',
          {'role': 'faculty', 'departmentId': 'dept_cse'},
          email: 'faculty.cse@gmail.com',
        ),
      );
      final service = AuthService(
        auth: fakeAuth,
        userRepository: userRepo,
        googleSignInAdapter: _FakeGoogleAdapter(),
      );

      final result = await service.loginAndGetProfile(
        email: 'faculty.cse@gmail.com',
        password: 'ephemeral-test-password',
      );
      expect(result.isFaculty, isTrue);
      expect(result.isActiveAndApproved, isTrue);
    });

    test('9. Pending Faculty account is denied with pending approval message and signed out', () async {
      final userRepo = _FakeUserRepository()
        ..seed(
          _makeProfile(
            uid: 'fac_pending',
            email: 'pending.fac@gmail.com',
            role: AppStrings.roleFaculty,
            departmentId: 'dept_cse',
            approvalStatus: 'pending',
            isActive: false,
          ),
        );
      final fakeAuth = _FakeFirebaseAuth(
        _FakeFirebaseUser('fac_pending', {}, email: 'pending.fac@gmail.com'),
      );
      final service = AuthService(
        auth: fakeAuth,
        userRepository: userRepo,
        googleSignInAdapter: _FakeGoogleAdapter(),
      );

      await expectLater(
        service.loginAndGetProfile(
          email: 'pending.fac@gmail.com',
          password: 'ephemeral-test-password',
        ),
        throwsA(
          isA<AuthException>()
              .having((e) => e.code, 'code', AuthErrorCode.pendingApproval)
              .having(
                (e) => e.message,
                'message',
                'Your account is pending approval.',
              ),
        ),
      );
      expect(fakeAuth.signOutCalled, isTrue);
    });

    test('10. Inactive institutional account is denied with deactivated message and signed out', () async {
      final userRepo = _FakeUserRepository()
        ..seed(
          _makeProfile(
            uid: 'head_cse_inactive',
            email: 'head.cse.lu@gmail.com',
            role: AppStrings.roleDeptHead,
            departmentId: 'dept_cse',
            approvalStatus: 'approved',
            isActive: false,
          ),
        );
      final fakeAuth = _FakeFirebaseAuth(
        _FakeFirebaseUser(
          'head_cse_inactive',
          {'role': 'department_head', 'departmentId': 'dept_cse'},
          email: 'head.cse.lu@gmail.com',
        ),
      );
      final service = AuthService(
        auth: fakeAuth,
        userRepository: userRepo,
        googleSignInAdapter: _FakeGoogleAdapter(),
      );

      await expectLater(
        service.loginAndGetProfile(
          email: 'head.cse.lu@gmail.com',
          password: 'ephemeral-test-password',
        ),
        throwsA(
          isA<AuthException>()
              .having((e) => e.code, 'code', AuthErrorCode.accountInactive)
              .having(
                (e) => e.message,
                'message',
                'Your account has been deactivated.',
              ),
        ),
      );
      expect(fakeAuth.signOutCalled, isTrue);
    });

    test('11. Department Head with mismatched departmentId in profile or claims is denied', () async {
      final userRepo = _FakeUserRepository()
        ..seed(
          _makeProfile(
            uid: 'head_cse_mismatch',
            email: 'head.cse.lu@gmail.com',
            role: AppStrings.roleDeptHead,
            departmentId: 'dept_eee', // CSE Head assigned wrong dept!
          ),
        );
      final fakeAuth = _FakeFirebaseAuth(
        _FakeFirebaseUser(
          'head_cse_mismatch',
          {'role': 'department_head', 'departmentId': 'dept_eee'},
          email: 'head.cse.lu@gmail.com',
        ),
      );
      final service = AuthService(
        auth: fakeAuth,
        userRepository: userRepo,
        googleSignInAdapter: _FakeGoogleAdapter(),
      );

      await expectLater(
        service.loginAndGetProfile(
          email: 'head.cse.lu@gmail.com',
          password: 'ephemeral-test-password',
        ),
        throwsA(
          isA<AuthException>()
              .having((e) => e.code, 'code', AuthErrorCode.invalidDepartment)
              .having(
                (e) => e.message,
                'message',
                'Your account role or department configuration is invalid.',
              ),
        ),
      );
      expect(fakeAuth.signOutCalled, isTrue);
    });

    test('12. Existing session restoreSession reloads Auth user, force-refreshes claims, and revokes disabled session', () async {
      final userRepo = _FakeUserRepository()
        ..seed(
          _makeProfile(
            uid: 'admin_1',
            email: 'admin.lu@gmail.com',
            role: AppStrings.roleAdmin,
            departmentId: 'admin_office',
          ),
        );
      final fakeUser = _FakeFirebaseUser(
        'admin_1',
        {'role': 'admin'},
        email: 'admin.lu@gmail.com',
        reloadException: FirebaseAuthException(code: 'user-disabled'),
      );
      final fakeAuth = _FakeFirebaseAuth(fakeUser);
      final service = AuthService(
        auth: fakeAuth,
        userRepository: userRepo,
        googleSignInAdapter: _FakeGoogleAdapter(),
      );

      await expectLater(
        service.restoreSession(),
        throwsA(
          isA<AuthException>()
              .having((e) => e.code, 'code', AuthErrorCode.accountInactive)
              .having(
                (e) => e.message,
                'message',
                'Your account has been deactivated.',
              ),
        ),
      );
      expect(fakeUser.reloadCalled, isTrue);
      expect(fakeAuth.signOutCalled, isTrue);
    });

    test('12b. Existing valid session force-refreshes claims during restoreSession', () async {
      final userRepo = _FakeUserRepository()
        ..seed(
          _makeProfile(
            uid: 'reg_1',
            email: 'registrar.lu@gmail.com',
            role: AppStrings.roleRegistrar,
            departmentId: 'registrar_office',
          ),
        );
      final fakeUser = _FakeFirebaseUser(
        'reg_1',
        {'role': 'registrar'},
        email: 'registrar.lu@gmail.com',
      );
      final fakeAuth = _FakeFirebaseAuth(fakeUser);
      final service = AuthService(
        auth: fakeAuth,
        userRepository: userRepo,
        googleSignInAdapter: _FakeGoogleAdapter(),
      );

      final restored = await service.restoreSession();
      expect(restored?.role, AppStrings.roleRegistrar);
      expect(fakeUser.reloadCalled, isTrue);
      expect(fakeUser.lastForceRefresh, isTrue);
    });
  });
}
