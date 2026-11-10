import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leavexa/core/utils/helpers.dart';
import 'package:leavexa/models/faculty_profile_state.dart';
import 'package:leavexa/models/leave_application_model.dart';
import 'package:leavexa/models/leave_balance_model.dart';
import 'package:leavexa/models/notification_model.dart';
import 'package:leavexa/models/user_model.dart';
import 'package:leavexa/repositories/auth_repository.dart';
import 'package:leavexa/repositories/leave_repository.dart';
import 'package:leavexa/repositories/user_repository.dart';
import 'package:leavexa/screens/admin/admin_dashboard.dart';
import 'package:leavexa/screens/admin/admin_profile_screen.dart';
import 'package:leavexa/screens/faculty/faculty_dashboard.dart';
import 'package:leavexa/screens/faculty/profile_screen.dart';
import 'package:leavexa/screens/head/head_dashboard.dart';
import 'package:leavexa/screens/head/head_profile_screen.dart';
import 'package:leavexa/services/notification_service.dart';
import 'package:leavexa/widgets/app_avatar.dart';

class MockAuthRepo extends AuthRepository {
  UserModel? mockUser;

  @override
  String? get currentUserId => mockUser?.uid;

  @override
  Future<UserModel?> getCurrentUserProfile() async => mockUser;
}

class MockLeaveRepo extends LeaveRepository {
  @override
  Future<List<LeaveBalanceModel>> balancesForUser(String uid) async => [];

  @override
  Future<List<LeaveApplicationModel>> departmentPending(String deptId) async =>
      [];
}

class MockNotificationService extends NotificationService {
  @override
  Future<List<NotificationModel>> getForUser(String uid) async => [];
}

class MockUserRepo extends UserRepository {
  @override
  Future<List<UserModel>> getPendingFaculty() async => [];

  @override
  Future<List<UserModel>> getAllFaculty() async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Optional Profile Photo - Initials Generation & AppAvatar Unit Tests', () {
    test('AppHelpers.initials correctly formats various names without photo', () {
      expect(AppHelpers.initials('Admin'), 'AD');
      expect(AppHelpers.initials('Md. Arman'), 'MA');
      expect(AppHelpers.initials('Dr. Tariqul Islam'), 'TI');
      expect(AppHelpers.initials('Prof. Dr. Tariqul Islam'), 'TI');
      expect(AppHelpers.initials('Chief Registrar Office'), 'CO');
      expect(AppHelpers.initials(''), '?');
      expect(AppHelpers.initials('   '), '?');
    });

    testWidgets('AppAvatar renders initials when photoUrl is null or empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppAvatar(
                name: 'Dr. Jane Smith',
                photoUrl: null,
                size: 50,
              ),
            ),
          ),
        ),
      );

      expect(find.text('JS'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('AppAvatar renders initials for single-word names', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppAvatar(
                name: 'Administrator',
                photoUrl: '',
                size: 40,
              ),
            ),
          ),
        ),
      );

      expect(find.text('AD'), findsOneWidget);
    });
  });

  group('Optional Profile Photo - Faculty Role Screens', () {
    final facultyUser = UserModel(
      uid: 'faculty_user_01',
      email: 'faculty@leavexa.edu',
      fullName: 'Dr. Jane Smith',
      employeeId: 'EMP-F101',
      role: 'faculty',
      departmentId: 'dept_cse',
      departmentName: 'Computer Science & Engineering',
      designation: 'Associate Professor',
      approvalStatus: 'approved',
      photoUrl: null, // Completely optional photo
      createdAt: DateTime.now(),
    );

    testWidgets('FacultyDashboard displays clean initials avatar with null photoUrl', (tester) async {
      FacultyProfileState.instance.updateProfile(
        fullName: 'Dr. Jane Smith',
        removePhoto: true,
      );
      final mockAuth = MockAuthRepo()..mockUser = facultyUser;
      final mockLeave = MockLeaveRepo();
      final mockNotif = MockNotificationService();

      await tester.pumpWidget(
        MaterialApp(
          home: FacultyDashboard(
            authRepository: mockAuth,
            leaveRepository: mockLeave,
            notificationService: mockNotif,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // AppAvatar should display "JS"
      expect(find.text('JS'), findsOneWidget);
      // No mandatory photo upload popup or blocker
      expect(find.text('Upload Profile Photo to Continue'), findsNothing);
    });

    testWidgets('Faculty ProfileScreen renders initials avatar without photo', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileScreen(),
        ),
      );
      await tester.pump();

      // AppAvatar renders cleanly
      expect(find.byType(AppAvatar), findsOneWidget);
      expect(find.text('Upload Profile Photo to Continue'), findsNothing);
    });
  });

  group('Optional Profile Photo - Department Head Role Screens', () {
    final headUser = UserModel(
      uid: 'head_user_01',
      email: 'head.cse@leavexa.edu',
      fullName: 'Prof. Dr. Tariqul Islam',
      employeeId: 'EMP-H1005',
      role: 'department_head',
      departmentId: 'dept_cse',
      departmentName: 'Computer Science & Engineering',
      designation: 'Professor & Head',
      approvalStatus: 'approved',
      photoUrl: null, // No photo uploaded
      createdAt: DateTime.now(),
    );

    testWidgets('HeadDashboard renders initials avatar with null photoUrl', (tester) async {
      final mockAuth = MockAuthRepo()..mockUser = headUser;
      final mockLeave = MockLeaveRepo();

      await tester.pumpWidget(
        MaterialApp(
          home: HeadDashboard(
            authRepository: mockAuth,
            leaveRepository: mockLeave,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(AppAvatar), findsOneWidget);
      expect(find.text('TI'), findsOneWidget);
    });

    testWidgets('HeadProfileScreen renders initials avatar and optional photo hint', (tester) async {
      final mockAuth = MockAuthRepo()..mockUser = headUser;

      await tester.pumpWidget(
        MaterialApp(
          home: HeadProfileScreen(
            authRepository: mockAuth,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(AppAvatar), findsOneWidget);
      expect(find.text('TI'), findsOneWidget);
    });
  });

  group('Optional Profile Photo - Admin & Registrar Role Screens', () {
    final adminUser = UserModel(
      uid: 'admin_user_01',
      email: 'admin@leavexa.edu',
      fullName: 'System Administrator',
      employeeId: 'EMP-ADM01',
      role: 'admin',
      departmentId: 'dept_admin',
      departmentName: 'Administration & Registry',
      designation: 'Chief Registrar',
      approvalStatus: 'approved',
      photoUrl: null, // Optional photo
      createdAt: DateTime.now(),
    );

    testWidgets('AdminDashboard renders initials avatar with null photoUrl', (tester) async {
      final mockAuth = MockAuthRepo()..mockUser = adminUser;
      final mockUserRepo = MockUserRepo();

      await tester.pumpWidget(
        MaterialApp(
          home: AdminDashboard(
            userRepository: mockUserRepo,
            authRepository: mockAuth,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(AppAvatar), findsOneWidget);
      expect(find.text('SA'), findsOneWidget);
    });

    testWidgets('AdminProfileScreen renders initials avatar without photo', (tester) async {
      final mockAuth = MockAuthRepo()..mockUser = adminUser;

      await tester.pumpWidget(
        MaterialApp(
          home: AdminProfileScreen(
            authRepository: mockAuth,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(AppAvatar), findsOneWidget);
      expect(find.text('SA'), findsOneWidget);
    });
  });
}
