import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sumquiz/views/screens/web/widgets/landing_tab_toggle.dart';

class EducatorLandingView extends StatefulWidget {
  const EducatorLandingView({super.key});

  @override
  State<EducatorLandingView> createState() => _EducatorLandingViewState();
}

class _EducatorLandingViewState extends State<EducatorLandingView> {
  final ScrollController _scrollController = ScrollController();
  int? _openFaq;

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
            _buildBenefits(),
            _buildHowItWorks(),
            _buildDeepScanShowcase(),
            _buildFaq(),
            _buildCta(),
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
            colors: [Color(0xFF09101F), Color(0xFF111E38), Color(0xFF0B1329)],
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
              currentTab: LandingTab.educator,
              isDark: true,
            ),
            const SizedBox(height: 28),

            // Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.workspace_premium_rounded,
                    size: 16,
                    color: Color(0xFF60A5FA),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'SUMQUIZ FOR EDUCATORS & INSTITUTIONS',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: const Color(0xFF93C5FD),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 250.ms),
            const SizedBox(height: 32),

            // Headline
            Text(
              'Empower Your Teaching.\nAssess & Engage in Seconds.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: isMobile ? 36 : 58,
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
              'Upload your syllabus, lecture slides, or textbook chapters. Our DeepScan AI\ngenerates structured assessments, flashcards, and student comprehension analytics instantly.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: isMobile ? 15 : 18,
                color: Colors.white70,
                height: 1.6,
              ),
            ).animate().fadeIn(delay: 150.ms, duration: 250.ms),
            const SizedBox(height: 40),

            // CTA Buttons
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                ElevatedButton(
                  onPressed: () => context.go('/auth'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
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
                        'Start Teaching Free',
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
                  onPressed: () => context.go('/auth'),
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
                    'Explore Classroom Tools',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ).animate().fadeIn(delay: 250.ms),
              ],
            ),
            const SizedBox(height: 48),

            // Hero Stats
            Wrap(
              alignment: WrapAlignment.center,
              spacing: isMobile ? 24 : 48,
              runSpacing: 24,
              children: [
                _buildHeroStat('99.4%', 'Extraction Accuracy'),
                _buildHeroStatDivider(isMobile),
                _buildHeroStat('10x', 'Faster Prep Time'),
                _buildHeroStatDivider(isMobile),
                _buildHeroStat('Free', 'Educator Tier'),
                _buildHeroStatDivider(isMobile),
                _buildHeroStat('Instant', 'Classroom Sync'),
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

  // ─── Benefits Section ─────────────────────────────────────────────────────────

  Widget _buildBenefits() {
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
              'Why Educators Choose SumQuiz',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: isMobile ? 28 : 40,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'A complete AI-assisted instructional suite engineered for instructors, departments, and academic institutions.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 48),
            isMobile
                ? Column(
                    children: _benefitCards()
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
                    childAspectRatio: 1.1,
                    children: _benefitCards(),
                  ),
          ],
        ),
      );
    });
  }

  List<Widget> _benefitCards() {
    final benefits = [
      (
        icon: Icons.auto_awesome_rounded,
        title: 'Automated Assessments',
        desc:
            'Generate comprehensive quizzes, multiple-choice tests, and exam papers with detailed answer keys in seconds.',
      ),
      (
        icon: Icons.picture_as_pdf_rounded,
        title: 'DeepScan Technology',
        desc:
            'Upload complex lecture slides, syllabuses, and handwritten formulas without losing formatting or context.',
      ),
      (
        icon: Icons.insights_rounded,
        title: 'Real-Time Class Insights',
        desc:
            'Monitor student progress, identify comprehension bottlenecks, and pinpoint weak topics before exam day.',
      ),
      (
        icon: Icons.hub_rounded,
        title: 'One-Click Distribution',
        desc:
            'Share curated study packs, notes, and flashcard sets directly to student devices using simple join codes.',
      ),
      (
        icon: Icons.psychology_rounded,
        title: 'Custom AI Tutor (Sumi)',
        desc:
            'Equip your students with a 24/7 AI tutor grounded specifically in your curriculum and approved course notes.',
      ),
      (
        icon: Icons.workspace_premium_rounded,
        title: 'Teacher Pro Access',
        desc:
            'Accredited educators and academic creators receive full access to high-volume AI generation tools for free.',
      ),
    ];

    return benefits
        .map(
          (b) => _buildBenefitCard(
            icon: b.icon,
            title: b.title,
            desc: b.desc,
          ),
        )
        .toList();
  }

  Widget _buildBenefitCard({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF2563EB), size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─── How It Works Section ─────────────────────────────────────────────────────

  Widget _buildHowItWorks() {
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 900;
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 24 : 80,
          vertical: isMobile ? 48 : 80,
        ),
        child: Column(
          children: [
            Text(
              'How It Works',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: isMobile ? 28 : 40,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Four intuitive steps to transform your curriculum into interactive study materials.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 48),
            isMobile
                ? Column(
                    children: [
                      _buildStep(
                        1,
                        'Upload Syllabus',
                        'Drop your PDFs, slides, textbook chapters, or YouTube lecture links.',
                        Icons.upload_file_rounded,
                      ),
                      _buildStepConnectorV(),
                      _buildStep(
                        2,
                        'AI Generates Material',
                        'DeepScan extracts concepts and generates quizzes, flashcards, and summaries.',
                        Icons.auto_awesome_rounded,
                      ),
                      _buildStepConnectorV(),
                      _buildStep(
                        3,
                        'Distribute to Students',
                        'Share via simple join codes or links for immediate access across devices.',
                        Icons.share_rounded,
                      ),
                      _buildStepConnectorV(),
                      _buildStep(
                        4,
                        'Review Performance',
                        'Track class comprehension heatmaps and export detailed grade reports.',
                        Icons.analytics_rounded,
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildStep(
                          1,
                          'Upload Syllabus',
                          'Drop your PDFs, slides, textbook chapters, or lecture links.',
                          Icons.upload_file_rounded,
                        ),
                      ),
                      _buildStepConnectorH(),
                      Expanded(
                        child: _buildStep(
                          2,
                          'AI Generates',
                          'DeepScan extracts concepts and builds study materials.',
                          Icons.auto_awesome_rounded,
                        ),
                      ),
                      _buildStepConnectorH(),
                      Expanded(
                        child: _buildStep(
                          3,
                          'Distribute',
                          'Share via simple join codes or links with your students.',
                          Icons.share_rounded,
                        ),
                      ),
                      _buildStepConnectorH(),
                      Expanded(
                        child: _buildStep(
                          4,
                          'Review Insights',
                          'Track comprehension heatmaps and export grade reports.',
                          Icons.analytics_rounded,
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      );
    });
  }

  Widget _buildStep(int number, String title, String desc, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '$number',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Icon(icon, color: Colors.grey[400], size: 24),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnectorH() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Icon(Icons.arrow_forward_rounded, color: Colors.grey[300], size: 20),
    );
  }

  Widget _buildStepConnectorV() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Icon(Icons.arrow_downward_rounded, color: Colors.grey[300], size: 20),
    );
  }

  // ─── DeepScan Showcase Section ────────────────────────────────────────────────

  Widget _buildDeepScanShowcase() {
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 900;
      return Container(
        color: const Color(0xFFF1F5F9),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 24 : 80,
          vertical: isMobile ? 48 : 80,
        ),
        child: Column(
          children: [
            Text(
              'High-Fidelity Document Intelligence',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: isMobile ? 28 : 40,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'SumQuiz DeepScan parses mathematical expressions, scientific formulas, tables, and multi-column textbooks with rigorous precision.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 48),
            Container(
              padding: EdgeInsets.all(isMobile ? 20 : 40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: isMobile
                  ? Column(
                      children: [
                        _buildShowcaseInputColumn(),
                        const SizedBox(height: 32),
                        const Icon(
                          Icons.arrow_downward_rounded,
                          color: Color(0xFF2563EB),
                          size: 32,
                        ),
                        const SizedBox(height: 32),
                        _buildShowcaseOutputColumn(),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildShowcaseInputColumn()),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 80,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              color: Color(0xFF2563EB),
                              size: 28,
                            ),
                          ),
                        ),
                        Expanded(child: _buildShowcaseOutputColumn()),
                      ],
                    ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildShowcaseInputColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.description_rounded, color: Color(0xFF2563EB), size: 20),
            const SizedBox(width: 8),
            Text(
              'Input: Lecture Note / PDF',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Physics 201: Maxwell\'s Equations',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Gauss\'s law relates electric flux to enclosed charge. Faraday\'s law describes induced electromotive force from changing magnetic flux. Ampère-Maxwell law includes displacement current.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '∮ B · dA = 0  (No Magnetic Monopoles)',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShowcaseOutputColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, color: Color(0xFF10B981), size: 20),
            const SizedBox(width: 8),
            Text(
              'Output: Intelligent Question & Rubric',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Q1: Which equation implies the non-existence of isolated magnetic monopoles?',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: const Color(0xFF14532D),
                ),
              ),
              const SizedBox(height: 10),
              _buildOption('A', 'Gauss\'s Law for Electricity', false),
              _buildOption('B', 'Gauss\'s Law for Magnetism (∮ B · dA = 0)', true),
              _buildOption('C', 'Faraday\'s Law of Induction', false),
              _buildOption('D', 'Ampère-Maxwell Law', false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOption(String letter, String text, bool isCorrect) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isCorrect ? const Color(0xFF15803D) : Colors.grey[200],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              letter,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isCorrect ? Colors.white : Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                color: isCorrect ? const Color(0xFF15803D) : Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── FAQ Section ──────────────────────────────────────────────────────────────

  Widget _buildFaq() {
    final faqs = [
      (
        q: 'Is SumQuiz free for teachers and lecturers?',
        a: 'Yes! Individual educators receive full access to our assessment generators, flashcard creators, and student analytics at zero cost.'
      ),
      (
        q: 'How does SumQuiz ensure academic accuracy and avoid hallucinations?',
        a: 'Our DeepScan engine strictly grounds all quiz and exam generation directly inside your uploaded materials (PDFs, slides, syllabus) with citation tracking.'
      ),
      (
        q: 'Can I export exams and quizzes to PDF or Word documents?',
        a: 'Yes. Every generated assessment can be exported to formatted PDF with separate teacher answer keys for in-person proctored exams.'
      ),
      (
        q: 'How do students access the classroom materials?',
        a: 'Students simply install the SumQuiz app or visit the web portal and enter your 6-digit classroom code to sync all decks and exams.'
      ),
      (
        q: 'Can SumQuiz handle mathematical formulas and diagrams?',
        a: 'Yes! Our OCR and parsing models support LaTeX mathematical formatting, scientific notation, tables, and chemical formulas.'
      ),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 900;
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 24 : 80,
          vertical: isMobile ? 48 : 80,
        ),
        child: Column(
          children: [
            Text(
              'Frequently Asked Questions',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: isMobile ? 28 : 40,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Everything you need to know about implementing SumQuiz in your classroom.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: Colors.grey[600],
                height: 1.5,
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
                            ? const Color(0xFF2563EB)
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
                                      ? const Color(0xFF2563EB)
                                      : Colors.grey[400],
                                ),
                              ],
                            ),
                            if (isOpen) ...[
                              const SizedBox(height: 12),
                              Text(
                                faq.a,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.grey[600],
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

  // ─── CTA Footer Section ───────────────────────────────────────────────────────

  Widget _buildCta() {
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 900;
      return Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF09101F), Color(0xFF1E3A8A), Color(0xFF0B1329)],
          ),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 24 : 80,
          vertical: isMobile ? 48 : 80,
        ),
        child: Column(
          children: [
            Text(
              'Ready to Transform Your Classroom?',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: isMobile ? 32 : 48,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Join hundreds of educators saving hours on assessment creation and grading every week.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: isMobile ? 15 : 18,
                color: Colors.white70,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 36),
            ElevatedButton(
              onPressed: () => context.go('/auth'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1E3A8A),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 32 : 44,
                  vertical: 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Get Started Free',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  // ─── Footer Section ───────────────────────────────────────────────────────────

  Widget _buildFooter() {
    return Container(
      color: const Color(0xFF0A0F1D),
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 40),
      child: Center(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/sumquiz_logo.png',
                  width: 24,
                  height: 24,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.school_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'SumQuiz',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '© 2026 SumQuiz. All rights reserved.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
