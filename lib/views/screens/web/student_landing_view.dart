import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:sumquiz/theme/web_theme.dart';
import 'package:sumquiz/views/screens/web/widgets/landing_3d_card.dart';
import 'package:sumquiz/views/screens/web/widgets/landing_tab_toggle.dart';

class StudentLandingView extends StatefulWidget {
  const StudentLandingView({super.key});

  @override
  State<StudentLandingView> createState() => _StudentLandingViewState();
}

class _StudentLandingViewState extends State<StudentLandingView> {
  final ScrollController _scrollController = ScrollController();

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
            const LandingTabToggle(currentTab: LandingTab.student),
            _buildStudentHeroSection(),
            _buildStepsSection(),
            _buildFeatureGridSection(),
            _buildSumiSpotlightSection(),
            _buildReviewsSection(),
            _buildCtaSection(),
            _buildStudentFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentHeroSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 900;
        final horizontalPadding = isMobile ? 24.0 : 80.0;

        return Container(
          padding:
              EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 60),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildStudentHeroContent(isMobile: true),
                    const SizedBox(height: 60),
                    _buildStudentHeroImage(isMobile: true),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 1,
                      child: _buildStudentHeroContent(isMobile: false),
                    ),
                    const SizedBox(width: 40),
                    Expanded(
                      flex: 1,
                      child: _buildStudentHeroImage(isMobile: false),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildStudentHeroContent({required bool isMobile}) {
    return Column(
      crossAxisAlignment:
          isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(20)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome,
                  size: 16, color: WebColors.purplePrimary),
              const SizedBox(width: 8),
              Text('THE ULTIMATE AI STUDY OS',
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: WebColors.purplePrimary)),
            ],
          ),
        ),
        const SizedBox(height: 32),
        RichText(
          textAlign: isMobile ? TextAlign.center : TextAlign.start,
          text: TextSpan(
            style: GoogleFonts.outfit(
                fontSize: isMobile ? 48 : 64,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF1F1F1F),
                height: 1.1,
                letterSpacing: -1.5),
            children: [
              const TextSpan(text: 'Your Ultimate\n'),
              TextSpan(
                  text: 'AI Study OS.',
                  style: GoogleFonts.outfit(color: WebColors.purplePrimary)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Upload anything—PDFs, slides, or audio—and instantly\nturn them into interactive notes, quizzes, and flashcards.',
          textAlign: isMobile ? TextAlign.center : TextAlign.start,
          style: GoogleFonts.inter(
              fontSize: 18, color: Colors.grey[600], height: 1.5),
        ),
        const SizedBox(height: 48),
        Row(
          mainAxisAlignment:
              isMobile ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: () => context.go('/auth'),
              style: ElevatedButton.styleFrom(
                backgroundColor: WebColors.purplePrimary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              child: Text('Start for Free',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            const SizedBox(width: 16),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.play_circle_fill,
                  color: WebColors.purplePrimary),
              label: Text('Watch Demo',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey[800],
                side: BorderSide(color: Colors.grey[300]!),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 48),
        Row(
          mainAxisAlignment:
              isMobile ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              height: 40,
              child: Stack(
                children: [
                  _buildAvatar('assets/images/sumquiz_logo.png', 0),
                  _buildAvatar('assets/images/sumquiz_logo.png', 20),
                  _buildAvatar('assets/images/sumquiz_logo.png', 40),
                  _buildAvatar('assets/images/sumquiz_logo.png', 60),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('18,000+ students use the AI Study OS',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800])),
                Row(
                  children: [
                    Row(
                        children: List.generate(
                            5,
                            (index) => const Icon(Icons.star,
                                color: Colors.amber, size: 14))),
                    const SizedBox(width: 4),
                    Text('4.9/5 stars',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: WebColors.purplePrimary,
                            fontWeight: FontWeight.w600)),
                  ],
                )
              ],
            )
          ],
        )
      ],
    );
  }

  Widget _buildStudentHeroImage({required bool isMobile}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          height: isMobile ? 350 : 500,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            color: const Color(0xFFEEF2FF),
            boxShadow: [
              BoxShadow(
                color: WebColors.purplePrimary.withValues(alpha: 0.1),
                blurRadius: 40,
                offset: const Offset(0, 20),
              )
            ],
            image: const DecorationImage(
              image: AssetImage('assets/images/student_studying_phone.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Fallback icon if image fails (DecorationImage doesn't have errorBuilder like Image.asset)
              // But we can check if it looks okay.
              return const SizedBox.shrink();
            },
          ),
        ),
        Positioned(
          bottom: -20,
          left: isMobile ? 10 : -40,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.loop,
                      color: WebColors.purplePrimary, size: 24),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SPACED REPETITION',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: WebColors.purplePrimary,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Organic Chemistry Mastery',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1F1F1F),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 150,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: 120,
                              decoration: BoxDecoration(
                                color: WebColors.purplePrimary,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '85%',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(String asset, double leftPos) {
    return Positioned(
      left: leftPos,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration:
            const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: CircleAvatar(
          radius: 16,
          backgroundColor: Colors.grey[200],
          backgroundImage: AssetImage(asset),
        ),
      ),
    );
  }

  Widget _buildStepsSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 900;
        final hPad = isMobile ? 24.0 : 80.0;
        return Container(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 80),
          child: Column(
            children: [
              Text('How the AI Study OS works',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                      fontSize: isMobile ? 28 : 40,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1)),
              const SizedBox(height: 16),
              Text(
                'One unified system. Every format accepted. Every subject mastered.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: isMobile ? 14 : 16,
                    color: Colors.grey[600],
                    height: 1.5),
              ),
              const SizedBox(height: 60),
              isMobile
                  ? Column(
                      children: [
                        _buildStepItem(
                            Icons.upload_file,
                            '1. Upload Anything',
                            'Drop PDFs, slides, audio recordings, or paste a YouTube link. Our AI DeepScan engine reads and processes everything instantly.'),
                        const SizedBox(height: 32),
                        _buildStepItem(
                            Icons.auto_awesome,
                            '2. OS Generates Your Study Kit',
                            'In seconds, receive AI-structured notes, interactive flashcards, and exam-standard quizzes—all aligned to your syllabus.'),
                        const SizedBox(height: 32),
                        _buildStepItem(
                            Icons.track_changes,
                            '3. Adaptive Learning Paths (ATLP)',
                            'Sumi Tutor and the Retention Engine diagnose your weak spots and serve Adaptive Targeted Learning Paths to guarantee mastery.'),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            child: _buildStepItem(
                                Icons.upload_file,
                                '1. Upload Anything',
                                'Drop PDFs, slides, audio recordings, or paste a YouTube link. Our AI DeepScan engine reads and processes everything instantly.')),
                        _buildConnector(),
                        Expanded(
                            child: _buildStepItem(
                                Icons.auto_awesome,
                                '2. OS Generates Your Study Kit',
                                'In seconds, receive AI-structured notes, interactive flashcards, and exam-standard quizzes—all aligned to your syllabus.')),
                        _buildConnector(),
                        Expanded(
                            child: _buildStepItem(
                                Icons.track_changes,
                                '3. Adaptive Learning Paths (ATLP)',
                                'Sumi Tutor and the Retention Engine diagnose your weak spots and serve Adaptive Targeted Learning Paths to guarantee mastery.')),
                      ],
                    ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConnector() {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      width: 40,
      child: Divider(
          color: Colors.grey[300], thickness: 2, indent: 8, endIndent: 8),
    );
  }

  Widget _buildStepItem(IconData icon, String title, String desc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF), shape: BoxShape.circle),
          child: Icon(icon, color: WebColors.purplePrimary, size: 24),
        ),
        const SizedBox(height: 24),
        Text(title,
            style:
                GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Text(desc,
            style: GoogleFonts.inter(
                fontSize: 14, color: Colors.grey[600], height: 1.5)),
      ],
    );
  }

  Widget _buildFeatureGridSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 900;
        final hPad = isMobile ? 24.0 : 80.0;
        return Container(
          color: const Color(0xFFF8FAFC),
          padding: EdgeInsets.symmetric(
              horizontal: hPad, vertical: isMobile ? 60 : 120),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Every feature of an\nAI Study OS',
                        style: GoogleFonts.outfit(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                            height: 1.1)),
                    const SizedBox(height: 16),
                    Text(
                        'One app that replaces your notebook, tutor, flashcard deck, and exam prep—powered by AI.',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey[600],
                            height: 1.5)),
                    const SizedBox(height: 24),
                    _buildCheckFeature('Smart Notes linked to flashcards & quizzes'),
                    const SizedBox(height: 12),
                    _buildCheckFeature('Upload PDFs, audio, slides, or YouTube links'),
                    const SizedBox(height: 12),
                    _buildCheckFeature('AI-generated summaries, quizzes & flashcards'),
                    const SizedBox(height: 40),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.9,
                      children: [
                        _buildGridCard(
                            icon: Icons.auto_stories,
                            title: 'Smart Notes',
                            desc: 'AI-linked notes connected to your quizzes and flashcards.',
                            accentColor: const Color(0xFF0D9488)),
                        _buildGridCard(
                            imageAsset: 'assets/images/sumi.png',
                            title: 'Sumi Tutor',
                            desc: 'Your 24/7 personal AI tutor—ask anything, anytime.',
                            accentColor: WebColors.purplePrimary),
                        _buildGridCard(
                            icon: Icons.repeat_on,
                            title: 'Spaced Repetition',
                            desc: 'Review facts exactly when you are about to forget them.',
                            accentColor: const Color(0xFFF59E0B)),
                        _buildGridCard(
                            icon: Icons.flag,
                            title: 'Daily Missions',
                            desc: 'Gamified study missions to keep motivation high.',
                            accentColor: Colors.green),
                      ],
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Every feature of an\nAI Study OS',
                              style: GoogleFonts.outfit(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1,
                                  height: 1.1)),
                          const SizedBox(height: 24),
                          Text(
                              'One app that replaces your notebook, tutor, flashcard deck, and exam prep. SumQuiz uses neuroscience-backed AI to accelerate your learning while reducing the effort needed to retain it.',
                              style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                  height: 1.5)),
                          const SizedBox(height: 40),
                          _buildCheckFeature('Smart Notes linked to flashcards & quizzes'),
                          const SizedBox(height: 16),
                          _buildCheckFeature('Upload PDFs, audio, slides, or YouTube links'),
                          const SizedBox(height: 16),
                          _buildCheckFeature('AI-generated summaries, quizzes & flashcards'),
                          const SizedBox(height: 16),
                          _buildCheckFeature('Retention Engine & Knowledge Graph'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 80),
                    Expanded(
                      flex: 1,
                      child: GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 24,
                        crossAxisSpacing: 24,
                        childAspectRatio: 1.05,
                        children: [
                          _buildGridCard(
                              icon: Icons.auto_stories,
                              title: 'Smart Notes',
                              desc: 'An AI-linked note workspace that auto-generates flashcards and quizzes from everything you write.',
                              accentColor: const Color(0xFF0D9488)),
                          _buildGridCard(
                              imageAsset: 'assets/images/sumi.png',
                              title: 'Sumi Tutor',
                              desc: 'Your 24/7 personal AI tutor. Ask Sumi to explain any concept contextually from your own notes.',
                              accentColor: WebColors.purplePrimary),
                          _buildGridCard(
                              icon: Icons.hub,
                              title: 'Knowledge Graph',
                              desc: 'A visual Retention Engine that maps how concepts connect—identifying your blind spots before exams.',
                              accentColor: const Color(0xFF1E3A8A)),
                          _buildGridCard(
                              icon: Icons.repeat_on,
                              title: 'Spaced Repetition',
                              desc: 'Science-backed daily missions that ensure you review content exactly when you are about to forget it.',
                              accentColor: const Color(0xFFF59E0B)),
                        ],
                      ),
                    )
                  ],
                ),
        );
      },
    );
  }

  Widget _buildCheckFeature(String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF), shape: BoxShape.circle),
          child:
              const Icon(Icons.check, size: 14, color: WebColors.purplePrimary),
        ),
        const SizedBox(width: 16),
        Text(text,
            style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1F1F1F))),
      ],
    );
  }

  Widget _buildGridCard({
    IconData? icon,
    String? imageAsset,
    required String title,
    required String desc,
    Color accentColor = WebColors.purplePrimary,
  }) {
    return Landing3DCard(
      depth: 10,
      padding: const EdgeInsets.all(22),
      backgroundColor: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          imageAsset != null
              ? Image.asset(imageAsset, width: 40, height: 40, fit: BoxFit.contain)
              : Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon!, color: accentColor, size: 24),
                ),
          const SizedBox(height: 14),
          Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(desc,
              style: GoogleFonts.lato(
                  fontSize: 12, color: Colors.grey[600], height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildSumiSpotlightSection() {
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 900;
      return Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF0F172A)],
          ),
        ),
        padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 24 : 80, vertical: isMobile ? 60 : 100),
        child: isMobile
            ? Column(
                children: [
                  _buildSumiOrb(size: 180),
                  const SizedBox(height: 48),
                  _buildSumiContent(isMobile: true),
                ],
              )
            : Row(
                children: [
                  Expanded(flex: 1, child: _buildSumiOrb(size: 300)),
                  const SizedBox(width: 80),
                  Expanded(flex: 1, child: _buildSumiContent(isMobile: false)),
                ],
              ),
      );
    });
  }

  Widget _buildSumiOrb({required double size}) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow ring
          Container(
            width: size * 1.3,
            height: size * 1.3,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF0D9488).withValues(alpha: 0.25),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // Inner glow ring
          Container(
            width: size * 1.1,
            height: size * 1.1,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF1E3A8A).withValues(alpha: 0.4),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // Sumi orb image
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.4),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/sumi.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0xFF0D9488), Color(0xFF1E3A8A)],
                    ),
                  ),
                  child: const Icon(Icons.smart_toy,
                      color: Colors.white, size: 80),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSumiContent({required bool isMobile}) {
    return Column(
      crossAxisAlignment:
          isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.6)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('MEET SUMI TUTOR',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: const Color(0xFF0D9488))),
        ),
        const SizedBox(height: 24),
        RichText(
          textAlign: isMobile ? TextAlign.center : TextAlign.start,
          text: TextSpan(
            style: GoogleFonts.poppins(
                fontSize: isMobile ? 32 : 44,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1.15),
            children: [
              const TextSpan(text: 'Your 24/7\n'),
              TextSpan(
                  text: 'AI Tutor',
                  style: GoogleFonts.poppins(
                      color: const Color(0xFF0D9488),
                      fontWeight: FontWeight.w900)),
              const TextSpan(text: ' that knows\nyour notes.'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Sumi doesn\'t just answer questions — she reads your uploaded materials and explains concepts using your own course content, building on what you already know.',
          textAlign: isMobile ? TextAlign.center : TextAlign.start,
          style: GoogleFonts.lato(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.75),
              height: 1.6),
        ),
        const SizedBox(height: 36),
        _buildSumiFeatureBullet(
          icon: Icons.hub_outlined,
          color: const Color(0xFF0D9488),
          title: 'Retention Engine & Knowledge Graph',
          desc: 'Visualises how concepts connect and surfaces what you haven\'t mastered yet.',
        ),
        const SizedBox(height: 20),
        _buildSumiFeatureBullet(
          icon: Icons.track_changes,
          color: const Color(0xFFF59E0B),
          title: 'Adaptive Learning Paths (ATLP)',
          desc: 'Sumi diagnoses your weak areas and builds a personalised revision roadmap.',
        ),
        const SizedBox(height: 20),
        _buildSumiFeatureBullet(
          icon: Icons.repeat_on,
          color: const Color(0xFF1E3A8A),
          title: 'Spaced Repetition Engine',
          desc: 'Daily missions powered by science-backed spacing to guarantee long-term memory.',
        ),
        const SizedBox(height: 40),
        ElevatedButton.icon(
          onPressed: () => context.go('/auth'),
          icon: const Icon(Icons.arrow_forward, size: 18),
          label: Text('Chat with Sumi — It\'s Free',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D9488),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
        ),
      ],
    );
  }

  Widget _buildSumiFeatureBullet({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 4),
              Text(desc,
                  style: GoogleFonts.lato(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.6),
                      height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewsSection() {

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 900;
        final hPad = isMobile ? 24.0 : 80.0;
        return Container(
          padding: EdgeInsets.symmetric(
              horizontal: hPad, vertical: isMobile ? 60 : 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('THE AI STUDY OS IN ACTION',
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                color: WebColors.purplePrimary)),
                        const SizedBox(height: 12),
                        Text('18,000+ students. One AI Study OS.',
                            style: GoogleFonts.outfit(
                                fontSize: isMobile ? 26 : 40,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1)),
                      ],
                    ),
                  ),
                  if (!isMobile)
                    Row(
                      children: [
                        IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.grey)),
                        const SizedBox(width: 8),
                        IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.arrow_forward,
                                color: Colors.black)),
                      ],
                    )
                ],
              ),
              const SizedBox(height: 48),
              isMobile
                  ? Column(
                      children: [
                        _buildReviewCard(
                            'SumQuiz turned my messy lecture notes into clear, usable quizzes. It\'s the reason I passed my last semester with a first class.',
                            'David Okafor',
                            'University of Lagos'),
                        const SizedBox(height: 16),
                        _buildReviewCard(
                            'The flashcard system is addictive. I study for 20-30 mins on the bus, and the information actually stays in my head permanently.',
                            'Aisha Yusuf',
                            'Ahmadu Bello University'),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                            child: _buildReviewCard(
                                'SumQuiz turned my messy lecture notes into clear, usable quizzes. It\'s the reason I passed my last semester with a first class.',
                                'David Okafor',
                                'University of Lagos')),
                        const SizedBox(width: 24),
                        Expanded(
                            child: _buildReviewCard(
                                'The flashcard system is addictive. I study for 20-30 mins on the bus, and the information actually stays in my head permanently.',
                                'Aisha Yusuf',
                                'Ahmadu Bello University')),
                        const SizedBox(width: 24),
                        Expanded(
                            child: _buildReviewCard(
                                'I uploaded my 200-level biochem slides and Sumi Tutor explained every diagram to me like a real teacher. I\'ve never understood enzyme kinetics this well.',
                                'Faruk Adebayo',
                                'Obafemi Awolowo University')),
                        const SizedBox(width: 24),
                        Expanded(
                            child: _buildReviewCard(
                                'The daily study missions keep me consistent. I\'ve never felt this confident about my final professional exams before.',
                                'Chioma Nwachukwu',
                                'University of Nigeria, Nsukka')),
                      ],
                    ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReviewCard(String quote, String name, String school) {
    return Landing3DCard(
      depth: 8,
      padding: const EdgeInsets.all(32),
      backgroundColor: const Color(0xFFF8FAFC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
              children: List.generate(
                  5,
                  (index) =>
                      const Icon(Icons.star, color: Colors.amber, size: 16))),
          const SizedBox(height: 24),
          Text('"$quote"',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.6,
                  fontStyle: FontStyle.italic)),
          const SizedBox(height: 32),
          Row(
            children: [
              CircleAvatar(
                  backgroundColor: Colors.grey[300],
                  radius: 16,
                  child:
                      const Icon(Icons.person, color: Colors.white, size: 16)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1F1F1F))),
                    Text(
                      school,
                      style: GoogleFonts.inter(
                          fontSize: 11, color: Colors.grey[500]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildCtaSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 900;
        final hPad = isMobile ? 24.0 : 80.0;
        return Container(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 80),
          child: Container(
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(
              color: WebColors.purplePrimary,
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
                  style: GoogleFonts.poppins(
                    fontSize: isMobile ? 28 : 40,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Upload anything. Get instant notes, quizzes, and flashcards. Let Sumi Tutor guide you to mastery with Adaptive Learning Paths and Spaced Repetition.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lato(
                    fontSize: isMobile ? 14 : 16,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () => context.go('/auth'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: WebColors.purplePrimary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 24),
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
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.white54, size: 14),
                    const SizedBox(width: 8),
                    Text(
                      'No credit card',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: Colors.white70),
                    ),
                    const SizedBox(width: 24),
                    const Icon(Icons.check_circle,
                        color: Colors.white54, size: 14),
                    const SizedBox(width: 8),
                    Text(
                      'Cancel anytime',
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

  Widget _buildStudentFooter() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 900;
        final hPad = isMobile ? 24.0 : 80.0;
        return Container(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 60),
          color: const Color(0xFF1E293B),
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
                                Icons.school,
                                color: Colors.white,
                                size: 24)),
                        const SizedBox(width: 8),
                        Text('SumQuiz',
                            style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                        'Empowering the next generation of Nigerian scholars through AI.',
                        style: GoogleFonts.inter(
                            fontSize: 12,
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
                      'JAMB Prep 2024',
                      'Success Stories',
                      'Help Center'
                    ]),
                    const SizedBox(height: 24),
                    Text('© 2024 SumQuiz AI Labs. All rights reserved.',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: Colors.grey[600])),
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
                                      Icons.school,
                                      color: Colors.white,
                                      size: 24)),
                              const SizedBox(width: 8),
                              Text('SumQuiz',
                                  style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: -0.5)),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                              'Empowering the next generation of\nNigerian scholars through cutting-\nedge AI technology and personalized\nlearning paths.',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.grey[400],
                                  height: 1.6)),
                          const SizedBox(height: 40),
                          Row(
                            children: [
                              const Icon(Icons.language,
                                  color: Colors.white, size: 20),
                              const SizedBox(width: 16),
                              const Icon(Icons.code,
                                  color: Colors.white, size: 20),
                            ],
                          )
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
                        'JAMB Prep 2024',
                        'Success Stories',
                        'Help Center'
                      ]),
                    ),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('JOIN US',
                              style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                  color: Colors.white)),
                          const SizedBox(height: 24),
                          Text(
                              'Study tips and AI updates delivered to your inbox.',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.grey[400],
                                  height: 1.5)),
                          const SizedBox(height: 16),
                          Container(
                            decoration: BoxDecoration(
                                color: const Color(0xFF334155),
                                borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                    child: Text('Your email address...',
                                        style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: Colors.grey[500]))),
                                Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                        color: WebColors.purplePrimary,
                                        borderRadius: BorderRadius.circular(8)),
                                    child: const Icon(Icons.arrow_forward,
                                        color: Colors.white, size: 16))
                              ],
                            ),
                          ),
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
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: Colors.white)),
        const SizedBox(height: 24),
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
