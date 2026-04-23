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

enum AuthMode { login, signUp }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
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
        developer.log('Sign-Up successful, user document creation initiated with role: ${_signUpRole.name}');
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
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    final theme = Theme.of(context);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('intended_role', _signUpRole.name);

      await authService.signInWithGoogle(context, referralCode: _referralCodeController.text.trim());
      
      if (!mounted) return;
      if (prefs.getBool('is_new_user') ?? false) {
        developer.log('Google Sign-In successful for new user, role: ${prefs.getString('intended_role')}');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(theme, messageForFirebaseAuth(e));
    } catch (e) {
      // Catch GoogleSignInException dynamically or check its type string to avoid compile errors if missing
      final errorStr = e.toString();
      if (errorStr.contains('GoogleSignInException') || errorStr.contains('PlatformException')) {
        final msg = messageForGoogleSignInException(e);
        if (mounted && msg.isNotEmpty) _showError(theme, msg);
      } else {
        if (mounted) _showError(theme, messageForAuthFailure(e));
      }
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 900;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Row(
        children: [
          if (!isMobile) Expanded(flex: 5, child: _buildBrandingPanel(theme)),
          Expanded(
            flex: 6,
            child: isMobile 
              ? SingleChildScrollView(child: _buildAuthPanel(theme, isMobile: true))
              : _buildAuthPanel(theme, isMobile: false),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandingPanel(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final bgGradient = isDark
        ? LinearGradient(colors: [theme.colorScheme.primary.withOpacity(0.1), theme.colorScheme.surface], begin: Alignment.topLeft, end: Alignment.bottomRight)
        : LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.primaryContainer.withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : theme.colorScheme.primary,
        gradient: bgGradient,
        border: Border(right: BorderSide(color: theme.dividerColor.withOpacity(0.1))),
      ),
      child: Stack(
        children: [
          // Subtle decorative graphic
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.surface.withOpacity(0.1),
              ),
            ),
          ).animate().fadeIn(duration: 1.seconds).scale(begin: const Offset(0.8, 0.8)),
          
          Padding(
            padding: const EdgeInsets.all(60.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 30, offset: const Offset(0, 10)),
                    ]
                  ),
                  child: Image.asset('assets/images/sumquiz_logo.png', width: 64, height: 64),
                ).animate().slideY(begin: 0.2).fadeIn(duration: 600.ms),
                const SizedBox(height: 40),
                Text(
                  'Empower your learning\nwith intelligent logic.',
                  style: GoogleFonts.outfit(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                    color: isDark ? theme.colorScheme.onSurface : Colors.white,
                    letterSpacing: -1,
                  ),
                ).animate().slideY(begin: 0.2, delay: 100.ms).fadeIn(),
                const SizedBox(height: 24),
                Text(
                  'Join thousands of educators and students leveraging AI to automate and deepen their study practices.',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                    color: isDark ? theme.colorScheme.onSurface.withOpacity(0.7) : Colors.white70,
                  ),
                ).animate().slideY(begin: 0.2, delay: 200.ms).fadeIn(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthPanel(ThemeData theme, {required bool isMobile}) {
    return Container(
      color: theme.colorScheme.surface,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 80, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isMobile) ...[
              Center(child: Image.asset('assets/images/sumquiz_logo.png', width: 48, height: 48)),
              const SizedBox(height: 32),
            ],
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero).animate(animation),
                  child: child,
                ),
              ),
              child: _authMode == AuthMode.login ? _buildLoginForm(theme) : _buildSignUpForm(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('loginForm'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Welcome back', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          Text('Please enter your details to sign in.', style: GoogleFonts.inter(fontSize: 15, color: theme.colorScheme.onSurface.withOpacity(0.6))),
          const SizedBox(height: 40),
          _buildTextField(
            controller: _emailController,
            label: 'Email Address',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (val) => val == null || !val.contains('@') ? 'Enter a valid email' : null,
            theme: theme,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _passwordController,
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            obscureText: true,
            validator: (val) => val == null || val.isEmpty ? 'Enter your password' : null,
            theme: theme,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact, foregroundColor: theme.colorScheme.primary),
              child: Text('Forgot password?', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ),
          const SizedBox(height: 24),
          _buildAuthButton('Sign In', _submit, theme),
          const SizedBox(height: 24),
          _buildSocialDivider(theme),
          const SizedBox(height: 24),
          _buildGoogleButton(theme),
          const SizedBox(height: 32),
          _buildSwitchAuthModeButton('Don\'t have an account?', 'Sign up', _switchAuthMode, theme),
        ],
      ),
    );
  }

  Widget _buildSignUpForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('signUpForm'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Create an account', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          Text('Start your journey with SumQuiz today.', style: GoogleFonts.inter(fontSize: 15, color: theme.colorScheme.onSurface.withOpacity(0.6))),
          const SizedBox(height: 32),
          _buildRoleSelector(theme),
          const SizedBox(height: 24),
          _buildTextField(
            controller: _fullNameController,
            label: 'Full Name',
            icon: Icons.person_outline,
            validator: (val) => val == null || val.isEmpty ? 'Enter full name' : null,
            theme: theme,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _emailController,
            label: 'Email Address',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (val) => val == null || !val.contains('@') ? 'Enter a valid email' : null,
            theme: theme,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _passwordController,
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            obscureText: true,
            validator: (val) => val == null || val.length < 6 ? 'Min 6 characters required' : null,
            theme: theme,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _referralCodeController,
            label: 'Referral Code (Optional)',
            icon: Icons.card_giftcard,
            theme: theme,
          ),
          const SizedBox(height: 32),
          _buildAuthButton('Create Account', _submit, theme),
          const SizedBox(height: 24),
          _buildSocialDivider(theme),
          const SizedBox(height: 24),
          _buildGoogleButton(theme),
          const SizedBox(height: 32),
          _buildSwitchAuthModeButton('Already have an account?', 'Log in', _switchAuthMode, theme),
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
    String? Function(String?)? validator,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface.withOpacity(0.8))),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          style: GoogleFonts.inter(fontSize: 15, color: theme.colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: 'Enter your ${label.toLowerCase()}',
            hintStyle: GoogleFonts.inter(fontSize: 14, color: theme.colorScheme.onSurface.withOpacity(0.4)),
            prefixIcon: Icon(icon, size: 20, color: theme.colorScheme.onSurface.withOpacity(0.5)),
            filled: true,
            fillColor: isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.1))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? theme.dividerColor.withOpacity(0.05) : const Color(0xFFE5E7EB))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.colorScheme.primary, width: 2)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.colorScheme.error)),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleSelector(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark ? theme.colorScheme.surfaceContainerHighest : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _RolePill(
              label: 'Student',
              isSelected: _signUpRole == UserRole.student,
              onTap: () => setState(() => _signUpRole = UserRole.student),
              theme: theme,
            ),
          ),
          Expanded(
            child: _RolePill(
              label: 'Educator',
              isSelected: _signUpRole == UserRole.creator,
              onTap: () => setState(() => _signUpRole = UserRole.creator),
              theme: theme,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthButton(String text, VoidCallback onPressed, ThemeData theme) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isLoading
            ? SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: theme.colorScheme.onPrimary))
            : Text(text, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildGoogleButton(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return SizedBox(
      height: 54,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : _googleSignIn,
        icon: SvgPicture.asset('assets/icons/google_logo.svg', height: 20),
        label: Text(
          'Sign in with Google',
          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: isDark ? Colors.transparent : Colors.white,
          side: BorderSide(color: isDark ? theme.dividerColor.withOpacity(0.3) : const Color(0xFFE5E7EB)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildSocialDivider(ThemeData theme) {
    return Row(
      children: [
        Expanded(child: Divider(color: theme.dividerColor.withOpacity(0.2))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('OR', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface.withOpacity(0.4))),
        ),
        Expanded(child: Divider(color: theme.dividerColor.withOpacity(0.2))),
      ],
    );
  }

  Widget _buildSwitchAuthModeButton(String text, String highlight, VoidCallback onTap, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(text, style: GoogleFonts.inter(fontSize: 14, color: theme.colorScheme.onSurface.withOpacity(0.7))),
        const SizedBox(width: 4),
        InkWell(
          onTap: onTap,
          child: Text(highlight, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
        ),
      ],
    );
  }
}

class _RolePill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ThemeData theme;

  const _RolePill({required this.label, required this.isSelected, required this.onTap, required this.theme});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))] : [],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ),
    );
  }
}
