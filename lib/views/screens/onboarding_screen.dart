import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/user_model.dart';

/// SumQuiz AI Study OS - Premium Onboarding Experience
/// Emphasizes the core pillars: Notes, Lectures, Quizzes, Flashcards, and AI Tutoring

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<OnboardingPageData> _pages = [
    OnboardingPageData(
      title: 'AI Study OS',
      subtitle: 'Your Complete Learning Intelligence Platform',
      description: 'Transform any content into personalized study materials with AI. Notes, lectures, textbooks — SumQuiz handles it all.',
      icon: Icons.psychology_rounded,
      gradientColors: [Color(0xFF1E3A8A), Color(0xFF0D9488)],
    ),
    OnboardingPageData(
      title: 'Smart Notes',
      subtitle: 'Capture & Organize Everything',
      description: 'Import PDFs, paste text, or record lectures. Our AI extracts key concepts and creates structured, searchable notes instantly.',
      icon: Icons.note_alt_rounded,
      gradientColors: [Color(0xFF0D9488), Color(0xFFF59E0B)],
    ),
    OnboardingPageData(
      title: 'Auto Quizzes',
      subtitle: 'Test Your Knowledge',
      description: 'Generate challenging quizzes from any study material. Multiple choice, theory, and essay questions — all AI-crafted to maximize retention.',
      icon: Icons.quiz_rounded,
      gradientColors: [Color(0xFFF59E0B), Color(0xFF1E3A8A)],
    ),
    OnboardingPageData(
      title: 'Flashcards + SRS',
      subtitle: 'Never Forget Again',
      description: 'Smart flashcards with spaced repetition scheduling. Our algorithm knows when you\'re about to forget and brings cards back at the perfect time.',
      icon: Icons.memory_rounded,
      gradientColors: [Color(0xFF1E3A8A), Color(0xFF0D9488)],
    ),
    OnboardingPageData(
      title: 'AI Tutor',
      subtitle: 'Personal 24/7 Tutoring',
      description: 'Get instant explanations, Socratic hints, and personalized guidance. Your AI tutor adapts to your learning style and pace.',
      icon: Icons.school_rounded,
      gradientColors: [Color(0xFF0D9488), Color(0xFFF59E0B)],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) => setState(() => _currentPage = page);

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    if (mounted) context.go('/auth');
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _prev() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF09090B) : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Animated Background
          _OnboardingBackground(isDark: isDark),

          SafeArea(
            child: Column(
              children: [
                // Top Bar
                _buildTopBar(cs, isDark),

                const SizedBox(height: 24),

                // Main Content
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      return _buildPage(_pages[index], cs, isDark, index);
                    },
                  ),
                ),

                // Bottom Controls
                _buildBottomControls(cs, isDark),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(ColorScheme cs, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cs.primary, cs.secondary],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'SumQuiz',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : cs.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: _finishOnboarding,
            child: Text(
              'Skip',
              style: GoogleFonts.inter(
                color: isDark ? Colors.white54 : cs.onSurface.withOpacity(0.6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(OnboardingPageData page, ColorScheme cs, bool isDark, int index) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon with gradient background
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: page.gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(35),
              boxShadow: [
                BoxShadow(
                  color: page.gradientColors[0].withOpacity(0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Icon(
              page.icon,
              size: 64,
              color: Colors.white,
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(0.95, 0.95),
                end: const Offset(1.05, 1.05),
                duration: 3.seconds,
              ),

          const SizedBox(height: 40),

          // Title
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 38,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : cs.onSurface,
              letterSpacing: -1,
              height: 1.1,
            ),
          )
              .animate()
              .fadeIn(duration: 600.ms)
              .slideY(begin: 0.2),

          const SizedBox(height: 12),

          // Subtitle
          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: cs.primary,
              letterSpacing: 0.5,
            ),
          )
              .animate(delay: 150.ms)
              .fadeIn(duration: 600.ms)
              .slideY(begin: 0.2),

          const SizedBox(height: 24),

          // Description
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: isDark ? Colors.white70 : cs.onSurface.withOpacity(0.7),
              height: 1.6,
            ),
          )
              .animate(delay: 300.ms)
              .fadeIn(duration: 600.ms)
              .slideY(begin: 0.2),
        ],
      ),
    );
  }

  Widget _buildBottomControls(ColorScheme cs, bool isDark) {
    final isLastPage = _currentPage == _pages.length - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Page indicator dots
          Row(
            children: List.generate(
              _pages.length,
              (i) => AnimatedContainer(
                duration: 300.ms,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 6,
                width: _currentPage == i ? 28 : 8,
                decoration: BoxDecoration(
                  color: _currentPage == i
                      ? cs.primary
                      : (isDark ? Colors.white24 : cs.onSurface.withOpacity(0.15)),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),

          // Next/Get Started button
          Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _next,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isLastPage ? 'Get Started' : 'Next',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isLastPage ? Icons.arrow_forward_rounded : Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingPageData {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final List<Color> gradientColors;

  const OnboardingPageData({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.gradientColors,
  });
}

class _OnboardingBackground extends StatelessWidget {
  final bool isDark;

  const _OnboardingBackground({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final glow1 = isDark
        ? const Color(0xFF1E3A8A).withOpacity(0.15)
        : const Color(0xFF1E3A8A).withOpacity(0.08);
    final glow2 = isDark
        ? const Color(0xFF0D9488).withOpacity(0.15)
        : const Color(0xFF0D9488).withOpacity(0.08);
    final glow3 = isDark
        ? const Color(0xFFF59E0B).withOpacity(0.1)
        : const Color(0xFFF59E0B).withOpacity(0.06);

    return Stack(
      children: [
        Container(color: isDark ? const Color(0xFF09090B) : const Color(0xFFF8FAFC)),

        // Animated glow orbs
        Positioned(
          top: -100,
          right: -100,
          child: _GlowOrb(color: glow1, size: 400),
        ),
        Positioned(
          bottom: -100,
          left: -100,
          child: _GlowOrb(color: glow2, size: 350),
        ),
        Positioned(
          top: MediaQuery.of(context).size.height * 0.5,
          right: -50,
          child: _GlowOrb(color: glow3, size: 300),
        ),

        // Subtle blur overlay
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
            child: Container(color: Colors.transparent),
          ),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(1.2, 1.2),
          duration: 8.seconds,
        )
        .move(
          begin: const Offset(-15, -15),
          end: const Offset(15, 15),
          duration: 12.seconds,
        );
  }
}