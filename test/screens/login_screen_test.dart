// ─────────────────────────────────────────────────────────────────────────────
//  login_screen_test.dart  –  Widget & flow tests for LoginScreen (Phase 3)
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:leavexa/core/constants/app_strings.dart';
import 'package:leavexa/core/routes/app_routes.dart';
import 'package:leavexa/models/user_model.dart';
import 'package:leavexa/repositories/auth_repository.dart';
import 'package:leavexa/screens/auth/login_screen.dart';
import 'package:leavexa/services/auth_exception.dart';

/// Test double for [AuthRepository] to test LoginScreen deterministically.
class FakeAuthRepository extends AuthRepository {
  UserModel? mockUserToReturn;
  AuthException? exceptionToThrow;
  Exception? genericExceptionToThrow;
  int loginCalls = 0;
  Completer<UserModel>? loginCompleter;

  int googleCalls = 0;
  Completer<UserModel>? googleCompleter;
  AuthException? googleExceptionToThrow;

  @override
  Future<UserModel> signInWithGoogle() async {
    googleCalls++;
    if (googleCompleter != null) {
      return googleCompleter!.future;
    }
    if (googleExceptionToThrow != null) {
      throw googleExceptionToThrow!;
    }
    return mockUserToReturn ??
        UserModel(
          uid: 'uid-google-1',
          fullName: 'Google User',
          email: 'google@example.com',
          employeeId: 'EMP001',
          departmentId: 'cs',
          departmentName: 'Computer Science',
          designation: 'Lecturer',
          role: AppStrings.roleFaculty,
          isActive: true,
          approvalStatus: 'approved',
          createdAt: DateTime(2025, 1, 1),
        );
  }

  @override
  Future<UserModel> loginAndGetProfile({
    required String email,
    required String password,
  }) async {
    loginCalls++;
    if (loginCompleter != null) {
      return loginCompleter!.future;
    }
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    if (genericExceptionToThrow != null) {
      throw genericExceptionToThrow!;
    }
    return mockUserToReturn ??
        UserModel(
          uid: 'uid-1',
          fullName: 'Test Faculty',
          email: email,
          employeeId: 'EMP001',
          departmentId: 'cs',
          departmentName: 'Computer Science',
          designation: 'Lecturer',
          role: AppStrings.roleFaculty,
          isActive: true,
          approvalStatus: 'approved',
          createdAt: DateTime(2025, 1, 1),
        );
  }
}

Widget buildTestApp(
  Widget screen, {
  Map<String, WidgetBuilder>? additionalRoutes,
}) {
  return MaterialApp(
    routes: {
      '/': (_) => screen,
      AppRoutes.facultyDashboard: (_) =>
          const Scaffold(body: Text('Faculty Dashboard')),
      AppRoutes.headDashboard: (_) =>
          const Scaffold(body: Text('Head Dashboard')),
      AppRoutes.registrarDashboard: (_) =>
          const Scaffold(body: Text('Registrar Dashboard')),
      AppRoutes.adminDashboard: (_) =>
          const Scaffold(body: Text('Admin Dashboard')),
      AppRoutes.forgotPassword: (_) =>
          const Scaffold(body: Text('Forgot Password Screen')),
      ...?additionalRoutes,
    },
  );
}

void main() {
  late FakeAuthRepository fakeRepo;

  setUp(() {
    fakeRepo = FakeAuthRepository();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      buildTestApp(LoginScreen(authRepository: fakeRepo)),
    );
    await tester.pumpAndSettle();
  }

  group('LoginScreen Form Validation', () {
    testWidgets('empty email triggers validation error', (tester) async {
      await pumpScreen(tester);

      final loginBtn = find.text('Login');
      await tester.tap(loginBtn);
      await tester.pump();

      expect(find.text('Please enter your email'), findsOneWidget);
      expect(fakeRepo.loginCalls, 0);
    });

    testWidgets('invalid email format triggers validation error', (
      tester,
    ) async {
      await pumpScreen(tester);

      final emailField = find.byType(TextFormField).first;
      await tester.enterText(emailField, 'notanemail');

      final passField = find.byType(TextFormField).at(1);
      await tester.enterText(passField, 'password123');

      final loginBtn = find.text('Login');
      await tester.tap(loginBtn);
      await tester.pump();

      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(fakeRepo.loginCalls, 0);
    });

    testWidgets('empty password triggers validation error', (tester) async {
      await pumpScreen(tester);

      final emailField = find.byType(TextFormField).first;
      await tester.enterText(emailField, 'valid@example.com');

      final loginBtn = find.text('Login');
      await tester.tap(loginBtn);
      await tester.pump();

      expect(find.text('Please enter your password'), findsOneWidget);
      expect(fakeRepo.loginCalls, 0);
    });

    testWidgets('tapping Forgot Password navigates to forgot password route', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Forgot Password?'));
      await tester.pumpAndSettle();

      expect(find.text('Forgot Password Screen'), findsOneWidget);
    });
  });

  group('LoginScreen Role Routing', () {
    testWidgets('approved faculty navigates to faculty dashboard', (
      tester,
    ) async {
      fakeRepo.mockUserToReturn = UserModel(
        uid: 'u-fac',
        fullName: 'Faculty Member',
        email: 'faculty@example.com',
        employeeId: 'EMP001',
        departmentId: 'cs',
        departmentName: 'Computer Science',
        designation: 'Lecturer',
        role: AppStrings.roleFaculty,
        isActive: true,
        approvalStatus: 'approved',
        createdAt: DateTime(2025, 1, 1),
      );

      await pumpScreen(tester);

      final emailField = find.byType(TextFormField).first;
      final passField = find.byType(TextFormField).at(1);
      await tester.enterText(emailField, 'faculty@example.com');
      await tester.enterText(passField, 'secret123');

      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      expect(find.text('Faculty Dashboard'), findsOneWidget);
      expect(fakeRepo.loginCalls, 1);
    });

    testWidgets('admin navigates to admin dashboard', (tester) async {
      fakeRepo.mockUserToReturn = UserModel(
        uid: 'u-admin',
        fullName: 'System Admin',
        email: 'admin@example.com',
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

      await tester.enterText(
        find.byType(TextFormField).first,
        'admin@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'secret123');

      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      expect(find.text('Admin Dashboard'), findsOneWidget);
    });

    testWidgets('department head navigates to head dashboard', (tester) async {
      fakeRepo.mockUserToReturn = UserModel(
        uid: 'u-head',
        fullName: 'Dept Head',
        email: 'head@example.com',
        employeeId: 'HED001',
        departmentId: 'cs',
        departmentName: 'Computer Science',
        designation: 'Professor',
        role: AppStrings.roleDeptHead,
        isActive: true,
        approvalStatus: 'approved',
        createdAt: DateTime(2025, 1, 1),
      );

      await pumpScreen(tester);

      await tester.enterText(
        find.byType(TextFormField).first,
        'head@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'secret123');

      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      expect(find.text('Head Dashboard'), findsOneWidget);
    });

    testWidgets('registrar navigates to registrar dashboard', (tester) async {
      fakeRepo.mockUserToReturn = UserModel(
        uid: 'u-reg',
        fullName: 'Registrar Staff',
        email: 'reg@example.com',
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

      await tester.enterText(
        find.byType(TextFormField).first,
        'reg@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'secret123');

      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      expect(find.text('Registrar Dashboard'), findsOneWidget);
    });
  });

  group('LoginScreen Error Handling', () {
    testWidgets('invalid credentials shows error snackbar', (tester) async {
      fakeRepo.exceptionToThrow = const AuthException(
        code: AuthErrorCode.invalidCredentials,
        message: 'Invalid email or password.',
      );

      await pumpScreen(tester);

      await tester.enterText(
        find.byType(TextFormField).first,
        'user@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'wrongpass');

      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid email or password.'), findsOneWidget);
    });

    testWidgets('pending faculty shows pending approval message', (
      tester,
    ) async {
      fakeRepo.exceptionToThrow = const AuthException(
        code: AuthErrorCode.pendingApproval,
        message: 'Your account is pending admin approval.',
      );

      await pumpScreen(tester);

      await tester.enterText(
        find.byType(TextFormField).first,
        'pending@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'secret123');

      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      expect(
        find.text('Your account is pending admin approval.'),
        findsOneWidget,
      );
    });

    testWidgets('rejected faculty shows rejection message', (tester) async {
      fakeRepo.exceptionToThrow = const AuthException(
        code: AuthErrorCode.accountRejected,
        message: 'Your account has been rejected.',
      );

      await pumpScreen(tester);

      await tester.enterText(
        find.byType(TextFormField).first,
        'rejected@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'secret123');

      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      expect(find.text('Your account has been rejected.'), findsOneWidget);
    });

    testWidgets('inactive account shows inactive message', (tester) async {
      fakeRepo.exceptionToThrow = const AuthException(
        code: AuthErrorCode.accountInactive,
        message: 'Your account is currently inactive.',
      );

      await pumpScreen(tester);

      await tester.enterText(
        find.byType(TextFormField).first,
        'inactive@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'secret123');

      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      expect(find.text('Your account is currently inactive.'), findsOneWidget);
    });
  });

  group('LoginScreen Loading & Multiple Submissions', () {
    testWidgets('shows loading indicator and prevents duplicate submissions', (
      tester,
    ) async {
      fakeRepo.loginCompleter = Completer<UserModel>();

      await pumpScreen(tester);

      await tester.enterText(
        find.byType(TextFormField).first,
        'user@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'secret123');

      // First tap -> starts login
      await tester.tap(find.text('Login'));
      await tester.pump();

      // Expect CircularProgressIndicator to be shown
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(fakeRepo.loginCalls, 1);

      // Attempt second tap while still loading -> should be ignored
      await tester.tap(find.byType(CircularProgressIndicator));
      await tester.pump();
      expect(fakeRepo.loginCalls, 1);

      // Resolve the login
      fakeRepo.loginCompleter!.complete(
        UserModel(
          uid: 'u-1',
          fullName: 'User',
          email: 'user@example.com',
          employeeId: 'EMP001',
          departmentId: 'cs',
          departmentName: 'CS',
          designation: 'Lecturer',
          role: AppStrings.roleFaculty,
          isActive: true,
          approvalStatus: 'approved',
          createdAt: DateTime(2025, 1, 1),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Faculty Dashboard'), findsOneWidget);
    });
  });

  group('LoginScreen Google Sign-In', () {
    testWidgets(
      'approved faculty signs in with Google and routes to dashboard',
      (tester) async {
        fakeRepo.mockUserToReturn = UserModel(
          uid: 'g-fac',
          fullName: 'Google Faculty',
          email: 'faculty@google.com',
          employeeId: 'EMP001',
          departmentId: 'cs',
          departmentName: 'CS',
          designation: 'Lecturer',
          role: AppStrings.roleFaculty,
          isActive: true,
          approvalStatus: 'approved',
          createdAt: DateTime(2025, 1, 1),
        );

        await pumpScreen(tester);

        await tester.tap(find.text('Continue with Google'));
        await tester.pumpAndSettle();

        expect(find.text('Faculty Dashboard'), findsOneWidget);
        expect(fakeRepo.googleCalls, 1);
      },
    );

    testWidgets('admin signs in with Google and routes to admin dashboard', (
      tester,
    ) async {
      fakeRepo.mockUserToReturn = UserModel(
        uid: 'g-admin',
        fullName: 'Google Admin',
        email: 'admin@google.com',
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

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(find.text('Admin Dashboard'), findsOneWidget);
      expect(fakeRepo.googleCalls, 1);
    });

    testWidgets('head signs in with Google and routes to head dashboard', (
      tester,
    ) async {
      fakeRepo.mockUserToReturn = UserModel(
        uid: 'g-head',
        fullName: 'Google Head',
        email: 'head@google.com',
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

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(find.text('Head Dashboard'), findsOneWidget);
      expect(fakeRepo.googleCalls, 1);
    });

    testWidgets(
      'registrar signs in with Google and routes to registrar dashboard',
      (tester) async {
        fakeRepo.mockUserToReturn = UserModel(
          uid: 'g-reg',
          fullName: 'Google Registrar',
          email: 'reg@google.com',
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

        await tester.tap(find.text('Continue with Google'));
        await tester.pumpAndSettle();

        expect(find.text('Registrar Dashboard'), findsOneWidget);
        expect(fakeRepo.googleCalls, 1);
      },
    );

    testWidgets('user cancels Google sign-in without error snackbar', (
      tester,
    ) async {
      fakeRepo.googleExceptionToThrow = const AuthException(
        code: AuthErrorCode.googleSignInCancelled,
        message: 'Google Sign-In was cancelled.',
      );

      await pumpScreen(tester);

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(find.text('Google Sign-In was cancelled.'), findsNothing);
      expect(fakeRepo.googleCalls, 1);
    });

    testWidgets('google authentication failure displays error snackbar', (
      tester,
    ) async {
      fakeRepo.googleExceptionToThrow = const AuthException(
        code: AuthErrorCode.googleSignInFailed,
        message: 'Google Sign-In failed. Please try again.',
      );

      await pumpScreen(tester);

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(
        find.text('Google Sign-In failed. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets('missing ID token displays error snackbar', (tester) async {
      fakeRepo.googleExceptionToThrow = const AuthException(
        code: AuthErrorCode.missingIdToken,
        message: 'Google authentication failed: ID token is missing.',
      );

      await pumpScreen(tester);

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(
        find.text('Google authentication failed: ID token is missing.'),
        findsOneWidget,
      );
    });

    testWidgets('missing profile guides user to registration', (tester) async {
      fakeRepo.googleExceptionToThrow = const AuthException(
        code: AuthErrorCode.googleNoAccount,
        message:
            'No account found for this Google identity. Please register first.',
      );

      await pumpScreen(tester);

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'No account found for this Google identity. Please register first.',
        ),
        findsOneWidget,
      );
      // Navigates to RegisterScreen
      expect(find.text('Create Your Account'), findsOneWidget);
    });

    testWidgets('pending Google faculty shows pending approval message', (
      tester,
    ) async {
      fakeRepo.googleExceptionToThrow = const AuthException(
        code: AuthErrorCode.pendingApproval,
        message: 'Your account is pending admin approval.',
      );

      await pumpScreen(tester);

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(
        find.text('Your account is pending admin approval.'),
        findsOneWidget,
      );
    });

    testWidgets('rejected Google faculty shows rejection message', (
      tester,
    ) async {
      fakeRepo.googleExceptionToThrow = const AuthException(
        code: AuthErrorCode.accountRejected,
        message: 'Your account has been rejected.',
      );

      await pumpScreen(tester);

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(find.text('Your account has been rejected.'), findsOneWidget);
    });

    testWidgets('inactive Google account shows inactive message', (
      tester,
    ) async {
      fakeRepo.googleExceptionToThrow = const AuthException(
        code: AuthErrorCode.accountInactive,
        message: 'Your account is currently inactive.',
      );

      await pumpScreen(tester);

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(find.text('Your account is currently inactive.'), findsOneWidget);
    });

    testWidgets('account linking conflict displays error message', (
      tester,
    ) async {
      fakeRepo.googleExceptionToThrow = const AuthException(
        code: AuthErrorCode.credentialAlreadyInUse,
        message:
            'An account already exists with this email using a different sign-in method.',
      );

      await pumpScreen(tester);

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'An account already exists with this email using a different sign-in method.',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'google loading state shows indicator and prevents duplicate taps',
      (tester) async {
        fakeRepo.googleCompleter = Completer<UserModel>();

        await pumpScreen(tester);

        // Tap Google button
        await tester.tap(find.text('Continue with Google'));
        await tester.pump();

        // Expect CircularProgressIndicator to be shown
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(fakeRepo.googleCalls, 1);

        // Attempt second tap while still loading -> ignored
        await tester.tap(find.byType(CircularProgressIndicator));
        await tester.pump();
        expect(fakeRepo.googleCalls, 1);

        // Also tap email login while Google is loading -> ignored
        await tester.tap(find.text('Login'));
        await tester.pump();
        expect(fakeRepo.loginCalls, 0);

        // Complete Google sign-in
        fakeRepo.googleCompleter!.complete(
          UserModel(
            uid: 'g-1',
            fullName: 'Google User',
            email: 'user@google.com',
            employeeId: 'EMP001',
            departmentId: 'cs',
            departmentName: 'CS',
            designation: 'Lecturer',
            role: AppStrings.roleFaculty,
            isActive: true,
            approvalStatus: 'approved',
            createdAt: DateTime(2025, 1, 1),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Faculty Dashboard'), findsOneWidget);
      },
    );
  });
}
