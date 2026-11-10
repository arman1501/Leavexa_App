// ─────────────────────────────────────────────────────────────────────────────
//  leave_service.dart  –  Leave Application Business Logic
// ─────────────────────────────────────────────────────────────────────────────

import '../models/leave_application_model.dart';
import '../core/constants/app_constants.dart';
import 'firestore_service.dart';

class LeaveService {
  final FirestoreService _firestore;
  LeaveService({FirestoreService? firestore})
    : _firestore = firestore ?? FirestoreService();

  /// Submit a new leave application.
  Future<String> submitApplication(LeaveApplicationModel application) async {
    final id = await _firestore.addDocument(
      AppConstants.applicationsCollection,
      application.toMap(),
    );
    return id;
  }

  /// Cancel a pending leave application (faculty applicant action).
  ///
  /// Can only be performed by the applicant while status is 'pending'.
  Future<void> cancelApplication({
    required String applicationId,
    required String applicantUid,
    String? reason,
  }) async {
    final appData = await _firestore.getDocument(
      AppConstants.applicationsCollection,
      applicationId,
    );
    if (appData == null) {
      throw Exception('Application $applicationId not found.');
    }
    if (appData['applicantUid'] != applicantUid) {
      throw Exception(
        'Unauthorized: You can only cancel your own applications.',
      );
    }
    if (appData['status'] != 'pending') {
      throw Exception(
        'Cannot cancel application: current status is "${appData['status']}". Only pending applications can be cancelled.',
      );
    }

    final fields = <String, dynamic>{
      'status': 'cancelled',
      'cancelledAt': DateTime.now().toIso8601String(),
    };
    if (reason != null && reason.trim().isNotEmpty) {
      fields['cancelReason'] = reason.trim();
    }

    await _firestore.updateDocument(
      AppConstants.applicationsCollection,
      applicationId,
      fields,
    );
  }

  /// Forward an application (department head action).
  Future<void> forwardApplication({
    required String applicationId,
    required String headUid,
    required String comment,
  }) async {
    await _firestore
        .updateDocument(AppConstants.applicationsCollection, applicationId, {
          'status': 'forwarded',
          'headUid': headUid,
          'headComment': comment,
          'headActionAt': DateTime.now().toIso8601String(),
        });
  }

  /// Reject an application at department level (department head action).
  Future<void> headRejectApplication({
    required String applicationId,
    required String headUid,
    required String comment,
  }) async {
    await _firestore
        .updateDocument(AppConstants.applicationsCollection, applicationId, {
          'status': 'rejected',
          'headUid': headUid,
          'headComment': comment,
          'headActionAt': DateTime.now().toIso8601String(),
        });
  }

  /// Approve or reject an application (registrar action).
  Future<void> finalAction({
    required String applicationId,
    required String registrarUid,
    required bool isApproved,
    required String comment,
  }) async {
    await _firestore
        .updateDocument(AppConstants.applicationsCollection, applicationId, {
          'status': isApproved ? 'approved' : 'rejected',
          'registrarUid': registrarUid,
          'registrarComment': comment,
          'registrarActionAt': DateTime.now().toIso8601String(),
        });
  }

  /// Fetch all applications for a given applicant UID.
  Future<List<LeaveApplicationModel>> getApplicationsByUser(
    String applicantUid,
  ) async {
    final data = await _firestore.queryCollection(
      AppConstants.applicationsCollection,
      isEqualTo: {'applicantUid': applicantUid},
    );
    final apps = data.map((m) => LeaveApplicationModel.fromMap(m)).toList();
    apps.sort((a, b) => b.appliedAt.compareTo(a.appliedAt));
    return apps;
  }

  /// Real-time stream of applications for a given applicant UID.
  Stream<List<LeaveApplicationModel>> streamApplicationsByUser(
    String applicantUid,
  ) {
    return _firestore
        .streamCollection(
          AppConstants.applicationsCollection,
          isEqualTo: {'applicantUid': applicantUid},
        )
        .map((list) {
          final apps =
              list.map((m) => LeaveApplicationModel.fromMap(m)).toList();
          apps.sort((a, b) => b.appliedAt.compareTo(a.appliedAt));
          return apps;
        });
  }

  /// Fetch all pending applications for a department (head view).
  Future<List<LeaveApplicationModel>> getPendingForDepartment(
    String departmentId,
  ) async {
    final data = await _firestore.queryCollection(
      AppConstants.applicationsCollection,
      isEqualTo: {'departmentId': departmentId, 'status': 'pending'},
    );
    final apps = data.map((m) => LeaveApplicationModel.fromMap(m)).toList();
    apps.sort((a, b) => b.appliedAt.compareTo(a.appliedAt));
    return apps;
  }

  /// Real-time stream of pending applications for a department (head view).
  Stream<List<LeaveApplicationModel>> streamPendingForDepartment(
    String departmentId,
  ) {
    return _firestore
        .streamCollection(
          AppConstants.applicationsCollection,
          isEqualTo: {'departmentId': departmentId, 'status': 'pending'},
        )
        .map((list) {
          final apps =
              list.map((m) => LeaveApplicationModel.fromMap(m)).toList();
          apps.sort((a, b) => b.appliedAt.compareTo(a.appliedAt));
          return apps;
        });
  }

  /// Fetch all forwarded applications (registrar view).
  Future<List<LeaveApplicationModel>> getForwardedApplications() async {
    final data = await _firestore.queryCollection(
      AppConstants.applicationsCollection,
      isEqualTo: {'status': 'forwarded'},
    );
    final apps = data.map((m) => LeaveApplicationModel.fromMap(m)).toList();
    apps.sort((a, b) => b.appliedAt.compareTo(a.appliedAt));
    return apps;
  }

  /// Real-time stream of forwarded applications (registrar view).
  Stream<List<LeaveApplicationModel>> streamForwardedApplications() {
    return _firestore
        .streamCollection(
          AppConstants.applicationsCollection,
          isEqualTo: {'status': 'forwarded'},
        )
        .map((list) {
          final apps =
              list.map((m) => LeaveApplicationModel.fromMap(m)).toList();
          apps.sort((a, b) => b.appliedAt.compareTo(a.appliedAt));
          return apps;
        });
  }
}
