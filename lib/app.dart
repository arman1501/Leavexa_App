// ─────────────────────────────────────────────────────────────────────────────
//  app.dart  –  Root MaterialApp with Theme & Routes
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_routes.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/faculty/faculty_dashboard.dart';
import 'screens/faculty/my_leaves_screen.dart';
import 'screens/faculty/apply_leave_screen.dart';
import 'screens/faculty/profile_screen.dart';
import 'screens/faculty/edit_profile_screen.dart';
import 'screens/faculty/settings_screen.dart';

class LeavexaApp extends StatelessWidget {
  const LeavexaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeState.instance.themeModeNotifier,
      builder: (context, themeMode, child) {
        return MaterialApp(
          title: 'Leavexa',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          initialRoute: AppRoutes.splash,
          routes: {
            AppRoutes.splash:           (_) => const SplashScreen(),
            AppRoutes.login:            (_) => const LoginScreen(),
            AppRoutes.register:         (_) => const RegisterScreen(),
            AppRoutes.facultyDashboard: (_) => const FacultyDashboard(),
            AppRoutes.myLeaves:         (_) => const MyLeavesScreen(),
            AppRoutes.applyLeave:        (_) => const ApplyLeaveScreen(),
            AppRoutes.profile:          (_) => const ProfileScreen(),
            AppRoutes.editProfile:      (_) => const EditProfileScreen(),
            AppRoutes.settings:         (_) => const SettingsScreen(),
          },
        );
      },
    );
  }
}
