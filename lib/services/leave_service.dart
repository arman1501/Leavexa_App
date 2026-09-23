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

  /// Forward an application (department head action).
  Future<void> forwardApplication({
    required String applicationId,
    required String headUid,
    required String comment,
  }) async {
    await _firestore.updateDocument(
      AppConstants.applicationsCollection,
      applicationId,
      {
        'status': 'forwarded',
        'headUid': headUid,
        'headComment': comment,
        'headActionAt': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Approve or reject an application (registrar action).
  Future<void> finalAction({
    required String applicationId,
    required String registrarUid,
    required bool isApproved,
    required String comment,
  }) async {
    await _firestore.updateDocument(
      AppConstants.applicationsCollection,
      applicationId,
      {
        'status': isApproved ? 'approved' : 'rejected',
        'registrarUid': registrarUid,
        'registrarComment': comment,
        'registrarActionAt': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Fetch all applications for a given applicant UID.
  Future<List<LeaveApplicationModel>> getApplicationsByUser(
      String applicantUid) async {
    // TODO: Filter by applicantUid in Firestore query
    final data = await _firestore.getCollection(
      AppConstants.applicationsCollection,
    );
    return data
        .map((m) => LeaveApplicationModel.fromMap(m))
        .where((a) => a.applicantUid == applicantUid)
        .toList();
  }

  /// Fetch all pending applications for a department (head view).
  Future<List<LeaveApplicationModel>> getPendingForDepartment(
      String departmentId) async {
    final data = await _firestore.getCollection(
      AppConstants.applicationsCollection,
    );
    return data
        .map((m) => LeaveApplicationModel.fromMap(m))
        .where((a) =>
            a.departmentId == departmentId && a.status == 'pending')
        .toList();
  }

  /// Fetch all forwarded applications (registrar view).
  Future<List<LeaveApplicationModel>> getForwardedApplications() async {
    final data = await _firestore.getCollection(
      AppConstants.applicationsCollection,
    );
    return data
        .map((m) => LeaveApplicationModel.fromMap(m))
        .where((a) => a.status == 'forwarded')
        .toList();
  }
}
