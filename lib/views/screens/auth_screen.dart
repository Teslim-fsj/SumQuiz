import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import 'package:sumquiz/services/auth_service.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/utils/auth_error_messages.dart';
import 'package:sumquiz/theme/web_theme.dart';

enum AuthMode { login, signUp }

class AuthScreen extends StatefulWidget {
  final String? redirectPath;
  const AuthScreen({super.key, this.redirectPath});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _referralCodeController = TextEditingController();

  AuthMode _authMode = AuthMode.login;
  UserRole _signUpRole = UserRole.student;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _showReferralField = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  void _switchAuthMode(AuthMode mode) {
    if (_authMode == mode) return;
    setState(() {
      _authMode = mode;
      _formKey.currentState?.reset();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;

    setState(() => _isLoading = true);
    final theme = Theme.of(context);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (_authMode == AuthMode.login) {
        await authService.signInWithEmailAndPassword(
          context,
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
        if (!mounted) return;
        _navigateAfterAuth();
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('intended_role', _signUpRole.name);

        await authService.signUpWithEmailAndPassword(
          context,
          _emailController.text.trim(),
          _passwordController.text.trim(),
          _fullNameController.text.trim(),
          _referralCodeController.text.trim(),
        );
        if (!mounted) return;
        _navigateAfterAuth();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(theme, messageForFirebaseAuth(e));
    } catch (e) {
      if (mounted) _showError(theme, messageForAuthFailure(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _googleSignIn() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    final theme = Theme.of(context);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('intended_role', _signUpRole.name);

      await authService.signInWithGoogle(
        context,
        referralCode: _referralCodeController.text.trim(),
      );

      if (!mounted) return;
      _navigateAfterAuth();
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(theme, messageForFirebaseAuth(e));
    } catch (e) {
      if (mounted) _showError(theme, messageForAuthFailure(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateAfterAuth() {
    if (widget.redirectPath != null && widget.redirectPath!.isNotEmpty) {
      context.go(widget.redirectPath!);
    } else {
      context.go('/');
    }
  }

  void _showForgotPasswordDialog() {
    final resetEmailController =
        TextEditingController(text: _emailController.text.trim());
    bool isResetting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Reset Password',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter your email address and we will send you a link to reset your password.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: resetEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ),
              ElevatedButton(
                onPressed: isResetting
                    ? null
                    : () async {
                        final email = resetEmailController.text.trim();
                        if (email.isEmpty) return;
                        setDialogState(() => isResetting = true);
                        try {
                          await FirebaseAuth.instance
                              .sendPasswordResetEmail(email: email);
                          if (!context.mounted) return;
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password reset email sent! Check your inbox.'),
                              backgroundColor: Color(0xFF10B981),
                            ),
                          );
                        } catch (e) {
                          setDialogState(() => isResetting = false);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: ${e.toString()}'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: WebColors.purplePrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: isResetting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Send Reset Link'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showError(ThemeData theme, String message) {
    if (!mounted || message.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 960;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D1A) : const Color(0xFFF8FAFC),
      body: Center(
        child: isDesktop
            ? Container(
                constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 720),
                margin: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.05),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Left: Value Proposition / Feature Showcase
                    Expanded(flex: 5, child: _buildBrandingShowcase(isDark)),
                    // Divider
                    Container(
                      width: 1,
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    ),
                    // Right: Clean Form
                    Expanded(
                      flex: 6,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
                        child: _buildFormContent(theme, isDark),
                      ),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      children: [
                        _buildMobileBrandHeader(isDark),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: _buildFormContent(theme, isDark),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // ─── Left Branding Showcase on Desktop ───────────────────────────────────────

  Widget _buildBrandingShowcase(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF090D1A) : const Color(0xFFFAFAFE),
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo & Title
          Row(
            children: [
              Image.asset(
                'assets/images/sumquiz_logo.png',
                width: 36,
                height: 36,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.school_rounded,
                  color: WebColors.purplePrimary,
                  size: 36,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'SumQuiz',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),

          // Main Tagline
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The Intelligent Study & Teaching OS.',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  height: 1.15,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Turn raw textbooks, lecture slides, and notes into active recall flashcards, quizzes, and print-ready exams in seconds.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF64748B),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 28),

              _featureBullet('⚡ Instant Deep Synthesis from PDFs & YouTube', isDark),
              const SizedBox(height: 12),
              _featureBullet('🧠 Spaced Repetition (SRS) for 10x long-term retention', isDark),
              const SizedBox(height: 12),
              _featureBullet('🎓 Teacher Question Analytics & Printable Exam Papers', isDark),
            ],
          ),

          // Trust Badge / Quote
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Trusted by over 50,000 students & educators worldwide.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureBullet(String text, bool isDark) {
    return Row(
      children: [
        const Icon(Icons.check_circle_rounded, color: WebColors.purplePrimary, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileBrandHeader(bool isDark) {
    return Column(
      children: [
        Image.asset(
          'assets/images/sumquiz_logo.png',
          width: 44,
          height: 44,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.school_rounded,
            color: WebColors.purplePrimary,
            size: 44,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'SumQuiz',
          style: GoogleFonts.outfit(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'AI-Powered Study & Teaching Suite',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  // ─── Main Form Content ───────────────────────────────────────────────────────

  Widget _buildFormContent(ThemeData theme, bool isDark) {
    final isLogin = _authMode == AuthMode.login;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Tab Toggle (Sign In / Create Account)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF090D1A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _tabButton(
                    title: 'Sign In',
                    isSelected: isLogin,
                    onTap: () => _switchAuthMode(AuthMode.login),
                    isDark: isDark,
                  ),
                ),
                Expanded(
                  child: _tabButton(
                    title: 'Create Account',
                    isSelected: !isLogin,
                    onTap: () => _switchAuthMode(AuthMode.signUp),
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Title & Subtitle
          Text(
            isLogin ? 'Welcome back' : 'Get started for free',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isLogin
                ? 'Enter your credentials to access your study library.'
                : 'Create your account to start generating study packs.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 24),

          // Role Switcher on Sign Up
          if (!isLogin) ...[
            Text(
              'I AM JOINING AS',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _roleCard(
                    title: 'Student / Learner',
                    icon: Icons.school_rounded,
                    isSelected: _signUpRole == UserRole.student,
                    onTap: () => setState(() => _signUpRole = UserRole.student),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _roleCard(
                    title: 'Teacher / Educator',
                    icon: Icons.workspace_premium_rounded,
                    isSelected: _signUpRole == UserRole.creator,
                    onTap: () => setState(() => _signUpRole = UserRole.creator),
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],

          // Google Button
          _buildGoogleButton(isDark),
          const SizedBox(height: 20),

          // Divider
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  'OR CONTINUE WITH EMAIL',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Sign Up: Full Name
          if (!isLogin) ...[
            _buildInputField(
              controller: _fullNameController,
              label: 'Full Name',
              hint: 'John Doe',
              icon: Icons.person_outline_rounded,
              isDark: isDark,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please enter your name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
          ],

          // Email
          _buildInputField(
            controller: _emailController,
            label: 'Email Address',
            hint: 'name@example.com',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            isDark: isDark,
            validator: (v) {
              if (v == null || v.trim().isEmpty || !v.contains('@')) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Password
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Password',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                  if (isLogin)
                    InkWell(
                      onTap: _showForgotPasswordDialog,
                      child: Text(
                        'Forgot password?',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: WebColors.purplePrimary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                validator: (v) {
                  if (v == null || v.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText: '••••••••',
                  hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: Colors.grey[500],
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF090D1A) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: WebColors.purplePrimary,
                      width: 1.5,
                    ),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Sign Up: Optional Referral Code Toggle
          if (!isLogin) ...[
            if (!_showReferralField)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _showReferralField = true),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Have a class / referral code?'),
                  style: TextButton.styleFrom(
                    foregroundColor: WebColors.purplePrimary,
                    textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              )
            else
              _buildInputField(
                controller: _referralCodeController,
                label: 'Class / Referral Code (Optional)',
                hint: 'e.g. SQ-BIO101',
                icon: Icons.tag_rounded,
                isDark: isDark,
              ),
            const SizedBox(height: 8),
          ],

          const SizedBox(height: 12),

          // Submit Action Button
          ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: WebColors.purplePrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isLogin ? 'Sign In' : 'Create Account',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
          ),
          const SizedBox(height: 20),

          // Footnote Terms
          Text(
            'By continuing, you agree to SumQuiz\'s Terms of Service and Privacy Policy.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF94A3B8),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF1E293B) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected
                ? (isDark ? Colors.white : const Color(0xFF0F172A))
                : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _roleCard({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? WebColors.purplePrimary.withValues(alpha: 0.1)
              : (isDark ? const Color(0xFF090D1A) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? WebColors.purplePrimary
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? WebColors.purplePrimary : const Color(0xFF64748B),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected
                      ? WebColors.purplePrimary
                      : (isDark ? Colors.white70 : const Color(0xFF334155)),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleButton(bool isDark) {
    return OutlinedButton(
      onPressed: _isLoading ? null : _googleSignIn,
      style: OutlinedButton.styleFrom(
        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
        side: BorderSide(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            'assets/icons/google_logo.svg',
            height: 18,
            width: 18,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.g_mobiledata_rounded,
              size: 22,
              color: Colors.redAccent,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Continue with Google',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
            prefixIcon: Icon(icon, size: 20),
            filled: true,
            fillColor: isDark ? const Color(0xFF090D1A) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: WebColors.purplePrimary,
                width: 1.5,
              ),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}

