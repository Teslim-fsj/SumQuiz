import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sumquiz/theme/web_theme.dart';
import 'package:sumquiz/views/screens/web/widgets/landing_tab_toggle.dart';

class StudentLandingView extends StatefulWidget {
  const StudentLandingView({super.key});

  @override
  State<StudentLandingView> createState() => _StudentLandingViewState();
}

class _StudentLandingViewState extends State<StudentLandingView> {
  final ScrollController _scrollController = ScrollController();
  int? _openFaq;
  int _selectedQuizOption = 1; // 1 is correct (Option B)

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            _buildHero(),
            _buildInteractiveShowcase(),
            _buildHowItWorks(),
            _buildFeatureGrid(),
            _buildSumiSpotlight(),
            _buildTestimonials(),
            _buildFaq(),
            _buildCtaBanner(),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ─── Hero Section ─────────────────────────────────────────────────────────────

  Widget _buildHero() {
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 900;
      return Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0C0728), Color(0xFF1B104D), Color(0xFF0F172A)],
          ),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 24 : 80,
          vertical: isMobile ? 36 : 64,
        ),
        child: Column(
          children: [
            // Tab Switcher
            const LandingTabToggle(
              currentTab: LandingTab.student,
              isDark: true,
            ),
            const SizedBox(height: 24),

            // Glowing Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: WebColors.purplePrimary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: WebColors.purplePrimary.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: Color(0xFFA78BFA),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'SUMQUIZ AI STUDY OS · ACTIVE RECALL & NEURAL SYNTHESIS',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: const Color(0xFFC4B5FD),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 250.ms),
            const SizedBox(height: 32),

            // Main Headline
            Text(
              'Study Smarter, Not Harder.\nMaster Any Subject in Minutes.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: isMobile ? 36 : 60,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1.1,
                letterSpacing: -1.0,
              ),
            )
                .animate()
                .fadeIn(delay: 100.ms, duration: 250.ms)
                .slideY(begin: 0.05, end: 0),
            const SizedBox(height: 24),

            // Subheadline
            Text(
              'Upload lecture PDFs, slides, textbook chapters, audio notes, or YouTube links.\nSumQuiz AI transforms your materials into interactive study packs, active-recall quizzes, and smart flashcards instantly.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: isMobile ? 15 : 18,
                color: Colors.white70,
                height: 1.6,
              ),
            ).animate().fadeIn(delay: 150.ms, duration: 250.ms),
            const SizedBox(height: 40),

            // Dual CTA Buttons
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                ElevatedButton(
                  onPressed: () => context.go('/auth'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WebColors.purplePrimary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 24 : 36,
                      vertical: 18,
                    ),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Start Studying for Free',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms),
                OutlinedButton(
                  onPressed: () {
                    _scrollController.animateTo(
                      650,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 24 : 36,
                      vertical: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'See How It Works',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ).animate().fadeIn(delay: 250.ms),
              ],
            ),
            const SizedBox(height: 48),

            // Hero Stats Strip
            Wrap(
              alignment: WrapAlignment.center,
              spacing: isMobile ? 24 : 48,
              runSpacing: 24,
              children: [
                _buildHeroStat('10x', 'Faster Recall & Prep'),
                _buildHeroStatDivider(isMobile),
                _buildHeroStat('98%', 'Exam Pass Rate'),
                _buildHeroStatDivider(isMobile),
                _buildHeroStat('50,000+', 'Active Learners'),
                _buildHeroStatDivider(isMobile),
                _buildHeroStat('100% Free', 'Core Study Tier'),
              ],
            ).animate().fadeIn(delay: 300.ms),
          ],
        ),
      );
    });
  }

  Widget _buildHeroStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.white54,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroStatDivider(bool isMobile) {
    if (isMobile) return const SizedBox.shrink();
    return Container(height: 36, width: 1, color: Colors.white12);
  }

  // ─── Interactive Live 3-Card Showcase ─────────────────────────────────────────

  Widget _buildInteractiveShowcase() {
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 900;
      return Container(
        color: const Color(0xFFF8FAFC),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 20 : 80,
          vertical: isMobile ? 48 : 80,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: WebColors.purplePrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'LIVE STUDY PACK PREVIEW',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: WebColors.purplePrimary,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'One Upload. Complete Mastery Suite.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: isMobile ? 28 : 40,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Everything generated simultaneously from your notes in under 15 seconds.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 48),

            // 3 Live Preview Cards
            isMobile
                ? Column(
                    children: [
                      _buildShowcaseSummaryCard(isMobile),
                      const SizedBox(height: 20),
                      _buildShowcaseQuizCard(isMobile),
                      const SizedBox(height: 20),
                      _buildShowcaseFlashcardCard(isMobile),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildShowcaseSummaryCard(isMobile)),
                      const SizedBox(width: 24),
                      Expanded(child: _buildShowcaseQuizCard(isMobile)),
                      const SizedBox(width: 24),
                      Expanded(child: _buildShowcaseFlashcardCard(isMobile)),
                    ],
                  ),
          ],
        ),
      );
    });
  }

  Widget _buildShowcaseSummaryCard(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_stories_rounded,
                        size: 14, color: Color(0xFF2563EB)),
                    const SizedBox(width: 6),
                    Text(
                      'AI SUMMARY',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF10B981), size: 18),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Cellular Respiration & ATP',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '• Glycolysis breaks glucose down into pyruvate in the cytoplasm, generating a net 2 ATP.\n'
            '• Krebs Cycle produces NADH & FADH2 electron carriers inside the mitochondrial matrix.\n'
            '• Electron Transport Chain generates up to 34 ATP via oxidative phosphorylation.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF475569),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '⚡ Distilled from 34-page textbook chapter',
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShowcaseQuizCard(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: WebColors.purplePrimary.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: WebColors.purplePrimary.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: WebColors.purplePrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.quiz_rounded,
                        size: 14, color: WebColors.purplePrimary),
                    const SizedBox(width: 6),
                    Text(
                      'ACTIVE RECALL QUIZ',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: WebColors.purplePrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Question 3 of 10',
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Where does the Krebs Cycle take place in eukaryotic cells?',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 14),

          _quizOption(
            index: 0,
            text: 'A. Outer mitochondrial membrane',
            isCorrect: false,
          ),
          const SizedBox(height: 8),
          _quizOption(
            index: 1,
            text: 'B. Mitochondrial Matrix',
            isCorrect: true,
          ),
          const SizedBox(height: 8),
          _quizOption(
            index: 2,
            text: 'C. Cytoplasm',
            isCorrect: false,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded,
                  size: 14, color: Color(0xFFD97706)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Sumi Hint: The innermost compartment contains the required enzymes.',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFFB45309),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quizOption({
    required int index,
    required String text,
    required bool isCorrect,
  }) {
    final isSelected = _selectedQuizOption == index;
    return InkWell(
      onTap: () => setState(() => _selectedQuizOption = index),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isCorrect
                  ? const Color(0xFFECFDF5)
                  : const Color(0xFFFEF2F2))
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? (isCorrect
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444))
                : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? (isCorrect
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded)
                  : Icons.radio_button_unchecked_rounded,
              size: 16,
              color: isSelected
                  ? (isCorrect
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444))
                  : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? (isCorrect
                          ? const Color(0xFF065F46)
                          : const Color(0xFF991B1B))
                      : const Color(0xFF334155),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShowcaseFlashcardCard(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.style_rounded,
                        size: 14, color: Color(0xFF7C3AED)),
                    const SizedBox(width: 6),
                    Text(
                      'SRS FLASHCARD',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF7C3AED),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Mastery: 92%',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF15803D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FRONT',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white54,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'What is the function of ATP Synthase in the inner membrane?',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 12),
                Text(
                  'BACK (REVEALED)',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF6EE7B7),
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Uses proton (H+) gradient to phosphorylate ADP into ATP.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _srsButton('Again (1d)', const Color(0xFFEF4444)),
              _srsButton('Good (3d)', const Color(0xFF3B82F6)),
              _srsButton('Easy (7d)', const Color(0xFF10B981)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _srsButton(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  // ─── How It Works (4-Step Workflow) ──────────────────────────────────────────

  Widget _buildHowItWorks() {
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 900;
      return Container(
        color: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 24 : 80,
          vertical: isMobile ? 48 : 80,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'NEURAL STUDY PIPELINE',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: WebColors.purplePrimary,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'How SumQuiz Transforms Your Study Flow',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: isMobile ? 28 : 40,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Go from overwhelming study material to confident mastery in 4 simple steps.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 15, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 56),

            // Steps Grid
            isMobile
                ? Column(
                    children: [
                      _buildStepCard('01', 'Drop Any Material',
                          'Upload PDFs, lecture slides, textbooks, YouTube videos, or take photos of your notes.', Icons.upload_file_rounded),
                      const SizedBox(height: 18),
                      _buildStepCard('02', 'Neural AI Synthesis',
                          'Gemini AI extracts key formulas, terms, and core concepts into structured study outputs.', Icons.psychology_rounded),
                      const SizedBox(height: 18),
                      _buildStepCard('03', 'Active Recall & SRS',
                          'Practice adaptive quizzes and flashcards scheduled automatically based on your retention curve.', Icons.repeat_rounded),
                      const SizedBox(height: 18),
                      _buildStepCard('04', 'Exam Confidence',
                          'Track topic mastery, revisit tricky questions with Sumi AI, and score top marks on exam day.', Icons.emoji_events_rounded),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: _buildStepCard('01', 'Drop Any Material',
                            'Upload PDFs, slides, textbooks, YouTube videos, or photos of your notes.', Icons.upload_file_rounded),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStepCard('02', 'Neural AI Synthesis',
                            'Gemini AI extracts key concepts, formulas, and terms into structured study outputs.', Icons.psychology_rounded),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStepCard('03', 'Active Recall & SRS',
                            'Practice adaptive quizzes and spaced flashcards scheduled to your retention curve.', Icons.repeat_rounded),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStepCard('04', 'Exam Confidence',
                            'Track topic mastery, revisit tricky areas with Sumi, and score top marks on exam day.', Icons.emoji_events_rounded),
                      ),
                    ],
                  ),
          ],
        ),
      );
    });
  }

  Widget _buildStepCard(String number, String title, String desc, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                number,
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: WebColors.purplePrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Icon(icon, color: WebColors.purplePrimary, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF64748B),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Feature Grid Section ───────────────────────────────────────────────────

  Widget _buildFeatureGrid() {
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 900;
      return Container(
        color: const Color(0xFFF8FAFC),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 24 : 80,
          vertical: isMobile ? 48 : 80,
        ),
        child: Column(
          children: [
            Text(
              'Engineered for Peak Study Performance',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: isMobile ? 28 : 40,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Everything you need to study deeper, remember longer, and eliminate exam anxiety.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 15, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 48),

            isMobile
                ? Column(
                    children: _featureCards()
                        .map((c) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: c,
                            ))
                        .toList(),
                  )
                : GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 24,
                    mainAxisSpacing: 24,
                    childAspectRatio: 1.15,
                    children: _featureCards(),
                  ),
          ],
        ),
      );
    });
  }

  List<Widget> _featureCards() {
    return [
      _featureCard(
        icon: Icons.summarize_rounded,
        iconBg: const Color(0xFFEFF6FF),
        iconColor: const Color(0xFF2563EB),
        badge: 'SYNTHESIS',
        title: 'Instant Executive Summaries',
        desc: 'Converts 50+ page PDFs, books, and lecture slides into clear key concepts and bullet takeaways.',
        bullets: ['Eliminates fluff', 'Highlights formulas & terms', 'Saves 80% reading time'],
      ),
      _featureCard(
        icon: Icons.quiz_rounded,
        iconBg: const Color(0xFFF3E8FF),
        iconColor: const Color(0xFF7C3AED),
        badge: 'ACTIVE RECALL',
        title: 'Adaptive Quizzes & Mock Exams',
        desc: 'Tests your understanding with custom multiple choice, short answer, and theory questions.',
        bullets: ['Instant answer explanations', 'Difficulty calibration', 'Exam simulation mode'],
      ),
      _featureCard(
        icon: Icons.style_rounded,
        iconBg: const Color(0xFFECFDF5),
        iconColor: const Color(0xFF059669),
        badge: 'SPACED REPETITION',
        title: 'Smart Spaced Repetition (SRS)',
        desc: 'Algorithms prompt you to review flashcards right before you forget them for permanent retention.',
        bullets: ['SM-2 repetition algorithm', 'Interactive 3D card flips', 'Topic mastery scores'],
      ),
      _featureCard(
        icon: Icons.smart_toy_rounded,
        iconBg: const Color(0xFFFFFBEB),
        iconColor: const Color(0xFFD97706),
        badge: 'AI TUTOR',
        title: 'Sumi AI Companion Tutor',
        desc: 'An AI study companion that guides your learning with Socratic hints and encouragement.',
        bullets: ['Step-by-step hints', 'Explains wrong answers', 'Adaptive study challenges'],
      ),
      _featureCard(
        icon: Icons.play_circle_fill_rounded,
        iconBg: const Color(0xFFFEF2F2),
        iconColor: const Color(0xFFDC2626),
        badge: 'MULTI-SOURCE',
        title: 'YouTube & Audio Extraction',
        desc: 'Paste a YouTube lecture link or upload voice memos to automatically extract full study decks.',
        bullets: ['Transcript extraction', 'Timestamped key points', 'Audio lecture parsing'],
      ),
      _featureCard(
        icon: Icons.devices_rounded,
        iconBg: const Color(0xFFF0FDF4),
        iconColor: const Color(0xFF16A34A),
        badge: 'EVERYWHERE',
        title: 'Offline & Multi-Device Sync',
        desc: 'Access all your study packs across web and mobile. Practice anywhere, anytime even offline.',
        bullets: ['Offline local storage', 'Cross-device cloud backup', 'One-tap deck sharing'],
      ),
    ];
  }

  Widget _featureCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String badge,
    required String title,
    required String desc,
    required List<String> bullets,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: iconColor,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          ...bullets.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.check_rounded, size: 14, color: iconColor),
                    const SizedBox(width: 6),
                    Text(
                      b,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ─── Sumi Spotlight ─────────────────────────────────────────────────────────

  Widget _buildSumiSpotlight() {
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 900;
      return Container(
        color: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 24 : 80,
          vertical: isMobile ? 48 : 80,
        ),
        child: Container(
          padding: EdgeInsets.all(isMobile ? 24 : 48),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F0B2D), Color(0xFF1E1048), Color(0xFF0F172A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: WebColors.purplePrimary.withValues(alpha: 0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: isMobile
              ? Column(
                  children: [
                    _buildSumiContent(isMobile),
                    const SizedBox(height: 32),
                    _buildSumiPreviewCard(),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: _buildSumiContent(isMobile)),
                    const SizedBox(width: 48),
                    Expanded(child: _buildSumiPreviewCard()),
                  ],
                ),
        ),
      );
    });
  }

  // ─── Sumi Spotlight Helpers ───────────────────────────────────────────────

  Widget _buildSumiContent(bool isMobile) {
    return Column(
      crossAxisAlignment:
          isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFA78BFA).withValues(alpha: 0.4),
            ),
          ),
          child: Text(
            'MEET SUMI · YOUR 24/7 AI TUTOR',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: const Color(0xFFC4B5FD),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'A study companion that actually knows your syllabus',
          textAlign: isMobile ? TextAlign.center : TextAlign.start,
          style: GoogleFonts.outfit(
            fontSize: isMobile ? 24 : 36,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.5,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Sumi is grounded in your uploaded materials, tracks what you haven\'t mastered, and intervenes before you fail.',
          textAlign: isMobile ? TextAlign.center : TextAlign.start,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.grey[400],
            height: 1.6,
          ),
        ),
        const SizedBox(height: 24),
        _buildSumiBullet(Icons.mic_none, 'Voice-to-voice tutoring',
            'Talk to Sumi aloud — on the bus, in bed, anywhere.'),
        const SizedBox(height: 12),
        _buildSumiBullet(Icons.psychology_outlined, 'Socratic questioning mode',
            'Sumi asks guiding questions to force active recall.'),
        const SizedBox(height: 12),
        _buildSumiBullet(
            Icons.notifications_active_outlined,
            'Proactive decay alerts',
            'Sumi notifies you the moment a topic enters the danger zone.'),
        const SizedBox(height: 28),
        ElevatedButton(
          onPressed: () => context.go('/auth'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED),
            foregroundColor: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            'Study with Sumi Free',
            style:
                GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      ],
    );
  }

  Widget _buildSumiBullet(IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFFA78BFA), size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  )),
              const SizedBox(height: 2),
              Text(desc,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[500],
                    height: 1.5,
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSumiPreviewCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B4B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFA78BFA).withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6D28D9).withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.psychology,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sumi',
                      style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  Text('AI Tutor · Online',
                      style: GoogleFonts.inter(
                          fontSize: 10, color: Colors.grey[500])),
                ],
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: Color(0xFF10B981), shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildChatBubble(
              'Can you explain enzyme inhibition using my biochem notes?',
              isUser: true),
          const SizedBox(height: 10),
          _buildChatBubble(
              'Of course! Based on your Week 5 slides, competitive inhibitors bind to the active site, blocking substrate access. Think of it like a wrong key stuck in a lock. Want a practice question?',
              isUser: false),
          const SizedBox(height: 10),
          _buildChatBubble('Yes, test me!', isUser: true),
          const SizedBox(height: 16),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text('Ask Sumi anything...',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: Colors.grey[600])),
                ),
                const Icon(Icons.mic_none,
                    color: Color(0xFFA78BFA), size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(String text, {required bool isUser}) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFF7C3AED)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: isUser ? Colors.white : Colors.grey[300],
            height: 1.5,
          ),
        ),
      ),
    );
  }

  // ─── Testimonials Section ──────────────────────────────────────────────────

  Widget _buildTestimonials() {
    final testimonials = [
      (
        quote:
            'SumQuiz turned my messy lecture notes into clear, usable quizzes. It\'s the reason I passed my last semester with a first class.',
        name: 'David Okafor',
        school: 'University of Lagos',
      ),
      (
        quote:
            'The flashcard system is addictive. I study for 20-30 mins on the bus, and the information actually stays in my head permanently.',
        name: 'Aisha Yusuf',
        school: 'Ahmadu Bello University',
      ),
      (
        quote:
            'I uploaded my 200-level biochem slides and Sumi Tutor explained every diagram to me like a real teacher. I\'ve never understood enzyme kinetics this well.',
        name: 'Faruk Adebayo',
        school: 'Obafemi Awolowo University',
      ),
      (
        quote:
            'The daily study missions keep me consistent. I\'ve never felt this confident about my final professional exams before.',
        name: 'Chioma Nwachukwu',
        school: 'University of Nigeria, Nsukka',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 900;
        final hPad = isMobile ? 24.0 : 80.0;
        return Container(
          width: double.infinity,
          color: const Color(0xFFF8FAFC),
          padding: EdgeInsets.symmetric(
              horizontal: hPad, vertical: isMobile ? 60 : 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('THE AI STUDY OS IN ACTION',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: WebColors.purplePrimary)),
              const SizedBox(height: 12),
              Text('18,000+ students. One AI Study OS.',
                  style: GoogleFonts.outfit(
                      fontSize: isMobile ? 28 : 40,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                      color: const Color(0xFF0F172A))),
              const SizedBox(height: 48),
              if (isMobile)
                Column(
                  children: testimonials
                      .map((t) => Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: _buildTestimonialCard(
                                t.quote, t.name, t.school),
                          ))
                      .toList(),
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: testimonials
                      .map((t) => Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: _buildTestimonialCard(
                                  t.quote, t.name, t.school),
                            ),
                          ))
                      .toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTestimonialCard(String quote, String name, String school) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(
              5,
              (index) =>
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '"$quote"',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF334155),
              height: 1.6,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              CircleAvatar(
                backgroundColor: WebColors.purplePrimary.withValues(alpha: 0.1),
                radius: 16,
                child: const Icon(Icons.person_rounded,
                    color: WebColors.purplePrimary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      school,
                      style: GoogleFonts.inter(
                          fontSize: 11, color: Colors.grey[500]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── FAQ Section ───────────────────────────────────────────────────────────

  Widget _buildFaq() {
    final faqs = [
      (
        q: 'How does SumQuiz create quizzes and flashcards from my notes?',
        a: 'Our DeepScan AI engine analyzes your uploaded PDFs, lecture recordings, YouTube links, and handwritten notes, extracts core concepts, and converts them into syllabus-aligned quizzes, flashcards, and summaries in seconds.'
      ),
      (
        q: 'Is SumQuiz completely free to get started?',
        a: 'Yes! Every student gets starting Neural Capacity compute units for free to upload materials, generate quizzes, review flashcards, and chat with Sumi Tutor.'
      ),
      (
        q: 'How does Sumi AI Tutor help me study?',
        a: 'Sumi is your personal 24/7 AI tutor. You can chat via text or speak voice-to-voice. Sumi uses Socratic questioning to explain hard concepts, break down slides, and test your understanding.'
      ),
      (
        q: 'What is Spaced Repetition (SRS) and Adaptive Learning?',
        a: 'Our ALPS (Adaptive Learning & Pathway Scheduling) system tracks your memory decay curve and schedules daily review cards at the exact scientific moment before you forget them.'
      ),
      (
        q: 'Can I study on my phone and my laptop?',
        a: 'Yes! Everything you upload and study automatically syncs seamlessly between the SumQuiz Web portal and our mobile apps.'
      ),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 900;
      final hPad = isMobile ? 24.0 : 80.0;
      return Container(
        width: double.infinity,
        color: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: hPad,
          vertical: isMobile ? 60 : 100,
        ),
        child: Column(
          children: [
            Text('FREQUENTLY ASKED QUESTIONS',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: WebColors.purplePrimary)),
            const SizedBox(height: 12),
            Text(
              'Everything you need to know about SumQuiz',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: isMobile ? 28 : 40,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 48),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                children: faqs.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final faq = entry.value;
                  final isOpen = _openFaq == idx;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isOpen
                            ? WebColors.purplePrimary
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _openFaq = isOpen ? null : idx;
                        });
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    faq.q,
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                Icon(
                                  isOpen
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  color: isOpen
                                      ? WebColors.purplePrimary
                                      : Colors.grey,
                                ),
                              ],
                            ),
                            if (isOpen) ...[
                              const SizedBox(height: 12),
                              Text(
                                faq.a,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      );
    });
  }

  // ─── CTA Banner ───────────────────────────────────────────────────────────

  Widget _buildCtaBanner() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 900;
        final hPad = isMobile ? 24.0 : 80.0;
        return Container(
          color: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 60),
          child: Container(
            padding: EdgeInsets.all(isMobile ? 32 : 56),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0C0728),
                  Color(0xFF1B104D),
                  Color(0xFF25136B)
                ],
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: WebColors.purplePrimary.withValues(alpha: 0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                )
              ],
            ),
            child: Column(
              children: [
                Text(
                  'Power up your studying with the AI Study OS',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: isMobile ? 26 : 40,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Upload anything. Get instant notes, quizzes, and flashcards. Let Sumi Tutor guide you to mastery with Adaptive Learning Paths and Spaced Repetition.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: isMobile ? 14 : 16,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 36),
                ElevatedButton(
                  onPressed: () => context.go('/auth'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: WebColors.purplePrimary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 20),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    'Get Started for Free',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Colors.white70, size: 14),
                    const SizedBox(width: 8),
                    Text(
                      'No credit card needed',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: Colors.white70),
                    ),
                    const SizedBox(width: 24),
                    const Icon(Icons.check_circle_rounded,
                        color: Colors.white70, size: 14),
                    const SizedBox(width: 8),
                    Text(
                      'Free forever tier',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Footer ───────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 900;
        final hPad = isMobile ? 24.0 : 80.0;
        return Container(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 60),
          color: const Color(0xFF0F172A),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Image.asset('assets/images/sumquiz_logo.png',
                            width: 24,
                            height: 24,
                            color: Colors.white,
                            errorBuilder: (_, __, ___) => const Icon(
                                Icons.school_rounded,
                                color: Colors.white,
                                size: 24)),
                        const SizedBox(width: 8),
                        Text('SumQuiz',
                            style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                        'Empowering the next generation of scholars through AI.',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.grey[400],
                            height: 1.6)),
                    const SizedBox(height: 32),
                    _footerCol('COMPANY', [
                      'About Us',
                      'Careers',
                      'Privacy Policy',
                      'Terms of Service'
                    ]),
                    const SizedBox(height: 24),
                    _footerCol('RESOURCES', [
                      'Academic Library',
                      'Study Guides',
                      'Success Stories',
                      'Help Center'
                    ]),
                    const SizedBox(height: 32),
                    Text('© 2026 SumQuiz AI Labs. All rights reserved.',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: Colors.grey[600])),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Image.asset('assets/images/sumquiz_logo.png',
                                  width: 24,
                                  height: 24,
                                  color: Colors.white,
                                  errorBuilder: (_, __, ___) => const Icon(
                                      Icons.school_rounded,
                                      color: Colors.white,
                                      size: 24)),
                              const SizedBox(width: 8),
                              Text('SumQuiz',
                                  style: GoogleFonts.outfit(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: -0.5)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                              'Empowering the next generation of\nscholars through cutting-edge AI technology\nand personalized learning paths.',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.grey[400],
                                  height: 1.6)),
                          const SizedBox(height: 32),
                          Text('© 2026 SumQuiz AI Labs. All rights reserved.',
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: _footerCol('COMPANY', [
                        'About Us',
                        'Careers',
                        'Privacy Policy',
                        'Terms of Service'
                      ]),
                    ),
                    Expanded(
                      flex: 1,
                      child: _footerCol('RESOURCES', [
                        'Academic Library',
                        'Study Guides',
                        'Success Stories',
                        'Help Center'
                      ]),
                    ),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('AI STUDY OS',
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                  color: Colors.white)),
                          const SizedBox(height: 16),
                          Text(
                              'Instant study sets, active recall, and 24/7 AI tutoring.',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.grey[400],
                                  height: 1.5)),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _footerCol(String title, List<String> links) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: Colors.white)),
        const SizedBox(height: 16),
        ...links.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(e,
                  style:
                      GoogleFonts.inter(fontSize: 12, color: Colors.grey[400])),
            )),
      ],
    );
  }
}
