// ─────────────────────────────────────────────────────────────────────────────
//  faculty_lifecycle_e2e_workflow_test.dart
//  Complete Faculty Account Lifecycle Flutter UI Workflow Test
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:leavexa/core/constants/app_strings.dart';
import 'package:leavexa/models/faculty_profile_state.dart';
import 'package:leavexa/models/leave_application_model.dart';
import 'package:leavexa/models/leave_balance_model.dart';
import 'package:leavexa/models/notification_model.dart';
import 'package:leavexa/models/registration_state.dart';
import 'package:leavexa/models/user_model.dart';
import 'package:leavexa/repositories/auth_repository.dart';
import 'package:leavexa/repositories/leave_repository.dart';
import 'package:leavexa/repositories/user_repository.dart';
import 'package:leavexa/screens/admin/admin_dashboard.dart';
import 'package:leavexa/screens/auth/login_screen.dart';
import 'package:leavexa/screens/auth/register_screen.dart';
import 'package:leavexa/screens/faculty/faculty_dashboard.dart';
import 'package:leavexa/screens/faculty/profile_screen.dart';
import 'package:leavexa/services/auth_exception.dart';
import 'package:leavexa/services/notification_service.dart';
import 'package:leavexa/widgets/app_avatar.dart';

/// In-memory fake AuthRepository simulating the lifecycle.
class LifecycleTestAuthRepository extends AuthRepository {
  final Map<String, UserModel> users = {};
  UserModel? loggedInUser;
  String? registeredEmpId;

  LifecycleTestAuthRepository() {
    // Seed Admin
    users['admin@leavexa.edu'] = UserModel(
      uid: 'admin_1',
      fullName: 'System Administrator',
      email: 'admin@leavexa.edu',
      employeeId: 'ADM-001',
      departmentId: 'dept_admin',
      departmentName: 'Administration',
      designation: 'Chief Administrator',
      role: AppStrings.roleAdmin,
      isActive: true,
      approvalStatus: 'approved',
      createdAt: DateTime(2025, 1, 1),
    );
  }

  @override
  String? get currentUserId => loggedInUser?.uid;

  @override
  Future<UserModel?> getCurrentUserProfile() async => loggedInUser;

  @override
  Future<UserModel> loginAndGetProfile({
    required String email,
    required String password,
  }) async {
    final user = users[email.trim().toLowerCase()];
    if (user == null || password != 'ValidPassword123!') {
      throw const AuthException(
        code: AuthErrorCode.invalidCredentials,
        message: 'Invalid email or password.',
      );
    }

    if (user.isFaculty) {
      if (user.isPending) {
        throw const AuthException(
          code: AuthErrorCode.pendingApproval,
          message: 'Your registration is pending administrator approval.',
        );
      }
      if (user.isRejected) {
        throw const AuthException(
          code: AuthErrorCode.accountRejected,
          message: 'Your registration was rejected by the administrator.',
        );
      }
      if (!user.isActive) {
        throw const AuthException(
          code: AuthErrorCode.accountInactive,
          message: 'Your account has been deactivated.',
        );
      }
    }

    loggedInUser = user;
    return user;
  }

  @override
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
    registeredEmpId = employeeId;
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedEmpId = employeeId.trim().toUpperCase();

    final newUser = UserModel(
      uid: 'faculty_e2e_new',
      fullName: fullName.trim(),
      email: normalizedEmail,
      employeeId: normalizedEmpId,
      departmentId: 'dept_cse',
      departmentName: departmentName,
      designation: designation,
      role: AppStrings.roleFaculty,
      phone: phone.trim(),
      isActive: false,
      approvalStatus: 'pending',
      photoUrl: null, // Profile photo optional
      createdAt: DateTime.now(),
    );

    users[normalizedEmail] = newUser;
  }

  @override
  Future<void> logout() async {
    loggedInUser = null;
  }
}

class LifecycleTestUserRepository extends UserRepository {
  final LifecycleTestAuthRepository authRepo;
  bool approveCalled = false;
  String? approvedUid;

  LifecycleTestUserRepository(this.authRepo);

  @override
  Future<List<UserModel>> getPendingFaculty() async {
    return authRepo.users.values.where((u) => u.isPending).toList();
  }

  @override
  Future<List<UserModel>> getAllFaculty() async {
    return authRepo.users.values.where((u) => u.isFaculty).toList();
  }

  @override
  Future<void> approveFaculty(String uid) async {
    approveCalled = true;
    approvedUid = uid;

    final entry = authRepo.users.entries.firstWhere(
      (e) => e.value.uid == uid,
      orElse: () => throw Exception('User not found'),
    );

    authRepo.users[entry.key] = entry.value.copyWith(
      approvalStatus: 'approved',
      isActive: true,
    );
  }
}

class LifecycleMockLeaveRepo extends LeaveRepository {
  @override
  Future<List<LeaveBalanceModel>> balancesForUser(String uid) async => [];

  @override
  Future<List<LeaveApplicationModel>> departmentPending(String deptId) async => [];
}

class LifecycleMockNotificationService extends NotificationService {
  @override
  Future<List<NotificationModel>> getForUser(String uid) async => [];
}

void main() {
  late LifecycleTestAuthRepository authRepo;
  late LifecycleTestUserRepository userRepo;

  setUp(() {
    authRepo = LifecycleTestAuthRepository();
    userRepo = LifecycleTestUserRepository(authRepo);
  });

  group('Phase 20 — Faculty Lifecycle E2E Flutter UI Workflow', () {
    testWidgets('1. Faculty registers via UI with auto-capitalized Employee ID and pending status', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(home: RegisterScreen(authRepository: authRepo)),
      );
      await tester.pumpAndSettle();

      // Form text fields:
      // at(0) -> Full Name
      // at(1) -> Employee ID
      // at(2) -> Email
      // at(3) -> Phone
      // at(4) -> Password
      // at(5) -> Confirm Password
      await tester.enterText(find.byType(TextFormField).at(0), 'Dr. New Faculty E2E');
      await tester.enterText(find.byType(TextFormField).at(1), 'fac-cse-909'); // lowercase
      await tester.enterText(find.byType(TextFormField).at(2), 'newfaculty@leavexa.edu');
      await tester.enterText(find.byType(TextFormField).at(3), '+8801711223344');
      await tester.enterText(find.byType(TextFormField).at(4), 'ValidPassword123!');
      await tester.enterText(find.byType(TextFormField).at(5), 'ValidPassword123!');

      // Select Department
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Computer Science & Engineering').last);
      await tester.pumpAndSettle();

      // Select Designation
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Assistant Professor').last);
      await tester.pumpAndSettle();

      // Check terms checkbox
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      // Tap Create Account
      await tester.tap(find.text('Create Account'));
      await tester.pump();

      // Verify that employeeId was normalized to uppercase
      expect(authRepo.registeredEmpId, 'FAC-CSE-909');

      // Verify success SnackBar message
      expect(
        find.text('Registration successful! Your account is pending admin approval.'),
        findsOneWidget,
      );

      // Verify saved state in user document
      final savedUser = authRepo.users['newfaculty@leavexa.edu'];
      expect(savedUser, isNotNull);
      expect(savedUser!.approvalStatus, 'pending');
      expect(savedUser.isActive, isFalse);
      expect(savedUser.employeeId, 'FAC-CSE-909');
      expect(savedUser.photoUrl, isNull);

      await tester.pumpAndSettle();
    });

    testWidgets('2. Pending Faculty login attempt displays pending verification message and blocks dashboard access', (
      tester,
    ) async {
      // Seed pending user
      authRepo.users['newfaculty@leavexa.edu'] = UserModel(
        uid: 'faculty_e2e_new',
        fullName: 'Dr. New Faculty E2E',
        email: 'newfaculty@leavexa.edu',
        employeeId: 'FAC-CSE-909',
        departmentId: 'dept_cse',
        departmentName: 'Computer Science & Engineering',
        designation: 'Assistant Professor',
        role: AppStrings.roleFaculty,
        isActive: false,
        approvalStatus: 'pending',
        photoUrl: null,
        createdAt: DateTime.now(),
      );

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(home: LoginScreen(authRepository: authRepo)),
      );
      await tester.pumpAndSettle();

      final emailField = find.byType(TextFormField).first;
      final passField = find.byType(TextFormField).at(1);
      await tester.enterText(emailField, 'newfaculty@leavexa.edu');
      await tester.enterText(passField, 'ValidPassword123!');

      await tester.tap(find.text('Login'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify error SnackBar
      expect(
        find.text('Your registration is pending administrator approval.'),
        findsOneWidget,
      );

      // Verify still on login screen
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('3. Admin Dashboard loads pending list, displays faculty info, and approves account', (
      tester,
    ) async {
      // Seed pending user
      final pendingFaculty = UserModel(
        uid: 'faculty_e2e_new',
        fullName: 'Dr. New Faculty E2E',
        email: 'newfaculty@leavexa.edu',
        employeeId: 'FAC-CSE-909',
        departmentId: 'dept_cse',
        departmentName: 'Computer Science & Engineering',
        designation: 'Assistant Professor',
        role: AppStrings.roleFaculty,
        isActive: false,
        approvalStatus: 'pending',
        photoUrl: null,
        createdAt: DateTime.now(),
      );
      authRepo.users['newfaculty@leavexa.edu'] = pendingFaculty;

      // Set logged in user as Admin
      authRepo.loggedInUser = authRepo.users['admin@leavexa.edu'];

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AdminDashboard(
            authRepository: authRepo,
            userRepository: userRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to Approvals tab (tab index 1)
      await tester.tap(find.text('Approvals'));
      await tester.pumpAndSettle();

      // Verify pending faculty is displayed in verification list
      expect(find.text('Dr. New Faculty E2E'), findsWidgets);

      // Trigger approval on the pending teacher card
      final approveButton = find.text('Approve').first;
      await tester.tap(approveButton);
      await tester.pumpAndSettle();

      // Verify repository approveFaculty called
      expect(userRepo.approveCalled, isTrue);
      expect(userRepo.approvedUid, 'faculty_e2e_new');

      // Verify user model in authRepo is now approved and active
      final approvedUser = authRepo.users['newfaculty@leavexa.edu'];
      expect(approvedUser!.approvalStatus, 'approved');
      expect(approvedUser.isActive, isTrue);
    });

    testWidgets('4. Approved Faculty logs in and uses app with initials avatar (optional photo)', (
      tester,
    ) async {
      // Seed approved active faculty without photoUrl
      final approvedFaculty = UserModel(
        uid: 'faculty_e2e_new',
        fullName: 'Dr. New Faculty E2E',
        email: 'newfaculty@leavexa.edu',
        employeeId: 'FAC-CSE-909',
        departmentId: 'dept_cse',
        departmentName: 'Computer Science & Engineering',
        designation: 'Assistant Professor',
        role: AppStrings.roleFaculty,
        isActive: true,
        approvalStatus: 'approved',
        photoUrl: null, // Profile photo optional!
        createdAt: DateTime.now(),
      );
      authRepo.users['newfaculty@leavexa.edu'] = approvedFaculty;
      authRepo.loggedInUser = approvedFaculty;

      FacultyProfileState.instance.updateProfile(
        fullName: approvedFaculty.fullName,
        email: approvedFaculty.email,
        phone: '+8801711223344',
        removePhoto: true,
      );

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Pump FacultyDashboard
      await tester.pumpWidget(
        MaterialApp(
          home: FacultyDashboard(
            authRepository: authRepo,
            leaveRepository: LifecycleMockLeaveRepo(),
            notificationService: LifecycleMockNotificationService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify AppAvatar displays clean initials avatar without error
      final avatarFinder = find.byType(AppAvatar);
      expect(avatarFinder, findsWidgets);

      // Pump ProfileScreen
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify profile displays without mandatory photo
      expect(find.byType(AppAvatar), findsWidgets);
    });
  });
}
