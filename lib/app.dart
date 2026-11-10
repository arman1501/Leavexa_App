// ─────────────────────────────────────────────────────────────────────────────
//  app.dart  –  Root MaterialApp with Theme & Routes
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_routes.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/faculty/faculty_dashboard.dart';
import 'screens/faculty/my_leaves_screen.dart';
import 'screens/faculty/apply_leave_screen.dart';
import 'screens/faculty/leave_details_screen.dart';
import 'screens/faculty/notifications_screen.dart';
import 'screens/faculty/profile_screen.dart';
import 'screens/faculty/edit_profile_screen.dart';
import 'screens/faculty/settings_screen.dart';
import 'screens/head/head_dashboard.dart';
import 'screens/head/head_profile_screen.dart';
import 'screens/head/head_leave_request_screen.dart';
import 'screens/head/dept_calendar_screen.dart';
import 'screens/head/head_requests_screen.dart';
import 'screens/head/head_request_details_screen.dart';
import 'screens/head/head_review_request_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/admin/admin_profile_screen.dart';
import 'screens/registrar/all_leave_requests.dart';
import 'screens/registrar/final_approval_screen.dart';
import 'screens/registrar/registrar_dashboard.dart';
import 'services/fcm_service.dart';

class LeavexaApp extends StatelessWidget {
  const LeavexaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeState.instance.themeModeNotifier,
      builder: (context, themeMode, child) {
        return MaterialApp(
          navigatorKey: FcmService.navigatorKey,
          title: 'Leavexa',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          initialRoute: AppRoutes.splash,
          routes: {
            AppRoutes.splash: (_) => const SplashScreen(),
            AppRoutes.login: (_) => const LoginScreen(),
            AppRoutes.register: (_) => const RegisterScreen(),
            AppRoutes.forgotPassword: (_) => const ForgotPasswordScreen(),
            AppRoutes.facultyDashboard: (_) => const FacultyDashboard(),
            AppRoutes.myLeaves: (_) => const MyLeavesScreen(),
            AppRoutes.leaveDetails: (_) => const LeaveDetailsScreen(),
            AppRoutes.applyLeave: (_) => const ApplyLeaveScreen(),
            AppRoutes.notifications: (_) => const NotificationsScreen(),
            AppRoutes.profile: (_) => const ProfileScreen(),
            AppRoutes.editProfile: (_) => const EditProfileScreen(),
            AppRoutes.settings: (_) => const SettingsScreen(),
            AppRoutes.headDashboard: (_) => const HeadDashboard(),
            AppRoutes.headProfile: (_) => const HeadProfileScreen(),
            AppRoutes.headRequests: (_) => const HeadRequestsScreen(),
            AppRoutes.headRequestDetails: (_) =>
                const HeadRequestDetailsScreen(),
            AppRoutes.headReviewRequest: (_) => const HeadReviewRequestScreen(),
            AppRoutes.leaveRequestDetails: (_) =>
                const HeadLeaveRequestScreen(),
            AppRoutes.deptCalendar: (_) => const DeptCalendarScreen(),
            AppRoutes.adminDashboard: (_) => const AdminDashboard(),
            AppRoutes.adminProfile: (_) => const AdminProfileScreen(),
            AppRoutes.registrarDashboard: (_) => const RegistrarDashboard(),
            AppRoutes.allLeaveRequests: (_) => const AllLeaveRequestsScreen(),
            AppRoutes.finalApproval: (_) => const FinalApprovalScreen(),
          },
        );
      },
    );
  }
}
