// ─────────────────────────────────────────────────────────────────────────────
//  final_approval_screen.dart  –  Registrar Final Leave Approval Screen
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../models/leave_application_model.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/leave_repository.dart';
import '../../services/notification_service.dart';

class FinalApprovalScreen extends StatefulWidget {
  final LeaveApplicationModel? application;
  final LeaveRepository? leaveRepository;
  final AuthRepository? authRepository;
  final NotificationService? notificationService;

  const FinalApprovalScreen({
    super.key,
    this.application,
    this.leaveRepository,
    this.authRepository,
    this.notificationService,
  });

  @override
  State<FinalApprovalScreen> createState() => _FinalApprovalScreenState();
}

class _FinalApprovalScreenState extends State<FinalApprovalScreen> {
  late final LeaveRepository _leaveRepo =
      widget.leaveRepository ?? LeaveRepository();
  late final AuthRepository _authRepo =
      widget.authRepository ?? AuthRepository();

  final _commentCtrl = TextEditingController();
  LeaveApplicationModel? _application;
  bool _isSubmitting = false;
  bool _isLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_application == null && !_isLoading) {
      if (widget.application != null) {
        _application = widget.application;
      } else {
        final args = ModalRoute.of(context)?.settings.arguments;
        if (args is LeaveApplicationModel) {
          _application = args;
        } else if (args is String) {
          _fetchApplication(args);
        } else if (args is Map<String, dynamic> && args['applicationId'] != null) {
          _fetchApplication(args['applicationId'].toString());
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

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleDecision({required bool isApproved}) async {
    final app = _application;
    if (app == null || _isSubmitting) return;

    if (app.status != 'forwarded') {
      AppHelpers.showError(
        context,
        'Only applications forwarded by Department Head can be reviewed by Registrar.',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = await _authRepo.getCurrentUserProfile();
      final registrarUid = user?.uid ?? _authRepo.currentUserId ?? 'registrar_uid';
      final comment = _commentCtrl.text.trim().isNotEmpty
          ? _commentCtrl.text.trim()
          : (isApproved
              ? 'Institutional leave approval granted.'
              : 'Institutional leave request declined.');

      await _leaveRepo.takeAction(
        applicationId: app.id,
        registrarUid: registrarUid,
        isApproved: isApproved,
        comment: comment,
      );

      if (!mounted) return;
      AppHelpers.showSuccess(
        context,
        isApproved
            ? 'Leave request approved and finalized!'
            : 'Leave request rejected.',
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      AppHelpers.showError(context, 'Failed to submit decision: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
                'Registrar Final Review',
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
                          'No application selected or unauthorized',
                          style: TextStyle(color: textSecondary),
                        ),
                      )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── STATUS ALERT ─────────────────────────────────────
                        if (app.status != 'forwarded')
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFDC2626).withOpacity(0.3),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Color(0xFFDC2626),
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Notice: Only applications forwarded by Department Head can receive final Registrar action.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // ── APPLICATION OVERVIEW CARD ────────────────────────
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
                                app.applicantName,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${app.applicantEmployeeId} • ${app.departmentName}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textSecondary,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Divider(color: borderColor, height: 1),
                              const SizedBox(height: 14),
                              _row('Leave Type', app.leaveTypeName, primaryColor),
                              const SizedBox(height: 8),
                              _row(
                                'Dates',
                                '${DateFormat('MMM dd, yyyy').format(app.startDate)} – ${DateFormat('MMM dd, yyyy').format(app.endDate)}',
                                textPrimary,
                              ),
                              const SizedBox(height: 8),
                              _row('Working Days', '${app.totalDays} Days', textPrimary),
                              const SizedBox(height: 8),
                              _row('Reason', app.reason, textSecondary),
                              if (app.headComment != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E3A8A).withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Department Head Recommendation:',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF2563EB),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        app.headComment!,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: textPrimary,
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

                        // ── REGISTRAR COMMENTS ────────────────────────────────
                        Text(
                          'REGISTRAR ENDORSEMENT NOTES',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: textSecondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _commentCtrl,
                          maxLines: 3,
                          style: TextStyle(fontSize: 13.5, color: textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Enter official registrar remarks / conditions...',
                            hintStyle: TextStyle(fontSize: 13, color: textSecondary),
                            filled: true,
                            fillColor: cardBg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: primaryColor, width: 1.5),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── ACTION BUTTONS ────────────────────────────────────
                        if (_isSubmitting)
                          const Center(child: CircularProgressIndicator())
                        else
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: app.status == 'forwarded'
                                      ? () => _handleDecision(isApproved: false)
                                      : null,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFDC2626),
                                    side: const BorderSide(color: Color(0xFFDC2626)),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Reject Application',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: app.status == 'forwarded'
                                      ? () => _handleDecision(isApproved: true)
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF16A34A),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Approve & Finalize',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _row(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
