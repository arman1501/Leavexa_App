// ─────────────────────────────────────────────────────────────────────────────
//  app_routes.dart  –  Named Route Definitions
// ─────────────────────────────────────────────────────────────────────────────

class AppRoutes {
  AppRoutes._();

  // ── Core ───────────────────────────────────────────────────────────────────
  static const String splash           = '/';
  static const String login            = '/login';
  static const String register         = '/register';

  // ── Faculty ────────────────────────────────────────────────────────────────
  static const String facultyDashboard = '/faculty/dashboard';
  static const String applyLeave       = '/faculty/apply-leave';
  static const String myLeaves         = '/faculty/my-leaves';
  static const String leaveDetails     = '/faculty/leave-details';
  static const String notifications    = '/faculty/notifications';
  static const String profile          = '/faculty/profile';
  static const String editProfile      = '/faculty/edit-profile';
  static const String settings         = '/faculty/settings';

  // ── Department Head ────────────────────────────────────────────────────────
  static const String headDashboard    = '/head/dashboard';
  static const String leaveRequestDetails = '/head/leave-request-details';
  static const String deptCalendar     = '/head/dept-calendar';

  // ── Registrar ──────────────────────────────────────────────────────────────
  static const String registrarDashboard = '/registrar/dashboard';
  static const String allLeaveRequests   = '/registrar/all-requests';
  static const String finalApproval      = '/registrar/final-approval';
}
