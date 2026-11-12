// ─────────────────────────────────────────────────────────────────────────────
//  app_workflow_test.dart  –  End-to-End Workflow & Multi-Role Integration Tests
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:leavexa/core/constants/app_strings.dart';
import 'package:leavexa/core/routes/app_routes.dart';
import 'package:leavexa/core/theme/app_theme.dart';
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
import 'package:leavexa/screens/admin/admin_profile_screen.dart';
import 'package:leavexa/screens/auth/forgot_password_screen.dart';
import 'package:leavexa/screens/auth/login_screen.dart';
import 'package:leavexa/screens/auth/register_screen.dart';
import 'package:leavexa/screens/faculty/apply_leave_screen.dart';
import 'package:leavexa/screens/faculty/faculty_dashboard.dart';
import 'package:leavexa/screens/faculty/leave_details_screen.dart';
import 'package:leavexa/screens/faculty/my_leaves_screen.dart';
import 'package:leavexa/screens/faculty/notifications_screen.dart';
import 'package:leavexa/screens/faculty/profile_screen.dart';
import 'package:leavexa/screens/faculty/settings_screen.dart';
import 'package:leavexa/screens/head/dept_calendar_screen.dart';
import 'package:leavexa/screens/head/head_dashboard.dart';
import 'package:leavexa/screens/head/head_profile_screen.dart';
import 'package:leavexa/screens/head/head_requests_screen.dart';
import 'package:leavexa/screens/registrar/registrar_dashboard.dart';
import 'package:leavexa/services/auth_exception.dart';
import 'package:leavexa/services/notification_service.dart';

/// In-memory fake AuthRepository simulating real role and status behavior.
class E2EAuthRepository extends AuthRepository {
  final Map<String, UserModel> users = {};
  int logoutCalls = 0;

  E2EAuthRepository() {
    // Seed initial test users for all 4 roles
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

    users['head@leavexa.edu'] = UserModel(
      uid: 'head_cse',
      fullName: 'Prof. Dr. Tariqul Islam',
      email: 'head@leavexa.edu',
      employeeId: 'EMP-H1005',
      departmentId: 'dept_cse',
      departmentName: 'Computer Science & Engineering',
      designation: 'Professor & Head of Department',
      role: AppStrings.roleDeptHead,
      isActive: true,
      approvalStatus: 'approved',
      createdAt: DateTime(2025, 1, 1),
    );

    users['registrar@leavexa.edu'] = UserModel(
      uid: 'registrar_1',
      fullName: 'Dr. Academic Registrar',
      email: 'registrar@leavexa.edu',
      employeeId: 'REG-001',
      departmentId: 'dept_reg',
      departmentName: 'Registrar Office',
      designation: 'Registrar',
      role: AppStrings.roleRegistrar,
      isActive: true,
      approvalStatus: 'approved',
      createdAt: DateTime(2025, 1, 1),
    );

    users['faculty.approved@leavexa.edu'] = UserModel(
      uid: 'faculty_approved',
      fullName: 'Md. Arman',
      email: 'faculty.approved@leavexa.edu',
      employeeId: 'FAC-1024',
      departmentId: 'dept_cse',
      departmentName: 'Computer Science & Engineering',
      designation: 'Lecturer',
      role: AppStrings.roleFaculty,
      isActive: true,
      approvalStatus: 'approved',
      createdAt: DateTime(2025, 1, 1),
    );

    users['faculty.pending@leavexa.edu'] = UserModel(
      uid: 'faculty_pending',
      fullName: 'Pending Lecturer',
      email: 'faculty.pending@leavexa.edu',
      employeeId: 'FAC-9999',
      departmentId: 'dept_cse',
      departmentName: 'Computer Science & Engineering',
      designation: 'Lecturer',
      role: AppStrings.roleFaculty,
      isActive: false,
      approvalStatus: 'pending',
      createdAt: DateTime(2025, 1, 1),
    );

    users['faculty.rejected@leavexa.edu'] = UserModel(
      uid: 'faculty_rejected',
      fullName: 'Rejected Lecturer',
      email: 'faculty.rejected@leavexa.edu',
      employeeId: 'FAC-0000',
      departmentId: 'dept_cse',
      departmentName: 'Computer Science & Engineering',
      designation: 'Lecturer',
      role: AppStrings.roleFaculty,
      isActive: false,
      approvalStatus: 'rejected',
      createdAt: DateTime(2025, 1, 1),
    );
  }

  String? activeUserUid;

  @override
  String? get currentUserId => activeUserUid ?? 'faculty_approved';

  @override
  Future<UserModel?> getCurrentUserProfile() async {
    final uid = currentUserId;
    if (uid == null) return null;
    return users.values.cast<UserModel?>().firstWhere(
      (u) => u?.uid == uid,
      orElse: () => users['faculty.approved@leavexa.edu'],
    );
  }

  @override
  Future<UserModel> loginAndGetProfile({
    required String email,
    required String password,
  }) async {
    final user = users[email.trim().toLowerCase()];
    if (user == null || password != 'Password123!') {
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
    final normalizedEmail = email.trim().toLowerCase();
    if (users.containsKey(normalizedEmail)) {
      throw const AuthException(
        code: AuthErrorCode.emailAlreadyInUse,
        message: 'This email is already registered.',
      );
    }

    final newUid = 'uid_${DateTime.now().millisecondsSinceEpoch}';
    users[normalizedEmail] = UserModel(
      uid: newUid,
      fullName: fullName,
      email: normalizedEmail,
      employeeId: employeeId,
      departmentId: departmentName.toLowerCase().replaceAll(' ', '_'),
      departmentName: departmentName,
      designation: designation,
      role: AppStrings.roleFaculty,
      isActive: false,
      approvalStatus: 'pending',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> forgotPassword(String email) async {
    // Valid reset link dispatched
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
  }
}

class E2ELeaveRepository extends LeaveRepository {
  bool cancelCalled = false;
  String? cancelledAppId;

  @override
  Future<void> cancelLeave({
    required String applicationId,
    required String applicantUid,
    String? reason,
  }) async {
    cancelCalled = true;
    cancelledAppId = applicationId;
  }

  @override
  Future<LeaveApplicationModel?> getApplicationById(String id) async {
    return null;
  }

  @override
  Future<List<LeaveBalanceModel>> balancesForUser(String uid) async {
    return [
      const LeaveBalanceModel(
        id: 'b1',
        userUid: 'faculty_approved',
        leaveTypeId: 'casual',
        leaveTypeName: 'Casual Leave',
        totalAllotted: 10,
        used: 2,
        year: 2026,
      ),
      const LeaveBalanceModel(
        id: 'b2',
        userUid: 'faculty_approved',
        leaveTypeId: 'medical',
        leaveTypeName: 'Medical Leave',
        totalAllotted: 14,
        used: 4,
        year: 2026,
      ),
      const LeaveBalanceModel(
        id: 'b3',
        userUid: 'faculty_approved',
        leaveTypeId: 'earned',
        leaveTypeName: 'Earned Leave',
        totalAllotted: 30,
        used: 5,
        year: 2026,
      ),
    ];
  }

  @override
  Future<List<LeaveApplicationModel>> myApplications(String uid) async => [];
}

class E2EUserRepository extends UserRepository {
  bool createStaffCalled = false;
  Map<String, dynamic>? createdStaff;
  bool setActiveCalled = false;
  String? activeUid;
  bool? activeStatus;

  @override
  Future<List<UserModel>> getPendingFaculty() async => [];

  @override
  Future<List<UserModel>> getAllFaculty() async => [
        UserModel(
          uid: 'faculty_approved',
          fullName: 'Md. Arman',
          email: 'faculty.approved@leavexa.edu',
          employeeId: 'FAC-1024',
          departmentId: 'dept_cse',
          departmentName: 'Computer Science & Engineering',
          designation: 'Lecturer',
          role: 'faculty',
          isActive: true,
          approvalStatus: 'approved',
          createdAt: DateTime(2025, 1, 1),
        ),
      ];

  @override
  Future<Map<String, dynamic>> createStaffAccount({
    required String email,
    required String password,
    required String fullName,
    required String employeeId,
    required String role,
    String? departmentId,
    String? departmentName,
    String? designation,
    String? phone,
  }) async {
    createStaffCalled = true;
    createdStaff = {
      'email': email,
      'password': password,
      'fullName': fullName,
      'employeeId': employeeId,
      'role': role,
      'departmentId': departmentId,
      'departmentName': departmentName,
      'designation': designation,
      'phone': phone,
    };
    return {'success': true, 'uid': 'staff_999'};
  }

  @override
  Future<void> setUserActive(String uid, bool isActive) async {
    setActiveCalled = true;
    activeUid = uid;
    activeStatus = isActive;
  }
}

class E2ENotificationService extends NotificationService {
  @override
  Future<List<NotificationModel>> getForUser(String uid) async => [];
}

Widget buildTestApp(E2EAuthRepository repo) {
  return MaterialApp(
    theme: AppTheme.light,
    initialRoute: AppRoutes.login,
    routes: {
      AppRoutes.login: (_) => LoginScreen(authRepository: repo),
      AppRoutes.register: (_) => RegisterScreen(authRepository: repo),
      AppRoutes.forgotPassword: (_) =>
          ForgotPasswordScreen(authRepository: repo),
      AppRoutes.facultyDashboard: (_) => const FacultyDashboard(),
      AppRoutes.myLeaves: (_) => const MyLeavesScreen(),
      AppRoutes.applyLeave: (_) => const ApplyLeaveScreen(),
      AppRoutes.notifications: (_) => const NotificationsScreen(),
      AppRoutes.profile: (_) => const ProfileScreen(),
      AppRoutes.settings: (_) => SettingsScreen(authRepository: repo),
      AppRoutes.headDashboard: (_) => const HeadDashboard(),
      AppRoutes.headProfile: (_) => HeadProfileScreen(authRepository: repo),
      AppRoutes.headRequests: (_) => const HeadRequestsScreen(),
      AppRoutes.deptCalendar: (_) => const DeptCalendarScreen(),
      AppRoutes.adminDashboard: (_) => const AdminDashboard(),
      AppRoutes.adminProfile: (_) => AdminProfileScreen(authRepository: repo),
      AppRoutes.registrarDashboard: (_) => const RegistrarDashboard(),
    },
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late E2EAuthRepository authRepo;

  setUp(() {
    authRepo = E2EAuthRepository();
    AppThemeState.instance.resetToLightMode();
    FacultyProfileState.instance.reset();
  });

  group('Phase 10 — Multi-Role End-to-End Workflow Testing', () {
    testWidgets(
      '1. Faculty Workflow: Registration, Pending check, Login, Dashboard, Profile, Leave Apply & Logout',
      (tester) async {
        await tester.pumpWidget(buildTestApp(authRepo));
        await tester.pumpAndSettle();

        // Verify Login Screen
        expect(find.text('Welcome Back'), findsOneWidget);

        // Navigate to Registration
        await tester.tap(find.text('Register'));
        await tester.pumpAndSettle();
        expect(find.text('Create Your Account'), findsOneWidget);

        // Navigate back to Login
        Navigator.of(tester.element(find.text('Create Your Account'))).pop();
        await tester.pumpAndSettle();
        expect(find.text('Welcome Back'), findsOneWidget);

        // Attempt login with Pending Faculty account
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Email Address / Employee ID'),
          'faculty.pending@leavexa.edu',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'),
          'Password123!',
        );
        await tester.tap(find.text('Login'));
        await tester.pumpAndSettle();

        // Verify pending approval error snackbar is displayed
        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.textContaining('pending administrator approval'),
          findsOneWidget,
        );
        expect(find.byType(FacultyDashboard), findsNothing);

        // Dismiss snackbar and log in with Approved Faculty account
        ScaffoldMessenger.of(
          tester.element(find.byType(LoginScreen)),
        ).hideCurrentSnackBar();
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Email Address / Employee ID'),
          'faculty.approved@leavexa.edu',
        );
        await tester.tap(find.text('Login'));
        await tester.pumpAndSettle();

        // Successfully routed to Faculty Dashboard
        expect(find.byType(FacultyDashboard), findsOneWidget);
        expect(find.text('LEAVE BALANCE'), findsOneWidget);

        // Open Apply Leave screen
        await tester.tap(find.text('Apply for Leave'));
        await tester.pumpAndSettle();
        expect(find.byType(ApplyLeaveScreen), findsOneWidget);

        // Back to Dashboard
        await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded).first);
        await tester.pumpAndSettle();

        // Navigate to Profile via bottom nav
        await tester.tap(find.text('Profile'));
        await tester.pumpAndSettle();
        expect(find.byType(ProfileScreen), findsOneWidget);

        // Navigate to Settings
        await tester.tap(find.byIcon(Icons.settings_outlined));
        await tester.pumpAndSettle();
        expect(find.byType(SettingsScreen), findsOneWidget);

        // Trigger Logout dialog
        await tester.scrollUntilVisible(find.text('Logout'), 200.0);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Logout'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Are you sure you want to log out of your Leavexa account?',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Yes, Log Out'));
        await tester.pumpAndSettle();

        // Cleanly routed back to Login Screen
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(authRepo.logoutCalls, 1);
      },
    );

    testWidgets(
      '2. Admin Workflow: Login, Dashboard, Review Registrations & Logout',
      (tester) async {
        await tester.pumpWidget(buildTestApp(authRepo));
        await tester.pumpAndSettle();

        // Log in as Admin
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Email Address / Employee ID'),
          'admin@leavexa.edu',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'),
          'Password123!',
        );
        await tester.tap(find.text('Login'));
        await tester.pumpAndSettle();

        // Successfully routed to Admin Dashboard
        expect(find.byType(AdminDashboard), findsOneWidget);
        expect(find.text('Pending Verifications'), findsOneWidget);

        // Navigate to Admin Profile & Log out
        await tester.tap(find.text('Profile'));
        await tester.pumpAndSettle();
        expect(find.byType(AdminProfileScreen), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('Log Out of Admin Portal'),
          200.0,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Log Out of Admin Portal'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Are you sure you want to log out of the Administrator Portal?',
          ),
          findsOneWidget,
        );
        await tester.tap(find.widgetWithText(ElevatedButton, 'Log Out'));
        await tester.pumpAndSettle();

        // Cleanly returned to Login Screen
        expect(find.byType(LoginScreen), findsOneWidget);
      },
    );

    testWidgets(
      '3. Department Head Workflow: Login, Dashboard, Department Oversight & Logout',
      (tester) async {
        await tester.pumpWidget(buildTestApp(authRepo));
        await tester.pumpAndSettle();

        // Log in as Department Head
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Email Address / Employee ID'),
          'head@leavexa.edu',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'),
          'Password123!',
        );
        await tester.tap(find.text('Login'));
        await tester.pumpAndSettle();

        // Successfully routed to Head Dashboard
        expect(find.byType(HeadDashboard), findsOneWidget);

        // Navigate to Head Profile & Log out
        await tester.tap(find.text('Profile'));
        await tester.pumpAndSettle();
        expect(find.byType(HeadProfileScreen), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('Log Out of Head Portal'),
          200.0,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Log Out of Head Portal'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Are you sure you want to log out of Department Head Portal?',
          ),
          findsOneWidget,
        );
        await tester.tap(find.widgetWithText(ElevatedButton, 'Log Out'));
        await tester.pumpAndSettle();

        expect(find.byType(LoginScreen), findsOneWidget);
      },
    );

    testWidgets('4. Registrar Workflow: Login, Registrar Dashboard & Logout', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp(authRepo));
      await tester.pumpAndSettle();

      // Log in as Registrar
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email Address / Employee ID'),
        'registrar@leavexa.edu',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'Password123!',
      );
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      // Successfully routed to dedicated Registrar Dashboard (zero Admin controls)
      expect(find.byType(RegistrarDashboard), findsOneWidget);
      expect(find.text('Registrar Dashboard'), findsOneWidget);
      expect(find.text('Create Staff Account (Head / Registrar)'), findsNothing);

      // Navigate to Profile & Log out
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Registrar Profile'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Log Out of Registrar Portal'),
        200.0,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log Out of Registrar Portal'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Are you sure you want to log out of the Registrar Portal?',
        ),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Log Out'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets(
      '5. Forgot Password Flow: Navigation, Form Validation & Submit',
      (tester) async {
        await tester.pumpWidget(buildTestApp(authRepo));
        await tester.pumpAndSettle();

        // Tap Forgot Password
        await tester.tap(find.text('Forgot Password?'));
        await tester.pumpAndSettle();
        expect(find.byType(ForgotPasswordScreen), findsOneWidget);

        // Empty submission
        await tester.tap(find.text('Send Reset Link'));
        await tester.pumpAndSettle();
        expect(find.text('Please enter your email'), findsOneWidget);

        // Enter valid email and submit
        await tester.enterText(
          find.widgetWithText(TextFormField, 'University Email Address'),
          'faculty.approved@leavexa.edu',
        );
        await tester.tap(find.text('Send Reset Link'));
        await tester.pumpAndSettle();

        // Success SnackBar displayed
        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.textContaining('password reset link has been sent'),
          findsOneWidget,
        );

        // Return to Login
        await tester.tap(find.text('Back to Login'));
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsOneWidget);
      },
    );

    testWidgets(
      '6. Phase 19: Faculty Leave Details & Cancellation Flow',
      (tester) async {
        final leaveRepo = E2ELeaveRepository();
        final testApp = LeaveApplicationModel(
          id: 'app_cancel_test',
          applicantUid: 'faculty_approved',
          applicantName: 'Md. Arman',
          applicantEmployeeId: 'FAC-1024',
          departmentId: 'dept_cse',
          departmentName: 'Computer Science & Engineering',
          leaveTypeId: 'casual',
          leaveTypeName: 'Casual Leave',
          startDate: DateTime.now().add(const Duration(days: 3)),
          endDate: DateTime.now().add(const Duration(days: 5)),
          totalDays: 3,
          reason: 'Personal emergency',
          status: 'pending',
          appliedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: LeaveDetailsScreen(
              application: testApp,
              leaveRepository: leaveRepo,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify Pending status and Cancel button
        expect(find.byKey(const Key('cancel_leave_button')), findsOneWidget);

        // Open cancellation dialog
        await tester.ensureVisible(find.byKey(const Key('cancel_leave_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('cancel_leave_button')));
        await tester.pumpAndSettle();

        expect(find.text('Cancel Leave Request'), findsNWidgets(2));
        expect(find.byKey(const Key('confirm_cancel_button')), findsOneWidget);

        // Enter optional cancellation reason and confirm
        await tester.enterText(
          find.byKey(const Key('cancel_reason_field')),
          'Schedule conflict resolved',
        );
        await tester.tap(find.byKey(const Key('confirm_cancel_button')));
        await tester.pumpAndSettle();

        expect(leaveRepo.cancelCalled, isTrue);
        expect(leaveRepo.cancelledAppId, 'app_cancel_test');
      },
    );

    testWidgets(
      '7. Phase 19: Admin Staff Account Management & Faculty Directory Active Toggle',
      (tester) async {
        final userRepo = E2EUserRepository();

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: AdminDashboard(userRepository: userRepo),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify and tap "Create Staff Account" button
        expect(find.byKey(const Key('create_staff_account_button')), findsOneWidget);
        await tester.tap(find.byKey(const Key('create_staff_account_button')));
        await tester.pumpAndSettle();

        // Verify bottomsheet elements
        expect(find.text('Create Staff Account'), findsOneWidget);
        expect(find.byKey(const Key('role_department_head_chip')), findsOneWidget);
        expect(find.byKey(const Key('role_registrar_chip')), findsOneWidget);
        expect(find.byKey(const Key('staff_dept_dropdown')), findsOneWidget);

        // Switch to Registrar role (dept dropdown hides)
        await tester.tap(find.byKey(const Key('role_registrar_chip')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('staff_dept_dropdown')), findsNothing);

        // Fill form fields
        await tester.enterText(
          find.byKey(const Key('staff_name_field')),
          'Dr. Registrar Office',
        );
        await tester.enterText(
          find.byKey(const Key('staff_empid_field')),
          'REG-888',
        );
        await tester.enterText(
          find.byKey(const Key('staff_email_field')),
          'new.reg@leavexa.edu',
        );
        await tester.enterText(
          find.byKey(const Key('staff_password_field')),
          'StrongPass888#',
        );
        await tester.pumpAndSettle();

        // Submit staff creation
        await tester.tap(find.byKey(const Key('submit_create_staff_button')));
        await tester.pumpAndSettle();

        expect(userRepo.createStaffCalled, isTrue);
        expect(userRepo.createdStaff?['role'], 'registrar');
        expect(userRepo.createdStaff?['employeeId'], 'REG-888');

        // 2. Switch to Faculty Directory tab & toggle Active status
        await tester.tap(find.byIcon(Icons.people_outline_rounded));
        await tester.pumpAndSettle();

        final toggleKey = find.byKey(const Key('toggle_active_faculty_approved'));
        expect(toggleKey, findsOneWidget);
        expect(find.text('ACTIVE'), findsOneWidget);

        await tester.tap(toggleKey);
        await tester.pumpAndSettle();

        expect(userRepo.setActiveCalled, isTrue);
        expect(userRepo.activeUid, 'faculty_approved');
        expect(userRepo.activeStatus, false);
        expect(find.text('INACTIVE'), findsOneWidget);
      },
    );

    testWidgets(
      '8. Phase 19: Faculty Dashboard Real Leave Balances & Type Alignment',
      (tester) async {
        final auth = E2EAuthRepository();
        final leaveRepo = E2ELeaveRepository();
        final notifService = E2ENotificationService();

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: FacultyDashboard(
              authRepository: auth,
              leaveRepository: leaveRepo,
              notificationService: notifService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify all 6 balance categories are present in horizontal view
        expect(find.text('Casual Leave'), findsWidgets);
        expect(find.text('Medical Leave'), findsOneWidget);
        expect(find.text('Earned Leave'), findsOneWidget);
        expect(find.text('Duty Leave'), findsWidgets);
        expect(find.text('Station Leave'), findsWidgets);
        expect(find.text('Study Leave'), findsWidgets);

        // Verify remaining days and used calculations:
        // Casual: 10 total - 2 used = 8 remaining
        expect(find.text('8'), findsOneWidget);
        expect(find.text('2 used of 10'), findsOneWidget);

        // Medical: 14 total - 4 used = 10 remaining
        expect(find.text('10'), findsWidgets);
        expect(find.text('4 used of 14'), findsOneWidget);

        // Earned: 30 total - 5 used = 25 remaining
        expect(find.text('25'), findsOneWidget);
        expect(find.text('5 used of 30'), findsOneWidget);
      },
    );
  });
}
