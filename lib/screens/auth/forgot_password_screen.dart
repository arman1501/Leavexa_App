// ─────────────────────────────────────────────────────────────────────────────
//  forgot_password_screen.dart  –  Leavexa Password Reset Screen
//  Preserves the Leavexa design system (colors, typography, animations)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../repositories/auth_repository.dart';
import '../../services/auth_exception.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final AuthRepository? authRepository;

  const ForgotPasswordScreen({super.key, this.authRepository});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isSuccess = false;

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
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _authRepository.forgotPassword(_emailCtrl.text.trim());

      if (!mounted) return;

      setState(() => _isSuccess = true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'If an account exists with this email, a password reset link has been sent. Please check your inbox.',
          ),
          backgroundColor: Color(0xFF1B4332),
          duration: Duration(seconds: 4),
        ),
      );
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
          content: Text('Failed to send reset link. Please try again.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
        body: SafeArea(
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),

                      // ── BACK BUTTON ─────────────────────────────────────────
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── LOGO (CENTERED) ─────────────────────────────────────
                      Center(
                        child: Image.asset(
                          'assets/main_logo.png',
                          width: size.width * 0.55,
                          fit: BoxFit.contain,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── TITLE & SUBTITLE ────────────────────────────────────
                      const Center(
                        child: Text(
                          'Reset Password',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Center(
                        child: Text(
                          'Enter your university email to receive a password reset link.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF64748B),
                            height: 1.4,
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── EMAIL INPUT FIELD ───────────────────────────────────
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(
                          fontSize: 14.5,
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w400,
                        ),
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
                        decoration: InputDecoration(
                          hintText: 'University Email Address',
                          hintStyle: const TextStyle(
                            fontSize: 14.5,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w400,
                          ),
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(left: 16, right: 12),
                            child: Icon(
                              Icons.email_outlined,
                              size: 20,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 0,
                            minHeight: 0,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFF1B4332),
                              width: 1.5,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFDC2626),
                              width: 1,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFDC2626),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── SUBMIT BUTTON ───────────────────────────────────────
                      _ResetButton(
                        isLoading: _isLoading,
                        isSuccess: _isSuccess,
                        onTap: _onSubmit,
                      ),

                      const SizedBox(height: 24),

                      // ── BACK TO LOGIN LINK ──────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Remember your password? ',
                            style: TextStyle(
                              fontSize: 13.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Text(
                              'Back to Login',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1B4332),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Reset Button with press-scale animation
// ─────────────────────────────────────────────────────────────────────────────
class _ResetButton extends StatefulWidget {
  final bool isLoading;
  final bool isSuccess;
  final VoidCallback onTap;

  const _ResetButton({
    required this.isLoading,
    required this.isSuccess,
    required this.onTap,
  });

  @override
  State<_ResetButton> createState() => _ResetButtonState();
}

class _ResetButtonState extends State<_ResetButton>
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
                : Text(
                    widget.isSuccess ? 'Resend Reset Link' : 'Send Reset Link',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
