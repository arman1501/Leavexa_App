// ─────────────────────────────────────────────────────────────────────────────
//  head_dashboard.dart  –  Department Head Dashboard Screen
//  Pixel-perfect implementation of Department Head Console UI design
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../models/leave_application_model.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/leave_repository.dart';
import '../../repositories/user_repository.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_bottom_navigation.dart';

class HeadDashboard extends StatefulWidget {
  final LeaveRepository? leaveRepository;
  final AuthRepository? authRepository;
  final UserRepository? userRepository;

  const HeadDashboard({
    super.key,
    this.leaveRepository,
    this.authRepository,
    this.userRepository,
  });

  @override
  State<HeadDashboard> createState() => _HeadDashboardState();
}

class _HeadDashboardState extends State<HeadDashboard> {
  late final LeaveRepository _leaveRepo =
      widget.leaveRepository ?? LeaveRepository();
  late final AuthRepository _authRepo =
      widget.authRepository ?? AuthRepository();
  late final UserRepository _userRepo =
      widget.userRepository ?? UserRepository();

  StreamSubscription<List<LeaveApplicationModel>>? _deptAppsSub;
  int _currentNavIndex = 0;
  String _selectedFilter = 'All';
  bool _hasFetchedReal = false;
  bool _missingDeptAssignment = false;
  String _headName = 'Department Head';
  String _deptId = '';
  String _deptName = 'Academic Department';
  String? _headPhotoUrl;
  int _approvedDeptCount = 0;
  int _rejectedDeptCount = 0;
  int _awayTodayCount = 0;
  int _deptFacultyCount = 0;
  List<Map<String, dynamic>> _realPendingRequests = [];
  List<Map<String, dynamic>> _realRecentDecisions = [];

  @override
  void initState() {
    super.initState();
    _loadRealData();
  }

  @override
  void dispose() {
    _deptAppsSub?.cancel();
    super.dispose();
  }

  void _applyDepartmentApplications(List<LeaveApplicationModel> apps) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final pendingApps = <LeaveApplicationModel>[];
    final decidedApps = <LeaveApplicationModel>[];
    int approved = 0;
    int rejected = 0;
    int awayToday = 0;

    for (final a in apps) {
      if (_deptId.isNotEmpty && a.departmentId != _deptId) continue;
      if (a.isPending) {
        pendingApps.add(a);
      } else if (a.isForwarded || a.isApproved) {
        approved++;
        decidedApps.add(a);
        if (a.isApproved) {
          final s = DateTime(a.startDate.year, a.startDate.month, a.startDate.day);
          final e = DateTime(a.endDate.year, a.endDate.month, a.endDate.day);
          if (!today.isBefore(s) && !today.isAfter(e)) {
            awayToday++;
          }
        }
      } else if (a.isRejected) {
        rejected++;
        decidedApps.add(a);
      }
    }

    final mappedPending = pendingApps.map((a) {
      final startStr = DateFormat('dd MMM').format(a.startDate);
      final endStr = DateFormat('dd MMM').format(a.endDate);
      final fullDates =
          '${DateFormat('dd MMM').format(a.startDate)} – ${DateFormat('dd MMM, yyyy').format(a.endDate)}';
      return {
        'id': a.id,
        'applicantUid': a.applicantUid,
        'departmentId': a.departmentId,
        'facultyName': a.applicantName,
        'facultyId': a.applicantEmployeeId,
        'designation': 'Faculty Member • ${a.departmentName}',
        'leaveType': a.leaveTypeName,
        'accentColor': a.leaveTypeName.toLowerCase().contains('medical')
            ? const Color(0xFFDC2626)
            : const Color(0xFF16A34A),
        'dateRange': '$startStr – $endStr',
        'datesFull': fullDates,
        'duration': '${a.totalDays} Day${a.totalDays > 1 ? 's' : ''}',
        'rxAttached': a.documentUrl != null && a.documentUrl!.isNotEmpty,
        'teachingCovered': 'Class coverage arranged',
        'reason': a.reason,
        'totalDaysNum': a.totalDays,
        'model': a,
      };
    }).toList();

    final mappedDecisions = decidedApps.take(5).map((a) {
      final actionAt = a.headActionAt ?? a.appliedAt;
      final dateLabel = DateFormat('dd MMM, hh:mm a').format(actionAt);
      final endorsed = a.isForwarded || a.isApproved;
      return {
        'name': a.applicantName,
        'leaveType': a.leaveTypeName,
        'detail': endorsed
            ? 'Endorsed to Registrar • $dateLabel'
            : 'Rejected by Dept. Head • $dateLabel',
        'status': endorsed ? 'Forwarded' : 'Rejected',
        'isApproved': endorsed,
      };
    }).toList();

    if (!mounted) return;
    setState(() {
      _realPendingRequests = mappedPending;
      _realRecentDecisions = mappedDecisions;
      _approvedDeptCount = approved;
      _rejectedDeptCount = rejected;
      _awayTodayCount = awayToday;
      _hasFetchedReal = true;
    });
  }

  Future<void> _loadRealData() async {
    try {
      final user = await _authRepo.getCurrentUserProfile();
      if (user == null || user.departmentId.trim().isEmpty) {
        if (mounted) {
          setState(() {
            _missingDeptAssignment = true;
            _realPendingRequests = [];
            _realRecentDecisions = [];
            _hasFetchedReal = true;
          });
        }
        return;
      }

      final deptId = user.departmentId.trim();
      final resolvedDeptName = user.departmentName.trim().isNotEmpty
          ? user.departmentName.trim()
          : (AppConstants.departmentIdToCanonicalName[deptId] ?? deptId);

      if (mounted) {
        setState(() {
          _missingDeptAssignment = false;
          _deptId = deptId;
          _deptName = resolvedDeptName;
          _headName = user.fullName.isNotEmpty ? user.fullName : 'Department Head';
          _headPhotoUrl = user.photoUrl;
        });
      }

      // Fetch department-scoped faculty count & applications strictly filtered by departmentId
      try {
        final deptUsers = await _userRepo.getFacultyByDepartment(deptId);
        final activeFaculty = deptUsers
            .where((u) => u.isFaculty && u.isActiveAndApproved && UserRepository.isGenuineUser(u))
            .length;
        if (mounted) {
          setState(() => _deptFacultyCount = activeFaculty);
        }
      } catch (_) {}

      final allDeptApps = await _leaveRepo.departmentApplications(deptId);
      if (allDeptApps.isNotEmpty) {
        _applyDepartmentApplications(allDeptApps);
      } else {
        final pendingOnly = await _leaveRepo.departmentPending(deptId);
        _applyDepartmentApplications(pendingOnly);
      }

      await _deptAppsSub?.cancel();
      _deptAppsSub = _leaveRepo.streamDepartmentApplications(deptId).listen(
        (apps) {
          if (apps.isNotEmpty || _hasFetchedReal) {
            _applyDepartmentApplications(apps);
          }
        },
        onError: (_) {},
      );
    } catch (_) {
      if (mounted && !_hasFetchedReal) {
        setState(() {
          _realPendingRequests = [];
          _realRecentDecisions = [];
          _hasFetchedReal = true;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _displayPendingRequests => _realPendingRequests;

  List<Map<String, dynamic>> get _filteredPendingRequests {
    if (_selectedFilter == 'All') return _displayPendingRequests;
    return _displayPendingRequests.where((item) {
      final type = (item['leaveType'] as String? ?? '').toLowerCase();
      final days = (item['totalDaysNum'] as int?) ?? 1;
      switch (_selectedFilter) {
        case 'Medical':
          return type.contains('medical') || type.contains('sick');
        case 'Casual':
          return type.contains('casual');
        case 'Urgent':
          return type.contains('medical') || days >= 3;
        default:
          return true;
      }
    }).toList();
  }

  List<Map<String, dynamic>> get _recentDecisions => _realRecentDecisions;

  void _onBottomNavTap(int index) {
    if (index == _currentNavIndex) return;
    setState(() => _currentNavIndex = index);
    switch (index) {
      case 0:
        // Already on Dashboard
        break;
      case 1:
        Navigator.pushReplacementNamed(context, AppRoutes.headRequests);
        break;
      case 2:
        Navigator.pushReplacementNamed(context, AppRoutes.deptCalendar);
        break;
      case 3:
        Navigator.pushReplacementNamed(context, AppRoutes.headProfile);
        break;
    }
  }

  void _onEndorseRequest(int index) async {
    final visible = _filteredPendingRequests;
    if (index < 0 || index >= visible.length) return;
    final item = visible[index];
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.headReviewRequest,
      arguments: item,
    );
    if (result != null) {
      _loadRealData();
    }
  }

  void _onViewDetails(Map<String, dynamic> item) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.headRequestDetails,
      arguments: item,
    );
    if (result != null) {
      _loadRealData();
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
        final primaryColor = isDark
            ? const Color(0xFF34D399)
            : const Color(0xFF1B4332);

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
                  vertical: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 1. TOP APP BAR (LOGO & PROFILE/NOTIF) ────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: primaryColor.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'LX',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: primaryColor,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Leavexa',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: textPrimary,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                Text(
                                  'Dept. Head Portal',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            // Notification bell with badge dot
                            GestureDetector(
                              onTap: () => Navigator.pushNamed(
                                context,
                                AppRoutes.notifications,
                              ),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isDark
                                          ? const Color(0xFF1E293B)
                                          : const Color(0xFFF1F5F9),
                                    ),
                                    child: Icon(
                                      Icons.notifications_none_rounded,
                                      size: 22,
                                      color: textPrimary,
                                    ),
                                  ),
                                  if (_displayPendingRequests.isNotEmpty)
                                    Positioned(
                                      top: 10,
                                      right: 10,
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF16A34A),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Profile Avatar button
                            GestureDetector(
                              onTap: () async {
                                await Navigator.pushNamed(
                                  context,
                                  AppRoutes.headProfile,
                                );
                                _loadRealData();
                              },
                              child: AppAvatar(
                                name: _headName,
                                photoUrl: _headPhotoUrl,
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // ── 2. CONSOLE TAG & ACADEMIC TERM ROW ───────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'DEPARTMENT HEAD CONSOLE',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF16A34A),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
                                : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? const Color(
                                      0xFF1E40AF,
                                    ).withValues(alpha: 0.5)
                                  : const Color(0xFFDBEAFE),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF16A34A),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '$_deptFacultyCount Faculty',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? const Color(0xFF93C5FD)
                                      : const Color(0xFF1E40AF),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // ── 3. GREETING TITLE & DEPT SUBTITLE ────────────────────
                    Text(
                      '${AppHelpers.getGreetingPrefix()}, $_headName',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _deptName,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
                    ),

                    if (_missingDeptAssignment) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: const Text(
                          'Department assignment is missing or inconsistent on this Head account. Access is blocked.',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF991B1B),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 18),

                    // ── 4. 3 SUMMARY STAT CARDS ──────────────────────────────
                    Row(
                      children: [
                        // Card 1: PENDING (Highlighted)
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(
                                      0xFF064E3B,
                                    ).withValues(alpha: 0.5)
                                  : const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF047857)
                                    : const Color(0xFFA7F3D0),
                                width: 1.2,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PENDING',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? const Color(0xFF34D399)
                                        : const Color(0xFF166534),
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _displayPendingRequests.length < 10
                                      ? '0${_displayPendingRequests.length}'
                                      : '${_displayPendingRequests.length}',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? const Color(0xFF6EE7B7)
                                        : const Color(0xFF064E3B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Needs Review',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? const Color(0xFFA7F3D0)
                                          : const Color(0xFF15803D),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Card 2: APPROVED
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'APPROVED',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: textSecondary,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _approvedDeptCount < 10
                                      ? '0$_approvedDeptCount'
                                      : '$_approvedDeptCount',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Endorsed / Approved',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Card 3: REJECTED
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'REJECTED',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: textSecondary,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _rejectedDeptCount < 10
                                      ? '0$_rejectedDeptCount'
                                      : '$_rejectedDeptCount',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Declined Req.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ── 5. QUICK ACTION CARDS (PENDING QUEUE & LEAVE CALENDAR) ──
                    Row(
                      children: [
                        // Pending Queue Card
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRoutes.headRequests,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: borderColor),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF334155)
                                          : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.tune_rounded,
                                      size: 18,
                                      color: textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Pending Queue',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: textPrimary,
                                                ),
                                              ),
                                            ),
                                            Icon(
                                              Icons.chevron_right_rounded,
                                              size: 16,
                                              color: textSecondary,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${_displayPendingRequests.length} actionable',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? const Color(0xFF34D399)
                                                : const Color(0xFF16A34A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Leave Calendar Card
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRoutes.deptCalendar,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: borderColor),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF334155)
                                          : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.calendar_month_outlined,
                                      size: 18,
                                      color: textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Leave Calendar',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: textPrimary,
                                                ),
                                              ),
                                            ),
                                            Icon(
                                              Icons.chevron_right_rounded,
                                              size: 16,
                                              color: textSecondary,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$_awayTodayCount away today',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
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
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // ── 6. FILTER CHIPS ROW ──────────────────────────────────
                    Builder(
                      builder: (context) {
                        final allCount = _displayPendingRequests.length;
                        final urgentCount = _displayPendingRequests.where((i) {
                          final t = (i['leaveType'] as String? ?? '').toLowerCase();
                          final d = (i['totalDaysNum'] as int?) ?? 1;
                          return t.contains('medical') || d >= 3;
                        }).length;
                        final medCount = _displayPendingRequests.where((i) {
                          final t = (i['leaveType'] as String? ?? '').toLowerCase();
                          return t.contains('medical') || t.contains('sick');
                        }).length;
                        final casCount = _displayPendingRequests.where((i) {
                          final t = (i['leaveType'] as String? ?? '').toLowerCase();
                          return t.contains('casual');
                        }).length;
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              _FilterChip(
                                label: 'All ($allCount)',
                                isSelected: _selectedFilter == 'All',
                                onTap: () =>
                                    setState(() => _selectedFilter = 'All'),
                                isDark: isDark,
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'Urgent ($urgentCount)',
                                isSelected: _selectedFilter == 'Urgent',
                                onTap: () =>
                                    setState(() => _selectedFilter = 'Urgent'),
                                isDark: isDark,
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'Medical ($medCount)',
                                isSelected: _selectedFilter == 'Medical',
                                onTap: () =>
                                    setState(() => _selectedFilter = 'Medical'),
                                isDark: isDark,
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'Casual ($casCount)',
                                isSelected: _selectedFilter == 'Casual',
                                onTap: () =>
                                    setState(() => _selectedFilter = 'Casual'),
                                isDark: isDark,
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 22),

                    // ── 7. PENDING LEAVE ENDORSEMENTS SECTION HEADER ──────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Pending Leave\nEndorsements',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                            height: 1.15,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF064E3B)
                                    : const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '${_displayPendingRequests.length} Awaiting',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF16A34A),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.headRequests,
                                );
                              },
                              child: const Text(
                                'View All',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF16A34A),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ── 8. PENDING LEAVE CARDS LIST ──────────────────────────
                    if (_filteredPendingRequests.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 44,
                              color: Color(0xFF16A34A),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'All Endorsements Completed!',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'No pending leave applications awaiting your review.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredPendingRequests.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final item = _filteredPendingRequests[index];
                          final accentColor =
                              item['accentColor'] as Color? ??
                              const Color(0xFF16A34A);

                          return Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor),
                            ),
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Left Colored Accent Stripe
                                  Container(width: 4.5, color: accentColor),
                                  // Card Content Body
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Top row: Name & Leave Type Pill
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      item['facultyName']
                                                          as String,
                                                      style: TextStyle(
                                                        fontSize: 15.5,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: textPrimary,
                                                        letterSpacing: -0.2,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      item['designation']
                                                          as String,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: textSecondary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: isDark
                                                      ? const Color(
                                                          0xFF1E3A8A,
                                                        ).withValues(alpha: 0.4)
                                                      : const Color(0xFFEFF6FF),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  item['leaveType'] as String,
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: isDark
                                                        ? const Color(
                                                            0xFF93C5FD,
                                                          )
                                                        : const Color(
                                                            0xFF1E40AF,
                                                          ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),

                                          const SizedBox(height: 12),

                                          // Date & Duration Box (Full width light blue/lavender container)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? const Color(0xFF0F172A)
                                                  : const Color(0xFFF1F5F9),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .calendar_today_outlined,
                                                      size: 15,
                                                      color: textSecondary,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      '${item['dateRange']}   •   ${item['duration']}',
                                                      style: TextStyle(
                                                        fontSize: 12.5,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: textPrimary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (item['rxAttached'] == true)
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFF86EFAC,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                    ),
                                                    child: const Text(
                                                      'Rx Attached',
                                                      style: TextStyle(
                                                        fontSize: 10.5,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: Color(
                                                          0xFF064E3B,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),

                                          const SizedBox(height: 10),

                                          // Teaching Covered Row
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Icon(
                                                Icons.assignment_ind_outlined,
                                                size: 16,
                                                color: Color(0xFF16A34A),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: RichText(
                                                  text: TextSpan(
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: textSecondary,
                                                      height: 1.3,
                                                    ),
                                                    children: [
                                                      const TextSpan(
                                                        text:
                                                            'Teaching Covered by: ',
                                                      ),
                                                      TextSpan(
                                                        text:
                                                            item['teachingCovered']
                                                                as String,
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: textPrimary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),

                                          const SizedBox(height: 8),

                                          // Reason text
                                          Text(
                                            item['reason'] as String,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              color: textSecondary,
                                              height: 1.35,
                                            ),
                                          ),

                                          const SizedBox(height: 14),

                                          // Action Buttons Row
                                          Row(
                                            children: [
                                              Expanded(
                                                child: OutlinedButton(
                                                  onPressed: () =>
                                                      _onViewDetails(item),
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor:
                                                        textPrimary,
                                                    side: BorderSide(
                                                      color: borderColor,
                                                    ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                    ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 12,
                                                        ),
                                                  ),
                                                  child: const Text(
                                                    'View Details',
                                                    style: TextStyle(
                                                      fontSize: 12.5,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: ElevatedButton(
                                                  onPressed: () =>
                                                      _onEndorseRequest(index),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: isDark
                                                        ? const Color(
                                                            0xFF047857,
                                                          )
                                                        : const Color(
                                                            0xFF1B4332,
                                                          ),
                                                    foregroundColor:
                                                        Colors.white,
                                                    elevation: 0,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                    ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 12,
                                                        ),
                                                  ),
                                                  child: const Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        'Review & Endorse',
                                                        style: TextStyle(
                                                          fontSize: 12.5,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                      SizedBox(width: 4),
                                                      Icon(
                                                        Icons
                                                            .arrow_forward_rounded,
                                                        size: 15,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                    const SizedBox(height: 24),

                    // ── 9. RECENT DECISIONS SECTION ──────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Decisions',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          'Last 48 hrs',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    if (_recentDecisions.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Text(
                          'No recent department decisions yet.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: textSecondary,
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _recentDecisions.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = _recentDecisions[index];
                        final isApproved = item['isApproved'] as bool;

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isApproved
                                      ? (isDark
                                            ? const Color(0xFF064E3B)
                                            : const Color(0xFFDCFCE7))
                                      : (isDark
                                            ? const Color(0xFF334155)
                                            : const Color(0xFFF1F5F9)),
                                ),
                                child: Icon(
                                  isApproved
                                      ? Icons.check_rounded
                                      : Icons.undo_rounded,
                                  size: 18,
                                  color: isApproved
                                      ? const Color(0xFF16A34A)
                                      : textSecondary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${item['name']} • ${item['leaveType']}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item['detail'] as String,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isApproved
                                      ? (isDark
                                            ? const Color(0xFF064E3B)
                                            : const Color(0xFFDCFCE7))
                                      : (isDark
                                            ? const Color(
                                                0xFF1E3A8A,
                                              ).withValues(alpha: 0.4)
                                            : const Color(0xFFEFF6FF)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item['status'] as String,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isApproved
                                        ? const Color(0xFF16A34A)
                                        : (isDark
                                              ? const Color(0xFF93C5FD)
                                              : const Color(0xFF1E40AF)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
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
}

// ─────────────────────────────────────────────────────────────────────────────
//  Filter Chip Widget
// ─────────────────────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final activeBg = isDark ? const Color(0xFF047857) : const Color(0xFF1B4332);
    final inactiveBg = isDark
        ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
        : const Color(0xFFEFF6FF);
    final inactiveBorder = isDark
        ? const Color(0xFF1E40AF).withValues(alpha: 0.5)
        : const Color(0xFFDBEAFE);
    final activeText = Colors.white;
    final inactiveText = isDark
        ? const Color(0xFF93C5FD)
        : const Color(0xFF1E40AF);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? null : Border.all(color: inactiveBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? activeText : inactiveText,
          ),
        ),
      ),
    );
  }
}
