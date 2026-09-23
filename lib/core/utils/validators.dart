// ─────────────────────────────────────────────────────────────────────────────
//  validators.dart  –  Form Field Validators
// ─────────────────────────────────────────────────────────────────────────────

import '../constants/app_strings.dart';

class Validators {
  Validators._();

  static String? required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.fieldRequired;
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return AppStrings.fieldRequired;
    final regex = RegExp(r'^[\w.-]+@[\w-]+\.[a-z]{2,}$', caseSensitive: false);
    if (!regex.hasMatch(value.trim())) return AppStrings.invalidEmail;
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
      if (value == null || value.trim().isEmpty) return AppStrings.fieldRequired;
      if (value.trim().length < min) {
        return 'Minimum $min characters required.';
      }
      return null;
    }(null);
  }
}
