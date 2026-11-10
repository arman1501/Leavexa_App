import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_strings.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../repositories/auth_repository.dart';
import '../../services/auth_exception.dart';
import 'register_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Leavexa – Login Screen
//  Matches the reference design pixel-perfectly
// ─────────────────────────────────────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  final AuthRepository? authRepository;

  const LoginScreen({super.key, this.authRepository});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _rememberMe = false;

  late final AuthRepository _authRepository =
      widget.authRepository ?? AuthRepository();

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _rise;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _rise = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic));
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (_isLoading || _isGoogleLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = await _authRepository.loginAndGetProfile(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );

      if (!mounted) return;

      AppThemeState.instance.resetToLightMode();

      final route = switch (user.role) {
        AppStrings.roleFaculty => AppRoutes.facultyDashboard,
        AppStrings.roleDeptHead => AppRoutes.headDashboard,
        AppStrings.roleRegistrar => AppRoutes.registrarDashboard,
        AppStrings.roleAdmin => AppRoutes.adminDashboard,
        _ => null,
      };

      if (route != null) {
        Navigator.pushReplacementNamed(context, route);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid role assigned to this account.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login failed. Please try again.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onGoogleSignIn() async {
    if (_isLoading || _isGoogleLoading) return;

    setState(() => _isGoogleLoading = true);

    try {
      final user = await _authRepository.signInWithGoogle();

      if (!mounted) return;

      AppThemeState.instance.resetToLightMode();

      final route = switch (user.role) {
        AppStrings.roleFaculty => AppRoutes.facultyDashboard,
        AppStrings.roleDeptHead => AppRoutes.headDashboard,
        AppStrings.roleRegistrar => AppRoutes.registrarDashboard,
        AppStrings.roleAdmin => AppRoutes.adminDashboard,
        _ => null,
      };

      if (route != null) {
        Navigator.pushReplacementNamed(context, route);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid role assigned to this account.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;

      if (e.code == AuthErrorCode.googleSignInCancelled) {
        // User voluntarily cancelled the picker
        return;
      }

      if (e.code == AuthErrorCode.googleNoAccount) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: const Color(0xFF1B4332),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Register',
              textColor: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                );
              },
            ),
          ),
        );
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RegisterScreen()),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google Sign-In failed. Please try again.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottom = MediaQuery.of(context).padding.bottom;
    final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: const Color(0xFFFFFFFF),
        body: Stack(
          children: [
            // ── TOP-RIGHT ACCENT BLOB ────────────────────────────────────────
            // Positioned(
            //   top: -size.width * 0.18,
            //   right: -size.width * 0.18,
            //   child: Container(
            //     width: size.width * 0.55,
            //     height: size.width * 0.55,
            //     decoration: BoxDecoration(
            //       color: const Color(0xFFD8F3DC).withValues(alpha: 0.60),
            //       shape: BoxShape.circle,
            //     ),
            //   ),
            // ),

            // ── MAIN CONTENT ─────────────────────────────────────────────────
            SafeArea(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  bottom: viewInsetsBottom + bottom + 24,
                ),
                child: FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _rise,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 0), // Top layout fixed
                          // ── LOGO (MOVED DOWN CLOSER TO WELCOME) ────────────
                          Transform.translate(
                            offset: const Offset(
                              0,
                              30,
                            ), // Move ONLY logo down closer to Welcome
                            child: Image.asset(
                              'assets/main_logo.png',
                              width: size.width * 0.70,
                              fit: BoxFit.contain,
                            ),
                          ),

                          const SizedBox(height: 1),

                          // ── WELCOME HEADING & SUBTITLE (SHIFTED 20px HIGHER UP) ──
                          Transform.translate(
                            offset: const Offset(0, -20), // 20px higher up
                            child: const Column(
                              children: [
                                Text(
                                  'Welcome Back',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Sign in to continue to Leavexa',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 6),

                          // ── EMAIL FIELD ────────────────────────────────────
                          _InputField(
                            controller: _emailCtrl,
                            hint: 'Email Address / Employee ID',
                            prefixIcon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Please enter your email';
                              }
                              final regex = RegExp(
                                r'^[\w.-]+@[\w-]+\.[a-z]{2,}$',
                                caseSensitive: false,
                              );
                              if (!regex.hasMatch(v.trim())) {
                                return 'Enter a valid email address.';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(
                            height: 12,
                          ), // 4. Email to Password gap
                          // ── PASSWORD FIELD ─────────────────────────────────
                          _InputField(
                            controller: _passCtrl,
                            hint: 'Password',
                            prefixIcon: Icons.lock_outline_rounded,
                            obscureText: _obscurePass,
                            suffixIcon: GestureDetector(
                              onTap: () =>
                                  setState(() => _obscurePass = !_obscurePass),
                              child: Icon(
                                _obscurePass
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 20,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Please enter your password';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 10),

                          // ── REMEMBER ME & FORGOT PASSWORD ──────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _rememberMe = !_rememberMe),
                                behavior: HitTestBehavior.opaque,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: Checkbox(
                                        value: _rememberMe,
                                        onChanged: (v) => setState(
                                          () => _rememberMe = v ?? false,
                                        ),
                                        activeColor: const Color(0xFF1B4332),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        side: const BorderSide(
                                          color: Color(0xFF94A3B8),
                                          width: 1.5,
                                        ),
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Remember me',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.forgotPassword,
                                  );
                                },
                                child: const Text(
                                  'Forgot Password?',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1B4332),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                            height: 20,
                          ), // 5. Checkbox to Login Button gap
                          // ── LOGIN BUTTON ───────────────────────────────────
                          _LoginButton(isLoading: _isLoading, onTap: _onLogin),

                          const SizedBox(
                            height: 16,
                          ), // 6. Login Button to OR Divider gap
                          // ── OR DIVIDER ─────────────────────────────────────
                          const Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: Color(0xFFE2E8F0),
                                  thickness: 1,
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'OR',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF94A3B8),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: Color(0xFFE2E8F0),
                                  thickness: 1,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // ── GOOGLE SIGN-IN BUTTON ──────────────────────────
                          _GoogleSignInButton(
                            isLoading: _isGoogleLoading,
                            onTap: _onGoogleSignIn,
                          ),

                          const SizedBox(height: 26),

                          // ── REGISTER LINK ──────────────────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "Don't have an account? ",
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const RegisterScreen(),
                                    ),
                                  );
                                },
                                child: const Text(
                                  'Register',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1B4332),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
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
//  Reusable Input Field
// ─────────────────────────────────────────────────────────────────────────────
class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(
        fontSize: 14.5,
        color: Color(0xFF0F172A),
        fontWeight: FontWeight.w400,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontSize: 14.5,
          color: Color(0xFF94A3B8),
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 12),
          child: Icon(prefixIcon, size: 20, color: const Color(0xFF94A3B8)),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: suffixIcon != null
            ? Padding(
                padding: const EdgeInsets.only(right: 14),
                child: suffixIcon,
              )
            : null,
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF1B4332), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Login Button with press-scale animation
// ─────────────────────────────────────────────────────────────────────────────
class _LoginButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback onTap;
  const _LoginButton({required this.isLoading, required this.onTap});

  @override
  State<_LoginButton> createState() => _LoginButtonState();
}

class _LoginButtonState extends State<_LoginButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    lowerBound: 0.96,
    upperBound: 1.0,
    value: 1.0,
    duration: const Duration(milliseconds: 100),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.reverse(),
      onTapUp: (_) {
        _ctrl.forward();
        if (!widget.isLoading) widget.onTap();
      },
      onTapCancel: () => _ctrl.forward(),
      child: ScaleTransition(
        scale: _ctrl,
        child: Container(
          height: 58,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF1B4332),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Login',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Google Sign-In Button
// ─────────────────────────────────────────────────────────────────────────────
class _GoogleSignInButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isLoading;
  const _GoogleSignInButton({required this.onTap, this.isLoading = false});

  @override
  State<_GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<_GoogleSignInButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    lowerBound: 0.96,
    upperBound: 1.0,
    value: 1.0,
    duration: const Duration(milliseconds: 100),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.reverse(),
      onTapUp: (_) {
        _ctrl.forward();
        if (!widget.isLoading) widget.onTap();
      },
      onTapCancel: () => _ctrl.forward(),
      child: ScaleTransition(
        scale: _ctrl,
        child: Container(
          height: 56,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          ),
          child: widget.isLoading
              ? const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Color(0xFF1B4332),
                      strokeWidth: 2.5,
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/icons/google.png',
                      width: 22,
                      height: 22,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Continue with Google',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
