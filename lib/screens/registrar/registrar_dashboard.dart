// ─────────────────────────────────────────────────────────────────────────────
//  registrar_dashboard.dart  –  Dedicated Registrar / Dean Console
//  Displays institution-wide forwarded leave applications for final approval
//  or rejection. Strictly isolated from System Admin permissions.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../models/faculty_profile_state.dart';
import '../../models/leave_application_model.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/leave_repository.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_bottom_navigation.dart';

class RegistrarDashboard extends StatefulWidget {
  final LeaveRepository? leaveRepository;
  final AuthRepository? authRepository;

  const RegistrarDashboard({
    super.key,
    this.leaveRepository,
    this.authRepository,
  });

  @override
  State<RegistrarDashboard> createState() => _RegistrarDashboardState();
}

class _RegistrarDashboardState extends State<RegistrarDashboard> {
  late final LeaveRepository _leaveRepo =
      widget.leaveRepository ?? LeaveRepository();
  late final AuthRepository _authRepo =
      widget.authRepository ?? AuthRepository();

  StreamSubscription<List<LeaveApplicationModel>>? _forwardedSub;
  int _currentNavIndex = 0; // 0: Dashboard, 1: All Requests, 2: Profile
  String _selectedStatusTab = 'forwarded'; // forwarded | approved | rejected | all
  String _selectedDeptFilter = 'ALL';
  String _searchQuery = '';
  bool _isLoading = true;
  bool _isLoggingOut = false;

  String _registrarName = 'Office of the Registrar';
  String _registrarEmail = 'registrar.lu@gmail.com';
  String _registrarEmployeeId = 'REG-001';
  String? _photoUrl;
  List<LeaveApplicationModel> _applications = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _forwardedSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final user = await _authRepo.getCurrentUserProfile();
      if (user != null && mounted) {
        setState(() {
          _registrarName =
              user.fullName.isNotEmpty ? user.fullName : _registrarName;
          _registrarEmail =
              user.email.isNotEmpty ? user.email : _registrarEmail;
          _registrarEmployeeId =
              user.employeeId.isNotEmpty ? user.employeeId : _registrarEmployeeId;
          _photoUrl = user.photoUrl;
        });
      }

      List<LeaveApplicationModel> list = [];
      try {
        list = await _leaveRepo.registrarApplications();
      } catch (_) {}

      if (list.isEmpty) {
        try {
          list = await _leaveRepo.forwardedAll();
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _applications = list;
          _isLoading = false;
        });
      }

      await _forwardedSub?.cancel();
      _forwardedSub = _leaveRepo.streamForwardedAll().listen(
        (forwarded) {
          if (!mounted) return;
          final mapById = {for (final a in _applications) a.id: a};
          for (final f in forwarded) {
            mapById[f.id] = f;
          }
          final merged = mapById.values.toList()
            ..sort((a, b) => b.appliedAt.compareTo(a.appliedAt));
          setState(() => _applications = merged);
        },
        onError: (_) {},
      );
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<LeaveApplicationModel> get _filteredApplications {
    return _applications.where((a) {
      if (_selectedStatusTab != 'all' && a.status != _selectedStatusTab) {
        return false;
      }
      if (_selectedDeptFilter != 'ALL' && a.departmentId != _selectedDeptFilter) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final matchesName = a.applicantName.toLowerCase().contains(q);
        final matchesDept = a.departmentName.toLowerCase().contains(q);
        final matchesType = a.leaveTypeName.toLowerCase().contains(q);
        final matchesEmp = a.applicantEmployeeId.toLowerCase().contains(q);
        if (!matchesName && !matchesDept && !matchesType && !matchesEmp) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  void _onBottomNavTap(int index) {
    if (index == _currentNavIndex) return;
    setState(() {
      _currentNavIndex = index;
      if (index == 1) {
        _selectedStatusTab = 'all';
      } else if (index == 0) {
        _selectedStatusTab = 'forwarded';
      }
    });
  }

  Future<void> _openFinalApproval(LeaveApplicationModel app) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.finalApproval,
      arguments: app,
    );
    if (result == true) {
      _loadData();
    }
  }

  void _onLogOut() {
    showDialog(
      context: context,
      barrierDismissible: !_isLoggingOut,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text(
          'Are you sure you want to log out of the Registrar Portal?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: _isLoggingOut
                ? null
                : () async {
                    Navigator.pop(dialogCtx);
                    _forwardedSub?.cancel();
                    _forwardedSub = null;
                    await Future.delayed(const Duration(milliseconds: 80));
                    if (!mounted) return;
                    setState(() => _isLoggingOut = true);
                    try {
                      await _authRepo.logout();
                      FacultyProfileState.instance.reset();
                      if (!mounted) return;
                      Navigator.of(context, rootNavigator: true)
                          .pushNamedAndRemoveUntil(
                        AppRoutes.login,
                        (route) => false,
                      );
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        AppThemeState.instance.resetToLightMode();
                      });
                    } catch (e) {
                      if (mounted) {
                        setState(() => _isLoggingOut = false);
                        AppHelpers.showError(context, 'Failed to log out: $e');
                      }
                    }
                  },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
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
            isDark ? const Color(0xFF34D399) : AppColors.primary;

        final forwardedCount =
            _applications.where((a) => a.status == 'forwarded').length;
        final approvedCount =
            _applications.where((a) => a.status == 'approved').length;
        final rejectedCount =
            _applications.where((a) => a.status == 'rejected').length;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
          ),
          child: Scaffold(
            backgroundColor: bgColor,
            body: SafeArea(
              child: _currentNavIndex == 2
                  ? _buildProfileView(
                      cardBg: cardBg,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      primaryColor: primaryColor,
                      isDark: isDark,
                      forwardedCount: forwardedCount,
                      approvedCount: approvedCount,
                      rejectedCount: rejectedCount,
                    )
                  : _buildConsoleView(
                      cardBg: cardBg,
                      borderColor: borderColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      primaryColor: primaryColor,
                      isDark: isDark,
                      forwardedCount: forwardedCount,
                      approvedCount: approvedCount,
                      rejectedCount: rejectedCount,
                    ),
            ),
            bottomNavigationBar: AppBottomNavigation(
              currentIndex: _currentNavIndex,
              role: 'registrar',
              onTap: _onBottomNavTap,
            ),
          ),
        );
      },
    );
  }

  Widget _buildConsoleView({
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color primaryColor,
    required bool isDark,
    required int forwardedCount,
    required int approvedCount,
    required int rejectedCount,
  }) {
    final visible = _filteredApplications;
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Registrar Dashboard',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Final review for Head-endorsed leave requests',
                      style: TextStyle(fontSize: 12.5, color: textSecondary),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Notifications',
                    icon: Icon(
                      Icons.notifications_none_rounded,
                      color: textPrimary,
                    ),
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.notifications),
                  ),
                  IconButton(
                    icon: Icon(
                      isDark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                      color: textPrimary,
                    ),
                    onPressed: () => AppThemeState.instance.toggleTheme(),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _currentNavIndex = 2),
                    child: AppAvatar(
                      name: _registrarName,
                      photoUrl: _photoUrl,
                      size: 38,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _statBox(
                cardBg: cardBg,
                borderColor: borderColor,
                label: 'Forwarded',
                value: '$forwardedCount',
                color: const Color(0xFF2563EB),
                textSecondary: textSecondary,
              ),
              const SizedBox(width: 10),
              _statBox(
                cardBg: cardBg,
                borderColor: borderColor,
                label: 'Approved',
                value: '$approvedCount',
                color: const Color(0xFF16A34A),
                textSecondary: textSecondary,
              ),
              const SizedBox(width: 10),
              _statBox(
                cardBg: cardBg,
                borderColor: borderColor,
                label: 'Rejected',
                value: '$rejectedCount',
                color: const Color(0xFFDC2626),
                textSecondary: textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search by faculty, department, or leave type...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
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
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final tab in const [
                  ('forwarded', 'Forwarded Queue'),
                  ('approved', 'Approved'),
                  ('rejected', 'Rejected'),
                  ('all', 'All'),
                ]) ...[
                  ChoiceChip(
                    label: Text(tab.$2),
                    selected: _selectedStatusTab == tab.$1,
                    onSelected: (_) =>
                        setState(() => _selectedStatusTab = tab.$1),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All Depts'),
                  selected: _selectedDeptFilter == 'ALL',
                  onSelected: (_) =>
                      setState(() => _selectedDeptFilter = 'ALL'),
                ),
                const SizedBox(width: 6),
                for (final entry in AppConstants.departmentIdToCode.entries
                    .where((e) => AppConstants.departmentIdToCanonicalName
                        .containsKey(e.key))) ...[
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: _selectedDeptFilter == entry.key,
                    onSelected: (_) =>
                        setState(() => _selectedDeptFilter = entry.key),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (visible.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.verified_outlined,
                    size: 42,
                    color: primaryColor,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No applications in this queue',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Forwarded leave applications endorsed by Department Heads appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: textSecondary),
                  ),
                ],
              ),
            )
          else
            for (final app in visible)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
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
                        Expanded(
                          child: Text(
                            app.applicantName,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: (app.status == 'approved'
                                    ? const Color(0xFF16A34A)
                                    : app.status == 'rejected'
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFF2563EB))
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            app.status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: app.status == 'approved'
                                  ? const Color(0xFF16A34A)
                                  : app.status == 'rejected'
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF2563EB),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${app.departmentName} • ${app.applicantEmployeeId}',
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${app.leaveTypeName} (${app.totalDays} days) • ${DateFormat('dd MMM').format(app.startDate)} – ${DateFormat('dd MMM, yyyy').format(app.endDate)}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    if (app.headComment != null &&
                        app.headComment!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Head Remarks: ${app.headComment}',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: textSecondary,
                        ),
                      ),
                    ],
                    if (app.status == 'forwarded') ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: ElevatedButton(
                          onPressed: () => _openFinalApproval(app),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Review & Finalize',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _statBox({
    required Color cardBg,
    required Color borderColor,
    required String label,
    required String value,
    required Color color,
    required Color textSecondary,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileView({
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required Color primaryColor,
    required bool isDark,
    required int forwardedCount,
    required int approvedCount,
    required int rejectedCount,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Registrar Profile',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                AppAvatar(
                  name: _registrarName,
                  photoUrl: _photoUrl,
                  size: 80,
                ),
                const SizedBox(height: 12),
                Text(
                  _registrarName,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Registrar / Dean • $_registrarEmployeeId',
                  style: TextStyle(fontSize: 13, color: textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  _registrarEmail,
                  style: TextStyle(fontSize: 12.5, color: textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _statBox(
                cardBg: cardBg,
                borderColor: borderColor,
                label: 'Forwarded',
                value: '$forwardedCount',
                color: const Color(0xFF2563EB),
                textSecondary: textSecondary,
              ),
              const SizedBox(width: 10),
              _statBox(
                cardBg: cardBg,
                borderColor: borderColor,
                label: 'Approved',
                value: '$approvedCount',
                color: const Color(0xFF16A34A),
                textSecondary: textSecondary,
              ),
              const SizedBox(width: 10),
              _statBox(
                cardBg: cardBg,
                borderColor: borderColor,
                label: 'Rejected',
                value: '$rejectedCount',
                color: const Color(0xFFDC2626),
                textSecondary: textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF450A0A).withValues(alpha: 0.3)
                  : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA),
              ),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: _isLoggingOut ? null : _onLogOut,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.logout_rounded,
                      size: 18,
                      color: Color(0xFFDC2626),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Log Out of Registrar Portal',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
