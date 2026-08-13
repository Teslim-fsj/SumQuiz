import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../services/auth_service.dart';
import '../../providers/sync_provider.dart';
import '../../services/local_database_service.dart';
import '../../models/flashcard_set.dart';
import '../../models/user_model.dart';
import '../../models/daily_mission.dart';
import '../../services/mission_service.dart';
import '../../services/mastery/sumi_tutor_service.dart';
import '../../services/user_service.dart';
import 'spaced_repetition_screen.dart';
import 'package:sumquiz/view_models/mastery_view_model.dart';
import 'flashcards_screen.dart';
import '../widgets/sumi_live_sandbox_overlay.dart';
import '../../theme/web_theme.dart';

class ReviewScreen extends StatefulWidget {
  final bool autoStartMission;
  const ReviewScreen({super.key, this.autoStartMission = false});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  DailyMission? _dailyMission;
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadDashboardData();
  }

  @override
  void didUpdateWidget(ReviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoStartMission && !oldWidget.autoStartMission) {
      _startMission();
    }
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;

    final localDb = Provider.of<LocalDatabaseService>(context, listen: false);
    await localDb.init();

    if (mounted) {
      await Provider.of<SyncProvider>(context, listen: false).syncData();
    }

    await _loadMission();

    if (widget.autoStartMission) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startMission();
      });
    }
  }

  Future<void> _loadMission() async {
    if (!mounted) return;
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.uid;

    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final missionService =
          Provider.of<MissionService>(context, listen: false);
      final mission = await missionService.generateDailyMission(userId);
      setState(() {
        _dailyMission = mission;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startMission() async {
    if (_dailyMission == null) return;
    setState(() => _isLoading = true);

    try {
      final userId =
          Provider.of<AuthService>(context, listen: false).currentUser?.uid;
      final missionService =
          Provider.of<MissionService>(context, listen: false);
      final cards = await missionService.fetchMissionCards(
          userId!, _dailyMission!.flashcardIds);

      if (cards.isEmpty) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No flashcards found for mission.')),
          );
        }
        return;
      }

      setState(() => _isLoading = false);
      if (!mounted) return;

      final reviewSet = FlashcardSet(
        id: 'mission_session',
        title: 'Daily Mission',
        flashcards: cards,
        timestamp: Timestamp.now(),
      );

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FlashcardsScreen(flashcardSet: reviewSet),
        ),
      );

      if (result != null && result is double && mounted) {
        await missionService.completeMission(userId, _dailyMission!, result);
        if (mounted) {
          await context
              .read<SumiTutorService>()
              .checkAndScheduleRetentionAlert(userId);
        }
        final userService = UserService();
        await userService.incrementItemsCompleted(userId);
        _loadDashboardData();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Consumer<MasteryViewModel?>(
          builder: (context, masteryVm, _) {
            if (_isLoading || (masteryVm != null && masteryVm.isLoading)) {
              return const Center(
                child: CircularProgressIndicator(color: WebColors.purplePrimary),
              );
            }

            return RefreshIndicator(
              color: WebColors.purplePrimary,
              onRefresh: () async {
                await _loadDashboardData();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Top Header Bar (Avatar, Brand, Notifications, Streak)
                    _buildTopHeader(user, isDark),
                    const SizedBox(height: 24),

                    // 2. Greeting Title
                    _buildGreeting(user, isDark),
                    const SizedBox(height: 20),

                    // 3. 4-Card Stats Grid (Streak, XP, Retention, Scholar Level)
                    _buildStatsGrid(user, masteryVm, isDark),
                    const SizedBox(height: 20),

                    // 4. Active Deck Review Card ("Startup Business")
                    _buildActiveDeckCard(masteryVm, isDark),
                    const SizedBox(height: 20),

                    // 5. Sumi AI Retention Insight Alert Card
                    _buildSumiInsightCard(masteryVm, isDark),
                    const SizedBox(height: 20),

                    // 6. Daily Mission Progress Card
                    _buildDailyMissionCard(isDark),
                    const SizedBox(height: 28),

                    // 7. Focus Areas Section
                    _buildFocusAreasSection(masteryVm, isDark),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ─── 1. Top Header Bar ─────────────────────────────────────────────────────────

  Widget _buildTopHeader(UserModel? user, bool isDark) {
    final streak = user?.missionCompletionStreak ?? 12;
    return Row(
      children: [
        // User Profile Avatar
        CircleAvatar(
          radius: 18,
          backgroundColor: WebColors.purplePrimary.withValues(alpha: 0.1),
          backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
          child: user?.photoURL == null
              ? Image.asset(
                  'assets/images/sumi.png',
                  width: 28,
                  height: 28,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.person_rounded,
                    color: WebColors.purplePrimary,
                    size: 20,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 10),
        // Brand Name
        Text(
          'SumQuiz',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        const Spacer(),
        // Notification Bell Icon with Badge
        IconButton(
          onPressed: () {},
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                Icons.notifications_none_rounded,
                size: 24,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        // Streak Pill Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF3E8FF),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                '$streak',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF7C3AED),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── 2. Greeting Header ────────────────────────────────────────────────────────

  Widget _buildGreeting(UserModel? user, bool isDark) {
    final firstName = user?.displayName.isNotEmpty == true
        ? user!.displayName.split(' ').first
        : 'Teslim';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_getGreeting()}\n$firstName',
          style: GoogleFonts.outfit(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            height: 1.15,
            letterSpacing: -0.8,
          ),
        ).animate().fadeIn(duration: 250.ms),
      ],
    );
  }

  // ─── 3. 4-Card Quick Stats Grid ────────────────────────────────────────────────

  Widget _buildStatsGrid(UserModel? user, MasteryViewModel? masteryVm, bool isDark) {
    final streak = user?.missionCompletionStreak ?? 12;
    final retentionPct = masteryVm != null ? (masteryVm.retentionHealth * 100).toInt() : 88;

    final stats = [
      (
        icon: Icons.local_fire_department_rounded,
        title: '$streak Day Streak',
      ),
      (
        icon: Icons.bolt_rounded,
        title: '250 Daily XP',
      ),
      (
        icon: Icons.trending_up_rounded,
        title: '$retentionPct% Retention',
      ),
      (
        icon: Icons.stars_rounded,
        title: 'Lvl 4 Scholar',
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.6,
      children: stats
          .map((s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(s.icon, color: WebColors.purplePrimary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.title,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    ).animate().fadeIn(delay: 50.ms, duration: 250.ms);
  }

  // ─── 4. Active Deck Review Card ────────────────────────────────────────────────

  Widget _buildActiveDeckCard(MasteryViewModel? masteryVm, bool isDark) {
    final activeTopicName = (masteryVm != null && masteryVm.priorityTopics.isNotEmpty)
        ? masteryVm.priorityTopics.first.name
        : 'Startup Business';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Circular Progress Ring Icon Container
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: WebColors.purplePrimary,
                    width: 3,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFF3E8FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      color: WebColors.purplePrimary,
                      size: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activeTopicName,
                      style: GoogleFonts.outfit(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Est. 5 mins review',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Continue Learning Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SpacedRepetitionScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: WebColors.purplePrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Continue Learning',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 250.ms);
  }

  // ─── 5. Sumi AI Insight Alert Card ─────────────────────────────────────────────

  Widget _buildSumiInsightCard(MasteryViewModel? masteryVm, bool isDark) {
    final activeTopicName = (masteryVm != null && masteryVm.priorityTopics.isNotEmpty)
        ? masteryVm.priorityTopics.first.name
        : 'Startup Business';
    final decayPct = (masteryVm != null && masteryVm.priorityTopics.isNotEmpty)
        ? (masteryVm.priorityTopics.first.forgettingRisk * 100).toInt()
        : 42;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF), // Soft light blue
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sumi Mascot Circle Avatar
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Image.asset(
                    'assets/images/sumi.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.smart_toy_rounded,
                      color: Color(0xFF2563EB),
                      size: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF1E3A8A),
                      height: 1.5,
                    ),
                    children: [
                      const TextSpan(text: 'You have forgotten '),
                      TextSpan(
                        text: '$decayPct%',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFEF4444), // Highlight red
                        ),
                      ),
                      TextSpan(
                          text:
                              ' of $activeTopicName. A 5 minute review today prevents losing everything.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Action Buttons (Talk with Sumi & Quick Review)
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    showGeneralDialog(
                      context: context,
                      barrierDismissible: true,
                      barrierLabel: "Sumi Tutor",
                      pageBuilder: (context, _, __) => const SumiLiveSandboxOverlay(),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: const Text('Talk with Sumi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SpacedRepetitionScreen(),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Quick Review',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 150.ms, duration: 250.ms);
  }

  // ─── 6. Daily Mission Progress Card ────────────────────────────────────────────

  Widget _buildDailyMissionCard(bool isDark) {
    final completed = _dailyMission?.isCompleted == true ? 8 : 5;
    final total = 8;
    final progress = completed / total;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Sparkles Icon + DAILY MISSION label + XP Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEDD5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFFF97316),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'DAILY MISSION',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '+120 XP',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF7C3AED),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress Title
          Text(
            '$completed/$total Complete',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          // Linear Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFFF3E8FF),
              valueColor: const AlwaysStoppedAnimation<Color>(WebColors.purplePrimary),
            ),
          ),
          const SizedBox(height: 16),
          // Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _startMission,
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('Continue Mission'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF3E8FF),
                foregroundColor: WebColors.purplePrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 250.ms);
  }

  // ─── 7. Focus Areas Section ─────────────────────────────────────────────────────

  Widget _buildFocusAreasSection(MasteryViewModel? masteryVm, bool isDark) {
    final topics = (masteryVm != null && masteryVm.priorityTopics.isNotEmpty)
        ? masteryVm.priorityTopics
        : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Focus Areas',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SpacedRepetitionScreen(),
                ),
              ),
              child: Text(
                'View All',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: WebColors.purplePrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (topics.isEmpty) ...[
          _buildFocusAreaCard(
            title: 'Startup business',
            decayText: '100% decay',
            isTanIcon: true,
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          _buildFocusAreaCard(
            title: 'Advanced Python',
            decayText: '72% decay',
            isTanIcon: false,
            isDark: isDark,
          ),
        ] else ...[
          ...topics.take(3).map((topic) {
            final decayPct = (topic.forgettingRisk * 100).toInt();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildFocusAreaCard(
                title: topic.name,
                decayText: '$decayPct% decay',
                isTanIcon: topic.forgettingRisk > 0.8,
                isDark: isDark,
              ),
            );
          }),
        ],
      ],
    ).animate().fadeIn(delay: 250.ms, duration: 250.ms);
  }

  Widget _buildFocusAreaCard({
    required String title,
    required String decayText,
    required bool isTanIcon,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SpacedRepetitionScreen(),
            ),
          ),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon Box
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isTanIcon ? const Color(0xFFFDE68A).withValues(alpha: 0.3) : const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    color: isTanIcon ? const Color(0xFFD97706) : WebColors.purplePrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            decayText,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('•', style: TextStyle(color: Colors.grey, fontSize: 10)),
                          const SizedBox(width: 8),
                          const Text('🟠 ', style: TextStyle(fontSize: 10)),
                          Text(
                            'High Priority',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey[400],
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
