// ─────────────────────────────────────────────────────────────────────────────
//  leave_details_screen.dart  –  Leave Application Details & Review Trail
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/leave_application_model.dart';
import '../../repositories/leave_repository.dart';

class LeaveDetailsScreen extends StatefulWidget {
  final LeaveApplicationModel? application;
  final String? applicationId;
  final LeaveRepository? leaveRepository;

  const LeaveDetailsScreen({
    super.key,
    this.application,
    this.applicationId,
    this.leaveRepository,
  });

  @override
  State<LeaveDetailsScreen> createState() => _LeaveDetailsScreenState();
}

class _LeaveDetailsScreenState extends State<LeaveDetailsScreen> {
  late final LeaveRepository _leaveRepo =
      widget.leaveRepository ?? LeaveRepository();

  LeaveApplicationModel? _application;
  bool _isLoading = false;
  bool _isCancelling = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_application == null) {
      if (widget.application != null) {
        _application = widget.application;
      } else {
        final args = ModalRoute.of(context)?.settings.arguments;
        if (args is LeaveApplicationModel) {
          _application = args;
        } else if (args is Map<String, dynamic> && args['model'] is LeaveApplicationModel) {
          _application = args['model'] as LeaveApplicationModel;
        } else if (args is String) {
          _fetchApplication(args);
        } else if (widget.applicationId != null) {
          _fetchApplication(widget.applicationId!);
        }
      }
    }
  }

  Future<void> _fetchApplication(String id) async {
    setState(() => _isLoading = true);
    try {
      final app = await _leaveRepo.getApplicationById(id);
      if (mounted) {
        setState(() {
          _application = app;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getStatusBg(String status, bool isDark) {
    switch (status.toLowerCase()) {
      case 'approved':
        return isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7);
      case 'rejected':
        return isDark ? const Color(0xFF451A1A) : const Color(0xFFFEE2E2);
      case 'forwarded':
        return isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE);
      case 'cancelled':
        return isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
      default:
        return isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return const Color(0xFF16A34A);
      case 'rejected':
        return const Color(0xFFDC2626);
      case 'forwarded':
        return const Color(0xFF2563EB);
      case 'cancelled':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFFD97706);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeState.instance.themeModeNotifier,
      builder: (context, themeMode, child) {
        final isDark = themeMode == ThemeMode.dark;
        final bgColor =
            isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFB);
        final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final borderColor =
            isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
        final textPrimary =
            isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
        final textSecondary =
            isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
        final primaryColor =
            isDark ? const Color(0xFF0D9488) : AppColors.primary;

        final app = _application;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          ),
          child: Scaffold(
            backgroundColor: bgColor,
            appBar: AppBar(
              backgroundColor: cardBg,
              elevation: 0,
              centerTitle: true,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: textPrimary,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Leave Details',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(color: borderColor, height: 1),
              ),
            ),
            body: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : app == null
                    ? Center(
                        child: Text(
                          'No details available',
                          style: TextStyle(color: textSecondary),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── STATUS CARD ──────────────────────────────
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: borderColor),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        app.leaveTypeName,
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                          color: textPrimary,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getStatusBg(
                                            app.status,
                                            isDark,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          app.status.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: _getStatusColor(app.status),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Divider(color: borderColor, height: 1),
                                  const SizedBox(height: 12),
                                  _infoRow(
                                    'Date Range',
                                    '${DateFormat('MMM dd, yyyy').format(app.startDate)} – ${DateFormat('MMM dd, yyyy').format(app.endDate)}',
                                    textPrimary,
                                    textSecondary,
                                  ),
                                  const SizedBox(height: 8),
                                  _infoRow(
                                    'Duration',
                                    '${app.totalDays} Day${app.totalDays > 1 ? 's' : ''}',
                                    primaryColor,
                                    textSecondary,
                                    isBold: true,
                                  ),
                                  const SizedBox(height: 8),
                                  _infoRow(
                                    'Applied On',
                                    DateFormat('MMM dd, yyyy • hh:mm a')
                                        .format(app.appliedAt),
                                    textPrimary,
                                    textSecondary,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // ── APPLICANT & REASON ────────────────────────
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: borderColor),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'APPLICANT INFORMATION',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: textSecondary,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _infoRow(
                                    'Faculty Member',
                                    app.applicantName,
                                    textPrimary,
                                    textSecondary,
                                  ),
                                  const SizedBox(height: 6),
                                  _infoRow(
                                    'Employee ID',
                                    app.applicantEmployeeId,
                                    textPrimary,
                                    textSecondary,
                                  ),
                                  const SizedBox(height: 6),
                                  _infoRow(
                                    'Department',
                                    app.departmentName,
                                    textPrimary,
                                    textSecondary,
                                  ),
                                  const SizedBox(height: 14),
                                  Divider(color: borderColor, height: 1),
                                  const SizedBox(height: 14),
                                  Text(
                                    'REASON FOR LEAVE',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: textSecondary,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    app.reason,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: textPrimary,
                                      height: 1.45,
                                    ),
                                  ),
                                  if (app.documentUrl != null &&
                                      app.documentUrl!.isNotEmpty) ...[
                                    const SizedBox(height: 14),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF334155)
                                            : const Color(0xFFF1F5F9),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.attach_file_rounded,
                                            size: 18,
                                            color: primaryColor,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              app.documentUrl!,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w500,
                                                color: textPrimary,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // ── REVIEW TRAIL ──────────────────────────────
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: borderColor),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'REVIEW TRAIL & TIMELINE',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: textSecondary,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  _timelineStep(
                                    title: '1. Application Submitted',
                                    subtitle: DateFormat(
                                      'MMM dd, yyyy • hh:mm a',
                                    ).format(app.appliedAt),
                                    isDone: true,
                                    isDark: isDark,
                                    textPrimary: textPrimary,
                                    textSecondary: textSecondary,
                                  ),
                                  _timelineStep(
                                    title: '2. Department Head Review',
                                    subtitle: app.headActionAt != null
                                        ? '${DateFormat('MMM dd, yyyy • hh:mm a').format(app.headActionAt!)}\nComment: ${app.headComment ?? "Approved & Forwarded"}'
                                        : 'Pending Department Head Review',
                                    isDone: app.headActionAt != null,
                                    isDark: isDark,
                                    textPrimary: textPrimary,
                                    textSecondary: textSecondary,
                                  ),
                                  _timelineStep(
                                    title: '3. Registrar Final Decision',
                                    subtitle: app.registrarActionAt != null
                                        ? '${DateFormat('MMM dd, yyyy • hh:mm a').format(app.registrarActionAt!)}\nDecision: ${app.status.toUpperCase()}\nComment: ${app.registrarComment ?? "Official approval confirmed."}'
                                        : (app.status == 'forwarded'
                                            ? 'Under Registrar Review'
                                            : 'Awaiting Department Head recommendation'),
                                    isDone: app.registrarActionAt != null,
                                    isLast: true,
                                    isDark: isDark,
                                    textPrimary: textPrimary,
                                    textSecondary: textSecondary,
                                  ),
                                ],
                              ),
                            ),
                            if (app.status == 'pending') ...[
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  key: const Key('cancel_leave_button'),
                                  onPressed: _isCancelling
                                      ? null
                                      : () => _confirmCancelApplication(app),
                                  icon: _isCancelling
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFFDC2626),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.cancel_outlined,
                                          size: 20,
                                          color: Color(0xFFDC2626),
                                        ),
                                  label: Text(
                                    _isCancelling
                                        ? 'Cancelling Request...'
                                        : 'Cancel Leave Request',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: Color(0xFFDC2626),
                                      width: 1.5,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
          ),
        );
      },
    );
  }

  Future<void> _confirmCancelApplication(LeaveApplicationModel app) async {
    final reasonController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Cancel Leave Request',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to cancel this ${app.leaveTypeName} request? This action cannot be undone.',
              style: TextStyle(
                fontSize: 13.5,
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('cancel_reason_field'),
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Reason for cancellation (optional)',
                labelStyle: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              style: TextStyle(
                fontSize: 13.5,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Keep Request',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton(
            key: const Key('confirm_cancel_button'),
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Confirm Cancel',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCancelling = true);

    try {
      final reason = reasonController.text.trim();
      await _leaveRepo.cancelLeave(
        applicationId: app.id,
        applicantUid: app.applicantUid,
        reason: reason.isNotEmpty ? reason : null,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Leave request cancelled successfully.'),
          backgroundColor: Color(0xFF1B4332),
        ),
      );

      // Re-fetch updated application state
      await _fetchApplication(app.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel request: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  Widget _infoRow(
    String label,
    String value,
    Color valueColor,
    Color labelColor, {
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: labelColor,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _timelineStep({
    required String title,
    required String subtitle,
    required bool isDone,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    bool isLast = false,
  }) {
    final activeColor = const Color(0xFF16A34A);
    final inactiveColor =
        isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone ? activeColor : inactiveColor.withOpacity(0.3),
                  border: Border.all(
                    color: isDone ? activeColor : inactiveColor,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Icon(
                    isDone ? Icons.check : Icons.circle,
                    size: isDone ? 13 : 6,
                    color: Colors.white,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isDone ? activeColor : inactiveColor,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
