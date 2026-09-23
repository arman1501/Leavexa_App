// ─────────────────────────────────────────────────────────────────────────────
//  helpers.dart  –  General App Helpers
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppHelpers {
  AppHelpers._();

  // ── SnackBar ───────────────────────────────────────────────────────────────
  static void showSuccess(BuildContext context, String message) {
    _showSnackBar(context, message, AppColors.approved, Icons.check_circle_outline_rounded);
  }

  static void showError(BuildContext context, String message) {
    _showSnackBar(context, message, AppColors.rejected, Icons.error_outline_rounded);
  }

  static void showInfo(BuildContext context, String message) {
    _showSnackBar(context, message, AppColors.primary, Icons.info_outline_rounded);
  }

  static void _showSnackBar(
    BuildContext context,
    String message,
    Color color,
    IconData icon,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  // ── Dialog ─────────────────────────────────────────────────────────────────
  static Future<bool?> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    Color confirmColor = AppColors.primary,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelLabel,
                style: const TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              confirmLabel,
              style: TextStyle(
                color: confirmColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── String ─────────────────────────────────────────────────────────────────
  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  static String capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }

  // ── Status ─────────────────────────────────────────────────────────────────
  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved': return AppColors.approved;
      case 'rejected': return AppColors.rejected;
      case 'forwarded': return AppColors.forwarded;
      default: return AppColors.pending;
    }
  }

  static Color statusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved': return AppColors.approvedBg;
      case 'rejected': return AppColors.rejectedBg;
      case 'forwarded': return AppColors.forwardedBg;
      default: return AppColors.pendingBg;
    }
  }

  // ── Dynamic Greeting ────────────────────────────────────────────────────────
  static String getGreetingPrefix([DateTime? dateTime]) {
    final now = dateTime ?? DateTime.now();
    final hour = now.hour;

    if (hour >= 5 && hour < 12) {
      return 'Good morning';
    } else if (hour >= 12 && hour < 15) {
      return 'Good noon';
    } else if (hour >= 15 && hour < 18) {
      return 'Good afternoon';
    } else if (hour >= 18 && hour < 19) {
      return 'Good evening';
    } else {
      return 'Good night';
    }
  }
}
