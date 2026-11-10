// ─────────────────────────────────────────────────────────────────────────────
//  leave_approval_workflow_test.dart  –  End-to-End Workflow Tests (Phase 9)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';

import 'package:leavexa/core/constants/app_constants.dart';
import 'package:leavexa/models/leave_application_model.dart';
import 'package:leavexa/repositories/leave_repository.dart';
import 'package:leavexa/services/firestore_service.dart';
import 'package:leavexa/services/leave_service.dart';

/// In-memory fake implementation of [FirestoreService] for workflow testing.
class FakeFirestoreWorkflowService extends FirestoreService {
  final Map<String, Map<String, Map<String, dynamic>>> _db = {};
  int _autoIdCounter = 1;

  void clear() => _db.clear();

  @override
  Future<String> addDocument(
    String collection,
    Map<String, dynamic> data,
  ) async {
    final docId = 'app_${_autoIdCounter++}';
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
  late FakeFirestoreWorkflowService fakeFirestore;
  late LeaveService leaveService;
  late LeaveRepository leaveRepository;

  setUp(() {
    fakeFirestore = FakeFirestoreWorkflowService();
    leaveService = LeaveService(firestore: fakeFirestore);
    leaveRepository = LeaveRepository(
      leaveService: leaveService,
      firestore: fakeFirestore,
    );
  });

  group('Leave Approval Complete Flow (Happy Path)', () {
    test(
      'Faculty submits -> Head forwards -> Registrar approves -> Faculty receives final status',
      () async {
        // Step 1: Faculty submits application
        final newApp = LeaveApplicationModel(
          id: '',
          applicantUid: 'faculty_101',
          applicantName: 'Dr. Jane Doe',
          applicantEmployeeId: 'FAC-101',
          departmentId: 'dept_cse',
          departmentName: 'Computer Science & Engineering',
          leaveTypeId: 'casual_leave',
          leaveTypeName: 'Casual Leave',
          startDate: DateTime(2025, 2, 10),
          endDate: DateTime(2025, 2, 12),
          totalDays: 3,
          reason: 'Attending IEEE conference',
          status: 'pending',
          appliedAt: DateTime(2025, 2, 1),
        );

        final appId = await leaveRepository.applyLeave(newApp);
        expect(appId, isNotEmpty);

        // Verify status is pending
        final storedAfterSubmit = await fakeFirestore.getDocument(
          AppConstants.applicationsCollection,
          appId,
        );
        expect(storedAfterSubmit!['status'], 'pending');
        expect(storedAfterSubmit['applicantUid'], 'faculty_101');
        expect(storedAfterSubmit['headUid'], isNull);

        // Step 2: Department Head reviews and forwards
        await leaveRepository.forwardLeave(
          applicationId: appId,
          headUid: 'head_cse_001',
          comment: 'Recommended. Workload covered by TA.',
        );

        final storedAfterForward = await fakeFirestore.getDocument(
          AppConstants.applicationsCollection,
          appId,
        );
        expect(storedAfterForward!['status'], 'forwarded');
        expect(storedAfterForward['headUid'], 'head_cse_001');
        expect(
          storedAfterForward['headComment'],
          'Recommended. Workload covered by TA.',
        );
        expect(storedAfterForward['headActionAt'], isNotNull);
        expect(storedAfterForward['registrarUid'], isNull);

        // Step 3: Registrar reviews forwarded applications and grants final approval
        final forwardedList = await leaveRepository.forwardedAll();
        expect(forwardedList.length, 1);
        expect(forwardedList.first.id, appId);

        await leaveRepository.takeAction(
          applicationId: appId,
          registrarUid: 'registrar_admin_01',
          isApproved: true,
          comment: 'Approved in accordance with academic policy.',
        );

        // Step 4: Faculty checks application status
        final facultyApplications = await leaveRepository.myApplications(
          'faculty_101',
        );
        expect(facultyApplications.length, 1);
        final finalApp = facultyApplications.first;

        expect(finalApp.status, 'approved');
        expect(finalApp.headUid, 'head_cse_001');
        expect(finalApp.headComment, 'Recommended. Workload covered by TA.');
        expect(finalApp.registrarUid, 'registrar_admin_01');
        expect(
          finalApp.registrarComment,
          'Approved in accordance with academic policy.',
        );
        expect(finalApp.registrarActionAt, isNotNull);
      },
    );
  });

  group('Department Head Rejection Flow', () {
    test('Faculty submits -> Head rejects application', () async {
      final app = LeaveApplicationModel(
        id: '',
        applicantUid: 'faculty_102',
        applicantName: 'Dr. John Smith',
        applicantEmployeeId: 'FAC-102',
        departmentId: 'dept_eee',
        departmentName: 'Electrical Engineering',
        leaveTypeId: 'casual_leave',
        leaveTypeName: 'Casual Leave',
        startDate: DateTime(2025, 3, 1),
        endDate: DateTime(2025, 3, 5),
        totalDays: 5,
        reason: 'Personal travel',
        status: 'pending',
        appliedAt: DateTime(2025, 2, 20),
      );

      final appId = await leaveRepository.applyLeave(app);

      // Head rejects
      await fakeFirestore
          .updateDocument(AppConstants.applicationsCollection, appId, {
            'status': 'rejected',
            'headUid': 'head_eee_001',
            'headComment':
                'Mid-term examinations scheduled. Leave not permitted.',
            'headActionAt': DateTime.now().toIso8601String(),
          });

      final stored = await fakeFirestore.getDocument(
        AppConstants.applicationsCollection,
        appId,
      );
      expect(stored!['status'], 'rejected');
      expect(stored['headUid'], 'head_eee_001');
      expect(stored['registrarUid'], isNull);

      // Ensure it does NOT appear in forwarded applications for Registrar
      final forwardedList = await leaveRepository.forwardedAll();
      expect(forwardedList.isEmpty, isTrue);

      // Faculty sees rejected status
      final facultyApps = await leaveRepository.myApplications('faculty_102');
      expect(facultyApps.first.status, 'rejected');
    });
  });

  group('Registrar Rejection Flow', () {
    test('Faculty submits -> Head forwards -> Registrar rejects', () async {
      final app = LeaveApplicationModel(
        id: '',
        applicantUid: 'faculty_103',
        applicantName: 'Prof. Alice Green',
        applicantEmployeeId: 'FAC-103',
        departmentId: 'dept_math',
        departmentName: 'Mathematics',
        leaveTypeId: 'study_leave',
        leaveTypeName: 'Study Leave',
        startDate: DateTime(2025, 4, 1),
        endDate: DateTime(2025, 4, 30),
        totalDays: 30,
        reason: 'Research visit',
        status: 'pending',
        appliedAt: DateTime(2025, 2, 25),
      );

      final appId = await leaveRepository.applyLeave(app);

      // Head forwards
      await leaveRepository.forwardLeave(
        applicationId: appId,
        headUid: 'head_math_001',
        comment: 'Forwarded for administrative review.',
      );

      // Registrar rejects
      await leaveRepository.takeAction(
        applicationId: appId,
        registrarUid: 'registrar_admin_01',
        isApproved: false,
        comment: 'Insufficient earned study balance.',
      );

      final stored = await fakeFirestore.getDocument(
        AppConstants.applicationsCollection,
        appId,
      );
      expect(stored!['status'], 'rejected');
      expect(stored['headUid'], 'head_math_001');
      expect(stored['registrarUid'], 'registrar_admin_01');
      expect(stored['registrarComment'], 'Insufficient earned study balance.');
    });
  });

  group('Workflow Isolation & Department Partitioning', () {
    test(
      'Department Head only sees pending applications from own department',
      () async {
        // Application from CSE
        await leaveRepository.applyLeave(
          LeaveApplicationModel(
            id: '',
            applicantUid: 'faculty_cse_1',
            applicantName: 'CSE Faculty',
            applicantEmployeeId: 'CSE-01',
            departmentId: 'dept_cse',
            departmentName: 'CSE',
            leaveTypeId: 'casual_leave',
            leaveTypeName: 'Casual Leave',
            startDate: DateTime(2025, 3, 1),
            endDate: DateTime(2025, 3, 2),
            totalDays: 2,
            reason: 'Reason 1',
            status: 'pending',
            appliedAt: DateTime(2025, 2, 28),
          ),
        );

        // Application from EEE
        await leaveRepository.applyLeave(
          LeaveApplicationModel(
            id: '',
            applicantUid: 'faculty_eee_1',
            applicantName: 'EEE Faculty',
            applicantEmployeeId: 'EEE-01',
            departmentId: 'dept_eee',
            departmentName: 'EEE',
            leaveTypeId: 'casual_leave',
            leaveTypeName: 'Casual Leave',
            startDate: DateTime(2025, 3, 1),
            endDate: DateTime(2025, 3, 2),
            totalDays: 2,
            reason: 'Reason 2',
            status: 'pending',
            appliedAt: DateTime(2025, 2, 28),
          ),
        );

        // CSE Head queries pending for dept_cse
        final csePending = await leaveRepository.departmentPending('dept_cse');
        expect(csePending.length, 1);
        expect(csePending.first.departmentId, 'dept_cse');
        expect(csePending.first.applicantName, 'CSE Faculty');

        // EEE Head queries pending for dept_eee
        final eeePending = await leaveRepository.departmentPending('dept_eee');
        expect(eeePending.length, 1);
        expect(eeePending.first.departmentId, 'dept_eee');
        expect(eeePending.first.applicantName, 'EEE Faculty');
      },
    );

    test(
      'Applicant cannot see applications of other faculty members',
      () async {
        await leaveRepository.applyLeave(
          LeaveApplicationModel(
            id: '',
            applicantUid: 'faculty_A',
            applicantName: 'Faculty A',
            applicantEmployeeId: 'A-01',
            departmentId: 'dept_cse',
            departmentName: 'CSE',
            leaveTypeId: 'casual_leave',
            leaveTypeName: 'Casual Leave',
            startDate: DateTime(2025, 3, 1),
            endDate: DateTime(2025, 3, 2),
            totalDays: 2,
            reason: 'Reason A',
            status: 'pending',
            appliedAt: DateTime(2025, 2, 28),
          ),
        );

        await leaveRepository.applyLeave(
          LeaveApplicationModel(
            id: '',
            applicantUid: 'faculty_B',
            applicantName: 'Faculty B',
            applicantEmployeeId: 'B-01',
            departmentId: 'dept_cse',
            departmentName: 'CSE',
            leaveTypeId: 'casual_leave',
            leaveTypeName: 'Casual Leave',
            startDate: DateTime(2025, 3, 1),
            endDate: DateTime(2025, 3, 2),
            totalDays: 2,
            reason: 'Reason B',
            status: 'pending',
            appliedAt: DateTime(2025, 2, 28),
          ),
        );

        final userAApps = await leaveRepository.myApplications('faculty_A');
        expect(userAApps.length, 1);
        expect(userAApps.first.applicantUid, 'faculty_A');

        final userBApps = await leaveRepository.myApplications('faculty_B');
        expect(userBApps.length, 1);
        expect(userBApps.first.applicantUid, 'faculty_B');
      },
    );
  });
}
