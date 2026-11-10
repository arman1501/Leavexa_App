// ─────────────────────────────────────────────────────────────────────────────
//  cloud_functions_service.dart  –  Centralized Cloud Functions Service
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_functions/cloud_functions.dart';

class CloudFunctionsService {
  FirebaseFunctions? _functionsInstance;

  CloudFunctionsService({FirebaseFunctions? functions})
      : _functionsInstance = functions;

  FirebaseFunctions get functions =>
      _functionsInstance ??= FirebaseFunctions.instance;

  /// Configure Firebase Functions local emulator suite host and port.
  void useEmulator(String host, int port) {
    functions.useFunctionsEmulator(host, port);
  }

  /// Approves a pending Faculty registration (Admin-only).
  ///
  /// The Cloud Function:
  /// 1. Updates Firestore profile (`approvalStatus: 'approved'`, `isActive: true`)
  /// 2. Atomically provisions default annual leave balances in `leave_balances`
  /// 3. Assigns Firebase Auth Custom Claims (`role: 'faculty'`, `approvalStatus: 'approved'`)
  /// 4. Dispatches FCM push notification and in-app notification
  /// 5. Appends an audit log entry (`FACULTY_APPROVE`)
  Future<Map<String, dynamic>> approveFacultyRegistration(
    String targetUid,
  ) async {
    final callable = functions.httpsCallable('approveFacultyRegistration');
    final result = await callable.call<Map<String, dynamic>>({
      'targetUid': targetUid,
    });
    return Map<String, dynamic>.from(result.data);
  }

  /// Rejects a pending Faculty registration (Admin-only).
  ///
  /// The Cloud Function:
  /// 1. Updates Firestore profile (`approvalStatus: 'rejected'`, `isActive: false`)
  /// 2. Disables user in Firebase Authentication
  /// 3. Updates Custom Claims (`approvalStatus: 'rejected'`)
  /// 4. Dispatches rejection push notification and in-app notification
  /// 5. Appends an audit log entry (`FACULTY_REJECT`)
  Future<Map<String, dynamic>> rejectFacultyRegistration(
    String targetUid, {
    String? reason,
  }) async {
    final callable = functions.httpsCallable('rejectFacultyRegistration');
    final result = await callable.call<Map<String, dynamic>>({
      'targetUid': targetUid,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
    return Map<String, dynamic>.from(result.data);
  }

  /// Creates a staff account (Department Head or Registrar) (Admin-only).
  ///
  /// The Cloud Function:
  /// 1. Verifies caller is an authenticated Administrator
  /// 2. Creates the Firebase Auth user record
  /// 3. Sets Custom Claims (`role`, `approvalStatus: 'approved'`, `departmentId`)
  /// 4. Writes verified user profile to `users`
  /// 5. Atomically reserves `employee_ids`
  /// 6. Appends an audit log entry (`STAFF_ACCOUNT_CREATED`)
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
    final callable = functions.httpsCallable('createStaffAccount');
    final result = await callable.call<Map<String, dynamic>>({
      'email': email,
      'password': password,
      'fullName': fullName,
      'employeeId': employeeId,
      'role': role,
      if (departmentId != null) 'departmentId': departmentId,
      if (departmentName != null) 'departmentName': departmentName,
      if (designation != null) 'designation': designation,
      if (phone != null) 'phone': phone,
    });
    return Map<String, dynamic>.from(result.data);
  }

  /// Activates or deactivates a user account (Admin-only).
  ///
  /// The Cloud Function:
  /// 1. Updates Firebase Auth `disabled: !isActive`
  /// 2. Updates Firestore `users/{targetUid}.isActive`
  /// 3. Appends an audit log entry (`USER_ACTIVATED` or `USER_DEACTIVATED`)
  Future<Map<String, dynamic>> setUserActive(
    String targetUid,
    bool isActive,
  ) async {
    final callable = functions.httpsCallable('setUserActive');
    final result = await callable.call<Map<String, dynamic>>({
      'targetUid': targetUid,
      'isActive': isActive,
    });
    return Map<String, dynamic>.from(result.data);
  }

  /// Synchronizes Firebase Auth Custom Claims with verified Firestore profile.
  Future<Map<String, dynamic>> syncUserCustomClaims({String? targetUid}) async {
    final callable = functions.httpsCallable('syncUserCustomClaims');
    final result = await callable.call<Map<String, dynamic>>({
      if (targetUid != null) 'targetUid': targetUid,
    });
    return Map<String, dynamic>.from(result.data);
  }

  /// Pre-checks Employee ID availability.
  Future<Map<String, dynamic>> checkEmployeeId(String employeeId) async {
    final callable = functions.httpsCallable('checkEmployeeId');
    final result = await callable.call<Map<String, dynamic>>({
      'employeeId': employeeId,
    });
    return Map<String, dynamic>.from(result.data);
  }

  /// Provisions initial admin when no active admin exists.
  Future<Map<String, dynamic>> provisionInitialAdmin({
    String? fullName,
    String? employeeId,
    String? email,
    String? bootstrapKey,
  }) async {
    final callable = functions.httpsCallable('provisionInitialAdmin');
    final result = await callable.call<Map<String, dynamic>>({
      if (fullName != null) 'fullName': fullName,
      if (employeeId != null) 'employeeId': employeeId,
      if (email != null) 'email': email,
      if (bootstrapKey != null) 'bootstrapKey': bootstrapKey,
    });
    return Map<String, dynamic>.from(result.data);
  }

  /// Synchronizes official university public information from https://lus.ac.bd/ (Admin-only).
  Future<Map<String, dynamic>> syncUniversityInfo({bool force = false}) async {
    final callable = functions.httpsCallable('syncUniversityInfo');
    final result = await callable.call<Map<String, dynamic>>({
      'force': force,
    });
    return Map<String, dynamic>.from(result.data);
  }

  /// Provisions or synchronizes designated fixed staff accounts (Admin / Bootstrap).
  Future<Map<String, dynamic>> provisionFixedStaffAccounts({String? bootstrapKey}) async {
    final callable = functions.httpsCallable('provisionFixedStaffAccounts');
    final result = await callable.call<Map<String, dynamic>>({
      if (bootstrapKey != null) 'bootstrapKey': bootstrapKey,
    });
    return Map<String, dynamic>.from(result.data);
  }
}
