// ─────────────────────────────────────────────────────────────────────────────
//  validators.dart  –  Form Field Validators
// ─────────────────────────────────────────────────────────────────────────────

import '../constants/app_constants.dart';
import '../constants/app_strings.dart';

class Validators {
  Validators._();

  static String? required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.fieldRequired;
    }
    return null;
  }

  static String? fullName(String? value) {
    if (value == null || value.trim().isEmpty) return AppStrings.fieldRequired;
    final trimmed = value.trim();
    if (trimmed.length < 2) return 'Full name must be at least 2 characters.';
    if (trimmed.length > 100) return 'Full name cannot exceed 100 characters.';
    return null;
  }

  static String? employeeId(String? value) {
    if (value == null || value.trim().isEmpty) return AppStrings.fieldRequired;
    final trimmed = value.trim().toUpperCase();
    if (trimmed.length < 3) return 'Employee ID must be at least 3 characters.';
    if (trimmed.length > 30) return 'Employee ID cannot exceed 30 characters.';
    final regex = RegExp(r'^[A-Z0-9\-_]+$');
    if (!regex.hasMatch(trimmed)) {
      return 'Only letters, numbers, hyphens, and underscores allowed.';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return AppStrings.fieldRequired;
    final regex = RegExp(r'^[\w.-]+@[\w-]+\.[a-z]{2,}$', caseSensitive: false);
    if (!regex.hasMatch(value.trim())) return AppStrings.invalidEmail;
    return null;
  }

  static String? facultyEmail(String? value) {
    final baseValidation = email(value);
    if (baseValidation != null) return baseValidation;
    if (AppConstants.isReservedStaffEmail(value!)) {
      return 'This email is reserved for administrative staff.';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return AppStrings.fieldRequired;
    if (value.length < 8) return AppStrings.weakPassword;
    return null;
  }

  static String? Function(String?) confirmPassword(String? original) {
    return (String? value) {
      if (value == null || value.isEmpty) return AppStrings.fieldRequired;
      if (value != original) return AppStrings.passwordMismatch;
      return null;
    };
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return AppStrings.fieldRequired;
    final regex = RegExp(r'^\+?[0-9]{10,15}$');
    if (!regex.hasMatch(value.trim())) return 'Enter a valid phone number.';
    return null;
  }

  static String? minLength(int min) {
    return (String? value) {
      if (value == null || value.trim().isEmpty) {
        return AppStrings.fieldRequired;
      }
      if (value.trim().length < min) {
        return 'Minimum $min characters required.';
      }
      return null;
    }(null);
  }
}
