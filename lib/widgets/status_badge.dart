// ─────────────────────────────────────────────────────────────────────────────
//  status_badge.dart  –  Leave Status Chip
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../core/utils/helpers.dart';
import '../core/constants/app_strings.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  String get _label {
    switch (status.toLowerCase()) {
      case 'approved':
        return AppStrings.approved;
      case 'rejected':
        return AppStrings.rejected;
      case 'forwarded':
        return AppStrings.forwarded;
      default:
        return AppStrings.pending;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = AppHelpers.statusColor(status);
    final bgColor = AppHelpers.statusBgColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
