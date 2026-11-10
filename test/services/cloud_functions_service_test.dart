// ─────────────────────────────────────────────────────────────────────────────
//  cloud_functions_service_test.dart  –  Phase 17 CloudFunctionsService Unit Tests
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';
import 'package:leavexa/repositories/user_repository.dart';
import 'package:leavexa/services/cloud_functions_service.dart';

class MockCloudFunctionsService extends CloudFunctionsService {
  final List<String> approvedUids = [];
  final Map<String, String?> rejectedUids = {};
  final Map<String, bool> userActiveStates = {};
  final List<Map<String, dynamic>> createdStaff = [];
  final List<String?> syncedClaimUids = [];

  @override
  Future<Map<String, dynamic>> approveFacultyRegistration(
    String targetUid,
  ) async {
    approvedUids.add(targetUid);
    return {
      'success': true,
      'targetUid': targetUid,
      'message': 'Faculty approved successfully.',
    };
  }

  @override
  Future<Map<String, dynamic>> rejectFacultyRegistration(
    String targetUid, {
    String? reason,
  }) async {
    rejectedUids[targetUid] = reason;
    return {
      'success': true,
      'targetUid': targetUid,
      'reason': reason,
      'message': 'Faculty rejected.',
    };
  }

  @override
  Future<Map<String, dynamic>> setUserActive(
    String targetUid,
    bool isActive,
  ) async {
    userActiveStates[targetUid] = isActive;
    return {'success': true, 'targetUid': targetUid, 'isActive': isActive};
  }

  @override
  Future<Map<String, dynamic>> syncUserCustomClaims({String? targetUid}) async {
    syncedClaimUids.add(targetUid);
    return {'success': true, 'targetUid': targetUid};
  }

  @override
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
    final record = {
      'email': email,
      'password': password,
      'fullName': fullName,
      'employeeId': employeeId,
      'role': role,
      'departmentId': departmentId,
      'departmentName': departmentName,
      'designation': designation,
      'phone': phone,
    };
    createdStaff.add(record);
    return {
      'success': true,
      'uid': 'new_staff_uid_123',
      'message': '$role account created successfully.',
    };
  }
}

void main() {
  group('Phase 17 — CloudFunctionsService & UserRepository Integration', () {
    late MockCloudFunctionsService mockFunctions;
    late UserRepository userRepo;

    setUp(() {
      mockFunctions = MockCloudFunctionsService();
      userRepo = UserRepository(functions: mockFunctions);
    });

    test('approveFaculty delegates to approveFacultyRegistration Cloud Function', () async {
      await userRepo.approveFaculty('fac_uid_001');

      expect(mockFunctions.approvedUids, contains('fac_uid_001'));
      expect(mockFunctions.approvedUids.length, equals(1));
    });

    test('rejectFaculty delegates to rejectFacultyRegistration with reason', () async {
      await userRepo.rejectFaculty(
        'fac_uid_002',
        reason: 'Incomplete documentation',
      );

      expect(mockFunctions.rejectedUids.containsKey('fac_uid_002'), isTrue);
      expect(
        mockFunctions.rejectedUids['fac_uid_002'],
        equals('Incomplete documentation'),
      );
    });

    test('setUserActive delegates to setUserActive Cloud Function', () async {
      await userRepo.setUserActive('target_uid_003', false);
      expect(mockFunctions.userActiveStates['target_uid_003'], isFalse);

      await userRepo.setUserActive('target_uid_003', true);
      expect(mockFunctions.userActiveStates['target_uid_003'], isTrue);
    });

    test('syncUserCustomClaims delegates to syncUserCustomClaims Cloud Function', () async {
      await userRepo.syncUserCustomClaims(uid: 'target_uid_004');
      expect(mockFunctions.syncedClaimUids, contains('target_uid_004'));
    });

    test('createStaffAccount delegates to createStaffAccount Cloud Function with full payload', () async {
      final res = await userRepo.createStaffAccount(
        email: 'head.cse@leavexa.edu',
        password: 'SecurePassword123!',
        fullName: 'Dr. Head of CSE',
        employeeId: 'HEAD-CSE-01',
        role: 'department_head',
        departmentId: 'dept_cse',
        departmentName: 'Computer Science & Engineering',
        designation: 'Professor & Head',
        phone: '+1234567890',
      );

      expect(res['success'], isTrue);
      expect(res['uid'], equals('new_staff_uid_123'));
      expect(mockFunctions.createdStaff.length, equals(1));
      expect(
        mockFunctions.createdStaff.first['email'],
        equals('head.cse@leavexa.edu'),
      );
      expect(
        mockFunctions.createdStaff.first['role'],
        equals('department_head'),
      );
    });
  });
}
