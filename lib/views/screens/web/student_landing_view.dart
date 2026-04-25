import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:sumquiz/theme/web_theme.dart';

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
            _buildTabToggle(),
            _buildStudentHeroSection(),
            _buildStepsSection(),
            _buildFeatureGridSection(),
            _buildReviewsSection(),
            _buildCtaSection(),
            _buildStudentFooter(),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: WebColors.purplePrimary,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                    color: WebColors.purplePrimary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Text('STUDENT',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 13,
                    letterSpacing: 1.2)),
          ),
          InkWell(
            onTap: () => context.go('/Educators'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text('EDUCATION',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                      fontSize: 13,
                      letterSpacing: 1.2)),
            ),
          )
        ],
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
              Text('AI-POWERED LEARNING ASSISTANT',
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
              const TextSpan(text: 'Your notes.\n'),
              TextSpan(
                  text: 'Your AI.\n',
                  style: GoogleFonts.outfit(color: WebColors.purplePrimary)),
              const TextSpan(text: 'Your growth.'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Transform any PDF, photo, or lecture recording into\npersonalized study guides, interactive quizzes, and\nsmart flashcards in seconds.',
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
                Text('18,000+ Nigerian Students',
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
              Text('Master any subject in 3 steps',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                      fontSize: isMobile ? 28 : 40,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1)),
              const SizedBox(height: 16),
              Text(
                'We\'ve distilled the complex process of learning into a seamless, high-speed journey designed for the modern student.',
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
                            Icons.description,
                            '1. Upload your content',
                            'Drop your messy PDFs, voice notes, or lecture photos. Our AI reads and organizes everything instantly.'),
                        const SizedBox(height: 32),
                        _buildStepItem(
                            Icons.auto_awesome,
                            '2. AI Works Its Magic',
                            'In seconds, get syllabus-aligned summaries, flashcards, and exam-standard quizzes generated just for you.'),
                        const SizedBox(height: 32),
                        _buildStepItem(
                            Icons.verified,
                            '3. Achieve Total Mastery',
                            'Track your retention levels, complete daily study missions, and enter your exams with 100% confidence.'),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            child: _buildStepItem(
                                Icons.description,
                                '1. Upload your content',
                                'Drop your messy PDFs, voice notes, or lecture photos. Our AI reads and organizes everything instantly.')),
                        _buildConnector(),
                        Expanded(
                            child: _buildStepItem(
                                Icons.auto_awesome,
                                '2. AI Works Its Magic',
                                'In seconds, get syllabus-aligned summaries, flashcards, and exam-standard quizzes generated just for you.')),
                        _buildConnector(),
                        Expanded(
                            child: _buildStepItem(
                                Icons.verified,
                                '3. Achieve Total Mastery',
                                'Track your retention levels, complete daily study missions, and enter your exams with 100% confidence.')),
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
                    Text('Why Students Love SumQuiz',
                        style: GoogleFonts.outfit(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                            height: 1.1)),
                    const SizedBox(height: 16),
                    Text(
                        'Traditional studying is slow. SumQuiz uses neuroscience-backed AI to accelerate your learning.',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey[600],
                            height: 1.5)),
                    const SizedBox(height: 24),
                    _buildCheckFeature(
                        'Curated Content for Nigerian Syllabuses'),
                    const SizedBox(height: 12),
                    _buildCheckFeature('AI Summary of 50-page PDFs in seconds'),
                    const SizedBox(height: 12),
                    _buildCheckFeature(
                        '24/7 Accessibility on all your devices'),
                    const SizedBox(height: 40),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.1,
                      children: [
                        _buildGridCard(Icons.lock, 'Private & Secure',
                            'Your study data is encrypted.'),
                        _buildGridCard(Icons.update, 'Smart Spacing',
                            'Review facts exactly when needed.'),
                        _buildGridCard(Icons.wifi_off, 'Offline Ready',
                            'Study anywhere, anytime.'),
                        _buildGridCard(Icons.flag, 'Daily Missions',
                            'Gamified challenges for motivation.'),
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
                          Text('Why Students Love\nSumQuiz',
                              style: GoogleFonts.outfit(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1,
                                  height: 1.1)),
                          const SizedBox(height: 24),
                          Text(
                              'Traditional studying is slow. SumQuiz uses neuroscience-backed AI to accelerate your learning speed while reducing the effort required to retain information.',
                              style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                  height: 1.5)),
                          const SizedBox(height: 40),
                          _buildCheckFeature(
                              'Curated Content for Nigerian Syllabuses'),
                          const SizedBox(height: 16),
                          _buildCheckFeature(
                              'AI Summary of 50-page PDFs in seconds'),
                          const SizedBox(height: 16),
                          _buildCheckFeature(
                              '24/7 Accessibility on all your devices'),
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
                        childAspectRatio: 1.2,
                        children: [
                          _buildGridCard(Icons.lock, 'Private & Secure',
                              'Your study data is encrypted and remains your personal property.'),
                          _buildGridCard(Icons.update, 'Smart Spacing',
                              'Review facts that appear exactly when you\'re about to forget.'),
                          _buildGridCard(Icons.wifi_off, 'Offline Ready',
                              'Study anywhere, explore areas with low connectivity.'),
                          _buildGridCard(Icons.flag, 'Daily Missions',
                              'Gamified challenges to keep your motivation high.'),
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

  Widget _buildGridCard(IconData icon, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: WebColors.purplePrimary, size: 28),
          const SizedBox(height: 16),
          Text(title,
              style: GoogleFonts.outfit(
                  fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(desc,
              style: GoogleFonts.inter(
                  fontSize: 12, color: Colors.grey[600], height: 1.5)),
        ],
      ),
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
                        Text('THE LUMINARY EFFECT',
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                color: WebColors.purplePrimary)),
                        const SizedBox(height: 12),
                        Text('Joined by 18,000+ Students',
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
                                'I created domains on my phone, and by the time I\'m home SumQuiz has a full summary ready. It\'s like having a personal tutor.',
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
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
              children: List.generate(
                  5,
                  (index) =>
                      const Icon(Icons.star, color: Colors.amber, size: 16))),
          const SizedBox(height: 24),
          Text('\"$quote\"',
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
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 100),
          child: Container(
            padding: EdgeInsets.all(isMobile ? 32 : 80),
            decoration: BoxDecoration(
              gradient: WebColors.AccentGradient,
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                    blurRadius: 40,
                    offset: const Offset(0, 20))
              ],
            ),
            child: Column(
              children: [
                Text('Ready to accelerate your learning?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                        fontSize: isMobile ? 32 : 48,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.1)),
                const SizedBox(height: 24),
                Text(
                    'Join 18,000+ students already mastering their subjects with SumQuiz AI.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        fontSize: 18,
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.5)),
                const SizedBox(height: 48),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () => context.go('/auth'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: WebColors.purplePrimary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 24),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                      child: Text('Get Started for Free',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold, fontSize: 16)),
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
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 80),
          color: Colors.white,
          child: Column(
            children: [
              isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFooterLogo(),
                        const SizedBox(height: 40),
                        _buildFooterLinks(),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(flex: 2, child: _buildFooterLogo()),
                        Expanded(flex: 3, child: _buildFooterLinks()),
                      ],
                    ),
              const SizedBox(height: 80),
              Divider(color: Colors.grey[200]),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('© 2026 SumQuiz. All rights reserved.',
                      style: GoogleFonts.inter(
                          fontSize: 14, color: Colors.grey[500])),
                  Row(
                    children: [
                      _socialIcon(Icons.facebook),
                      const SizedBox(width: 16),
                      _socialIcon(Icons.camera_alt),
                      const SizedBox(width: 16),
                      _socialIcon(Icons.chat_bubble),
                    ],
                  )
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildFooterLogo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Image.asset('assets/images/sumquiz_logo.png',
                width: 32,
                height: 32,
                errorBuilder: (_, __, ___) => const Icon(Icons.school,
                    color: WebColors.purplePrimary, size: 32)),
            const SizedBox(width: 12),
            Text('SumQuiz',
                style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1F1F1F),
                    letterSpacing: -0.5)),
          ],
        ),
        const SizedBox(height: 24),
        Text(
            'The intelligence layer for modern\neducation. Empowering Nigerian\nscholars through cutting-edge AI.',
            style: GoogleFonts.inter(
                fontSize: 14, color: Colors.grey[500], height: 1.6)),
      ],
    );
  }

  Widget _buildFooterLinks() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
            child: _footerCol('STUDY', [
          'Library',
          'Spaced Repetition',
          'Deep Scan',
          'Syllabus Guide'
        ])),
        Expanded(
            child: _footerCol('RESOURCES',
                ['Blog', 'Help Center', 'Student Stories', 'Community'])),
        Expanded(
            child: _footerCol(
                'COMPANY', ['About', 'Careers', 'Privacy', 'Terms'])),
      ],
    );
  }

  Widget _footerCol(String title, List<String> links) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: const Color(0xFF1F1F1F))),
        const SizedBox(height: 24),
        ...links.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(e,
                  style:
                      GoogleFonts.inter(fontSize: 14, color: Colors.grey[600])),
            )),
      ],
    );
  }

  Widget _socialIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 18, color: Colors.grey[600]),
    );
  }
}
