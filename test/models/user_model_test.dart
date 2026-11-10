import 'package:flutter_test/flutter_test.dart';
import 'package:leavexa/core/constants/app_strings.dart';
import 'package:leavexa/models/user_model.dart';

void main() {
  // ── Helper ────────────────────────────────────────────────────────────────
  UserModel make({
    String role = 'faculty',
    bool isActive = true,
    String approvalStatus = 'approved',
  }) {
    return UserModel(
      uid: 'u1',
      fullName: 'Test User',
      email: 'test@example.com',
      employeeId: 'EMP001',
      departmentId: 'd1',
      departmentName: 'CS',
      designation: 'Lecturer',
      role: role,
      isActive: isActive,
      approvalStatus: approvalStatus,
      createdAt: DateTime(2025, 1, 1),
    );
  }

  // ── AppStrings role constants ─────────────────────────────────────────────
  group('AppStrings role constants', () {
    test('has exactly four roles', () {
      expect(AppStrings.allRoles.length, 4);
    });

    test('contains all expected identifiers', () {
      expect(AppStrings.allRoles, contains('faculty'));
      expect(AppStrings.allRoles, contains('department_head'));
      expect(AppStrings.allRoles, contains('registrar'));
      expect(AppStrings.allRoles, contains('admin'));
    });

    test('roleAdmin constant equals "admin"', () {
      expect(AppStrings.roleAdmin, 'admin');
    });
  });

  // ── Role getters ──────────────────────────────────────────────────────────
  group('UserModel role getters', () {
    test('isFaculty', () {
      expect(make(role: 'faculty').isFaculty, isTrue);
      expect(make(role: 'admin').isFaculty, isFalse);
    });

    test('isDeptHead', () {
      expect(make(role: 'department_head').isDeptHead, isTrue);
      expect(make(role: 'faculty').isDeptHead, isFalse);
    });

    test('isRegistrar', () {
      expect(make(role: 'registrar').isRegistrar, isTrue);
      expect(make(role: 'faculty').isRegistrar, isFalse);
    });

    test('isAdmin', () {
      expect(make(role: 'admin').isAdmin, isTrue);
      expect(make(role: 'faculty').isAdmin, isFalse);
    });
  });

  // ── Approval / status getters ─────────────────────────────────────────────
  group('UserModel approval / status getters', () {
    test('isApproved', () {
      expect(make(approvalStatus: 'approved').isApproved, isTrue);
      expect(make(approvalStatus: 'pending').isApproved, isFalse);
    });

    test('isPending', () {
      expect(make(approvalStatus: 'pending').isPending, isTrue);
      expect(make(approvalStatus: 'approved').isPending, isFalse);
    });

    test('isRejected', () {
      expect(make(approvalStatus: 'rejected').isRejected, isTrue);
      expect(make(approvalStatus: 'pending').isRejected, isFalse);
    });

    test('isActiveAndApproved — both true', () {
      expect(
        make(isActive: true, approvalStatus: 'approved').isActiveAndApproved,
        isTrue,
      );
    });

    test('isActiveAndApproved — inactive', () {
      expect(
        make(isActive: false, approvalStatus: 'approved').isActiveAndApproved,
        isFalse,
      );
    });

    test('isActiveAndApproved — not approved', () {
      expect(
        make(isActive: true, approvalStatus: 'pending').isActiveAndApproved,
        isFalse,
      );
    });
  });
}
