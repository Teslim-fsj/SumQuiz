import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/auth_service.dart';
import 'package:sumquiz/services/user_service.dart';
import 'package:sumquiz/theme/web_theme.dart';

class RoleSelectionDialog extends StatefulWidget {
  const RoleSelectionDialog({super.key});

  @override
  State<RoleSelectionDialog> createState() => _RoleSelectionDialogState();
}

class _RoleSelectionDialogState extends State<RoleSelectionDialog> {
  UserRole? _selectedRole;
  bool _isLoading = false;

  Future<void> _confirm() async {
    if (_selectedRole == null) return;
    setState(() => _isLoading = true);

    final authService = Provider.of<AuthService>(context, listen: false);
    final uid = authService.currentUser?.uid;

    if (uid != null) {
      await UserService().updateRole(uid, _selectedRole!);
    }

    if (!mounted) return;
    Navigator.of(context).pop();

    if (_selectedRole == UserRole.creator) {
      context.go('/'); // Home now shows TeacherDashboard for creators
    } else {
      context.go('/create');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 680),
        decoration: BoxDecoration(
          color: WebColors.background,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: WebColors.border, width: 1.5),
          boxShadow: WebColors.cardShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    WebColors.primary.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [WebColors.primary, Color(0xFF7C3AED)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: WebColors.primary.withValues(alpha: 0.3),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.waving_hand_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  )
                      .animate()
                      .scale(duration: 500.ms, curve: Curves.easeOutBack),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome to SumQuiz!',
                    style: GoogleFonts.outfit(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: WebColors.textPrimary,
                    ),
                  ).animate().fadeIn(delay: 100.ms),
                  const SizedBox(height: 12),
                  Text(
                    'To personalize your experience, tell us how you\'ll be using SumQuiz.',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      color: WebColors.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 200.ms),
                ],
              ),
            ),

            // Role Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _buildRoleCard(
                      role: UserRole.student,
                      icon: Icons.school_rounded,
                      label: 'Student',
                      description:
                          'I want to study smarter, generate flashcards, and track my learning progress.',
                      color: const Color(0xFF2563EB),
                      delay: 0,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _buildRoleCard(
                      role: UserRole.creator,
                      icon: Icons.assignment_rounded,
                      label: 'Teacher',
                      description:
                          'I create exams and assessments to evaluate and challenge my students.',
                      color: const Color(0xFF7C3AED),
                      delay: 100,
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0),
            ),

            // Confirm Button
            Padding(
              padding: const EdgeInsets.fromLTRB(40, 24, 40, 40),
              child: SizedBox(
                width: double.infinity,
                height: 64,
                child: ElevatedButton(
                  onPressed:
                      _selectedRole != null && !_isLoading ? _confirm : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WebColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: WebColors.primary.withValues(alpha: 0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _selectedRole == null
                                  ? 'Select a role to continue'
                                  : _selectedRole == UserRole.student
                                      ? 'Start Learning →'
                                      : 'Start Creating →',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ).animate(delay: 400.ms).fadeIn(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required UserRole role,
    required IconData icon,
    required String label,
    required String description,
    required Color color,
    required int delay,
  }) {
    final isSelected = _selectedRole == role;

    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : WebColors.backgroundAlt,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? color : WebColors.border,
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon ring
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isSelected ? color : WebColors.background,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? color : WebColors.border,
                  width: 2,
                ),
              ),
              child: Icon(
                icon,
                size: 36,
                color: isSelected ? Colors.white : WebColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isSelected ? color : WebColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: WebColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (isSelected) ...[
              const SizedBox(height: 20),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_rounded,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Selected',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ).animate().scale(duration: 200.ms, curve: Curves.easeOutBack),
            ],
          ],
        ),
      ),
    );
  }
}
