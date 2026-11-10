// ─────────────────────────────────────────────────────────────────────────────
//  splash_screen_test.dart  –  Widget & flow tests for SplashScreen (Phase 6)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:leavexa/core/constants/app_strings.dart';
import 'package:leavexa/core/routes/app_routes.dart';
import 'package:leavexa/models/user_model.dart';
import 'package:leavexa/repositories/auth_repository.dart';
import 'package:leavexa/screens/splash/splash_screen.dart';
import 'package:leavexa/services/auth_exception.dart';

class FakeSplashAuthRepository extends AuthRepository {
  UserModel? mockUserToReturn;
  AuthException? exceptionToThrow;
  Exception? genericExceptionToThrow;
  int restoreCalls = 0;

  @override
  Future<UserModel?> restoreSession() async {
    restoreCalls++;
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    if (genericExceptionToThrow != null) {
      throw genericExceptionToThrow!;
    }
    return mockUserToReturn;
  }
}

Widget buildTestApp(Widget screen) {
  return MaterialApp(
    routes: {
      '/': (_) => screen,
      AppRoutes.login: (_) => const Scaffold(body: Text('Login Screen')),
      AppRoutes.facultyDashboard: (_) =>
          const Scaffold(body: Text('Faculty Dashboard')),
      AppRoutes.headDashboard: (_) =>
          const Scaffold(body: Text('Head Dashboard')),
      AppRoutes.registrarDashboard: (_) =>
          const Scaffold(body: Text('Registrar Dashboard')),
      AppRoutes.adminDashboard: (_) =>
          const Scaffold(body: Text('Admin Dashboard')),
    },
  );
}

void main() {
  late FakeSplashAuthRepository fakeRepo;

  setUp(() {
    fakeRepo = FakeSplashAuthRepository();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      buildTestApp(SplashScreen(authRepository: fakeRepo)),
    );
  }

  group('SplashScreen Session Restoration Routing', () {
    testWidgets('no existing session navigates to Login Screen', (
      tester,
    ) async {
      fakeRepo.mockUserToReturn = null;

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text('Login Screen'), findsOneWidget);
      expect(fakeRepo.restoreCalls, 1);
    });

    testWidgets('approved and active Faculty navigates to Faculty Dashboard', (
      tester,
    ) async {
      fakeRepo.mockUserToReturn = UserModel(
        uid: 'u-fac',
        fullName: 'Prof. Alice',
        email: 'alice@university.edu',
        employeeId: 'EMP001',
        departmentId: 'cs',
        departmentName: 'CS',
        designation: 'Professor',
        role: AppStrings.roleFaculty,
        isActive: true,
        approvalStatus: 'approved',
        createdAt: DateTime(2025, 1, 1),
      );

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text('Faculty Dashboard'), findsOneWidget);
      expect(fakeRepo.restoreCalls, 1);
    });

    testWidgets('active Department Head navigates to Head Dashboard', (
      tester,
    ) async {
      fakeRepo.mockUserToReturn = UserModel(
        uid: 'u-head',
        fullName: 'Dr. Head',
        email: 'head@university.edu',
        employeeId: 'HED001',
        departmentId: 'cs',
        departmentName: 'CS',
        designation: 'Professor',
        role: AppStrings.roleDeptHead,
        isActive: true,
        approvalStatus: 'approved',
        createdAt: DateTime(2025, 1, 1),
      );

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text('Head Dashboard'), findsOneWidget);
      expect(fakeRepo.restoreCalls, 1);
    });

    testWidgets('active Registrar navigates to Registrar Dashboard', (
      tester,
    ) async {
      fakeRepo.mockUserToReturn = UserModel(
        uid: 'u-reg',
        fullName: 'Mr. Registrar',
        email: 'reg@university.edu',
        employeeId: 'REG001',
        departmentId: 'reg',
        departmentName: 'Registry',
        designation: 'Registrar',
        role: AppStrings.roleRegistrar,
        isActive: true,
        approvalStatus: 'approved',
        createdAt: DateTime(2025, 1, 1),
      );

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text('Registrar Dashboard'), findsOneWidget);
      expect(fakeRepo.restoreCalls, 1);
    });

    testWidgets('active Admin navigates to Admin Dashboard', (tester) async {
      fakeRepo.mockUserToReturn = UserModel(
        uid: 'u-adm',
        fullName: 'System Admin',
        email: 'admin@university.edu',
        employeeId: 'ADM001',
        departmentId: 'admin',
        departmentName: 'Administration',
        designation: 'Administrator',
        role: AppStrings.roleAdmin,
        isActive: true,
        approvalStatus: 'approved',
        createdAt: DateTime(2025, 1, 1),
      );

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text('Admin Dashboard'), findsOneWidget);
      expect(fakeRepo.restoreCalls, 1);
    });
  });

  group('SplashScreen Safety Fallbacks (Unauthorized/Invalid → Login)', () {
    testWidgets('pending Faculty falls back safely to Login Screen', (
      tester,
    ) async {
      fakeRepo.mockUserToReturn = UserModel(
        uid: 'u-pending',
        fullName: 'Pending Faculty',
        email: 'pending@university.edu',
        employeeId: 'EMP002',
        departmentId: 'cs',
        departmentName: 'CS',
        designation: 'Lecturer',
        role: AppStrings.roleFaculty,
        isActive: false,
        approvalStatus: 'pending',
        createdAt: DateTime(2025, 1, 1),
      );

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text('Login Screen'), findsOneWidget);
      expect(find.text('Faculty Dashboard'), findsNothing);
    });

    testWidgets('rejected Faculty falls back safely to Login Screen', (
      tester,
    ) async {
      fakeRepo.mockUserToReturn = UserModel(
        uid: 'u-rejected',
        fullName: 'Rejected Faculty',
        email: 'rejected@university.edu',
        employeeId: 'EMP003',
        departmentId: 'cs',
        departmentName: 'CS',
        designation: 'Lecturer',
        role: AppStrings.roleFaculty,
        isActive: false,
        approvalStatus: 'rejected',
        createdAt: DateTime(2025, 1, 1),
      );

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text('Login Screen'), findsOneWidget);
      expect(find.text('Faculty Dashboard'), findsNothing);
    });

    testWidgets('inactive account falls back safely to Login Screen', (
      tester,
    ) async {
      fakeRepo.mockUserToReturn = UserModel(
        uid: 'u-inactive',
        fullName: 'Inactive Admin',
        email: 'inactive@university.edu',
        employeeId: 'ADM002',
        departmentId: 'admin',
        departmentName: 'Administration',
        designation: 'Administrator',
        role: AppStrings.roleAdmin,
        isActive: false,
        approvalStatus: 'approved',
        createdAt: DateTime(2025, 1, 1),
      );

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text('Login Screen'), findsOneWidget);
      expect(find.text('Admin Dashboard'), findsNothing);
    });

    testWidgets('missing Firestore profile falls back safely to Login Screen', (
      tester,
    ) async {
      fakeRepo.exceptionToThrow = const AuthException(
        code: AuthErrorCode.missingProfile,
        message: 'Your account profile was not found.',
      );

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text('Login Screen'), findsOneWidget);
    });

    testWidgets('invalid role falls back safely to Login Screen', (
      tester,
    ) async {
      fakeRepo.exceptionToThrow = const AuthException(
        code: AuthErrorCode.invalidRole,
        message: 'Invalid role assigned to this account.',
      );

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text('Login Screen'), findsOneWidget);
    });

    testWidgets('network error falls back safely to Login Screen', (
      tester,
    ) async {
      fakeRepo.exceptionToThrow = const AuthException(
        code: AuthErrorCode.networkError,
        message: 'Network error.',
      );

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text('Login Screen'), findsOneWidget);
    });

    testWidgets('navigation occurs only once', (tester) async {
      fakeRepo.mockUserToReturn = null;

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      // Trigger extra frames / rebuild
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Login Screen'), findsOneWidget);
      expect(fakeRepo.restoreCalls, 1);
    });
  });
}
