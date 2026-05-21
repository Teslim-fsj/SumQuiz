import 'dart:ui';
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

  static const int _totalPages = 4;

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
                  physics:
                      const NeverScrollableScrollPhysics(), // Force button navigation for narrative
                  children: [
                    _buildIntroPage(cs),
                    _buildSmartPage(cs),
                    _buildInputPage(cs),
                    _buildMasteryPage(cs),
                  ],
                ),
              ),

              // Bottom Controls
              _buildBottomControls(cs),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 10),
              Text(
                'Step ${_currentPage + 1} of $_totalPages${_getPageSuffix(_currentPage)}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.4),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 10),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(ColorScheme cs) {
    final isDark = cs.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : cs.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/sumquiz_logo.png',
                  height: 32,
                  width: 32,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'SumQuiz',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: textColor,
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
                color: textColor.withValues(alpha: 0.5),
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
    final isDark = cs.brightness == Brightness.dark;
    final dotActive = cs.primary;
    final dotInactive = isDark
        ? Colors.white.withValues(alpha: 0.2)
        : cs.onSurface.withValues(alpha: 0.1);

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
                height: 6,
                width: _currentPage == i ? 24 : 8,
                decoration: BoxDecoration(
                  color: _currentPage == i ? dotActive : dotInactive,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),

          // Action Button
          AnimatedContainer(
            duration: 400.ms,
            curve: Curves.easeOutCubic,
            height: 56,
            width: isLastPage ? 200 : 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.tertiary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isLastPage ? 'Start Learning' : 'Next',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: cs.onPrimary,
                    ),
                  ),
                  if (!isLastPage) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded,
                        color: cs.onPrimary, size: 20),
                  ],
                ],
              ),
            ),
          )
              .animate(target: isLastPage ? 1 : 0)
              .shimmer(delay: 2.seconds, duration: 1.seconds),
        ],
      ),
    );
  }

  String _getPageSuffix(int page) {
    switch (page) {
      case 0:
        return ' — Intro';
      case 1:
        return ' — Smart';
      case 2:
        return ' — Input';
      case 3:
        return ' — Mastery';
      default:
        return '';
    }
  }

  Widget _buildIntroPage(ColorScheme cs) {
    return _OnboardingContentPage(
      title: "Your Learning ",
      highlightedTitle: "Brain.",
      subtitle:
          "Turn messy notes, PDFs, lectures, and videos into personalized learning instantly.",
      colorScheme: cs,
    );
  }

  Widget _buildSmartPage(ColorScheme cs) {
    return _OnboardingContentPage(
      title: "Study Smarter, ",
      highlightedTitle: "Not Longer.",
      subtitle:
          "Sumi adapts to your strengths, weaknesses, and forgetting patterns automatically.",
      colorScheme: cs,
    );
  }

  Widget _buildInputPage(ColorScheme cs) {
    return _OnboardingContentPage(
      title: "Learn From ",
      highlightedTitle: "Anything.",
      subtitle:
          "Upload notes, record lectures, paste YouTube links, or scan textbooks — Sumi handles the rest.",
      colorScheme: cs,
      extra: _buildFeatureGrid(cs),
    );
  }

  Widget _buildMasteryPage(ColorScheme cs) {
    return _OnboardingContentPage(
      title: "Built for ",
      highlightedTitle: "Mastery",
      subtitle:
          "Stay consistent, beat burnout, and grow into the smartest version of yourself.",
      colorScheme: cs,
      extra: _buildStatsGrid(cs),
    );
  }

  Widget _buildFeatureGrid(ColorScheme cs) {
    final features = [
      {'icon': Icons.picture_as_pdf_rounded, 'label': 'PDFs'},
      {'icon': Icons.play_circle_fill_rounded, 'label': 'YouTube'},
      {'icon': Icons.mic_rounded, 'label': 'Voice'},
      {'icon': Icons.camera_alt_rounded, 'label': 'Textbooks'},
    ];

    final isDark = cs.brightness == Brightness.dark;
    final cardBg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : cs.surfaceContainerHighest.withValues(alpha: 0.3);
    final cardBorder = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : cs.outline.withValues(alpha: 0.1);

    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.8,
        ),
        itemCount: features.length,
        itemBuilder: (context, index) {
          final f = features[index];
          return ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cardBorder),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(f['icon'] as IconData, color: cs.primary, size: 26),
                    const SizedBox(height: 8),
                    Text(
                      f['label'] as String,
                      style: GoogleFonts.inter(
                        color: isDark ? Colors.white : cs.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ).animate().fadeIn(delay: (300 + index * 100).ms).slideY(begin: 0.2);
        },
      ),
    );
  }

  Widget _buildStatsGrid(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'CURRENT STREAK',
              '0 Days',
              cs.primary,
              cs,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildStatCard(
              'GROWTH LEVEL',
              'Seedling',
              cs.tertiary,
              cs,
            ),
          ),
        ],
      ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
    );
  }

  Widget _buildStatCard(
      String label, String value, Color color, ColorScheme cs) {
    final isDark = cs.brightness == Brightness.dark;
    final cardBg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : cs.surfaceContainerHighest.withValues(alpha: 0.3);
    final cardBorder = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : cs.outline.withValues(alpha: 0.1);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white54 : cs.onSurfaceVariant,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  SumiState _getSumiStateForPage(int page) {
    switch (page) {
      case 0:
        return SumiState.idle;
      case 1:
        return SumiState.analytical;
      case 2:
        return SumiState.focused;
      case 3:
        return SumiState.celebrating;
      default:
        return SumiState.idle;
    }
  }
}

class _OnboardingContentPage extends StatelessWidget {
  final String title;
  final String highlightedTitle;
  final String subtitle;
  final Widget? extra;
  final ColorScheme colorScheme;

  const _OnboardingContentPage({
    required this.title,
    required this.highlightedTitle,
    required this.subtitle,
    this.extra,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = colorScheme.brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : colorScheme.onSurface;
    final secondaryText =
        isDark ? Colors.white70 : colorScheme.onSurfaceVariant;
    final highlight = colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              children: [
                TextSpan(
                  text: title,
                  style: GoogleFonts.outfit(
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    color: primaryText,
                    letterSpacing: -1.2,
                    height: 1.1,
                  ),
                ),
                TextSpan(
                  text: highlightedTitle,
                  style: GoogleFonts.outfit(
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    color: highlight,
                    letterSpacing: -1.2,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(duration: 600.ms)
              .slideY(begin: 0.1, curve: Curves.easeOutCubic),
          const SizedBox(height: 24),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: secondaryText,
              height: 1.6,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.2,
            ),
          ).animate(delay: 200.ms).fadeIn(duration: 600.ms),
          if (extra != null) extra!,
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
          color: isSelected
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.1),
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
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
                    ? colorScheme.onPrimary.withValues(alpha: 0.2)
                    : colorScheme.primary.withValues(alpha: 0.1),
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
                      color: isSelected
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: isSelected
                          ? colorScheme.onPrimary.withValues(alpha: 0.8)
                          : colorScheme.onSurface.withValues(alpha: 0.6),
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
    final isDark = colorScheme.brightness == Brightness.dark;

    // Select colors based on theme
    final baseColor =
        isDark ? const Color(0xFF09090B) : const Color(0xFFF8FAFC);
    final glow1 = isDark
        ? Colors.blueAccent.withValues(alpha: 0.15)
        : Colors.blue.withValues(alpha: 0.1);
    final glow2 = isDark
        ? Colors.purpleAccent.withValues(alpha: 0.15)
        : Colors.purple.withValues(alpha: 0.1);
    final glow3 = isDark
        ? Colors.cyanAccent.withValues(alpha: 0.1)
        : Colors.teal.withValues(alpha: 0.1);

    return Stack(
      children: [
        // Base
        Container(color: baseColor),

        // Animated Orbs
        Positioned(
          top: -150,
          right: -100,
          child: _GlowNode(color: glow1, size: 500),
        ),
        Positioned(
          bottom: -150,
          left: -100,
          child: _GlowNode(color: glow2, size: 500),
        ),
        Positioned(
          top: MediaQuery.of(context).size.height * 0.4,
          left: -50,
          child: _GlowNode(color: glow3, size: 400),
        ),

        // Global Glassmorphism Blur Layer
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
            child: Container(color: Colors.transparent),
          ),
        ),
      ],
    );
  }
}

class _GlowNode extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowNode({required this.color, required this.size});

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
            end: const Offset(1.3, 1.3),
            duration: 8.seconds)
        .move(
            begin: const Offset(-20, -20),
            end: const Offset(20, 20),
            duration: 10.seconds);
  }
}
