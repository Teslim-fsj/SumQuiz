import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/user_model.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  UserRole? _selectedRole;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    if (_selectedRole != null) {
      await prefs.setString('intended_role', _selectedRole!.name);
    }
    if (mounted) context.go('/auth');
  }

  void _navigateToNextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Content
          PageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            children: [
              OnboardingPage(
                pageIndex: 0,
                controller: _pageController, // Pass controller for parallax
                title: 'From Lecture to Legend',
                subtitle:
                    'Transform raw notes into powerful summaries and quizzes instantly.',
                imagePath: 'assets/images/onboarding_learn.svg',
                theme: theme,
              ),
              OnboardingPage(
                pageIndex: 1,
                controller: _pageController,
                title: 'Your Knowledge,\nSupercharged',
                subtitle:
                    'Generate flashcards, track momentum, and conquer any subject.',
                imagePath: 'assets/images/onboarding_notes.svg',
                theme: theme,
              ),
              OnboardingPage(
                pageIndex: 2,
                controller: _pageController,
                title: 'Master It All',
                subtitle:
                    'Start for free today. Upgrade your study strategy forever.',
                imagePath: 'assets/images/onboarding_rocket.svg',
                theme: theme,
              ),
              _buildRoleSelectionPage(theme),
            ],
          ),

          // Bottom Controls
          Positioned(
            left: 0,
            right: 0,
            bottom: 48,
            child: _buildBottomControls(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        children: [
          // Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) => _buildDot(index, theme)),
          ),
          const SizedBox(height: 32),

          // Button
          AnimatedContainer(
            duration: 300.ms,
            width: _currentPage == 3 ? 300 : 80, // Morph width
            height: 64,
            child: ElevatedButton(
              onPressed:
                  _currentPage == 3 
                  ? (_selectedRole != null ? _finishOnboarding : null)
                  : _navigateToNextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32)),
                padding: EdgeInsets.zero,
                elevation: 8,
                shadowColor: theme.colorScheme.primary.withValues(alpha: 0.4),
              ),
              child: AnimatedSwitcher(
                duration: 200.ms,
                child: _currentPage == 3
                    ? Text(
                        _selectedRole == null ? 'Select your role' : 'Get Started',
                        key: const ValueKey('text'),
                        style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimary),
                      )
                    : Icon(
                        Icons.arrow_forward_rounded,
                        key: const ValueKey('icon'),
                        color: theme.colorScheme.onPrimary,
                        size: 30,
                      ),
              ),
            ),
          ),

          if (_currentPage == 3)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: TextButton(
                onPressed: _finishOnboarding,
                child: Text(
                  'Already have an account? Sign In',
                  style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w600),
                ),
              ).animate().fadeIn(),
            ),
        ],
      ),
    );
  }

  Widget _buildDot(int index, ThemeData theme) {
    bool isActive = _currentPage == index;
    return AnimatedContainer(
      duration: 300.ms,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: isActive ? 24 : 8,
      decoration: BoxDecoration(
        color: isActive
            ? theme.colorScheme.primary
            : theme.disabledColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildRoleSelectionPage(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'How will you use SumQuiz?',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
              height: 1.2,
            ),
          ).animate().fadeIn().slideY(begin: 0.2, end: 0),
          const SizedBox(height: 16),
          Text(
            'We\'ll tailor your experience based on your role.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ).animate(delay: 100.ms).fadeIn(),
          const SizedBox(height: 48),
          _buildRoleCard(
            role: UserRole.student,
            title: 'I\'m a Student',
            subtitle: 'I want to study and master subjects.',
            icon: Icons.school_outlined,
            theme: theme,
          ).animate(delay: 200.ms).fadeIn().slideX(begin: -0.2, end: 0),
          const SizedBox(height: 20),
          _buildRoleCard(
            role: UserRole.creator, // Creator is the teacher role
            title: 'I\'m a Teacher',
            subtitle: 'I want to create exams and track students.',
            icon: Icons.assignment_ind_outlined,
            theme: theme,
          ).animate(delay: 300.ms).fadeIn().slideX(begin: 0.2, end: 0),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildRoleCard({
    required UserRole role,
    required String title,
    required String subtitle,
    required IconData icon,
    required ThemeData theme,
  }) {
    bool isSelected = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: 300.ms,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.5),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
                size: 32,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: theme.colorScheme.primary,
              ).animate().scale(),
          ],
        ),
      ),
    );
  }
}

class OnboardingPage extends StatelessWidget {
  final int pageIndex;
  final PageController controller;
  final String title;
  final String subtitle;
  final String imagePath;
  final ThemeData theme;

  const OnboardingPage({
    super.key,
    required this.pageIndex,
    required this.controller,
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        double pageOffset = 0;
        if (controller.position.haveDimensions) {
          pageOffset = controller.page! - pageIndex;
        }

        // Parallax Effect
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Image Parallax (Moves horizontally)
              Transform.translate(
                offset: Offset(pageOffset * -50, 0), // Subtle parallax
                child: SvgPicture.asset(
                  imagePath,
                  height: 300,
                  colorFilter: ColorFilter.mode(
                      theme.colorScheme.primary, BlendMode.srcIn),
                )
                    .animate(target: 1)
                    .scale(duration: 600.ms, curve: Curves.easeOutBack),
              ),
              const SizedBox(height: 48),

              // Text Content
              Transform.translate(
                offset:
                    Offset(pageOffset * 50, 0), // Inverse parallax for depth
                child: Column(
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontSize: 16,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 120), // Spacer for buttons
            ],
          ),
        );
      },
    );
  }
}
