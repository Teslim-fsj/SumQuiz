import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/auth_service.dart';
import 'package:sumquiz/views/widgets/pro_status_widget.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AccountProfileScreen extends StatelessWidget {
  const AccountProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserModel?>();
    final authService = context.read<AuthService>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (user == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Account',
            style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.primary),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          // Animated Gradient Background
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
                                const Color(0xFFF3F4F6),
                                Color.lerp(const Color(0xFFE8EAF6),
                                    const Color(0xFFC5CAE9), value)!,
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
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    children: <Widget>[
                      _buildHeader(context, user, theme)
                          .animate()
                          .fadeIn(delay: 100.ms)
                          .slideY(begin: 0.1),
                      const SizedBox(height: 32),
                      const ProStatusWidget()
                          .animate()
                          .fadeIn(delay: 200.ms)
                          .scale(),
                      const SizedBox(height: 24),
                      _buildAccountActions(context, authService, user, theme)
                          .animate()
                          .fadeIn(delay: 300.ms),
                      const SizedBox(height: 32),
                      _buildSignOutButton(context, authService, theme)
                          .animate()
                          .fadeIn(delay: 400.ms),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassContainer(ThemeData theme, {required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardColor.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, UserModel user, ThemeData theme) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                blurRadius: 15,
                spreadRadius: 5,
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 50,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            child: Text(
              user.displayName.isNotEmpty
                  ? user.displayName[0].toUpperCase()
                  : '?',
              style: theme.textTheme.displayMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 40,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          user.displayName,
          style: theme.textTheme.headlineSmall?.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 4),
        Text(
          user.email,
          style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
        ),
        if (user.subscriptionExpiry != null)
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amberAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.amberAccent.withValues(alpha: 0.3)),
              ),
              child: Text(
                'Pro until ${user.subscriptionExpiry!.toLocal().toString().split(' ')[0]}',
                style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.amber[800],
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAccountActions(BuildContext context, AuthService authService,
      UserModel user, ThemeData theme) {
    return _buildGlassContainer(
      theme,
      child: Column(
        children: [
          _buildListTile(
            context,
            icon: Icons.lock_outline,
            title: 'Change Password',
            theme: theme,
            onTap: () {
              authService.sendPasswordResetEmail(user.email);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Password reset email sent.'),
                  duration: Duration(seconds: 3),
                  backgroundColor: Colors.green,
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Divider(
                height: 1, color: theme.dividerColor.withValues(alpha: 0.1)),
          ),
          _buildListTile(
            context,
            icon: Icons.volunteer_activism,
            title: 'Refer & Earn',
            theme: theme,
            onTap: () => context.push('/referral'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Divider(
                height: 1, color: theme.dividerColor.withValues(alpha: 0.1)),
          ),
          _buildListTile(
            context,
            icon: Icons.email_outlined,
            title: 'Update Email',
            theme: theme,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Email update coming soon')),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Divider(
                height: 1, color: theme.dividerColor.withValues(alpha: 0.1)),
          ),
          _buildListTile(
            context,
            icon: Icons.delete_outline,
            title: 'Delete Account',
            theme: theme,
            onTap: () => _showDeleteAccountDialog(context, authService, theme),
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required ThemeData theme,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? Colors.redAccent : theme.colorScheme.primary;
    final textColor =
        isDestructive ? Colors.redAccent : theme.colorScheme.onSurface;

    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title,
          style: theme.textTheme.bodyLarge
              ?.copyWith(color: textColor, fontSize: 16)),
      trailing:
          Icon(Icons.arrow_forward_ios, size: 14, color: theme.disabledColor),
    );
  }

  void _showDeleteAccountDialog(
      BuildContext context, AuthService authService, ThemeData theme) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: theme.dialogBackgroundColor,
          title: Text('Delete Account',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          content: Text(
              'Are you sure you want to permanently delete your account? This action cannot be undone.',
              style: theme.textTheme.bodyMedium),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Delete',
                  style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.redAccent, fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Account deletion coming soon')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildSignOutButton(
      BuildContext context, AuthService authService, ThemeData theme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.cardColor.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextButton.icon(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            label: Text('Sign Out',
                style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
            onPressed: () => authService.signOut(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ),
    );
  }
}
