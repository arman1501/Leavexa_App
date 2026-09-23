// ─────────────────────────────────────────────────────────────────────────────
//  settings_screen.dart  –  Faculty Settings Screen
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;

  void _showLogoutDialog(bool isDark) {
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
                  color: isDark ? const Color(0xFF451A1A) : const Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFEF4444),
                  size: 24,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Log Out',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Are you sure you want to log out of your Leavexa account?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
                        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        foregroundColor: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                        side: BorderSide(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Cancel',
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
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRoutes.login,
                          (route) => false,
                        );
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
                        'Yes, Log Out',
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
        final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFB);
        final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
        final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
        final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
        final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
        final dividerColor = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          ),
          child: Scaffold(
            backgroundColor: bgColor,
            appBar: AppBar(
              backgroundColor: bgColor,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: titleColor, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                  letterSpacing: -0.2,
                ),
              ),
              centerTitle: false,
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── PREFERENCES ──────────────────────────────────────────
                    _buildSectionTitle('PREFERENCES', subtitleColor),
                    const SizedBox(height: 8),
                    _buildCardGroup(
                      cardColor: cardColor,
                      borderColor: borderColor,
                      dividerColor: dividerColor,
                      children: [
                        _buildSettingTile(
                          icon: Icons.notifications_none_rounded,
                          iconBgColor: isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5),
                          iconColor: isDark ? const Color(0xFF34D399) : const Color(0xFF0D9488),
                          title: 'Notifications',
                          subtitle: 'Manage leave and application...',
                          titleColor: titleColor,
                          subtitleColor: subtitleColor,
                          trailing: Switch.adaptive(
                            value: _notificationsEnabled,
                            activeTrackColor: isDark ? const Color(0xFF0D9488) : const Color(0xFF042F2C),
                            onChanged: (val) {
                              setState(() => _notificationsEnabled = val);
                              AppHelpers.showSuccess(
                                context,
                                val ? 'Notifications enabled' : 'Notifications disabled',
                              );
                            },
                          ),
                        ),
                        _buildSettingTile(
                          icon: Icons.dark_mode_outlined,
                          iconBgColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                          iconColor: isDark ? const Color(0xFF38BDF8) : const Color(0xFF64748B),
                          title: 'Dark Mode',
                          subtitle: 'Use dark appearance',
                          titleColor: titleColor,
                          subtitleColor: subtitleColor,
                          trailing: Switch.adaptive(
                            value: isDark,
                            activeTrackColor: const Color(0xFF0D9488),
                            onChanged: (val) {
                              AppThemeState.instance.toggleTheme(val);
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // ── SECURITY ─────────────────────────────────────────────
                    _buildSectionTitle('SECURITY', subtitleColor),
                    const SizedBox(height: 8),
                    _buildCardGroup(
                      cardColor: cardColor,
                      borderColor: borderColor,
                      dividerColor: dividerColor,
                      children: [
                        _buildSettingTile(
                          icon: Icons.key_outlined,
                          iconBgColor: isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5),
                          iconColor: isDark ? const Color(0xFF34D399) : const Color(0xFF0D9488),
                          title: 'Change Password',
                          subtitle: 'Update your account password',
                          titleColor: titleColor,
                          subtitleColor: subtitleColor,
                          chevronColor: subtitleColor,
                          onTap: () {
                            AppHelpers.showSuccess(context, 'Change Password opened');
                          },
                        ),
                        _buildSettingTile(
                          icon: Icons.shield_outlined,
                          iconBgColor: isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5),
                          iconColor: isDark ? const Color(0xFF34D399) : const Color(0xFF0D9488),
                          title: 'Privacy & Security',
                          subtitle: 'Manage your privacy and security',
                          titleColor: titleColor,
                          subtitleColor: subtitleColor,
                          chevronColor: subtitleColor,
                          onTap: () {
                            AppHelpers.showSuccess(context, 'Privacy & Security opened');
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // ── SUPPORT ──────────────────────────────────────────────
                    _buildSectionTitle('SUPPORT', subtitleColor),
                    const SizedBox(height: 8),
                    _buildCardGroup(
                      cardColor: cardColor,
                      borderColor: borderColor,
                      dividerColor: dividerColor,
                      children: [
                        _buildSettingTile(
                          icon: Icons.help_outline_rounded,
                          iconBgColor: isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5),
                          iconColor: isDark ? const Color(0xFF34D399) : const Color(0xFF0D9488),
                          title: 'Help & Support',
                          subtitle: 'Get help with Leavexa',
                          titleColor: titleColor,
                          subtitleColor: subtitleColor,
                          chevronColor: subtitleColor,
                          onTap: () {
                            AppHelpers.showSuccess(context, 'Help & Support opened');
                          },
                        ),
                        _buildSettingTile(
                          icon: Icons.info_outline_rounded,
                          iconBgColor: isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5),
                          iconColor: isDark ? const Color(0xFF34D399) : const Color(0xFF0D9488),
                          title: 'About Leavexa',
                          subtitle: 'Version 1.0.0',
                          titleColor: titleColor,
                          subtitleColor: subtitleColor,
                          chevronColor: subtitleColor,
                          onTap: () {
                            AppHelpers.showSuccess(context, 'Leavexa v1.0.0 (Latest)');
                          },
                        ),
                        _buildSettingTile(
                          icon: Icons.article_outlined,
                          iconBgColor: isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5),
                          iconColor: isDark ? const Color(0xFF34D399) : const Color(0xFF0D9488),
                          title: 'Terms & Conditions',
                          titleColor: titleColor,
                          subtitleColor: subtitleColor,
                          chevronColor: subtitleColor,
                          onTap: () {
                            AppHelpers.showSuccess(context, 'Terms & Conditions opened');
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // ── ACCOUNT ──────────────────────────────────────────────
                    _buildSectionTitle('ACCOUNT', subtitleColor),
                    const SizedBox(height: 8),
                    _buildCardGroup(
                      cardColor: cardColor,
                      borderColor: borderColor,
                      dividerColor: dividerColor,
                      children: [
                        _buildSettingTile(
                          icon: Icons.logout_rounded,
                          iconBgColor: isDark ? const Color(0xFF451A1A) : const Color(0xFFFEF2F2),
                          iconColor: const Color(0xFFEF4444),
                          title: 'Logout',
                          titleColor: const Color(0xFFEF4444),
                          chevronColor: const Color(0xFFEF4444),
                          onTap: () => _showLogoutDialog(isDark),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // ── FOOTER ───────────────────────────────────────────────
                    Center(
                      child: Column(
                        children: [
                          Text(
                            'Leavexa Faculty Management Portal',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Academic Year 2024–2025',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildCardGroup({
    required List<Widget> children,
    required Color cardColor,
    required Color borderColor,
    required Color dividerColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: List.generate(children.length, (index) {
          final isLast = index == children.length - 1;
          return Column(
            children: [
              children[index],
              if (!isLast)
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 62,
                  endIndent: 0,
                  color: dividerColor,
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    String? subtitle,
    Color titleColor = const Color(0xFF0F172A),
    Color subtitleColor = const Color(0xFF64748B),
    Color chevronColor = const Color(0xFF94A3B8),
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 19,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing
            else
              Icon(
                Icons.chevron_right_rounded,
                color: chevronColor,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
