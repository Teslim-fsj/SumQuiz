import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sumquiz/theme/web_theme.dart';

class CreatorTabView extends StatelessWidget {
  const CreatorTabView({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeroSection(context),
          _buildVisualStats(context),
          _buildProcessSection(context),
          _buildFeaturesSection(context),
          _buildTestimonials(context),
          _buildFAQ(context),
          _buildCTASection(context),
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            WebColors.background,
            WebColors.primary.withOpacity(0.05),
            const Color(0xFFF3E8FF), // Light purple for creator vibe
          ],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Row(
            children: [
              // Left Content
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: WebColors.primary.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.school,
                              color: WebColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Tools for Teachers & Tutors',
                            style: TextStyle(
                              color: WebColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.2),
                    const SizedBox(height: 24),
                    Text(
                      'The All-in-One Educator Platform',
                      style: TextStyle(
                        fontSize: 60,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        letterSpacing: -1,
                        color: WebColors.primary,
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 200.ms, duration: 600.ms)
                        .slideX(begin: -0.2),
                    const SizedBox(height: 24),
                    Text(
                      'Automate content creation, manage student performance with AI-driven insights, and deliver professional exams — all from a single, powerful dashboard.',
                      style: TextStyle(
                        fontSize: 20,
                        color: WebColors.textSecondary,
                        height: 1.6,
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 400.ms, duration: 600.ms)
                        .slideX(begin: -0.2),
                    const SizedBox(height: 48),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _buildPrimaryButton(context, 'Launch Dashboard',
                            () => context.go('/auth')),
                        _buildSecondaryButton(
                            context,
                            'Watch Demo',
                            () => launchUrl(Uri.parse(
                                'https://sumquiz.xyz/demo'))),
                      ],
                    ).animate().fadeIn(delay: 600.ms, duration: 600.ms),
                    const SizedBox(height: 40),
                    Row(
                      children: [
                        _buildTrustBadge(
                            Icons.dashboard_customize_outlined, 'Centralized Command'),
                        _buildTrustBadge(
                            Icons.query_stats_outlined, 'Real-time Analytics'),
                        _buildTrustBadge(
                            Icons.psychology_outlined, 'AI Feedback Engine'),
                      ],
                    ).animate().fadeIn(delay: 800.ms),
                  ],
                ),
              ),
              const SizedBox(width: 60),
              // Right Image
              Expanded(
                flex: 1,
                child: Container(
                  height: 500,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: WebColors.primary.withOpacity(0.2),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Image.asset(
                      'assets/images/web/teacher_dashboard_preview.png', // Updated placeholder name
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: WebColors.primary.withOpacity(0.05),
                        child: Center(
                          child: Icon(Icons.dashboard, size: 80, color: WebColors.primary.withOpacity(0.2)),
                        ),
                      ),
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(duration: 800.ms)
                    .scale(begin: const Offset(0.9, 0.9)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrustBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.only(right: 12),
      decoration: WebColors.glassDecoration(
        blur: 10,
        opacity: 0.8,
        color: WebColors.surface,
        borderRadius: 20,
      ).copyWith(
        boxShadow: WebColors.subtleShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: WebColors.primary, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: WebColors.textPrimary,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton(
      BuildContext context, String text, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: WebColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 17,
        ),
      ),
      child: Text(text),
    ).animate().scale(delay: 100.ms);
  }

  Widget _buildSecondaryButton(
      BuildContext context, String text, VoidCallback onPressed) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: WebColors.primary,
        side: BorderSide(color: WebColors.primary, width: 2),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 17,
        ),
      ),
      child: Text(text),
    );
  }

  Widget _buildVisualStats(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80),
      color: Colors.white,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem('2,500+', 'Active Classrooms', Icons.meeting_room),
              _buildDivider(),
              _buildStatItem('150k+', 'Content Assets', Icons.library_books),
              _buildDivider(),
              _buildStatItem('20hrs+', 'Weekly Savings', Icons.timer),
              _buildDivider(),
              _buildStatItem('92%', 'Student Mastery', Icons.trending_up),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: WebColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: WebColors.primary, size: 32),
        ),
        const SizedBox(height: 16),
        Text(
          value,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: WebColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: WebColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 60,
      width: 1,
      color: Colors.grey.withOpacity(0.2),
    );
  }

  Widget _buildProcessSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80),
      decoration: BoxDecoration(
        color: WebColors.backgroundAlt.withOpacity(0.5),
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Text(
                'THE EDUCATOR WORKFLOW',
                style: TextStyle(
                  color: WebColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'From raw material to academic excellence',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: WebColors.textPrimary,
                ),
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStepCard(1, 'Automated Authoring',
                      'Upload your syllabus or text. Our AI generates exams, flashcards, and summaries instantly.'),
                  _buildStepArrow(),
                  _buildStepCard(2, 'Pro-Level Management',
                      'Organize students into classes, distribute assignments, and track real-time study patterns.'),
                  _buildStepArrow(),
                  _buildStepCard(3, 'Intelligent Feedback',
                      'Bridge the gap with AI-driven insights that identify exactly where each student is struggling.'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepCard(int number, String title, String description) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(32),
      decoration: WebColors.glassDecoration(
        blur: 15,
        opacity: 0.1,
        color: Colors.white,
        borderRadius: 24,
      ).copyWith(
        boxShadow: WebColors.cardShadow,
      ),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [WebColors.primary, const Color(0xFF9333EA)],
              ),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: WebColors.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: WebColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildStepArrow() {
    return Icon(
      Icons.chevron_right,
      color: WebColors.primary.withOpacity(0.3),
      size: 40,
    );
  }

  Widget _buildFeaturesSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80),
      color: Colors.white,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Text(
                'THE SUITE',
                style: TextStyle(
                  color: WebColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Complete modules for the modern educator',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: WebColors.textPrimary,
                ),
              ),
              const SizedBox(height: 48),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 24,
                crossAxisSpacing: 24,
                childAspectRatio: 1.25,
                children: [
                  _buildFeatureCard(
                    'Educator Dashboard',
                    'Your centralized command center for managing study materials, classes, and student performance.',
                    Icons.dashboard_outlined,
                    WebColors.primary,
                  ),
                  _buildFeatureCard(
                    'Student Management',
                    'A robust registry to organize your students, monitor individual progress, and boost engagement.',
                    Icons.people_alt_outlined,
                    WebColors.secondary,
                  ),
                  _buildFeatureCard(
                    'Advanced Analytics',
                    'Deep-dive into mastery heatmaps and study metrics to understand class understanding at a glance.',
                    Icons.pie_chart_outline,
                    WebColors.accent,
                  ),
                  _buildFeatureCard(
                    'AI Feedback Engine',
                    'Automated, intelligent feedback that identifies student gaps and offers real-time remedial guidance.',
                    Icons.psychology_outlined,
                    WebColors.primary,
                  ),
                  _buildFeatureCard(
                    'Professional PDF Exams',
                    'Export beautifully formatted test papers with automated marking schemes from any source material.',
                    Icons.picture_as_pdf_outlined,
                    WebColors.secondary,
                  ),
                  _buildFeatureCard(
                    'Secure Content Sharing',
                    'Distribute interactive study decks and exams directly to your classes with one-click sharing.',
                    Icons.share_outlined,
                    WebColors.accent,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
      String title, String description, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: WebColors.glassDecoration(
        blur: 15,
        opacity: 0.05,
        color: WebColors.surface,
        borderRadius: 20,
      ).copyWith(
        boxShadow: WebColors.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: WebColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: WebColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildTestimonials(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            WebColors.backgroundAlt,
          ],
        ),
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Text(
                'EDUCATOR SUCCESS',
                style: TextStyle(
                  color: WebColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Hear from verified educators',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: WebColors.textPrimary,
                ),
              ),
              const SizedBox(height: 48),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 24,
                crossAxisSpacing: 24,
                childAspectRatio: 1.4,
                children: [
                  _buildEducatorTestimonial(
                    'I save over 10 hours a week on exam preparation. The AI-generated questions are remarkably accurate.',
                    'Dr. David Chen',
                    'University Physics Professor',
                    '10+ hrs',
                    'Saved per week',
                  ),
                  _buildEducatorTestimonial(
                    'The interactive study decks have significantly improved my students\' engagement and test scores.',
                    'Sarah Williams',
                    'High School Biology Teacher',
                    '95%',
                    'Student Engagement',
                  ),
                  _buildEducatorTestimonial(
                    'Being able to export clean PDFs with marking schemes has transformed how I handle midterms.',
                    'Prof. Michael Roberts',
                    'Mathematics Department Head',
                    '15 min',
                    'To create full exams',
                  ),
                  _buildEducatorTestimonial(
                    'I love how I can turn my lecture slides directly into a study hub for my class in seconds.',
                    'Emma Thompson',
                    'History & Arts Tutor',
                    '100+',
                    'Decks Shared',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEducatorTestimonial(
      String quote, String name, String role, String stat, String statLabel) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: WebColors.glassDecoration(
        blur: 15,
        opacity: 0.1,
        color: WebColors.surface,
        borderRadius: 20,
      ).copyWith(
        boxShadow: WebColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: WebColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    name[0],
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: WebColors.textPrimary,
                    ),
                  ),
                  Text(
                    role,
                    style: TextStyle(
                      fontSize: 14,
                      color: WebColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            quote,
            style: TextStyle(
              fontSize: 14,
              color: WebColors.textPrimary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: WebColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.trending_up, color: WebColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  stat,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: WebColors.primary,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  statLabel,
                  style: TextStyle(
                    fontSize: 14,
                    color: WebColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildFAQ(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80),
      color: Colors.white,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              Text(
                'EDUCATOR FAQ',
                style: TextStyle(
                  color: WebColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Everything you need to know',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: WebColors.textPrimary,
                ),
              ),
              const SizedBox(height: 48),
              _buildFAQItem(
                'Can I customize the generated exam questions?',
                'Absolutely! Every question generated by our AI is fully editable. You can tweak the wording, adjust difficulty levels, change the answer options, or add your own custom questions to the mix.',
              ),
              const SizedBox(height: 16),
              _buildFAQItem(
                'What materials can I use to create exams?',
                'You can upload PDFs, PowerPoint presentations, Word documents, or even paste raw text. You can also import content directly from YouTube videos and web articles.',
              ),
              const SizedBox(height: 16),
              _buildFAQItem(
                'How do students access my shared study decks?',
                'When you share a deck, a unique code and link are generated. Students simply enter the code or click the link to import the deck into their own SumQuiz library, where they can study it even offline.',
              ),
              const SizedBox(height: 16),
              _buildFAQItem(
                'Is the marking scheme included in the export?',
                'Yes, when you export an exam as a PDF, you have the option to include a clean, detailed marking scheme that makes grading effortless.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: WebColors.backgroundAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WebColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: WebColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            answer,
            style: TextStyle(
              fontSize: 16,
              color: WebColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCTASection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [WebColors.primary, const Color(0xFF9333EA)],
        ),
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Colors.white, Colors.white],
                ).createShader(bounds),
                child: Text(
                  'Ready to Transform Your Teaching?',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Join our community of educators and start enhancing your classroom today. No technical experience required.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white.withOpacity(0.9),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 48),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildPrimaryButton(context, 'Join Educator Program',
                      () => context.go('/auth')),
                  _buildSecondaryButton(context, 'View Educator Hub',
                      () => context.go('/creator_dashboard')),
                ],
              ),
              const SizedBox(height: 40),
              Text(
                'Free to use • Pro features available • Join thousands of tutors',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      color: WebColors.textPrimary,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: WebColors.HeroGradient,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.auto_awesome_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'SumQuiz Educator',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Empowering educators through AI-assisted teaching.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _buildFooterColumn('For Educators', [
                        'Educator Dashboard',
                        'Time Savings Calculator',
                        'Content Guidelines',
                        'Educator Community',
                      ]),
                      const SizedBox(width: 60),
                      _buildFooterColumn('Resources', [
                        'Educator Handbook',
                        'Best Practices',
                        'Marketing Tips',
                        'Success Stories',
                      ]),
                      const SizedBox(width: 60),
                      _buildFooterColumn('Support', [
                        'Educator Support',
                        'Technical Help',
                        'Subscription Support',
                        'Content Review',
                      ]),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 48),
              Container(
                height: 1,
                color: Colors.white.withOpacity(0.1),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '© 2024 SumQuiz Educator Hub. All rights reserved.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.language,
                            color: Colors.white.withOpacity(0.7)),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: Icon(Icons.facebook,
                            color: Colors.white.withOpacity(0.7)),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: Icon(Icons.link,
                            color: Colors.white.withOpacity(0.7)),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooterColumn(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                item,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
            )),
      ],
    );
  }
}
