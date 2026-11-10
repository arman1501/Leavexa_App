// ─────────────────────────────────────────────────────────────────────────────
//  head_profile_screen.dart  –  Dedicated Department Head Profile Screen
//  Role-specific profile for Department Head with department oversight stats,
//  administrative contacts, office consultation hours & secure logout.
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

class HeadProfileScreen extends StatefulWidget {
  final AuthRepository? authRepository;

  const HeadProfileScreen({super.key, this.authRepository});

  @override
  State<HeadProfileScreen> createState() => _HeadProfileScreenState();
}

class _HeadProfileScreenState extends State<HeadProfileScreen> {
  late final AuthRepository _authRepository =
      widget.authRepository ?? AuthRepository();
  late final StorageService _storageService = StorageService();
  late final UserRepository _userRepo = UserRepository();
  bool _isLoggingOut = false;
  bool _isUploadingPhoto = false;
  String? _photoUrl;
  final int _currentNavIndex = 3; // 3: Profile tab active

  // Department Head specific profile state
  String _fullName = 'Prof. Dr. Tariqul Islam';
  String _email = 'head.cse@leavexa.edu';
  String _phone = '+880 1711-987654';
  String _office = 'Room 501, Head Office, Academic Bldg 1';
  final String _employeeId = 'EMP-H1005';
  final String _department = 'Computer Science & Engineering';
  final String _designation = 'Professor & Head of Department';
  final String _officeHours = 'Sun – Thu, 10:00 AM – 04:00 PM';
  final String _appointedDate = 'January 2024';

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
          _fullName = user.fullName;
          _email = user.email;
          _photoUrl = user.photoUrl;
          if (user.phone != null && user.phone!.isNotEmpty) {
            _phone = user.phone!;
          }
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
                    color: Color(0xFF16A34A),
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
        Navigator.pushReplacementNamed(context, AppRoutes.headDashboard);
        break;
      case 1:
        Navigator.pushReplacementNamed(context, AppRoutes.headRequests);
        break;
      case 2:
        Navigator.pushReplacementNamed(context, AppRoutes.deptCalendar);
        break;
      case 3:
        // Already on Profile
        break;
    }
  }

  void _onLogOut() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text(
          'Are you sure you want to log out of Department Head Portal?',
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
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  void _openEditProfileDialog() {
    final nameCtrl = TextEditingController(text: _fullName);
    final emailCtrl = TextEditingController(text: _email);
    final phoneCtrl = TextEditingController(text: _phone);
    final officeCtrl = TextEditingController(text: _office);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final sheetBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
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
                Text(
                  'Edit Head Profile',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Official Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Direct Phone',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: officeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Office Location',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _fullName = nameCtrl.text.trim();
                        _email = emailCtrl.text.trim();
                        _phone = phoneCtrl.text.trim();
                        _office = officeCtrl.text.trim();
                      });
                      Navigator.pop(ctx);
                      AppHelpers.showSuccess(
                        context,
                        'Head profile updated successfully',
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F3827),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Save Changes',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
                          'Profile Head',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        // Settings / Theme Switcher
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

                    // ── 2. TOP PROFILE HEADER CARD ─────────────────────────
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
                          // Avatar with camera icon & tap to change/remove photo
                          GestureDetector(
                            onTap: () => _showPhotoOptions(isDark),
                            behavior: HitTestBehavior.opaque,
                            child: Stack(
                              children: [
                                AppAvatar(
                                  name: _fullName,
                                  photoUrl: _photoUrl,
                                  size: 84,
                                  border: Border.all(
                                    color: const Color(0xFF16A34A),
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
                                      color: const Color(0xFF16A34A),
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
                          Text(
                            _fullName,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _designation,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _department,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w400,
                              color: textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Badges Row
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
                                          0xFF064E3B,
                                        ).withValues(alpha: 0.4)
                                      : const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.verified_rounded,
                                      size: 13,
                                      color: Color(0xFF16A34A),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Dept. Head',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF16A34A),
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
                                      _employeeId,
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

                    // ── 3. DEPARTMENT OVERSIGHT STATS ────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _buildHeadStatCard(
                            cardBg: cardBg,
                            borderColor: borderColor,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            label: 'Faculty',
                            value: '18',
                            color: const Color(0xFF16A34A),
                            icon: Icons.groups_outlined,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildHeadStatCard(
                            cardBg: cardBg,
                            borderColor: borderColor,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            label: 'Pending Requests',
                            value: '6',
                            color: const Color(0xFFD97706),
                            icon: Icons.pending_actions_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildHeadStatCard(
                            cardBg: cardBg,
                            borderColor: borderColor,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            label: 'Courses',
                            value: '32',
                            color: const Color(0xFF2563EB),
                            icon: Icons.menu_book_rounded,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // ── 4. PERSONAL & ADMINISTRATIVE INFORMATION ─────────────
                    Text(
                      'ADMINISTRATIVE INFORMATION',
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
                          _HeadProfileRow(
                            label: 'Full Name',
                            value: _fullName,
                            icon: Icons.person_outline_rounded,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                          Divider(height: 1, color: dividerColor),
                          _HeadProfileRow(
                            label: 'Official Email',
                            value: _email,
                            icon: Icons.alternate_email_rounded,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                          Divider(height: 1, color: dividerColor),
                          _HeadProfileRow(
                            label: 'Direct Phone',
                            value: _phone,
                            icon: Icons.phone_outlined,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                          Divider(height: 1, color: dividerColor),
                          _HeadProfileRow(
                            label: 'Office Location',
                            value: _office,
                            icon: Icons.room_outlined,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                          Divider(height: 1, color: dividerColor),
                          _HeadProfileRow(
                            label: 'Consultation Hours',
                            value: _officeHours,
                            icon: Icons.schedule_rounded,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                          Divider(height: 1, color: dividerColor),
                          _HeadProfileRow(
                            label: 'Appointed Since',
                            value: _appointedDate,
                            icon: Icons.event_available_rounded,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── 5. EDIT PROFILE BUTTON ───────────────────────────────
                    GestureDetector(
                      onTap: _openEditProfileDialog,
                      child: Container(
                        width: double.infinity,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF064E3B).withValues(alpha: 0.3)
                              : const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF065F46)
                                : const Color(0xFFBBF7D0),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: Color(0xFF16A34A),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Edit Profile',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

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
                          'Log Out of Head Portal',
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
              role: 'department_head',
              onTap: _onBottomNavTap,
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeadStatCard({
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
}

class _HeadProfileRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color textPrimary;
  final Color textSecondary;

  const _HeadProfileRow({
    required this.label,
    required this.value,
    required this.icon,
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
