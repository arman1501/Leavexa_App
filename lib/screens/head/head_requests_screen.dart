// ─────────────────────────────────────────────────────────────────────────────
//  head_requests_screen.dart  –  Department Head Requests List Screen
//  Pixel-perfect implementation of Requests UI (Supports Pending & Reviewed views)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/leave_repository.dart';
import '../../widgets/app_bottom_navigation.dart';

class HeadRequestsScreen extends StatefulWidget {
  final LeaveRepository? leaveRepository;
  final AuthRepository? authRepository;

  const HeadRequestsScreen({
    super.key,
    this.leaveRepository,
    this.authRepository,
  });

  @override
  State<HeadRequestsScreen> createState() => _HeadRequestsScreenState();
}

class _HeadRequestsScreenState extends State<HeadRequestsScreen> {
  late final LeaveRepository _leaveRepo =
      widget.leaveRepository ?? LeaveRepository();
  late final AuthRepository _authRepo =
      widget.authRepository ?? AuthRepository();

  int _currentNavIndex = 1; // 1: Requests tab active
  int _selectedFilterIndex =
      1; // Default to Reviewed (12) to match reference screenshot
  String _searchQuery = '';
  bool _isSearching = false;
  final _searchCtrl = TextEditingController();
  String _selectedSort = 'Latest First';
  bool _hasFetchedReal = false;
  List<Map<String, dynamic>> _realRequests = [];

  @override
  void initState() {
    super.initState();
    _loadRealPendingRequests();
  }

  Future<void> _loadRealPendingRequests() async {
    try {
      final user = await _authRepo.getCurrentUserProfile();
      final deptId = user?.departmentId ?? 'dept_cse';
      final apps = await _leaveRepo.departmentPending(deptId);
      if (mounted) {
        setState(() {
          _realRequests = apps.map((a) {
            final startStr = DateFormat('dd MMM').format(a.startDate);
            final endStr = DateFormat('dd MMM').format(a.endDate);
            final fullDates =
                '${DateFormat('dd MMM').format(a.startDate)} – ${DateFormat('dd MMM, yyyy').format(a.endDate)}';
            return {
              'id': a.id,
              'applicantUid': a.applicantUid,
              'facultyName': a.applicantName,
              'facultyId': a.applicantEmployeeId,
              'designation': 'Faculty Member • ${a.departmentName}',
              'leaveType': a.leaveTypeName,
              'accentColor': const Color(0xFF16A34A),
              'dateRange': '$startStr – $endStr',
              'duration': '${a.totalDays} Day${a.totalDays > 1 ? 's' : ''}',
              'datesFull': fullDates,
              'rxAttached': a.documentUrl != null && a.documentUrl!.isNotEmpty,
              'teachingCovered': 'Arranged with Department',
              'reviewedBy': a.headUid,
              'reviewedAt': a.headActionAt != null
                  ? DateFormat('dd MMM, hh:mm a').format(a.headActionAt!)
                  : null,
              'reason': a.reason,
              'attachmentName': a.documentUrl ?? 'Application_Doc.pdf',
              'attachmentSize': '1.0 MB',
              'submittedAt':
                  '${DateFormat('dd MMM, hh:mm a').format(a.appliedAt)} by ${a.applicantName}',
              'status': 'Pending',
              'model': a,
            };
          }).toList();
          _hasFetchedReal = true;
        });
      }
    } catch (_) {}
  }

  final List<Map<String, dynamic>> _allRequests = [
    // ── REVIEWED REQUESTS ──────────────────────────────────────────────────
    {
      'id': 'REQ-802',
      'facultyName': 'Mr. Tanvir Hasan',
      'facultyId': 'CSE-1024',
      'designation': 'Lecturer • Data Structures & Algorithms',
      'leaveType': 'Medical Leave',
      'accentColor': const Color(0xFF16A34A), // Green accent for Approved
      'dateRange': '25 Sep – 26 Sep',
      'duration': '2 Days',
      'datesFull': '25 Sep – 26 Sep, 2026',
      'rxAttached': true,
      'teachingCovered': 'Ms. Sadia Karim (CS 201 Lab)',
      'reviewedBy': 'Head of Department',
      'reviewedAt': '24 Sep, 03:45 PM',
      'reviewComment': 'Leave approved. Ensure class coverage as mentioned.',
      'reason':
          'Medical consultation & dental treatment (physician certificate uploaded).',
      'attachmentName': 'Medical_Certificate.pdf',
      'attachmentSize': '2.4 MB',
      'submittedAt': '24 Sep, 10:20 AM',
      'status': 'Approved',
    },
    {
      'id': 'REQ-799',
      'facultyName': 'Dr. Tariqul Islam',
      'facultyId': 'CSE-1005',
      'designation': 'Professor • Computer Systems',
      'leaveType': 'Casual Leave',
      'accentColor': const Color(
        0xFFF59E0B,
      ), // Orange/Amber accent for Changes Requested
      'dateRange': '15 Sep – 16 Sep',
      'duration': '2 Days',
      'datesFull': '15 Sep – 16 Sep, 2026',
      'rxAttached': false,
      'teachingCovered': 'Engr. Naila Parveen',
      'reviewedBy': 'Head of Department',
      'reviewedAt': '24 Sep, 03:45 PM',
      'reviewComment':
          "Please update the doctor's certificate with the exact treatment date and re-submit.",
      'reason': 'Personal work with student project evaluation review.',
      'attachmentName': 'Clarification_Doc.pdf',
      'attachmentSize': '1.2 MB',
      'submittedAt': '14 Sep, 11:00 AM',
      'status': 'Changes Requested',
    },
    {
      'id': 'REQ-795',
      'facultyName': 'Ms. Farhana Akter',
      'facultyId': 'CSE-1033',
      'designation': 'Lecturer • Software Engineering',
      'leaveType': 'Earned Leave',
      'accentColor': const Color(0xFFDC2626), // Red accent for Rejected
      'dateRange': '10 Sep – 12 Sep',
      'duration': '3 Days',
      'datesFull': '10 Sep – 12 Sep, 2026',
      'rxAttached': false,
      'teachingCovered': null,
      'reviewedBy': 'Head of Department',
      'reviewedAt': '24 Sep, 03:45 PM',
      'rejectionReason':
          'The leave cannot be approved due to ongoing academic assessment during this period.',
      'reason': 'Urgent relocation travel during scheduled mid-term exam week.',
      'attachmentName': 'Travel_Notice.pdf',
      'attachmentSize': '650 KB',
      'submittedAt': '08 Sep, 03:45 PM',
      'status': 'Rejected',
    },

    // ── PENDING REQUESTS ───────────────────────────────────────────────────
    {
      'id': 'REQ-805',
      'facultyName': 'Mr. Tanvir Hasan',
      'facultyId': 'CSE-1024',
      'designation': 'Lecturer • Data Structures & Algorithms',
      'leaveType': 'Medical Leave',
      'accentColor': const Color(0xFFDC2626),
      'dateRange': '25 Sep – 26 Sep',
      'duration': '2 Days',
      'datesFull': '25 Sep – 26 Sep, 2026',
      'rxAttached': true,
      'teachingCovered': 'Ms. Sadia Karim (CS 201 Lab)',
      'reviewedBy': null,
      'reviewedAt': null,
      'reason':
          'Medical consultation & dental treatment (physician certificate uploaded).',
      'attachmentName': 'Medical_Certificate.pdf',
      'attachmentSize': '2.4 MB',
      'submittedAt': '24 Sep, 10:20 AM by Mr. Tanvir Hasan',
      'status': 'Pending',
    },
    {
      'id': 'REQ-803',
      'facultyName': 'Dr. Farhana Yasmin',
      'facultyId': 'CSE-1018',
      'designation': 'Associate Professor • AI Lab',
      'leaveType': 'Earned Leave',
      'accentColor': const Color(0xFF334155),
      'dateRange': '28 Sep – 02 Oct',
      'duration': '5 Days',
      'datesFull': '28 Sep – 02 Oct, 2026',
      'rxAttached': false,
      'teachingCovered': 'Dr. Anwar Hussain (AI 501)',
      'reviewedBy': null,
      'reviewedAt': null,
      'reason':
          'Family bereavement & urgent relocation matters for elder relatives.',
      'attachmentName': 'Official_Note.pdf',
      'attachmentSize': '1.1 MB',
      'submittedAt': '25 Sep, 02:15 PM by Dr. Farhana Yasmin',
      'status': 'Pending',
    },
    {
      'id': 'REQ-801',
      'facultyName': 'Dr. Sarah Ahmed',
      'facultyId': 'CSE-1012',
      'designation': 'Assistant Professor • Software Engineering',
      'leaveType': 'Casual Leave',
      'accentColor': const Color(0xFF16A34A),
      'dateRange': '20 Sep – 22 Sep',
      'duration': '3 Days',
      'datesFull': '20 Sep – 22 Sep, 2026',
      'rxAttached': false,
      'teachingCovered': 'Prof. M. Kamal (SE 402, 3 Classes)',
      'reviewedBy': null,
      'reviewedAt': null,
      'reason':
          'Attending international symposium & curriculum harmonization workshop at National Center.',
      'attachmentName': 'Workshop_Invitation.pdf',
      'attachmentSize': '3.2 MB',
      'submittedAt': '18 Sep, 09:30 AM by Dr. Sarah Ahmed',
      'status': 'Pending',
    },
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onBottomNavTap(int index) {
    if (index == _currentNavIndex) return;
    setState(() => _currentNavIndex = index);
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, AppRoutes.headDashboard);
        break;
      case 1:
        // Already on Requests
        break;
      case 2:
        Navigator.pushReplacementNamed(context, AppRoutes.deptCalendar);
        break;
      case 3:
        Navigator.pushReplacementNamed(context, AppRoutes.headProfile);
        break;
    }
  }

  void _openViewDetails(Map<String, dynamic> item) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.headRequestDetails,
      arguments: item,
    );
    if (result != null && mounted) {
      setState(() {
        if (result is Map<String, dynamic>) {
          item['status'] = result['status'] ?? item['status'];
          item['reviewedAt'] = result['reviewTime'] ?? '24 Sep, 03:45 PM';
          item['reviewedBy'] = result['reviewedBy'] ?? 'Head of Department';
          if (result['comment'] != null) {
            item['reviewComment'] = result['comment'];
          }
        } else if (result == true) {
          item['status'] = 'Approved';
          item['reviewedAt'] = '24 Sep, 03:45 PM';
          item['reviewedBy'] = 'Head of Department';
        } else if (result == false) {
          item['status'] = 'Rejected';
          item['reviewedAt'] = '24 Sep, 03:45 PM';
          item['reviewedBy'] = 'Head of Department';
        }
      });
    }
  }

  void _openReviewRequest(Map<String, dynamic> item) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.headReviewRequest,
      arguments: item,
    );
    if (result != null && mounted) {
      setState(() {
        if (result is Map<String, dynamic>) {
          item['status'] = result['status'] ?? item['status'];
          item['reviewedAt'] = result['reviewTime'] ?? '24 Sep, 03:45 PM';
          item['reviewedBy'] = result['reviewedBy'] ?? 'Head of Department';
          if (result['comment'] != null) {
            item['reviewComment'] = result['comment'];
          }
        } else if (result == true) {
          item['status'] = 'Approved';
          item['reviewedAt'] = '24 Sep, 03:45 PM';
          item['reviewedBy'] = 'Head of Department';
        } else if (result == false) {
          item['status'] = 'Rejected';
          item['reviewedAt'] = '24 Sep, 03:45 PM';
          item['reviewedBy'] = 'Head of Department';
        }
      });
    }
  }

  List<Map<String, dynamic>> get _currentAllRequests {
    if (_hasFetchedReal && _realRequests.isNotEmpty) {
      return [
        ..._realRequests,
        ..._allRequests.where((r) => r['status'] != 'Pending'),
      ];
    }
    return _allRequests;
  }

  List<Map<String, dynamic>> get _filteredRequests {
    return _currentAllRequests.where((item) {
      final isPending = item['status'] == 'Pending';
      final matchesFilter = _selectedFilterIndex == 0
          ? isPending
          : _selectedFilterIndex == 1
          ? !isPending
          : true;
      if (!matchesFilter) return false;
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final name = (item['facultyName'] as String).toLowerCase();
      final type = (item['leaveType'] as String).toLowerCase();
      return name.contains(q) || type.contains(q);
    }).toList();
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 1. HEADER (TITLE, SEARCH & FILTER ICONS) ──────────────
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 20,
                      right: 12,
                      top: 14,
                      bottom: 2,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Requests',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                _isSearching
                                    ? Icons.close
                                    : Icons.search_rounded,
                                size: 23,
                                color: textPrimary,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isSearching = !_isSearching;
                                  if (!_isSearching) {
                                    _searchQuery = '';
                                    _searchCtrl.clear();
                                  }
                                });
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.filter_alt_outlined,
                                size: 23,
                                color: textPrimary,
                              ),
                              onPressed: () {
                                _showSortAndFilterMenu(
                                  cardBg: cardBg,
                                  borderColor: borderColor,
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Search Bar (if searching)
                  if (_isSearching)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 6,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          autofocus: true,
                          onChanged: (v) => setState(() => _searchQuery = v),
                          style: TextStyle(color: textPrimary, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Search by faculty name or leave type...',
                            hintStyle: TextStyle(
                              color: textSecondary,
                              fontSize: 13.5,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Subtitle
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Leave and official requests for your review',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── 2. FILTER PILLS: Pending (6), Reviewed (12), All ──────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'Pending (6)',
                          isSelected: _selectedFilterIndex == 0,
                          onTap: () => setState(() => _selectedFilterIndex = 0),
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Reviewed (12)',
                          isSelected: _selectedFilterIndex == 1,
                          onTap: () => setState(() => _selectedFilterIndex = 1),
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'All',
                          isSelected: _selectedFilterIndex == 2,
                          onTap: () => setState(() => _selectedFilterIndex = 2),
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── 3. SECTION SUBHEADER (Reviewed Requests | Latest First ˇ)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedFilterIndex == 1
                              ? 'Reviewed Requests'
                              : _selectedFilterIndex == 0
                              ? 'Pending Requests'
                              : 'All Requests',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            _showSortAndFilterMenu(
                              cardBg: cardBg,
                              borderColor: borderColor,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                            );
                          },
                          child: Row(
                            children: [
                              Text(
                                _selectedSort,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: textSecondary,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 18,
                                color: textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ── 4. CARDS LIST ─────────────────────────────────────────
                  Expanded(
                    child: _filteredRequests.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.inbox_outlined,
                                  size: 48,
                                  color: textSecondary,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'No requests found',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            itemCount: _filteredRequests.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = _filteredRequests[index];
                              final isPending = item['status'] == 'Pending';

                              // If Reviewed or All tab showing a reviewed item, render Reviewed Card
                              if (!isPending) {
                                return _buildReviewedCard(
                                  item: item,
                                  cardBg: cardBg,
                                  borderColor: borderColor,
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
                                  isDark: isDark,
                                );
                              }

                              // Otherwise render Pending Card
                              return _buildPendingCard(
                                item: item,
                                cardBg: cardBg,
                                borderColor: borderColor,
                                textPrimary: textPrimary,
                                textSecondary: textSecondary,
                                isDark: isDark,
                              );
                            },
                          ),
                  ),
                ],
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
  //  REVIEWED CARD (Matching Image 100%)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildReviewedCard({
    required Map<String, dynamic> item,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
  }) {
    final status = item['status'] as String? ?? 'Approved';

    // Accent Stripe Color & Status Badge
    Color accentColor;
    Widget statusBadge;

    if (status == 'Approved') {
      accentColor = const Color(0xFF16A34A);
      statusBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF064E3B).withValues(alpha: 0.5)
              : const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 14,
              color: Color(0xFF16A34A),
            ),
            SizedBox(width: 4),
            Text(
              'Approved',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF16A34A),
              ),
            ),
          ],
        ),
      );
    } else if (status == 'Changes Requested') {
      accentColor = const Color(0xFFF59E0B);
      statusBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF451A03).withValues(alpha: 0.5)
              : const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sync_rounded, size: 14, color: Color(0xFFD97706)),
            SizedBox(width: 4),
            Text(
              'Changes Requested',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFFD97706),
              ),
            ),
          ],
        ),
      );
    } else {
      // Rejected
      accentColor = const Color(0xFFDC2626);
      statusBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF451A03).withValues(alpha: 0.5)
              : const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cancel_outlined, size: 14, color: Color(0xFFDC2626)),
            SizedBox(width: 4),
            Text(
              'Rejected',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFFDC2626),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Accent Stripe
            Container(width: 4.5, color: accentColor),
            // Card Content Body
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row: Avatar + Name + Status Badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person,
                            size: 20,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['facultyName'] as String,
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item['designation'] as String,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        statusBadge,
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Date & Duration Box with Leave Type on Right
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 14,
                                color: textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${item['datesFull']}  |  ${item['duration']}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _getLeaveTypeBg(
                                item['leaveType'] as String,
                                isDark,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item['leaveType'] as String,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _getLeaveTypeColor(
                                  item['leaveType'] as String,
                                  isDark,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Teaching Covered Row (if present)
                    if (item['teachingCovered'] != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.groups_outlined,
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
                                  const TextSpan(text: 'Teaching Covered by: '),
                                  TextSpan(
                                    text: item['teachingCovered'] as String,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 10),

                    // Reviewed by: Department Head   |   Timestamp
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 15,
                              color: Color(0xFF16A34A),
                            ),
                            const SizedBox(width: 6),
                            RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textSecondary,
                                ),
                                children: [
                                  const TextSpan(text: 'Reviewed by: '),
                                  TextSpan(
                                    text:
                                        item['reviewedBy'] as String? ??
                                        'Department Head',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Text(
                          item['reviewedAt'] as String? ?? '',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Full-width Outlined "View Details" Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _openViewDetails(item),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textPrimary,
                          side: BorderSide(color: borderColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.visibility_outlined, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'View Details',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  PENDING CARD
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildPendingCard({
    required Map<String, dynamic> item,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
  }) {
    final accentColor =
        item['accentColor'] as Color? ?? const Color(0xFF16A34A);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4.5, color: accentColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['facultyName'] as String,
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item['designation'] as String,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E3A8A).withValues(alpha: 0.4)
                                : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item['leaveType'] as String,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? const Color(0xFF93C5FD)
                                  : const Color(0xFF1E40AF),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Date & Rx Attached box
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 15,
                                color: textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${item['dateRange']}  •  ${item['duration']}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                ),
                              ),
                            ],
                          ),
                          if (item['rxAttached'] == true)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF064E3B)
                                    : const Color(0xFFD1FAE5),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Rx Attached',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF059669),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    if (item['teachingCovered'] != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                  const TextSpan(text: 'Teaching Covered by: '),
                                  TextSpan(
                                    text: item['teachingCovered'] as String,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 8),

                    Text(
                      item['reason'] as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: textSecondary,
                        height: 1.35,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Actions Row: View Details & Review Request
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _openViewDetails(item),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textPrimary,
                              side: BorderSide(color: borderColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.visibility_outlined, size: 15),
                                SizedBox(width: 5),
                                Text(
                                  'View Details',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _openReviewRequest(item),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark
                                  ? const Color(0xFF047857)
                                  : const Color(0xFF1B4332),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.edit_note_rounded, size: 18),
                                SizedBox(width: 4),
                                Text(
                                  'Review Request',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(width: 3),
                                Icon(Icons.arrow_forward_rounded, size: 14),
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
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  SORT & FILTER BOTTOM SHEET
  // ───────────────────────────────────────────────────────────────────────────
  void _showSortAndFilterMenu({
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Sort Requests',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Latest First',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: _selectedSort == 'Latest First'
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: _selectedSort == 'Latest First'
                          ? const Color(0xFF16A34A)
                          : textPrimary,
                    ),
                  ),
                  trailing: _selectedSort == 'Latest First'
                      ? const Icon(Icons.check, color: Color(0xFF16A34A))
                      : null,
                  onTap: () {
                    setState(() => _selectedSort = 'Latest First');
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Oldest First',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: _selectedSort == 'Oldest First'
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: _selectedSort == 'Oldest First'
                          ? const Color(0xFF16A34A)
                          : textPrimary,
                    ),
                  ),
                  trailing: _selectedSort == 'Oldest First'
                      ? const Icon(Icons.check, color: Color(0xFF16A34A))
                      : null,
                  onTap: () {
                    setState(() => _selectedSort = 'Oldest First');
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getLeaveTypeBg(String type, bool isDark) {
    if (type.contains('Medical')) {
      return isDark
          ? const Color(0xFF1E3A8A).withValues(alpha: 0.4)
          : const Color(0xFFEFF6FF);
    } else if (type.contains('Casual')) {
      return isDark
          ? const Color(0xFF064E3B).withValues(alpha: 0.5)
          : const Color(0xFFDCFCE7);
    } else {
      return isDark
          ? const Color(0xFF1E3A8A).withValues(alpha: 0.4)
          : const Color(0xFFEFF6FF);
    }
  }

  Color _getLeaveTypeColor(String type, bool isDark) {
    if (type.contains('Medical')) {
      return isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF);
    } else if (type.contains('Casual')) {
      return const Color(0xFF16A34A);
    } else {
      return isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF);
    }
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
    final inactiveBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final inactiveBorder = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final activeText = Colors.white;
    final inactiveText = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF0F172A);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? null : Border.all(color: inactiveBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? activeText : inactiveText,
          ),
        ),
      ),
    );
  }
}
