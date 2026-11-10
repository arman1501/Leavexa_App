// ─────────────────────────────────────────────────────────────────────────────
//  faculty_dashboard.dart  –  Faculty Dashboard Screen (Dark & Light Theme Aware)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../models/faculty_profile_state.dart';
import '../../models/leave_application_model.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/leave_repository.dart';
import '../../services/notification_service.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_bottom_navigation.dart';

class FacultyDashboard extends StatefulWidget {
  final LeaveRepository? leaveRepository;
  final AuthRepository? authRepository;
  final NotificationService? notificationService;

  const FacultyDashboard({
    super.key,
    this.leaveRepository,
    this.authRepository,
    this.notificationService,
  });

  @override
  State<FacultyDashboard> createState() => _FacultyDashboardState();
}

class _FacultyDashboardState extends State<FacultyDashboard> {
  late final LeaveRepository _leaveRepo =
      widget.leaveRepository ?? LeaveRepository();
  late final AuthRepository _authRepo =
      widget.authRepository ?? AuthRepository();
  late final NotificationService _notifService =
      widget.notificationService ?? NotificationService();

  int _currentNavIndex = 0;
  bool _hasFetchedReal = false;
  int _unreadNotifCount = 0;
  List<LeaveApplicationModel> _realRecentLeaves = [];
  final Map<String, ({int remaining, int total, int used})> _realBalances = {
    'Casual': (remaining: 10, total: 10, used: 0),
    'Medical': (remaining: 14, total: 14, used: 0),
    'Earned': (remaining: 30, total: 30, used: 0),
    'Duty': (remaining: 15, total: 15, used: 0),
    'Station': (remaining: 5, total: 5, used: 0),
    'Study': (remaining: 30, total: 30, used: 0),
  };

  @override
  void initState() {
    super.initState();
    _loadRealData();
  }

  Future<void> _loadRealData() async {
    try {
      final user = await _authRepo.getCurrentUserProfile();
      final uid = user?.uid ?? _authRepo.currentUserId;
      if (uid == null) return;

      final balances = await _leaveRepo.balancesForUser(uid);
      final apps = await _leaveRepo.myApplications(uid);
      final notifs = await _notifService.getForUser(uid);

      if (mounted) {
        setState(() {
          _hasFetchedReal = true;
          _unreadNotifCount = notifs.where((n) => !n.isRead).length;
          _realRecentLeaves = apps;
          for (final b in balances) {
            String key = b.leaveTypeName.split(' ').first;
            if (key.toLowerCase() == 'sick' ||
                b.leaveTypeId == 'sick' ||
                b.leaveTypeId == 'medical') {
              key = 'Medical';
            }
            if (_realBalances.containsKey(key)) {
              final rem = b.remainingDays < 0 ? 0 : b.remainingDays;
              _realBalances[key] = (
                remaining: rem,
                total: b.totalAllotted,
                used: b.used,
              );
            }
          }
        });
      }
    } catch (_) {}
  }

  void _onBottomNavTap(int index) {
    if (index == _currentNavIndex) return;
    setState(() => _currentNavIndex = index);
    switch (index) {
      case 0:
        // Already on Dashboard
        break;
      case 1:
        Navigator.pushReplacementNamed(context, AppRoutes.myLeaves);
        break;
      case 2:
        Navigator.pushReplacementNamed(context, AppRoutes.notifications);
        break;
      case 3:
        Navigator.pushReplacementNamed(context, AppRoutes.profile);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeState.instance.themeModeNotifier,
      builder: (context, themeMode, child) {
        final isDark = themeMode == ThemeMode.dark;
        final bgColor = isDark
            ? const Color(0xFF0F172A)
            : const Color(0xFFF8FAFB);
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
        final textHint = isDark
            ? const Color(0xFF64748B)
            : const Color(0xFF94A3B8);
        final primaryColor = isDark
            ? const Color(0xFF0D9488)
            : AppColors.primary;
        final dividerColor = isDark
            ? const Color(0xFF334155)
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
            body: SafeArea(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 1. HEADER (PROFILE + NOTIFICATIONS) ──────────────────────
                    Row(
                      children: [
                        // Profile Avatar (Tappable -> Faculty Profile)
                        ValueListenableBuilder<FacultyProfileData>(
                          valueListenable:
                              FacultyProfileState.instance.notifier,
                          builder: (context, profileData, _) {
                            return GestureDetector(
                              key: const Key('faculty_dashboard_avatar'),
                              onTap: () => Navigator.pushReplacementNamed(
                                context,
                                AppRoutes.profile,
                              ),
                              child: AppAvatar(
                                name: profileData.fullName,
                                photoUrl: profileData.photoUrl,
                                size: 44,
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        // Name & Designation (Synced with Faculty Profile State)
                        Expanded(
                          child: ValueListenableBuilder<FacultyProfileData>(
                            valueListenable:
                                FacultyProfileState.instance.notifier,
                            builder: (context, profileData, _) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${AppHelpers.getGreetingPrefix()}, ${profileData.fullName}',
                                    style: TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${profileData.designation} • CSE',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                      color: textSecondary,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        // Notification Button
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(
                            context,
                            AppRoutes.notifications,
                          ),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: cardBg,
                              border: Border.all(color: borderColor),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  Icons.notifications_none_rounded,
                                  size: 20,
                                  color: textSecondary,
                                ),
                                if (!_hasFetchedReal || _unreadNotifCount > 0)
                                  Positioned(
                                    top: 9,
                                    right: 9,
                                    child: Container(
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF16A34A),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── 2. PRIMARY ACTION (APPLY FOR LEAVE) ──────────────────────
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.applyLeave,
                      ).then((_) => _loadRealData()),
                      child: Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.18),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Apply for Leave',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── 3. LEAVE BALANCE SECTION ─────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'LEAVE BALANCE',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: textSecondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          'Academic Year ${DateTime.now().year}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildBalanceCard(
                            title: 'Casual Leave',
                            typeKey: 'Casual',
                            cardBg: cardBg,
                            borderColor: borderColor,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            primaryColor: primaryColor,
                          ),
                          const SizedBox(width: 10),
                          _buildBalanceCard(
                            title: 'Medical Leave',
                            typeKey: 'Medical',
                            cardBg: cardBg,
                            borderColor: borderColor,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            primaryColor: primaryColor,
                          ),
                          const SizedBox(width: 10),
                          _buildBalanceCard(
                            title: 'Earned Leave',
                            typeKey: 'Earned',
                            cardBg: cardBg,
                            borderColor: borderColor,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            primaryColor: primaryColor,
                          ),
                          const SizedBox(width: 10),
                          _buildBalanceCard(
                            title: 'Duty Leave',
                            typeKey: 'Duty',
                            cardBg: cardBg,
                            borderColor: borderColor,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            primaryColor: primaryColor,
                          ),
                          const SizedBox(width: 10),
                          _buildBalanceCard(
                            title: 'Station Leave',
                            typeKey: 'Station',
                            cardBg: cardBg,
                            borderColor: borderColor,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            primaryColor: primaryColor,
                          ),
                          const SizedBox(width: 10),
                          _buildBalanceCard(
                            title: 'Study Leave',
                            typeKey: 'Study',
                            cardBg: cardBg,
                            borderColor: borderColor,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            primaryColor: primaryColor,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── 4. RECENT LEAVES SECTION ─────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'RECENT LEAVES',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: textSecondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        GestureDetector(
                          onTap: () =>
                              Navigator.pushNamed(context, AppRoutes.myLeaves),
                          child: const Text(
                            'View all',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor),
                      ),
                      child: _hasFetchedReal && _realRecentLeaves.isNotEmpty
                          ? Column(
                              children: _realRecentLeaves.take(4).map((app) {
                                final isLast =
                                    app == _realRecentLeaves.take(4).last;
                                final status = app.status;
                                final statusBg = switch (status.toLowerCase()) {
                                  'approved' => isDark
                                      ? const Color(0xFF064E3B)
                                      : const Color(0xFFDCFCE7),
                                  'rejected' => isDark
                                      ? const Color(0xFF451A1A)
                                      : const Color(0xFFFEE2E2),
                                  'forwarded' => isDark
                                      ? const Color(0xFF1E3A8A)
                                      : const Color(0xFFDBEAFE),
                                  _ => isDark
                                      ? const Color(0xFF451A03)
                                      : const Color(0xFFFEF3C7),
                                };
                                final statusColor = switch (
                                    status.toLowerCase()) {
                                  'approved' => const Color(0xFF16A34A),
                                  'rejected' => const Color(0xFFDC2626),
                                  'forwarded' => const Color(0xFF2563EB),
                                  _ => const Color(0xFFD97706),
                                };
                                final dateStr =
                                    '${DateFormat('MMM dd').format(app.startDate)} – ${DateFormat('MMM dd').format(app.endDate)}';

                                return Column(
                                  children: [
                                    GestureDetector(
                                      onTap: () => Navigator.pushNamed(
                                        context,
                                        AppRoutes.leaveDetails,
                                        arguments: app,
                                      ),
                                      child: _RecentLeaveTile(
                                        title: app.leaveTypeName,
                                        dateRange: dateStr,
                                        status: status[0].toUpperCase() +
                                            status.substring(1),
                                        statusBg: statusBg,
                                        statusColor: statusColor,
                                        textPrimary: textPrimary,
                                        textHint: textHint,
                                      ),
                                    ),
                                    if (!isLast)
                                      Divider(height: 1, color: dividerColor),
                                  ],
                                );
                              }).toList(),
                            )
                          : Column(
                              children: [
                                _RecentLeaveTile(
                                  title: 'Casual Leave',
                                  dateRange: 'Sep 18 – Sep 20',
                                  status: 'Pending',
                                  statusBg: isDark
                                      ? const Color(0xFF451A03)
                                      : const Color(0xFFFEF3C7),
                                  statusColor: const Color(0xFFD97706),
                                  textPrimary: textPrimary,
                                  textHint: textHint,
                                ),
                                Divider(height: 1, color: dividerColor),
                                _RecentLeaveTile(
                                  title: 'Duty Leave',
                                  dateRange: 'Sep 22 – Sep 24',
                                  status: 'Approved',
                                  statusBg: isDark
                                      ? const Color(0xFF064E3B)
                                      : const Color(0xFFDCFCE7),
                                  statusColor: const Color(0xFF16A34A),
                                  textPrimary: textPrimary,
                                  textHint: textHint,
                                ),
                                Divider(height: 1, color: dividerColor),
                                _RecentLeaveTile(
                                  title: 'Station Leave',
                                  dateRange: 'Oct 01 – Oct 03',
                                  status: 'Approved',
                                  statusBg: isDark
                                      ? const Color(0xFF064E3B)
                                      : const Color(0xFFDCFCE7),
                                  statusColor: const Color(0xFF16A34A),
                                  textPrimary: textPrimary,
                                  textHint: textHint,
                                ),
                                Divider(height: 1, color: dividerColor),
                                _RecentLeaveTile(
                                  title: 'Study Leave',
                                  dateRange: 'Oct 10 – Oct 15',
                                  status: 'Rejected',
                                  statusBg: isDark
                                      ? const Color(0xFF451A1A)
                                      : const Color(0xFFFEE2E2),
                                  statusColor: const Color(0xFFDC2626),
                                  textPrimary: textPrimary,
                                  textHint: textHint,
                                ),
                              ],
                            ),
                    ),

                    const SizedBox(height: 24),

                    // ── 5. QUICK ACTIONS SECTION ─────────────────────────────────
                    Text(
                      'QUICK ACTIONS',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.calendar_today_rounded,
                            title: 'My Leaves',
                            subtitle: 'History & balance',
                            cardBg: cardBg,
                            borderColor: borderColor,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            iconColor: primaryColor,
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRoutes.myLeaves,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.calendar_month_rounded,
                            title: 'Calendar',
                            subtitle: 'Academic schedule',
                            cardBg: cardBg,
                            borderColor: borderColor,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            iconColor: primaryColor,
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRoutes.deptCalendar,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: AppBottomNavigation(
              currentIndex: _currentNavIndex,
              role: 'faculty',
              onTap: _onBottomNavTap,
            ),
          ),
        );
      },
    );
  }

  Widget _buildBalanceCard({
    required String title,
    required String typeKey,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color primaryColor,
  }) {
    final bal = _realBalances[typeKey] ?? (remaining: 0, total: 0, used: 0);
    final remaining = bal.remaining < 0 ? 0 : bal.remaining;
    final progress =
        bal.total > 0 ? (remaining / bal.total).clamp(0.0, 1.0) : 0.0;
    final subtitle = '${bal.used} used of ${bal.total}';

    return SizedBox(
      width: 128,
      child: _LeaveBalanceCard(
        title: title,
        count: remaining.toString(),
        subtitle: subtitle,
        progress: progress,
        cardBg: cardBg,
        borderColor: borderColor,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        progressColor: primaryColor,
      ),
    );
  }
}

class _LeaveBalanceCard extends StatelessWidget {
  final String title;
  final String count;
  final String? subtitle;
  final double progress;
  final Color cardBg;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color progressColor;

  const _LeaveBalanceCard({
    required this.title,
    required this.count,
    this.subtitle,
    required this.progress,
    required this.cardBg,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.progressColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                count,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'days',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: textSecondary,
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
                color: textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3.5,
              backgroundColor: textSecondary.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentLeaveTile extends StatelessWidget {
  final String title;
  final String dateRange;
  final String status;
  final Color statusBg;
  final Color statusColor;
  final Color textPrimary;
  final Color textHint;

  const _RecentLeaveTile({
    required this.title,
    required this.dateRange,
    required this.status,
    required this.statusBg,
    required this.statusColor,
    required this.textPrimary,
    required this.textHint,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                dateRange,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: textHint,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color cardBg;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color iconColor;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.cardBg,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w400,
                color: textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
