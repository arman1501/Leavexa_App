// ─────────────────────────────────────────────────────────────────────────────
//  register_screen_test.dart  –  Widget & flow tests for RegisterScreen (Phase 3)
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:leavexa/models/registration_state.dart';
import 'package:leavexa/repositories/auth_repository.dart';
import 'package:leavexa/screens/auth/register_screen.dart';
import 'package:leavexa/services/auth_exception.dart';

class FakeRegisterAuthRepository extends AuthRepository {
  AuthException? exceptionToThrow;
  Exception? genericExceptionToThrow;
  int registerCalls = 0;
  Completer<void>? registerCompleter;

  String? lastFullName;
  String? lastEmployeeId;
  String? lastEmail;
  String? lastPhone;
  String? lastDepartmentName;
  String? lastDesignation;
  String? lastPassword;

  @override
  Future<void> registerFaculty({
    required String fullName,
    required String employeeId,
    required String email,
    required String phone,
    required String departmentName,
    required String designation,
    required String password,
    void Function(RegistrationState state)? onStateChanged,
  }) async {
    registerCalls++;
    lastFullName = fullName;
    lastEmployeeId = employeeId;
    lastEmail = email;
    lastPhone = phone;
    lastDepartmentName = departmentName;
    lastDesignation = designation;
    lastPassword = password;

    if (registerCompleter != null) {
      await registerCompleter!.future;
      return;
    }
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    if (genericExceptionToThrow != null) {
      throw genericExceptionToThrow!;
    }
  }
}

Widget buildTestApp(Widget screen) {
  return MaterialApp(home: screen);
}

void main() {
  late FakeRegisterAuthRepository fakeRepo;

  setUp(() {
    fakeRepo = FakeRegisterAuthRepository();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      buildTestApp(RegisterScreen(authRepository: fakeRepo)),
    );
    await tester.pumpAndSettle();
  }

  group('RegisterScreen Form Validation', () {
    testWidgets('empty required fields trigger validation errors', (
      tester,
    ) async {
      await pumpScreen(tester);

      final registerBtn = find.text('Create Account');
      await tester.tap(registerBtn);
      await tester.pump();

      expect(find.text('Please enter your full name'), findsOneWidget);
      expect(find.text('Please enter your employee ID'), findsOneWidget);
      expect(find.text('Please enter your university email'), findsOneWidget);
      expect(find.text('Please enter your phone number'), findsOneWidget);
      expect(find.text('Please enter a password'), findsOneWidget);
      expect(find.text('Please confirm your password'), findsOneWidget);
      expect(fakeRepo.registerCalls, 0);
    });

    testWidgets('invalid email format triggers validation error', (
      tester,
    ) async {
      await pumpScreen(tester);

      final emailField = find.byType(TextFormField).at(2);
      await tester.enterText(emailField, 'notanemail');

      final registerBtn = find.text('Create Account');
      await tester.tap(registerBtn);
      await tester.pump();

      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(fakeRepo.registerCalls, 0);
    });

    testWidgets('password mismatch triggers validation error', (tester) async {
      await pumpScreen(tester);

      // Full Name
      await tester.enterText(find.byType(TextFormField).at(0), 'John Doe');
      // Employee ID
      await tester.enterText(find.byType(TextFormField).at(1), 'EMP100');
      // Email
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'john@university.edu',
      );
      // Phone
      await tester.enterText(find.byType(TextFormField).at(3), '01700000000');
      // Password
      await tester.enterText(find.byType(TextFormField).at(4), 'password123');
      // Confirm Password (mismatch)
      await tester.enterText(
        find.byType(TextFormField).at(5),
        'differentpassword',
      );

      final registerBtn = find.text('Create Account');
      await tester.tap(registerBtn);
      await tester.pump();

      expect(find.text('Passwords do not match'), findsOneWidget);
      expect(fakeRepo.registerCalls, 0);
    });

    testWidgets('weak password (< 6 chars) triggers validation error', (
      tester,
    ) async {
      await pumpScreen(tester);

      final passField = find.byType(TextFormField).at(4);
      await tester.enterText(passField, '123');

      final registerBtn = find.text('Create Account');
      await tester.tap(registerBtn);
      await tester.pump();

      expect(
        find.text('Password must be at least 6 characters.'),
        findsOneWidget,
      );
      expect(fakeRepo.registerCalls, 0);
    });
  });

  group('RegisterScreen Submission & Success', () {
    Future<void> fillValidForm(WidgetTester tester) async {
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Dr. Alice Smith',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'EMP200');
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'alice@university.edu',
      );
      await tester.enterText(find.byType(TextFormField).at(3), '01711111111');
      await tester.enterText(find.byType(TextFormField).at(4), 'securePass123');
      await tester.enterText(find.byType(TextFormField).at(5), 'securePass123');

      // Select Department
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Computer Science & Engineering').last);
      await tester.pumpAndSettle();

      // Select Designation
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Assistant Professor').last);
      await tester.pumpAndSettle();

      // Tap Terms Checkbox
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
    }

    testWidgets('successful registration shows pending approval message', (
      tester,
    ) async {
      await pumpScreen(tester);
      await fillValidForm(tester);

      final registerBtn = find.text('Create Account');
      await tester.tap(registerBtn);
      await tester.pump();

      expect(fakeRepo.registerCalls, 1);
      expect(fakeRepo.lastFullName, 'Dr. Alice Smith');
      expect(fakeRepo.lastEmployeeId, 'EMP200');
      expect(fakeRepo.lastEmail, 'alice@university.edu');

      // Check success SnackBar
      expect(
        find.text(
          'Registration successful! Your account is pending admin approval.',
        ),
        findsOneWidget,
      );

      await tester.pumpAndSettle();
    });

    testWidgets('duplicate email error displays error message', (tester) async {
      fakeRepo.exceptionToThrow = const AuthException(
        code: AuthErrorCode.emailAlreadyInUse,
        message: 'This email is already registered.',
      );

      await pumpScreen(tester);
      await fillValidForm(tester);

      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      expect(find.text('This email is already registered.'), findsOneWidget);
    });

    testWidgets('duplicate employee ID error displays error message', (
      tester,
    ) async {
      fakeRepo.exceptionToThrow = const AuthException(
        code: AuthErrorCode.duplicateEmployeeId,
        message: 'This Employee ID is already registered.',
      );

      await pumpScreen(tester);
      await fillValidForm(tester);

      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      expect(
        find.text('This Employee ID is already registered.'),
        findsOneWidget,
      );
    });

    testWidgets('firestore write failure displays error message', (
      tester,
    ) async {
      fakeRepo.exceptionToThrow = const AuthException(
        code: AuthErrorCode.networkError,
        message: 'Network error. Please check your connection.',
      );

      await pumpScreen(tester);
      await fillValidForm(tester);

      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      expect(
        find.text('Network error. Please check your connection.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'loading state displays indicator and prevents duplicate submissions',
      (tester) async {
        fakeRepo.registerCompleter = Completer<void>();

        await pumpScreen(tester);
        await fillValidForm(tester);

        // Tap button once
        await tester.tap(find.text('Create Account'));
        await tester.pump();

        // Expect circular progress indicator
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(fakeRepo.registerCalls, 1);

        // Tap button second time while still loading
        await tester.tap(find.byType(CircularProgressIndicator));
        await tester.pump();
        expect(fakeRepo.registerCalls, 1);

        // Complete registration
        fakeRepo.registerCompleter!.complete();
        await tester.pump();

        expect(
          find.text(
            'Registration successful! Your account is pending admin approval.',
          ),
          findsOneWidget,
        );

        await tester.pumpAndSettle();
      },
    );
  });
}
