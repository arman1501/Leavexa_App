// ─────────────────────────────────────────────────────────────────────────────
//  leave_repository.dart
// ─────────────────────────────────────────────────────────────────────────────

import '../models/leave_application_model.dart';
import '../models/leave_balance_model.dart';
import '../services/leave_service.dart';
import '../services/firestore_service.dart';
import '../core/constants/app_constants.dart';

class LeaveRepository {
  final LeaveService _leaveService;
  final FirestoreService _firestore;

  LeaveRepository({LeaveService? leaveService, FirestoreService? firestore})
    : _leaveService = leaveService ?? LeaveService(),
      _firestore = firestore ?? FirestoreService();

  Future<String> applyLeave(LeaveApplicationModel application) =>
      _leaveService.submitApplication(application);

  Future<void> cancelLeave({
    required String applicationId,
    required String applicantUid,
    String? reason,
  }) => _leaveService.cancelApplication(
    applicationId: applicationId,
    applicantUid: applicantUid,
    reason: reason,
  );

  Future<void> forwardLeave({
    required String applicationId,
    required String headUid,
    required String comment,
  }) => _leaveService.forwardApplication(
    applicationId: applicationId,
    headUid: headUid,
    comment: comment,
  );

  Future<void> headRejectLeave({
    required String applicationId,
    required String headUid,
    required String comment,
  }) => _leaveService.headRejectApplication(
    applicationId: applicationId,
    headUid: headUid,
    comment: comment,
  );

  Future<void> takeAction({
    required String applicationId,
    required String registrarUid,
    required bool isApproved,
    required String comment,
  }) => _leaveService.finalAction(
    applicationId: applicationId,
    registrarUid: registrarUid,
    isApproved: isApproved,
    comment: comment,
  );

  Future<List<LeaveApplicationModel>> myApplications(String uid) =>
      _leaveService.getApplicationsByUser(uid);

  Stream<List<LeaveApplicationModel>> streamMyApplications(String uid) =>
      _leaveService.streamApplicationsByUser(uid);

  Future<List<LeaveApplicationModel>> departmentPending(String deptId) =>
      _leaveService.getPendingForDepartment(deptId);

  Stream<List<LeaveApplicationModel>> streamDepartmentPending(String deptId) =>
      _leaveService.streamPendingForDepartment(deptId);

  Future<List<LeaveApplicationModel>> forwardedAll() =>
      _leaveService.getForwardedApplications();

  Stream<List<LeaveApplicationModel>> streamForwardedAll() =>
      _leaveService.streamForwardedApplications();

  Future<LeaveApplicationModel?> getApplicationById(String id) async {
    final doc = await _firestore.getDocument(
      AppConstants.applicationsCollection,
      id,
    );
    if (doc == null) return null;
    return LeaveApplicationModel.fromMap({...doc, 'id': id});
  }

  Future<List<LeaveBalanceModel>> balancesForUser(String uid) async {
    final data = await _firestore.queryCollection(
      AppConstants.balancesCollection,
      isEqualTo: {'userUid': uid},
    );
    return data.map((m) => LeaveBalanceModel.fromMap(m)).toList();
  }

  Stream<List<LeaveBalanceModel>> streamBalancesForUser(String uid) {
    return _firestore
        .streamCollection(
          AppConstants.balancesCollection,
          isEqualTo: {'userUid': uid},
        )
        .map((list) => list.map((m) => LeaveBalanceModel.fromMap(m)).toList());
  }
}
