// ─────────────────────────────────────────────────────────────────────────────
//  admin_profile_screen.dart  –  Dedicated Admin / Registrar Profile Screen
//  Role-specific profile for System Administrator with system metrics,
//  administrative controls, dark mode switcher & secure logout.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../widgets/app_bottom_navigation.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  final int _currentNavIndex = 3; // 3: Profile tab active

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
      builder: (context) => AlertDialog(
        title: const Text('Admin Log Out'),
        content: const Text(
          'Are you sure you want to log out of the Administrator Portal?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.login,
                (route) => false,
              );
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
        final dividerColor =
            isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
        final surfaceAlt =
            isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          ),
          child: Scaffold(
            backgroundColor: bgColor,
            body: SafeArea(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                          // Admin Avatar with green online dot
                          Stack(
                            children: [
                              Container(
                                width: 84,
                                height: 84,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF3B82F6)
                                        : const Color(0xFF1B4332),
                                    width: 2.5,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(42),
                                  child: Image.asset(
                                    'assets/images/profile.jpg',
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        Container(
                                      color: const Color(0xFF1B4332),
                                      child: const Center(
                                        child: Text(
                                          'ADM',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 2,
                                right: 4,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF16A34A),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark
                                          ? const Color(0xFF1E293B)
                                          : Colors.white,
                                      width: 2.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // Name
                          Text(
                            'System Administrator',
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
                                      ? const Color(0xFF1E3A8A)
                                          .withValues(alpha: 0.4)
                                      : const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF3B82F6)
                                            .withValues(alpha: 0.4)
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
                            value: '231',
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
                            value: '12',
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
                            value: 'admin@leavexa.edu',
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
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.assignment_outlined,
                                color: Color(0xFFB45309),
                                size: 20,
                              ),
                            ),
                            title: Text(
                              'Teacher Verifications Queue',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              '12 applications waiting for review',
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
                                arguments: {'tab': 1},
                              );
                            },
                          ),
                          Divider(height: 1, color: dividerColor),
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
                              '231 registered faculty members',
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
                          Divider(height: 1, color: dividerColor),
                          ListTile(
                            leading: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.brightness_6_outlined,
                                color: Color(0xFF4F46E5),
                                size: 20,
                              ),
                            ),
                            title: Text(
                              'Theme Appearance',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              isDark ? 'Dark Mode Active' : 'Light Mode Active',
                              style: TextStyle(
                                fontSize: 12,
                                color: textSecondary,
                              ),
                            ),
                            trailing: Switch(
                              value: isDark,
                              activeColor: const Color(0xFF34D399),
                              onChanged: (val) {
                                AppThemeState.instance.toggleTheme(val);
                              },
                            ),
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
