// ─────────────────────────────────────────────────────────────────────────────
//  firestore_query_migration_test.dart  –  Phase 11 Query Migration Tests
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';

import 'package:leavexa/core/constants/app_strings.dart';
import 'package:leavexa/models/leave_application_model.dart';
import 'package:leavexa/models/user_model.dart';
import 'package:leavexa/repositories/leave_repository.dart';
import 'package:leavexa/repositories/user_repository.dart';
import 'package:leavexa/services/firestore_service.dart';
import 'package:leavexa/services/leave_service.dart';
import 'package:leavexa/services/notification_service.dart';

/// Test fake for FirestoreService with full queryCollection filtering & sorting.
class MockFirestoreQueryService extends FirestoreService {
  final Map<String, Map<String, Map<String, dynamic>>> _db = {};
  int _idCounter = 1;

  void clear() => _db.clear();

  @override
  Future<String> addDocument(String collection, Map<String, dynamic> data) async {
    final docId = data['id'] as String? ?? 'doc_${_idCounter++}';
    _db.putIfAbsent(collection, () => {})[docId] = {
      'id': docId,
      ...Map<String, dynamic>.from(data),
    };
    return docId;
  }

  @override
  Future<void> setDocument(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    _db.putIfAbsent(collection, () => {})[docId] = {
      'id': docId,
      ...Map<String, dynamic>.from(data),
    };
  }

  @override
  Future<void> updateDocument(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    final col = _db[collection];
    if (col == null || !col.containsKey(docId)) {
      throw Exception('Document $docId not found in $collection');
    }
    col[docId]!.addAll(data);
  }

  @override
  Future<Map<String, dynamic>?> getDocument(
    String collection,
    String docId,
  ) async {
    final col = _db[collection];
    if (col == null || !col.containsKey(docId)) return null;
    return Map<String, dynamic>.from(col[docId]!);
  }

  @override
  Future<List<Map<String, dynamic>>> getCollection(String collection) async {
    final col = _db[collection];
    if (col == null) return [];
    return col.entries.map((e) => {...e.value, 'id': e.key}).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> queryCollection(
    String collection, {
    Map<String, Object?>? isEqualTo,
    String? orderBy,
    bool descending = false,
    int? limit,
  }) async {
    final all = await getCollection(collection);
    var filtered = all;
    if (isEqualTo != null) {
      filtered = filtered.where((doc) {
        for (final entry in isEqualTo.entries) {
          if (doc[entry.key] != entry.value) return false;
        }
        return true;
      }).toList();
    }
    if (orderBy != null) {
      filtered.sort((a, b) {
        final valA = a[orderBy];
        final valB = b[orderBy];
        if (valA == null || valB == null) return 0;
        final cmp = Comparable.compare(valA as Comparable, valB as Comparable);
        return descending ? -cmp : cmp;
      });
    }
    if (limit != null && filtered.length > limit) {
      filtered = filtered.sublist(0, limit);
    }
    return filtered;
  }
}

void main() {
  late MockFirestoreQueryService fakeDb;
  late LeaveService leaveService;
  late LeaveRepository leaveRepo;
  late UserRepository userRepo;
  late NotificationService notifService;

  setUp(() {
    fakeDb = MockFirestoreQueryService();
    leaveService = LeaveService(firestore: fakeDb);
    leaveRepo = LeaveRepository(leaveService: leaveService, firestore: fakeDb);
    userRepo = UserRepository(firestore: fakeDb);
    notifService = NotificationService(firestore: fakeDb);
  });

  group('LeaveService & LeaveRepository Firestore Queries', () {
    test('getApplicationsByUser returns only the matching applicant applications', () async {
      final app1 = LeaveApplicationModel(
        id: 'app_1',
        applicantUid: 'user_A',
        applicantName: 'Prof. Alice',
        applicantEmployeeId: 'EMP-001',
        departmentId: 'dept_cse',
        departmentName: 'Computer Science',
        leaveTypeId: 'annual',
        leaveTypeName: 'Annual Leave',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 2)),
        totalDays: 2,
        reason: 'Personal family event',
        status: 'pending',
        appliedAt: DateTime.now(),
      );

      final app2 = LeaveApplicationModel(
        id: 'app_2',
        applicantUid: 'user_B',
        applicantName: 'Dr. Bob',
        applicantEmployeeId: 'EMP-002',
        departmentId: 'dept_cse',
        departmentName: 'Computer Science',
        leaveTypeId: 'sick',
        leaveTypeName: 'Sick Leave',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 1)),
        totalDays: 1,
        reason: 'Flu symptoms',
        status: 'pending',
        appliedAt: DateTime.now(),
      );

      await leaveService.submitApplication(app1);
      await leaveService.submitApplication(app2);

      final userALeaves = await leaveRepo.myApplications('user_A');
      expect(userALeaves.length, 1);
      expect(userALeaves.first.applicantUid, 'user_A');
      expect(userALeaves.first.applicantName, 'Prof. Alice');

      final userBLeaves = await leaveRepo.myApplications('user_B');
      expect(userBLeaves.length, 1);
      expect(userBLeaves.first.applicantUid, 'user_B');
    });

    test('getPendingForDepartment isolates department leaves and ignores other statuses', () async {
      final appDeptCse = LeaveApplicationModel(
        id: 'cse_app',
        applicantUid: 'user_A',
        applicantName: 'Prof. Alice',
        applicantEmployeeId: 'EMP-001',
        departmentId: 'dept_cse',
        departmentName: 'Computer Science',
        leaveTypeId: 'annual',
        leaveTypeName: 'Annual Leave',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 2)),
        totalDays: 2,
        reason: 'Conference travel',
        status: 'pending',
        appliedAt: DateTime.now(),
      );

      final appDeptEee = LeaveApplicationModel(
        id: 'eee_app',
        applicantUid: 'user_C',
        applicantName: 'Dr. Charlie',
        applicantEmployeeId: 'EMP-003',
        departmentId: 'dept_eee',
        departmentName: 'Electrical Engineering',
        leaveTypeId: 'annual',
        leaveTypeName: 'Annual Leave',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 3)),
        totalDays: 3,
        reason: 'Research visit',
        status: 'pending',
        appliedAt: DateTime.now(),
      );

      final appApprovedCse = LeaveApplicationModel(
        id: 'cse_app_approved',
        applicantUid: 'user_D',
        applicantName: 'Dr. David',
        applicantEmployeeId: 'EMP-004',
        departmentId: 'dept_cse',
        departmentName: 'Computer Science',
        leaveTypeId: 'casual',
        leaveTypeName: 'Casual Leave',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 1)),
        totalDays: 1,
        reason: 'Emergency',
        status: 'approved',
        appliedAt: DateTime.now(),
      );

      await leaveService.submitApplication(appDeptCse);
      await leaveService.submitApplication(appDeptEee);
      await leaveService.submitApplication(appApprovedCse);

      final csePending = await leaveRepo.departmentPending('dept_cse');
      expect(csePending.length, 1);
      expect(csePending.first.id, 'cse_app');
      expect(csePending.first.departmentId, 'dept_cse');
      expect(csePending.first.status, 'pending');

      final eeePending = await leaveRepo.departmentPending('dept_eee');
      expect(eeePending.length, 1);
      expect(eeePending.first.id, 'eee_app');
    });

    test('getForwardedApplications returns all and only applications with status == forwarded', () async {
      final appPending = LeaveApplicationModel(
        id: 'app_pending',
        applicantUid: 'user_A',
        applicantName: 'Prof. Alice',
        applicantEmployeeId: 'EMP-001',
        departmentId: 'dept_cse',
        departmentName: 'Computer Science',
        leaveTypeId: 'annual',
        leaveTypeName: 'Annual Leave',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 2)),
        totalDays: 2,
        reason: 'Vacation',
        status: 'pending',
        appliedAt: DateTime.now(),
      );

      final appForwarded = LeaveApplicationModel(
        id: 'app_forwarded',
        applicantUid: 'user_B',
        applicantName: 'Dr. Bob',
        applicantEmployeeId: 'EMP-002',
        departmentId: 'dept_eee',
        departmentName: 'Electrical Engineering',
        leaveTypeId: 'sick',
        leaveTypeName: 'Sick Leave',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 3)),
        totalDays: 3,
        reason: 'Medical Leave',
        status: 'forwarded',
        appliedAt: DateTime.now(),
      );

      await leaveService.submitApplication(appPending);
      await leaveService.submitApplication(appForwarded);

      final forwarded = await leaveRepo.forwardedAll();
      expect(forwarded.length, 1);
      expect(forwarded.first.id, 'app_forwarded');
      expect(forwarded.first.status, 'forwarded');
    });

    test('headRejectLeave updates status to rejected with headUid and headComment', () async {
      final app = LeaveApplicationModel(
        id: 'app_head_rej',
        applicantUid: 'user_A',
        applicantName: 'Prof. Alice',
        applicantEmployeeId: 'EMP-001',
        departmentId: 'dept_cse',
        departmentName: 'Computer Science',
        leaveTypeId: 'casual',
        leaveTypeName: 'Casual Leave',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 1)),
        totalDays: 1,
        reason: 'Personal',
        status: 'pending',
        appliedAt: DateTime.now(),
      );

      await leaveService.submitApplication(app);
      await leaveRepo.headRejectLeave(
        applicationId: 'app_head_rej',
        headUid: 'head_uid_101',
        comment: 'Examinations scheduled on this date',
      );

      final updated = await leaveRepo.getApplicationById('app_head_rej');
      expect(updated, isNotNull);
      expect(updated!.status, 'rejected');
      expect(updated.headUid, 'head_uid_101');
      expect(updated.headComment, 'Examinations scheduled on this date');
      expect(updated.headActionAt, isNotNull);
    });

    test('takeAction executes Registrar final approval or rejection on forwarded applications', () async {
      final app = LeaveApplicationModel(
        id: 'app_reg_action',
        applicantUid: 'user_A',
        applicantName: 'Prof. Alice',
        applicantEmployeeId: 'EMP-001',
        departmentId: 'dept_cse',
        departmentName: 'Computer Science',
        leaveTypeId: 'annual',
        leaveTypeName: 'Annual Leave',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 5)),
        totalDays: 5,
        reason: 'Annual family holiday',
        status: 'forwarded',
        appliedAt: DateTime.now(),
      );

      await leaveService.submitApplication(app);

      // Registrar approves
      await leaveRepo.takeAction(
        applicationId: 'app_reg_action',
        registrarUid: 'reg_uid_999',
        isApproved: true,
        comment: 'Final approval granted by Registrar',
      );

      final approvedDoc = await leaveRepo.getApplicationById('app_reg_action');
      expect(approvedDoc!.status, 'approved');
      expect(approvedDoc.registrarUid, 'reg_uid_999');
      expect(approvedDoc.registrarComment, 'Final approval granted by Registrar');
      expect(approvedDoc.registrarActionAt, isNotNull);
    });

    test('cancelLeave allows applicant to cancel their own pending application', () async {
      final app = LeaveApplicationModel(
        id: 'app_cancel_test',
        applicantUid: 'user_cancel_1',
        applicantName: 'Prof. Cancel',
        applicantEmployeeId: 'EMP-007',
        departmentId: 'dept_cse',
        departmentName: 'Computer Science',
        leaveTypeId: 'casual',
        leaveTypeName: 'Casual Leave',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 2)),
        totalDays: 2,
        reason: 'Personal matters',
        status: 'pending',
        appliedAt: DateTime.now(),
      );

      await leaveService.submitApplication(app);

      // Cancel
      await leaveRepo.cancelLeave(
        applicationId: 'app_cancel_test',
        applicantUid: 'user_cancel_1',
        reason: 'Conference rescheduled',
      );

      final cancelledDoc = await leaveRepo.getApplicationById('app_cancel_test');
      expect(cancelledDoc!.status, 'cancelled');
      expect(cancelledDoc.isCancelled, isTrue);
      expect(cancelledDoc.cancelledAt, isNotNull);
      expect(cancelledDoc.cancelReason, 'Conference rescheduled');
    });

    test('cancelLeave rejects cancellation when not applicant or not pending', () async {
      final app = LeaveApplicationModel(
        id: 'app_cancel_guard',
        applicantUid: 'user_owner',
        applicantName: 'Prof. Owner',
        applicantEmployeeId: 'EMP-008',
        departmentId: 'dept_cse',
        departmentName: 'Computer Science',
        leaveTypeId: 'casual',
        leaveTypeName: 'Casual Leave',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 2)),
        totalDays: 2,
        reason: 'Personal matters',
        status: 'forwarded', // Already forwarded
        appliedAt: DateTime.now(),
      );

      await leaveService.submitApplication(app);

      // 1. Non-applicant rejection
      expect(
        () => leaveRepo.cancelLeave(
          applicationId: 'app_cancel_guard',
          applicantUid: 'intruder_uid',
        ),
        throwsA(isA<Exception>()),
      );

      // 2. Non-pending rejection
      expect(
        () => leaveRepo.cancelLeave(
          applicationId: 'app_cancel_guard',
          applicantUid: 'user_owner',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('UserRepository Admin Operations & Queries', () {
    test('getPendingFaculty queries role == faculty and approvalStatus == pending', () async {
      final faculty1 = UserModel(
        uid: 'fac_1',
        fullName: 'Dr. Pending One',
        email: 'one@uni.edu',
        employeeId: 'EMP-001',
        departmentId: 'dept_cse',
        departmentName: 'Computer Science',
        designation: 'Assistant Professor',
        role: AppStrings.roleFaculty,
        isActive: false,
        approvalStatus: 'pending',
        createdAt: DateTime.now(),
      );

      final faculty2 = UserModel(
        uid: 'fac_2',
        fullName: 'Prof. Approved Two',
        email: 'two@uni.edu',
        employeeId: 'EMP-002',
        departmentId: 'dept_eee',
        departmentName: 'Electrical Engineering',
        designation: 'Professor',
        role: AppStrings.roleFaculty,
        isActive: true,
        approvalStatus: 'approved',
        createdAt: DateTime.now(),
      );

      await userRepo.createUser(faculty1);
      await userRepo.createUser(faculty2);

      final pending = await userRepo.getPendingFaculty();
      expect(pending.length, 1);
      expect(pending.first.uid, 'fac_1');
      expect(pending.first.approvalStatus, 'pending');

      final allFaculty = await userRepo.getAllFaculty();
      expect(allFaculty.length, 2);
    });

    test('approveFaculty and rejectFaculty update user state accurately', () async {
      final faculty = UserModel(
        uid: 'fac_test',
        fullName: 'Candidate Test',
        email: 'test@uni.edu',
        employeeId: 'EMP-TEST',
        departmentId: 'dept_phy',
        departmentName: 'Physics',
        designation: 'Lecturer',
        role: AppStrings.roleFaculty,
        isActive: false,
        approvalStatus: 'pending',
        createdAt: DateTime.now(),
      );

      await userRepo.createUser(faculty);

      // Approve
      await userRepo.approveFaculty('fac_test');
      var user = await userRepo.getUserById('fac_test');
      expect(user!.approvalStatus, 'approved');
      expect(user.isActive, true);

      // Reject
      await userRepo.rejectFaculty('fac_test');
      user = await userRepo.getUserById('fac_test');
      expect(user!.approvalStatus, 'rejected');
      expect(user.isActive, false);
    });
  });

  group('NotificationService Firestore Queries', () {
    test('getForUser queries recipientUid and returns ordered notifications', () async {
      await notifService.send(
        recipientUid: 'user_X',
        title: 'Application Approved',
        body: 'Your leave application was approved',
        type: 'approval',
      );

      await notifService.send(
        recipientUid: 'user_Y',
        title: 'Other User Notice',
        body: 'Not for user X',
        type: 'info',
      );

      final userXNotifs = await notifService.getForUser('user_X');
      expect(userXNotifs.length, 1);
      expect(userXNotifs.first.recipientUid, 'user_X');
      expect(userXNotifs.first.title, 'Application Approved');
      expect(userXNotifs.first.isRead, false);

      // Mark read
      await notifService.markRead(userXNotifs.first.id);
      final updated = await notifService.getForUser('user_X');
      expect(updated.first.isRead, true);
    });
  });
}
