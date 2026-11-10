// ─────────────────────────────────────────────────────────────────────────────
//  admin_profile_screen.dart  –  Dedicated Admin / Registrar Profile Screen
//  Role-specific profile for System Administrator with system metrics,
//  administrative controls, dark mode switcher & secure logout.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../models/faculty_profile_state.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/storage_service.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_bottom_navigation.dart';

class AdminProfileScreen extends StatefulWidget {
  final AuthRepository? authRepository;

  const AdminProfileScreen({super.key, this.authRepository});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  late final AuthRepository _authRepository =
      widget.authRepository ?? AuthRepository();
  late final StorageService _storageService = StorageService();
  late final UserRepository _userRepo = UserRepository();
  bool _isLoggingOut = false;
  bool _isUploadingPhoto = false;
  String _adminName = 'System Administrator';
  String _adminEmail = 'admin@leavexa.edu';
  String? _photoUrl;
  int _pendingCount = 0;
  int _approvedCount = 0;
  final int _currentNavIndex = 3; // 3: Profile tab active

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = await _authRepository.getCurrentUserProfile();
      if (user != null && mounted) {
        setState(() {
          _adminName = user.fullName;
          _adminEmail = user.email;
          _photoUrl = user.photoUrl;
        });
      }
      final pending = await _userRepo.getPendingFaculty();
      final all = await _userRepo.getAllFaculty();
      if (mounted) {
        setState(() {
          _pendingCount = pending.length;
          _approvedCount = all.where((u) => u.isApproved).length;
        });
      }
    } catch (_) {}
  }

  Future<void> _onPickProfileImage() async {
    if (_isUploadingPhoto) return;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
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
      if (uid == null) return;

      setState(() => _isUploadingPhoto = true);

      final downloadUrl = await _storageService.uploadProfileImage(
        uid: uid,
        file: file,
        previousPhotoUrl: _photoUrl,
      );

      await _userRepo.updateUser(uid, {'photoUrl': downloadUrl});

      if (mounted) {
        setState(() {
          _photoUrl = downloadUrl;
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
    if (uid == null) return;

    setState(() => _isUploadingPhoto = true);

    try {
      final oldUrl = _photoUrl;
      if (oldUrl != null && oldUrl.isNotEmpty) {
        try {
          await _storageService.deleteByUrl(oldUrl);
        } catch (_) {}
      }

      await _userRepo.updateUser(uid, {'photoUrl': null});

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
                  leading: const Icon(
                    Icons.photo_library_outlined,
                    color: Color(0xFF1B4332),
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
                  onTap: () {
                    Navigator.pop(ctx);
                    _onPickProfileImage();
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
                    onTap: () {
                      Navigator.pop(ctx);
                      _onRemoveProfilePhoto();
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
                            setState(() => _isLoggingOut = true);
                            try {
                              await _authRepository.logout();
                              AppThemeState.instance.resetToLightMode();
                              FacultyProfileState.instance.reset();
                              if (mounted) {
                                Navigator.pushNamedAndRemoveUntil(
                                  context,
                                  AppRoutes.login,
                                  (route) => false,
                                );
                              }
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
                        Text(
                          'Admin Profile',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'serif',
                            color: textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
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

                          // Designation
                          Text(
                            'Chief Registrar & IT Systems',
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
                            'Office of the Registrar & Administration',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w400,
                              color: textSecondary,
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Badges Row: Access Level + Employee ID
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
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
                              const SizedBox(width: 8),
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
                                      'EMP-ADM01',
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

                    const SizedBox(height: 20),

                    // ── 3. SYSTEM STATS OVERVIEW CARDS ───────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatBlock(
                            cardBg: cardBg,
                            borderColor: borderColor,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            label: 'Teachers',
                            value: '$_approvedCount',
                            color: const Color(0xFF047857),
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
                            label: 'Pending',
                            value: '$_pendingCount',
                            color: const Color(0xFFB45309),
                            icon: Icons.pending_actions_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatBlock(
                            cardBg: cardBg,
                            borderColor: borderColor,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            label: 'Uptime',
                            value: '99.9%',
                            color: const Color(0xFF2563EB),
                            icon: Icons.speed_rounded,
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
                            value: 'System Administrator & Registrar',
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
                            value: '+880 1700-000000',
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                          Divider(height: 1, color: dividerColor),
                          _AdminInfoRow(
                            icon: Icons.room_outlined,
                            label: 'Office Location',
                            value: 'Registrar Complex, Room 204',
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                          Divider(height: 1, color: dividerColor),
                          _AdminInfoRow(
                            icon: Icons.security_outlined,
                            label: 'Access Privilege',
                            value: 'Full Super-Admin (Level 1)',
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
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.people_outline_rounded,
                                color: Color(0xFF047857),
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
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── 6. LOG OUT BUTTON ────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _onLogOut,
                        icon: const Icon(
                          Icons.logout_rounded,
                          size: 18,
                          color: Color(0xFFDC2626),
                        ),
                        label: const Text(
                          'Log Out of Admin Portal',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFECACA)),
                          backgroundColor: isDark
                              ? const Color(0xFF450A0A).withValues(alpha: 0.3)
                              : const Color(0xFFFEF2F2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
              onTap: _onBottomNavTap,
            ),
          ),
        );
      },
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
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
