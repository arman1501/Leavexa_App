// ─────────────────────────────────────────────────────────────────────────────
//  leave_card.dart  –  Leave Application List Card (Dark & Light Theme Aware)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../models/leave_application_model.dart';
import '../core/constants/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/date_utils.dart';
import 'status_badge.dart';

class LeaveCard extends StatelessWidget {
  final LeaveApplicationModel application;
  final VoidCallback? onTap;

  const LeaveCard({super.key, required this.application, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = AppThemeState.instance.isDarkMode;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : AppColors.border;
    final textPrimary = isDark
        ? const Color(0xFFF8FAFC)
        : AppColors.textPrimary;
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : AppColors.textSecondary;
    final textHint = isDark ? const Color(0xFF64748B) : AppColors.textHint;
    final primaryColor = isDark ? const Color(0xFF34D399) : AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Text(
                    application.leaveTypeName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                ),
                StatusBadge(status: application.status),
              ],
            ),

            const SizedBox(height: 10),

            // ── Date range ──────────────────────────────────────────────────
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  '${LeaveDateUtils.formatDisplay(application.startDate)} '
                  '– ${LeaveDateUtils.formatDisplay(application.endDate)}',
                  style: TextStyle(fontSize: 13, color: textSecondary),
                ),
                const Spacer(),
                Text(
                  '${application.totalDays} day${application.totalDays > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: primaryColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // ── Reason snippet ──────────────────────────────────────────────
            Text(
              application.reason,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: textSecondary, height: 1.4),
            ),

            const SizedBox(height: 10),

            // ── Footer ──────────────────────────────────────────────────────
            Text(
              'Applied ${LeaveDateUtils.timeAgo(application.appliedAt)}',
              style: TextStyle(fontSize: 11.5, color: textHint),
            ),
          ],
        ),
      ),
    );
  }
}
