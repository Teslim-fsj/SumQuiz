import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:sumquiz/theme/web_theme.dart';

class CreatorTabView extends StatefulWidget {
  const CreatorTabView({super.key});

  @override
  State<CreatorTabView> createState() => _CreatorTabViewState();
}

class _CreatorTabViewState extends State<CreatorTabView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
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

  Widget _buildHeroSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 60),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.psychology, size: 16, color: WebColors.purplePrimary),
                      const SizedBox(width: 8),
                      Text('THE FUTURE OF PEDAGOGY', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: WebColors.purplePrimary)),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.outfit(fontSize: 64, fontWeight: FontWeight.w900, color: const Color(0xFF1F1F1F), height: 1.1, letterSpacing: -1.5),
                    children: [
                      const TextSpan(text: 'Create exam-\nready papers\nin minutes\n— '),
                      TextSpan(text: 'not hours.', style: GoogleFonts.outfit(fontStyle: FontStyle.italic, color: WebColors.purplePrimary)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Generate, edit, and export exam papers with answers and\nmarking schemes. Share with a QR code so students can\npractice instantly.',
                  style: GoogleFonts.inter(fontSize: 18, color: Colors.grey[600], height: 1.5),
                ),
                const SizedBox(height: 48),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () => context.go('/auth'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: WebColors.purplePrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: Text('Request a Demo', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[800],
                        side: BorderSide(color: Colors.grey[300]!),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: Text('View Curriculum', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ],
                )
              ],
            ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1),
          ),
          const SizedBox(width: 60),
          Expanded(
            flex: 1,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 450,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    color: const Color(0xFFF8FAFC),
                    border: Border.all(color: Colors.grey[200]!, width: 8),
                    boxShadow: [BoxShadow(color: WebColors.purplePrimary.withValues(alpha: 0.05), blurRadius: 40, offset: const Offset(0, 20))],
                  ),
                  child: Center(
                    child: Icon(Icons.tablet_mac, size: 160, color: Colors.grey[300]), // IPad Placeholder
                  )
                ).animate().fadeIn(duration: 800.ms, delay: 200.ms).scale(begin: const Offset(0.95, 0.95)),
                Positioned(
                  bottom: -20,
                  left: -40,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_graph, color: WebColors.purplePrimary),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('DEEP SCAN AI', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: WebColors.purplePrimary, letterSpacing: 1)),
                            const SizedBox(height: 4),
                            Text('Mapping student Knowledge\nGaps across 12 source\nmaterials in seconds.', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[800], height: 1.4, fontStyle: FontStyle.italic)),
                          ],
                        )
                      ],
                    ),
                  ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Text('TRUSTED BY LEADING RESEARCH INSTITUTIONS', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[400], letterSpacing: 2)),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTrustLogo('STANFORD ACADEMICS'),
              const SizedBox(width: 60),
              _buildTrustLogo('MIT CENTER'),
              const SizedBox(width: 60),
              _buildTrustLogo('OXFORD EDUCATION'),
              const SizedBox(width: 60),
              _buildTrustLogo('IVY COALITION'),
              const SizedBox(width: 60),
              _buildTrustLogo('RTH RESEARCH'),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTrustLogo(String text) {
    return Text(text, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.grey[400]));
  }

  Widget _buildEducatorFrameworkSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('THE EDUCATOR FRAMEWORK', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: WebColors.purplePrimary)),
          const SizedBox(height: 16),
          Text('Designed for Depth, Built for\nEfficiency.', style: GoogleFonts.outfit(fontSize: 48, fontWeight: FontWeight.w900, color: const Color(0xFF1F1F1F), letterSpacing: -1, height: 1.1)),
          const SizedBox(height: 16),
          Text("We've eliminated the administrative burden of high-stakes assessment, allowing\nyou to focus on the human element of teaching.", style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600], height: 1.5)),
          const SizedBox(height: 60),
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildFrameworkCard(Icons.science, 'Exam Architect', 'Maintain absolute control over academic rigor. Map questions to Bloom\'s Taxonomy with precision scoring.', ['TAXONOMY MAPPING', 'AUTO-BALANCING'])),
              const SizedBox(width: 24),
              Expanded(child: _buildFrameworkCard(Icons.insights, 'Real-time Analytics', 'Identify conceptual bottlenecks instantly. See beyond the score to understand the "why" of student performance.', ['CONCEPT DRILLS', 'COHORT TRENDS'])),
              const SizedBox(width: 24),
              Expanded(child: _buildFrameworkCard(Icons.all_inclusive, 'Knowledge Fusion', 'Synthesize diverse sources—from PDFs to lecture transcripts—into coherent, verified study modules.', ['MULTI-SOURCE', 'AUTO-SUMMARIES'])),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildFrameworkCard(IconData icon, String title, String desc, List<String> tags) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF3E8FF), shape: BoxShape.circle),
            child: Icon(icon, color: WebColors.purplePrimary),
          ),
          const SizedBox(height: 24),
          Text(title, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Text(desc, style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600], height: 1.5)),
          const Spacer(),
          const SizedBox(height: 24),
          Row(
            children: tags.map((t) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey[200]!)),
                child: Text(t, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.grey[700])),
              ),
            )).toList(),
          )
        ],
      ),
    );
  }

  Widget _buildDeepScanFeature() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 80),
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 1,
                child: Container(
                  height: 350,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: WebColors.purplePrimary, borderRadius: BorderRadius.circular(16)),
                          child: const Icon(Icons.dashboard, color: Colors.white),
                        ),
                        const SizedBox(height: 32),
                        Container(height: 8, width: 200, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4))),
                        const SizedBox(height: 16),
                        Container(height: 8, width: 150, decoration: BoxDecoration(color: WebColors.purplePrimary, borderRadius: BorderRadius.circular(4))),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 80),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Precision Control for Complex\nCurriculums.', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, height: 1.1, letterSpacing: -0.5)),
                    const SizedBox(height: 16),
                    Text('Our interface was developed in collaboration with\nresearch professors to minimize cognitive load. Every\nfeature is exactly where you expect it to be.', style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600], height: 1.5)),
                    const SizedBox(height: 32),
                    _featureHighlight('Native LMS Integration', 'Sync grades and rosters with Canvas, Blackboard, and Moodle in one click.'),
                    const SizedBox(height: 24),
                    _featureHighlight('Automated Feedback Loops', 'Personalized feedback generated for every student based on their unique friction points.'),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 120),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Deep Scan: Beyond Scores.', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, height: 1.1, letterSpacing: -0.5)),
                    const SizedBox(height: 16),
                    Text('Legacy platforms tell you who failed. SumQuiz tells you\nwhy. Our Deep Scan engine identifies the specific\nmental models causing confusion across your whole\ncohort.', style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600], height: 1.5)),
                    const SizedBox(height: 40),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey[200]!)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('"SumQuiz identified that 80% of my class struggling\nspecifically with the application of Entropy, not the\ncalculation. I pivot my lectures based on these\ninsights every Tuesday."', style: GoogleFonts.inter(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.grey[800], height: 1.5)),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              CircleAvatar(backgroundColor: WebColors.purplePrimary.withValues(alpha: 0.2), radius: 16),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Dr. Audrina Malek', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                                  Text('Professor of Applied Physics', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey[500])),
                                ],
                              )
                            ],
                          )
                        ],
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(width: 80),
              Expanded(
                flex: 1,
                child: Container(
                  height: 400,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    gradient: const LinearGradient(colors: [Color(0xFF1A1A1A), Colors.black], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 40, offset: const Offset(0, 20))],
                  ),
                  child: Center(
                    child: Icon(Icons.query_stats, size: 120, color: Colors.cyanAccent.withValues(alpha: 0.3)),
                  )
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _featureHighlight(String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(6)),
          child: const Icon(Icons.check, size: 12, color: WebColors.purplePrimary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF1F1F1F))),
              const SizedBox(height: 4),
              Text(desc, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600], height: 1.5)),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildCtaFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 120),
      child: Container(
        padding: const EdgeInsets.all(80),
        decoration: BoxDecoration(
          color: const Color(0xFF2E1A47),
          borderRadius: BorderRadius.circular(40),
          boxShadow: [BoxShadow(color: const Color(0xFF2E1A47).withValues(alpha: 0.3), blurRadius: 40, offset: const Offset(0, 20))],
        ),
        child: Column(
          children: [
            Text('Elevate Your\nAcademic Impact.', textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1, letterSpacing: -1)),
            const SizedBox(height: 24),
            Text('Join a community of elite educators using data-driven pedagogical\ntools to transform student outcomes.', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 16, color: Colors.white70, height: 1.5)),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => context.go('/auth'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF2E1A47),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: Text('Start Your Free Trial', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                const SizedBox(width: 16),
                OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: Text('Institutional Solutions', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text('GET A DEMO IN POST OR READ SALES', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white30))
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 60),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Row(
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
                    Image.asset('assets/images/sumquiz_logo.png', width: 24, height: 24),
                    const SizedBox(width: 8),
                    Text('SumQuiz', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF1F1F1F), letterSpacing: -0.5)),
                  ],
                ),
                const SizedBox(height: 16),
                Text('The intelligence layer for modern\neducation. Scalable, ethical, and\nresearch-backed tools for the global\nacademic community.', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500], height: 1.6)),
                const SizedBox(height: 40),
                Text('© 2024 SumQuiz AI Labs. All rights reserved.', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey[400])),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: _footerCol('PLATFORM', ['Exam Architect', 'Deep Scan Analytics', 'Integrations', 'Security']),
          ),
          Expanded(
            flex: 1,
            child: _footerCol('RESOURCES', ['Case Studies', 'Whitepapers', 'Documentation', 'Academic Support']),
          ),
          Expanded(
            flex: 1,
            child: _footerCol('COMPANY', ['About Us', 'Careers', 'Privacy Policy', 'Contact']),
          ),
        ],
      ),
    );
  }

  Widget _footerCol(String title, List<String> links) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: const Color(0xFF1F1F1F))),
        const SizedBox(height: 24),
        ...links.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(e, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
        )),
      ],
    );
  }
}
