import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leavexa/models/leave_application_model.dart';
import 'package:leavexa/repositories/leave_repository.dart';
import 'package:leavexa/screens/faculty/leave_details_screen.dart';

class MockLeaveRepository extends LeaveRepository {
  bool cancelCalled = false;
  String? cancelledAppId;
  String? cancelledUid;
  String? cancelledReason;
  bool shouldThrow = false;
  LeaveApplicationModel? fetchedApp;

  @override
  Future<void> cancelLeave({
    required String applicationId,
    required String applicantUid,
    String? reason,
  }) async {
    if (shouldThrow) {
      throw Exception('Cancellation network timeout');
    }
    cancelCalled = true;
    cancelledAppId = applicationId;
    cancelledUid = applicantUid;
    cancelledReason = reason;
  }

  @override
  Future<LeaveApplicationModel?> getApplicationById(String id) async {
    return fetchedApp;
  }
}

void main() {
  LeaveApplicationModel createApp({
    required String status,
    String id = 'app_123',
    String applicantUid = 'faculty_uid_1',
  }) {
    return LeaveApplicationModel(
      id: id,
      applicantUid: applicantUid,
      applicantName: 'Dr. Jane Doe',
      applicantEmployeeId: 'EMP-001',
      departmentId: 'dept_cse',
      departmentName: 'Computer Science',
      leaveTypeId: 'casual',
      leaveTypeName: 'Casual Leave',
      startDate: DateTime.now().add(const Duration(days: 2)),
      endDate: DateTime.now().add(const Duration(days: 4)),
      totalDays: 3,
      reason: 'Attending family program',
      status: status,
      appliedAt: DateTime.now().subtract(const Duration(hours: 4)),
    );
  }

  testWidgets(
      'Cancel button is displayed when leave status is pending',
      (tester) async {
    final mockRepo = MockLeaveRepository();
    final app = createApp(status: 'pending');

    await tester.pumpWidget(
      MaterialApp(
        home: LeaveDetailsScreen(
          application: app,
          leaveRepository: mockRepo,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cancel_leave_button')), findsOneWidget);
    expect(find.text('Cancel Leave Request'), findsOneWidget);
  });

  testWidgets(
      'Cancel button is NOT displayed when status is forwarded, approved, or rejected',
      (tester) async {
    final mockRepo = MockLeaveRepository();

    for (final st in ['forwarded', 'approved', 'rejected', 'cancelled']) {
      final app = createApp(status: st);
      await tester.pumpWidget(
        MaterialApp(
          home: LeaveDetailsScreen(
            application: app,
            leaveRepository: mockRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cancel_leave_button')), findsNothing);
    }
  });

  testWidgets(
      'Tapping Cancel button shows confirmation dialog and confirms cancellation',
      (tester) async {
    final mockRepo = MockLeaveRepository();
    final app = createApp(status: 'pending');
    mockRepo.fetchedApp = createApp(status: 'cancelled');

    await tester.pumpWidget(
      MaterialApp(
        home: LeaveDetailsScreen(
          application: app,
          leaveRepository: mockRepo,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Scroll to and tap Cancel
    await tester.ensureVisible(find.byKey(const Key('cancel_leave_button')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('cancel_leave_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cancel_leave_button')));
    await tester.pumpAndSettle();

    // Verify dialog content
    expect(find.text('Cancel Leave Request'), findsNWidgets(2)); // Button + Dialog title
    expect(find.byKey(const Key('confirm_cancel_button')), findsOneWidget);

    // Enter optional reason
    await tester.enterText(
      find.byKey(const Key('cancel_reason_field')),
      'Family plans changed',
    );
    await tester.pumpAndSettle();

    // Confirm cancel
    await tester.tap(find.byKey(const Key('confirm_cancel_button')));
    await tester.pumpAndSettle();

    expect(mockRepo.cancelCalled, isTrue);
    expect(mockRepo.cancelledAppId, 'app_123');
    expect(mockRepo.cancelledUid, 'faculty_uid_1');
    expect(mockRepo.cancelledReason, 'Family plans changed');
    expect(find.text('Leave request cancelled successfully.'), findsOneWidget);
  });

  testWidgets('Cancel button displays error SnackBar when repository throws',
      (tester) async {
    final mockRepo = MockLeaveRepository();
    mockRepo.shouldThrow = true;
    final app = createApp(status: 'pending');

    await tester.pumpWidget(
      MaterialApp(
        home: LeaveDetailsScreen(
          application: app,
          leaveRepository: mockRepo,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('cancel_leave_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cancel_leave_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirm_cancel_button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Failed to cancel request'), findsOneWidget);
  });
}
