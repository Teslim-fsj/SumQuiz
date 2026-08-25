import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sumquiz/theme/web_theme.dart';
import 'package:sumquiz/views/screens/web/widgets/landing_tab_toggle.dart';

class CreatorProgramLanding extends StatefulWidget {
  const CreatorProgramLanding({super.key});

  @override
  State<CreatorProgramLanding> createState() => _CreatorProgramLandingState();
}

class _CreatorProgramLandingState extends State<CreatorProgramLanding> {
  int? _openFaq;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildHero(),
            _buildBenefits(),
            _buildHowItWorks(),
            _buildCreatorSpotlight(),
            _buildFaq(),
            _buildCta(),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ─── Hero ─────────────────────────────────────────────────────────────────────

  Widget _buildHero() {
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 900;
      return Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F0B2D), Color(0xFF1E1048), Color(0xFF0F172A)],
          ),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 24 : 80,
          vertical: isMobile ? 36 : 64,
        ),
        child: Column(
          children: [
            const LandingTabToggle(
              currentTab: LandingTab.creator,
              isDark: true,
            ),
            const SizedBox(height: 24),
            // Badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: WebColors.purplePrimary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: WebColors.purplePrimary.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded,
                      size: 16, color: WebColors.purplePrimary),
                  const SizedBox(width: 8),
                  Text(
                    'SUMQUIZ CREATOR PROGRAM',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: WebColors.purplePrimary,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 250.ms),
            const SizedBox(height: 32),
            // Headline
            Text(
              'Help Students Learn Better.\nEarn While You Do.',
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
              'Join an elite group of educational creators and student influencers\npartnering with SumQuiz to reach millions of students worldwide.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: isMobile ? 15 : 18,
                color: Colors.white70,
                height: 1.6,
              ),
            ).animate().fadeIn(delay: 150.ms, duration: 250.ms),
            const SizedBox(height: 40),
            // CTAs
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                ElevatedButton(
                  onPressed: () => context.go('/creator-program/apply'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WebColors.purplePrimary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 24 : 36,
                      vertical: 18,
                    ),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Apply Now',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms),
                ElevatedButton(
                  onPressed: () => context.go('/creator-dashboard'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 24 : 32,
                      vertical: 18,
                    ),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Colors.white24),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.dashboard_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Creator Dashboard',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 250.ms),
              ],
            ),
            const SizedBox(height: 48),
            // Stats Row
            Wrap(
              alignment: WrapAlignment.center,
              spacing: isMobile ? 24 : 48,
              runSpacing: 24,
              children: [
                _buildHeroStat('18K+', 'Student Users'),
                _buildHeroStatDivider(isMobile),
                _buildHeroStat('Free', 'SumQuiz Pro'),
                _buildHeroStatDivider(isMobile),
                _buildHeroStat('Early', 'Feature Access'),
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
    return Container(
        height: 36, width: 1, color: Colors.white12);
  }

  // ─── Benefits ─────────────────────────────────────────────────────────────────

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
              'Why Creators Choose SumQuiz',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: isMobile ? 28 : 40,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Everything you need to build your brand and earn as an educational creator.',
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
        icon: Icons.workspace_premium_rounded,
        title: 'Free SumQuiz Pro',
        desc:
            'Get lifetime Pro access the moment you\'re approved. Experience all premium features — for free.',
      ),
      (
        icon: Icons.monetization_on_rounded,
        title: 'Revenue Sharing',
        desc:
            'Earn a share of revenue from every paying user you refer. The more you share, the more you earn.',
      ),
      (
        icon: Icons.rocket_launch_rounded,
        title: 'Early Feature Access',
        desc:
            'Be the first to test new AI features before public release. Your feedback shapes the product.',
      ),
      (
        icon: Icons.person_pin_rounded,
        title: 'Featured Profile',
        desc:
            'Get featured on SumQuiz\'s creator showcase page, reaching thousands of students.',
      ),
      (
        icon: Icons.groups_rounded,
        title: 'Exclusive Community',
        desc:
            'Join a private Discord with top educational creators, study influencers, and the SumQuiz team.',
      ),
      (
        icon: Icons.bar_chart_rounded,
        title: 'Creator Dashboard',
        desc:
            'Track your clicks, signups, and earnings in real-time through your personal creator dashboard.',
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
              color: WebColors.purplePrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: WebColors.purplePrimary, size: 24),
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

  // ─── How It Works ─────────────────────────────────────────────────────────────

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
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Four simple steps to start earning as a SumQuiz creator.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 15, color: Colors.grey[600], height: 1.5),
            ),
            const SizedBox(height: 48),
            isMobile
                ? Column(
                    children: [
                      _buildStep(
                          1,
                          'Apply',
                          'Fill out a short application about your channel and audience. Takes less than 5 minutes.',
                          Icons.edit_note_rounded),
                      _buildStepConnectorV(),
                      _buildStep(
                          2,
                          'Get Approved',
                          'We review applications within 48 hours. Approved creators get instant Pro access and their referral link.',
                          Icons.verified_rounded),
                      _buildStepConnectorV(),
                      _buildStep(
                          3,
                          'Share SumQuiz',
                          'Post content featuring SumQuiz. Use your unique referral link in bio or video descriptions.',
                          Icons.share_rounded),
                      _buildStepConnectorV(),
                      _buildStep(
                          4,
                          'Earn Rewards',
                          'Every student who signs up through your link contributes to your earnings and lifetime perks.',
                          Icons.workspace_premium_rounded),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildStep(
                            1,
                            'Apply',
                            'Fill out a short application about your channel and audience.',
                            Icons.edit_note_rounded),
                      ),
                      _buildStepConnectorH(),
                      Expanded(
                        child: _buildStep(
                            2,
                            'Get Approved',
                            'We review within 48 hours. Get instant Pro access + referral link.',
                            Icons.verified_rounded),
                      ),
                      _buildStepConnectorH(),
                      Expanded(
                        child: _buildStep(
                            3,
                            'Share SumQuiz',
                            'Post content and use your unique referral link in bio or descriptions.',
                            Icons.share_rounded),
                      ),
                      _buildStepConnectorH(),
                      Expanded(
                        child: _buildStep(
                            4,
                            'Earn Rewards',
                            'Every referred student contributes to your earnings and perks.',
                            Icons.workspace_premium_rounded),
                      ),
                    ],
                  ),
          ],
        ),
      );
    });
  }

  Widget _buildStep(int number, String title, String desc, IconData icon) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: WebColors.purplePrimary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: WebColors.purplePrimary, size: 24),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: WebColors.purplePrimary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$number',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          desc,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.grey[600],
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildStepConnectorH() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 60),
      child: SizedBox(
        width: 32,
        child: Divider(color: Colors.grey[200], thickness: 2),
      ),
    );
  }

  Widget _buildStepConnectorV() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Container(width: 2, height: 32, color: Colors.grey[200]),
    );
  }

  // ─── Creator Spotlight ────────────────────────────────────────────────────────

  Widget _buildCreatorSpotlight() {
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
              'Who Should Apply?',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: isMobile ? 28 : 40,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'We partner with creators across every major educational platform.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 15, color: Colors.grey[600], height: 1.5),
            ),
            const SizedBox(height: 48),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                _buildCreatorTypeCard(
                    '📚', 'Study Creators', 'TikTok & Reels',
                    'Share study with me, note-taking, and exam prep content'),
                _buildCreatorTypeCard(
                    '⚡', 'Productivity Creators', 'YouTube & Blogs',
                    'Focus on tools, workflows, and second brain systems'),
                _buildCreatorTypeCard(
                    '🎓', 'Student Influencers', 'All Platforms',
                    'Document your student journey and inspire peers'),
                _buildCreatorTypeCard(
                    '📝', 'Exam Prep Creators', 'Instagram & YouTube',
                    'Help students ace exams with proven strategies'),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildCreatorTypeCard(
      String emoji, String type, String platform, String desc) {
    return Container(
      width: 250,
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
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 16),
          Text(
            type,
            style: GoogleFonts.outfit(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: WebColors.purplePrimary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              platform,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: WebColors.purplePrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            desc,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─── FAQ ──────────────────────────────────────────────────────────────────────

  Widget _buildFaq() {
    final faqs = [
      (
        q: 'Who can apply to the Creator Program?',
        a:
            'Anyone creating educational content — study tips, productivity, exam prep, or student lifestyle. There\'s no minimum follower requirement, but we look for engaged audiences and authentic content.'
      ),
      (
        q: 'How quickly will I hear back after applying?',
        a:
            'We review all applications within 48 hours. You\'ll receive an email notification when your application is approved or if we need more information.'
      ),
      (
        q: 'What is the referral commission structure?',
        a:
            'Approved creators receive a revenue share for every paying user they refer. Full commission details are shared in the creator welcome package upon approval.'
      ),
      (
        q: 'What is the minimum follower count to apply?',
        a:
            'There is no strict minimum. We\'re looking for creators with genuine engagement and authentic connections with student audiences. Even micro-creators with 1,000 engaged followers can be accepted.'
      ),
      (
        q: 'Do I need to post a certain number of times per month?',
        a:
            'No fixed requirement. We believe in authentic, quality content over volume. We just ask that creators share SumQuiz in a genuine way that\'s relevant to their audience.'
      ),
      (
        q: 'Can I promote SumQuiz on multiple platforms?',
        a:
            'Absolutely! Your single referral link works across all platforms. We encourage creators to share across TikTok, YouTube, Instagram, and wherever their audience lives.'
      ),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 900;
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 24 : 160,
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
              ),
            ),
            const SizedBox(height: 40),
            ...faqs.asMap().entries.map((entry) {
              final i = entry.key;
              final faq = entry.value;
              final isOpen = _openFaq == i;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isOpen ? WebColors.purplePrimary.withValues(alpha: 0.04) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isOpen
                        ? WebColors.purplePrimary.withValues(alpha: 0.3)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => setState(
                      () => _openFaq = isOpen ? null : i),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                faq.q,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            Icon(
                              isOpen
                                  ? Icons.remove_rounded
                                  : Icons.add_rounded,
                              color: WebColors.purplePrimary,
                              size: 24,
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
                              height: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      );
    });
  }

  // ─── CTA ──────────────────────────────────────────────────────────────────────

  Widget _buildCta() {
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 900;
      return Container(
        margin: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 80),
        padding: EdgeInsets.all(isMobile ? 32 : 48),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6B5CE7), Color(0xFF4F46E5), Color(0xFF1E1048)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Text(
              'Ready to Grow With SumQuiz?',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: isMobile ? 28 : 40,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Join our Creator Program and be part of the movement\nto make learning better for millions of students.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: Colors.white70,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => context.go('/creator-program/apply'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF6B5CE7),
                padding: const EdgeInsets.symmetric(
                    horizontal: 36, vertical: 18),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                'Apply to Creator Program',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No follower minimum • Free to join • Reviewed within 48 hours',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white54,
              ),
            ),
          ],
        ),
      );
    });
  }

  // ─── Footer ───────────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/sumquiz_logo.png',
                width: 28,
                height: 28,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.stars_rounded,
                  color: Color(0xFFC084FC),
                  size: 28,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'SumQuiz Creator Program',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Empowering Educational Creators & Student Influencers.',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white54),
          ),
          const SizedBox(height: 28),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 28,
            runSpacing: 12,
            children: [
              _footerLink('For Students', () => context.go('/landing')),
              _footerLink('For Teachers', () => context.go('/educators')),
              _footerLink('Creator Partnership', () => context.go('/creator-program')),
              _footerLink('Pricing & Pro', () => context.push('/settings/subscription')),
              _footerLink('Apply as Creator', () => context.go('/creator-program/apply')),
            ],
          ),
          const SizedBox(height: 32),
          const Divider(color: Colors.white12),
          const SizedBox(height: 20),
          Text(
            '© ${DateTime.now().year} SumQuiz. All rights reserved.',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white38),
          ),
        ],
      ),
    );
  }

  Widget _footerLink(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: Colors.white70,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

