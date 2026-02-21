import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sumquiz/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';

enum AuthMode { login, signUp }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _referralCodeController = TextEditingController();
  AuthMode _authMode = AuthMode.login;
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
      _authMode =
          _authMode == AuthMode.login ? AuthMode.signUp : AuthMode.login;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });
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
        await authService.signUpWithEmailAndPassword(
          context,
          _emailController.text.trim(),
          _passwordController.text.trim(),
          _fullNameController.text.trim(),
          _referralCodeController.text.trim(),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Authentication failed. Please try again.';

      switch (e.code) {
        case 'invalid-email':
          errorMessage = 'Invalid email address format.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled.';
          break;
        case 'user-not-found':
          errorMessage = 'No account found with this email.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password.';
          break;
        case 'email-already-in-use':
          errorMessage = 'An account already exists with this email.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Email/password accounts are not enabled.';
          break;
        case 'weak-password':
          errorMessage =
              'Password is too weak. Please use a stronger password.';
          break;
        case 'network-request-failed':
          errorMessage =
              'Network error. Please check your connection and try again.';
          break;
        default:
          errorMessage = 'Authentication failed. Please try again later.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(errorMessage, style: theme.textTheme.bodyMedium)),
        );
      }
    } catch (e) {
      // Check if this is a referral-related error
      String errorMessage = 'Authentication Failed: ${e.toString()}';
      if (e.toString().toLowerCase().contains('referral')) {
        errorMessage = e.toString().replaceAll('Exception:', '').trim();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(errorMessage, style: theme.textTheme.bodyMedium)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _googleSignIn() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    // Add a small delay to ensure UI updates before starting the flow
    await Future.delayed(const Duration(milliseconds: 100));
    final theme = Theme.of(context);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signInWithGoogle(context,
          referralCode: _referralCodeController.text.trim());
    } catch (e) {
      String errorMessage = 'Google Sign-In failed. Please try again.';

      // Check for specific error types
      if (e.toString().contains('network') ||
          e.toString().contains('connection')) {
        errorMessage =
            'Network error. Please check your connection and try again.';
      } else if (e.toString().contains('cancelled')) {
        // Don't show an error message if the user cancelled the sign-in
        errorMessage = '';
      } else if (e.toString().contains('account disabled')) {
        errorMessage =
            'This account has been disabled. Please contact support.';
      } else if (e.toString().contains('malformed') ||
          e.toString().contains('expired')) {
        errorMessage = 'Authentication token is invalid. Please try again.';
      } else if (e.toString().contains('Google Sign-In is disabled')) {
        errorMessage =
            'Google Sign-In is currently disabled. Please try again later.';
      } else if (e.toString().toLowerCase().contains('referral')) {
        // Handle referral-related errors
        errorMessage = e.toString().replaceAll('Exception:', '').trim();
      } else {
        // Use the actual error message from the exception
        errorMessage = e.toString().replaceAll('Exception:', '').trim();
        if (errorMessage.isEmpty) {
          errorMessage = 'Google Sign-In failed. Please try again.';
        }
      }

      if (mounted && errorMessage.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(errorMessage, style: theme.textTheme.bodyMedium)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      body: Stack(
        children: [
          // Animated Background
          Animate(
            onPlay: (controller) => controller.repeat(reverse: true),
            effects: [
              CustomEffect(
                duration: 6.seconds,
                builder: (context, value, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                theme.colorScheme.surface,
                                Color.lerp(theme.colorScheme.surface,
                                    theme.colorScheme.primaryContainer, value)!,
                              ]
                            : [
                                const Color(0xFFF3F4F6), // Light Grey
                                Color.lerp(
                                    const Color(0xFFE8EAF6),
                                    const Color(0xFFC5CAE9),
                                    value)!, // Pulse Blue
                              ],
                      ),
                    ),
                    child: child,
                  );
                },
              )
            ],
            child: Container(),
          ),

          // Main Content
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 800) {
                // Desktop / Web Wide Layout
                return Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Row(
                      children: [
                        // Left Side: Illustration / Branding
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                    color: theme.cardColor,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: theme.colorScheme.primary
                                            .withValues(alpha: 0.15),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                      )
                                    ]),
                                child: Image.asset(
                                  'assets/images/sumquiz_logo.png',
                                  width: 80,
                                  height: 80,
                                ),
                              ).animate().scale(
                                  duration: 500.ms, curve: Curves.easeOutBack),
                              const SizedBox(height: 32),
                              Text(
                                'Master Your Knowledge.',
                                style: theme.textTheme.displaySmall?.copyWith(
                                  fontSize: 42,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                  height: 1.1,
                                ),
                              ).animate().fadeIn().slideX(),
                              const SizedBox(height: 16),
                              Text(
                                'Generate quizzes, flashcards, and summaries instantly with AI.',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontSize: 18,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.7),
                                  height: 1.5,
                                ),
                              ).animate().fadeIn(delay: 200.ms).slideX(),
                            ],
                          ),
                        ),
                        // Right Side: Auth Form
                        const SizedBox(width: 80),
                        Expanded(child: _buildAuthCard(theme)),
                      ],
                    ),
                  ),
                );
              } else {
                // Mobile Layout
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24.0, vertical: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo Area
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: theme.cardColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.15),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                )
                              ]),
                          child: Image.asset(
                            'assets/images/sumquiz_logo.png',
                            width: 60,
                            height: 60,
                          ),
                        )
                            .animate()
                            .scale(duration: 500.ms, curve: Curves.easeOutBack),

                        const SizedBox(height: 32),

                        // Glass Card (Constrained for mobile)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400),
                          child: _buildAuthCard(theme),
                        ),
                      ],
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAuthCard(ThemeData theme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: theme.cardColor.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: theme.cardColor.withValues(alpha: 0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            switchInCurve: Curves.easeOutQuart,
            switchOutCurve: Curves.easeInQuart,
            layoutBuilder: (child, list) => Stack(children: [child!, ...list]),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                  opacity: animation,
                  child: SizeTransition(sizeFactor: animation, child: child));
            },
            child: _authMode == AuthMode.login
                ? _buildLoginForm(theme)
                : _buildSignUpForm(theme),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 600.ms, delay: 200.ms)
        .slideY(begin: 0.1, end: 0);
  }

  Widget _buildLoginForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('loginForm'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Welcome Back',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in to your account',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 32),
          _buildTextField(
            controller: _emailController,
            labelText: 'Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (value) =>
                value == null || !value.contains('@') ? 'Invalid email' : null,
            theme: theme,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _passwordController,
            labelText: 'Password',
            icon: Icons.lock_outline,
            obscureText: true,
            validator: (value) =>
                value == null || value.isEmpty ? 'Enter password' : null,
            theme: theme,
          ),
          const SizedBox(height: 32),
          _buildAuthButton('Sign In', _submit, theme),
          const SizedBox(height: 16),
          _buildGoogleButton(theme),
          const SizedBox(height: 24),
          _buildSwitchAuthModeButton(
            'Don\'t have an account? ',
            'Sign Up',
            _switchAuthMode,
            theme,
          ),
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
          Text(
            'Create Account',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Join SumQuiz for free',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 32),
          _buildTextField(
            controller: _fullNameController,
            labelText: 'Full Name',
            icon: Icons.person_outline,
            validator: (value) =>
                value == null || value.isEmpty ? 'Enter full name' : null,
            theme: theme,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _emailController,
            labelText: 'Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (value) =>
                value == null || !value.contains('@') ? 'Invalid email' : null,
            theme: theme,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _passwordController,
            labelText: 'Password',
            icon: Icons.lock_outline,
            obscureText: true,
            validator: (value) =>
                value == null || value.length < 6 ? 'Min 6 characters' : null,
            theme: theme,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _referralCodeController,
            labelText: 'Referral Code (Optional)',
            icon: Icons.card_giftcard,
            validator: null,
            theme: theme,
          ),
          const SizedBox(height: 32),
          _buildAuthButton('Sign Up', _submit, theme),
          const SizedBox(height: 16),
          _buildGoogleButton(theme),
          const SizedBox(height: 24),
          _buildSwitchAuthModeButton(
            'Already have an account? ',
            'Sign In',
            _switchAuthMode,
            theme,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    required ThemeData theme,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: theme.textTheme.bodyMedium
          ?.copyWith(fontSize: 15, color: theme.colorScheme.onSurface),
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 14),
        prefixIcon: Icon(icon,
            color: theme.colorScheme.primary.withValues(alpha: 0.7), size: 20),
        filled: true,
        fillColor: theme.cardColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
      ),
    );
  }

  Widget _buildAuthButton(
      String text, VoidCallback onPressed, ThemeData theme) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          elevation: 4,
          shadowColor: theme.colorScheme.primary.withValues(alpha: 0.4),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _isLoading
            ? SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: theme.colorScheme.onPrimary))
            : Text(
                text,
                style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onPrimary),
              ),
      ),
    );
  }

  Widget _buildGoogleButton(ThemeData theme) {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : _googleSignIn,
        icon: SvgPicture.asset('assets/icons/google_logo.svg', height: 22),
        label: Text(
          'Continue with Google',
          style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: theme.cardColor,
          side: BorderSide(color: theme.dividerColor),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildSwitchAuthModeButton(
      String text, String buttonText, VoidCallback onPressed, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(text,
            style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 14)),
        GestureDetector(
          onTap: onPressed,
          child: Text(
            buttonText,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
