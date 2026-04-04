import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sumquiz/theme/web_theme.dart';
import 'package:sumquiz/views/screens/web/creator_tab_view.dart';

class LandingPageWeb extends StatefulWidget {
  final int initialTab;
  const LandingPageWeb({super.key, this.initialTab = 0});

  @override
  State<LandingPageWeb> createState() => _LandingPageWebState();
}

class _LandingPageWebState extends State<LandingPageWeb>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _tabController.addListener(_handleTabSelection);
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == 0) {
      context.go('/landing');
    } else {
      context.go('/Educators');
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildTopBar(context),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStudentLanding(),
                const CreatorTabView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    bool isEducator = _tabController.index == 1;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo
          InkWell(
            onTap: () {
              if (isEducator) {
                _tabController.animateTo(0);
              }
            },
            child: Row(
              children: [
                Image.asset('assets/images/sumquiz_logo.png', width: 32, height: 32),
                const SizedBox(width: 12),
                Text('SumQuiz', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: const Color(0xFF1F1F1F), letterSpacing: -0.5)),
              ],
            ),
          ),
          
          // Center Links
          Row(
            children: [
              _navLink('Features'),
              const SizedBox(width: 32),
              _navLink(isEducator ? 'Solutions' : 'How it Works'),
              const SizedBox(width: 32),
              _navLink('Pricing'),
              if (isEducator) ...[
                const SizedBox(width: 32),
                _navLink('Resources'),
              ]
            ],
          ),

          // Actions
          Row(
            children: [
              TextButton(
                onPressed: () => context.go('/auth'),
                child: Text(isEducator ? 'Sign In' : 'Log In', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.grey[800], fontSize: 14)),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () => context.go('/auth'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WebColors.purplePrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: Text('Get Started', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _navLink(String text) {
    return InkWell(
      onTap: () {},
      child: Text(text, style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildStudentLanding() {
    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        children: [
          _buildHeroSection(),
          _buildExcellenceSection(),
          _buildCtaSection(),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 60),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
                      Text('THE INTELLIGENT LUMINARY', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: WebColors.purplePrimary)),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.outfit(fontSize: 64, fontWeight: FontWeight.w900, color: const Color(0xFF1F1F1F), height: 1.1, letterSpacing: -1.5),
                    children: [
                      const TextSpan(text: 'Know exactly\nwhat to study —\n'),
                      TextSpan(text: 'instantly.', style: GoogleFonts.outfit(fontStyle: FontStyle.italic, color: WebColors.purplePrimary)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'SumQuiz tells you what to study, explains it fast, and tests\nyou immediately so you actually remember.',
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
                      child: Text('Start Learning Now', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
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
                      child: Text('Watch Demo', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
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
                  height: 500,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    gradient: const LinearGradient(colors: [Color(0xFF1A2836), Color(0xFF0F172A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    boxShadow: [BoxShadow(color: WebColors.purplePrimary.withValues(alpha: 0.1), blurRadius: 40, offset: const Offset(0, 20))],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: Opacity(
                      opacity: 0.5,
                      child: Icon(Icons.map, size: 300, color: Colors.cyanAccent.withValues(alpha: 0.3)), // Placeholder map
                    ),
                  ),
                ).animate().fadeIn(duration: 800.ms, delay: 200.ms).scale(begin: const Offset(0.95, 0.95)),
                Positioned(
                  bottom: -20,
                  left: -20,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))],
                    ),
                    child: Row(
                      children: [
                        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFF3E8FF), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.memory, color: WebColors.purplePrimary, size: 20)),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('AI Processing', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                            Text('Simulating...', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey[500])),
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

  Widget _buildExcellenceSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 120),
      child: Column(
        children: [
          Text('Redefining Excellence', style: GoogleFonts.outfit(fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: -1)),
          const SizedBox(height: 16),
          Text(
            'Sophisticated tools built for the modern scholar who demands more from\ntheir study time.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600], height: 1.5),
          ),
          const SizedBox(height: 60),
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 6,
                child: Container(
                  height: 300,
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
                      const Icon(Icons.precision_manufacturing, color: WebColors.purplePrimary),
                      const Spacer(),
                      Text('Study Pack Architect', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      Text('Turn any source into custom summaries and quizzes. From 100-page PDFs to YouTube lectures, we structure the knowledge for you.', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600], height: 1.5)),
                      const SizedBox(height: 24),
                      Row(
                        children: ['PDFS', 'VIDEO', 'WEB'].map((e) => Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(20)),
                            child: Text(e, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                          ),
                        )).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 4,
                child: Container(
                  height: 300,
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: WebColors.purplePrimary,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [BoxShadow(color: WebColors.purplePrimary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.all_inclusive, color: Colors.white, size: 32),
                      const Spacer(),
                      Text('Knowledge Fusion', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
                      const SizedBox(height: 12),
                      Text('Drag and drop multiple sources for an integrated learning experience that finds connections you missed.', style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, height: 1.5)),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 4,
                child: Container(
                  height: 300,
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.all_inclusive, color: WebColors.purplePrimary),
                      const Spacer(),
                      Text('SRS Mastery', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      Text('Spaced Repetition built into your daily routine. We schedule your reviews based on active recall performance.', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600], height: 1.5)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 6,
                child: Container(
                  height: 300,
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.insights, color: WebColors.purplePrimary),
                            const Spacer(),
                            Text('AI Progress Coach', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 12),
                            Text('Real-time insights and motivational tracking. Get granular feedback on your retention rates and concept mastery curves.', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600], height: 1.5)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 40),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)]),
                        child: Column(
                          children: [
                            Text('RETENTION SCORE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 1)),
                            const SizedBox(height: 16),
                            Text('94%', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900, color: WebColors.purplePrimary)),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildCtaSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 120),
      child: Column(
        children: [
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: GoogleFonts.outfit(fontSize: 64, fontWeight: FontWeight.w900, color: const Color(0xFF1F1F1F), height: 1.1, letterSpacing: -1.5),
              children: [
                const TextSpan(text: 'Join the '),
                TextSpan(text: 'Intelligent\nLuminary', style: GoogleFonts.outfit(fontStyle: FontStyle.italic, color: WebColors.purplePrimary)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Stop just studying. Start mastering. Join thousands of high-\nperformers using SumQuiz to redefine academic excellence.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600], height: 1.5),
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: () => context.go('/auth'),
            style: ElevatedButton.styleFrom(
              backgroundColor: WebColors.purplePrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: Text('Create Your Account', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(height: 24),
          Text('Free for 14 days. No credit card required.', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
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
              Text('© 2024 SumQuiz AI. Academic Excellence Redefined.', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500])),
            ],
          ),
          Row(
            children: ['Academic Resources', 'Study Guides', 'Research', 'Privacy'].map((e) => Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Text(e, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
            )).toList(),
          )
        ],
      ),
    );
  }
}
