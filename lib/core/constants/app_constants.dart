// ─────────────────────────────────────────────────────────────────────────────
//  app_constants.dart  –  Leavexa App-wide Non-string Constants
// ─────────────────────────────────────────────────────────────────────────────

class AppConstants {
  AppConstants._();

  // ── Assets ─────────────────────────────────────────────────────────────────
  static const String logoPath = 'assets/main_logo.png';

  // ── Firestore Collection Names ─────────────────────────────────────────────
  static const String usersCollection = 'users';
  static const String departmentsCollection = 'departments';
  static const String leaveTypesCollection = 'leave_types';
  static const String applicationsCollection = 'leave_applications';
  static const String balancesCollection = 'leave_balances';
  static const String notificationsCollection = 'notifications';
  static const String employeeIdsCollection = 'employee_ids';

  // ── Canonical Department Mapping ───────────────────────────────────────────
  static const Map<String, String> departmentNameToId = {
    'Computer Science & Engineering': 'dept_cse',
    'Electrical & Electronic Engineering': 'dept_eee',
    'Business Administration': 'dept_bba',
    'Civil Engineering': 'dept_civil',
    'Department of Law': 'dept_law',
    'Department of Architecture': 'dept_arch',
    'Department of Public Health': 'dept_public_health',
    'Toursim & Hospitality Management': 'dept_thm',
    'Tourism & Hospitality Management': 'dept_thm',
    'Department of Islamic Studies': 'dept_islamic_studies',
    'Department of English': 'dept_english',
    'Department of Bangla': 'dept_bangla',
    'Bangla': 'dept_bangla',
  };

  static String getDepartmentId(String departmentName) {
    final trimmed = departmentName.trim();
    if (departmentNameToId.containsKey(trimmed)) {
      return departmentNameToId[trimmed]!;
    }
    return trimmed
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  static bool isValidDepartment(String departmentName) {
    return departmentNameToId.containsKey(departmentName.trim());
  }

  static const List<String> allowedDesignations = [
    'Associate Professor',
    'Assistant Professor',
    'Lecturer',
    'Adjunct Lecturer',
  ];

  static bool isValidDesignation(String designation) {
    return allowedDesignations.contains(designation.trim());
  }

  // ── Reserved Administrative Staff Emails ────────────────────────────────────
  static const Set<String> reservedStaffEmails = {
    'department.head.lu@gmail.com',
    'registrar.lu@gmail.com',
    'admin.lu@gmail.com',
  };

  static bool isReservedStaffEmail(String email) {
    return reservedStaffEmails.contains(email.trim().toLowerCase());
  }

  // ── Leave Defaults ─────────────────────────────────────────────────────────
  static const int defaultCasualLeave = 10;
  static const int defaultSickLeave = 14;
  static const int defaultEarnedLeave = 30;
  static const int maxLeaveDays = 60;

  // ── UI Dimensions ──────────────────────────────────────────────────────────
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXL = 24.0;
  static const double radiusFull = 999.0;

  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXL = 32.0;

  static const double buttonHeight = 56.0;
  static const double inputHeight = 56.0;
  static const double bottomNavHeight = 64.0;

  // ── Animation Durations ────────────────────────────────────────────────────
  static const Duration animFast = Duration(milliseconds: 200);
  static const Duration animNormal = Duration(milliseconds: 350);
  static const Duration animSlow = Duration(milliseconds: 600);
  static const Duration splashDuration = Duration(milliseconds: 700);

  // ── Date Formats ───────────────────────────────────────────────────────────
  static const String dateDisplay = 'dd MMM yyyy';
  static const String dateISO = 'yyyy-MM-dd';
  static const String dateTimeDisplay = 'dd MMM yyyy, hh:mm a';
}
