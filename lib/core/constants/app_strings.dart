// ─────────────────────────────────────────────────────────────────────────────
//  app_strings.dart  –  Leavexa App-wide String Constants
// ─────────────────────────────────────────────────────────────────────────────

class AppStrings {
  AppStrings._();

  // ── App ────────────────────────────────────────────────────────────────────
  static const String appName        = 'Leavexa';
  static const String appTagline     = 'Smart Faculty Leave Management';

  // ── Auth ───────────────────────────────────────────────────────────────────
  static const String login          = 'Login';
  static const String register       = 'Register';
  static const String logout         = 'Logout';
  static const String email          = 'Email';
  static const String password       = 'Password';
  static const String confirmPassword= 'Confirm Password';
  static const String forgotPassword = 'Forgot Password?';
  static const String fullName       = 'Full Name';
  static const String employeeId     = 'Employee ID';
  static const String department     = 'Department';
  static const String role           = 'Role';

  // ── Leave ──────────────────────────────────────────────────────────────────
  static const String applyLeave     = 'Apply for Leave';
  static const String myLeaves       = 'My Leaves';
  static const String leaveBalance   = 'Leave Balance';
  static const String leaveType      = 'Leave Type';
  static const String startDate      = 'Start Date';
  static const String endDate        = 'End Date';
  static const String reason         = 'Reason';
  static const String attachDocument = 'Attach Document';
  static const String submitRequest  = 'Submit Request';
  static const String leaveDetails   = 'Leave Details';

  // ── Status Labels ──────────────────────────────────────────────────────────
  static const String pending        = 'Pending';
  static const String approved       = 'Approved';
  static const String rejected       = 'Rejected';
  static const String forwarded      = 'Forwarded';

  // ── Dashboard ──────────────────────────────────────────────────────────────
  static const String dashboard      = 'Dashboard';
  static const String notifications  = 'Notifications';
  static const String profile        = 'Profile';
  static const String editProfile    = 'Edit Profile';
  static const String leaveRequests  = 'Leave Requests';
  static const String allRequests    = 'All Requests';
  static const String deptCalendar   = 'Department Calendar';
  static const String finalApproval  = 'Final Approval';

  // ── Roles ──────────────────────────────────────────────────────────────────
  static const String roleFaculty    = 'faculty';
  static const String roleDeptHead   = 'department_head';
  static const String roleRegistrar  = 'registrar';

  // ── Common UI ──────────────────────────────────────────────────────────────
  static const String cancel         = 'Cancel';
  static const String confirm        = 'Confirm';
  static const String save           = 'Save';
  static const String update         = 'Update';
  static const String delete         = 'Delete';
  static const String noData         = 'No data available';
  static const String loading        = 'Loading…';
  static const String error          = 'Something went wrong. Please try again.';
  static const String success        = 'Done!';

  // ── Validation ─────────────────────────────────────────────────────────────
  static const String fieldRequired  = 'This field is required.';
  static const String invalidEmail   = 'Enter a valid email address.';
  static const String weakPassword   = 'Password must be at least 8 characters.';
  static const String passwordMismatch = 'Passwords do not match.';
}
