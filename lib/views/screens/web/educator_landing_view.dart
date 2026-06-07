import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:sumquiz/providers/theme_provider.dart';
import 'package:sumquiz/theme/web_theme.dart';
import 'package:sumquiz/views/screens/web/widgets/landing_3d_card.dart';

class EducatorLandingView extends StatefulWidget {
  const EducatorLandingView({super.key});

  @override
  State<EducatorLandingView> createState() => _EducatorLandingViewState();
}

class _EducatorLandingViewState extends State<EducatorLandingView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFAFAFA),
      child: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            _buildTabToggle(),
            _buildHeroSection(),
            _buildTrustBanner(),
            _buildEducatorFrameworkSection(),
            _buildDeepScanFeature(),
            _buildCtaFooter(),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildTabToggle() {
    return Container(
      margin: const EdgeInsets.only(top: 40, bottom: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => context.go('/landing'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text('STUDENT',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                      fontSize: 13,
                      letterSpacing: 1.2)),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: ThemeProvider.primaryDeepBlue,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                    color: ThemeProvider.primaryDeepBlue.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Text('EDUCATION',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 13,
                    letterSpacing: 1.2)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 900;
      final hPad = isMobile ? 24.0 : 80.0;
      return Container(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 60),
        child: isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildHeroContent(isMobile: true),
                  const SizedBox(height: 60),
                  _buildHeroImage(isMobile: true),
                ],
              )
            : Row(
                children: [
                  Expanded(flex: 1, child: _buildHeroContent(isMobile: false)),
                  const SizedBox(width: 40),
                  Expanded(flex: 1, child: _buildHeroImage(isMobile: false)),
                ],
              ),
      );
    });
  }

  Widget _buildHeroContent({required bool isMobile}) {
    return Column(
      crossAxisAlignment:
          isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.workspace_premium,
                  size: 16, color: ThemeProvider.primaryDeepBlue),
              const SizedBox(width: 8),
              Text('FOR EDUCATORS AND INSTITUTIONS',
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: ThemeProvider.primaryDeepBlue)),
            ],
          ),
        ),
        const SizedBox(height: 32),
        RichText(
          textAlign: isMobile ? TextAlign.center : TextAlign.start,
          text: TextSpan(
            style: GoogleFonts.poppins(
                fontSize: isMobile ? 40 : 56,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF1E293B),
                height: 1.1,
                letterSpacing: -1),
            children: [
              const TextSpan(text: 'Transform your\n'),
              TextSpan(
                  text: 'Curriculum ',
                  style: GoogleFonts.poppins(
                      color: ThemeProvider.primaryDeepBlue)),
              const TextSpan(text: 'into an\nintelligent ecosystem.'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Upload your syllabus, lecture notes, or textbooks. Our AI engine generates comprehensive assessments, flashcards, and student analytics in minutes.',
          textAlign: isMobile ? TextAlign.center : TextAlign.start,
          style: GoogleFonts.lato(
              fontSize: 18, color: const Color(0xFF475569), height: 1.6),
        ),
        const SizedBox(height: 48),
        Row(
          mainAxisAlignment:
              isMobile ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: () => context.go('/auth'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeProvider.primaryDeepBlue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              child: Text('Start Teaching with AI',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroImage({required bool isMobile}) {
    // 3D tactile composition for the hero
    return SizedBox(
      height: 450,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background soft glow
          Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ThemeProvider.primaryDeepBlue.withValues(alpha: 0.1),
              boxShadow: [
                BoxShadow(
                  color: ThemeProvider.primaryDeepBlue.withValues(alpha: 0.2),
                  blurRadius: 100,
                  spreadRadius: 20,
                )
              ],
            ),
          ),
          // Main 3D Card
          Positioned(
            child: Landing3DCard(
              depth: 20,
              backgroundColor: Colors.white,
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: ThemeProvider.primaryDeepBlue,
                            borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.analytics, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      Text('Class Performance',
                          style: GoogleFonts.poppins(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMiniStat('Avg Score', '87%', Colors.green),
                      const SizedBox(width: 16),
                      _buildMiniStat('Engagement', '92%', Colors.blue),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    height: 80,
                    width: 250,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          ThemeProvider.primaryDeepBlue.withValues(alpha: 0.8),
                          ThemeProvider.primaryDeepBlue
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  )
                ],
              ),
            ),
          ),
          // Floating 3D sub-card 1
          Positioned(
            right: 0,
            bottom: 40,
            child: Landing3DCard(
              depth: 15,
              padding: const EdgeInsets.all(16),
              backgroundColor: Colors.white,
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Exam Generated',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('50 Questions in 12s',
                          style: GoogleFonts.lato(
                              fontSize: 12, color: Colors.grey[600])),
                    ],
                  )
                ],
              ),
            ),
          ),
          // Floating 3D sub-card 2
          Positioned(
            left: 0,
            top: 40,
            child: Landing3DCard(
              depth: 15,
              padding: const EdgeInsets.all(16),
              backgroundColor: const Color(0xFF1E293B), // Dark card
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                  const SizedBox(width: 12),
                  Text('Syllabus.pdf parsed',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.white)),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.lato(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 24, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildTrustBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(color: Colors.grey[200]!),
              top: BorderSide(color: Colors.grey[200]!))),
      child: Center(
        child: Column(
          children: [
            Text('TRUSTED BY EDUCATORS ACROSS NIGERIA',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: Colors.grey[500])),
            const SizedBox(height: 24),
            Wrap(
              spacing: 40,
              runSpacing: 20,
              alignment: WrapAlignment.center,
              children: [
                _buildTrustLogo('Unilag'),
                _buildTrustLogo('OAU'),
                _buildTrustLogo('ABU'),
                _buildTrustLogo('UNN'),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTrustLogo(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.w900,
        color: Colors.grey[300],
        letterSpacing: 2,
      ),
    );
  }

  Widget _buildEducatorFrameworkSection() {
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 900;
      return Container(
        padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 24 : 80, vertical: 100),
        child: Column(
          children: [
            Text('The Modern Teaching Framework',
                style: GoogleFonts.poppins(
                    fontSize: isMobile ? 32 : 48, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            Text(
                'Focus on teaching. Let our AI handle the tedious content creation and analytics.',
                textAlign: TextAlign.center,
                style: GoogleFonts.lato(fontSize: 18, color: Colors.grey[600])),
            const SizedBox(height: 60),
            Wrap(
              spacing: 32,
              runSpacing: 32,
              alignment: WrapAlignment.center,
              children: [
                _buildFrameworkCard(
                  icon: Icons.upload_file,
                  title: 'Upload Materials',
                  desc: 'Simply drag and drop your PDFs, syllabuses, or slides.',
                  depth: 10,
                ),
                _buildFrameworkCard(
                  icon: Icons.precision_manufacturing,
                  title: 'Automated Generation',
                  desc: 'AI generates quizzes, flashcards, and study guides instantly.',
                  depth: 15, // Make middle one pop
                ),
                _buildFrameworkCard(
                  icon: Icons.insights,
                  title: 'Track Performance',
                  desc: 'Monitor class progress and identify knowledge gaps.',
                  depth: 10,
                ),
              ],
            )
          ],
        ),
      );
    });
  }

  Widget _buildFrameworkCard({required IconData icon, required String title, required String desc, required double depth}) {
    return SizedBox(
      width: 320,
      child: Landing3DCard(
        depth: depth,
        padding: const EdgeInsets.all(32),
        backgroundColor: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: ThemeProvider.primaryDeepBlue, size: 32),
            ),
            const SizedBox(height: 24),
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(desc,
                style: GoogleFonts.lato(fontSize: 15, color: Colors.grey[600], height: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildDeepScanFeature() {
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 900;
      return Container(
        color: const Color(0xFFF8FAFC),
        padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 24 : 80, vertical: 100),
        child: isMobile
            ? Column(
                children: [
                  _buildDeepScanContent(),
                  const SizedBox(height: 60),
                  _buildDeepScanVisual(),
                ],
              )
            : Row(
                children: [
                  Expanded(child: _buildDeepScanVisual()),
                  const SizedBox(width: 80),
                  Expanded(child: _buildDeepScanContent()),
                ],
              ),
      );
    });
  }

  Widget _buildDeepScanContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CONTENT EXTRACTION',
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: ThemeProvider.primaryDeepBlue)),
        const SizedBox(height: 16),
        Text('Extract intelligence from any format',
            style: GoogleFonts.poppins(
                fontSize: 36, fontWeight: FontWeight.w900, height: 1.2)),
        const SizedBox(height: 24),
        Text(
            'SumQuiz DeepScan technology can parse through complex mathematical formulas, historical timelines, and dense medical textbooks with near-human accuracy.',
            style: GoogleFonts.lato(
                fontSize: 16, color: Colors.grey[600], height: 1.6)),
        const SizedBox(height: 32),
        _buildFeatureItem(Icons.picture_as_pdf, 'High-fidelity PDF parsing'),
        const SizedBox(height: 16),
        _buildFeatureItem(Icons.video_library, 'YouTube transcript extraction'),
        const SizedBox(height: 16),
        _buildFeatureItem(Icons.text_format, 'Raw text and code blocks'),
      ],
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: ThemeProvider.primaryDeepBlue, size: 20),
        const SizedBox(width: 16),
        Text(text,
            style: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildDeepScanVisual() {
    return SizedBox(
      height: 400,
      child: Center(
        child: Landing3DCard(
          depth: 25, // Extra deep for main visual
          padding: const EdgeInsets.all(0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // Simulating a UI screenshot
                Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      Container(
                        height: 48,
                        color: const Color(0xFFF1F5F9),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            const Icon(Icons.circle, size: 12, color: Colors.red),
                            const SizedBox(width: 8),
                            const Icon(Icons.circle, size: 12, color: Colors.amber),
                            const SizedBox(width: 8),
                            const Icon(Icons.circle, size: 12, color: Colors.green),
                            const SizedBox(width: 16),
                            Text('sumquiz.xyz/creator', style: GoogleFonts.lato(fontSize: 12, color: Colors.grey[500]))
                          ],
                        ),
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(height: 20, width: 200, color: Colors.grey[200]),
                              const SizedBox(height: 24),
                              Container(height: 100, color: const Color(0xFFEEF2FF)),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Expanded(child: Container(height: 60, color: Colors.grey[100])),
                                  const SizedBox(width: 16),
                                  Expanded(child: Container(height: 60, color: Colors.grey[100])),
                                ],
                              )
                            ],
                          ),
                        ),
                      )
                    ],
                  ),
                ),
                // Overlay "processing" effect
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          ThemeProvider.primaryDeepBlue.withValues(alpha: 0.0),
                          ThemeProvider.primaryDeepBlue.withValues(alpha: 0.1),
                        ]
                      )
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCtaFooter() {
    return Container(
      color: ThemeProvider.primaryDeepBlue,
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
      width: double.infinity,
      child: Column(
        children: [
          Text('Ready to scale your teaching?',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Colors.white)),
          const SizedBox(height: 24),
          Text(
              'Join thousands of educators saving hours on content creation every week.',
              textAlign: TextAlign.center,
              style: GoogleFonts.lato(
                  fontSize: 18, color: Colors.white70, height: 1.5)),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: () => context.go('/auth'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: ThemeProvider.primaryDeepBlue,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
            ),
            child: Text('Get Started Free',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 80),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Image.asset('assets/images/sumquiz_logo.png', width: 32),
              const SizedBox(width: 12),
              Text('SumQuiz',
                  style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ],
          ),
          Text('© 2026 SumQuiz. All rights reserved.',
              style: GoogleFonts.lato(fontSize: 14, color: Colors.grey[500])),
        ],
      ),
    );
  }
}
