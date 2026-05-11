import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/user_model.dart';
import '../../widgets/sumi_mascot.dart';
import '../../models/sumi_emotion.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  UserRole? _selectedRole;

  static const int _totalPages = 5; 

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) => setState(() => _currentPage = page);

  void _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    if (_selectedRole != null) {
      await prefs.setString('intended_role', _selectedRole!.name);
    }
    if (mounted) context.go('/auth');
  }

  void _next() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutQuart,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _prev() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutQuart,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        children: [
          // Background Aesthetic
          _OnboardingBackground(colorScheme: cs),

          // Main Onboarding Flow
          Column(
            children: [
              SizedBox(height: MediaQuery.of(context).padding.top + 20),
              // Top Bar
              _buildTopBar(cs),
              
              // Central Mascot Area
              Expanded(
                flex: 4,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(scale: animation, child: child),
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey('mascot_$_currentPage'),
                      child: SumiMascot(
                        state: _getSumiStateForPage(_currentPage),
                        size: 280,
                        showBubble: false,
                      ),
                    ),
                  ),
                ),
              ),

              // Dynamic Content Area
              Expanded(
                flex: 5,
                child: PageView(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  physics: const NeverScrollableScrollPhysics(), // Force button navigation for narrative
                  children: [
                    _OnboardingContentPage(
                      title: "Hi! I'm Sumi.",
                      subtitle: "Your personal AI tutor and study companion. I'm here to help you master anything, faster.",
                      features: const ["AI Study Buddy", "24/7 Availability", "Empathetic Learning"],
                      colorScheme: cs,
                    ),
                    _OnboardingContentPage(
                      title: "Neural Capture",
                      subtitle: "I can listen to your live lectures and transcribe them directly into organized study notes in real-time.",
                      features: const ["Live Transcription", "Smart Formatting", "Key Point Extraction"],
                      colorScheme: cs,
                    ),
                    _OnboardingContentPage(
                      title: "Live Tutoring",
                      subtitle: "Let's talk! We can have voice-to-voice tutoring sessions. I'll ask questions to test your depth of knowledge.",
                      features: const ["Voice-to-Voice", "Active Recall", "Socratic Mentoring"],
                      colorScheme: cs,
                    ),
                    _OnboardingContentPage(
                      title: "Mastery Hub",
                      subtitle: "From your notes, I generate adaptive quizzes, flashcards, and visual mastery analytics to track your progress.",
                      features: const ["Smart Quizzes", "Neural Analytics", "Spaced Repetition"],
                      colorScheme: cs,
                    ),
                    _buildRoleSelection(theme),
                  ],
                ),
              ),

              // Bottom Controls
              _buildBottomControls(cs),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: cs.primary, size: 24),
              const SizedBox(width: 8),
              Text(
                'SumQuiz',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: cs.primary,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: _finishOnboarding,
            child: Text(
              'Skip',
              style: GoogleFonts.outfit(
                color: cs.onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(ColorScheme cs) {
    final isLastPage = _currentPage == _totalPages - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Dots
          Row(
            children: List.generate(
              _totalPages,
              (i) => AnimatedContainer(
                duration: 300.ms,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 8,
                width: _currentPage == i ? 32 : 8,
                decoration: BoxDecoration(
                  color: _currentPage == i ? cs.primary : cs.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),

          // Action Button
          SizedBox(
            height: 64,
            width: isLastPage ? 180 : 64,
            child: ElevatedButton(
              onPressed: isLastPage
                  ? (_selectedRole != null ? _finishOnboarding : null)
                  : _next,
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
                elevation: 8,
                shadowColor: cs.primary.withValues(alpha: 0.4),
                padding: EdgeInsets.zero,
              ),
              child: isLastPage
                  ? Text(
                      'Let\'s Go!',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    )
                  : const Icon(Icons.arrow_forward_ios_rounded, size: 24),
            ),
          ).animate(target: isLastPage ? 1 : 0).shimmer(delay: 2.seconds, duration: 1.seconds),
        ],
      ),
    );
  }

  Widget _buildRoleSelection(ThemeData theme) {
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Who are you studying as?',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 32),
          _RoleOption(
            role: UserRole.student,
            title: "I'm a Learner",
            subtitle: "Studying for exams and mastery.",
            icon: Icons.school_rounded,
            isSelected: _selectedRole == UserRole.student,
            onTap: () => setState(() => _selectedRole = UserRole.student),
            colorScheme: cs,
          ),
          const SizedBox(height: 16),
          _RoleOption(
            role: UserRole.creator,
            title: "I'm an Educator",
            subtitle: "Creating content and tracking students.",
            icon: Icons.auto_stories_rounded,
            isSelected: _selectedRole == UserRole.creator,
            onTap: () => setState(() => _selectedRole = UserRole.creator),
            colorScheme: cs,
          ),
        ],
      ),
    );
  }

  SumiState _getSumiStateForPage(int page) {
    switch (page) {
      case 0: return SumiState.idle;
      case 1: return SumiState.focused;
      case 2: return SumiState.thinking;
      case 3: return SumiState.analytical;
      case 4: return SumiState.celebrating;
      default: return SumiState.idle;
    }
  }
}

class _OnboardingContentPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> features;
  final ColorScheme colorScheme;

  const _OnboardingContentPage({
    required this.title,
    required this.subtitle,
    required this.features,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: colorScheme.onSurface,
              letterSpacing: -1,
            ),
          ).animate().fadeIn().slideY(begin: 0.1),
          const SizedBox(height: 16),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 16,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
              height: 1.5,
            ),
          ).animate(delay: 200.ms).fadeIn(),
          const SizedBox(height: 32),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: features.map((f) => _FeatureBadge(text: f, colorScheme: colorScheme)).toList(),
          ).animate(delay: 400.ms).fadeIn(duration: 600.ms),
        ],
      ),
    );
  }
}

class _FeatureBadge extends StatelessWidget {
  final String text;
  final ColorScheme colorScheme;

  const _FeatureBadge({required this.text, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: colorScheme.primary,
        ),
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  final UserRole role;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _RoleOption({
    required this.role,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 300.ms,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.outline.withValues(alpha: 0.1),
            width: 2,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ] : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? colorScheme.onPrimary.withValues(alpha: 0.2) : colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: isSelected ? colorScheme.onPrimary : colorScheme.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: isSelected ? colorScheme.onPrimary.withValues(alpha: 0.8) : colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: colorScheme.onPrimary),
          ],
        ),
      ),
    );
  }
}

class _OnboardingBackground extends StatelessWidget {
  final ColorScheme colorScheme;
  const _OnboardingBackground({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primary.withValues(alpha: 0.05),
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: 4.seconds),
        ),
        Positioned(
          bottom: -50,
          left: -50,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.tertiary.withValues(alpha: 0.05),
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 5.seconds),
        ),
      ],
    );
  }
}
