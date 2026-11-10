// ─────────────────────────────────────────────────────────────────────────────
//  apply_leave_screen.dart  –  Apply for Leave Screen (Dark & Light Theme Aware)
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../models/faculty_profile_state.dart';
import '../../models/leave_application_model.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/leave_repository.dart';
import '../../services/notification_service.dart';
import '../../services/storage_service.dart';

class ApplyLeaveScreen extends StatefulWidget {
  final LeaveRepository? leaveRepository;
  final AuthRepository? authRepository;
  final NotificationService? notificationService;
  final StorageService? storageService;

  const ApplyLeaveScreen({
    super.key,
    this.leaveRepository,
    this.authRepository,
    this.notificationService,
    this.storageService,
  });

  @override
  State<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends State<ApplyLeaveScreen> {
  late final LeaveRepository _leaveRepo =
      widget.leaveRepository ?? LeaveRepository();
  late final AuthRepository _authRepo =
      widget.authRepository ?? AuthRepository();
  late final StorageService _storageService =
      widget.storageService ?? StorageService();

  final _formKey = GlobalKey<FormState>();
  final _reasonCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _emergencyPhoneCtrl = TextEditingController();
  final _arrangementsCtrl = TextEditingController();

  String _selectedLeaveType = 'Casual';
  DateTime _startDate = DateTime.now().add(const Duration(days: 3));
  DateTime _endDate = DateTime.now().add(const Duration(days: 5));
  String? _attachedFileName;
  File? _pickedDocumentFile;
  double _uploadProgress = 0.0;
  bool _isUploadingDocument = false;
  bool _isHalfDay = false;
  bool _isSubmitting = false;

  final Map<String, Map<String, dynamic>> _leaveBalances = {
    'Casual': {'remaining': 6, 'name': 'Casual Leave (CL)'},
    'Medical': {'remaining': 12, 'name': 'Medical Leave (ML)'},
    'Earned': {'remaining': 24, 'name': 'Earned Leave (EL)'},
    'Duty': {'remaining': 4, 'name': 'Duty Leave (DL)'},
    'Station': {'remaining': 2, 'name': 'Station Leave (STL)'},
    'Study': {'remaining': 15, 'name': 'Study Leave (SL)'},
  };

  @override
  void initState() {
    super.initState();
    _loadRealBalances();
  }

  Future<void> _loadRealBalances() async {
    try {
      final user = await _authRepo.getCurrentUserProfile();
      final uid = user?.uid ?? _authRepo.currentUserId;
      if (uid == null) return;
      final balances = await _leaveRepo.balancesForUser(uid);
      if (balances.isNotEmpty && mounted) {
        setState(() {
          for (final b in balances) {
            String key = b.leaveTypeName.split(' ').first;
            if (key == 'Sick') key = 'Medical';
            if (_leaveBalances.containsKey(key)) {
              _leaveBalances[key]!['remaining'] = b.remainingDays;
            }
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _addressCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    _arrangementsCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final isDark = AppThemeState.instance.isDarkMode;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2026, 1, 1),
      lastDate: DateTime(2028, 12, 31),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: Color(0xFF0D9488),
                    onPrimary: Colors.white,
                    surface: Color(0xFF1E293B),
                    onSurface: Color(0xFFF8FAFC),
                  )
                : const ColorScheme.light(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                    onSurface: Color(0xFF0F172A),
                  ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate.add(const Duration(days: 1));
          }
        } else {
          if (picked.isBefore(_startDate)) {
            AppHelpers.showError(
              context,
              'End date cannot be before start date',
            );
            return;
          }
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _onPickDocument() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      );

      if (result.isNotEmpty && result.first.path != null) {
        final file = File(result.first.path!);
        final size = await file.length();

        if (size > StorageService.maxDocumentSizeBytes) {
          if (mounted) {
            AppHelpers.showError(
              context,
              'Selected document exceeds the maximum allowed size of 10 MB.',
            );
          }
          return;
        }

        setState(() {
          _pickedDocumentFile = file;
          _attachedFileName = result.first.name;
        });

        if (mounted) {
          AppHelpers.showSuccess(
            context,
            'Document selected: ${result.first.name}',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppHelpers.showError(context, 'Failed to select document: $e');
      }
    }
  }

  void _onRemoveAttachment() {
    setState(() {
      _pickedDocumentFile = null;
      _attachedFileName = null;
      _uploadProgress = 0.0;
      _isUploadingDocument = false;
    });
  }

  void _onSaveDraft() {
    AppHelpers.showSuccess(context, 'Application saved as draft');
  }

  Future<void> _onSubmitApplication() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) {
      AppHelpers.showError(
        context,
        'Please fill in required fields correctly!',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = await _authRepo.getCurrentUserProfile();
      final applicantUid =
          user?.uid ?? _authRepo.currentUserId ?? 'unknown_uid';
      final applicantName =
          user?.fullName ??
          FacultyProfileState.instance.notifier.value.fullName;
      final applicantEmpId =
          user?.employeeId ??
          FacultyProfileState.instance.notifier.value.employeeId;
      final deptId =
          user?.departmentId ??
          FacultyProfileState.instance.notifier.value.department
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]+'), '_');
      final deptName =
          user?.departmentName ??
          FacultyProfileState.instance.notifier.value.department;

      String? documentUrl;
      if (_pickedDocumentFile != null) {
        setState(() {
          _isUploadingDocument = true;
          _uploadProgress = 0.05;
        });

        try {
          final tempAppId = 'app_${DateTime.now().millisecondsSinceEpoch}';
          final uploadRes = await _storageService.uploadLeaveDocument(
            uid: applicantUid,
            applicationId: tempAppId,
            file: _pickedDocumentFile!,
            onProgress: (p) {
              if (mounted) setState(() => _uploadProgress = p);
            },
          );
          documentUrl = uploadRes.downloadUrl;
        } catch (e) {
          if (mounted) {
            setState(() {
              _isSubmitting = false;
              _isUploadingDocument = false;
            });
            AppHelpers.showError(
              context,
              'Document upload failed: $e. Please check your network and retry.',
            );
          }
          return;
        }
      }

      final application = LeaveApplicationModel(
        id: '',
        applicantUid: applicantUid,
        applicantName: applicantName,
        applicantEmployeeId: applicantEmpId,
        departmentId: deptId,
        departmentName: deptName,
        leaveTypeId: _selectedLeaveType.toLowerCase(),
        leaveTypeName: '$_selectedLeaveType Leave',
        startDate: _startDate,
        endDate: _endDate,
        totalDays: _calculateWorkingDays,
        reason: _reasonCtrl.text.trim(),
        documentUrl: documentUrl,
        status: 'pending',
        appliedAt: DateTime.now(),
      );

      await _leaveRepo.applyLeave(application);

      if (!mounted) return;
      AppHelpers.showSuccess(
        context,
        'Leave application submitted for approval!',
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      AppHelpers.showError(context, 'Failed to submit leave application: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  int get _calculateWorkingDays {
    final difference = _endDate.difference(_startDate).inDays + 1;
    return difference > 0 ? difference : 1;
  }

  @override
  Widget build(BuildContext context) {
    final currentBalance =
        _leaveBalances[_selectedLeaveType] ?? _leaveBalances['Casual']!;
    final workingDays = _calculateWorkingDays;
    final dateFormat = DateFormat('MM/dd/yyyy');

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
        final primaryColor = isDark
            ? const Color(0xFF0D9488)
            : AppColors.primary;
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
            body: SafeArea(
              child: Column(
                children: [
                  // ── 1. TOP HEADER ──────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: cardBg,
                              border: Border.all(color: borderColor),
                            ),
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 18,
                              color: textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Apply for Leave',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                'Faculty Portal',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: _onSaveDraft,
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: cardBg,
                              border: Border.all(color: borderColor),
                            ),
                            child: Icon(
                              Icons.bookmark_outline_rounded,
                              size: 20,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── MAIN SCROLLABLE FORM ───────────────────────────────────────
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── 2. LEAVE BALANCE BANNER CARD ────────────────────
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: borderColor),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF064E3B)
                                          : const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.calendar_month_rounded,
                                      color: Color(0xFF16A34A),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'LEAVE BALANCE',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: textSecondary,
                                            letterSpacing: 0.6,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          currentBalance['name'] as String,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF064E3B)
                                          : const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${currentBalance['remaining']} days remaining',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF16A34A),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // ── 3. LEAVE TYPE SELECTION ─────────────────────────
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'Leave Type ',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const TextSpan(
                                        text: '*',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFFDC2626),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  'Select one',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: [
                                  _LeaveTypeCard(
                                    title: 'Casual',
                                    subtitle: '6d left',
                                    isSelected: _selectedLeaveType == 'Casual',
                                    isDark: isDark,
                                    onTap: () => setState(
                                      () => _selectedLeaveType = 'Casual',
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _LeaveTypeCard(
                                    title: 'Medical',
                                    subtitle: '12d left',
                                    isSelected: _selectedLeaveType == 'Medical',
                                    isDark: isDark,
                                    onTap: () => setState(
                                      () => _selectedLeaveType = 'Medical',
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _LeaveTypeCard(
                                    title: 'Earned',
                                    subtitle: '24d left',
                                    isSelected: _selectedLeaveType == 'Earned',
                                    isDark: isDark,
                                    onTap: () => setState(
                                      () => _selectedLeaveType = 'Earned',
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _LeaveTypeCard(
                                    title: 'Duty',
                                    subtitle: '4d left',
                                    isSelected: _selectedLeaveType == 'Duty',
                                    isDark: isDark,
                                    onTap: () => setState(
                                      () => _selectedLeaveType = 'Duty',
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _LeaveTypeCard(
                                    title: 'Station',
                                    subtitle: '2d left',
                                    isSelected: _selectedLeaveType == 'Station',
                                    isDark: isDark,
                                    onTap: () => setState(
                                      () => _selectedLeaveType = 'Station',
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _LeaveTypeCard(
                                    title: 'Study',
                                    subtitle: '15d left',
                                    isSelected: _selectedLeaveType == 'Study',
                                    isDark: isDark,
                                    onTap: () => setState(
                                      () => _selectedLeaveType = 'Study',
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // ── 4. DATE SELECTION & DURATION CARD ───────────────
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: borderColor),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      // Start Date
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            RichText(
                                              text: TextSpan(
                                                children: [
                                                  TextSpan(
                                                    text: 'Start Date ',
                                                    style: TextStyle(
                                                      fontSize: 12.5,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: textPrimary,
                                                    ),
                                                  ),
                                                  const TextSpan(
                                                    text: '*',
                                                    style: TextStyle(
                                                      fontSize: 12.5,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Color(0xFFDC2626),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            GestureDetector(
                                              onTap: () =>
                                                  _selectDate(context, true),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 10,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: bgColor,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: borderColor,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      dateFormat.format(
                                                        _startDate,
                                                      ),
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: textPrimary,
                                                      ),
                                                    ),
                                                    Icon(
                                                      Icons
                                                          .calendar_today_rounded,
                                                      size: 16,
                                                      color: textSecondary,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // End Date
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            RichText(
                                              text: TextSpan(
                                                children: [
                                                  TextSpan(
                                                    text: 'End Date ',
                                                    style: TextStyle(
                                                      fontSize: 12.5,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: textPrimary,
                                                    ),
                                                  ),
                                                  const TextSpan(
                                                    text: '*',
                                                    style: TextStyle(
                                                      fontSize: 12.5,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Color(0xFFDC2626),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            GestureDetector(
                                              onTap: () =>
                                                  _selectDate(context, false),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 10,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: bgColor,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: borderColor,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      dateFormat.format(
                                                        _endDate,
                                                      ),
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: textPrimary,
                                                      ),
                                                    ),
                                                    Icon(
                                                      Icons
                                                          .calendar_today_rounded,
                                                      size: 16,
                                                      color: textSecondary,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 12),
                                  Divider(height: 1, color: borderColor),
                                  const SizedBox(height: 10),

                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Checkbox(
                                            value: _isHalfDay,
                                            activeColor: primaryColor,
                                            onChanged: (val) {
                                              setState(
                                                () => _isHalfDay = val ?? false,
                                              );
                                            },
                                          ),
                                          Text(
                                            'Half Day Leave',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                              color: textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? const Color(0xFF064E3B)
                                              : const Color(0xFFDCFCE7),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          'Total: $workingDays Working Day${workingDays > 1 ? 's' : ''}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF16A34A),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // ── 5. REASON FOR LEAVE ─────────────────────────────
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Reason for Leave ',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                    ),
                                  ),
                                  const TextSpan(
                                    text: '*',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _reasonCtrl,
                              maxLines: 3,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: textPrimary,
                              ),
                              decoration: InputDecoration(
                                hintText:
                                    'Please state detailed official or personal reason...',
                                hintStyle: TextStyle(
                                  color: textSecondary,
                                  fontSize: 13,
                                ),
                                filled: true,
                                fillColor: inputBg,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: borderColor),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: primaryColor,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Reason is required';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 20),

                            // ── 6. ATTACHMENT DOCUMENT ──────────────────────────
                            Text(
                              'Supporting Documents (Optional)',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: _onPickDocument,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFF334155)
                                                : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            _attachedFileName != null
                                                ? Icons.file_present_rounded
                                                : Icons.cloud_upload_outlined,
                                            color: primaryColor,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _attachedFileName ??
                                                    'Upload Medical Certificate or Proof',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: textPrimary,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _attachedFileName != null
                                                    ? 'Document ready for submission'
                                                    : 'PDF, PNG, JPG up to 10MB',
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  color: textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (_attachedFileName != null && !_isSubmitting)
                                          IconButton(
                                            icon: const Icon(Icons.close_rounded, size: 18),
                                            color: textSecondary,
                                            tooltip: 'Remove document',
                                            onPressed: _onRemoveAttachment,
                                          ),
                                      ],
                                    ),
                                    if (_isUploadingDocument) ...[
                                      const SizedBox(height: 8),
                                      LinearProgressIndicator(
                                        value: _uploadProgress > 0 ? _uploadProgress : null,
                                        backgroundColor: borderColor,
                                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                                        minHeight: 4,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // ── 7. SUBMIT BUTTON ────────────────────────────────
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isSubmitting ? null : _onSubmitApplication,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: _isSubmitting
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.send_rounded,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Submit Leave Application',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),

                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LeaveTypeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _LeaveTypeCard({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final primaryColor = isDark
        ? const Color(0xFF0D9488)
        : const Color(0xFF1B4332);
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final textPrimary = isDark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF0F172A);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 124,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: activeBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? primaryColor : borderColor,
            width: isSelected ? 2 : 1,
          ),
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
                      fontSize: 13.5,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? primaryColor
                          : (isDark
                                ? const Color(0xFF64748B)
                                : const Color(0xFFCBD5E1)),
                      width: isSelected ? 4.5 : 1.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF16A34A)
                    : (isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF94A3B8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
