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

  LeaveRepository({
    LeaveService? leaveService,
    FirestoreService? firestore,
  })  : _leaveService = leaveService ?? LeaveService(),
        _firestore = firestore ?? FirestoreService();

  Future<String> applyLeave(LeaveApplicationModel application) =>
      _leaveService.submitApplication(application);

  Future<void> forwardLeave({
    required String applicationId,
    required String headUid,
    required String comment,
  }) =>
      _leaveService.forwardApplication(
        applicationId: applicationId,
        headUid: headUid,
        comment: comment,
      );

  Future<void> takeAction({
    required String applicationId,
    required String registrarUid,
    required bool isApproved,
    required String comment,
  }) =>
      _leaveService.finalAction(
        applicationId: applicationId,
        registrarUid: registrarUid,
        isApproved: isApproved,
        comment: comment,
      );

  Future<List<LeaveApplicationModel>> myApplications(String uid) =>
      _leaveService.getApplicationsByUser(uid);

  Future<List<LeaveApplicationModel>> departmentPending(String deptId) =>
      _leaveService.getPendingForDepartment(deptId);

  Future<List<LeaveApplicationModel>> forwardedAll() =>
      _leaveService.getForwardedApplications();

  Future<List<LeaveBalanceModel>> balancesForUser(String uid) async {
    final data = await _firestore.getCollection(
      AppConstants.balancesCollection,
    );
    return data
        .map((m) => LeaveBalanceModel.fromMap(m))
        .where((b) => b.userUid == uid)
        .toList();
  }
}
