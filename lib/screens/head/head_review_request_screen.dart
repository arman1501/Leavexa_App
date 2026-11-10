// ─────────────────────────────────────────────────────────────────────────────
//  head_review_request_screen.dart  –  Department Head Review Decision Screen
//  Screen 3 of 3: Formal decision approval, change request, or rejection
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../models/leave_application_model.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/leave_repository.dart';
import '../../services/notification_service.dart';

enum _ReviewDecision { approve, requestChanges, reject }

class HeadReviewRequestScreen extends StatefulWidget {
  final Map<String, dynamic>? requestData;
  final LeaveRepository? leaveRepository;
  final AuthRepository? authRepository;
  final NotificationService? notificationService;

  const HeadReviewRequestScreen({
    super.key,
    this.requestData,
    this.leaveRepository,
    this.authRepository,
    this.notificationService,
  });

  @override
  State<HeadReviewRequestScreen> createState() =>
      _HeadReviewRequestScreenState();
}

class _HeadReviewRequestScreenState extends State<HeadReviewRequestScreen> {
  late final LeaveRepository _leaveRepo =
      widget.leaveRepository ?? LeaveRepository();
  late final AuthRepository _authRepo =
      widget.authRepository ?? AuthRepository();

  _ReviewDecision _selectedDecision = _ReviewDecision.approve;
  final _commentCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (_isSubmitting) return;
    final comment = _commentCtrl.text.trim();
    final args =
        widget.requestData ??
        (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?) ??
        {};
    final appId =
        (args['model'] as LeaveApplicationModel?)?.id ??
        (args['id'] as String? ?? '');

    setState(() => _isSubmitting = true);

    try {
      final headUser = await _authRepo.getCurrentUserProfile();
      final headUid = headUser?.uid ?? _authRepo.currentUserId ?? 'head_uid';

      if (appId.isNotEmpty) {
        if (_selectedDecision == _ReviewDecision.approve) {
          await _leaveRepo.forwardLeave(
            applicationId: appId,
            headUid: headUid,
            comment: comment.isNotEmpty
                ? comment
                : 'Leave approved and endorsed to Dean/Registrar.',
          );
        } else if (_selectedDecision == _ReviewDecision.reject) {
          await _leaveRepo.headRejectLeave(
            applicationId: appId,
            headUid: headUid,
            comment: comment.isNotEmpty
                ? comment
                : 'Leave request rejected by Department Head.',
          );
        }
      }

      if (!mounted) return;
      if (_selectedDecision == _ReviewDecision.approve) {
        AppHelpers.showSuccess(
          context,
          'Leave Request Approved and Endorsed to Dean!',
        );
        Navigator.pop(context, {
          'status': 'Approved',
          'comment': comment.isNotEmpty
              ? comment
              : 'Leave approved. Ensure class coverage as mentioned.',
          'reviewTime': DateFormat('dd MMM, hh:mm a').format(DateTime.now()),
          'reviewedBy': headUser?.fullName ?? 'Head of Department',
        });
      } else if (_selectedDecision == _ReviewDecision.requestChanges) {
        AppHelpers.showSuccess(
          context,
          'Clarification requested from faculty member.',
        );
        Navigator.pop(context, {
          'status': 'Changes Requested',
          'comment': comment.isNotEmpty
              ? comment
              : "Please update the doctor's certificate with the exact treatment date and re-submit.",
          'reviewTime': DateFormat('dd MMM, hh:mm a').format(DateTime.now()),
          'reviewedBy': headUser?.fullName ?? 'Head of Department',
        });
      } else {
        AppHelpers.showError(context, 'Leave Request Rejected.');
        Navigator.pop(context, {
          'status': 'Rejected',
          'comment': comment.isNotEmpty
              ? comment
              : 'The leave cannot be approved due to ongoing academic assessment during this period.',
          'reviewTime': DateFormat('dd MMM, hh:mm a').format(DateTime.now()),
          'reviewedBy': headUser?.fullName ?? 'Head of Department',
        });
      }
    } catch (e) {
      if (!mounted) return;
      AppHelpers.showError(context, 'Failed to update review: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args =
        widget.requestData ??
        (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?) ??
        {};

    final facultyName = args['facultyName'] ?? 'Mr. Tanvir Hasan';
    final designation =
        args['designation'] ?? 'Lecturer • Data Structures & Algorithms';
    final leaveType = args['leaveType'] ?? 'Medical Leave';
    final datesFull = args['datesFull'] ?? '25 Sep – 26 Sep, 2026';
    final duration = args['duration'] ?? '2 Days';
    final coverage = args['teachingCovered'] ?? 'Ms. Sadia Karim (CS 201 Lab)';
    final reason =
        args['reason'] ??
        'Medical consultation & dental treatment (physician certificate uploaded).';
    final attachmentName = args['attachmentName'] ?? 'Medical_Certificate.pdf';

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeState.instance.themeModeNotifier,
      builder: (context, themeMode, child) {
        final isDark = themeMode == ThemeMode.dark;
        final bgColor = isDark
            ? const Color(0xFF0F172A)
            : const Color(0xFFF8FAFC);
        final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final borderColor = isDark
            ? const Color(0xFF334155)
            : const Color(0xFFE2E8F0);
        final textPrimary = isDark
            ? const Color(0xFFF8FAFC)
            : const Color(0xFF0F172A);
        final textSecondary = isDark
            ? const Color(0xFF94A3B8)
            : const Color(0xFF64748B);
        final primaryColor = isDark
            ? const Color(0xFF047857)
            : const Color(0xFF1B4332);

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          ),
          child: Scaffold(
            backgroundColor: bgColor,
            appBar: AppBar(
              backgroundColor: cardBg,
              elevation: 0,
              scrolledUnderElevation: 0,
              centerTitle: false,
              titleSpacing: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: textPrimary, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Review Request',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── 1. USER PROFILE SUMMARY CARD ──────────────────
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFF1F5F9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.person,
                                    size: 22,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              facultyName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 15.5,
                                                fontWeight: FontWeight.w800,
                                                color: textPrimary,
                                                letterSpacing: -0.2,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? const Color(
                                                      0xFF1E3A8A,
                                                    ).withValues(alpha: 0.4)
                                                  : const Color(0xFFEFF6FF),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              leaveType,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: isDark
                                                    ? const Color(0xFF93C5FD)
                                                    : const Color(0xFF1E40AF),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        designation,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // ── 2. REQUEST SUMMARY CARD ───────────────────────
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.assignment_outlined,
                                      size: 18,
                                      color: Color(0xFF16A34A),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Request Summary',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                // Date & Duration
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.calendar_today_outlined,
                                      size: 16,
                                      color: textSecondary,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        '$datesFull ($duration)',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 10),

                                // Teaching Covered
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.assignment_ind_outlined,
                                      size: 16,
                                      color: textSecondary,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: RichText(
                                        text: TextSpan(
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: textSecondary,
                                          ),
                                          children: [
                                            const TextSpan(
                                              text: 'Teaching Covered by: ',
                                            ),
                                            TextSpan(
                                              text: coverage,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 10),

                                // Reason
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.description_outlined,
                                      size: 16,
                                      color: textSecondary,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: RichText(
                                        text: TextSpan(
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: textSecondary,
                                            height: 1.35,
                                          ),
                                          children: [
                                            const TextSpan(
                                              text: 'Reason: ',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            TextSpan(
                                              text: reason,
                                              style: TextStyle(
                                                color: textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 10),

                                // Attachment
                                Row(
                                  children: [
                                    Icon(
                                      Icons.attach_file_rounded,
                                      size: 16,
                                      color: textSecondary,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Attachment: $attachmentName',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: textPrimary,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.open_in_new_rounded,
                                      size: 16,
                                      color: textSecondary,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // ── 3. DECISION CARD ──────────────────────────────
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.balance_rounded,
                                      size: 18,
                                      color: Color(0xFF16A34A),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Decision',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                // Option 1: Approve
                                _DecisionOptionTile(
                                  label: 'Approve',
                                  isSelected:
                                      _selectedDecision ==
                                      _ReviewDecision.approve,
                                  selectedBorderColor: const Color(0xFF86EFAC),
                                  selectedBgColor: isDark
                                      ? const Color(
                                          0xFF064E3B,
                                        ).withValues(alpha: 0.5)
                                      : const Color(0xFFE8F5E9),
                                  selectedIconColor: const Color(0xFF16A34A),
                                  selectedTextColor: const Color(0xFF16A34A),
                                  onTap: () => setState(
                                    () => _selectedDecision =
                                        _ReviewDecision.approve,
                                  ),
                                  isDark: isDark,
                                  borderColor: borderColor,
                                  textPrimary: textPrimary,
                                ),

                                const SizedBox(height: 10),

                                // Option 2: Request Changes
                                _DecisionOptionTile(
                                  label: 'Request Changes',
                                  isSelected:
                                      _selectedDecision ==
                                      _ReviewDecision.requestChanges,
                                  selectedBorderColor: const Color(0xFFFDE68A),
                                  selectedBgColor: isDark
                                      ? const Color(
                                          0xFF451A03,
                                        ).withValues(alpha: 0.5)
                                      : const Color(0xFFFFFBEB),
                                  selectedIconColor: const Color(0xFFD97706),
                                  selectedTextColor: const Color(0xFFD97706),
                                  onTap: () => setState(
                                    () => _selectedDecision =
                                        _ReviewDecision.requestChanges,
                                  ),
                                  isDark: isDark,
                                  borderColor: borderColor,
                                  textPrimary: textPrimary,
                                ),

                                const SizedBox(height: 10),

                                // Option 3: Reject
                                _DecisionOptionTile(
                                  label: 'Reject',
                                  isSelected:
                                      _selectedDecision ==
                                      _ReviewDecision.reject,
                                  selectedBorderColor: const Color(0xFFFECDD3),
                                  selectedBgColor: isDark
                                      ? const Color(
                                          0xFF451A03,
                                        ).withValues(alpha: 0.5)
                                      : const Color(0xFFFEF2F2),
                                  selectedIconColor: const Color(0xFFDC2626),
                                  selectedTextColor: const Color(0xFFDC2626),
                                  onTap: () => setState(
                                    () => _selectedDecision =
                                        _ReviewDecision.reject,
                                  ),
                                  isDark: isDark,
                                  borderColor: borderColor,
                                  textPrimary: textPrimary,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // ── 4. COMMENTS (OPTIONAL) CARD ───────────────────
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.edit_outlined,
                                      size: 18,
                                      color: Color(0xFF16A34A),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Comments (Optional)',
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                        color: textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: TextField(
                                    controller: _commentCtrl,
                                    minLines: 3,
                                    maxLines: 4,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: textPrimary,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Add a comment...',
                                      hintStyle: TextStyle(
                                        fontSize: 13.5,
                                        color: textSecondary.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                      isDense: true,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),

                  // ── STICKY BOTTOM ACTION BUTTON ──────────────────────────
                  Container(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 12,
                      bottom: MediaQuery.of(context).padding.bottom > 0
                          ? MediaQuery.of(context).padding.bottom + 8
                          : 16,
                    ),
                    decoration: BoxDecoration(
                      color: cardBg,
                      border: Border(top: BorderSide(color: borderColor)),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _onSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _selectedDecision == _ReviewDecision.reject
                              ? const Color(0xFFDC2626)
                              : _selectedDecision ==
                                    _ReviewDecision.requestChanges
                              ? const Color(0xFFD97706)
                              : primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _selectedDecision == _ReviewDecision.reject
                                  ? Icons.close_rounded
                                  : Icons.check_rounded,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _selectedDecision == _ReviewDecision.reject
                                  ? 'Reject Request'
                                  : _selectedDecision ==
                                        _ReviewDecision.requestChanges
                                  ? 'Submit Change Request'
                                  : 'Approve Request',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Decision Option Tile Widget
// ─────────────────────────────────────────────────────────────────────────────
class _DecisionOptionTile extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color selectedBorderColor;
  final Color selectedBgColor;
  final Color selectedIconColor;
  final Color selectedTextColor;
  final VoidCallback onTap;
  final bool isDark;
  final Color borderColor;
  final Color textPrimary;

  const _DecisionOptionTile({
    required this.label,
    required this.isSelected,
    required this.selectedBorderColor,
    required this.selectedBgColor,
    required this.selectedIconColor,
    required this.selectedTextColor,
    required this.onTap,
    required this.isDark,
    required this.borderColor,
    required this.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedBgColor
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? selectedBorderColor : borderColor,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                size: 20,
                color: selectedIconColor,
              )
            else
              Icon(
                Icons.radio_button_unchecked_rounded,
                size: 20,
                color: isDark
                    ? const Color(0xFF64748B)
                    : const Color(0xFF94A3B8),
              ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? selectedTextColor : textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
