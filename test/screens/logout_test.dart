// ─────────────────────────────────────────────────────────────────────────────
//  logout_test.dart  –  Widget & flow tests for Logout across all roles (Phase 7)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:leavexa/core/routes/app_routes.dart';
import 'package:leavexa/core/theme/app_theme.dart';
import 'package:leavexa/models/faculty_profile_state.dart';
import 'package:leavexa/repositories/auth_repository.dart';
import 'package:leavexa/screens/admin/admin_profile_screen.dart';
import 'package:leavexa/screens/faculty/settings_screen.dart';
import 'package:leavexa/screens/head/head_profile_screen.dart';
import 'package:leavexa/screens/registrar/registrar_dashboard.dart';

class FakeLogoutAuthRepository extends AuthRepository {
  int logoutCalls = 0;
  Exception? exceptionToThrow;

  @override
  Future<void> logout() async {
    logoutCalls++;
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
  }
}

Widget buildTestApp(Widget screen) {
  return MaterialApp(
    routes: {
      '/': (_) => screen,
      AppRoutes.login: (_) => const Scaffold(body: Text('Login Screen')),
    },
  );
}

void main() {
  late FakeLogoutAuthRepository fakeRepo;

  setUp(() {
    fakeRepo = FakeLogoutAuthRepository();
    AppThemeState.instance.resetToLightMode();
    FacultyProfileState.instance.reset();
  });

  tearDown(() {
    AppThemeState.instance.resetToLightMode();
    FacultyProfileState.instance.reset();
  });

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildTestApp(screen));
    await tester.pumpAndSettle();
  }

  group('Faculty SettingsScreen Logout', () {
    testWidgets('shows confirmation dialog on tap and dismisses on Cancel', (
      tester,
    ) async {
      await pumpScreen(tester, SettingsScreen(authRepository: fakeRepo));

      // Scroll down to ACCOUNT section
      await tester.scrollUntilVisible(find.text('Logout'), 200.0);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();

      expect(find.text('Log Out'), findsWidgets);
      expect(
        find.text('Are you sure you want to log out of your Leavexa account?'),
        findsOneWidget,
      );

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(
        find.text('Are you sure you want to log out of your Leavexa account?'),
        findsNothing,
      );
      expect(fakeRepo.logoutCalls, 0);
    });

    testWidgets(
      'calls repository logout, resets theme & profile, navigates to login',
      (tester) async {
        AppThemeState.instance.toggleTheme(true); // Set to dark mode
        FacultyProfileState.instance.updateProfile(fullName: 'Modified User');

        await pumpScreen(tester, SettingsScreen(authRepository: fakeRepo));

        await tester.scrollUntilVisible(find.text('Logout'), 200.0);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Logout'));
        await tester.pumpAndSettle();

        // Tap Yes, Log Out
        await tester.tap(find.text('Yes, Log Out'));
        await tester.pumpAndSettle();

        expect(fakeRepo.logoutCalls, 1);
        expect(AppThemeState.instance.themeModeNotifier.value, ThemeMode.light);
        expect(
          FacultyProfileState.instance.notifier.value.fullName,
          'Md. Arman',
        );
        expect(find.text('Login Screen'), findsOneWidget);
      },
    );

    testWidgets('handles logout failure gracefully and displays SnackBar', (
      tester,
    ) async {
      fakeRepo.exceptionToThrow = Exception('Network logout failed');

      await pumpScreen(tester, SettingsScreen(authRepository: fakeRepo));

      await tester.scrollUntilVisible(find.text('Logout'), 200.0);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Yes, Log Out'));
      await tester.pumpAndSettle();

      expect(fakeRepo.logoutCalls, 1);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Failed to log out'), findsOneWidget);
      expect(find.text('Login Screen'), findsNothing);
    });
  });

  group('Department Head HeadProfileScreen Logout', () {
    testWidgets('shows confirmation dialog on tap and dismisses on Cancel', (
      tester,
    ) async {
      await pumpScreen(tester, HeadProfileScreen(authRepository: fakeRepo));

      await tester.scrollUntilVisible(
        find.text('Log Out of Head Portal'),
        200.0,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Log Out of Head Portal'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Are you sure you want to log out of Department Head Portal?',
        ),
        findsOneWidget,
      );

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Are you sure you want to log out of Department Head Portal?',
        ),
        findsNothing,
      );
      expect(fakeRepo.logoutCalls, 0);
    });

    testWidgets(
      'calls repository logout, resets theme & profile, navigates to login',
      (tester) async {
        AppThemeState.instance.toggleTheme(true);

        await pumpScreen(tester, HeadProfileScreen(authRepository: fakeRepo));

        await tester.scrollUntilVisible(
          find.text('Log Out of Head Portal'),
          200.0,
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Log Out of Head Portal'));
        await tester.pumpAndSettle();

        // Tap Log Out inside dialog
        await tester.tap(find.widgetWithText(ElevatedButton, 'Log Out'));
        await tester.pumpAndSettle();

        expect(fakeRepo.logoutCalls, 1);
        expect(AppThemeState.instance.themeModeNotifier.value, ThemeMode.light);
        expect(find.text('Login Screen'), findsOneWidget);
      },
    );

    testWidgets('handles logout failure gracefully and displays SnackBar', (
      tester,
    ) async {
      fakeRepo.exceptionToThrow = Exception('SignOut timeout');

      await pumpScreen(tester, HeadProfileScreen(authRepository: fakeRepo));

      await tester.scrollUntilVisible(
        find.text('Log Out of Head Portal'),
        200.0,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Log Out of Head Portal'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Log Out'));
      await tester.pumpAndSettle();

      expect(fakeRepo.logoutCalls, 1);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Failed to log out'), findsOneWidget);
      expect(find.text('Login Screen'), findsNothing);
    });
  });

  group('Admin & Registrar AdminProfileScreen Logout', () {
    testWidgets('shows confirmation dialog on tap and dismisses on Cancel', (
      tester,
    ) async {
      await pumpScreen(tester, AdminProfileScreen(authRepository: fakeRepo));

      await tester.scrollUntilVisible(
        find.text('Log Out of Admin Portal'),
        200.0,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Log Out of Admin Portal'));
      await tester.pumpAndSettle();

      expect(find.text('Log Out'), findsWidgets);
      expect(
        find.text(
          'Are you sure you want to log out of the Administrator Portal?',
        ),
        findsOneWidget,
      );

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Are you sure you want to log out of the Administrator Portal?',
        ),
        findsNothing,
      );
      expect(fakeRepo.logoutCalls, 0);
    });

    testWidgets(
      'calls repository logout, resets theme & profile, navigates to login',
      (tester) async {
        AppThemeState.instance.toggleTheme(true);

        await pumpScreen(tester, AdminProfileScreen(authRepository: fakeRepo));

        await tester.scrollUntilVisible(
          find.text('Log Out of Admin Portal'),
          200.0,
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Log Out of Admin Portal'));
        await tester.pumpAndSettle();

        // Tap Log Out inside dialog
        await tester.tap(find.widgetWithText(ElevatedButton, 'Log Out'));
        await tester.pumpAndSettle();

        expect(fakeRepo.logoutCalls, 1);
        expect(AppThemeState.instance.themeModeNotifier.value, ThemeMode.light);
        expect(find.text('Login Screen'), findsOneWidget);
      },
    );

    testWidgets('handles logout failure gracefully and displays SnackBar', (
      tester,
    ) async {
      fakeRepo.exceptionToThrow = Exception('Firebase logout blocked');

      await pumpScreen(tester, AdminProfileScreen(authRepository: fakeRepo));

      await tester.scrollUntilVisible(
        find.text('Log Out of Admin Portal'),
        200.0,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Log Out of Admin Portal'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Log Out'));
      await tester.pumpAndSettle();

      expect(fakeRepo.logoutCalls, 1);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Failed to log out'), findsOneWidget);
      expect(find.text('Login Screen'), findsNothing);
    });
  });

  group('Registrar Dashboard Architecture', () {
    testWidgets(
      'RegistrarDashboard renders dedicated console cleanly without Admin UI',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(buildTestApp(const RegistrarDashboard()));
        await tester.pump();
        expect(find.byType(RegistrarDashboard), findsOneWidget);
        expect(find.text('Registrar Dashboard'), findsOneWidget);
        expect(find.text('Create Staff Account (Head / Registrar)'), findsNothing);
      },
    );
  });
}
