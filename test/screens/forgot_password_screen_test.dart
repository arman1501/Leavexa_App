// ─────────────────────────────────────────────────────────────────────────────
//  forgot_password_screen_test.dart  –  Widget & flow tests for ForgotPasswordScreen
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:leavexa/repositories/auth_repository.dart';
import 'package:leavexa/screens/auth/forgot_password_screen.dart';
import 'package:leavexa/services/auth_exception.dart';

class FakeForgotAuthRepository extends AuthRepository {
  AuthException? exceptionToThrow;
  Exception? genericExceptionToThrow;
  int forgotCalls = 0;
  String? lastEmail;
  Completer<void>? forgotCompleter;

  @override
  Future<void> forgotPassword(String email) async {
    forgotCalls++;
    lastEmail = email;

    if (forgotCompleter != null) {
      await forgotCompleter!.future;
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
  late FakeForgotAuthRepository fakeRepo;

  setUp(() {
    fakeRepo = FakeForgotAuthRepository();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      buildTestApp(ForgotPasswordScreen(authRepository: fakeRepo)),
    );
    await tester.pumpAndSettle();
  }

  group('ForgotPasswordScreen Validation', () {
    testWidgets('empty email triggers validation error', (tester) async {
      await pumpScreen(tester);

      final submitBtn = find.text('Send Reset Link');
      await tester.tap(submitBtn);
      await tester.pump();

      expect(find.text('Please enter your email'), findsOneWidget);
      expect(fakeRepo.forgotCalls, 0);
    });

    testWidgets('invalid email triggers validation error', (tester) async {
      await pumpScreen(tester);

      final emailField = find.byType(TextFormField);
      await tester.enterText(emailField, 'not-an-email');

      final submitBtn = find.text('Send Reset Link');
      await tester.tap(submitBtn);
      await tester.pump();

      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(fakeRepo.forgotCalls, 0);
    });
  });

  group('ForgotPasswordScreen Flow & Submission', () {
    testWidgets('valid email submits and shows success generic message', (
      tester,
    ) async {
      await pumpScreen(tester);

      final emailField = find.byType(TextFormField);
      await tester.enterText(emailField, 'user@university.edu');

      final submitBtn = find.text('Send Reset Link');
      await tester.tap(submitBtn);
      await tester.pump();

      expect(fakeRepo.forgotCalls, 1);
      expect(fakeRepo.lastEmail, 'user@university.edu');

      expect(
        find.text(
          'If an account exists with this email, a password reset link has been sent. Please check your inbox.',
        ),
        findsOneWidget,
      );

      // Button changes to "Resend Reset Link"
      expect(find.text('Resend Reset Link'), findsOneWidget);
    });

    testWidgets(
      'user not found returns generic response without leaking account status',
      (tester) async {
        // Per OWASP guidelines, non-existing email receives the same generic message
        await pumpScreen(tester);

        final emailField = find.byType(TextFormField);
        await tester.enterText(emailField, 'unknown@university.edu');

        final submitBtn = find.text('Send Reset Link');
        await tester.tap(submitBtn);
        await tester.pump();

        expect(fakeRepo.forgotCalls, 1);
        expect(
          find.text(
            'If an account exists with this email, a password reset link has been sent. Please check your inbox.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('network error displays error snackbar', (tester) async {
      fakeRepo.exceptionToThrow = const AuthException(
        code: AuthErrorCode.networkError,
        message: 'Network error. Please check your connection.',
      );

      await pumpScreen(tester);

      final emailField = find.byType(TextFormField);
      await tester.enterText(emailField, 'user@university.edu');

      final submitBtn = find.text('Send Reset Link');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(
        find.text('Network error. Please check your connection.'),
        findsOneWidget,
      );
    });

    testWidgets('too many requests displays rate limit snackbar', (
      tester,
    ) async {
      fakeRepo.exceptionToThrow = const AuthException(
        code: AuthErrorCode.tooManyRequests,
        message: 'Too many attempts. Please wait a moment and try again.',
      );

      await pumpScreen(tester);

      final emailField = find.byType(TextFormField);
      await tester.enterText(emailField, 'user@university.edu');

      final submitBtn = find.text('Send Reset Link');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(
        find.text('Too many attempts. Please wait a moment and try again.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'loading state displays indicator and prevents duplicate submissions',
      (tester) async {
        fakeRepo.forgotCompleter = Completer<void>();

        await pumpScreen(tester);

        final emailField = find.byType(TextFormField);
        await tester.enterText(emailField, 'user@university.edu');

        // First tap
        await tester.tap(find.text('Send Reset Link'));
        await tester.pump();

        // Expect progress indicator
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(fakeRepo.forgotCalls, 1);

        // Attempt second tap while still loading
        await tester.tap(find.byType(CircularProgressIndicator));
        await tester.pump();
        expect(fakeRepo.forgotCalls, 1);

        // Resolve completer
        fakeRepo.forgotCompleter!.complete();
        await tester.pumpAndSettle();

        expect(find.text('Resend Reset Link'), findsOneWidget);
      },
    );
  });
}
