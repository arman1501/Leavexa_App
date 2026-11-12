// ─────────────────────────────────────────────────────────────────────────────
//  dept_calendar_screen.dart  –  Department Head Calendar Screen
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../models/leave_application_model.dart';
import '../../models/user_model.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/leave_repository.dart';
import '../../repositories/user_repository.dart';
import '../../widgets/app_bottom_navigation.dart';

class DeptCalendarScreen extends StatefulWidget {
  final AuthRepository? authRepository;
  final LeaveRepository? leaveRepository;
  final UserRepository? userRepository;

  const DeptCalendarScreen({
    super.key,
    this.authRepository,
    this.leaveRepository,
    this.userRepository,
  });

  @override
  State<DeptCalendarScreen> createState() => _DeptCalendarScreenState();
}

class _DeptCalendarScreenState extends State<DeptCalendarScreen> {
  late final AuthRepository _authRepo =
      widget.authRepository ?? AuthRepository();
  late final LeaveRepository _leaveRepo =
      widget.leaveRepository ?? LeaveRepository();
  late final UserRepository _userRepo =
      widget.userRepository ?? UserRepository();

  String _departmentTitle = 'Department Faculty Leave Overview';
  int _currentNavIndex = 2;
  String _selectedViewTab = 'Month';
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _selectedDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  bool _showDayDetails = true;
  bool _isFilterViewActive = false;

  bool _isLoading = true;
  String? _errorMessage;
  List<LeaveApplicationModel> _deptApplications = [];
  List<UserModel> _deptFaculty = [];

  // Filter state
  String _selectedStatusFilter = 'All';
  String _selectedLeaveType = 'All Leave Types';

  @override
  void initState() {
    super.initState();
    _loadDepartmentData();
  }

  Future<void> _loadDepartmentData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final user = await _authRepo.getCurrentUserProfile();
      if (!mounted) return;
      final deptId = user?.departmentId.trim() ?? '';
      if (deptId.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Missing department assignment for this Head account.';
        });
        return;
      }

      final name = user!.departmentName.trim().isNotEmpty
          ? user.departmentName.trim()
          : (AppConstants.departmentIdToCanonicalName[deptId] ?? deptId);

      final results = await Future.wait([
        _leaveRepo.departmentApplications(deptId),
        _userRepo.getFacultyByDepartment(deptId),
      ]);

      if (!mounted) return;
      setState(() {
        _departmentTitle = '$name • Faculty Leave Overview';
        _deptApplications = results[0] as List<LeaveApplicationModel>;
        _deptFaculty = results[1] as List<UserModel>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load department calendar: $e';
      });
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      final next = DateTime(_focusedMonth.year, _focusedMonth.month + delta, 1);
      _focusedMonth = next;
      final daysInNext = DateUtils.getDaysInMonth(next.year, next.month);
      final clampedDay = _selectedDate.day.clamp(1, daysInNext);
      _selectedDate = DateTime(next.year, next.month, clampedDay);
    });
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _focusedMonth = DateTime(now.year, now.month, 1);
      _selectedDate = DateTime(now.year, now.month, now.day);
      _showDayDetails = true;
    });
  }

  bool _coversDate(LeaveApplicationModel app, DateTime day) {
    final target = DateTime(day.year, day.month, day.day);
    final start = DateTime(
      app.startDate.year,
      app.startDate.month,
      app.startDate.day,
    );
    final end = DateTime(app.endDate.year, app.endDate.month, app.endDate.day);
    return !target.isBefore(start) && !target.isAfter(end);
  }

  List<LeaveApplicationModel> _applicationsForDay(DateTime day) {
    return _deptApplications
        .where(
          (a) =>
              (a.status == 'approved' ||
                  a.status == 'pending' ||
                  a.status == 'forwarded') &&
              _coversDate(a, day),
        )
        .toList();
  }

  List<Color> _dotsForDay(DateTime day) {
    final apps = _applicationsForDay(day);
    if (apps.isEmpty) return const [];
    final dots = <Color>[];
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final hasApproved = apps.any((a) => a.status == 'approved');
    final hasPending = apps.any(
      (a) => a.status == 'pending' || a.status == 'forwarded',
    );
    final isUpcoming = hasApproved && day.isAfter(today);

    if (hasApproved) {
      dots.add(isUpcoming ? const Color(0xFF2563EB) : const Color(0xFF16A34A));
    }
    if (hasPending) {
      dots.add(const Color(0xFFF59E0B));
    }
    if (apps.length >= 2) {
      dots.add(const Color(0xFFDC2626));
    }
    return dots;
  }

  List<LeaveApplicationModel> get _filteredApplications {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    return _deptApplications.where((app) {
      if (_selectedStatusFilter == 'Approved' && app.status != 'approved') {
        return false;
      }
      if (_selectedStatusFilter == 'Pending' &&
          app.status != 'pending' &&
          app.status != 'forwarded') {
        return false;
      }
      if (_selectedStatusFilter == 'Upcoming' &&
          (app.status != 'approved' || !app.startDate.isAfter(today))) {
        return false;
      }
      if (_selectedLeaveType != 'All Leave Types' &&
          !app.leaveTypeName.toLowerCase().contains(
            _selectedLeaveType.toLowerCase(),
          )) {
        return false;
      }
      return true;
    }).toList();
  }

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
        const primaryColor = Color(0xFF0B6A41);

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
              backgroundColor: bgColor,
              elevation: 0,
              scrolledUnderElevation: 0,
              automaticallyImplyLeading: false,
              titleSpacing: 16,
              title: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (_isFilterViewActive) {
                        setState(() => _isFilterViewActive = false);
                      } else {
                        Navigator.pushReplacementNamed(
                          context,
                          AppRoutes.headDashboard,
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: textPrimary,
                        size: 24,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Department Calendar',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          _departmentTitle,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: _isFilterViewActive ? 'Calendar View' : 'Filter Leaves',
                  icon: Icon(
                    _isFilterViewActive
                        ? Icons.calendar_month_rounded
                        : Icons.filter_list_rounded,
                    color: _isFilterViewActive ? primaryColor : textPrimary,
                    size: 22,
                  ),
                  onPressed: () {
                    setState(() => _isFilterViewActive = !_isFilterViewActive);
                  },
                ),
                IconButton(
                  tooltip: 'Notifications',
                  icon: Icon(
                    Icons.notifications_none_rounded,
                    color: textPrimary,
                    size: 22,
                  ),
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.notifications);
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: SafeArea(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: textSecondary),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _loadDepartmentData,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _isFilterViewActive
                  ? _buildFilterView(
                      isDark: isDark,
                      cardBg: cardBg,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      primaryColor: primaryColor,
                    )
                  : _buildCalendarView(
                      isDark: isDark,
                      cardBg: cardBg,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      primaryColor: primaryColor,
                    ),
            ),
            bottomNavigationBar: AppBottomNavigation(
              currentIndex: _currentNavIndex,
              onTap: _onBottomNavTap,
              role: 'department_head',
            ),
          ),
        );
      },
    );
  }

  Widget _buildCalendarView({
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color primaryColor,
  }) {
    final monthLabel = DateFormat('MMMM yyyy').format(_focusedMonth);
    final firstWeekdayOffset = _focusedMonth.weekday % 7; // Sun=0..Sat=6
    final daysInMonth =
        DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
    final prevMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
    final daysInPrevMonth =
        DateUtils.getDaysInMonth(prevMonth.year, prevMonth.month);

    final totalCells = ((firstWeekdayOffset + daysInMonth + 6) ~/ 7) * 7;
    final rows = <Widget>[];
    for (int rowStart = 0; rowStart < totalCells; rowStart += 7) {
      final cells = <Widget>[];
      for (int col = 0; col < 7; col++) {
        final idx = rowStart + col;
        if (idx < firstWeekdayOffset) {
          final dayNum = daysInPrevMonth - (firstWeekdayOffset - 1 - idx);
          cells.add(
            _buildDayCell(
              day: dayNum,
              date: DateTime(prevMonth.year, prevMonth.month, dayNum),
              isOtherMonth: true,
              textPrimary: textPrimary,
            ),
          );
        } else if (idx >= firstWeekdayOffset + daysInMonth) {
          final dayNum = idx - (firstWeekdayOffset + daysInMonth) + 1;
          final nextMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
          cells.add(
            _buildDayCell(
              day: dayNum,
              date: DateTime(nextMonth.year, nextMonth.month, dayNum),
              isOtherMonth: true,
              textPrimary: textPrimary,
            ),
          );
        } else {
          final dayNum = idx - firstWeekdayOffset + 1;
          final cellDate = DateTime(_focusedMonth.year, _focusedMonth.month, dayNum);
          cells.add(
            _buildDayCell(
              day: dayNum,
              date: cellDate,
              dots: _dotsForDay(cellDate),
              textPrimary: textPrimary,
            ),
          );
        }
      }
      rows.add(Row(children: cells));
      if (rowStart + 7 < totalCells) {
        rows.add(const SizedBox(height: 6));
      }
    }

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 40,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: ['Month', 'Week', 'Day'].map((tab) {
                final isSelected = _selectedViewTab == tab;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedViewTab = tab;
                        if (tab == 'Day') _showDayDetails = true;
                      });
                    },
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark ? const Color(0xFF334155) : Colors.white)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tab,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected ? textPrimary : textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Previous Month',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.chevron_left_rounded,
                      size: 24,
                      color: textPrimary,
                    ),
                    onPressed: () => _changeMonth(-1),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    monthLabel,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Next Month',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.chevron_right_rounded,
                      size: 24,
                      color: textPrimary,
                    ),
                    onPressed: () => _changeMonth(1),
                  ),
                ],
              ),
              OutlinedButton(
                onPressed: _goToToday,
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
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
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
                ...rows,
                const SizedBox(height: 14),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
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
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDayLeavesCard({
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
  }) {
    final dayLabel = DateFormat('d MMMM yyyy • EEEE').format(_selectedDate);
    final dayApps = _applicationsForDay(_selectedDate);

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
                    dayLabel,
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
          if (dayApps.isEmpty)
            Text(
              'No department leave applications scheduled for this date.',
              style: TextStyle(fontSize: 13, color: textSecondary),
            )
          else
            ...dayApps.map((app) {
              final isApproved = app.status == 'approved';
              final statusColor = isApproved
                  ? const Color(0xFF16A34A)
                  : const Color(0xFFD97706);
              final statusBg = isApproved
                  ? (isDark
                        ? const Color(0xFF064E3B).withValues(alpha: 0.5)
                        : const Color(0xFFDCFCE7))
                  : (isDark
                        ? const Color(0xFF78350F).withValues(alpha: 0.4)
                        : const Color(0xFFFEF3C7));
              final range =
                  '${DateFormat('d MMM').format(app.startDate)} – ${DateFormat('d MMM, yyyy').format(app.endDate)}';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildDayFacultyItem(
                  name: app.applicantName,
                  designation: app.applicantEmployeeId,
                  status: app.status[0].toUpperCase() + app.status.substring(1),
                  statusColor: statusColor,
                  statusBg: statusBg,
                  detailText:
                      '${app.leaveTypeName} • ${app.totalDays} Day(s)\n($range)',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  isDark: isDark,
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildDepartmentOverviewCard({
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final monthName = DateFormat('MMM').format(_focusedMonth);
    final monthApps = _deptApplications.where((a) {
      return (a.startDate.year == _focusedMonth.year &&
              a.startDate.month == _focusedMonth.month) ||
          (a.endDate.year == _focusedMonth.year &&
              a.endDate.month == _focusedMonth.month);
    }).toList();
    final approvedCount = monthApps.where((a) => a.status == 'approved').length;
    final pendingCount = monthApps
        .where((a) => a.status == 'pending' || a.status == 'forwarded')
        .length;

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
            onTap: () => setState(() => _showDayDetails = true),
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
                      'Department Overview ($monthName)',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
                Icon(Icons.chevron_right_rounded, size: 20, color: textSecondary),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _OverviewStat(
                label: 'Faculty',
                value: '${_deptFaculty.length}',
                color: textPrimary,
              ),
              _OverviewStat(
                label: 'Approved',
                value: '$approvedCount',
                color: const Color(0xFF16A34A),
              ),
              _OverviewStat(
                label: 'Pending',
                value: '$pendingCount',
                color: const Color(0xFFF59E0B),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterView({
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color primaryColor,
  }) {
    final filtered = _filteredApplications;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                Text(
                  'Filter Department Leaves',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['All', 'Approved', 'Pending', 'Upcoming'].map((f) {
                    final selected = _selectedStatusFilter == f;
                    return ChoiceChip(
                      label: Text(f),
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => _selectedStatusFilter = f),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedLeaveType,
                  decoration: InputDecoration(
                    labelText: 'Leave Type',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'All Leave Types',
                      child: Text('All Leave Types'),
                    ),
                    DropdownMenuItem(value: 'Casual', child: Text('Casual Leave')),
                    DropdownMenuItem(value: 'Medical', child: Text('Medical Leave')),
                    DropdownMenuItem(value: 'Earned', child: Text('Earned Leave')),
                    DropdownMenuItem(value: 'Duty', child: Text('Duty Leave')),
                    DropdownMenuItem(value: 'Study', child: Text('Study Leave')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedLeaveType = val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
                    Text(
                      'Matching Leaves (${filtered.length})',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(
                          context,
                          AppRoutes.headRequests,
                        );
                      },
                      child: const Text('View All'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (filtered.isEmpty)
                  Text(
                    'No leave applications match the selected filters.',
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  )
                else
                  ...filtered.take(20).map((app) {
                    final range =
                        '${DateFormat('d MMM').format(app.startDate)} – ${DateFormat('d MMM, yyyy').format(app.endDate)}';
                    final isApproved = app.status == 'approved';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildUpcomingItem(
                        name: app.applicantName,
                        subtitle:
                            '${app.leaveTypeName} • ${app.totalDays} Day(s)\n$range',
                        status:
                            app.status[0].toUpperCase() + app.status.substring(1),
                        statusColor: isApproved
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF2563EB),
                        statusBg: isDark
                            ? const Color(0xFF1E3A8A).withValues(alpha: 0.4)
                            : const Color(0xFFEFF6FF),
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        isDark: isDark,
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell({
    required int day,
    required DateTime date,
    bool isOtherMonth = false,
    List<Color> dots = const [],
    required Color textPrimary,
  }) {
    final isSelected =
        !isOtherMonth &&
        date.year == _selectedDate.year &&
        date.month == _selectedDate.month &&
        date.day == _selectedDate.day;

    return Expanded(
      child: GestureDetector(
        onTap: isOtherMonth
            ? null
            : () {
                setState(() {
                  _selectedDate = date;
                  _showDayDetails = true;
                });
              },
        child: Container(
          height: 44,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0B6A41) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$day',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : isOtherMonth
                      ? textPrimary.withValues(alpha: 0.3)
                      : textPrimary,
                ),
              ),
              if (dots.isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: dots
                      .map(
                        (c) => Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : c,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
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
                  Expanded(
                    child: Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
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
              if (designation.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  designation,
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                detailText,
                style: TextStyle(
                  fontSize: 12.5,
                  color: textPrimary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
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
    return _buildDayFacultyItem(
      name: name,
      designation: '',
      status: status,
      statusColor: statusColor,
      statusBg: statusBg,
      detailText: subtitle,
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      isDark: isDark,
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  final String label;
  const _WeekdayHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFF64748B),
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
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
        ),
      ],
    );
  }
}

class _OverviewStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _OverviewStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
      ],
    );
  }
}
