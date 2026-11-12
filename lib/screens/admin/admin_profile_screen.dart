// ─────────────────────────────────────────────────────────────────────────────
//  admin_profile_screen.dart  –  Dedicated Admin / Registrar Profile Screen
//  Role-specific profile for System Administrator with system metrics,
//  administrative controls, dark mode switcher & secure logout.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../models/faculty_profile_state.dart';
import '../../models/user_model.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/storage_service.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_bottom_navigation.dart';

class AdminProfileScreen extends StatefulWidget {
  final AuthRepository? authRepository;
  final UserRepository? userRepository;
  final StorageService? storageService;
  final ImagePicker? imagePicker;

  const AdminProfileScreen({
    super.key,
    this.authRepository,
    this.userRepository,
    this.storageService,
    this.imagePicker,
  });

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  late final AuthRepository _authRepository =
      widget.authRepository ?? AuthRepository();
  late final StorageService _storageService =
      widget.storageService ?? StorageService();
  late final UserRepository _userRepo =
      widget.userRepository ?? UserRepository();
  StreamSubscription<List<UserModel>>? _usersSub;
  bool _isLoggingOut = false;
  bool _isUploadingPhoto = false;
  bool _hasStreamData = false;
  String? _loadError;
  String _adminName = 'Administrator';
  String _adminEmail = 'admin@leavexa.edu';
  String _adminDesignation = 'Administrator';
  String _adminDepartment = 'Office of the Administrator';
  String _adminEmployeeId = 'ADMIN ID: LU-01';
  String _adminPhone = 'Not provided';
  String? _photoUrl;
  int _pendingCount = 0;
  int _approvedCount = 0;
  int _totalTeachersCount = 0;
  int _activeAdminsCount = 0;
  final int _currentNavIndex = 3; // 3: Profile tab active

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _startRealtimeStreams();
  }

  @override
  void dispose() {
    _usersSub?.cancel();
    super.dispose();
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
              _authRepository.currentUserId ?? AuthRepository.activeUser?.uid;
          String nextAdminName = _adminName;
          String nextAdminEmail = _adminEmail;
          String nextDesignation = _adminDesignation;
          String nextDepartment = _adminDepartment;
          String nextEmployeeId = _adminEmployeeId;
          String nextPhone = _adminPhone;
          String? nextPhotoUrl = _photoUrl;

          if (currentUid != null) {
            for (final u in allUsers) {
              if (u.uid == currentUid) {
                nextAdminName =
                    u.fullName.isNotEmpty ? u.fullName : nextAdminName;
                nextAdminEmail = u.email.isNotEmpty ? u.email : nextAdminEmail;
                nextDesignation = u.designation.isNotEmpty
                    ? u.designation
                    : nextDesignation;
                nextDepartment = u.departmentName.isNotEmpty
                    ? u.departmentName
                    : nextDepartment;
                nextEmployeeId =
                    u.employeeId.isNotEmpty ? u.employeeId : nextEmployeeId;
                nextPhone = (u.phone != null && u.phone!.trim().isNotEmpty)
                    ? u.phone!.trim()
                    : 'Not provided';
                nextPhotoUrl = u.photoUrl;
                break;
              }
            }
          }

          final faculty = allUsers
              .where((u) => u.role == 'faculty' && UserRepository.isGenuineUser(u))
              .toList();
          final admins = allUsers
              .where((u) => u.role == 'admin' && u.isActive)
              .toList();

          final nextPending = faculty.where((u) => u.isPending).length;
          final nextApproved = faculty.where((u) => u.isApproved).length;
          final nextTeachers = faculty.length;
          final nextAdmins = admins.length;

          if (_adminName == nextAdminName &&
              _adminEmail == nextAdminEmail &&
              _adminDesignation == nextDesignation &&
              _adminDepartment == nextDepartment &&
              _adminEmployeeId == nextEmployeeId &&
              _adminPhone == nextPhone &&
              _photoUrl == nextPhotoUrl &&
              _pendingCount == nextPending &&
              _approvedCount == nextApproved &&
              _totalTeachersCount == nextTeachers &&
              _activeAdminsCount == nextAdmins &&
              _loadError == null) {
            return;
          }

          setState(() {
            _adminName = nextAdminName;
            _adminEmail = nextAdminEmail;
            _adminDesignation = nextDesignation;
            _adminDepartment = nextDepartment;
            _adminEmployeeId = nextEmployeeId;
            _adminPhone = nextPhone;
            _photoUrl = nextPhotoUrl;
            _pendingCount = nextPending;
            _approvedCount = nextApproved;
            _totalTeachersCount = nextTeachers;
            _activeAdminsCount = nextAdmins;
            _loadError = null;
          });
        },
        onError: (_) {
          if (!mounted) return;
          setState(() {
            if (!_hasStreamData) {
              _loadError = 'Unable to sync live metrics. Tap retry to refresh.';
            }
          });
        },
      );
    } catch (_) {
      // Gracefully fall back to future-based _loadProfile() in unit tests where
      // Firebase is not initialized and streamAllUsers() is not mocked.
    }
  }

  Future<void> _loadProfile() async {
    try {
      final user = await _authRepository.getCurrentUserProfile();
      if (user != null && mounted) {
        setState(() {
          _adminName = user.fullName;
          _adminEmail = user.email;
          if (user.designation.isNotEmpty) {
            _adminDesignation = user.designation;
          }
          if (user.departmentName.isNotEmpty) {
            _adminDepartment = user.departmentName;
          }
          if (user.employeeId.isNotEmpty) {
            _adminEmployeeId = user.employeeId;
          }
          if (user.phone != null && user.phone!.trim().isNotEmpty) {
            _adminPhone = user.phone!.trim();
          }
          _photoUrl = user.photoUrl;
        });
      }
      final pending = await _userRepo.getPendingFaculty();
      final all = await _userRepo.getAllFaculty();
      final admins = await _userRepo.getActiveAdmins();
      final genuinePending =
          pending.where(UserRepository.isGenuineUser).toList();
      final genuineAll = all.where(UserRepository.isGenuineUser).toList();
      if (mounted && !_hasStreamData) {
        setState(() {
          _pendingCount = genuinePending.length;
          _approvedCount = genuineAll.where((u) => u.isApproved).length;
          _totalTeachersCount = genuineAll.length;
          _activeAdminsCount = admins.length;
          _loadError = null;
        });
      }
    } catch (_) {
      // In unit tests without Firebase initialized, preserve loaded profile metrics.
    }
  }

  Future<void> _onPickProfileImage() async {
    if (_isUploadingPhoto) return;
    try {
      final picker = widget.imagePicker ?? ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );
      if (picked == null) return;

      final file = File(picked.path);
      final size = await file.length();
      if (size > StorageService.maxProfileImageSizeBytes) {
        if (mounted) {
          AppHelpers.showError(
            context,
            'Image exceeds the maximum allowed size of 5 MB.',
          );
        }
        return;
      }

      final uid =
          _authRepository.currentUserId ?? AuthRepository.activeUser?.uid;
      if (uid == null) {
        if (mounted) {
          AppHelpers.showError(
            context,
            'Session expired. Please sign in again to update your photo.',
          );
        }
        return;
      }

      setState(() => _isUploadingPhoto = true);

      final realMime = await StorageService.detectRealMimeType(file);
      if (!realMime.startsWith('image/')) {
        throw const StorageValidationException(
          'Selected file is not a supported image (JPG, PNG, WEBP).',
        );
      }

      String nextPhotoUrl;
      try {
        nextPhotoUrl = await _storageService
            .uploadProfileImage(
              uid: uid,
              file: file,
              previousPhotoUrl: _photoUrl,
            )
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        // Fallback when Firebase Storage bucket is unprovisioned or offline:
        // persist compressed 512x512 image directly as a data URI in Firestore.
        final bytes = await file.readAsBytes();
        if (bytes.length > 500 * 1024) {
          throw const StorageValidationException(
            'Image is too large after compression. Please select a smaller image.',
          );
        }
        nextPhotoUrl = 'data:$realMime;base64,${base64Encode(bytes)}';
      }

      await _userRepo.updateUser(uid, {'photoUrl': nextPhotoUrl});
      if (AuthRepository.activeUser != null) {
        AuthRepository.activeUser =
            AuthRepository.activeUser!.copyWith(photoUrl: nextPhotoUrl);
      }

      if (mounted) {
        setState(() {
          _photoUrl = nextPhotoUrl;
          _isUploadingPhoto = false;
        });
        AppHelpers.showSuccess(context, 'Profile photo updated successfully!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        AppHelpers.showError(context, 'Failed to update photo: $e');
      }
    }
  }

  Future<void> _onRemoveProfilePhoto() async {
    if (_isUploadingPhoto || _photoUrl == null || _photoUrl!.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Profile Photo'),
        content: const Text(
          'Are you sure you want to remove your profile photo? Your avatar will display your initials instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final uid =
        _authRepository.currentUserId ?? AuthRepository.activeUser?.uid;
    if (uid == null) {
      if (mounted) {
        AppHelpers.showError(
          context,
          'Session expired. Please sign in again.',
        );
      }
      return;
    }

    setState(() => _isUploadingPhoto = true);

    try {
      final oldUrl = _photoUrl;
      if (oldUrl != null &&
          oldUrl.isNotEmpty &&
          oldUrl.startsWith('http')) {
        try {
          await _storageService
              .deleteByUrl(oldUrl)
              .timeout(const Duration(seconds: 5));
        } catch (_) {}
      }

      await _userRepo.updateUser(uid, {'photoUrl': null});
      if (AuthRepository.activeUser != null) {
        final u = AuthRepository.activeUser!;
        AuthRepository.activeUser = UserModel(
          uid: u.uid,
          fullName: u.fullName,
          email: u.email,
          employeeId: u.employeeId,
          departmentId: u.departmentId,
          departmentName: u.departmentName,
          designation: u.designation,
          role: u.role,
          phone: u.phone,
          photoUrl: null,
          isActive: u.isActive,
          approvalStatus: u.approvalStatus,
          createdAt: u.createdAt,
        );
      }

      if (mounted) {
        setState(() {
          _photoUrl = null;
          _isUploadingPhoto = false;
        });
        AppHelpers.showSuccess(context, 'Profile photo removed successfully.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        AppHelpers.showError(context, 'Failed to remove photo: $e');
      }
    }
  }

  void _showPhotoOptions(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final textPrimary =
            isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
        final textSecondary =
            isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
        final accentColor =
            isDark ? const Color(0xFF34D399) : const Color(0xFF1B4332);
        final hasPhoto = _photoUrl != null && _photoUrl!.isNotEmpty;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Profile Photo (Optional)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Upload, change or remove your profile picture anytime.',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Icon(
                    Icons.photo_library_outlined,
                    color: accentColor,
                  ),
                  title: Text(
                    hasPhoto ? 'Change Photo' : 'Upload Photo',
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Choose an image from your gallery',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await Future.delayed(const Duration(milliseconds: 80));
                    if (mounted) _onPickProfileImage();
                  },
                ),
                if (hasPhoto)
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFEF4444),
                    ),
                    title: const Text(
                      'Remove Photo',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Use a clean initials avatar instead',
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await Future.delayed(const Duration(milliseconds: 80));
                      if (mounted) _onRemoveProfilePhoto();
                    },
                  ),
                ListTile(
                  leading: Icon(
                    Icons.close_rounded,
                    color: textSecondary,
                  ),
                  title: Text(
                    'Cancel',
                    style: TextStyle(color: textSecondary),
                  ),
                  onTap: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onBottomNavTap(int index) {
    if (index == _currentNavIndex) return;
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, AppRoutes.adminDashboard);
        break;
      case 1:
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.adminDashboard,
          arguments: {'tab': 1},
        );
        break;
      case 2:
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.adminDashboard,
          arguments: {'tab': 2},
        );
        break;
      case 3:
        // Already on Profile
        break;
    }
  }

  void _onLogOut() {
    showDialog(
      context: context,
      barrierDismissible: !_isLoggingOut,
      builder: (dialogCtx) => PopScope(
        canPop: !_isLoggingOut,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEE2E2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Color(0xFFDC2626),
                    size: 26,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Log Out',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Are you sure you want to log out of the Administrator Portal?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // ── TOP BUTTON: Log Out (Destructive Red) ───────────────────
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isLoggingOut
                        ? null
                        : () async {
                            Navigator.pop(dialogCtx);
                            // Cancel live listener immediately before waiting for dialog dismissal.
                            _usersSub?.cancel();
                            _usersSub = null;
                            await Future.delayed(
                              const Duration(milliseconds: 100),
                            );
                            if (!mounted) return;
                            setState(() => _isLoggingOut = true);
                            try {
                              await _authRepository.logout();
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
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to log out: $e'),
                                    backgroundColor: const Color(0xFFDC2626),
                                  ),
                                );
                              }
                            }
                          },
                    child: _isLoggingOut
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Log Out',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 10),

                // ── BOTTOM BUTTON: Cancel (Neutral Outlined) ────────────────
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      foregroundColor: const Color(0xFF475569),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
    final dividerColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFF1F5F9);
    final surfaceAlt = isDark
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
                  vertical: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 1. TOP HEADER BAR ───────────────────────────────────
                    Row(
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
                                'Admin Profile',
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
                        // Settings / Dark Mode toggle
                        GestureDetector(
                          onTap: () {
                            AppThemeState.instance.toggleTheme();
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: surfaceAlt,
                            ),
                            child: Icon(
                              isDark
                                  ? Icons.light_mode_outlined
                                  : Icons.dark_mode_outlined,
                              size: 20,
                              color: textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // ── 2. TOP ADMIN PROFILE CARD ───────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 24,
                      ),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: borderColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Admin Avatar with camera icon & tap to change/remove photo
                          GestureDetector(
                            onTap: () => _showPhotoOptions(isDark),
                            behavior: HitTestBehavior.opaque,
                            child: Stack(
                              children: [
                                AppAvatar(
                                  name: _adminName,
                                  photoUrl: _photoUrl,
                                  size: 84,
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF3B82F6)
                                        : const Color(0xFF1B4332),
                                    width: 2.5,
                                  ),
                                ),
                                if (_isUploadingPhoto)
                                  Container(
                                    width: 84,
                                    height: 84,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color:
                                          Colors.black.withValues(alpha: 0.45),
                                    ),
                                    child: const Center(
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF3B82F6)
                                          : const Color(0xFF1B4332),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isDark
                                            ? const Color(0xFF1E293B)
                                            : Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_outlined,
                                      size: 13,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Name
                          Text(
                            _adminName,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),

                          // Designation (avoid repeating full name identically)
                          Text(
                            _adminDesignation.toLowerCase() ==
                                    _adminName.toLowerCase()
                                ? 'Chief Registrar & IT Systems'
                                : _adminDesignation,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),

                          // Department
                          Text(
                            _adminDepartment,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w400,
                              color: textSecondary,
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Badges Row: Access Level + Employee ID
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(
                                          0xFF1E3A8A,
                                        ).withValues(alpha: 0.4)
                                      : const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(
                                            0xFF3B82F6,
                                          ).withValues(alpha: 0.4)
                                        : const Color(0xFFE0E7FF),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.security_rounded,
                                      size: 13,
                                      color: Color(0xFF3B82F6),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Super Admin',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF3B82F6),
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
                                  color: surfaceAlt,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.badge_outlined,
                                      size: 13,
                                      color: textSecondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _adminEmployeeId,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    if (_loadError != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.wifi_off_rounded,
                              size: 18,
                              color: Color(0xFFDC2626),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _loadError!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF991B1B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() => _loadError = null);
                                _loadProfile();
                              },
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // ── 3. SYSTEM STATS OVERVIEW CARDS (Image 3 Style) ───────
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatBlock(
                            cardBg: cardBg,
                            borderColor: borderColor,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            label: 'Total Teachers',
                            value: '$_totalTeachersCount',
                            color: const Color(0xFF00C48C),
                            icon: Icons.people_outline_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatBlock(
                            cardBg: cardBg,
                            borderColor: borderColor,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            label: 'Pending Requests',
                            value: '$_pendingCount',
                            color: const Color(0xFFF59E0B),
                            icon: Icons.access_time_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatBlock(
                            cardBg: cardBg,
                            borderColor: borderColor,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            label: 'Active Admins',
                            value: '$_activeAdminsCount',
                            color: const Color(0xFF3B82F6),
                            icon: Icons.manage_accounts_outlined,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // ── 4. ADMINISTRATIVE DETAILS ───────────────────────────
                    Text(
                      'ADMINISTRATIVE DETAILS',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: textSecondary,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        children: [
                          _AdminInfoRow(
                            icon: Icons.person_outline_rounded,
                            label: 'Official Title',
                            value: _adminDesignation.toLowerCase() ==
                                    _adminName.toLowerCase()
                                ? 'System Administrator'
                                : _adminDesignation,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                          Divider(height: 1, color: dividerColor),
                          _AdminInfoRow(
                            icon: Icons.alternate_email_rounded,
                            label: 'Admin Email',
                            value: _adminEmail,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                          Divider(height: 1, color: dividerColor),
                          _AdminInfoRow(
                            icon: Icons.phone_outlined,
                            label: 'Hotline / Contact',
                            value: _adminPhone,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                          Divider(height: 1, color: dividerColor),
                          _AdminInfoRow(
                            icon: Icons.room_outlined,
                            label: 'Office Location',
                            value: 'Building RKB-204',
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                          Divider(height: 1, color: dividerColor),
                          _AdminInfoRow(
                            icon: Icons.security_outlined,
                            label: 'Access Privilege',
                            value: 'Full Super-Admin (Level-1)',
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // ── 5. ADMINISTRATIVE SHORTCUTS ─────────────────────────
                    Text(
                      'MANAGEMENT SHORTCUTS',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: textSecondary,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Container(
                      key: const ValueKey('admin_profile_shortcuts_card'),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Material(
                        type: MaterialType.transparency,
                        child: ListTile(
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF064E3B)
                                      .withValues(alpha: 0.5)
                                  : const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.people_outline_rounded,
                              color: isDark
                                  ? const Color(0xFF34D399)
                                  : const Color(0xFF047857),
                              size: 20,
                            ),
                          ),
                          title: Text(
                            'Verified Faculty Directory',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            '$_approvedCount registered faculty members',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            color: textSecondary,
                          ),
                          onTap: () {
                            Navigator.pushReplacementNamed(
                              context,
                              AppRoutes.adminDashboard,
                              arguments: {'tab': 2},
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── 6. LOG OUT BUTTON ────────────────────────────────────
                    Container(
                      key: const ValueKey('admin_profile_logout_btn'),
                      width: double.infinity,
                      height: 48,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF450A0A).withValues(alpha: 0.3)
                            : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF7F1D1D)
                              : const Color(0xFFFECACA),
                        ),
                      ),
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          onTap: _isLoggingOut ? null : _onLogOut,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.logout_rounded,
                                  size: 18,
                                  color: Color(0xFFDC2626),
                                ),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Log Out of Admin Portal',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
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
  }

  Widget _buildStatBlock({
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
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
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color textPrimary;
  final Color textSecondary;

  const _AdminInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Icon(icon, size: 18, color: textSecondary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
