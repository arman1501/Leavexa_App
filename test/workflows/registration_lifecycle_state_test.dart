// ─────────────────────────────────────────────────────────────────────────────
//  registration_lifecycle_state_test.dart
//  Tests the RegistrationState machine, transitions, form retention, and UI states
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:leavexa/models/registration_state.dart';
import 'package:leavexa/repositories/auth_repository.dart';
import 'package:leavexa/screens/auth/register_screen.dart';
import 'package:leavexa/services/auth_exception.dart';

class StateTrackingAuthRepository extends AuthRepository {
  final List<RegistrationStep> observedSteps = [];
  AuthException? errorToThrow;
  Completer<void>? stallCompleter;
  int submissionCount = 0;

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
    submissionCount++;

    void notify(RegistrationStep step) {
      observedSteps.add(step);
      onStateChanged?.call(RegistrationState(step: step));
    }

    notify(RegistrationStep.validating);
    notify(RegistrationStep.checking);
    notify(RegistrationStep.creatingAuth);

    if (stallCompleter != null) {
      await stallCompleter!.future;
    }

    if (errorToThrow != null) {
      final isRecoverable = errorToThrow!.code == AuthErrorCode.networkError;
      final failedStep = isRecoverable
          ? RegistrationStep.recoverableFailure
          : RegistrationStep.permanentFailure;
      observedSteps.add(failedStep);
      onStateChanged?.call(RegistrationState(
        step: failedStep,
        message: errorToThrow!.message,
        errorCode: errorToThrow!.code,
        isRecoverable: isRecoverable,
      ));
      throw errorToThrow!;
    }

    notify(RegistrationStep.creatingProfile);
    notify(RegistrationStep.completed);
  }
}

Widget buildTestApp(Widget screen) {
  return MaterialApp(home: screen);
}

void main() {
  late StateTrackingAuthRepository fakeRepo;

  setUp(() {
    fakeRepo = StateTrackingAuthRepository();
  });

  Future<void> fillValidForm(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildTestApp(RegisterScreen(authRepository: fakeRepo)));
    await tester.pumpAndSettle();

    // Fill valid values
    await tester.enterText(find.byType(TextFormField).at(0), 'Dr. Test Faculty');
    await tester.enterText(find.byType(TextFormField).at(1), 'LU-099');
    await tester.enterText(find.byType(TextFormField).at(2), 'faculty.test@leavexa.edu');
    await tester.enterText(find.byType(TextFormField).at(3), '01711111111');
    await tester.enterText(find.byType(TextFormField).at(4), 'Password123!');
    await tester.enterText(find.byType(TextFormField).at(5), 'Password123!');

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

    // Agree to terms
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
  }

  group('Registration Lifecycle & State Machine Verification', () {
    testWidgets('1. Transitions through validating -> checking -> creatingAuth -> creatingProfile -> completed', (tester) async {
      await fillValidForm(tester);

      await tester.tap(find.text('Create Account'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(fakeRepo.observedSteps, containsAllInOrder([
        RegistrationStep.validating,
        RegistrationStep.checking,
        RegistrationStep.creatingAuth,
        RegistrationStep.creatingProfile,
        RegistrationStep.completed,
      ]));
      expect(find.text('Registration successful! Your account is pending admin approval.'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 3));
    });

    testWidgets('2. Double submission is blocked while registration is in progress', (tester) async {
      fakeRepo.stallCompleter = Completer<void>();
      await fillValidForm(tester);

      // Tap once
      await tester.tap(find.text('Create Account'));
      await tester.pump();

      // Tap again while in flight
      await tester.tap(find.byType(CircularProgressIndicator));
      await tester.pump();

      expect(fakeRepo.submissionCount, 1, reason: 'Only one submission must execute');

      // Complete the stall
      fakeRepo.stallCompleter!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('3. Recoverable network failure preserves form data for retry', (tester) async {
      fakeRepo.errorToThrow = const AuthException(
        code: AuthErrorCode.networkError,
        message: 'Unable to connect. Check your internet and try again.',
      );
      await fillValidForm(tester);

      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      expect(find.text('Unable to connect. Check your internet and try again.'), findsOneWidget);

      // Form data is completely intact
      expect(find.text('Dr. Test Faculty'), findsOneWidget);
      expect(find.text('LU-099'), findsOneWidget);
      expect(find.text('faculty.test@leavexa.edu'), findsOneWidget);
      expect(find.text('01711111111'), findsOneWidget);

      // User retries
      fakeRepo.errorToThrow = null;
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      expect(fakeRepo.submissionCount, 2, reason: 'Retry executes successfully');
      expect(fakeRepo.observedSteps.last, RegistrationStep.completed);
      await tester.pumpAndSettle(const Duration(seconds: 3));
    });

    testWidgets('4. Permanent duplicate employee ID error displays clear error and retains form', (tester) async {
      fakeRepo.errorToThrow = const AuthException(
        code: AuthErrorCode.duplicateEmployeeId,
        message: 'This Employee ID is already registered.',
      );
      await fillValidForm(tester);

      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      expect(find.text('This Employee ID is already registered.'), findsOneWidget);

      // Form is still populated
      expect(find.text('LU-099'), findsOneWidget);
      expect(fakeRepo.observedSteps, contains(RegistrationStep.permanentFailure));
    });
  });
}
