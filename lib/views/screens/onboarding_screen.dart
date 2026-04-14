import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  static const int _totalPages = 4; // 3 showcase + 1 role selection

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
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _prev() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  // ───────────────────────────────────────────────────────────
  //  BUILD
  // ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        children: [
          // Subtle gradient background orbs
          _BackgroundOrbs(colorScheme: cs),

          // Pages
          PageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            children: [
              _PageFeatureShowcase(colorScheme: cs),
              _PageStartWithAnything(colorScheme: cs),
              _PageUnfairAdvantage(colorScheme: cs),
              _buildRoleSelection(theme),
            ],
          ),

          // Top bar: Logo + Sign In
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 24,
            right: 24,
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'SumQuiz',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: cs.primary,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _finishOnboarding,
                  child: Text(
                    'Sign In',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom controls
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: _buildBottomControls(cs),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────
  //  BOTTOM CONTROLS
  // ───────────────────────────────────────────────────────────
  Widget _buildBottomControls(ColorScheme cs) {
    final isLastPage = _currentPage == _totalPages - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _totalPages,
              (i) => AnimatedContainer(
                duration: 300.ms,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 6,
                width: _currentPage == i ? 24 : 6,
                decoration: BoxDecoration(
                  color: _currentPage == i
                      ? cs.primary
                      : cs.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Navigation Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back arrow (hidden on first page)
              AnimatedOpacity(
                opacity: _currentPage > 0 ? 1.0 : 0.0,
                duration: 200.ms,
                child: IconButton(
                  onPressed: _currentPage > 0 ? _prev : null,
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: cs.onSurface.withOpacity(0.5),
                  ),
                ),
              ),
              // Forward / Get Started button
              AnimatedContainer(
                duration: 300.ms,
                width: isLastPage ? 200 : 56,
                height: 56,
                child: ElevatedButton(
                  onPressed: isLastPage
                      ? (_selectedRole != null ? _finishOnboarding : null)
                      : _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 6,
                    shadowColor: cs.primary.withOpacity(0.4),
                    padding: EdgeInsets.zero,
                  ),
                  child: AnimatedSwitcher(
                    duration: 200.ms,
                    child: isLastPage
                        ? Text(
                            _selectedRole == null
                                ? 'Select a role'
                                : 'Get Started',
                            key: const ValueKey('text'),
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          )
                        : const Icon(Icons.arrow_forward_rounded,
                            key: ValueKey('icon'), size: 26),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────
  //  PAGE 4: ROLE SELECTION
  // ───────────────────────────────────────────────────────────
  Widget _buildRoleSelection(ThemeData theme) {
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'How will you use\nSumQuiz?',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: cs.onSurface,
              height: 1.2,
            ),
          ).animate().fadeIn().slideY(begin: 0.15),
          const SizedBox(height: 12),
          Text(
            'We\'ll tailor your experience.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 15,
              color: cs.onSurface.withOpacity(0.6),
            ),
          ).animate(delay: 100.ms).fadeIn(),
          const SizedBox(height: 48),
          _RoleCard(
            role: UserRole.student,
            selected: _selectedRole == UserRole.student,
            title: 'I\'m a Student',
            subtitle: 'Study smarter, master subjects.',
            icon: Icons.school_outlined,
            colorScheme: cs,
            onTap: () => setState(() => _selectedRole = UserRole.student),
          ).animate(delay: 200.ms).fadeIn().slideX(begin: -0.15),
          const SizedBox(height: 16),
          _RoleCard(
            role: UserRole.creator,
            selected: _selectedRole == UserRole.creator,
            title: 'I\'m a Teacher',
            subtitle: 'Create exams, track students.',
            icon: Icons.assignment_ind_outlined,
            colorScheme: cs,
            onTap: () => setState(() => _selectedRole = UserRole.creator),
          ).animate(delay: 300.ms).fadeIn().slideX(begin: 0.15),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  PAGE 1: FEATURE SHOWCASE
// ═════════════════════════════════════════════════════════════
class _PageFeatureShowcase extends StatelessWidget {
  final ColorScheme colorScheme;
  const _PageFeatureShowcase({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 72),

          // Hero headline
          Text(
            'Everything You\nNeed to Ace.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 38,
              fontWeight: FontWeight.w900,
              color: cs.onSurface,
              height: 1.1,
              letterSpacing: -1,
            ),
          ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1),
          const SizedBox(height: 16),
          Text(
            'Master complex topics with hyper-summaries,\nadaptive quizzes, and smart flashcards.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: cs.onSurface.withOpacity(0.55),
              height: 1.5,
            ),
          ).animate(delay: 100.ms).fadeIn(),
          const SizedBox(height: 40),

          // CONCEPT SUMMARY card
          _GlassCard(
            colorScheme: cs,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.description_outlined,
                        size: 18, color: cs.tertiary),
                    const SizedBox(width: 8),
                    Text(
                      'CONCEPT SUMMARY',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: cs.tertiary,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Neural Plasticity',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                _BulletPoint(
                  text: 'Brain\'s ability to ',
                  highlight: 'reorganize',
                  suffix: ' pathways.',
                  colorScheme: cs,
                ),
                const SizedBox(height: 6),
                _BulletPoint(
                  text: 'Synaptic pruning optimizes neural efficiency.',
                  colorScheme: cs,
                ),
              ],
            ),
          ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.08),
          const SizedBox(height: 16),

          // DAILY QUIZ card
          _GlassCard(
            colorScheme: cs,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.quiz_outlined, size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    Text(
                      'DAILY QUIZ',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '75%',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: cs.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Which neurotransmitter is most associated with long-term potentiation?',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _QuizOption(label: 'Glutamate', selected: true, cs: cs),
                    const SizedBox(width: 10),
                    _QuizOption(label: 'Dopamine', selected: false, cs: cs),
                  ],
                ),
              ],
            ),
          ).animate(delay: 350.ms).fadeIn().slideY(begin: 0.08),
          const SizedBox(height: 16),

          // SMART FLASHCARD card
          _GlassCard(
            colorScheme: cs,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.style_outlined, size: 18, color: cs.error),
                    const SizedBox(width: 8),
                    Text(
                      'SMART FLASHCARD',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: cs.error,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.tertiary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle,
                              size: 12, color: cs.tertiary),
                          const SizedBox(width: 4),
                          Text(
                            'MASTERY',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: cs.tertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'QUESTION',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: cs.primary.withOpacity(0.6),
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Define \'Hebbian Theory\' in one sentence.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate(delay: 500.ms).fadeIn().slideY(begin: 0.08),

          // CTA button
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Center(
              child: Text(
                'Start Free Trial',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: cs.primary,
                ),
              ),
            ),
          ).animate(delay: 650.ms).fadeIn(),
          const SizedBox(height: 8),
          Text(
            'UNLOCK UNLIMITED ACCESS FOR \$9.99/MO',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withOpacity(0.35),
              letterSpacing: 1,
            ),
          ).animate(delay: 700.ms).fadeIn(),
          const SizedBox(height: 120),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  PAGE 2: START WITH ANYTHING
// ═════════════════════════════════════════════════════════════
class _PageStartWithAnything extends StatelessWidget {
  final ColorScheme colorScheme;
  const _PageStartWithAnything({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),

          // Headline
          Text(
            'Start with',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 38,
              fontWeight: FontWeight.w900,
              color: cs.onSurface,
              height: 1.1,
              letterSpacing: -1,
            ),
          ).animate().fadeIn().slideY(begin: 0.1),
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [cs.primary, cs.tertiary, cs.error],
            ).createShader(bounds),
            child: Text(
              'Anything.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 38,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1.1,
                letterSpacing: -1,
              ),
            ),
          ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.1),
          const SizedBox(height: 20),
          Text(
            'No more formatting. Paste a link or\nupload a file and watch the AI do the\nheavy lifting.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: cs.onSurface.withOpacity(0.55),
              height: 1.6,
            ),
          ).animate(delay: 200.ms).fadeIn(),

          const Spacer(),

          // Input mockup
          _GlassCard(
            colorScheme: cs,
            child: Row(
              children: [
                Icon(Icons.link_rounded,
                    size: 20, color: cs.onSurface.withOpacity(0.4)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Paste any link…',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      color: cs.onSurface.withOpacity(0.35),
                    ),
                  ),
                ),
                _InputTypeIcon(icon: Icons.picture_as_pdf_rounded, cs: cs),
                const SizedBox(width: 8),
                _InputTypeIcon(icon: Icons.play_arrow_rounded, cs: cs),
                const SizedBox(width: 8),
                _InputTypeIcon(
                    icon: Icons.play_circle_filled_rounded,
                    cs: cs,
                    isAccent: true),
              ],
            ),
          ).animate(delay: 350.ms).fadeIn().scale(begin: const Offset(0.95, 0.95)),

          const SizedBox(height: 24),

          // Generate button mockup
          Container(
            width: 180,
            height: 52,
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Center(
              child: Text(
                'Generate',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: cs.primary,
                ),
              ),
            ),
          ).animate(delay: 450.ms).fadeIn(),

          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  PAGE 3: UNFAIR ACADEMIC ADVANTAGE
// ═════════════════════════════════════════════════════════════
class _PageUnfairAdvantage extends StatelessWidget {
  final ColorScheme colorScheme;
  const _PageUnfairAdvantage({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 72),

          // Elite member card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cs.surfaceVariant,
                  cs.surfaceVariant.withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: cs.primary.withOpacity(0.15),
              ),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withOpacity(0.08),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              children: [
                // Top row: sparkle + badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(Icons.auto_awesome, color: cs.primary, size: 22),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'ELITE MEMBER',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: cs.primary,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Cap icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.primary.withOpacity(0.12),
                  ),
                  child: Icon(Icons.school_rounded,
                      color: cs.primary, size: 40),
                ),
                const SizedBox(height: 20),

                Text(
                  'ACADEMIC RANK',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withOpacity(0.45),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Superhuman',
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 24),

                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: 0.85,
                    minHeight: 6,
                    backgroundColor: cs.onSurface.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation(cs.primary),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'COURSES MASTERED',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface.withOpacity(0.4),
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      '85% COMPLETE',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(duration: 600.ms).scale(
                begin: const Offset(0.92, 0.92),
                curve: Curves.easeOutBack,
              ),

          const SizedBox(height: 48),

          // Headline
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: GoogleFonts.outfit(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: cs.onSurface,
                height: 1.15,
                letterSpacing: -0.5,
              ),
              children: [
                const TextSpan(text: 'Your '),
                TextSpan(
                  text: 'Unfair',
                  style: GoogleFonts.outfit(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    color: cs.primary,
                    height: 1.15,
                  ),
                ),
                const TextSpan(text: ' Academic\nAdvantage.'),
              ],
            ),
          ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.1),
          const SizedBox(height: 20),
          Text(
            'Join 100k+ students at Stanford, MIT, and\nOxford using SumQuiz to master courses in\nhalf the time.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: cs.onSurface.withOpacity(0.55),
              height: 1.6,
            ),
          ).animate(delay: 300.ms).fadeIn(),
          const SizedBox(height: 28),

          // University badges
          Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: ['STANFORD', 'MIT', 'OXFORD', 'HARVARD'].map((name) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    name,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withOpacity(0.45),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              );
            }).toList(),
          ).animate(delay: 400.ms).fadeIn(),

          const SizedBox(height: 36),

          // CTA
          Container(
            width: 220,
            height: 56,
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Claim My Edge',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded,
                      color: cs.primary, size: 20),
                ],
              ),
            ),
          ).animate(delay: 500.ms).fadeIn(),

          const SizedBox(height: 120),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  SHARED COMPONENTS
// ═════════════════════════════════════════════════════════════

class _BackgroundOrbs extends StatelessWidget {
  final ColorScheme colorScheme;
  const _BackgroundOrbs({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return Stack(
      children: [
        Positioned(
          top: -80,
          right: -80,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primary.withOpacity(0.06),
            ),
          ),
        ),
        Positioned(
          bottom: 100,
          left: -60,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.tertiary.withOpacity(0.04),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  final ColorScheme colorScheme;
  final Widget child;
  const _GlassCard({required this.colorScheme, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.08),
        ),
      ),
      child: child,
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final String text;
  final String? highlight;
  final String? suffix;
  final ColorScheme colorScheme;

  const _BulletPoint({
    required this.text,
    this.highlight,
    this.suffix,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: highlight != null
              ? RichText(
                  text: TextSpan(
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: cs.onSurface.withOpacity(0.7),
                      height: 1.4,
                    ),
                    children: [
                      TextSpan(text: text),
                      TextSpan(
                        text: highlight,
                        style: TextStyle(
                          color: cs.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (suffix != null) TextSpan(text: suffix),
                    ],
                  ),
                )
              : Text(
                  text,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: cs.onSurface.withOpacity(0.7),
                    height: 1.4,
                  ),
                ),
        ),
      ],
    );
  }
}

class _QuizOption extends StatelessWidget {
  final String label;
  final bool selected;
  final ColorScheme cs;
  const _QuizOption(
      {required this.label, required this.selected, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withOpacity(0.15)
              : cs.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? cs.primary.withOpacity(0.3)
                : cs.outline.withOpacity(0.1),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? cs.primary
                  : cs.onSurface.withOpacity(0.6),
            ),
          ),
        ),
      ),
    );
  }
}

class _InputTypeIcon extends StatelessWidget {
  final IconData icon;
  final ColorScheme cs;
  final bool isAccent;
  const _InputTypeIcon(
      {required this.icon, required this.cs, this.isAccent = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isAccent
            ? cs.error.withOpacity(0.12)
            : cs.onSurface.withOpacity(0.08),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 18,
        color: isAccent
            ? cs.error
            : cs.onSurface.withOpacity(0.4),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final UserRole role;
  final bool selected;
  final String title;
  final String subtitle;
  final IconData icon;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _RoleCard({
    required this.role,
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 300.ms,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withOpacity(0.1)
              : cs.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? cs.primary
                : cs.outline.withOpacity(0.15),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: cs.primary.withOpacity(0.1),
                    blurRadius: 12,
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
                color: selected
                    ? cs.primary
                    : cs.onSurface.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: selected ? cs.onPrimary : cs.onSurface.withOpacity(0.6),
                size: 28,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: selected ? cs.primary : cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: cs.onSurface.withOpacity(0.55),
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: cs.primary, size: 24)
                  .animate()
                  .scale(begin: const Offset(0.5, 0.5)),
          ],
        ),
      ),
    );
  }
}
