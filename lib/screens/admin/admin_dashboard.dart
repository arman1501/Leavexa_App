// ─────────────────────────────────────────────────────────────────────────────
//  admin_dashboard.dart  –  Admin Dashboard Screen
//  Pixel-perfect implementation of Stitch Screen 07e86fc7dbf84e198b6a1b13fae76a59
//  Manage pending teacher registrations, credential verification & approvals
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/helpers.dart';
import '../../models/user_model.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/notification_service.dart';
import '../../services/university_info_service.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_bottom_navigation.dart';

class AdminDashboard extends StatefulWidget {
  final UserRepository? userRepository;
  final NotificationService? notificationService;
  final AuthRepository? authRepository;

  const AdminDashboard({
    super.key,
    this.userRepository,
    this.notificationService,
    this.authRepository,
  });

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late final UserRepository _userRepo =
      widget.userRepository ?? UserRepository();
  late final AuthRepository _authRepo =
      widget.authRepository ?? AuthRepository();

  int _currentNavIndex = 0; // 0: Home, 1: Approvals, 2: Faculty, 3: Profile

  int _pendingCount = 0;
  int _approvedCount = 0;
  int _rejectedCount = 0;

  bool _sortNewestFirst = true;
  bool _didReadInitialTab = false;
  bool _isLoading = true;
  bool _hasStreamData = false;
  String? _loadError;
  String _adminName = 'System Administrator';
  String? _adminPhotoUrl;
  List<Map<String, dynamic>> _realTeachers = [];
  List<Map<String, dynamic>> _allFacultyDirectory = [];
  List<OfficialFacultyMember> _officialMembers = const [];
  List<UserModel> _latestPending = const [];
  List<UserModel> _latestAllFaculty = const [];
  StreamSubscription<List<UserModel>>? _usersSub;

  // Approvals Tab state
  String _approvalStatusFilter =
      'ALL'; // 'ALL', 'PENDING', 'APPROVED', 'REJECTED'
  String _approvalSearchQuery = '';
  final TextEditingController _approvalSearchCtrl = TextEditingController();

  // Faculty Directory Tab state
  String _facultyDeptFilter = 'ALL';
  String _facultyStatusFilter =
      'ALL'; // 'ALL', 'ACTIVE', 'INACTIVE', 'REGISTERED', 'OFFICIAL'
  String _facultySearchQuery = '';
  final TextEditingController _facultySearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRealFaculty();
    _startRealtimeStreams();
  }

  void _startRealtimeStreams() {
    if (_usersSub != null) return;
    try {
      _usersSub = _userRepo.streamAllUsers().listen(
        (allUsers) {
          if (!mounted) return;
          _hasStreamData = true;
          _loadError = null;
          final currentUid =
              _authRepo.currentUserId ?? AuthRepository.activeUser?.uid;
          if (currentUid != null) {
            for (final u in allUsers) {
              if (u.uid == currentUid) {
                if (_adminName != u.fullName || _adminPhotoUrl != u.photoUrl) {
                  setState(() {
                    _adminName = u.fullName;
                    _adminPhotoUrl = u.photoUrl;
                  });
                }
                break;
              }
            }
          }

          final faculty = allUsers
              .where((u) => u.role == 'faculty' && UserRepository.isGenuineUser(u))
              .toList()
            ..sort((a, b) => a.fullName.compareTo(b.fullName));
          final pending = faculty.where((u) => u.isPending).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          _latestPending = pending;
          _latestAllFaculty = faculty;
          _applyFacultyData(pending, faculty);
        },
        onError: (Object error) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            if (!_hasStreamData && _realTeachers.isEmpty) {
              _loadError = 'Unable to sync live faculty records. Tap retry to reconnect.';
            }
          });
        },
      );
    } catch (_) {
      // Gracefully fall back to future-based _loadRealFaculty() in unit tests
      // where Firebase is not initialized and streamAllUsers() is not mocked.
    }
  }

  Future<void> _loadRealFaculty() async {
    try {
      try {
        final currentAdmin = await _authRepo.getCurrentUserProfile();
        if (currentAdmin != null && mounted) {
          setState(() {
            _adminName = currentAdmin.fullName;
            _adminPhotoUrl = currentAdmin.photoUrl;
          });
        }
      } catch (_) {}

      final pending = await _userRepo.getPendingFaculty();
      final all = await _userRepo.getAllFaculty();

      final genuinePending = pending.where(UserRepository.isGenuineUser).toList();
      final genuineAll = all.where(UserRepository.isGenuineUser).toList();

      if (!_hasStreamData) {
        _latestPending = genuinePending;
        _latestAllFaculty = genuineAll;
        _applyFacultyData(genuinePending, genuineAll);
      }

      try {
        final officialMembers =
            await UniversityInfoService().getOfficialFaculty();
        if (mounted) {
          _officialMembers = officialMembers;
          _applyFacultyData(_latestPending, _latestAllFaculty);
        }
      } catch (_) {}
    } catch (e) {
      if (mounted && !_hasStreamData) {
        setState(() {
          _isLoading = false;
          _loadError = 'Failed to load dashboard data. Please check connection.';
        });
      }
    }
  }

  void _applyFacultyData(List<UserModel> pending, List<UserModel> all) {
    final genuinePending = pending.where(UserRepository.isGenuineUser).toList();
    final genuineAll = all.where(UserRepository.isGenuineUser).toList();

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _loadError = null;
      _pendingCount = genuinePending.length;
      _approvedCount = genuineAll.where((u) => u.isApproved).length;
      _rejectedCount = genuineAll.where((u) => u.isRejected).length;

      // 1. Registered faculty (Leavexa verified)
      final registeredVerified =
          genuineAll.where((u) => u.isApproved).map((u) {
        return {
          'id': u.uid,
          'name': u.fullName,
          'empId': u.employeeId,
          'department': u.departmentName,
          'deptCode': AppConstants.getDepartmentCode(
            u.departmentId,
            u.departmentName,
          ),
          'designation': u.designation,
          'email': u.email,
          'phone': u.phone ?? 'N/A',
          'joined': 'Leavexa Registered Member',
          'degrees': [u.designation],
          'institution': 'Leading University Academic Faculty',
          'credentials': 'Faculty ID Verified',
          'nidVerified': true,
          'status': 'VERIFIED',
          'isActive': u.isActive,
          'isOfficial': false,
          'source': 'Leavexa Registered & Verified',
          'model': u,
        };
      }).toList();

      // 2. Official university faculty directory from lus.ac.bd
      final officialItems = _officialMembers.map((f) {
        return {
          'id': f.id,
          'name': f.name,
          'empId': f.id,
          'department': f.department,
          'deptCode': f.deptCode,
          'designation': f.designation,
          'email': '',
          'phone': '',
          'joined': 'Official University Directory',
          'degrees': [f.designation],
          'institution': 'Leading University (${f.department})',
          'credentials': 'Faculty ID Verified',
          'nidVerified': true,
          'status': 'VERIFIED',
          'isActive': true,
          'isOfficial': true,
          'imageUrl': f.imageUrl,
          'profileUrl': f.profileUrl,
          'source': 'Official University Directory • lus.ac.bd',
        };
      }).toList();

      _allFacultyDirectory = [
        ...registeredVerified,
        ...officialItems,
      ];

      // 3. Pending approvals list + reviewed faculty accounts (no duplicates)
      final seenUids = <String>{};
      final combined = <UserModel>[];
      for (final u in genuinePending) {
        if (seenUids.add(u.uid)) combined.add(u);
      }
      for (final u in genuineAll) {
        if (!u.isPending && seenUids.add(u.uid)) combined.add(u);
      }
      _realTeachers = combined.map((u) {
        final isApproved = u.isApproved;
        final isRejected = u.isRejected;
        final createdAtMs = u.createdAt.millisecondsSinceEpoch;
        final submittedLabel = createdAtMs > 0
            ? LeaveDateUtils.timeAgo(u.createdAt)
            : 'Registered Member';
        return {
          'id': u.uid,
          'name': u.fullName,
          'empId': u.employeeId,
          'department': u.departmentName,
          'designation': u.designation,
          'email': u.email,
          'phone': u.phone ?? '',
          'submittedTime': submittedLabel,
          'createdAtMs': createdAtMs,
          'submittedHours': 1,
          'credentials': isApproved
              ? 'Faculty ID Verified'
              : isRejected
                  ? 'Registration Rejected'
                  : 'Faculty ID: Awaiting Verification',
          'avatarType': 'placeholder',
          'avatarColor': const Color(0xFF0D9488),
          'status': u.approvalStatus.toUpperCase(),
          'institution': 'Leading University Faculty Member',
          'nidVerified': isApproved,
          'degrees': [u.designation, u.departmentName],
          'model': u,
        };
      }).toList();
    });
  }

  List<Map<String, dynamic>> get _currentTeachers => _realTeachers;

  List<Map<String, dynamic>> get _currentFacultyDirectory =>
      _allFacultyDirectory;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didReadInitialTab) {
      _didReadInitialTab = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic> && args['tab'] is int) {
        final tab = args['tab'] as int;
        if (tab >= 0 && tab <= 2) {
          setState(() {
            _currentNavIndex = tab;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _usersSub?.cancel();
    _approvalSearchCtrl.dispose();
    _facultySearchCtrl.dispose();
    super.dispose();
  }

  void _onBottomNavTap(int index) {
    if (index == 3) {
      Navigator.pushReplacementNamed(context, AppRoutes.adminProfile);
      return;
    }
    setState(() => _currentNavIndex = index);
  }

  Future<void> _onApproveTeacher(Map<String, dynamic> teacher) async {
    final userModel = teacher['model'] as UserModel?;
    final prevStatus = teacher['status'];
    final prevPending = _pendingCount;
    final prevApproved = _approvedCount;

    setState(() {
      teacher['status'] = 'APPROVED';
      _pendingCount = (_pendingCount > 0) ? _pendingCount - 1 : 0;
      _approvedCount++;
    });

    if (userModel != null) {
      try {
        await _userRepo.approveFaculty(userModel.uid);
      } catch (e) {
        if (mounted) {
          setState(() {
            teacher['status'] = prevStatus;
            _pendingCount = prevPending;
            _approvedCount = prevApproved;
          });
          AppHelpers.showError(
            context,
            'Failed to approve ${teacher['name']}: $e',
          );
        }
        return;
      }
    }

    if (mounted) {
      AppHelpers.showSuccess(
        context,
        '${teacher['name']} has been approved and registered!',
      );
    }
  }

  void _onRejectTeacher(Map<String, dynamic> teacher) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final sheetBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
        final textSecondary = isDark
            ? const Color(0xFF94A3B8)
            : const Color(0xFF64748B);

        String selectedReason = 'Incomplete documentation';
        final reasons = [
          'Incomplete documentation',
          'Unverified academic credentials',
          'NID / Identity mismatch',
          'Department criteria not satisfied',
        ];

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.cancel_outlined,
                          color: Color(0xFFDC2626),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reject Verification',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
                              ),
                            ),
                            Text(
                              teacher['name'] as String,
                              style: TextStyle(
                                fontSize: 13,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Select Rejection Reason:',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...reasons.map(
                    (r) => RadioListTile<String>(
                      value: r,
                      groupValue: selectedReason,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      activeColor: const Color(0xFFDC2626),
                      title: Text(
                        r,
                        style: TextStyle(fontSize: 13.5, color: textPrimary),
                      ),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedReason = val);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            final userModel = teacher['model'] as UserModel?;
                            final prevStatus = teacher['status'];
                            final prevPending = _pendingCount;
                            final prevRejected = _rejectedCount;
                            setState(() {
                              teacher['status'] = 'REJECTED';
                              _pendingCount = (_pendingCount > 0)
                                  ? _pendingCount - 1
                                  : 0;
                              _rejectedCount++;
                            });
                            if (userModel != null) {
                              try {
                                await _userRepo.rejectFaculty(
                                  userModel.uid,
                                  reason: selectedReason,
                                );
                              } catch (e) {
                                if (mounted) {
                                  setState(() {
                                    teacher['status'] = prevStatus;
                                    _pendingCount = prevPending;
                                    _rejectedCount = prevRejected;
                                  });
                                  AppHelpers.showError(
                                    this.context,
                                    'Failed to reject ${teacher['name']}: $e',
                                  );
                                }
                                return;
                              }
                            }
                            if (mounted) {
                              AppHelpers.showError(
                                this.context,
                                'Registration rejected: $selectedReason',
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Confirm Reject',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _toggleUserActive(Map<String, dynamic> faculty) async {
    final current = faculty['isActive'] != false;
    final newStatus = !current;
    final uid = faculty['id'] as String;

    setState(() {
      faculty['isActive'] = newStatus;
    });

    try {
      await _userRepo.setUserActive(uid, newStatus);
      if (mounted) {
        AppHelpers.showSuccess(
          context,
          '${faculty['name']} status updated to ${newStatus ? 'Active' : 'Inactive'}',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          faculty['isActive'] = current;
        });
        AppHelpers.showError(context, 'Failed to update user status: $e');
      }
    }
  }

  void _openCreateStaffModal() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final empIdCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final designationCtrl = TextEditingController(
      text: 'Professor & Head of Department',
    );
    final phoneCtrl = TextEditingController();

    String selectedRole = 'department_head';
    String selectedDeptName = 'Computer Science & Engineering';
    String selectedDeptId = 'dept_cse';
    bool isSubmitting = false;
    String? submitError;

    final deptMap = {
      'dept_cse': 'Computer Science & Engineering',
      'dept_eee': 'Electrical & Electronic Engineering',
      'dept_bba': 'Business Administration',
      'dept_civil': 'Civil Engineering',
      'dept_law': 'Department of Law',
      'dept_arch': 'Department of Architecture',
      'dept_public_health': 'Department of Public Health',
      'dept_thm': 'Tourism & Hospitality Management',
      'dept_islamic_studies': 'Department of Islamic Studies',
      'dept_english': 'Department of English',
      'dept_bangla': 'Department of Bangla',
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final sheetBg = isDark ? const Color(0xFF1E293B) : Colors.white;
            final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
            final textSecondary =
                isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
            final borderColor =
                isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
            final inputBg =
                isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.9,
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1B4332)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.admin_panel_settings_rounded,
                                  color: Color(0xFF1B4332),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Create Staff Account',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded,
                                color: textSecondary),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (submitError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            border:
                                Border.all(color: const Color(0xFFFCA5A5)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: Color(0xFFDC2626), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  submitError!,
                                  style: const TextStyle(
                                    color: Color(0xFFDC2626),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      Text(
                        'Role Selection',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              key: const Key('role_department_head_chip'),
                              label: const Text('Department Head'),
                              selected: selectedRole == 'department_head',
                              onSelected: (val) {
                                if (val) {
                                  setModalState(() {
                                    selectedRole = 'department_head';
                                    designationCtrl.text =
                                        'Professor & Head of Department';
                                  });
                                }
                              },
                              selectedColor: const Color(0xFF1B4332)
                                  .withValues(alpha: 0.15),
                              labelStyle: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: selectedRole == 'department_head'
                                    ? const Color(0xFF1B4332)
                                    : textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ChoiceChip(
                              key: const Key('role_registrar_chip'),
                              label: const Text('Registrar'),
                              selected: selectedRole == 'registrar',
                              onSelected: (val) {
                                if (val) {
                                  setModalState(() {
                                    selectedRole = 'registrar';
                                    designationCtrl.text = 'Registrar';
                                  });
                                }
                              },
                              selectedColor: const Color(0xFF1B4332)
                                  .withValues(alpha: 0.15),
                              labelStyle: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: selectedRole == 'registrar'
                                    ? const Color(0xFF1B4332)
                                    : textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        key: const Key('staff_name_field'),
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Full Name *',
                          prefixIcon: const Icon(Icons.person_outline),
                          filled: true,
                          fillColor: inputBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: borderColor),
                          ),
                        ),
                        validator: (val) =>
                            (val == null || val.trim().isEmpty)
                                ? 'Full Name is required'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('staff_empid_field'),
                        controller: empIdCtrl,
                        decoration: InputDecoration(
                          labelText: 'Employee ID *',
                          prefixIcon: const Icon(Icons.badge_outlined),
                          filled: true,
                          fillColor: inputBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: borderColor),
                          ),
                        ),
                        validator: (val) =>
                            (val == null || val.trim().isEmpty)
                                ? 'Employee ID is required'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('staff_email_field'),
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email Address *',
                          prefixIcon: const Icon(Icons.email_outlined),
                          filled: true,
                          fillColor: inputBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: borderColor),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Email is required';
                          }
                          final regex = RegExp(
                            r'^[\w.-]+@[\w-]+\.[a-z]{2,}$',
                            caseSensitive: false,
                          );
                          if (!regex.hasMatch(val.trim())) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('staff_password_field'),
                        controller: passwordCtrl,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Password * (min 8 chars)',
                          prefixIcon: const Icon(Icons.lock_outline),
                          filled: true,
                          fillColor: inputBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: borderColor),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Password is required';
                          }
                          if (val.length < 8) {
                            return 'Password must be at least 8 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('staff_designation_field'),
                        controller: designationCtrl,
                        decoration: InputDecoration(
                          labelText: 'Designation *',
                          prefixIcon: const Icon(Icons.work_outline),
                          filled: true,
                          fillColor: inputBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: borderColor),
                          ),
                        ),
                        validator: (val) =>
                            (val == null || val.trim().isEmpty)
                                ? 'Designation is required'
                                : null,
                      ),
                      if (selectedRole == 'department_head') ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          key: const Key('staff_dept_dropdown'),
                          initialValue: selectedDeptId,
                          decoration: InputDecoration(
                            labelText: 'Department *',
                            prefixIcon:
                                const Icon(Icons.account_balance_outlined),
                            filled: true,
                            fillColor: inputBg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: borderColor),
                            ),
                          ),
                          items: deptMap.entries.map((e) {
                            return DropdownMenuItem(
                              value: e.key,
                              child: Text(
                                e.value,
                                style: const TextStyle(fontSize: 13.5),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() {
                                selectedDeptId = val;
                                selectedDeptName = deptMap[val] ?? '';
                              });
                            }
                          },
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('staff_phone_field'),
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Phone Number (Optional)',
                          prefixIcon: const Icon(Icons.phone_outlined),
                          filled: true,
                          fillColor: inputBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: borderColor),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          key: const Key('submit_create_staff_button'),
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) {
                                    return;
                                  }
                                  setModalState(() {
                                    isSubmitting = true;
                                    submitError = null;
                                  });

                                  try {
                                    await _userRepo.createStaffAccount(
                                      email: emailCtrl.text.trim().toLowerCase(),
                                      password: passwordCtrl.text,
                                      fullName: nameCtrl.text.trim(),
                                      employeeId:
                                          empIdCtrl.text.trim().toUpperCase(),
                                      role: selectedRole,
                                      departmentId:
                                          selectedRole == 'department_head'
                                              ? selectedDeptId
                                              : null,
                                      departmentName:
                                          selectedRole == 'department_head'
                                              ? selectedDeptName
                                              : null,
                                      designation:
                                          designationCtrl.text.trim(),
                                      phone: phoneCtrl.text.trim().isEmpty
                                          ? null
                                          : phoneCtrl.text.trim(),
                                    );

                                    if (!mounted) return;
                                    final createdName = nameCtrl.text.trim();
                                    if (ctx.mounted) {
                                      Navigator.pop(ctx);
                                    }
                                    if (!_hasStreamData) {
                                      _loadRealFaculty();
                                    }
                                    AppHelpers.showSuccess(
                                      this.context,
                                      'Staff account for $createdName created successfully!',
                                    );
                                  } catch (e) {
                                    setModalState(() {
                                      isSubmitting = false;
                                      submitError = e.toString().contains(
                                              'already-exists')
                                          ? 'Employee ID or email is already registered.'
                                          : 'Failed to create staff account: $e';
                                    });
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B4332),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Create Account',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  static const MethodChannel _browserChannel = MethodChannel(
    'com.leavexa.leavexa/browser',
  );

  Future<void> _launchUniversityWebsite(String url) async {
    try {
      final launched = await _browserChannel.invokeMethod<bool>(
        'openUrl',
        {'url': url},
      );
      if (launched == true) return;
    } catch (_) {
      // Fallback for non-Android platforms or widget tests
    }
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      AppHelpers.showSuccess(
        context,
        'University website link copied: $url',
      );
    }
  }

  void _openUniversityInfoModal() {
    final infoService = UniversityInfoService();
    const universityUrl = 'https://lus.ac.bd/';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final sheetBg = isDark ? const Color(0xFF1E293B) : Colors.white;
            final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
            final textSecondary =
                isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
            final boxBg =
                isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
            final borderCol =
                isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
            final accentColor =
                isDark ? const Color(0xFF34D399) : const Color(0xFF1B4332);
            final linkColor =
                isDark ? const Color(0xFF6EE7B7) : const Color(0xFF1B4332);

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.public_rounded,
                                color: accentColor,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'University Official Info',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Primary Source: $universityUrl',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: textSecondary),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: FutureBuilder<List<dynamic>>(
                      future: Future.wait([
                        infoService.getOverview(),
                        infoService.getOfficialDepartments(),
                        infoService.getLeavePolicies(),
                        infoService.getSyncMetadata(),
                      ]),
                      builder: (ctx, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final overview = snapshot.data![0] as UniversityOverview;
                        final departments = snapshot.data![1] as List<OfficialDepartment>;
                        final policiesDoc = snapshot.data![2] as Map<String, dynamic>;
                        final metadata = snapshot.data![3] as Map<String, dynamic>?;
                        final resolvedUrl = overview.websiteUrl.isNotEmpty
                            ? overview.websiteUrl
                            : universityUrl;

                        final leavePolicies = (policiesDoc['leavePolicies'] as Map<String, dynamic>?) ?? {};

                        return ListView(
                          children: [
                            // ── Overview Card ──
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: boxBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderCol),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    overview.universityName,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    overview.campusAddress,
                                    style: TextStyle(fontSize: 12, color: textSecondary),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 14,
                                    runSpacing: 6,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.phone_outlined, size: 14, color: textSecondary),
                                          const SizedBox(width: 4),
                                          Text(
                                            'PABX: ${overview.pabx}',
                                            style: TextStyle(fontSize: 12, color: textPrimary),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.email_outlined, size: 14, color: textSecondary),
                                          const SizedBox(width: 4),
                                          Text(
                                            overview.generalEmail,
                                            style: TextStyle(fontSize: 12, color: textPrimary),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  InkWell(
                                    onTap: () => _launchUniversityWebsite(resolvedUrl),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color: accentColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: accentColor.withValues(alpha: 0.4),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.link_rounded,
                                            size: 15,
                                            color: linkColor,
                                          ),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              resolvedUrl,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w700,
                                                color: linkColor,
                                                decoration: TextDecoration.underline,
                                                decorationColor: linkColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (metadata != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Last sync: ${metadata['status'] ?? 'SUCCESS'} (${metadata['lastSuccessfulSync'] != null ? 'Synced' : 'Cached'})',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? const Color(0xFF4ADE80)
                                            : const Color(0xFF15803D),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // ── Official Departments ──
                            Text(
                              'Official Academic Departments (${departments.length})',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: departments.map((d) {
                                return Chip(
                                  label: Text(
                                    '${d.name} (${d.code})',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: textPrimary,
                                    ),
                                  ),
                                  backgroundColor: boxBg,
                                  side: BorderSide(color: borderCol),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 14),

                            // ── Leave Policies ──
                            Text(
                              'Faculty Leave Policies Integration',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...leavePolicies.entries.map((e) {
                              final p = e.value as Map<String, dynamic>;
                              final isVerified = p['status'] == 'VERIFIED';
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: boxBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isVerified
                                        ? const Color(0xFF22C55E)
                                        : borderCol,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isVerified
                                          ? Icons.verified_rounded
                                          : Icons.warning_amber_rounded,
                                      size: 18,
                                      color: isVerified
                                          ? const Color(0xFF22C55E)
                                          : const Color(0xFFEAB308),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p['name']?.toString() ?? e.key,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: textPrimary,
                                            ),
                                          ),
                                          Text(
                                            p['status']?.toString() ?? '',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isVerified
                                                  ? (isDark
                                                      ? const Color(0xFF4ADE80)
                                                      : const Color(0xFF15803D))
                                                  : (isDark
                                                      ? const Color(0xFFFBBF24)
                                                      : const Color(0xFFB45309)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      key: const Key('modal_visit_university_website_button'),
                      onPressed: () => _launchUniversityWebsite(universityUrl),
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text(
                        'Visit University Website',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? const Color(0xFF0D9488)
                            : const Color(0xFF1B4332),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openInspectModal(Map<String, dynamic> teacher) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final sheetBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
        final textSecondary = isDark
            ? const Color(0xFF94A3B8)
            : const Color(0xFF64748B);
        final boxBg = isDark
            ? const Color(0xFF0F172A)
            : const Color(0xFFF8FAFC);
        final borderCol = isDark
            ? const Color(0xFF334155)
            : const Color(0xFFE2E8F0);

        return Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).padding.bottom + 20,
          ),
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        size: 22,
                        color: Color(0xFF16A34A),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Credential Inspection',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: textSecondary, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: boxBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderCol),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teacher['name'] as String,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${teacher['empId']} • ${teacher['department']} • ${teacher['designation']}',
                      style: TextStyle(fontSize: 12.5, color: textSecondary),
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Builder(
                      builder: (context) {
                        final isApproved = teacher['status'] == 'APPROVED' ||
                            teacher['status'] == 'VERIFIED';
                        return Row(
                          children: [
                            Icon(
                              isApproved
                                  ? Icons.check_circle_rounded
                                  : Icons.pending_outlined,
                              size: 16,
                              color: isApproved
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFD97706),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isApproved
                                  ? 'Faculty ID Verified'
                                  : 'Faculty ID: Not Verified',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: isApproved
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFD97706),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.school_outlined,
                          size: 16,
                          color: Color(0xFF3B82F6),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            teacher['institution'] as String? ??
                                'Leading University Faculty Member',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: textSecondary,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if ((teacher['email'] as String? ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.email_outlined, size: 15, color: textSecondary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              teacher['email'] as String,
                              style: TextStyle(fontSize: 12.5, color: textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if ((teacher['phone'] as String? ?? '').isNotEmpty &&
                        teacher['phone'] != 'N/A') ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.phone_outlined, size: 15, color: textSecondary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              teacher['phone'] as String,
                              style: TextStyle(fontSize: 12.5, color: textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (teacher['status'] == 'PENDING')
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _onRejectTeacher(teacher);
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Color(0xFFDC2626),
                        ),
                        label: const Text(
                          'Reject',
                          style: TextStyle(
                            color: Color(0xFFDC2626),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Color(0xFFFECACA)),
                          backgroundColor: const Color(0xFFFEE2E2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _onApproveTeacher(teacher);
                        },
                        icon: const Icon(
                          Icons.check_rounded,
                          size: 17,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Approve',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F3827),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else ...[
                if (teacher['isOfficial'] != true &&
                    teacher['status'] == 'APPROVED' &&
                    (teacher['id'] as String? ?? '').isNotEmpty) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openTransferDepartmentModal(teacher);
                      },
                      icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                      label: const Text(
                        'Transfer Department',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Verified Faculty Member • Done',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F3827),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _openTransferDepartmentModal(Map<String, dynamic> teacher) {
    final uid = teacher['id'] as String? ?? '';
    if (uid.isEmpty) return;

    final currentDeptId = (teacher['departmentId'] as String? ?? '').trim();
    final deptEntries = AppConstants.departmentIdToCanonicalName.entries.toList();
    String selectedDeptId = deptEntries
        .firstWhere(
          (e) => e.key != currentDeptId,
          orElse: () => deptEntries.first,
        )
        .key;
    final reasonCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Transfer Faculty Department'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Transfer ${teacher['name']} to a verified department. Historical leave applications will retain their original department.',
                style: const TextStyle(fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedDeptId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'New Department',
                  border: OutlineInputBorder(),
                ),
                items: deptEntries
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(
                          e.value,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: isSubmitting
                    ? null
                    : (val) {
                        if (val != null) {
                          setModalState(() => selectedDeptId = val);
                        }
                      },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Official Transfer Reason',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (selectedDeptId == currentDeptId) {
                        AppHelpers.showError(
                          context,
                          'Please select a different target department.',
                        );
                        return;
                      }
                      setModalState(() => isSubmitting = true);
                      try {
                        final targetName =
                            AppConstants.departmentIdToCanonicalName[selectedDeptId] ??
                            selectedDeptId;
                        await _userRepo.transferFacultyDepartment(
                          targetUid: uid,
                          newDepartmentId: selectedDeptId,
                          newDepartmentName: targetName,
                          reason: reasonCtrl.text.trim(),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          AppHelpers.showSuccess(
                            context,
                            '${teacher['name']} transferred to $targetName.',
                          );
                        }
                      } catch (e) {
                        setModalState(() => isSubmitting = false);
                        if (mounted) {
                          AppHelpers.showError(
                            context,
                            'Department transfer failed: $e',
                          );
                        }
                      }
                    },
              child: const Text('Confirm Transfer'),
            ),
          ],
        ),
      ),
    );
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
              child: _buildCurrentTabBody(
                isDark: isDark,
                bgColor: bgColor,
                cardBg: cardBg,
                borderColor: borderColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
            ),
            bottomNavigationBar: AppBottomNavigation(
              currentIndex: _currentNavIndex,
              role: 'admin',
              adminApprovalBadgeCount: _pendingCount > 0 ? _pendingCount : null,
              onTap: _onBottomNavTap,
            ),
          ),
        );
      },
    );
  }

  Widget _buildCurrentTabBody({
    required bool isDark,
    required Color bgColor,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    switch (_currentNavIndex) {
      case 1:
        return _buildApprovalsView(
          isDark: isDark,
          bgColor: bgColor,
          cardBg: cardBg,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        );
      case 2:
        return _buildFacultyDirectoryView(
          isDark: isDark,
          bgColor: bgColor,
          cardBg: cardBg,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        );
      case 0:
      default:
        return _buildHomeView(
          isDark: isDark,
          bgColor: bgColor,
          cardBg: cardBg,
          borderColor: borderColor,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        );
    }
  }

  // ── Unified Header Bar for Admin Dashboard Views (Title on Left, Pill + Avatar on Right) ────
  Widget _buildHeader({
    required String title,
    Widget? pill,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (pill != null) ...[
                pill,
                const SizedBox(width: 8),
              ],
              GestureDetector(
                onTap: () => Navigator.pushReplacementNamed(
                  context,
                  AppRoutes.adminProfile,
                ),
                child: AppAvatar(
                  name: _adminName,
                  photoUrl: _adminPhotoUrl,
                  size: 38,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSemesterPill(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E3A8A).withValues(alpha: 0.35)
            : const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? const Color(0xFF3B82F6).withValues(alpha: 0.3)
              : const Color(0xFFE0E7FF),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF3B82F6),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Fall Term 2026',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeView({
    required bool isDark,
    required Color bgColor,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final activeList = _currentTeachers
        .where((t) => t['status'] == 'PENDING')
        .toList();

    if (!_sortNewestFirst) {
      activeList.sort(
        (a, b) =>
            (a['createdAtMs'] as int? ?? 0).compareTo(b['createdAtMs'] as int? ?? 0),
      );
    } else {
      activeList.sort(
        (a, b) =>
            (b['createdAtMs'] as int? ?? 0).compareTo(a['createdAtMs'] as int? ?? 0),
      );
    }

    return CustomScrollView(
      slivers: [
        // ── 1. UNIFIED HEADER (Title on Left, Pill + Avatar on Right) ───────
        SliverToBoxAdapter(
          child: _buildHeader(
            title: 'Admin Dashboard',
            pill: _buildSemesterPill(isDark),
            isDark: isDark,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
        ),

        // ── 2. SUBTITLE & ACTION BUTTONS ───────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  'Manage pending teacher registrations and verify credentials.',
                  style: TextStyle(
                    fontSize: 13,
                    color: textSecondary,
                    fontWeight: FontWeight.w400,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    key: const Key('create_staff_account_button'),
                    onPressed: _openCreateStaffModal,
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: const Text(
                      'Create Staff Account (Head / Registrar)',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B4332),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('university_info_sync_button'),
                    onPressed: _openUniversityInfoModal,
                    icon: const Icon(Icons.public_rounded, size: 18),
                    label: const Text(
                      'University Info & Policies (lus.ac.bd)',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark
                          ? const Color(0xFF34D399)
                          : const Color(0xFF1B4332),
                      backgroundColor: isDark
                          ? const Color(0xFF064E3B).withValues(alpha: 0.28)
                          : Colors.transparent,
                      side: BorderSide(
                        color: isDark
                            ? const Color(0xFF34D399)
                            : const Color(0xFF1B4332),
                        width: 1.5,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),

        // ── 3. TOP 3 STATS CARDS (Pending, Approved, Rejected) ─────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // Card 1: Pending
                Expanded(
                  child: _buildMetricCard(
                    cardBg: cardBg,
                    borderColor: borderColor,
                    textSecondary: textSecondary,
                    title: 'Pending',
                    dotColor: const Color(0xFFD97706),
                    value: '$_pendingCount',
                    valueColor: const Color(0xFFB45309),
                    caption: 'Needs Action',
                    captionColor: const Color(0xFFB45309),
                  ),
                ),
                const SizedBox(width: 10),

                // Card 2: Approved
                Expanded(
                  child: _buildMetricCard(
                    cardBg: cardBg,
                    borderColor: borderColor,
                    textSecondary: textSecondary,
                    title: 'Approved',
                    dotColor: const Color(0xFF16A34A),
                    value: '$_approvedCount',
                    valueColor: const Color(0xFF047857),
                    caption: 'This Session',
                    captionColor: const Color(0xFF047857),
                  ),
                ),
                const SizedBox(width: 10),

                // Card 3: Rejected
                Expanded(
                  child: _buildMetricCard(
                    cardBg: cardBg,
                    borderColor: borderColor,
                    textSecondary: textSecondary,
                    title: 'Rejected',
                    dotColor: const Color(0xFFDC2626),
                    value: '$_rejectedCount',
                    valueColor: const Color(0xFFDC2626),
                    caption: 'Archived',
                    captionColor: textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── 4. SECTION HEADER: "Pending Verifications" + SORT ─────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
              top: 22,
              bottom: 12,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Pending Verifications',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                            letterSpacing: -0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$_pendingCount',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _sortNewestFirst = !_sortNewestFirst;
                    });
                  },
                  child: Row(
                    children: [
                      Text(
                        'Sort by Date',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.swap_vert_rounded,
                        size: 18,
                        color: textSecondary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── 5. PENDING VERIFICATIONS LIST ─────────────────────────
        if (_loadError != null && activeList.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.wifi_off_rounded,
                      color: Color(0xFFDC2626),
                      size: 28,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _loadError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF991B1B),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isLoading = true;
                          _loadError = null;
                        });
                        _loadRealFaculty();
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (_isLoading && activeList.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF1B4332)),
              ),
            ),
          )
        else if (activeList.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 32,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No Pending Registrations',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'All faculty registrations have been reviewed and processed.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final teacher = activeList[index];
                return _buildTeacherCard(
                  teacher: teacher,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  isDark: isDark,
                );
              }, childCount: activeList.length),
            ),
          ),

        // ── 6. "VIEW ALL PENDING REQUESTS →" BUTTON ─────────────
        if (activeList.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                top: 4,
                bottom: 24,
              ),
              child: GestureDetector(
                onTap: () {
                  setState(() => _currentNavIndex = 1);
                },
                child: Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE0E7FF),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'View All $_pendingCount Pending Requests',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? const Color(0xFF93C5FD)
                              : const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: isDark
                            ? const Color(0xFF93C5FD)
                            : const Color(0xFF334155),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  TAB 1: APPROVALS QUEUE VIEW
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildApprovalsView({
    required bool isDark,
    required Color bgColor,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final filtered = _currentTeachers.where((t) {
      final status = (t['status'] as String).toUpperCase();
      if (_approvalStatusFilter != 'ALL' && status != _approvalStatusFilter) {
        return false;
      }
      if (_approvalSearchQuery.isNotEmpty) {
        final name = (t['name'] as String).toLowerCase();
        final emp = (t['empId'] as String).toLowerCase();
        final dept = (t['department'] as String).toLowerCase();
        final email = (t['email'] as String? ?? '').toLowerCase();
        if (!name.contains(_approvalSearchQuery) &&
            !emp.contains(_approvalSearchQuery) &&
            !dept.contains(_approvalSearchQuery) &&
            !email.contains(_approvalSearchQuery)) {
          return false;
        }
      }
      return true;
    }).toList();

    return CustomScrollView(
      slivers: [
        // 1. UNIFIED HEADER (Title on Left, All Count Pill + Avatar on Right)
        SliverToBoxAdapter(
          child: _buildHeader(
            title: 'Approvals Queue',
            pill: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF451A03).withValues(alpha: 0.5)
                    : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_currentTeachers.length} All',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFB45309),
                ),
              ),
            ),
            isDark: isDark,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
        ),

        // 2. Subtitle & Search
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  'Review incoming teacher registrations and approve faculty accounts.',
                  style: TextStyle(fontSize: 12.5, color: textSecondary),
                ),
                const SizedBox(height: 14),

                // Search Box
                Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: TextField(
                    controller: _approvalSearchCtrl,
                    onChanged: (val) {
                      setState(() {
                        _approvalSearchQuery = val.trim().toLowerCase();
                      });
                    },
                    style: TextStyle(fontSize: 13.5, color: textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search by teacher name, ID, or department...',
                      hintStyle: TextStyle(fontSize: 13, color: textSecondary),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: textSecondary,
                      ),
                      suffixIcon: _approvalSearchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                size: 18,
                                color: textSecondary,
                              ),
                              onPressed: () {
                                _approvalSearchCtrl.clear();
                                setState(() => _approvalSearchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 3. Status Filter Chips
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildStatusChip(
                    'ALL',
                    'All (${_currentTeachers.length})',
                    isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChip(
                    'PENDING',
                    'Pending ($_pendingCount)',
                    isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChip(
                    'APPROVED',
                    'Approved (${_currentTeachers.where((t) => t['status'] == 'APPROVED').length})',
                    isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChip(
                    'REJECTED',
                    'Rejected (${_currentTeachers.where((t) => t['status'] == 'REJECTED').length})',
                    isDark,
                  ),
                ],
              ),
            ),
          ),
        ),

        // 4. List of Teachers
        if (filtered.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.folder_open_rounded,
                      size: 48,
                      color: textSecondary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No registration requests found',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Try clearing the search query or status filter.',
                      style: TextStyle(fontSize: 12.5, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final teacher = filtered[index];
                return _buildTeacherCard(
                  teacher: teacher,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  isDark: isDark,
                );
              }, childCount: filtered.length),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusChip(String statusKey, String label, bool isDark) {
    final isSelected = _approvalStatusFilter == statusKey;
    return GestureDetector(
      onTap: () => setState(() => _approvalStatusFilter = statusKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF34D399) : const Color(0xFF0F3827))
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (isDark ? const Color(0xFF34D399) : const Color(0xFF0F3827))
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  TAB 2: VERIFIED FACULTY DIRECTORY VIEW
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildFacultyDirectoryView({
    required bool isDark,
    required Color bgColor,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final filtered = _currentFacultyDirectory.where((f) {
      final deptCode = (f['deptCode'] as String? ?? '').toUpperCase();
      if (_facultyDeptFilter != 'ALL' &&
          deptCode != _facultyDeptFilter.toUpperCase()) {
        return false;
      }
      final isActive = f['isActive'] != false;
      final isOfficial = f['isOfficial'] == true;
      switch (_facultyStatusFilter) {
        case 'ACTIVE':
          if (!isActive) return false;
          break;
        case 'INACTIVE':
          if (isActive) return false;
          break;
        case 'REGISTERED':
          if (isOfficial) return false;
          break;
        case 'OFFICIAL':
          if (!isOfficial) return false;
          break;
      }
      if (_facultySearchQuery.isNotEmpty) {
        final name = (f['name'] as String).toLowerCase();
        final emp = (f['empId'] as String).toLowerCase();
        final dept = (f['department'] as String).toLowerCase();
        final email = (f['email'] as String? ?? '').toLowerCase();
        final designation = (f['designation'] as String? ?? '').toLowerCase();
        if (!name.contains(_facultySearchQuery) &&
            !emp.contains(_facultySearchQuery) &&
            !dept.contains(_facultySearchQuery) &&
            !email.contains(_facultySearchQuery) &&
            !designation.contains(_facultySearchQuery)) {
          return false;
        }
      }
      return true;
    }).toList();

    return CustomScrollView(
      slivers: [
        // 1. UNIFIED HEADER (Title on Left, Verified Count Pill + Avatar on Right)
        SliverToBoxAdapter(
          child: _buildHeader(
            title: 'Faculty Directory',
            pill: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF064E3B).withValues(alpha: 0.5)
                    : const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_currentFacultyDirectory.length} Verified',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF16A34A),
                ),
              ),
            ),
            isDark: isDark,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
        ),

        // 2. Subtitle & Search
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  'Browse registered faculty members across university departments.',
                  style: TextStyle(fontSize: 12.5, color: textSecondary),
                ),
                const SizedBox(height: 14),

                // Search Box
                Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: TextField(
                    controller: _facultySearchCtrl,
                    onChanged: (val) {
                      setState(() {
                        _facultySearchQuery = val.trim().toLowerCase();
                      });
                    },
                    style: TextStyle(fontSize: 13.5, color: textPrimary),
                    decoration: InputDecoration(
                      hintText:
                          'Search faculty by name, ID, email or department...',
                      hintStyle: TextStyle(fontSize: 13, color: textSecondary),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: textSecondary,
                      ),
                      suffixIcon: _facultySearchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                size: 18,
                                color: textSecondary,
                              ),
                              onPressed: () {
                                _facultySearchCtrl.clear();
                                setState(() => _facultySearchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 3. Department & Status Filter Chips
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _buildDeptChip('ALL', 'All Departments', isDark),
                      const SizedBox(width: 8),
                      _buildDeptChip('CSE', 'CSE', isDark),
                      const SizedBox(width: 8),
                      _buildDeptChip('EEE', 'EEE', isDark),
                      const SizedBox(width: 8),
                      _buildDeptChip('BBA', 'BBA', isDark),
                      const SizedBox(width: 8),
                      _buildDeptChip('CE', 'Civil (CE)', isDark),
                      const SizedBox(width: 8),
                      _buildDeptChip('ARCH', 'Architecture', isDark),
                      const SizedBox(width: 8),
                      _buildDeptChip('LAW', 'Law', isDark),
                      const SizedBox(width: 8),
                      _buildDeptChip('IS', 'Islamic Studies', isDark),
                      const SizedBox(width: 8),
                      _buildDeptChip('MPH', 'Public Health', isDark),
                      const SizedBox(width: 8),
                      _buildDeptChip('THM', 'THM', isDark),
                      const SizedBox(width: 8),
                      _buildDeptChip('ENG', 'English', isDark),
                      const SizedBox(width: 8),
                      _buildDeptChip('BNG', 'Bangla', isDark),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _buildFacultyStatusChip('ALL', 'All Status', isDark),
                      const SizedBox(width: 8),
                      _buildFacultyStatusChip('ACTIVE', 'Active', isDark),
                      const SizedBox(width: 8),
                      _buildFacultyStatusChip('INACTIVE', 'Inactive', isDark),
                      const SizedBox(width: 8),
                      _buildFacultyStatusChip(
                        'REGISTERED',
                        'Registered Only',
                        isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildFacultyStatusChip(
                        'OFFICIAL',
                        'Official Directory',
                        isDark,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // 4. Faculty List
        if (_isLoading && filtered.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF1B4332)),
              ),
            ),
          )
        else if (filtered.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.person_search_rounded,
                      size: 48,
                      color: textSecondary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No faculty members found',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Try choosing another department or clearing search query.',
                      style: TextStyle(fontSize: 12.5, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final faculty = filtered[index];
                return _buildFacultyCard(
                  faculty: faculty,
                  isDark: isDark,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                );
              }, childCount: filtered.length),
            ),
          ),
      ],
    );
  }

  Widget _buildDeptChip(String deptKey, String label, bool isDark) {
    return _buildFilterChip(
      label: label,
      isSelected: _facultyDeptFilter == deptKey,
      isDark: isDark,
      onTap: () => setState(() => _facultyDeptFilter = deptKey),
    );
  }

  Widget _buildFacultyStatusChip(String statusKey, String label, bool isDark) {
    return _buildFilterChip(
      label: label,
      isSelected: _facultyStatusFilter == statusKey,
      isDark: isDark,
      onTap: () => setState(() => _facultyStatusFilter = statusKey),
      compact: true,
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
    bool compact = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 14,
          vertical: compact ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF34D399) : const Color(0xFF0F3827))
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (isDark ? const Color(0xFF34D399) : const Color(0xFF0F3827))
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: compact ? 11.5 : 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  FACULTY DIRECTORY CARD WIDGET
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildFacultyCard({
    required Map<String, dynamic> faculty,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(faculty, isDark),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      faculty['name'] as String,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (faculty['isOfficial'] == true)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E3A8A).withValues(alpha: 0.5)
                                  : const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF3B82F6).withValues(alpha: 0.3)
                                    : const Color(0xFFE0E7FF),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.public_rounded,
                                  size: 11,
                                  color: Color(0xFF2563EB),
                                ),
                                SizedBox(width: 3),
                                Text(
                                  'OFFICIAL DIRECTORY',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF064E3B).withValues(alpha: 0.5)
                                  : const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified_rounded,
                                  size: 11,
                                  color: Color(0xFF16A34A),
                                ),
                                SizedBox(width: 3),
                                Text(
                                  'LEAVEXA VERIFIED',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            key: Key('toggle_active_${faculty['id']}'),
                            onTap: () => _toggleUserActive(faculty),
                            borderRadius: BorderRadius.circular(5),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: (faculty['isActive'] != false)
                                    ? (isDark
                                        ? const Color(0xFF064E3B)
                                            .withValues(alpha: 0.5)
                                        : const Color(0xFFDCFCE7))
                                    : (isDark
                                        ? const Color(0xFF7F1D1D)
                                            .withValues(alpha: 0.5)
                                        : const Color(0xFFFEE2E2)),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    (faculty['isActive'] != false)
                                        ? Icons.check_circle_outline
                                        : Icons.block,
                                    size: 11,
                                    color: (faculty['isActive'] != false)
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFFDC2626),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    (faculty['isActive'] != false)
                                        ? 'ACTIVE'
                                        : 'INACTIVE',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.4,
                                      color: (faculty['isActive'] != false)
                                          ? const Color(0xFF16A34A)
                                          : const Color(0xFFDC2626),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${faculty['empId']} • ${faculty['department']}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF064E3B).withValues(alpha: 0.5)
                                : const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.school_rounded,
                                size: 12,
                                color: Color(0xFF16A34A),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  faculty['designation'] as String,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'Joined ${faculty['joined']}',
                          style: TextStyle(fontSize: 11, color: textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Icon(
                  (faculty['isOfficial'] == true)
                      ? Icons.public_rounded
                      : Icons.school_outlined,
                  size: 15,
                  color: (faculty['isOfficial'] == true)
                      ? const Color(0xFF2563EB)
                      : const Color(0xFF16A34A),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    faculty['source'] as String? ??
                        (faculty['isOfficial'] == true
                            ? 'Official University Directory • lus.ac.bd'
                            : 'Leavexa Registered Faculty'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _openInspectModal(faculty),
                  child: Text(
                    'Inspect',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? const Color(0xFF93C5FD)
                          : const Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if ((faculty['email'] as String? ?? '').isNotEmpty ||
              (faculty['phone'] as String? ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if ((faculty['email'] as String? ?? '').isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.email_outlined, size: 13, color: textSecondary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          faculty['email'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: textSecondary),
                        ),
                      ),
                    ],
                  ),
                if ((faculty['phone'] as String? ?? '').isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.phone_outlined, size: 13, color: textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        faculty['phone'] as String,
                        style: TextStyle(fontSize: 11.5, color: textSecondary),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  METRIC CARD (Top 3 summary blocks)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildMetricCard({
    required Color cardBg,
    required Color borderColor,
    required Color textSecondary,
    required String title,
    required Color dotColor,
    required String value,
    required Color valueColor,
    required String caption,
    required Color captionColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: valueColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: captionColor,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  TEACHER CARD (Pending Verification Item)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildTeacherCard({
    required Map<String, dynamic> teacher,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required bool isDark,
  }) {
    final status = (teacher['status'] as String? ?? 'PENDING').toUpperCase();
    final isPending = status == 'PENDING';
    final isApproved = status == 'APPROVED' || status == 'VERIFIED';
    final badgeBg = isApproved
        ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.5) : const Color(0xFFDCFCE7))
        : (isPending
            ? (isDark ? const Color(0xFF451A03).withValues(alpha: 0.5) : const Color(0xFFFEF3C7))
            : (isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.5) : const Color(0xFFFEE2E2)));
    final badgeFg = isApproved
        ? const Color(0xFF16A34A)
        : (isPending ? const Color(0xFFB45309) : const Color(0xFFDC2626));

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top Row: Avatar (2-Letter Initials) + Info + Status Badge ──────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with 2-letter initials
              _buildAvatar(teacher, isDark),
              const SizedBox(width: 10),

              // Info Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name & status badge on same line
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            teacher['name'] as String,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Dynamic Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                              color: badgeFg,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${teacher['empId']} • ${teacher['department']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Wrap designation & submitted time to NEVER overflow
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        // Green pill: 🎓 Assistant Professor / Lecturer
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF064E3B).withValues(alpha: 0.5)
                                : const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.school_rounded,
                                size: 12.5,
                                color: Color(0xFF16A34A),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  teacher['designation'] as String,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          teacher['submittedTime'] as String,
                          style: TextStyle(fontSize: 11, color: textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Middle Row: Credential Box with Shield & Inspect Button ────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  size: 15,
                  color: Color(0xFF475569),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    teacher['credentials'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _openInspectModal(teacher),
                  child: Text(
                    'Inspect',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? const Color(0xFF93C5FD)
                          : const Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (isPending) ...[
            const SizedBox(height: 12),

            // ── Action Buttons: [ ✕ Reject ]   [ ✓ Approve ] ────────────────
            Row(
              children: [
                // Reject Button (Soft Pink/Red)
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: ElevatedButton(
                      onPressed: () => _onRejectTeacher(teacher),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? const Color(0xFF450A0A)
                            : const Color(0xFFFEE2E2),
                        foregroundColor: const Color(0xFFDC2626),
                        elevation: 0,
                        side: BorderSide(
                          color: isDark
                              ? const Color(0xFF7F1D1D)
                              : const Color(0xFFFECACA),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.close_rounded, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Reject',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Approve Button (Dark Forest Green)
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: ElevatedButton(
                      onPressed: () => _onApproveTeacher(teacher),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F3827),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_rounded, size: 17),
                          SizedBox(width: 6),
                          Text(
                            'Approve',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Avatar Widget matching Stitch mockup
  String _getInitials(String name) {
    // Strip prefixes: Dr., Engr., Prof., Mr., Ms., Mrs., Md.
    final clean = name
        .replaceAll(
          RegExp(
            r'^(Dr\.|Engr\.|Prof\.|Mr\.|Ms\.|Mrs\.|Md\.)\s*',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0].length >= 2
          ? parts[0].substring(0, 2).toUpperCase()
          : parts[0][0].toUpperCase();
    }
    return 'TC';
  }

  // 2-Letter Initials Avatar Widget (as requested)
  Widget _buildAvatar(Map<String, dynamic> teacher, bool isDark) {
    final name = teacher['name'] as String;
    final initials = _getInitials(name);

    Color bgColor;
    Color textColor;
    Color borderColor;

    if (name.contains('Nazmul')) {
      bgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
      textColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155);
      borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    } else if (name.contains('Farhana')) {
      bgColor = isDark ? const Color(0xFF134E4A) : const Color(0xFFCCFBF1);
      textColor = isDark ? const Color(0xFF99F6E4) : const Color(0xFF0F766E);
      borderColor = isDark ? const Color(0xFF115E59) : const Color(0xFF99F6E4);
    } else if (name.contains('Mahruf')) {
      bgColor = isDark ? const Color(0xFF1E1B4B) : const Color(0xFFE0E7FF);
      textColor = isDark ? const Color(0xFFC7D2FE) : const Color(0xFF4338CA);
      borderColor = isDark ? const Color(0xFF3730A3) : const Color(0xFFC7D2FE);
    } else if (name.contains('Sadia')) {
      bgColor = isDark ? const Color(0xFF581C87) : const Color(0xFFF3E8FF);
      textColor = isDark ? const Color(0xFFE9D5FF) : const Color(0xFF7E22CE);
      borderColor = isDark ? const Color(0xFF6B21A8) : const Color(0xFFDDD6FE);
    } else {
      bgColor = isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7);
      textColor = isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309);
      borderColor = isDark ? const Color(0xFF92400E) : const Color(0xFFFDE68A);
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: textColor,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
