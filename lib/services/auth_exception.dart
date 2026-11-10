// ─────────────────────────────────────────────────────────────────────────────
//  auth_exception.dart  –  Typed authentication / authorisation errors
// ─────────────────────────────────────────────────────────────────────────────

/// Every auth-related failure that surfaces to the UI layer goes through
/// this single type so callers never need to inspect raw Firebase strings.
class AuthException implements Exception {
  /// Machine-readable code — matches the [AuthErrorCode] constants below.
  final String code;

  /// Human-readable message safe to show in a SnackBar.
  final String message;

  const AuthException({required this.code, required this.message});

  @override
  String toString() => 'AuthException($code): $message';
}

// ─────────────────────────────────────────────────────────────────────────────
//  Well-known error codes (used in both AuthService and unit tests)
// ─────────────────────────────────────────────────────────────────────────────

abstract final class AuthErrorCode {
  static const String invalidCredentials = 'invalid-credentials';
  static const String userNotFound = 'user-not-found';
  static const String emailAlreadyInUse = 'email-already-in-use';
  static const String weakPassword = 'weak-password';
  static const String tooManyRequests = 'too-many-requests';
  static const String networkError = 'network-error';
  static const String missingProfile = 'missing-profile';
  static const String pendingApproval = 'pending-approval';
  static const String accountRejected = 'account-rejected';
  static const String accountInactive = 'account-inactive';
  static const String duplicateEmployeeId = 'duplicate-employee-id';
  static const String invalidEmployeeId = 'invalid-employee-id';
  static const String invalidDepartment = 'invalid-department';
  static const String incompleteRegistration = 'incomplete-registration';
  static const String invalidRole = 'invalid-role';
  static const String googleSignInCancelled = 'google-sign-in-cancelled';
  static const String googleSignInFailed = 'google-sign-in-failed';
  static const String googleNoAccount = 'google-no-account';
  static const String missingIdToken = 'missing-id-token';
  static const String credentialAlreadyInUse = 'credential-already-in-use';
  static const String unknown = 'unknown';
}
