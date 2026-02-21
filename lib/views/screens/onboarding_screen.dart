import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_animate/flutter_animate.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

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
    if (mounted) context.go('/auth');
  }

  void _navigateToNextPage() {
    if (_currentPage < 2) {
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
            children: List.generate(3, (index) => _buildDot(index, theme)),
          ),
          const SizedBox(height: 32),

          // Button
          AnimatedContainer(
            duration: 300.ms,
            width: _currentPage == 2 ? 300 : 80, // Morph width
            height: 64,
            child: ElevatedButton(
              onPressed:
                  _currentPage == 2 ? _finishOnboarding : _navigateToNextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32)),
                padding: EdgeInsets.zero,
                elevation: 8,
                shadowColor: theme.colorScheme.primary.withOpacity(0.4),
              ),
              child: AnimatedSwitcher(
                duration: 200.ms,
                child: _currentPage == 2
                    ? Text(
                        'Get Started',
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

          if (_currentPage == 2)
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
