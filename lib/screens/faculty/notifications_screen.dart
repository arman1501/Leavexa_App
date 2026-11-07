// ─────────────────────────────────────────────────────────────────────────────
//  notifications_screen.dart  –  Faculty Notifications Screen
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../widgets/app_bottom_navigation.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final int _currentNavIndex = 2; // 2: Notifications active
  String _selectedFilter = 'All';

  final List<Map<String, dynamic>> _notifications = [
    {
      'title': 'Medical Leave Approved',
      'body':
          'Your leave request for 25 Sep – 26 Sep (2 Days) has been approved by Department Head.',
      'time': 'Today, 09:15 AM',
      'type': 'leave',
      'icon': Icons.check_circle_outline_rounded,
      'iconColor': const Color(0xFF16A34A),
      'isUnread': true,
    },
    {
      'title': 'Teaching Coverage Confirmed',
      'body':
          'Ms. Sadia Karim has accepted class coverage for CS 201 Data Structures Lab.',
      'time': 'Yesterday, 04:30 PM',
      'type': 'coverage',
      'icon': Icons.groups_outlined,
      'iconColor': const Color(0xFF2563EB),
      'isUnread': true,
    },
    {
      'title': 'Fall Term 2026 Routine Published',
      'body':
          'Mid-term assessment schedules and exam duties have been updated by Academic Affairs.',
      'time': '2 days ago',
      'type': 'system',
      'icon': Icons.calendar_month_outlined,
      'iconColor': const Color(0xFFD97706),
      'isUnread': false,
    },
    {
      'title': 'Casual Leave Endorsed',
      'body':
          'Your casual leave request for 20 Sep – 22 Sep was endorsed and archived.',
      'time': '18 Sep, 11:20 AM',
      'type': 'leave',
      'icon': Icons.verified_outlined,
      'iconColor': const Color(0xFF16A34A),
      'isUnread': false,
    },
  ];

  void _onBottomNavTap(int index) {
    if (index == _currentNavIndex) return;
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, AppRoutes.facultyDashboard);
        break;
      case 1:
        Navigator.pushReplacementNamed(context, AppRoutes.myLeaves);
        break;
      case 2:
        break;
      case 3:
        Navigator.pushReplacementNamed(context, AppRoutes.profile);
        break;
    }
  }

  void _markAllAsRead() {
    setState(() {
      for (var n in _notifications) {
        n['isUnread'] = false;
      }
    });
    AppHelpers.showSuccess(context, 'All notifications marked as read');
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeState.instance.themeModeNotifier,
      builder: (context, themeMode, child) {
        final isDark = themeMode == ThemeMode.dark;
        final bgColor =
            isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
        final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final borderColor =
            isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
        final textPrimary =
            isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
        final textSecondary =
            isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

        final filtered = _notifications.where((n) {
          if (_selectedFilter == 'Unread') return n['isUnread'] == true;
          if (_selectedFilter == 'Leaves') return n['type'] == 'leave';
          return true;
        }).toList();

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          ),
          child: Scaffold(
            backgroundColor: bgColor,
            appBar: AppBar(
              backgroundColor: cardBg,
              elevation: 0,
              scrolledUnderElevation: 0,
              automaticallyImplyLeading: false,
              title: Text(
                'Notifications',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _markAllAsRead,
                  child: const Text(
                    'Mark all read',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: SafeArea(
              child: Column(
                children: [
                  // Filter Pills
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: ['All', 'Unread', 'Leaves'].map((filter) {
                        final isSelected = _selectedFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _selectedFilter = filter),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (isDark
                                        ? const Color(0xFF047857)
                                        : const Color(0xFF1B4332))
                                    : (isDark
                                        ? const Color(0xFF1E293B)
                                        : Colors.white),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.transparent
                                      : borderColor,
                                ),
                              ),
                              child: Text(
                                filter,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? Colors.white
                                      : textSecondary,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // Notifications List
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final isUnread = item['isUnread'] == true;

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isUnread
                                  ? const Color(0xFF16A34A).withValues(alpha: 0.5)
                                  : borderColor,
                              width: isUnread ? 1.5 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: (item['iconColor'] as Color)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  item['icon deadly'] ?? item['icon'],
                                  color: item['iconColor'] as Color,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item['title'] as String,
                                            style: TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: isUnread
                                                  ? FontWeight.w800
                                                  : FontWeight.w700,
                                              color: textPrimary,
                                            ),
                                          ),
                                        ),
                                        if (isUnread)
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF16A34A),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item['body'] as String,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w400,
                                        color: textSecondary,
                                        height: 1.35,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      item['time'] as String,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
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
