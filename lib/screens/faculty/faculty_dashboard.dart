// ─────────────────────────────────────────────────────────────────────────────
//  faculty_dashboard.dart  –  Faculty Dashboard Screen (Dark & Light Theme Aware)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../widgets/app_bottom_navigation.dart';

class FacultyDashboard extends StatefulWidget {
  const FacultyDashboard({super.key});

  @override
  State<FacultyDashboard> createState() => _FacultyDashboardState();
}

class _FacultyDashboardState extends State<FacultyDashboard> {
  int _currentNavIndex = 0;

  void _onBottomNavTap(int index) {
    if (index == _currentNavIndex) return;
    setState(() => _currentNavIndex = index);
    switch (index) {
      case 1:
        Navigator.pushNamed(context, AppRoutes.myLeaves);
        break;
      case 2:
        Navigator.pushNamed(context, AppRoutes.notifications);
        break;
      case 3:
        Navigator.pushNamed(context, AppRoutes.profile);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeState.instance.themeModeNotifier,
      builder: (context, themeMode, child) {
        final isDark = themeMode == ThemeMode.dark;
        final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFB);
        final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
        final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
        final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
        final textHint = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
        final primaryColor = isDark ? const Color(0xFF0D9488) : AppColors.primary;
        final dividerColor = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          ),
          child: Scaffold(
            backgroundColor: bgColor,
            body: SafeArea(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 1. HEADER (PROFILE + NOTIFICATIONS) ──────────────────────
                    Row(
                      children: [
                        // Profile Avatar
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            image: DecorationImage(
                              image: AssetImage('assets/images/profile.jpg'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Name & Designation
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${AppHelpers.getGreetingPrefix()}, Md. Arman',
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Assistant Professor • CSE',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Notification Button
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, AppRoutes.notifications),
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
                      onTap: () => Navigator.pushNamed(context, AppRoutes.applyLeave),
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
                            Icon(Icons.add_rounded, color: Colors.white, size: 20),
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
                          SizedBox(
                            width: 124,
                            child: _LeaveBalanceCard(
                              title: 'Casual Leave',
                              count: '6',
                              progress: 0.4,
                              cardBg: cardBg,
                              borderColor: borderColor,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                              progressColor: primaryColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 124,
                            child: _LeaveBalanceCard(
                              title: 'Duty Leave',
                              count: '4',
                              progress: 0.3,
                              cardBg: cardBg,
                              borderColor: borderColor,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                              progressColor: primaryColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 124,
                            child: _LeaveBalanceCard(
                              title: 'Station Leave',
                              count: '2',
                              progress: 0.2,
                              cardBg: cardBg,
                              borderColor: borderColor,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                              progressColor: primaryColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 124,
                            child: _LeaveBalanceCard(
                              title: 'Study Leave',
                              count: '15',
                              progress: 0.8,
                              cardBg: cardBg,
                              borderColor: borderColor,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                              progressColor: primaryColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 124,
                            child: _LeaveBalanceCard(
                              title: 'Others',
                              count: '5',
                              progress: 0.5,
                              cardBg: cardBg,
                              borderColor: borderColor,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                              progressColor: primaryColor,
                            ),
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
                          onTap: () => Navigator.pushNamed(context, AppRoutes.myLeaves),
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
                      child: Column(
                        children: [
                          _RecentLeaveTile(
                            title: 'Casual Leave',
                            dateRange: 'Sep 18 – Sep 20',
                            status: 'Pending',
                            statusBg: isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
                            statusColor: const Color(0xFFD97706),
                            textPrimary: textPrimary,
                            textHint: textHint,
                          ),
                          Divider(height: 1, color: dividerColor),
                          _RecentLeaveTile(
                            title: 'Duty Leave',
                            dateRange: 'Sep 22 – Sep 24',
                            status: 'Approved',
                            statusBg: isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7),
                            statusColor: const Color(0xFF16A34A),
                            textPrimary: textPrimary,
                            textHint: textHint,
                          ),
                          Divider(height: 1, color: dividerColor),
                          _RecentLeaveTile(
                            title: 'Station Leave',
                            dateRange: 'Oct 01 – Oct 03',
                            status: 'Approved',
                            statusBg: isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7),
                            statusColor: const Color(0xFF16A34A),
                            textPrimary: textPrimary,
                            textHint: textHint,
                          ),
                          Divider(height: 1, color: dividerColor),
                          _RecentLeaveTile(
                            title: 'Study Leave',
                            dateRange: 'Oct 10 – Oct 15',
                            status: 'Rejected',
                            statusBg: isDark ? const Color(0xFF451A1A) : const Color(0xFFFEE2E2),
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
                            onTap: () => Navigator.pushNamed(context, AppRoutes.myLeaves),
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
                            onTap: () => Navigator.pushNamed(context, AppRoutes.deptCalendar),
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
}

class _LeaveBalanceCard extends StatelessWidget {
  final String title;
  final String count;
  final double progress;
  final Color cardBg;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color progressColor;

  const _LeaveBalanceCard({
    required this.title,
    required this.count,
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
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: count,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                TextSpan(
                  text: ' days',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
