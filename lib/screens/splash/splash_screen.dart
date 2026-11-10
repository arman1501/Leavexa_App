import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_strings.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../repositories/auth_repository.dart';

class SplashScreen extends StatefulWidget {
  final AuthRepository? authRepository;

  const SplashScreen({super.key, this.authRepository});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final AuthRepository _authRepository =
      widget.authRepository ?? AuthRepository();
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Pure smooth Fade-in (0.0s – 0.5s)
    _fade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.5 / 1.5, curve: Curves.easeInOut),
    );

    _ctrl.forward();

    _restoreSessionAndNavigate();
  }

  Future<void> _restoreSessionAndNavigate() async {
    UserModel? user;
    try {
      final results = await Future.wait<dynamic>([
        _authRepository.restoreSession(),
        Future<void>.delayed(const Duration(milliseconds: 1200)),
      ]);
      user = results.first as UserModel?;
    } catch (_) {
      // Fails safely on any error (no session, missing profile,
      // invalid role, pending/rejected/inactive, network failure)
      user = null;
    }

    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;

    AppThemeState.instance.resetToLightMode();

    final targetRoute = _determineRoute(user);
    Navigator.pushReplacementNamed(context, targetRoute);
  }

  String _determineRoute(UserModel? user) {
    if (user == null) return AppRoutes.login;

    return switch (user.role) {
      AppStrings.roleFaculty when user.isActiveAndApproved =>
        AppRoutes.facultyDashboard,
      AppStrings.roleDeptHead when user.isActive => AppRoutes.headDashboard,
      AppStrings.roleRegistrar when user.isActive =>
        AppRoutes.registrarDashboard,
      AppStrings.roleAdmin when user.isActive => AppRoutes.adminDashboard,
      _ => AppRoutes.login,
    };
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFFFF),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── TOP-LEFT BLOB ──────────────────────────────────────────────
            // Large pale-green circle peeking from top-left corner
            Positioned(
              top: -size.width * 0.28,
              left: -size.width * 0.28,
              child: _AccentBlob(size: size.width * 0.75),
            ),

            // ── BOTTOM-RIGHT LARGE BLOB ────────────────────────────────────
            // Large pale-green circle peeking from bottom-right corner
            Positioned(
              bottom: -size.width * 0.32,
              right: -size.width * 0.32,
              child: _AccentBlob(size: size.width * 0.85),
            ),

            // ── BOTTOM-RIGHT SMALL DOT ─────────────────────────────────────
            Positioned(
              bottom: size.height * 0.17,
              right: size.width * 0.10,
              child: const _AccentBlob(size: 12),
            ),

            // ── LOGO — centered, shifted slightly above middle ─────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: size.height * 0.18,
              child: Center(
                child: FadeTransition(
                  opacity: _fade,
                  child: Image.asset(
                    'assets/main_logo.png',
                    width: _responsiveLogoWidth(size.width),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),

            // ── TAGLINE — top at 0.48 of screen height ─────────────────────
            Positioned(
              top: size.height * 0.47,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _fade,
                child: const Text(
                  'Smart Faculty Leave Management',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.6,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Accent blob (circle)
// ─────────────────────────────────────────────────────────────────────────────
class _AccentBlob extends StatelessWidget {
  final double size;
  const _AccentBlob({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFD8F3DC).withValues(alpha: 0.60),
        shape: BoxShape.circle,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Responsive logo width

double _responsiveLogoWidth(double screenW) {
  double ratio;
  if (screenW >= 1024) {
    ratio = 0.30; // laptop / desktop
  } else if (screenW >= 600) {
    ratio = 0.50; // tablet
  } else {
    ratio = 0.82; // phone — বড় দেখাবে
  }
  return (screenW * ratio).clamp(200.0, 540.0);
}
