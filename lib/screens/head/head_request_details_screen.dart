// ─────────────────────────────────────────────────────────────────────────────
//  head_request_details_screen.dart  –  Department Head Request Details Screen
//  Pixel-perfect implementation of all 4 request states:
//  1. Pending (Awaiting review, action button active)
//  2. Approved (Review Decision card, approved timeline)
//  3. Changes Requested (Review Feedback card, revisions required)
//  4. Rejected (Review Decision card with Rejection Reason, rejected timeline)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';

class HeadRequestDetailsScreen extends StatefulWidget {
  final Map<String, dynamic>? requestData;

  const HeadRequestDetailsScreen({super.key, this.requestData});

  @override
  State<HeadRequestDetailsScreen> createState() =>
      _HeadRequestDetailsScreenState();
}

class _HeadRequestDetailsScreenState extends State<HeadRequestDetailsScreen> {
  bool _isInitialized = false;

  late String _status;
  late String _facultyName;
  late String _designation;
  late String _leaveType;
  late String _datesFull;
  late String _duration;
  late String _coverage;
  late String _reason;
  late String _attachmentName;
  late String _attachmentSize;
  late String _submittedAt;
  late String _reviewedBy;
  late String _reviewTime;
  late String _comment;

  Map<String, dynamic> _rawArgs = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _rawArgs =
          widget.requestData ??
          (ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?) ??
          {};

      _status = _rawArgs['status'] ?? 'Pending';
      _facultyName = _rawArgs['facultyName'] ?? 'Mr. Tanvir Hasan';
      _designation =
          _rawArgs['designation'] ?? 'Lecturer • Data Structures & Algorithms';
      _leaveType = _rawArgs['leaveType'] ?? 'Medical Leave';
      _datesFull = _rawArgs['datesFull'] ?? '25 Sep – 26 Sep, 2026';
      _duration = _rawArgs['duration'] ?? '2 Days';
      _coverage = _rawArgs['teachingCovered'] ?? 'Ms. Sadia Karim (CS 201 Lab)';
      _reason =
          _rawArgs['reason'] ??
          'Medical consultation & dental treatment (physician certificate uploaded).';
      _attachmentName = _rawArgs['attachmentName'] ?? 'Medical_Certificate.pdf';
      _attachmentSize = _rawArgs['attachmentSize'] ?? '2.4 MB';
      _submittedAt = _rawArgs['submittedAt'] ?? '24 Sep, 10:20 AM';
      _reviewedBy = _rawArgs['reviewedBy'] ?? 'Head of Department';
      _reviewTime =
          _rawArgs['reviewedAt'] ??
          _rawArgs['reviewTime'] ??
          '24 Sep, 03:45 PM';

      // Comments based on initial status or passed argument
      if (_status == 'Approved') {
        _comment =
            _rawArgs['reviewComment'] ??
            _rawArgs['comment'] ??
            'Leave approved. Ensure class coverage as mentioned.';
      } else if (_status == 'Changes Requested') {
        _comment =
            _rawArgs['reviewComment'] ??
            _rawArgs['comment'] ??
            "Please update the doctor's certificate with the exact treatment date and re-submit.";
      } else if (_status == 'Rejected') {
        _comment =
            _rawArgs['rejectionReason'] ??
            _rawArgs['reviewComment'] ??
            _rawArgs['comment'] ??
            'The leave cannot be approved due to ongoing academic assessment during this period.';
      } else {
        _comment = '';
      }

      _isInitialized = true;
    }
  }

  void _onOpenReview() async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.headReviewRequest,
      arguments: {
        ..._rawArgs,
        'facultyName': _facultyName,
        'designation': _designation,
        'leaveType': _leaveType,
        'datesFull': _datesFull,
        'duration': _duration,
        'teachingCovered': _coverage,
        'reason': _reason,
        'attachmentName': _attachmentName,
        'status': _status,
      },
    );

    if (result != null && mounted) {
      if (result is Map<String, dynamic>) {
        setState(() {
          _status = result['status'] ?? 'Approved';
          _reviewedBy = result['reviewedBy'] ?? 'Head of Department';
          _reviewTime = result['reviewTime'] ?? '24 Sep, 03:45 PM';
          _comment =
              result['comment'] ??
              (_status == 'Approved'
                  ? 'Leave approved. Ensure class coverage as mentioned.'
                  : _status == 'Changes Requested'
                  ? "Please update the doctor's certificate with the exact treatment date and re-submit."
                  : 'The leave cannot be approved due to ongoing academic assessment during this period.');
        });
      } else if (result == true) {
        setState(() {
          _status = 'Approved';
          _reviewedBy = 'Head of Department';
          _reviewTime = '24 Sep, 03:45 PM';
          _comment = 'Leave approved. Ensure class coverage as mentioned.';
        });
      } else if (result == false) {
        setState(() {
          _status = 'Rejected';
          _reviewedBy = 'Head of Department';
          _reviewTime = '24 Sep, 03:45 PM';
          _comment =
              'The leave cannot be approved due to ongoing academic assessment during this period.';
        });
      }
    }
  }

  void _handleBack() {
    Navigator.pop(context, {
      'status': _status,
      'reviewedBy': _reviewedBy,
      'reviewTime': _reviewTime,
      'comment': _comment,
    });
  }

  @override
  Widget build(BuildContext context) {
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
          child: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) return;
              _handleBack();
            },
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
                  onPressed: _handleBack,
                ),
                title: Text(
                  'Request Details',
                  style: TextStyle(
                    fontSize: 18.5,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                actions: [
                  // Fast preview switcher menu to test all 4 states on the fly
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: textPrimary,
                      size: 22,
                    ),
                    tooltip: 'Switch State Preview',
                    onSelected: (val) {
                      setState(() {
                        _status = val;
                        if (val == 'Approved') {
                          _comment =
                              'Leave approved. Ensure class coverage as mentioned.';
                        } else if (val == 'Changes Requested') {
                          _comment =
                              "Please update the doctor's certificate with the exact treatment date and re-submit.";
                        } else if (val == 'Rejected') {
                          _comment =
                              'The leave cannot be approved due to ongoing academic assessment during this period.';
                        }
                      });
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'Pending',
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 18,
                              color: Color(0xFFD97706),
                            ),
                            SizedBox(width: 8),
                            Text('Preview: Pending'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'Approved',
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              size: 18,
                              color: Color(0xFF16A34A),
                            ),
                            SizedBox(width: 8),
                            Text('Preview: Approved'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'Changes Requested',
                        child: Row(
                          children: [
                            Icon(
                              Icons.sync_rounded,
                              size: 18,
                              color: Color(0xFFD97706),
                            ),
                            SizedBox(width: 8),
                            Text('Preview: Changes Requested'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'Rejected',
                        child: Row(
                          children: [
                            Icon(
                              Icons.cancel_outlined,
                              size: 18,
                              color: Color(0xFFDC2626),
                            ),
                            SizedBox(width: 8),
                            Text('Preview: Rejected'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              body: SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── 1. USER PROFILE SUMMARY CARD ────────────────
                            _buildFacultyHeaderCard(
                              cardBg: cardBg,
                              borderColor: borderColor,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                              isDark: isDark,
                            ),

                            const SizedBox(height: 12),

                            // ── 2. STATUS BANNER CARD ───────────────────────
                            _buildStatusBanner(isDark: isDark),

                            const SizedBox(height: 14),

                            // ── 3. REQUEST INFORMATION CARD ─────────────────
                            _buildRequestInfoCard(
                              cardBg: cardBg,
                              borderColor: borderColor,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                            ),

                            const SizedBox(height: 14),

                            // ── 4. ATTACHMENT CARD ──────────────────────────
                            _buildAttachmentCard(
                              cardBg: cardBg,
                              borderColor: borderColor,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                              isDark: isDark,
                            ),

                            // ── 5. REVIEW DECISION / FEEDBACK CARD ──────────
                            // (Only visible for Approved, Changes Requested, Rejected)
                            if (_status != 'Pending') ...[
                              const SizedBox(height: 14),
                              _buildReviewDecisionOrFeedbackCard(
                                isDark: isDark,
                                textPrimary: textPrimary,
                                textSecondary: textSecondary,
                              ),
                            ],

                            const SizedBox(height: 14),

                            // ── 6. REQUEST TIMELINE CARD ────────────────────
                            _buildTimelineCard(
                              cardBg: cardBg,
                              borderColor: borderColor,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                              isDark: isDark,
                            ),

                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),

                    // ── 7. STICKY BOTTOM BUTTON (ONLY FOR PENDING) ───────────
                    if (_status == 'Pending')
                      Container(
                        padding: EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 12,
                          bottom: MediaQuery.of(context).padding.bottom > 0
                              ? MediaQuery.of(context).padding.bottom + 8
                              : 14,
                        ),
                        decoration: BoxDecoration(
                          color: cardBg,
                          border: Border(top: BorderSide(color: borderColor)),
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _onOpenReview,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.playlist_add_check_rounded,
                                  size: 21,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Review Request',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Icon(Icons.arrow_forward_rounded, size: 17),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  1. FACULTY HEADER CARD
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildFacultyHeaderCard({
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person, size: 22, color: textPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _facultyName,
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
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E3A8A).withValues(alpha: 0.4)
                            : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _leaveType,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? const Color(0xFF93C5FD)
                              : const Color(0xFF1D4ED8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _designation,
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
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  2. STATUS BANNER CARD
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildStatusBanner({required bool isDark}) {
    Color bannerBg;
    Color bannerBorder;
    Widget bannerIcon;
    String bannerTitle;
    Color bannerTitleColor;
    String bannerSubtitle;
    Color bannerSubColor;

    if (_status == 'Approved') {
      bannerBg = isDark
          ? const Color(0xFF064E3B).withValues(alpha: 0.35)
          : const Color(0xFFF0FDF4);
      bannerBorder = isDark ? const Color(0xFF065F46) : const Color(0xFFDCFCE7);
      bannerIcon = const Icon(
        Icons.check_circle_outline_rounded,
        color: Color(0xFF16A34A),
        size: 26,
      );
      bannerTitle = 'Approved';
      bannerTitleColor = isDark
          ? const Color(0xFF34D399)
          : const Color(0xFF15803D);
      bannerSubtitle = 'The leave request has been approved.';
      bannerSubColor = isDark
          ? const Color(0xFFE2E8F0)
          : const Color(0xFF166534);
    } else if (_status == 'Changes Requested') {
      bannerBg = isDark
          ? const Color(0xFF451A03).withValues(alpha: 0.35)
          : const Color(0xFFFFFBEB);
      bannerBorder = isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7);
      bannerIcon = const Icon(
        Icons.sync_rounded,
        color: Color(0xFFD97706),
        size: 26,
      );
      bannerTitle = 'Changes Requested';
      bannerTitleColor = isDark
          ? const Color(0xFFFBBF24)
          : const Color(0xFFB45309);
      bannerSubtitle = 'Revisions are required before approval.';
      bannerSubColor = isDark
          ? const Color(0xFFE2E8F0)
          : const Color(0xFF78350F);
    } else if (_status == 'Rejected') {
      bannerBg = isDark
          ? const Color(0xFF450A0A).withValues(alpha: 0.35)
          : const Color(0xFFFEF2F2);
      bannerBorder = isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2);
      bannerIcon = const Icon(
        Icons.cancel_outlined,
        color: Color(0xFFDC2626),
        size: 26,
      );
      bannerTitle = 'Rejected';
      bannerTitleColor = isDark
          ? const Color(0xFFF87171)
          : const Color(0xFFDC2626);
      bannerSubtitle = 'The leave request has been rejected.';
      bannerSubColor = isDark
          ? const Color(0xFFE2E8F0)
          : const Color(0xFF991B1B);
    } else {
      // Pending
      bannerBg = isDark
          ? const Color(0xFF451A03).withValues(alpha: 0.35)
          : const Color(0xFFFFFBEB);
      bannerBorder = isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7);
      bannerIcon = const Icon(
        Icons.access_time_rounded,
        color: Color(0xFFD97706),
        size: 26,
      );
      bannerTitle = 'Pending';
      bannerTitleColor = isDark
          ? const Color(0xFFFBBF24)
          : const Color(0xFFB45309);
      bannerSubtitle = 'Awaiting your review and decision.';
      bannerSubColor = isDark
          ? const Color(0xFFE2E8F0)
          : const Color(0xFF78350F);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bannerBorder),
      ),
      child: Row(
        children: [
          bannerIcon,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bannerTitle,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: bannerTitleColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  bannerSubtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: bannerSubColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  3. REQUEST INFORMATION CARD
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildRequestInfoCard({
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
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
                Icons.info_outline_rounded,
                size: 18,
                color: Color(0xFF16A34A),
              ),
              const SizedBox(width: 8),
              Text(
                'Request Information',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Leave Date
          _InfoRow(
            icon: Icons.calendar_today_outlined,
            label: 'Leave Date',
            value: _datesFull,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),

          const SizedBox(height: 14),

          // Duration
          _InfoRow(
            icon: Icons.access_time_rounded,
            label: 'Duration',
            value: _duration,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),

          const SizedBox(height: 14),

          // Teaching Covered by
          _InfoRow(
            icon: Icons.assignment_ind_outlined,
            label: 'Teaching Covered by',
            value: _coverage,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),

          const SizedBox(height: 14),

          // Reason
          _InfoRow(
            icon: Icons.description_outlined,
            label: 'Reason',
            value: _reason,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  4. ATTACHMENT CARD
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildAttachmentCard({
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
  }) {
    return Container(
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
                Icons.attach_file_rounded,
                size: 18,
                color: Color(0xFF16A34A),
              ),
              const SizedBox(width: 8),
              Text(
                'Attachment (1)',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF450A0A)
                      : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text(
                    'PDF',
                    style: TextStyle(
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.w900,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _attachmentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _attachmentSize,
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.file_download_outlined,
                  color: textSecondary,
                  size: 22,
                ),
                onPressed: () {
                  AppHelpers.showSuccess(
                    context,
                    'Downloading $_attachmentName...',
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  5. REVIEW DECISION OR FEEDBACK CARD (Only for Reviewed states)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildReviewDecisionOrFeedbackCard({
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    if (_status == 'Approved') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF064E3B).withValues(alpha: 0.25)
              : const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF065F46) : const Color(0xFFDCFCE7),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 18,
                  color: Color(0xFF16A34A),
                ),
                SizedBox(width: 8),
                Text(
                  'Review Decision',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildAlignedRow(
              label: 'Decision',
              value: 'Approved',
              valueColor: const Color(0xFF16A34A),
              isBold: true,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            _buildAlignedRow(
              label: 'Reviewed by',
              value: _reviewedBy,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            _buildAlignedRow(
              label: 'Review Time',
              value: _reviewTime,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            _buildAlignedRow(
              label: 'Comment',
              value: _comment,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
          ],
        ),
      );
    } else if (_status == 'Changes Requested') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF451A03).withValues(alpha: 0.25)
              : const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 18,
                  color: Color(0xFFD97706),
                ),
                SizedBox(width: 8),
                Text(
                  'Review Feedback',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFD97706),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildAlignedRow(
              label: 'Reviewed by',
              value: _reviewedBy,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            _buildAlignedRow(
              label: 'Review Time',
              value: _reviewTime,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            _buildAlignedRow(
              label: 'Comment',
              value: _comment,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
          ],
        ),
      );
    } else {
      // Rejected
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF450A0A).withValues(alpha: 0.25)
              : const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.cancel_outlined, size: 18, color: Color(0xFFDC2626)),
                SizedBox(width: 8),
                Text(
                  'Review Decision',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildAlignedRow(
              label: 'Reviewed by',
              value: _reviewedBy,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            _buildAlignedRow(
              label: 'Review Time',
              value: _reviewTime,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            _buildAlignedRow(
              label: 'Rejection Reason',
              value: _comment,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
          ],
        ),
      );
    }
  }

  Widget _buildAlignedRow({
    required String label,
    required String value,
    Color? valueColor,
    bool isBold = false,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 124,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: textSecondary,
                  ),
                ),
                Text(
                  ':',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                color: valueColor ?? textPrimary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  6. REQUEST TIMELINE CARD
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildTimelineCard({
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
  }) {
    // Line & Step 2 color configuration
    Color lineColor;
    Widget step2Icon;
    String step2Title;
    String step2Sub;

    if (_status == 'Approved') {
      lineColor = const Color(0xFF16A34A);
      step2Icon = Container(
        width: 18,
        height: 18,
        decoration: const BoxDecoration(
          color: Color(0xFF16A34A),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, size: 12, color: Colors.white),
      );
      step2Title = 'Reviewed & Approved';
      step2Sub = _reviewTime;
    } else if (_status == 'Changes Requested') {
      lineColor = const Color(0xFFF59E0B);
      step2Icon = Container(
        width: 18,
        height: 18,
        decoration: const BoxDecoration(
          color: Color(0xFFF59E0B),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.sync, size: 12, color: Colors.white),
      );
      step2Title = 'Changes Requested';
      step2Sub = _reviewTime;
    } else if (_status == 'Rejected') {
      lineColor = const Color(0xFFDC2626);
      step2Icon = Container(
        width: 18,
        height: 18,
        decoration: const BoxDecoration(
          color: Color(0xFFDC2626),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.close, size: 12, color: Colors.white),
      );
      step2Title = 'Reviewed & Rejected';
      step2Sub = _reviewTime;
    } else {
      // Pending
      lineColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
      step2Icon = Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            width: 2,
          ),
        ),
      );
      step2Title = 'Pending Review';
      step2Sub = 'Awaiting your decision';
    }

    // Step 1 Icon
    Widget step1Icon;
    if (_status == 'Pending') {
      step1Icon = Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF16A34A), width: 2),
        ),
        child: Center(
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF16A34A),
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    } else {
      step1Icon = Container(
        width: 18,
        height: 18,
        decoration: const BoxDecoration(
          color: Color(0xFF16A34A),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, size: 12, color: Colors.white),
      );
    }

    return Container(
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
                Icons.calendar_month_outlined,
                size: 18,
                color: Color(0xFF16A34A),
              ),
              const SizedBox(width: 8),
              Text(
                'Request Timeline',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Timeline Step 1: Submitted
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  step1Icon,
                  Container(width: 2, height: 34, color: lineColor),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Submitted',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _submittedAt,
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Timeline Step 2: Dynamic state
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              step2Icon,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step2Title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      step2Sub,
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color textPrimary;
  final Color textSecondary;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
