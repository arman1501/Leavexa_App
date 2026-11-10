// ─────────────────────────────────────────────────────────────────────────────
//  edit_profile_screen.dart  –  Edit Faculty Profile Screen (Dark & Light Theme Aware)
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../models/faculty_profile_state.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/storage_service.dart';
import '../../widgets/app_avatar.dart';

class EditProfileScreen extends StatefulWidget {
  final StorageService? storageService;
  final UserRepository? userRepository;
  final AuthRepository? authRepository;

  const EditProfileScreen({
    super.key,
    this.storageService,
    this.userRepository,
    this.authRepository,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final StorageService _storageService =
      widget.storageService ?? StorageService();
  late final UserRepository _userRepo =
      widget.userRepository ?? UserRepository();
  late final AuthRepository _authRepo =
      widget.authRepository ?? AuthRepository();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _officeController;
  final _formKey = GlobalKey<FormState>();

  String? _photoUrl;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    final current = FacultyProfileState.instance.notifier.value;
    _nameController = TextEditingController(text: current.fullName);
    _emailController = TextEditingController(text: current.email);
    _phoneController = TextEditingController(text: current.phone);
    _officeController = TextEditingController(text: current.office);
    _loadCurrentPhoto();
  }

  Future<void> _loadCurrentPhoto() async {
    try {
      final user = await _authRepo.getCurrentUserProfile();
      if (user != null && mounted) {
        setState(() {
          _photoUrl = user.photoUrl;
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

      final uid = _authRepo.currentUserId ?? AuthRepository.activeUser?.uid;
      if (uid == null) {
        if (mounted) {
          AppHelpers.showError(
            context,
            'You must be signed in to update photo.',
          );
        }
        return;
      }

      setState(() => _isUploadingPhoto = true);

      final downloadUrl = await _storageService.uploadProfileImage(
        uid: uid,
        file: file,
        previousPhotoUrl: _photoUrl,
      );

      await _userRepo.updateUser(uid, {'photoUrl': downloadUrl});
      FacultyProfileState.instance.updateProfile(photoUrl: downloadUrl);

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
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
        );
      },
    );

    if (confirmed != true) return;

    final uid = _authRepo.currentUserId ?? AuthRepository.activeUser?.uid;
    if (uid == null) {
      if (mounted) {
        AppHelpers.showError(context, 'You must be signed in to remove photo.');
      }
      return;
    }

    setState(() => _isUploadingPhoto = true);

    try {
      final oldUrl = _photoUrl;
      if (oldUrl != null && oldUrl.isNotEmpty) {
        try {
          await _storageService.deleteByUrl(oldUrl);
        } catch (_) {
          // Best effort storage deletion
        }
      }

      await _userRepo.updateUser(uid, {'photoUrl': null});
      FacultyProfileState.instance.updateProfile(removePhoto: true);

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
                  style: TextStyle(
                    fontSize: 12,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_outlined,
                    color: Color(0xFF0D9488),
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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _officeController.dispose();
    super.dispose();
  }

  void _onSaveChanges() {
    if (!_formKey.currentState!.validate()) {
      AppHelpers.showError(context, 'Please fix errors before saving!');
      return;
    }

    final phoneVal = _phoneController.text.trim();
    if (RegExp(r'[a-zA-Z]').hasMatch(phoneVal)) {
      AppHelpers.showError(
        context,
        'Exception: Phone number cannot contain letters!',
      );
      return;
    }
    if (phoneVal.length > 1 && phoneVal.substring(1).contains('+')) {
      AppHelpers.showError(
        context,
        '"+" sign can only be at the start of phone number!',
      );
      return;
    }

    FacultyProfileState.instance.updateProfile(
      fullName: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: phoneVal,
      office: _officeController.text.trim(),
    );
    AppHelpers.showSuccess(context, 'Profile updated successfully!');
    Navigator.pop(context);
  }

  void _showDiscardDialog(bool isDark) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF451A1A)
                      : const Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFEF4444),
                  size: 26,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Discard Unsaved Changes?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? const Color(0xFFF8FAFC)
                      : const Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Are you sure you want to exit? Any changes you made will be lost.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF8FAFC),
                        foregroundColor: isDark
                            ? const Color(0xFFCBD5E1)
                            : const Color(0xFF475569),
                        side: BorderSide(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      child: const Text(
                        'No, Keep Editing',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Yes, Discard',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
            : const Color(0xFFF8FAFB);
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
        final disabledBg = isDark
            ? const Color(0xFF334155)
            : const Color(0xFFF1F5F9);
        final inputBg = isDark ? const Color(0xFF1E293B) : Colors.white;

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
            appBar: AppBar(
              backgroundColor: bgColor,
              elevation: 0,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: textPrimary,
                  size: 22,
                ),
                onPressed: () => _showDiscardDialog(isDark),
              ),
              title: Text(
                'Edit Profile',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              centerTitle: false,
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── 1. PROFILE PHOTO SECTION ────────────────────────────────
                      Center(
                        child: GestureDetector(
                          onTap: () => _showPhotoOptions(isDark),
                          behavior: HitTestBehavior.opaque,
                          child: Column(
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  AppAvatar(
                                    name: _nameController.text.trim().isNotEmpty
                                        ? _nameController.text.trim()
                                        : 'Faculty Member',
                                    photoUrl: _photoUrl,
                                    size: 90,
                                    border: Border.all(
                                      color: borderColor,
                                      width: 2,
                                    ),
                                  ),
                                  if (_isUploadingPhoto)
                                    Container(
                                      width: 90,
                                      height: 90,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.black.withValues(alpha: 0.45),
                                      ),
                                      child: const Center(
                                        child: SizedBox(
                                          width: 28,
                                          height: 28,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor:
                                                AlwaysStoppedAnimation<
                                                    Color>(Colors.white),
                                          ),
                                        ),
                                      ),
                                    ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF0D9488)
                                            : const Color(0xFF042F2C),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: cardBg,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt_outlined,
                                        size: 15,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _isUploadingPhoto
                                    ? 'Updating photo...'
                                    : (_photoUrl != null &&
                                            _photoUrl!.isNotEmpty)
                                        ? 'Tap to change or remove photo'
                                        : 'Tap to upload photo (Optional)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? const Color(0xFF38BDF8)
                                      : const Color(0xFF0D9488),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Optional • JPG, PNG up to 5MB',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                  color: textSecondary,
                                ),
                              ),
                              if (_photoUrl != null &&
                                  _photoUrl!.isNotEmpty &&
                                  !_isUploadingPhoto) ...[
                                const SizedBox(height: 6),
                                GestureDetector(
                                  onTap: _onRemoveProfilePhoto,
                                  child: const Text(
                                    'Remove Photo',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFEF4444),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 22),

                      // ── 2. ACADEMIC APPOINTMENT (LOCKED) SECTION ─────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.lock_outline_rounded,
                                size: 14,
                                color: textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'ACADEMIC APPOINTMENT (LOCKED)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: textSecondary,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Registrar Verified',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

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
                            // Employee ID
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Employee ID',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                ),
                                Text(
                                  'System ID',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            _buildDisabledField(
                              value: 'FAC-1024',
                              icon: Icons.lock_outline_rounded,
                              disabledBg: disabledBg,
                              textSecondary: textSecondary,
                            ),

                            const SizedBox(height: 14),

                            // Department
                            Text(
                              'Department',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _buildDisabledField(
                              value: 'Computer Science & Engineering',
                              icon: Icons.apartment_rounded,
                              disabledBg: disabledBg,
                              textSecondary: textSecondary,
                            ),

                            const SizedBox(height: 14),

                            // Designation
                            Text(
                              'Designation',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _buildDisabledField(
                              value: 'Assistant Professor',
                              icon: Icons.badge_outlined,
                              disabledBg: disabledBg,
                              textSecondary: textSecondary,
                            ),

                            const SizedBox(height: 14),

                            // Info Container
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E3A8A)
                                    : const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    size: 18,
                                    color: isDark
                                        ? const Color(0xFF60A5FA)
                                        : const Color(0xFF0D9488),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Tenure status, title, and departmental affiliations are managed exclusively by the Academic Senate and HR Services.',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                        color: isDark
                                            ? const Color(0xFFDBEAFE)
                                            : const Color(0xFF334155),
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),

                      // ── 3. PERSONAL & CONTACT INFORMATION SECTION ────────────────
                      Row(
                        children: [
                          Icon(
                            Icons.badge_outlined,
                            size: 16,
                            color: isDark
                                ? const Color(0xFF38BDF8)
                                : const Color(0xFF0D9488),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'PERSONAL & CONTACT INFORMATION',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

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
                            // Full Name & Honorific
                            Text(
                              'Full Name & Honorific',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _buildEditableField(
                              controller: _nameController,
                              hint: 'Enter full name',
                              inputBg: inputBg,
                              borderColor: borderColor,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                            ),

                            const SizedBox(height: 14),

                            // Official Email
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Official Email',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF064E3B)
                                        : const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.verified_outlined,
                                        size: 12,
                                        color: Color(0xFF16A34A),
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Institutional',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF16A34A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            _buildEditableField(
                              controller: _emailController,
                              hint: 'Enter official email',
                              prefixIcon: Icons.email_outlined,
                              inputBg: inputBg,
                              borderColor: borderColor,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                            ),

                            const SizedBox(height: 14),

                            // Contact Phone
                            Text(
                              'Contact Phone',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _buildEditableField(
                              controller: _phoneController,
                              hint: 'Enter contact phone',
                              prefixIcon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              inputBg: inputBg,
                              borderColor: borderColor,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[\d\+\-\s\(\)]'),
                                ),
                                TextInputFormatter.withFunction((
                                  oldValue,
                                  newValue,
                                ) {
                                  final text = newValue.text;
                                  if (text.contains('+')) {
                                    final firstCharIsPlus = text.startsWith(
                                      '+',
                                    );
                                    final stripped = text.replaceAll('+', '');
                                    final resultText = firstCharIsPlus
                                        ? '+$stripped'
                                        : stripped;
                                    if (resultText != text) {
                                      final diff =
                                          text.length - resultText.length;
                                      final newOffset =
                                          (newValue.selection.end - diff).clamp(
                                            0,
                                            resultText.length,
                                          );
                                      return TextEditingValue(
                                        text: resultText,
                                        selection: TextSelection.collapsed(
                                          offset: newOffset,
                                        ),
                                      );
                                    }
                                  }
                                  return newValue;
                                }),
                              ],
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Phone number cannot be empty';
                                }
                                if (RegExp(r'[a-zA-Z]').hasMatch(value)) {
                                  return 'Exception: Phone number can only contain numbers';
                                }
                                if (value.length > 1 &&
                                    value.substring(1).contains('+')) {
                                  return '"+" sign is only allowed at the beginning';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 14),

                            // Assigned Faculty Office
                            Text(
                              'Assigned Faculty Office',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _buildEditableField(
                              controller: _officeController,
                              hint: 'Enter assigned office',
                              prefixIcon: Icons.door_front_door_outlined,
                              inputBg: inputBg,
                              borderColor: borderColor,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── 4. SAVE CHANGES BUTTON ───────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _onSaveChanges,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark
                                ? const Color(0xFF0D9488)
                                : const Color(0xFF042F2C),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Save Changes',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── 5. DISCARD CHANGES LINK ──────────────────────────────────
                      Center(
                        child: GestureDetector(
                          onTap: () => _showDiscardDialog(isDark),
                          child: Text(
                            'Discard Changes',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: textSecondary,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDisabledField({
    required String value,
    required IconData icon,
    required Color disabledBg,
    required Color textSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: disabledBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(icon, size: 18, color: textSecondary),
        ],
      ),
    );
  }

  Widget _buildEditableField({
    required TextEditingController controller,
    required String hint,
    required Color inputBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
    IconData? prefixIcon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 18, color: textSecondary)
            : null,
        filled: true,
        fillColor: inputBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        errorStyle: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          color: Color(0xFFEF4444),
        ),
      ),
    );
  }
}
