// ─────────────────────────────────────────────────────────────────────────────
//  my_leaves_screen.dart  –  My Leaves & History Screen (Dark & Light Theme Aware)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_bottom_navigation.dart';

class MyLeavesScreen extends StatefulWidget {
  const MyLeavesScreen({super.key});

  @override
  State<MyLeavesScreen> createState() => _MyLeavesScreenState();
}

class _MyLeavesScreenState extends State<MyLeavesScreen> {
  int _selectedFilterIndex = 0; // 0: All, 1: Pending, 2: Approved, 3: Rejected
  int _currentNavIndex = 1; // 1: My Leaves tab active

  final List<Map<String, dynamic>> _allLeaves = const [
    {
      'title': 'Casual Leave',
      'code': 'CL',
      'dateRange': 'Sep 18 – Sep 20, 2026',
      'duration': '3 Days',
      'status': 'Pending',
      'reason': 'Family emergency requirement',
      'appliedOn': 'Applied Sep 15, 2026',
    },
    {
      'title': 'Duty Leave',
      'code': 'DL',
      'dateRange': 'Sep 22 – Sep 24, 2026',
      'duration': '3 Days',
      'status': 'Approved',
      'reason': 'Attending IEEE International Conference',
      'appliedOn': 'Applied Sep 10, 2026',
    },
    {
      'title': 'Station Leave',
      'code': 'STL',
      'dateRange': 'Oct 01 – Oct 03, 2026',
      'duration': '3 Days',
      'status': 'Approved',
      'reason': 'Official university workshop in Dhaka',
      'appliedOn': 'Applied Sep 20, 2026',
    },
    {
      'title': 'Study Leave',
      'code': 'SL',
      'dateRange': 'Oct 10 – Oct 15, 2026',
      'duration': '6 Days',
      'status': 'Rejected',
      'reason': 'PhD dissertation research phase',
      'appliedOn': 'Applied Sep 25, 2026',
    },
    {
      'title': 'Others',
      'code': 'OTH',
      'dateRange': 'Nov 02 – Nov 06, 2026',
      'duration': '5 Days',
      'status': 'Approved',
      'reason': 'Special administrative duty leave',
      'appliedOn': 'Applied Oct 28, 2026',
    },
  ];

  List<Map<String, dynamic>> get _filteredLeaves {
    switch (_selectedFilterIndex) {
      case 1:
        return _allLeaves.where((l) => l['status'] == 'Pending').toList();
      case 2:
        return _allLeaves.where((l) => l['status'] == 'Approved').toList();
      case 3:
        return _allLeaves.where((l) => l['status'] == 'Rejected').toList();
      default:
        return _allLeaves;
    }
  }

  void _onBottomNavTap(int index) {
    if (index == _currentNavIndex) return;
    setState(() => _currentNavIndex = index);
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, AppRoutes.facultyDashboard);
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
    final filteredList = _filteredLeaves;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeState.instance.themeModeNotifier,
      builder: (context, themeMode, child) {
        final isDark = themeMode == ThemeMode.dark;
        final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFB);
        final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
        final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
        final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
        final primaryColor = isDark ? const Color(0xFF34D399) : const Color(0xFF1B4332);

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          ),
          child: Scaffold(
            backgroundColor: bgColor,
            body: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── TOP HEADER ─────────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: cardBg,
                              border: Border.all(color: borderColor),
                            ),
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 18,
                              color: textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'My Leaves & History',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── FILTER TABS ────────────────────────────────────────────────
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'All (${_allLeaves.length})',
                          isSelected: _selectedFilterIndex == 0,
                          isDark: isDark,
                          onTap: () => setState(() => _selectedFilterIndex = 0),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Pending (${_allLeaves.where((l) => l['status'] == 'Pending').length})',
                          isSelected: _selectedFilterIndex == 1,
                          isDark: isDark,
                          onTap: () => setState(() => _selectedFilterIndex = 1),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Approved (${_allLeaves.where((l) => l['status'] == 'Approved').length})',
                          isSelected: _selectedFilterIndex == 2,
                          isDark: isDark,
                          onTap: () => setState(() => _selectedFilterIndex = 2),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Rejected (${_allLeaves.where((l) => l['status'] == 'Rejected').length})',
                          isSelected: _selectedFilterIndex == 3,
                          isDark: isDark,
                          onTap: () => setState(() => _selectedFilterIndex = 3),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ── LEAVES LIST ────────────────────────────────────────────────
                  Expanded(
                    child: filteredList.isEmpty
                        ? Center(
                            child: Text(
                              'No leave applications found',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                color: textSecondary,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            physics: const BouncingScrollPhysics(),
                            itemCount: filteredList.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = filteredList[index];
                              return _LeaveHistoryCard(
                                item: item,
                                isDark: isDark,
                                cardBg: cardBg,
                                borderColor: borderColor,
                                textPrimary: textPrimary,
                                textSecondary: textSecondary,
                                primaryColor: primaryColor,
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeBg = isDark ? const Color(0xFF0D9488) : const Color(0xFF042F2C);
    final inactiveBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final inactiveBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final activeText = Colors.white;
    final inactiveText = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeBg : inactiveBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? activeText : inactiveText,
          ),
        ),
      ),
    );
  }
}

class _LeaveHistoryCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isDark;
  final Color cardBg;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color primaryColor;

  const _LeaveHistoryCard({
    required this.item,
    required this.isDark,
    required this.cardBg,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.primaryColor,
  });

  Color _getStatusBg(String status) {
    switch (status) {
      case 'Approved':
        return isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7);
      case 'Rejected':
        return isDark ? const Color(0xFF451A1A) : const Color(0xFFFEE2E2);
      default:
        return isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Approved':
        return const Color(0xFF16A34A);
      case 'Rejected':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFFD97706);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = item['status'] as String;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item['code'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    item['title'] as String,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusBg(status),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(status),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item['reason'] as String,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 14,
                    color: textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    item['dateRange'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
              Text(
                item['duration'] as String,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
