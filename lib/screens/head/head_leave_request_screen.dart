// ─────────────────────────────────────────────────────────────────────────────
//  head_leave_request_screen.dart  –  Department Head Leave Request Review Screen
//  Pixel-perfect implementation of Leave Request UI design
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../widgets/app_avatar.dart';

class HeadLeaveRequestScreen extends StatefulWidget {
  final Map<String, dynamic>? requestData;

  const HeadLeaveRequestScreen({super.key, this.requestData});

  @override
  State<HeadLeaveRequestScreen> createState() => _HeadLeaveRequestScreenState();
}

class _HeadLeaveRequestScreenState extends State<HeadLeaveRequestScreen> {
  final _commentCtrl = TextEditingController();

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  void _onReject() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Leave Request'),
        content: const Text(
          'Are you sure you want to reject this faculty leave application?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              AppHelpers.showError(context, 'Leave request has been rejected.');
              Navigator.pop(context, false);
            },
            child: const Text('Confirm Reject'),
          ),
        ],
      ),
    );
  }

  void _onApprove() {
    AppHelpers.showSuccess(
      context,
      'Leave approved and endorsed to Dean / Registrar!',
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    // Extract dynamic arguments if passed, otherwise default to screenshot reference
    final rawArgs = ModalRoute.of(context)?.settings.arguments;
    final Map<String, dynamic> args = widget.requestData ??
        (rawArgs is Map<String, dynamic>
            ? rawArgs
            : (rawArgs is String ? {'id': rawArgs, 'applicationId': rawArgs} : {}));

    final facultyName = args['facultyName'] ?? 'Md. Hasan Rahman';
    final String? facultyPhotoUrl =
        args['applicantPhotoUrl'] ?? args['photoUrl'];
    final facultyId = args['facultyId'] ?? 'CSE-1024';
    final designation =
        args['designation'] ?? 'Lecturer • Computer Science & Engineering';
    final leaveType = args['leaveType'] ?? 'Casual Leave';
    final startDate = args['startDate'] ?? '18 Sep 2026';
    final startDay = args['startDay'] ?? 'Friday';
    final endDate = args['endDate'] ?? '20 Sep 2026';
    final endDay = args['endDay'] ?? 'Sunday';
    final duration = args['duration'] ?? '3 Days';
    final durationType = args['durationType'] ?? 'Working Days';
    final reason = args['reason'] ?? 'Personal work';
    final coverage =
        args['teachingCovered'] ?? 'Lecture modules covered by peer faculty.';
    final remainingDays = args['remainingDays'] ?? '07 Days';
    final totalDays = args['totalDays'] ?? '10';
    final attachmentName =
        args['attachmentName'] ?? 'casual_leave_duty_handover.pdf';
    final attachmentMeta = args['attachmentMeta'] ?? 'PDF • 420 KB • 16 Sep';

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
        final surfaceAlt = isDark
            ? const Color(0xFF0F172A)
            : const Color(0xFFF1F5F9);

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
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: textPrimary, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Leave Request',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4.5,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF451A03).withValues(alpha: 0.7)
                            : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF78350F)
                              : const Color(0xFFFDE68A),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFFD97706),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Pending',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? const Color(0xFFFCD34D)
                                  : const Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            body: SafeArea(
              child: Column(
                children: [
                  // ── SCROLLABLE CARDS CONTENT ─────────────────────────────
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
                          // ── 1. FACULTY USER INFO CARD ─────────────────────
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                AppAvatar(
                                  name: facultyName,
                                  photoUrl: facultyPhotoUrl,
                                  size: 46,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
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
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 2.5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? const Color(0xFF334155)
                                                  : const Color(0xFFF1F5F9),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: isDark
                                                    ? const Color(0xFF475569)
                                                    : const Color(0xFFE2E8F0),
                                              ),
                                            ),
                                            child: Text(
                                              'ID: $facultyId',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: textSecondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        designation,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12.5,
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

                          // ── 2. APPLICATION DETAILS CARD ───────────────────
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
                                // Header: Title & Leave Type Pill
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'APPLICATION DETAILS',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: textSecondary,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(
                                                0xFF064E3B,
                                              ).withValues(alpha: 0.6)
                                            : const Color(0xFFD1FAE5),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        leaveType,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? const Color(0xFF34D399)
                                              : const Color(0xFF059669),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 14),

                                // Date & Duration Container (3 Columns)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: surfaceAlt,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      // Start Date
                                      Expanded(
                                        child: Column(
                                          children: [
                                            Text(
                                              'START DATE',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color: textSecondary,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              startDate,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w800,
                                                color: textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              startDay,
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                color: textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // End Date
                                      Expanded(
                                        child: Column(
                                          children: [
                                            Text(
                                              'END DATE',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color: textSecondary,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              endDate,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w800,
                                                color: textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              endDay,
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                color: textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Duration
                                      Expanded(
                                        child: Column(
                                          children: [
                                            Text(
                                              'DURATION',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color: textSecondary,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              duration,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w800,
                                                color: textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              durationType,
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                color: textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // Stated Reason Box
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: surfaceAlt,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'STATED REASON',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: textSecondary,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        reason,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.info_outline_rounded,
                                            size: 15,
                                            color: textSecondary,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              coverage,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: textSecondary,
                                                height: 1.3,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // ── 3. LEAVE BALANCE CARD ─────────────────────────
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 13,
                            ),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.account_balance_wallet_outlined,
                                  size: 19,
                                  color: textPrimary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '$leaveType Balance',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: textPrimary,
                                    ),
                                  ),
                                ),
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'Remaining: $remainingDays ',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: textPrimary,
                                        ),
                                      ),
                                      TextSpan(
                                        text: '(of $totalDays)',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w400,
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

                          // ── 4. ATTACHMENT CARD ────────────────────────────
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF451A03)
                                        : const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.picture_as_pdf_outlined,
                                    color: Color(0xFFDC2626),
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        attachmentName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        attachmentMeta,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () {
                                    AppHelpers.showSuccess(
                                      context,
                                      'Opening $attachmentName',
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(
                                              0xFF1E3A8A,
                                            ).withValues(alpha: 0.4)
                                          : const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.visibility_outlined,
                                          size: 15,
                                          color: isDark
                                              ? const Color(0xFF93C5FD)
                                              : const Color(0xFF1E40AF),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          'View',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: isDark
                                                ? const Color(0xFF93C5FD)
                                                : const Color(0xFF1E40AF),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // ── 5. COMMENT (OPTIONAL) CARD ────────────────────
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'COMMENT (OPTIONAL)',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: textSecondary,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: surfaceAlt,
                                    borderRadius: BorderRadius.circular(10),
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
                                      hintText: 'Add a comment (optional)...',
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
                                const SizedBox(height: 8),
                                Text(
                                  'Recorded in Registrar academic dossier audit log.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),

                  // ── 6. BOTTOM FIXED ACTION BUTTONS ───────────────────────
                  Container(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 12,
                      bottom: MediaQuery.of(context).padding.bottom > 0
                          ? MediaQuery.of(context).padding.bottom + 6
                          : 16,
                    ),
                    decoration: BoxDecoration(
                      color: cardBg,
                      border: Border(top: BorderSide(color: borderColor)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Reject Button
                        Expanded(
                          flex: 2,
                          child: OutlinedButton(
                            onPressed: _onReject,
                            style: OutlinedButton.styleFrom(
                              backgroundColor: isDark
                                  ? const Color(
                                      0xFF451A03,
                                    ).withValues(alpha: 0.4)
                                  : const Color(0xFFFFE4E6),
                              side: BorderSide(
                                color: isDark
                                    ? const Color(0xFF7F1D1D)
                                    : const Color(0xFFFECDD3),
                              ),
                              foregroundColor: const Color(0xFFDC2626),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: Color(0xFFDC2626),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Reject',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Approve Leave Button
                        Expanded(
                          flex: 3,
                          child: ElevatedButton(
                            onPressed: _onApprove,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1B4332),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Approve Leave',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
