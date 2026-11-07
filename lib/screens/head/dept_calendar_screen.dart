// ─────────────────────────────────────────────────────────────────────────────
//  dept_calendar_screen.dart  –  Department Head Calendar Screen
//  Pixel-perfect implementation of Department Calendar UI (All 3 Views:
//  1. Overview & Calendar Grid
//  2. Selected Day Faculty Leaves Card (25 Sep)
//  3. Filters & Upcoming Leaves View)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../widgets/app_bottom_navigation.dart';

class DeptCalendarScreen extends StatefulWidget {
  const DeptCalendarScreen({super.key});

  @override
  State<DeptCalendarScreen> createState() => _DeptCalendarScreenState();
}

class _DeptCalendarScreenState extends State<DeptCalendarScreen> {
  int _currentNavIndex = 2; // 2: Calendar tab active
  String _selectedViewTab = 'Month'; // 'Month', 'Week', 'Day'
  int _selectedDay = 25; // Default to 25 to match screenshot
  bool _showDayDetails = true; // True: Screen 2, False: Screen 1
  bool _isFilterViewActive = false; // True: Screen 3

  // Filter state for Screen 3
  String _selectedStatusFilter = 'All'; // 'All', 'Approved', 'Pending', 'Upcoming'
  String _selectedLeaveType = 'All Leave Types';
  String _selectedFaculty = 'All Faculty';
  bool _isFilterCardExpanded = true;

  void _onBottomNavTap(int index) {
    if (index == _currentNavIndex) return;
    setState(() => _currentNavIndex = index);
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, AppRoutes.headDashboard);
        break;
      case 1:
        Navigator.pushReplacementNamed(context, AppRoutes.headRequests);
        break;
      case 2:
        break;
      case 3:
        Navigator.pushReplacementNamed(context, AppRoutes.headProfile);
        break;
    }
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
        final primaryColor =
            isDark ? const Color(0xFF047857) : const Color(0xFF1B4332);
        final subtleBg =
            isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          ),
          child: Scaffold(
            backgroundColor: bgColor,
            // ── APPBAR ──────────────────────────────────────────────────────
            appBar: AppBar(
              backgroundColor: cardBg,
              elevation: 0,
              scrolledUnderElevation: 0,
              centerTitle: false,
              leading: _isFilterViewActive
                  ? IconButton(
                      icon: Icon(
                        Icons.arrow_back,
                        color: textPrimary,
                        size: 22,
                      ),
                      onPressed: () {
                        setState(() => _isFilterViewActive = false);
                      },
                    )
                  : Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Center(
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.calendar_month_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Department Calendar',
                    style: TextStyle(
                      fontSize: 17.5,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (!_isFilterViewActive)
                    Text(
                      'CSE Department • Faculty Leave Overview',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
                    ),
                ],
              ),
              actions: [
                if (_isFilterViewActive)
                  IconButton(
                    icon: Icon(
                      Icons.filter_alt_outlined,
                      color: primaryColor,
                      size: 22,
                    ),
                    onPressed: () {},
                  )
                else ...[
                  IconButton(
                    icon: Icon(
                      Icons.filter_list_rounded,
                      color: textPrimary,
                      size: 22,
                    ),
                    onPressed: () {
                      setState(() => _isFilterViewActive = true);
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.notifications_none_rounded,
                      color: textPrimary,
                      size: 22,
                    ),
                    onPressed: () {},
                  ),
                ],
                const SizedBox(width: 8),
              ],
            ),

            // ── BODY CONTENT ────────────────────────────────────────────────
            body: SafeArea(
              child: _isFilterViewActive
                  ? _buildFilterView(
                      cardBg: cardBg,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      primaryColor: primaryColor,
                      isDark: isDark,
                      subtleBg: subtleBg,
                    )
                  : _buildCalendarView(
                      cardBg: cardBg,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      primaryColor: primaryColor,
                      isDark: isDark,
                      subtleBg: subtleBg,
                    ),
            ),
            bottomNavigationBar: AppBottomNavigation(
              currentIndex: _currentNavIndex,
              role: 'department_head',
              onTap: _onBottomNavTap,
            ),
          ),
        );
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  VIEW 1 & 2: CALENDAR & OVERVIEW / SELECTED DAY
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildCalendarView({
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color primaryColor,
    required bool isDark,
    required Color subtleBg,
  }) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. VIEW SEGMENTED SWITCHER (Month | Week | Day) ────────────────
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: subtleBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildSegmentTab('Month', primaryColor),
                _buildSegmentTab('Week', primaryColor),
                _buildSegmentTab('Day', primaryColor),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── 2. MONTH SELECTOR & TODAY ROW ──────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.chevron_left_rounded,
                      size: 24,
                      color: textPrimary,
                    ),
                    onPressed: () {},
                  ),
                  const SizedBox(width: 4),
                  Row(
                    children: [
                      Text(
                        'September 2026',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: textPrimary,
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.chevron_right_rounded,
                      size: 24,
                      color: textPrimary,
                    ),
                    onPressed: () {},
                  ),
                ],
              ),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _selectedDay = 25;
                    _showDayDetails = true;
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: textPrimary,
                  side: BorderSide(color: borderColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Today',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── 3. CALENDAR GRID CARD ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                // Weekday Header: Sun, Mon, Tue, Wed, Thu, Fri, Sat
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: const [
                    _WeekdayHeader('Sun'),
                    _WeekdayHeader('Mon'),
                    _WeekdayHeader('Tue'),
                    _WeekdayHeader('Wed'),
                    _WeekdayHeader('Thu'),
                    _WeekdayHeader('Fri'),
                    _WeekdayHeader('Sat'),
                  ],
                ),

                const SizedBox(height: 10),

                // Row 1: 30(other), 31(other), 1, 2, 3, 4(green dot), 5
                Row(
                  children: [
                    _buildDayCell(day: 30, isOtherMonth: true, textPrimary: textPrimary),
                    _buildDayCell(day: 31, isOtherMonth: true, textPrimary: textPrimary),
                    _buildDayCell(day: 1, textPrimary: textPrimary),
                    _buildDayCell(day: 2, textPrimary: textPrimary),
                    _buildDayCell(day: 3, textPrimary: textPrimary),
                    _buildDayCell(
                      day: 4,
                      dots: [const Color(0xFF16A34A)],
                      textPrimary: textPrimary,
                    ),
                    _buildDayCell(day: 5, textPrimary: textPrimary),
                  ],
                ),

                const SizedBox(height: 6),

                // Row 2: 6, 7, 8(orange dot), 9, 10, 11(green dot), 12
                Row(
                  children: [
                    _buildDayCell(day: 6, textPrimary: textPrimary),
                    _buildDayCell(day: 7, textPrimary: textPrimary),
                    _buildDayCell(
                      day: 8,
                      dots: [const Color(0xFFF59E0B)],
                      textPrimary: textPrimary,
                    ),
                    _buildDayCell(day: 9, textPrimary: textPrimary),
                    _buildDayCell(day: 10, textPrimary: textPrimary),
                    _buildDayCell(
                      day: 11,
                      dots: [const Color(0xFF16A34A)],
                      textPrimary: textPrimary,
                    ),
                    _buildDayCell(day: 12, textPrimary: textPrimary),
                  ],
                ),

                const SizedBox(height: 6),

                // Row 3: 13, 14, 15(blue dot), 16(green dot), 17(orange dot), 18, 19
                Row(
                  children: [
                    _buildDayCell(day: 13, textPrimary: textPrimary),
                    _buildDayCell(day: 14, textPrimary: textPrimary),
                    _buildDayCell(
                      day: 15,
                      dots: [const Color(0xFF2563EB)],
                      textPrimary: textPrimary,
                    ),
                    _buildDayCell(
                      day: 16,
                      dots: [const Color(0xFF16A34A)],
                      textPrimary: textPrimary,
                    ),
                    _buildDayCell(
                      day: 17,
                      dots: [const Color(0xFFF59E0B)],
                      textPrimary: textPrimary,
                    ),
                    _buildDayCell(day: 18, textPrimary: textPrimary),
                    _buildDayCell(day: 19, textPrimary: textPrimary),
                  ],
                ),

                const SizedBox(height: 6),

                // Row 4: 20, 21, 22, 23, 24, 25(SELECTED), 26
                Row(
                  children: [
                    _buildDayCell(day: 20, textPrimary: textPrimary),
                    _buildDayCell(day: 21, textPrimary: textPrimary),
                    _buildDayCell(day: 22, textPrimary: textPrimary),
                    _buildDayCell(day: 23, textPrimary: textPrimary),
                    _buildDayCell(day: 24, textPrimary: textPrimary),
                    _buildDayCell(
                      day: 25,
                      isSelected: true,
                      dots: [const Color(0xFF16A34A), const Color(0xFFF59E0B)],
                      textPrimary: textPrimary,
                    ),
                    _buildDayCell(day: 26, textPrimary: textPrimary),
                  ],
                ),

                const SizedBox(height: 6),

                // Row 5: 27, 28(blue dot), 29(blue dot), 30, 1(other), 2(other), 3(other)
                Row(
                  children: [
                    _buildDayCell(day: 27, textPrimary: textPrimary),
                    _buildDayCell(
                      day: 28,
                      dots: [const Color(0xFF2563EB)],
                      textPrimary: textPrimary,
                    ),
                    _buildDayCell(
                      day: 29,
                      dots: [const Color(0xFF2563EB)],
                      textPrimary: textPrimary,
                    ),
                    _buildDayCell(day: 30, textPrimary: textPrimary),
                    _buildDayCell(day: 1, isOtherMonth: true, textPrimary: textPrimary),
                    _buildDayCell(day: 2, isOtherMonth: true, textPrimary: textPrimary),
                    _buildDayCell(day: 3, isOtherMonth: true, textPrimary: textPrimary),
                  ],
                ),

                const SizedBox(height: 16),

                // Legend Row: Approved, Pending, Upcoming, Conflict
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: const [
                    _LegendDot(color: Color(0xFF16A34A), label: 'Approved'),
                    _LegendDot(color: Color(0xFFF59E0B), label: 'Pending'),
                    _LegendDot(color: Color(0xFF2563EB), label: 'Upcoming'),
                    _LegendDot(color: Color(0xFFDC2626), label: 'Conflict'),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── 4. LOWER CARD (TOGGLES BETWEEN SCREEN 1 & SCREEN 2) ───────────
          if (_showDayDetails)
            _buildDayLeavesCard(
              cardBg: cardBg,
              borderColor: borderColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              isDark: isDark,
            )
          else
            _buildDepartmentOverviewCard(
              cardBg: cardBg,
              borderColor: borderColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              isDark: isDark,
            ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  SCREEN 2 LOWER CARD: "25 September 2026 • Friday"
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildDayLeavesCard({
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
          // Header: Date & Close Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 18,
                    color: Color(0xFF16A34A),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$_selectedDay September 2026 • Friday',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(Icons.close_rounded, size: 18, color: textSecondary),
                onPressed: () {
                  setState(() => _showDayDetails = false);
                },
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Item 1: Mr. Tanvir Hasan (Approved)
          _buildDayFacultyItem(
            name: 'Mr. Tanvir Hasan',
            designation: 'Lecturer',
            status: 'Approved',
            statusColor: const Color(0xFF16A34A),
            statusBg: isDark
                ? const Color(0xFF064E3B).withValues(alpha: 0.5)
                : const Color(0xFFDCFCE7),
            detailText: 'Medical Leave • 2 Days\n(25 Sep – 26 Sep, 2026)',
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            isDark: isDark,
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.headRequestDetails);
            },
          ),

          const SizedBox(height: 14),
          Divider(
            height: 1,
            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
          ),
          const SizedBox(height: 14),

          // Item 2: Dr. Farhana Yasmin (Pending)
          _buildDayFacultyItem(
            name: 'Dr. Farhana Yasmin',
            designation: 'Associate Professor',
            status: 'Pending',
            statusColor: const Color(0xFFD97706),
            statusBg: isDark
                ? const Color(0xFF451A03).withValues(alpha: 0.5)
                : const Color(0xFFFEF3C7),
            detailText: 'Earned Leave • 5 Days\n(28 Sep – 02 Oct, 2026)',
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            isDark: isDark,
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.headRequestDetails);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDayFacultyItem({
    required String name,
    required String designation,
    required String status,
    required Color statusColor,
    required Color statusBg,
    required String detailText,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person, size: 20, color: textPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  designation,
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        detailText,
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
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  SCREEN 1 LOWER CARD: "Department Overview (Sep)"
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildDepartmentOverviewCard({
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
          GestureDetector(
            onTap: () {
              setState(() => _showDayDetails = true);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.bar_chart_rounded,
                      size: 20,
                      color: Color(0xFF16A34A),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Department Overview (Sep)',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: textSecondary,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 4 Stat Columns: 12 Total, 7 Approved, 3 Pending, 2 Upcoming
          Row(
            children: [
              _buildStatCol('12', 'Total Leave', textPrimary, textSecondary),
              _buildDivider(isDark),
              _buildStatCol('7', 'Approved', const Color(0xFF16A34A), textSecondary),
              _buildDivider(isDark),
              _buildStatCol('3', 'Pending', const Color(0xFFF59E0B), textSecondary),
              _buildDivider(isDark),
              _buildStatCol('2', 'Upcoming', const Color(0xFF2563EB), textSecondary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCol(
    String value,
    String label,
    Color valColor,
    Color textSecondary,
  ) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: valColor,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      width: 1,
      height: 32,
      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  VIEW 3: FILTERS & UPCOMING LEAVES VIEW (SCREEN 3)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildFilterView({
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color primaryColor,
    required bool isDark,
    required Color subtleBg,
  }) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. FILTERS CARD ───────────────────────────────────────────────
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
                GestureDetector(
                  onTap: () {
                    setState(() => _isFilterCardExpanded = !_isFilterCardExpanded);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            size: 18,
                            color: textPrimary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Filters',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Icon(
                        _isFilterCardExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 22,
                        color: textSecondary,
                      ),
                    ],
                  ),
                ),

                if (_isFilterCardExpanded) ...[
                  const SizedBox(height: 16),

                  // Leave Status
                  Text(
                    'Leave Status',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildStatusChip('All', primaryColor, isDark),
                        const SizedBox(width: 8),
                        _buildStatusChip('Approved', primaryColor, isDark),
                        const SizedBox(width: 8),
                        _buildStatusChip('Pending', primaryColor, isDark),
                        const SizedBox(width: 8),
                        _buildStatusChip('Upcoming', primaryColor, isDark),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Leave Type Dropdown
                  Text(
                    'Leave Type',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedLeaveType,
                          style: TextStyle(fontSize: 13.5, color: textPrimary),
                        ),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: textSecondary,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Faculty Dropdown
                  Text(
                    'Faculty',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedFaculty,
                          style: TextStyle(fontSize: 13.5, color: textPrimary),
                        ),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: textSecondary,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Buttons: Apply Filter & Reset
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: ElevatedButton(
                          onPressed: () {
                            AppHelpers.showSuccess(context, 'Filters applied.');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Apply Filter',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _selectedStatusFilter = 'All';
                              _selectedLeaveType = 'All Leave Types';
                              _selectedFaculty = 'All Faculty';
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textPrimary,
                            side: BorderSide(color: borderColor),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Reset',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── 2. UPCOMING LEAVES SECTION ────────────────────────────────────
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_month_rounded,
                          size: 18,
                          color: Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Upcoming Leaves',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {},
                      child: const Text(
                        'View All',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E40AF),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Item 1: Dr. Anwar Hussain (Upcoming)
                _buildUpcomingItem(
                  name: 'Dr. Anwar Hussain',
                  subtitle: 'Duty Leave • 1 Day\n28 Sep, 2026',
                  status: 'Upcoming',
                  statusColor: const Color(0xFF2563EB),
                  statusBg: isDark
                      ? const Color(0xFF1E3A8A).withValues(alpha: 0.4)
                      : const Color(0xFFEFF6FF),
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  isDark: isDark,
                ),

                const SizedBox(height: 14),
                Divider(
                  height: 1,
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                ),
                const SizedBox(height: 14),

                // Item 2: Ms. Sadia Karim (Upcoming)
                _buildUpcomingItem(
                  name: 'Ms. Sadia Karim',
                  subtitle: 'Medical Leave • 2 Days\n30 Sep – 01 Oct, 2026',
                  status: 'Upcoming',
                  statusColor: const Color(0xFF2563EB),
                  statusBg: isDark
                      ? const Color(0xFF1E3A8A).withValues(alpha: 0.4)
                      : const Color(0xFFEFF6FF),
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  isDark: isDark,
                ),

                const SizedBox(height: 14),
                Divider(
                  height: 1,
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                ),
                const SizedBox(height: 14),

                // Item 3: Dr. Farhana Yasmin (Pending)
                _buildUpcomingItem(
                  name: 'Dr. Farhana Yasmin',
                  subtitle: 'Earned Leave • 5 Days\n28 Sep – 02 Oct, 2026',
                  status: 'Pending',
                  statusColor: const Color(0xFFD97706),
                  statusBg: isDark
                      ? const Color(0xFF451A03).withValues(alpha: 0.5)
                      : const Color(0xFFFEF3C7),
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  isDark: isDark,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildUpcomingItem({
    required String name,
    required String subtitle,
    required String status,
    required Color statusColor,
    required Color statusBg,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.person, size: 20, color: textPrimary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: textSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  HELPER WIDGETS
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildSegmentTab(String title, Color primaryColor) {
    final isSelected = _selectedViewTab == title;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedViewTab = title);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDayCell({
    required int day,
    bool isOtherMonth = false,
    bool isSelected = false,
    List<Color> dots = const [],
    required Color textPrimary,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!isOtherMonth) {
            setState(() {
              _selectedDay = day;
              _showDayDetails = true;
            });
          }
        },
        child: Container(
          height: 48,
          decoration: isSelected
              ? BoxDecoration(
                  color: const Color(0xFF1B4332), // Dark green selected
                  borderRadius: BorderRadius.circular(10),
                )
              : null,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$day',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : isOtherMonth
                          ? (isDark
                              ? const Color(0xFF475569)
                              : const Color(0xFFCBD5E1))
                          : textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              if (dots.isNotEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: dots
                      .map(
                        (c) => Container(
                          width: 4.5,
                          height: 4.5,
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                      .toList(),
                )
              else
                const SizedBox(height: 4.5),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, Color primaryColor, bool isDark) {
    final isSelected = _selectedStatusFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedStatusFilter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : (isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  final String text;
  const _WeekdayHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}
