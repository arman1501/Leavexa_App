import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Leavexa – Register Screen
//  Pixel-perfect implementation matching the reference UI
// ─────────────────────────────────────────────────────────────────────────────

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameCtrl = TextEditingController();
  final _empIdCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  // Dropdown states
  String? _selectedDept;
  String? _selectedDesignation;

  // Toggle states
  bool _obscurePass = true;
  bool _obscureConfirmPass = true;
  bool _agreeTerms = false;
  bool _isLoading = false;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _rise;

  final List<String> _departments = [
    'Computer Science & Engineering',
    'Electrical & Electronic Engineering',
    'Business Administration',
    'Civil Engineering',
    'Department of Law',
    'Department of Architecture',
    'Department of Public Health',
    'Toursim & Hospitality Management',
    'Department of Islamic Studies',
    'Department of English',
  ];

  final List<String> _designations = [
    'Associate Professor',
    'Assistant Professor',
    'Lecturer',
    'Adjunct Lecturer',
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _rise = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic));
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _nameCtrl.dispose();
    _empIdCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _onRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDept == null || _selectedDesignation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your department and designation'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    if (!_agreeTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the Terms & Privacy Policy'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await AuthService().registerFaculty(
        fullName: _nameCtrl.text,
        employeeId: _empIdCtrl.text,
        email: _emailCtrl.text,
        phone: _phoneCtrl.text,
        departmentName: _selectedDept!,
        designation: _selectedDesignation!,
        password: _passCtrl.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Registration successful! Your account is pending admin approval.',
          ),
          backgroundColor: Color(0xFF1B4332),
        ),
      );

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'This email is already registered.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        case 'weak-password':
          message = 'Password must be at least 6 characters.';
          break;
        case 'network-request-failed':
          message = 'Network error. Please check your internet connection.';
          break;
        default:
          message = e.message ?? 'Registration failed. Please try again.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration failed: $e'),
          backgroundColor: const Color(0xFFDC2626),
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

            // ── MAIN FORM CONTENT ────────────────────────────────────────────
            SafeArea(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  bottom: viewInsetsBottom + bottom + 16,
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
                          const SizedBox(height: 40),

                          // ── HEADING & SUBTITLE ──────────────────────────────
                          const Text(
                            'Create Your Account',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),

                          const SizedBox(height: 4),

                          const Text(
                            'Register as Faculty',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF64748B),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ── FULL NAME ───────────────────────────────────────
                          _InputField(
                            controller: _nameCtrl,
                            hint: 'Full Name',
                            prefixIcon: Icons.person_outline_rounded,
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Please enter your full name'
                                : null,
                          ),

                          const SizedBox(height: 8),

                          // ── EMPLOYEE ID ─────────────────────────────────────
                          _InputField(
                            controller: _empIdCtrl,
                            hint: 'Employee ID',
                            prefixIcon: Icons.badge_outlined,
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Please enter your employee ID'
                                : null,
                          ),

                          const SizedBox(height: 8),

                          // ── UNIVERSITY EMAIL ────────────────────────────────
                          _InputField(
                            controller: _emailCtrl,
                            hint: 'University Email',
                            prefixIcon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Please enter your university email'
                                : null,
                          ),

                          const SizedBox(height: 8),

                          // ── PHONE NUMBER ────────────────────────────────────
                          _InputField(
                            controller: _phoneCtrl,
                            hint: 'Phone Number',
                            prefixIcon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Please enter your phone number'
                                : null,
                          ),

                          const SizedBox(height: 8),

                          // ── DEPARTMENT DROPDOWN ─────────────────────────────
                          _DropdownField(
                            hint: 'Department',
                            prefixIcon: Icons.account_balance_outlined,
                            value: _selectedDept,
                            items: _departments,
                            onChanged: (val) =>
                                setState(() => _selectedDept = val),
                          ),

                          const SizedBox(height: 8),

                          // ── DESIGNATION DROPDOWN ────────────────────
                          _DropdownField(
                            hint: 'Designation',
                            prefixIcon: Icons.work_outline_rounded,
                            value: _selectedDesignation,
                            items: _designations,
                            onChanged: (val) =>
                                setState(() => _selectedDesignation = val),
                          ),

                          const SizedBox(height: 8),

                          // ── PASSWORD ────────────────────────────────
                          _InputField(
                            controller: _passCtrl,
                            hint: 'Password',
                            prefixIcon: Icons.lock_outline_rounded,
                            obscureText: _obscurePass,
                            suffixIcon: GestureDetector(
                              onTap: () => setState(
                                      () => _obscurePass = !_obscurePass),
                              child: Icon(
                                _obscurePass
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 20,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                            validator: (v) => v == null || v.isEmpty
                                ? 'Please enter a password'
                                : null,
                          ),

                          const SizedBox(height: 8),

                          // ── CONFIRM PASSWORD ────────────────────────
                          _InputField(
                            controller: _confirmPassCtrl,
                            hint: 'Confirm Password',
                            prefixIcon: Icons.lock_outline_rounded,
                            obscureText: _obscureConfirmPass,
                            suffixIcon: GestureDetector(
                              onTap: () => setState(() =>
                              _obscureConfirmPass =
                              !_obscureConfirmPass),
                              child: Icon(
                                _obscureConfirmPass
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 20,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Please confirm your password';
                              }
                              if (v != _passCtrl.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 12),

                          // ── TERMS & PRIVACY POLICY CHECKBOX ─────────
                          Row(
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: Checkbox(
                                  value: _agreeTerms,
                                  onChanged: (v) => setState(
                                          () => _agreeTerms = v ?? false),
                                  activeColor: const Color(0xFF1B4332),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(4),
                                  ),
                                  side: const BorderSide(
                                    color: Color(0xFF94A3B8),
                                    width: 1.5,
                                  ),
                                  materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(
                                          () => _agreeTerms = !_agreeTerms),
                                  child: RichText(
                                    text: const TextSpan(
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF64748B),
                                      ),
                                      children: [
                                        TextSpan(
                                            text: 'I agree to the '),
                                        TextSpan(
                                          text: 'Terms & Privacy Policy',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF1B4332),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 38),

                          // ── CREATE ACCOUNT BUTTON ───────────────────
                          _RegisterButton(
                            isLoading: _isLoading,
                            onTap: _onRegister,
                          ),

                          const SizedBox(height: 26),

                          // ── LOGIN LINK ──────────────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Already have an account? ',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: const Text(
                                  'Login',
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
        suffixIconConstraints:
        const BoxConstraints(minWidth: 0, minHeight: 0),
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
//  Reusable Dropdown Field
// ─────────────────────────────────────────────────────────────────────────────
class _DropdownField extends StatelessWidget {
  final String hint;
  final IconData prefixIcon;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _DropdownField({
    required this.hint,
    required this.prefixIcon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      onChanged: onChanged,
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: Color(0xFF94A3B8),
        size: 22,
      ),
      dropdownColor: Colors.white,
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
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF1B4332), width: 1.5),
        ),
      ),
      items: items
          .map((item) => DropdownMenuItem<String>(
        value: item,
        child: Text(item),
      ))
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Register Button with press-scale animation
// ─────────────────────────────────────────────────────────────────────────────
class _RegisterButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback onTap;
  const _RegisterButton({required this.isLoading, required this.onTap});

  @override
  State<_RegisterButton> createState() => _RegisterButtonState();
}

class _RegisterButtonState extends State<_RegisterButton>
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
                : const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Create Account',
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
