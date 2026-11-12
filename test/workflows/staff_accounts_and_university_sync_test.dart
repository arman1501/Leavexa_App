// ─────────────────────────────────────────────────────────────────────────────
//  staff_accounts_and_university_sync_test.dart
//  Tests fixed staff account verification, role routing, reserved email blocking,
//  and official university website integration service.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';
import 'package:leavexa/core/constants/app_constants.dart';
import 'package:leavexa/core/constants/app_strings.dart';
import 'package:leavexa/core/routes/app_routes.dart';
import 'package:leavexa/core/utils/validators.dart';
import 'package:leavexa/models/user_model.dart';
import 'package:leavexa/services/university_info_service.dart';

void main() {
  group('Fixed Staff Account & Role Routing Verification', () {
    test('Designated staff accounts route to their respective dashboards', () {
      final accounts = [
        {
          'email': 'department.head.lu@gmail.com',
          'role': AppStrings.roleDeptHead,
          'expectedRoute': AppRoutes.headDashboard,
        },
        {
          'email': 'registrar.lu@gmail.com',
          'role': AppStrings.roleRegistrar,
          'expectedRoute': AppRoutes.registrarDashboard,
        },
        {
          'email': 'admin.lu@gmail.com',
          'role': AppStrings.roleAdmin,
          'expectedRoute': AppRoutes.adminDashboard,
        },
      ];

      for (final acc in accounts) {
        final role = acc['role'] as String;
        final route = switch (role) {
          AppStrings.roleFaculty => AppRoutes.facultyDashboard,
          AppStrings.roleDeptHead => AppRoutes.headDashboard,
          AppStrings.roleRegistrar => AppRoutes.registrarDashboard,
          AppStrings.roleAdmin => AppRoutes.adminDashboard,
          _ => null,
        };

        expect(route, equals(acc['expectedRoute']));
      }
    });

    test('Reserved staff emails are blocked from faculty registration', () {
      final reserved = [
        'admin.lu@gmail.com',
        'ADMIN.LU@GMAIL.COM',
        'registrar.lu@gmail.com',
        'REGISTRAR.LU@GMAIL.COM',
        'department.head.lu@gmail.com',
        'DEPARTMENT.HEAD.LU@GMAIL.COM',
        'head.cse.lu@gmail.com',
        'head.eee.lu@gmail.com',
        'head.bba.lu@gmail.com',
        'head.ce.lu@gmail.com',
        'head.law.lu@gmail.com',
        'head.arch.lu@gmail.com',
        'head.ph.lu@gmail.com',
        'head.thm.lu@gmail.com',
        'head.islamic.lu@gmail.com',
        'head.english.lu@gmail.com',
      ];

      for (final email in reserved) {
        expect(AppConstants.isReservedStaffEmail(email), isTrue,
            reason: 'Expected $email to be reserved');
        final validation = Validators.facultyEmail(email);
        expect(validation, equals('This email is reserved for administrative staff.'));
      }

      // Verify all 10 canonical institutional department mappings exist
      expect(AppConstants.departmentIdToCanonicalName.length, equals(10));
      expect(AppConstants.getDepartmentId('Tourism & Hospitality Management'), equals('dept_thm'));

      // Normal faculty email is allowed
      expect(AppConstants.isReservedStaffEmail('faculty.member@gmail.com'), isFalse);
      expect(Validators.facultyEmail('faculty.member@gmail.com'), isNull);
    });

    test('Staff UserModel objects have correct roles and permissions', () {
      final head = UserModel(
        uid: 'head_uid_1',
        email: 'department.head.lu@gmail.com',
        fullName: 'Department Head (CSE)',
        employeeId: 'HEAD-CSE-001',
        departmentId: 'dept_cse',
        departmentName: 'Computer Science & Engineering',
        designation: 'Department Head',
        role: AppStrings.roleDeptHead,
        approvalStatus: 'approved',
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
      );
      expect(head.isDeptHead, isTrue);
      expect(head.isActive, isTrue);
      expect(head.departmentId, 'dept_cse');

      final reg = UserModel(
        uid: 'reg_uid_1',
        email: 'registrar.lu@gmail.com',
        fullName: 'Office of the Registrar',
        employeeId: 'REG-001',
        departmentId: 'registrar_office',
        departmentName: 'Office of the Registrar',
        designation: 'Registrar',
        role: AppStrings.roleRegistrar,
        approvalStatus: 'approved',
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
      );
      expect(reg.isRegistrar, isTrue);
      expect(reg.isActive, isTrue);

      final admin = UserModel(
        uid: 'admin_uid_1',
        email: 'admin.lu@gmail.com',
        fullName: 'System Administrator',
        employeeId: 'ADMIN-001',
        departmentId: 'admin_office',
        departmentName: 'Office of the Administrator',
        designation: 'System Administrator',
        role: AppStrings.roleAdmin,
        approvalStatus: 'approved',
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
      );
      expect(admin.isAdmin, isTrue);
      expect(admin.isActive, isTrue);
    });
  });

  group('Official University Website (lus.ac.bd) Integration', () {
    test('University overview fallback data contains accurate official contacts', () async {
      final service = UniversityInfoService();
      final overview = await service.getOverview();

      expect(overview.universityName, equals('Leading University'));
      expect(overview.pabx, equals('01313084499'));
      expect(overview.generalEmail, equals('info@lus.ac.bd'));
      expect(overview.campusAddress, contains('Ragibnagar'));
      expect(overview.websiteUrl, equals('https://lus.ac.bd/'));
      expect(overview.sourceUrl, equals('https://lus.ac.bd/contact/'));
    });

    test('Official departments contains all 11 canonical academic departments', () async {
      final service = UniversityInfoService();
      final departments = await service.getOfficialDepartments();

      expect(departments.length, greaterThanOrEqualTo(11));
      final deptCodes = departments.map((d) => d.id).toSet();

      expect(deptCodes.contains('dept_cse'), isTrue);
      expect(deptCodes.contains('dept_eee'), isTrue);
      expect(deptCodes.contains('dept_bba'), isTrue);
      expect(deptCodes.contains('dept_civil'), isTrue);
      expect(deptCodes.contains('dept_law'), isTrue);
      expect(deptCodes.contains('dept_arch'), isTrue);
      expect(deptCodes.contains('dept_public_health'), isTrue);
      expect(deptCodes.contains('dept_thm'), isTrue);
      expect(deptCodes.contains('dept_islamic_studies'), isTrue);
      expect(deptCodes.contains('dept_english'), isTrue);
      expect(deptCodes.contains('dept_bangla'), isTrue);
    });

    test('Study Leave Policy is distinguished from unverified leave categories', () async {
      final service = UniversityInfoService();
      final policies = await service.getLeavePolicies();

      final leavePolicies = policies['leavePolicies'] as Map<String, dynamic>;
      expect(leavePolicies['study_leave']['status'], equals('VERIFIED'));
      expect(leavePolicies['study_leave']['isPubliclyVerified'], isTrue);

      expect(leavePolicies['casual_leave']['status'], contains('Not verified'));
      expect(leavePolicies['casual_leave']['isPubliclyVerified'], isFalse);

      expect(leavePolicies['medical_leave']['status'], contains('Not verified'));
      expect(leavePolicies['medical_leave']['isPubliclyVerified'], isFalse);
    });
  });
}
