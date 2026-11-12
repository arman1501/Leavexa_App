// ─────────────────────────────────────────────────────────────────────────────
//  app_constants.dart  –  Leavexa App-wide Non-string Constants
// ─────────────────────────────────────────────────────────────────────────────

class InstitutionalAccountSpec {
  final String email;
  final String role;
  final String departmentId;

  const InstitutionalAccountSpec({
    required this.email,
    required this.role,
    required this.departmentId,
  });
}

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
    'Law': 'dept_law',
    'Department of Architecture': 'dept_arch',
    'Architecture': 'dept_arch',
    'Department of Public Health': 'dept_public_health',
    'Public Health': 'dept_public_health',
    'Toursim & Hospitality Management': 'dept_thm',
    'Tourism & Hospitality Management': 'dept_thm',
    'Department of Islamic Studies': 'dept_islamic_studies',
    'Islamic Studies': 'dept_islamic_studies',
    'Department of English': 'dept_english',
    'English': 'dept_english',
    'Department of Bangla': 'dept_bangla',
    'Bangla': 'dept_bangla',
  };

  static const Map<String, String> departmentIdToCanonicalName = {
    'dept_cse': 'Computer Science & Engineering',
    'dept_eee': 'Electrical & Electronic Engineering',
    'dept_bba': 'Business Administration',
    'dept_civil': 'Civil Engineering',
    'dept_law': 'Department of Law',
    'dept_arch': 'Department of Architecture',
    'dept_public_health': 'Department of Public Health',
    'dept_thm': 'Tourism & Hospitality Management',
    'dept_islamic_studies': 'Department of Islamic Studies',
    'dept_english': 'Department of English',
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

  static const Map<String, String> departmentIdToCode = {
    'dept_cse': 'CSE',
    'dept_eee': 'EEE',
    'dept_bba': 'BBA',
    'dept_civil': 'CE',
    'dept_ce': 'CE',
    'dept_law': 'LAW',
    'dept_arch': 'ARCH',
    'dept_public_health': 'MPH',
    'dept_mph': 'MPH',
    'dept_thm': 'THM',
    'dept_islamic_studies': 'IS',
    'dept_is': 'IS',
    'dept_english': 'ENG',
    'dept_eng': 'ENG',
    'dept_bangla': 'BNG',
    'dept_bng': 'BNG',
  };

  /// Returns canonical department short code (e.g. 'CE', 'MPH', 'IS', 'ENG', 'BNG')
  /// matching `assets/data/official_faculty.json` and Directory filter chips.
  static String getDepartmentCode(String departmentId, [String? departmentName]) {
    final normalizedId = departmentId.trim().toLowerCase();
    if (departmentIdToCode.containsKey(normalizedId)) {
      return departmentIdToCode[normalizedId]!;
    }
    if (departmentName != null && departmentName.trim().isNotEmpty) {
      final mappedId = getDepartmentId(departmentName);
      if (departmentIdToCode.containsKey(mappedId)) {
        return departmentIdToCode[mappedId]!;
      }
    }
    return normalizedId.replaceFirst('dept_', '').toUpperCase();
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
    'admin.lu@gmail.com',
    'registrar.lu@gmail.com',
    'department.head.lu@gmail.com',
    'head.cse.lu@gmail.com',
    'head.eee.lu@gmail.com',
    'head.bba.lu@gmail.com',
    'head.ce.lu@gmail.com',
    'head.law.lu@gmail.com',
    'head.arch.lu@gmail.com',
    'head.ph.lu@gmail.com',
    'head.thm.lu@gmail.com',
    'head.islamic.lu@gmail.com',
    'head.english.lu@gmail.com',
  };

  static bool isReservedStaffEmail(String email) {
    return reservedStaffEmails.contains(email.trim().toLowerCase());
  }

  // ── Strict 12-Account Institutional Allowlist ──────────────────────────────
  static const Map<String, InstitutionalAccountSpec>
  institutionalAccountAllowlist = {
    'admin.lu@gmail.com': InstitutionalAccountSpec(
      email: 'admin.lu@gmail.com',
      role: 'admin',
      departmentId: 'admin_office',
    ),
    'registrar.lu@gmail.com': InstitutionalAccountSpec(
      email: 'registrar.lu@gmail.com',
      role: 'registrar',
      departmentId: 'registrar_office',
    ),
    'head.cse.lu@gmail.com': InstitutionalAccountSpec(
      email: 'head.cse.lu@gmail.com',
      role: 'department_head',
      departmentId: 'dept_cse',
    ),
    'head.eee.lu@gmail.com': InstitutionalAccountSpec(
      email: 'head.eee.lu@gmail.com',
      role: 'department_head',
      departmentId: 'dept_eee',
    ),
    'head.bba.lu@gmail.com': InstitutionalAccountSpec(
      email: 'head.bba.lu@gmail.com',
      role: 'department_head',
      departmentId: 'dept_bba',
    ),
    'head.ce.lu@gmail.com': InstitutionalAccountSpec(
      email: 'head.ce.lu@gmail.com',
      role: 'department_head',
      departmentId: 'dept_civil',
    ),
    'head.law.lu@gmail.com': InstitutionalAccountSpec(
      email: 'head.law.lu@gmail.com',
      role: 'department_head',
      departmentId: 'dept_law',
    ),
    'head.arch.lu@gmail.com': InstitutionalAccountSpec(
      email: 'head.arch.lu@gmail.com',
      role: 'department_head',
      departmentId: 'dept_arch',
    ),
    'head.ph.lu@gmail.com': InstitutionalAccountSpec(
      email: 'head.ph.lu@gmail.com',
      role: 'department_head',
      departmentId: 'dept_public_health',
    ),
    'head.thm.lu@gmail.com': InstitutionalAccountSpec(
      email: 'head.thm.lu@gmail.com',
      role: 'department_head',
      departmentId: 'dept_thm',
    ),
    'head.islamic.lu@gmail.com': InstitutionalAccountSpec(
      email: 'head.islamic.lu@gmail.com',
      role: 'department_head',
      departmentId: 'dept_islamic_studies',
    ),
    'head.english.lu@gmail.com': InstitutionalAccountSpec(
      email: 'head.english.lu@gmail.com',
      role: 'department_head',
      departmentId: 'dept_english',
    ),
  };

  static bool isInstitutionalAllowlistedEmail(String email) {
    return institutionalAccountAllowlist.containsKey(email.trim().toLowerCase());
  }

  static InstitutionalAccountSpec? getInstitutionalSpec(String email) {
    return institutionalAccountAllowlist[email.trim().toLowerCase()];
  }

  static bool isAuthorizedInstitutionalAccount({
    required String email,
    required String role,
    String? departmentId,
  }) {
    final spec = getInstitutionalSpec(email);
    if (spec == null || spec.role != role.trim()) {
      return false;
    }
    if (role.trim() == 'department_head') {
      return departmentId != null && departmentId.trim() == spec.departmentId;
    }
    return true;
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
