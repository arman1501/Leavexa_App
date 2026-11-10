import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leavexa/models/leave_application_model.dart';
import 'package:leavexa/models/leave_balance_model.dart';
import 'package:leavexa/models/notification_model.dart';
import 'package:leavexa/models/user_model.dart';
import 'package:leavexa/repositories/auth_repository.dart';
import 'package:leavexa/repositories/leave_repository.dart';
import 'package:leavexa/screens/faculty/faculty_dashboard.dart';
import 'package:leavexa/services/notification_service.dart';

class MockLeaveRepository extends LeaveRepository {
  List<LeaveBalanceModel> balances = [];

  @override
  Future<List<LeaveBalanceModel>> balancesForUser(String uid) async {
    return balances;
  }

  @override
  Future<List<LeaveApplicationModel>> myApplications(String uid) async {
    return [];
  }
}

class MockAuthRepository extends AuthRepository {
  UserModel? mockUser;

  @override
  String? get currentUserId => mockUser?.uid ?? 'test_uid_faculty';

  @override
  Future<UserModel?> getCurrentUserProfile() async => mockUser;
}

class MockNotificationService extends NotificationService {
  @override
  Future<List<NotificationModel>> getForUser(String uid) async => [];
}

void main() {
  final testUser = UserModel(
    uid: 'faculty_uid_101',
    email: 'faculty@leavexa.edu',
    fullName: 'Dr. Jane Smith',
    employeeId: 'EMP-F101',
    role: 'faculty',
    departmentId: 'dept_cse',
    departmentName: 'Computer Science & Engineering',
    designation: 'Assistant Professor',
    approvalStatus: 'approved',
    createdAt: DateTime.now(),
  );

  testWidgets(
      'Faculty Dashboard displays Casual, Medical, and Earned Leave cards with default days',
      (tester) async {
    final mockAuth = MockAuthRepository()..mockUser = testUser;
    final mockLeave = MockLeaveRepository();
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
    await tester.pumpAndSettle();

    expect(find.text('Casual Leave'), findsWidgets);
    expect(find.text('Medical Leave'), findsOneWidget);
    expect(find.text('Earned Leave'), findsOneWidget);
    expect(find.text('Duty Leave'), findsWidgets);
    expect(find.text('Station Leave'), findsWidgets);
    expect(find.text('Study Leave'), findsWidgets);

    // Default remaining days: Casual (10), Medical (14), Earned (30)
    expect(find.text('10'), findsWidgets);
    expect(find.text('14'), findsOneWidget);
    expect(find.text('30'), findsWidgets);
  });

  testWidgets(
      'Real Firestore balances and legacy sick leave mapping are correctly loaded',
      (tester) async {
    final mockAuth = MockAuthRepository()..mockUser = testUser;
    final mockLeave = MockLeaveRepository();
    final mockNotif = MockNotificationService();

    mockLeave.balances = [
      const LeaveBalanceModel(
        id: 'bal_1',
        userUid: 'faculty_uid_101',
        leaveTypeId: 'casual',
        leaveTypeName: 'Casual Leave',
        totalAllotted: 10,
        used: 3,
        year: 2026,
      ),
      // Legacy sick leave mapping to Medical
      const LeaveBalanceModel(
        id: 'bal_2',
        userUid: 'faculty_uid_101',
        leaveTypeId: 'sick',
        leaveTypeName: 'Sick Leave',
        totalAllotted: 14,
        used: 4,
        year: 2026,
      ),
      const LeaveBalanceModel(
        id: 'bal_3',
        userUid: 'faculty_uid_101',
        leaveTypeId: 'earned',
        leaveTypeName: 'Earned Leave',
        totalAllotted: 30,
        used: 10,
        year: 2026,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: FacultyDashboard(
          authRepository: mockAuth,
          leaveRepository: mockLeave,
          notificationService: mockNotif,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Casual: 10 - 3 = 7 remaining
    expect(find.text('7'), findsOneWidget);
    expect(find.text('3 used of 10'), findsOneWidget);

    // Medical (mapped from Sick): 14 - 4 = 10 remaining
    expect(find.text('10'), findsWidgets);
    expect(find.text('4 used of 14'), findsOneWidget);

    // Earned: 30 - 10 = 20 remaining
    expect(find.text('20'), findsOneWidget);
    expect(find.text('10 used of 30'), findsOneWidget);
  });

  testWidgets('Zero balance is safely handled and displays 0 days and used of total',
      (tester) async {
    final mockAuth = MockAuthRepository()..mockUser = testUser;
    final mockLeave = MockLeaveRepository();
    final mockNotif = MockNotificationService();

    mockLeave.balances = [
      const LeaveBalanceModel(
        id: 'bal_casual_zero',
        userUid: 'faculty_uid_101',
        leaveTypeId: 'casual',
        leaveTypeName: 'Casual Leave',
        totalAllotted: 10,
        used: 10, // All 10 used
        year: 2026,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: FacultyDashboard(
          authRepository: mockAuth,
          leaveRepository: mockLeave,
          notificationService: mockNotif,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('0'), findsWidgets);
    expect(find.text('10 used of 10'), findsOneWidget);
  });
}
