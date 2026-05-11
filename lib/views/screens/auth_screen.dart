import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:sumquiz/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sumquiz/utils/auth_error_messages.dart';
import 'package:go_router/go_router.dart';
import 'package:sumquiz/widgets/sumi_mascot.dart';
import 'package:sumquiz/models/sumi_emotion.dart';

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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  void _switchAuthMode() {
    setState(() {
      _authMode = _authMode == AuthMode.login ? AuthMode.signUp : AuthMode.login;
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
        if (widget.redirectPath != null && widget.redirectPath!.isNotEmpty) {
          context.go(widget.redirectPath!);
        } else {
          context.go('/');
        }
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
        if (widget.redirectPath != null && widget.redirectPath!.isNotEmpty) {
          context.go(widget.redirectPath!);
        } else {
          context.go('/');
        }
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

      await authService.signInWithGoogle(context, referralCode: _referralCodeController.text.trim());

      if (!mounted) return;
      if (widget.redirectPath != null && widget.redirectPath!.isNotEmpty) {
        context.go(widget.redirectPath!);
      } else {
        context.go('/');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(theme, messageForFirebaseAuth(e));
    } catch (e) {
      if (mounted) _showError(theme, messageForAuthFailure(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(ThemeData theme, String message) {
    if (!mounted || message.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onError)),
        backgroundColor: theme.colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 900;
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        children: [
          // Background Aesthetic
          _AuthBackground(colorScheme: cs),

          Row(
            children: [
              if (!isMobile) 
                Expanded(
                  flex: 5, 
                  child: _buildBrandingPanel(theme)
                ),
              Expanded(
                flex: 6,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: _buildAuthPanel(theme, isMobile: isMobile),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBrandingPanel(ThemeData theme) {
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(64),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mascot interaction
          SumiMascot(
            state: _authMode == AuthMode.login ? SumiState.idle : SumiState.celebrating,
            size: 320,
            showBubble: true,
            dialogue: _authMode == AuthMode.login 
              ? "Welcome back! Ready to dive back in?" 
              : "New adventure? Let's get you set up!",
          ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
          
          const SizedBox(height: 48),
          
          Text(
            _authMode == AuthMode.login 
              ? 'Your neural pathways\nare waiting.' 
              : 'Begin your journey\nto complete mastery.',
            style: GoogleFonts.outfit(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              height: 1.1,
              color: cs.onSurface,
              letterSpacing: -1.5,
            ),
          ).animate().fadeIn(duration: 800.ms).slideX(begin: -0.1),
          
          const SizedBox(height: 24),
          
          Text(
            'SumQuiz leverages advanced AI to transform any content into a personalized learning experience.',
            style: GoogleFonts.outfit(
              fontSize: 18,
              color: cs.onSurface.withValues(alpha: 0.6),
              height: 1.5,
            ),
          ).animate(delay: 200.ms).fadeIn(),
        ],
      ),
    );
  }

  Widget _buildAuthPanel(ThemeData theme, {required bool isMobile}) {
    final cs = theme.colorScheme;
    
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isMobile) ...[
            Center(
              child: SumiMascot(
                state: _authMode == AuthMode.login ? SumiState.idle : SumiState.celebrating,
                size: 160,
                showBubble: true,
                dialogue: _authMode == AuthMode.login ? "Welcome back!" : "Let's join!",
              ),
            ),
            const SizedBox(height: 40),
          ],
          
          // Auth Card
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: AnimatedSwitcher(
              duration: 400.ms,
              child: _authMode == AuthMode.login
                  ? _buildLoginForm(theme)
                  : _buildSignUpForm(theme),
            ),
          ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95)),
        ],
      ),
    );
  }

  Widget _buildLoginForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('login'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Sign In',
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your credentials to continue your study.',
            style: GoogleFonts.outfit(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 32),
          _buildTextField(
            controller: _emailController,
            label: 'Email',
            icon: Icons.alternate_email_rounded,
            theme: theme,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _passwordController,
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            theme: theme,
            obscureText: true,
          ),
          const SizedBox(height: 24),
          _buildAuthButton('Login to Neural Hub', _submit, theme),
          const SizedBox(height: 24),
          _buildSocialDivider(theme),
          const SizedBox(height: 24),
          _buildGoogleButton(theme),
          const SizedBox(height: 32),
          _buildSwitchMode('Don\'t have an account?', 'Create one', _switchAuthMode, theme),
        ],
      ),
    );
  }

  Widget _buildSignUpForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('signup'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Join SumQuiz',
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 32),
          _buildRoleSelector(theme),
          const SizedBox(height: 24),
          _buildTextField(
            controller: _fullNameController,
            label: 'Full Name',
            icon: Icons.person_outline_rounded,
            theme: theme,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _emailController,
            label: 'Email',
            icon: Icons.alternate_email_rounded,
            theme: theme,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _passwordController,
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            theme: theme,
            obscureText: true,
          ),
          const SizedBox(height: 24),
          _buildAuthButton('Begin My Journey', _submit, theme),
          const SizedBox(height: 24),
          _buildSocialDivider(theme),
          const SizedBox(height: 24),
          _buildGoogleButton(theme),
          const SizedBox(height: 32),
          _buildSwitchMode('Already a member?', 'Log in', _switchAuthMode, theme),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required ThemeData theme,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: cs.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: GoogleFonts.outfit(color: cs.onSurface),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20, color: cs.primary),
            filled: true,
            fillColor: cs.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: cs.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleSelector(ThemeData theme) {
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _RolePill(
              label: 'Learner',
              isSelected: _signUpRole == UserRole.student,
              onTap: () => setState(() => _signUpRole = UserRole.student),
              colorScheme: cs,
            ),
          ),
          Expanded(
            child: _RolePill(
              label: 'Educator',
              isSelected: _signUpRole == UserRole.creator,
              onTap: () => setState(() => _signUpRole = UserRole.creator),
              colorScheme: cs,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthButton(String text, VoidCallback onPressed, ThemeData theme) {
    return SizedBox(
      height: 60,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(text, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    ).animate(target: _isLoading ? 0 : 1).shimmer(duration: 2.seconds);
  }

  Widget _buildGoogleButton(ThemeData theme) {
    return SizedBox(
      height: 60,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : _googleSignIn,
        icon: SvgPicture.asset('assets/icons/google_logo.svg', height: 24),
        label: Text('Continue with Google', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
        ),
      ),
    );
  }

  Widget _buildSocialDivider(ThemeData theme) {
    return Row(
      children: [
        Expanded(child: Divider(color: theme.colorScheme.outline.withValues(alpha: 0.1))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('OR', style: GoogleFonts.jetBrainsMono(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.3), fontWeight: FontWeight.bold)),
        ),
        Expanded(child: Divider(color: theme.colorScheme.outline.withValues(alpha: 0.1))),
      ],
    );
  }

  Widget _buildSwitchMode(String text, String action, VoidCallback onTap, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(text, style: GoogleFonts.outfit(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
        TextButton(
          onPressed: onTap,
          child: Text(action, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
        ),
      ],
    );
  }
}

class _RolePill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _RolePill({required this.label, required this.isSelected, required this.onTap, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 300.ms,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

class _AuthBackground extends StatelessWidget {
  final ColorScheme colorScheme;
  const _AuthBackground({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -150,
          left: -150,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primary.withValues(alpha: 0.03),
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: 6.seconds),
        ),
        Positioned(
          bottom: -100,
          right: -100,
          child: Container(
            width: 350,
            height: 350,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.tertiary.withValues(alpha: 0.03),
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 8.seconds),
        ),
      ],
    );
  }
}
