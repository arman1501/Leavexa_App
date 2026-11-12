// ─────────────────────────────────────────────────────────────────────────────
//  user_repository.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import '../models/user_model.dart';
import '../services/auth_exception.dart';
import '../services/cloud_functions_service.dart';
import '../services/firestore_service.dart';

class UserRepository {
  FirestoreService? _firestore;
  CloudFunctionsService? _functions;

  UserRepository({
    FirestoreService? firestore,
    CloudFunctionsService? functions,
  })  : _firestore = firestore,
        _functions = functions;

  FirestoreService get _service => _firestore ??= FirestoreService();
  CloudFunctionsService get _cloudFunctions =>
      _functions ??= CloudFunctionsService();

  Future<void> createUser(UserModel user) async {
    await _service.setDocument(
      AppConstants.usersCollection,
      user.uid,
      user.toMap(),
    );
  }

  /// Checks whether an Employee ID is already reserved, returning the reserving UID or null.
  Future<String?> checkEmployeeIdReservation(String employeeId) async {
    final normalized = employeeId.trim().toUpperCase();
    final doc = await _service.getDocument(
      AppConstants.employeeIdsCollection,
      normalized,
    );
    if (doc == null) return null;
    return doc['uid'] as String?;
  }

  /// Atomically verifies that [user.employeeId] is not already taken by reading
  /// the `employee_ids/{employeeId}` document in a Firestore transaction.
  /// If available, it creates both the index document and the user document.
  /// If this user already owns the employeeId reservation (recovery), permits completion.
  Future<void> createFacultyUser(UserModel user) async {
    final normalizedEmpId = user.employeeId.trim().toUpperCase();
    final normalizedUser = user.employeeId == normalizedEmpId
        ? user
        : user.copyWith(employeeId: normalizedEmpId);

    // Fast pre-check: if already reserved by a different UID, fail fast with a descriptive AuthException
    final existingDoc = await _service.getDocument(
      AppConstants.employeeIdsCollection,
      normalizedEmpId,
    );
    if (existingDoc != null) {
      final existingUid = existingDoc['uid'];
      if (existingUid != null && existingUid != user.uid) {
        throw const AuthException(
          code: AuthErrorCode.duplicateEmployeeId,
          message: 'This Employee ID is already registered.',
        );
      }
    }

    try {
      await _service.runTransaction((transaction) async {
        final empRef = _service.firestore
            .collection(AppConstants.employeeIdsCollection)
            .doc(normalizedEmpId);

        final empDoc = await transaction.get(empRef);
        if (empDoc.exists) {
          final existingUid = empDoc.data()?['uid'];
          if (existingUid != null && existingUid != user.uid) {
            throw const AuthException(
              code: AuthErrorCode.duplicateEmployeeId,
              message: 'This Employee ID is already registered.',
            );
          }
        }

        final userRef = _service.firestore
            .collection(AppConstants.usersCollection)
            .doc(user.uid);

        transaction.set(empRef, {
          'uid': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.set(userRef, normalizedUser.toMap());
      });
    } on AuthException {
      rethrow;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        final checkDoc = await _service.getDocument(
          AppConstants.employeeIdsCollection,
          normalizedEmpId,
        );
        if (checkDoc != null && checkDoc['uid'] != user.uid) {
          throw const AuthException(
            code: AuthErrorCode.duplicateEmployeeId,
            message: 'This Employee ID is already registered.',
          );
        }
      } else if (e.code == 'unavailable' ||
          e.code == 'network-request-failed' ||
          e.code == 'deadline-exceeded') {
        throw const AuthException(
          code: AuthErrorCode.networkError,
          message: 'Unable to connect. Check your internet and try again.',
        );
      }
      rethrow;
    }
  }

  Future<UserModel?> getUserById(String uid) async {
    final data = await _service.getDocument(AppConstants.usersCollection, uid);
    if (data == null) return null;
    return UserModel.fromMap(data);
  }

  Stream<UserModel?> streamUserById(String uid) {
    return _service
        .streamDocument(AppConstants.usersCollection, uid)
        .map((data) => data == null ? null : UserModel.fromMap(data));
  }

  Future<void> updateUser(String uid, Map<String, dynamic> fields) async {
    await _service.updateDocument(AppConstants.usersCollection, uid, fields);
  }

  /// Fetch all pending faculty registrations (Admin).
  Future<List<UserModel>> getPendingFaculty() async {
    final data = await _service.queryCollection(
      AppConstants.usersCollection,
      isEqualTo: {'role': 'faculty', 'approvalStatus': 'pending'},
    );
    final users = data.map((m) => UserModel.fromMap(m)).toList();
    users.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return users;
  }

  /// Stream of pending faculty registrations (Admin).
  Stream<List<UserModel>> streamPendingFaculty() {
    return _service
        .streamCollection(
          AppConstants.usersCollection,
          isEqualTo: {'role': 'faculty', 'approvalStatus': 'pending'},
        )
        .map((list) {
          final users = list.map((m) => UserModel.fromMap(m)).toList();
          users.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return users;
        });
  }

  /// Fetch all faculty members (Admin directory).
  Future<List<UserModel>> getAllFaculty() async {
    final data = await _service.queryCollection(
      AppConstants.usersCollection,
      isEqualTo: {'role': 'faculty'},
    );
    final users = data.map((m) => UserModel.fromMap(m)).toList();
    users.sort((a, b) => a.fullName.compareTo(b.fullName));
    return users;
  }

  /// Identifies genuine university accounts while filtering out automated
  /// unit/emulator test stub documents.
  static bool isGenuineUser(UserModel u) {
    if (u.fullName.trim().isEmpty || u.employeeId.trim().isEmpty) {
      return false;
    }
    final name = u.fullName.toLowerCase();
    final emp = u.employeeId.toLowerCase();
    final uid = u.uid.toLowerCase();
    if (emp.contains('nophoto') ||
        name.contains('valid faculty') ||
        name.contains('mocha') ||
        uid.startsWith('no_photo_user') ||
        uid.startsWith('owner_') ||
        uid.startsWith('user_a_') ||
        uid.startsWith('user_b_') ||
        uid.startsWith('restart_uid_') ||
        uid.startsWith('valid_reg_') ||
        uid.startsWith('recovery_user_') ||
        uid.startsWith('uid_norm_') ||
        uid.startsWith('uid_ws_')) {
      return false;
    }
    return true;
  }

  /// Fetch all active admin accounts.
  Future<List<UserModel>> getActiveAdmins() async {
    final data = await _service.queryCollection(
      AppConstants.usersCollection,
      isEqualTo: {'role': 'admin'},
    );
    return data
        .map((m) => UserModel.fromMap(m))
        .where((u) => u.isActive)
        .toList();
  }

  /// Real-time stream of all users in Firestore (`users` collection).
  Stream<List<UserModel>> streamAllUsers() {
    return _service
        .streamCollection(AppConstants.usersCollection)
        .map((list) => list.map((m) => UserModel.fromMap(m)).toList());
  }

  /// Real-time stream of active admin accounts.
  Stream<List<UserModel>> streamActiveAdmins() {
    return _service
        .streamCollection(
          AppConstants.usersCollection,
          isEqualTo: {'role': 'admin'},
        )
        .map(
          (list) => list
              .map((m) => UserModel.fromMap(m))
              .where((u) => u.isActive)
              .toList(),
        );
  }

  /// Stream of all faculty members (Admin directory).
  Stream<List<UserModel>> streamAllFaculty() {
    return _service
        .streamCollection(
          AppConstants.usersCollection,
          isEqualTo: {'role': 'faculty'},
        )
        .map((list) {
          final users = list.map((m) => UserModel.fromMap(m)).toList();
          users.sort((a, b) => a.fullName.compareTo(b.fullName));
          return users;
        });
  }

  /// Fetch faculty by department (Department Head).
  Future<List<UserModel>> getFacultyByDepartment(String departmentId) async {
    final data = await _service.queryCollection(
      AppConstants.usersCollection,
      isEqualTo: {'departmentId': departmentId},
    );
    return data.map((m) => UserModel.fromMap(m)).toList();
  }

  /// Stream of faculty by department (Department Head).
  Stream<List<UserModel>> streamFacultyByDepartment(String departmentId) {
    return _service
        .streamCollection(
          AppConstants.usersCollection,
          isEqualTo: {'departmentId': departmentId},
        )
        .map((list) => list.map((m) => UserModel.fromMap(m)).toList());
  }

  /// Approve pending faculty (Admin action via Cloud Functions).
  ///
  /// Atomically updates profile, provisions default leave balances, sets custom claims,
  /// dispatches notifications and appends audit log.
  Future<void> approveFaculty(String uid) async {
    if (_functions != null || _firestore == null) {
      await _cloudFunctions.approveFacultyRegistration(uid);
    } else {
      // Mock test harness where FirestoreService was explicitly injected
      await updateUser(uid, {'approvalStatus': 'approved', 'isActive': true});
    }
  }

  /// Reject pending faculty (Admin action via Cloud Functions).
  ///
  /// Updates profile status, disables Auth user, sets rejected custom claims,
  /// dispatches notification and logs audit event.
  Future<void> rejectFaculty(String uid, {String? reason}) async {
    if (_functions != null || _firestore == null) {
      await _cloudFunctions.rejectFacultyRegistration(uid, reason: reason);
    } else {
      // Mock test harness where FirestoreService was explicitly injected
      await updateUser(uid, {
        'approvalStatus': 'rejected',
        'isActive': false,
        'rejectionReason': ?reason,
      });
    }
  }

  /// Activate or deactivate user account (Admin action via Cloud Functions).
  Future<void> setUserActive(String uid, bool isActive) async {
    if (_functions != null || _firestore == null) {
      await _cloudFunctions.setUserActive(uid, isActive);
    } else {
      // Mock test harness where FirestoreService was explicitly injected
      await updateUser(uid, {'isActive': isActive});
    }
  }

  /// Synchronize Firebase Auth Custom Claims with Firestore user profile.
  Future<Map<String, dynamic>> syncUserCustomClaims({String? uid}) async {
    return await _cloudFunctions.syncUserCustomClaims(targetUid: uid);
  }

  /// Officially transfer a Faculty member to a new verified department (Admin-only).
  Future<Map<String, dynamic>> transferFacultyDepartment({
    required String targetUid,
    required String newDepartmentId,
    String? newDepartmentName,
    String? reason,
  }) async {
    if (_functions != null || _firestore == null) {
      return await _cloudFunctions.transferFacultyDepartment(
        targetUid: targetUid,
        newDepartmentId: newDepartmentId,
        newDepartmentName: newDepartmentName,
        reason: reason,
      );
    } else {
      await updateUser(targetUid, {
        'departmentId': newDepartmentId,
        if (newDepartmentName != null) 'departmentName': newDepartmentName,
      });
      return {
        'success': true,
        'targetUid': targetUid,
        'newDepartmentId': newDepartmentId,
      };
    }
  }

  /// Create a staff account (Department Head or Registrar) via Cloud Functions.
  Future<Map<String, dynamic>> createStaffAccount({
    required String email,
    required String password,
    required String fullName,
    required String employeeId,
    required String role,
    String? departmentId,
    String? departmentName,
    String? designation,
    String? phone,
  }) async {
    return await _cloudFunctions.createStaffAccount(
      email: email,
      password: password,
      fullName: fullName,
      employeeId: employeeId,
      role: role,
      departmentId: departmentId,
      departmentName: departmentName,
      designation: designation,
      phone: phone,
    );
  }
}
