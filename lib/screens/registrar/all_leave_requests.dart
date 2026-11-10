// ─────────────────────────────────────────────────────────────────────────────
//  all_leave_requests.dart  –  Registrar Institution-Wide Leave Requests Screen
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../models/leave_application_model.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/leave_repository.dart';

class AllLeaveRequestsScreen extends StatefulWidget {
  final LeaveRepository? leaveRepository;
  final AuthRepository? authRepository;

  const AllLeaveRequestsScreen({
    super.key,
    this.leaveRepository,
    this.authRepository,
  });

  @override
  State<AllLeaveRequestsScreen> createState() => _AllLeaveRequestsScreenState();
}

class _AllLeaveRequestsScreenState extends State<AllLeaveRequestsScreen> {
  late final LeaveRepository _leaveRepo =
      widget.leaveRepository ?? LeaveRepository();

  bool _isLoading = false;
  List<LeaveApplicationModel> _forwardedRequests = [];

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() => _isLoading = true);
    try {
      final list = await _leaveRepo.forwardedAll();
      if (mounted) {
        setState(() {
          _forwardedRequests = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
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
                'Registrar Approval Queue',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.refresh_rounded, color: primaryColor),
                  onPressed: _fetchRequests,
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(color: borderColor, height: 1),
              ),
            ),
            body: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  color: cardBg,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A8A).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_forwardedRequests.length} Forwarded',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Awaiting Registrar Final Decision',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _forwardedRequests.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.verified_outlined,
                                    size: 48,
                                    color: primaryColor,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No Forwarded Applications',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'All forwarded requests have been reviewed.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(20),
                              itemCount: _forwardedRequests.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final app = _forwardedRequests[index];
                                final startStr = DateFormat(
                                  'MMM dd',
                                ).format(app.startDate);
                                final endStr = DateFormat(
                                  'MMM dd, yyyy',
                                ).format(app.endDate);

                                return GestureDetector(
                                  onTap: () {
                                    Navigator.pushNamed(
                                      context,
                                      AppRoutes.finalApproval,
                                      arguments: app,
                                    ).then((_) => _fetchRequests());
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: cardBg,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: borderColor),
                                    ),
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
                                                app.applicantName,
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                  color: textPrimary,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                  0xFF1E3A8A,
                                                ).withOpacity(0.12),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                'FORWARDED',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF2563EB),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${app.applicantEmployeeId} • ${app.departmentName}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFF334155)
                                                : const Color(0xFFF1F5F9),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                app.leaveTypeName,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: primaryColor,
                                                ),
                                              ),
                                              Text(
                                                '$startStr – $endStr (${app.totalDays}d)',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: textPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (app.headComment != null) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            'Head Note: ${app.headComment}',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontStyle: FontStyle.italic,
                                              color: textSecondary,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
