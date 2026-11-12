import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:leavexa/core/constants/app_strings.dart';
import 'package:leavexa/core/routes/app_routes.dart';
import 'package:leavexa/models/leave_application_model.dart';
import 'package:leavexa/models/user_model.dart';
import 'package:leavexa/repositories/auth_repository.dart';
import 'package:leavexa/repositories/leave_repository.dart';
import 'package:leavexa/repositories/user_repository.dart';
import 'package:leavexa/screens/head/head_dashboard.dart';
import 'package:leavexa/screens/head/head_requests_screen.dart';
import 'package:leavexa/screens/registrar/registrar_dashboard.dart';
import 'package:leavexa/services/auth_exception.dart';
import 'package:leavexa/services/auth_service.dart';

class _FakeAuthRepo extends AuthRepository {
  UserModel? user;
  bool logoutCalled = false;
  _FakeAuthRepo(this.user);

  @override
  Future<UserModel?> getCurrentUserProfile() async => user;

  @override
  String? get currentUserId => user?.uid;

  @override
  Future<void> logout() async {
    logoutCalled = true;
    AuthRepository.activeUser = null;
  }
}

class _FakeUserRepo extends UserRepository {
  final List<UserModel> deptUsers;
  _FakeUserRepo([this.deptUsers = const []]);

  @override
  Future<List<UserModel>> getFacultyByDepartment(String departmentId) async =>
      deptUsers.where((u) => u.departmentId == departmentId).toList();
}

class _FakeLeaveRepo extends LeaveRepository {
  final List<LeaveApplicationModel> allApps;
  String? lastQueriedDeptId;

  _FakeLeaveRepo(this.allApps);

  @override
  Future<List<LeaveApplicationModel>> departmentApplications(
    String deptId,
  ) async {
    lastQueriedDeptId = deptId;
    return allApps.where((a) => a.departmentId == deptId).toList();
  }

  @override
  Future<List<LeaveApplicationModel>> departmentPending(String deptId) async {
    lastQueriedDeptId = deptId;
    return allApps
        .where((a) => a.departmentId == deptId && a.status == 'pending')
        .toList();
  }

  @override
  Stream<List<LeaveApplicationModel>> streamDepartmentApplications(
    String deptId,
  ) {
    lastQueriedDeptId = deptId;
    return Stream.value(
      allApps.where((a) => a.departmentId == deptId).toList(),
    );
  }

  @override
  Future<List<LeaveApplicationModel>> registrarApplications() async => allApps
      .where(
        (a) =>
            a.status == 'forwarded' ||
            a.status == 'approved' ||
            a.status == 'rejected',
      )
      .toList();

  @override
  Stream<List<LeaveApplicationModel>> streamForwardedAll() =>
      Stream.value(allApps.where((a) => a.status == 'forwarded').toList());
}

class _FakeIdTokenResult implements IdTokenResult {
  @override
  final Map<String, dynamic>? claims;
  _FakeIdTokenResult(this.claims);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFirebaseUser implements User {
  @override
  final String uid;
  final Map<String, dynamic> customClaims;
  _FakeFirebaseUser(this.uid, this.customClaims);

  @override
  Future<IdTokenResult> getIdTokenResult([bool forceRefresh = false]) async =>
      _FakeIdTokenResult(customClaims);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFirebaseAuth implements FirebaseAuth {
  final _FakeFirebaseUser user;
  bool signedOut = false;
  _FakeFirebaseAuth(this.user);

  @override
  User? get currentUser => user;

  @override
  Future<void> signOut() async {
    signedOut = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeGoogleAdapter extends GoogleSignInAdapter {
  @override
  Future<OAuthCredential> authenticateAndGetCredential() =>
      throw UnimplementedError();
  @override
  Future<void> signOut() async {}
}

class _SingleUserRepo extends UserRepository {
  final UserModel? profile;
  _SingleUserRepo(this.profile);

  @override
  Future<UserModel?> getUserById(String uid) async => profile;
}

void main() {
  final eeeHead = UserModel(
    uid: 'head_eee_uid',
    email: 'head.eee.lu@gmail.com',
    fullName: 'Department Head (EEE)',
    employeeId: 'HEAD-EEE-001',
    departmentId: 'dept_eee',
    departmentName: 'Electrical & Electronic Engineering',
    designation: 'Department Head',
    role: AppStrings.roleDeptHead,
    approvalStatus: 'approved',
    isActive: true,
    createdAt: DateTime(2026, 1, 1),
  );

  final csePendingApp = LeaveApplicationModel(
    id: 'app_cse_1',
    applicantUid: 'fac_cse_1',
    applicantName: 'Dr. CSE Researcher',
    applicantEmployeeId: 'CSE-101',
    departmentId: 'dept_cse',
    departmentName: 'Computer Science & Engineering',
    leaveTypeId: 'casual',
    leaveTypeName: 'Casual Leave',
    startDate: DateTime(2026, 11, 20),
    endDate: DateTime(2026, 11, 21),
    totalDays: 2,
    reason: 'CSE symposium',
    status: 'pending',
    appliedAt: DateTime(2026, 11, 10),
  );

  final eeePendingApp = LeaveApplicationModel(
    id: 'app_eee_1',
    applicantUid: 'fac_eee_1',
    applicantName: 'Engr. EEE Lecturer',
    applicantEmployeeId: 'EEE-202',
    departmentId: 'dept_eee',
    departmentName: 'Electrical & Electronic Engineering',
    leaveTypeId: 'medical',
    leaveTypeName: 'Medical Leave',
    startDate: DateTime(2026, 11, 22),
    endDate: DateTime(2026, 11, 24),
    totalDays: 3,
    reason: 'Dental surgery recovery',
    status: 'pending',
    appliedAt: DateTime(2026, 11, 11),
  );

  final forwardedApp = LeaveApplicationModel(
    id: 'app_fwd_1',
    applicantUid: 'fac_law_1',
    applicantName: 'Adv. Law Faculty',
    applicantEmployeeId: 'LAW-301',
    departmentId: 'dept_law',
    departmentName: 'Department of Law',
    leaveTypeId: 'duty',
    leaveTypeName: 'Duty Leave',
    startDate: DateTime(2026, 11, 25),
    endDate: DateTime(2026, 11, 26),
    totalDays: 2,
    reason: 'Moot court seminar',
    status: 'forwarded',
    headUid: 'head_law_uid',
    headComment: 'Recommended by Law Head',
    appliedAt: DateTime(2026, 11, 12),
  );

  group('Department Head Strict Isolation (Zero CSE Fallback / Hardcoding)', () {
    testWidgets(
      'EEE HeadDashboard displays EEE department data only and excludes CSE applications',
      (tester) async {
        final authRepo = _FakeAuthRepo(eeeHead);
        final leaveRepo = _FakeLeaveRepo([csePendingApp, eeePendingApp]);
        final userRepo = _FakeUserRepo([eeeHead]);

        await tester.pumpWidget(
          MaterialApp(
            home: HeadDashboard(
              authRepository: authRepo,
              leaveRepository: leaveRepo,
              userRepository: userRepo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(leaveRepo.lastQueriedDeptId, equals('dept_eee'));
        expect(find.textContaining('Department Head (EEE)'), findsOneWidget);
        expect(find.text('Electrical & Electronic Engineering'), findsOneWidget);
        expect(find.text('Engr. EEE Lecturer'), findsOneWidget);
        // Must NEVER render CSE app or fake CSE names
        expect(find.text('Dr. CSE Researcher'), findsNothing);
        expect(find.text('Dr. Sarah Ahmed'), findsNothing);
        expect(find.text('Department of Computer Science & Engineering'), findsNothing);
      },
    );

    testWidgets(
      'HeadRequestsScreen shows only real department requests and zero hardcoded CSE mocks',
      (tester) async {
        final authRepo = _FakeAuthRepo(eeeHead);
        final leaveRepo = _FakeLeaveRepo([csePendingApp, eeePendingApp]);

        await tester.pumpWidget(
          MaterialApp(
            home: HeadRequestsScreen(
              authRepository: authRepo,
              leaveRepository: leaveRepo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(leaveRepo.lastQueriedDeptId, equals('dept_eee'));
        expect(find.text('Engr. EEE Lecturer'), findsOneWidget);
        expect(find.text('Dr. CSE Researcher'), findsNothing);
        expect(find.text('Mr. Tanvir Hasan'), findsNothing);
      },
    );

    testWidgets(
      'HeadDashboard blocks access cleanly when departmentId is missing',
      (tester) async {
        final badHead = UserModel(
          uid: 'bad_head',
          email: 'bad.head@gmail.com',
          fullName: 'Unassigned Head',
          employeeId: 'HEAD-BAD',
          departmentId: '',
          departmentName: '',
          designation: 'Department Head',
          role: AppStrings.roleDeptHead,
          approvalStatus: 'approved',
          isActive: true,
          createdAt: DateTime(2026, 1, 1),
        );

        final leaveRepo = _FakeLeaveRepo([csePendingApp, eeePendingApp]);
        await tester.pumpWidget(
          MaterialApp(
            home: HeadDashboard(
              authRepository: _FakeAuthRepo(badHead),
              leaveRepository: leaveRepo,
              userRepository: _FakeUserRepo(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(leaveRepo.lastQueriedDeptId, isNull);
        expect(find.textContaining('Department assignment is missing'), findsOneWidget);
        expect(find.text('Dr. CSE Researcher'), findsNothing);
        expect(find.text('Engr. EEE Lecturer'), findsNothing);
      },
    );
  });

  group('Registrar Dedicated Console & Role Isolation', () {
    testWidgets(
      'RegistrarDashboard renders Forwarded Queue without Admin Faculty Approval / Staff Creation UI',
      (tester) async {
        final regUser = UserModel(
          uid: 'reg_1',
          email: 'registrar.lu@gmail.com',
          fullName: 'Office of the Registrar',
          employeeId: 'REG-001',
          departmentId: 'registrar_office',
          departmentName: 'Office of the Registrar',
          designation: 'Registrar',
          role: AppStrings.roleRegistrar,
          approvalStatus: 'approved',
          isActive: true,
          createdAt: DateTime(2026, 1, 1),
        );

        final leaveRepo = _FakeLeaveRepo([csePendingApp, forwardedApp]);
        await tester.pumpWidget(
          MaterialApp(
            routes: {
              AppRoutes.login: (_) => const Scaffold(body: Text('Login Mock')),
            },
            home: RegistrarDashboard(
              authRepository: _FakeAuthRepo(regUser),
              leaveRepository: leaveRepo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Registrar Dashboard'), findsOneWidget);
        expect(find.text('Adv. Law Faculty'), findsOneWidget);
        expect(find.text('Head Remarks: Recommended by Law Head'), findsOneWidget);
        // Must NOT show unforwarded pending apps or Admin-only buttons
        expect(find.text('Dr. CSE Researcher'), findsNothing);
        expect(find.text('Create Staff Account (Head / Registrar)'), findsNothing);
        expect(find.text('Admin Dashboard'), findsNothing);
      },
    );
  });

  group('AuthService Claim & Department Consistency Guard', () {
    test('denies Head session when custom claim departmentId disagrees with Firestore profile', () async {
      final authService = AuthService(
        auth: _FakeFirebaseAuth(
          _FakeFirebaseUser('head_eee_uid', {
            'role': 'department_head',
            'departmentId': 'dept_cse', // Mismatch!
          }),
        ),
        userRepository: _SingleUserRepo(eeeHead),
        googleSignInAdapter: _FakeGoogleAdapter(),
      );

      await expectLater(
        authService.restoreSession(),
        throwsA(
          isA<AuthException>().having(
            (e) => e.code,
            'code',
            AuthErrorCode.invalidDepartment,
          ),
        ),
      );
    });

    test('denies Head session when custom claim is missing departmentId', () async {
      final authService = AuthService(
        auth: _FakeFirebaseAuth(
          _FakeFirebaseUser('head_eee_uid', {
            'role': 'department_head',
          }),
        ),
        userRepository: _SingleUserRepo(eeeHead),
        googleSignInAdapter: _FakeGoogleAdapter(),
      );

      await expectLater(
        authService.restoreSession(),
        throwsA(
          isA<AuthException>().having(
            (e) => e.code,
            'code',
            AuthErrorCode.invalidDepartment,
          ),
        ),
      );
    });
  });
}
