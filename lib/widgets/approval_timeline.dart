// ─────────────────────────────────────────────────────────────────────────────
//  approval_timeline.dart  –  2-step Approval Flow Visual
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/date_utils.dart';
import '../models/leave_application_model.dart';

class ApprovalTimeline extends StatelessWidget {
  final LeaveApplicationModel application;

  const ApprovalTimeline({super.key, required this.application});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TimelineStep(
          step: 1,
          title: 'Department Head',
          status: _headStatus(),
          timestamp: application.headActionAt,
          comment: application.headComment,
        ),
        _TimelineConnector(filled: _headDone()),
        _TimelineStep(
          step: 2,
          title: 'Registrar',
          status: _registrarStatus(),
          timestamp: application.registrarActionAt,
          comment: application.registrarComment,
        ),
      ],
    );
  }

  String _headStatus() {
    if (application.headActionAt == null) return 'pending';
    if (application.status == 'rejected' && application.registrarUid == null) {
      return 'rejected';
    }
    return 'forwarded';
  }

  String _registrarStatus() {
    switch (application.status) {
      case 'approved':
        return 'approved';
      case 'rejected':
        return 'rejected';
      default:
        return 'pending';
    }
  }

  bool _headDone() => application.headActionAt != null;
}

class _TimelineStep extends StatelessWidget {
  final int step;
  final String title;
  final String status;
  final DateTime? timestamp;
  final String? comment;

  const _TimelineStep({
    required this.step,
    required this.title,
    required this.status,
    this.timestamp,
    this.comment,
  });

  Color get _dotColor {
    switch (status) {
      case 'approved':
      case 'forwarded':
        return AppColors.approved;
      case 'rejected':
        return AppColors.rejected;
      default:
        return AppColors.border;
    }
  }

  IconData get _icon {
    switch (status) {
      case 'approved':
      case 'forwarded':
        return Icons.check_rounded;
      case 'rejected':
        return Icons.close_rounded;
      default:
        return Icons.circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dot
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _dotColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: _dotColor, width: 1.5),
          ),
          child: Icon(_icon, size: 16, color: _dotColor),
        ),

        const SizedBox(width: 12),

        // Content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (timestamp != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    LeaveDateUtils.formatDateTime(timestamp!),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
                if (comment != null && comment!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '"$comment"',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineConnector extends StatelessWidget {
  final bool filled;
  const _TimelineConnector({required this.filled});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 17, top: 2, bottom: 2),
      child: Container(
        width: 2,
        height: 28,
        color: filled ? AppColors.approved : AppColors.border,
      ),
    );
  }
}
