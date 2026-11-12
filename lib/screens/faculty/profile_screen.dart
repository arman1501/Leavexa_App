// ─────────────────────────────────────────────────────────────────────────────
//  profile_screen.dart  –  Faculty Profile Screen (Dark & Light Theme Aware)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../models/faculty_profile_state.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_bottom_navigation.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _currentNavIndex = 3; // 3: Profile tab active

  void _onBottomNavTap(int index) {
    if (index == _currentNavIndex) return;
    setState(() => _currentNavIndex = index);
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, AppRoutes.facultyDashboard);
        break;
      case 1:
        Navigator.pushReplacementNamed(context, AppRoutes.myLeaves);
        break;
      case 2:
        Navigator.pushReplacementNamed(context, AppRoutes.notifications);
        break;
      case 3:
        break;
    }
  }

  void _onCopyEmployeeNumber() {
    final employeeId = FacultyProfileState.instance.notifier.value.employeeId;
    Clipboard.setData(ClipboardData(text: employeeId));
    AppHelpers.showSuccess(context, 'Employee ID copied to clipboard');
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
        final dividerColor = isDark
            ? const Color(0xFF334155)
            : const Color(0xFFF1F5F9);
        final surfaceAlt = isDark
            ? const Color(0xFF334155)
            : const Color(0xFFF1F5F9);
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
              child: Column(
                children: [
                  // ── MAIN SCROLLABLE CONTENT ────────────────────────────────────
                  Expanded(
                    child: ValueListenableBuilder<FacultyProfileData>(
                      valueListenable: FacultyProfileState.instance.notifier,
                      builder: (context, profileData, child) {
                        return SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── 1. TOP HEADER ──────────────────────────────────────
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Profile Faculty',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => Navigator.pushNamed(
                                      context,
                                      AppRoutes.settings,
                                    ),
                                    child: Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: surfaceAlt,
                                        border: Border.all(color: borderColor),
                                      ),
                                      child: Icon(
                                        Icons.settings_outlined,
                                        size: 18,
                                        color: textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 18),

                              // ── 2. SUB-HEADER (ACADEMIC RECORD) ─────────────────────
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ACADEMIC RECORD',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: textSecondary,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Faculty Portal ID • Active Session',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                      color: textSecondary,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 14),

                              // ── 3. PROFILE MAIN CARD ───────────────────────────────
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: borderColor),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isDark
                                          ? const Color(0x33000000)
                                          : const Color(0x05000000),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Avatar with online dot
                                        Stack(
                                          children: [
                                            AppAvatar(
                                              name: profileData.fullName,
                                              photoUrl: profileData.photoUrl,
                                              size: 68,
                                            ),
                                            Positioned(
                                              bottom: 2,
                                              right: 2,
                                              child: Container(
                                                width: 14,
                                                height: 14,
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFF16A34A,
                                                  ),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: isDark
                                                        ? const Color(
                                                            0xFF1E293B,
                                                          )
                                                        : Colors.white,
                                                    width: 2,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 14),
                                        // Name & Details
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                profileData.fullName,
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w700,
                                                  color: textPrimary,
                                                  letterSpacing: -0.3,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                profileData.designation,
                                                style: const TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF16A34A),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                profileData.department,
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w500,
                                                  color: textSecondary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: isDark
                                                      ? const Color(0xFF064E3B)
                                                      : const Color(0xFFDCFCE7),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  'ID: #${profileData.employeeId}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF16A34A),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    // Edit Profile Button
                                    GestureDetector(
                                      onTap: () => Navigator.pushNamed(
                                        context,
                                        AppRoutes.editProfile,
                                      ),
                                      child: Container(
                                        width: double.infinity,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: surfaceAlt,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.edit_outlined,
                                              size: 16,
                                              color: primaryColor,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Edit Profile',
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w700,
                                                color: primaryColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 22),

                              // ── 4. ACADEMIC & PERSONAL DETAILS SECTION ────────────────
                              Text(
                                'ACADEMIC & PERSONAL DETAILS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: textSecondary,
                                  letterSpacing: 0.8,
                                ),
                              ),

                              const SizedBox(height: 10),

                              Container(
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: borderColor),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isDark
                                          ? const Color(0x33000000)
                                          : const Color(0x05000000),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    _InfoTile(
                                      icon: Icons.badge_outlined,
                                      label: 'Employee ID',
                                      value: profileData.employeeId,
                                      isDark: isDark,
                                      textPrimary: textPrimary,
                                      textSecondary: textSecondary,
                                      surfaceAlt: surfaceAlt,
                                      trailing: GestureDetector(
                                        onTap: _onCopyEmployeeNumber,
                                        child: Icon(
                                          Icons.content_copy_rounded,
                                          size: 18,
                                          color: textSecondary,
                                        ),
                                      ),
                                    ),
                                    Divider(height: 1, color: dividerColor),
                                    _InfoTile(
                                      icon: Icons.email_outlined,
                                      label: 'University Email',
                                      value: profileData.email,
                                      isDark: isDark,
                                      textPrimary: textPrimary,
                                      textSecondary: textSecondary,
                                      surfaceAlt: surfaceAlt,
                                      trailing: IconButton(
                                        tooltip: 'Copy Email',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: profileData.email.trim().isEmpty
                                            ? null
                                            : () async {
                                                await Clipboard.setData(
                                                  ClipboardData(
                                                    text: profileData.email.trim(),
                                                  ),
                                                );
                                                if (context.mounted) {
                                                  AppHelpers.showSuccess(
                                                    context,
                                                    'Email copied to clipboard',
                                                  );
                                                }
                                              },
                                        icon: Icon(
                                          Icons.copy_rounded,
                                          size: 18,
                                          color: textSecondary,
                                        ),
                                      ),
                                    ),
                                    Divider(height: 1, color: dividerColor),
                                    _InfoTile(
                                      icon: Icons.phone_outlined,
                                      label: 'Phone Number',
                                      value: profileData.phone,
                                      isDark: isDark,
                                      textPrimary: textPrimary,
                                      textSecondary: textSecondary,
                                      surfaceAlt: surfaceAlt,
                                      trailing: IconButton(
                                        tooltip: 'Copy Phone Number',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: profileData.phone.trim().isEmpty
                                            ? null
                                            : () async {
                                                await Clipboard.setData(
                                                  ClipboardData(
                                                    text: profileData.phone.trim(),
                                                  ),
                                                );
                                                if (context.mounted) {
                                                  AppHelpers.showSuccess(
                                                    context,
                                                    'Phone number copied to clipboard',
                                                  );
                                                }
                                              },
                                        icon: Icon(
                                          Icons.copy_rounded,
                                          size: 18,
                                          color: textSecondary,
                                        ),
                                      ),
                                    ),
                                    Divider(height: 1, color: dividerColor),
                                    _InfoTile(
                                      icon: Icons.account_balance_outlined,
                                      label: 'Department',
                                      value: profileData.department,
                                      isDark: isDark,
                                      textPrimary: textPrimary,
                                      textSecondary: textSecondary,
                                      surfaceAlt: surfaceAlt,
                                    ),
                                    Divider(height: 1, color: dividerColor),
                                    _InfoTile(
                                      icon: Icons.school_outlined,
                                      label: 'Designation',
                                      value: profileData.designation,
                                      isDark: isDark,
                                      textPrimary: textPrimary,
                                      textSecondary: textSecondary,
                                      surfaceAlt: surfaceAlt,
                                    ),
                                    Divider(height: 1, color: dividerColor),
                                    _InfoTile(
                                      icon: Icons.door_front_door_outlined,
                                      label: 'Assigned Faculty Office',
                                      value: profileData.office,
                                      isDark: isDark,
                                      textPrimary: textPrimary,
                                      textSecondary: textSecondary,
                                      surfaceAlt: surfaceAlt,
                                    ),
                                    Divider(height: 1, color: dividerColor),
                                    _InfoTile(
                                      icon: Icons.calendar_today_outlined,
                                      label: 'Appointment Date',
                                      value: profileData.appointmentDate,
                                      isDark: isDark,
                                      textPrimary: textPrimary,
                                      textSecondary: textSecondary,
                                      surfaceAlt: surfaceAlt,
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 12),

                              // ── VERIFIED FOOTER BADGE ───────────────────────────────
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.verified_outlined,
                                    size: 16,
                                    color: textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Faculty ID verified by Registrar Office',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: textSecondary,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: AppBottomNavigation(
              currentIndex: _currentNavIndex,
              role: 'faculty',
              onTap: _onBottomNavTap,
            ),
          ),
        );
      },
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final Color textPrimary;
  final Color textSecondary;
  final Color surfaceAlt;
  final Widget? trailing;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    required this.textPrimary,
    required this.textSecondary,
    required this.surfaceAlt,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: textSecondary, size: 18),
          ),
          const SizedBox(width: 12),
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
                const SizedBox(height: 1),
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
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
