import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:leavexa/core/constants/app_strings.dart';
import 'package:leavexa/core/routes/app_routes.dart';
import 'package:leavexa/models/faculty_profile_state.dart';
import 'package:leavexa/models/leave_application_model.dart';
import 'package:leavexa/models/leave_balance_model.dart';
import 'package:leavexa/models/user_model.dart';
import 'package:leavexa/repositories/auth_repository.dart';
import 'package:leavexa/repositories/leave_repository.dart';
import 'package:leavexa/repositories/user_repository.dart';
import 'package:leavexa/screens/faculty/apply_leave_screen.dart';
import 'package:leavexa/screens/faculty/profile_screen.dart';
import 'package:leavexa/screens/head/dept_calendar_screen.dart';
import 'package:leavexa/screens/registrar/registrar_dashboard.dart';

class _FakeAuthRepo extends AuthRepository {
  final UserModel user;
  _FakeAuthRepo(this.user);

  @override
  String? get currentUserId => user.uid;

  @override
  Future<UserModel?> getCurrentUserProfile() async => user;
}

class _FakeLeaveRepo extends LeaveRepository {
  final List<LeaveApplicationModel> apps;
  _FakeLeaveRepo([this.apps = const []]);

  @override
  Future<List<LeaveBalanceModel>> balancesForUser(String uid) async => const [];

  @override
  Future<List<LeaveApplicationModel>> departmentApplications(
    String deptId,
  ) async => apps.where((a) => a.departmentId == deptId).toList();

  @override
  Stream<List<LeaveApplicationModel>> streamDepartmentApplications(
    String deptId,
  ) => Stream.value(apps.where((a) => a.departmentId == deptId).toList());

  @override
  Future<List<LeaveApplicationModel>> registrarApplications() async => apps;
}

class _FakeUserRepo extends UserRepository {
  @override
  Future<List<UserModel>> getFacultyByDepartment(String departmentId) async =>
      const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final facultyUser = UserModel(
    uid: 'fac_draft_1',
    email: 'faculty.cse@gmail.com',
    fullName: 'Dr. CSE Faculty',
    employeeId: 'CSE-101',
    departmentId: 'dept_cse',
    departmentName: 'Computer Science & Engineering',
    designation: 'Assistant Professor',
    role: AppStrings.roleFaculty,
    approvalStatus: 'approved',
    isActive: true,
    createdAt: DateTime(2026, 1, 1),
  );

  final cseHeadUser = UserModel(
    uid: 'head_cse_1',
    email: 'head.cse.lu@gmail.com',
    fullName: 'Head of CSE',
    employeeId: 'HEAD-CSE-001',
    departmentId: 'dept_cse',
    departmentName: 'Computer Science & Engineering',
    designation: 'Department Head',
    role: AppStrings.roleDeptHead,
    approvalStatus: 'approved',
    isActive: true,
    createdAt: DateTime(2026, 1, 1),
  );

  final regUser = UserModel(
    uid: 'reg_1',
    email: 'registrar.lu@gmail.com',
    fullName: 'University Registrar',
    employeeId: 'REG-001',
    departmentId: 'registrar_office',
    departmentName: 'Office of the Registrar',
    designation: 'Registrar',
    role: AppStrings.roleRegistrar,
    approvalStatus: 'approved',
    isActive: true,
    createdAt: DateTime(2026, 1, 1),
  );

  group('Phase 20 Regression Suite', () {
    testWidgets('Save Draft persists, restores on reopen, and deletes cleanly', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        MaterialApp(
          home: ApplyLeaveScreen(
            authRepository: _FakeAuthRepo(facultyUser),
            leaveRepository: _FakeLeaveRepo(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter a reason and tap Save Draft bookmark button
      await tester.enterText(
        find.byType(TextFormField).first,
        'Persisted draft reason for seminar',
      );
      await tester.tap(find.byIcon(Icons.bookmark_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Application saved as draft'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);

      // Re-mount ApplyLeaveScreen cleanly -> draft must restore
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        MaterialApp(
          home: ApplyLeaveScreen(
            authRepository: _FakeAuthRepo(facultyUser),
            leaveRepository: _FakeLeaveRepo(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Persisted draft reason for seminar'),
        findsOneWidget,
      );

      // Delete draft
      await tester.tap(find.byTooltip('Delete Draft'));
      await tester.pumpAndSettle();
      expect(find.text('Draft deleted'), findsOneWidget);
      expect(find.byTooltip('Delete Draft'), findsNothing);
    });

    testWidgets('DeptCalendarScreen renders dynamic month, navigates months & opens notifications', (tester) async {
      final now = DateTime.now();
      final currentMonthLabel = DateFormat('MMMM yyyy').format(now);
      final nextMonthLabel = DateFormat('MMMM yyyy')
          .format(DateTime(now.year, now.month + 1, 1));

      final cseApp = LeaveApplicationModel(
        id: 'app_cal_1',
        applicantUid: 'fac_1',
        applicantName: 'Dr. Real CSE Faculty',
        applicantEmployeeId: 'CSE-101',
        departmentId: 'dept_cse',
        departmentName: 'Computer Science & Engineering',
        leaveTypeId: 'casual',
        leaveTypeName: 'Casual Leave',
        startDate: now,
        endDate: now,
        totalDays: 1,
        reason: 'Conference',
        status: 'approved',
        appliedAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            AppRoutes.notifications: (_) =>
                const Scaffold(body: Text('Notifications Screen')),
          },
          home: DeptCalendarScreen(
            authRepository: _FakeAuthRepo(cseHeadUser),
            leaveRepository: _FakeLeaveRepo([cseApp]),
            userRepository: _FakeUserRepo(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(currentMonthLabel), findsOneWidget);
      expect(find.text('September 2026'), findsNothing);
      expect(find.text('Dr. Real CSE Faculty'), findsOneWidget);

      await tester.tap(find.byTooltip('Next Month'));
      await tester.pumpAndSettle();
      expect(find.text(nextMonthLabel), findsOneWidget);

      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();
      expect(find.text('Notifications Screen'), findsOneWidget);
    });

    testWidgets('Faculty Profile copy actions copy email and phone to clipboard', (tester) async {
      String? copiedText;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText = (call.arguments as Map)['text'] as String?;
        }
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      FacultyProfileState.instance.updateProfile(
        email: 'faculty.cse@gmail.com',
        phone: '+8801711000000',
      );

      await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Copy Email'));
      await tester.pumpAndSettle();
      expect(copiedText, 'faculty.cse@gmail.com');

      await tester.tap(find.byTooltip('Copy Phone Number'));
      await tester.pumpAndSettle();
      expect(copiedText, '+8801711000000');
    });

    testWidgets('RegistrarDashboard notification shortcut navigates to Notifications screen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          routes: {
            AppRoutes.notifications: (_) =>
                const Scaffold(body: Text('Registrar Notifications')),
          },
          home: RegistrarDashboard(
            authRepository: _FakeAuthRepo(regUser),
            leaveRepository: _FakeLeaveRepo(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();
      expect(find.text('Registrar Notifications'), findsOneWidget);
    });
  });
}
