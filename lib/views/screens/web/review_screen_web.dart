import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/auth_service.dart';
import '../../../providers/sync_provider.dart';
import '../../../services/local_database_service.dart';
import '../../../services/spaced_repetition_service.dart';
import '../../../models/flashcard.dart';
import '../../../models/user_model.dart';
import '../../../models/daily_mission.dart';
import '../../../services/mission_service.dart';
import '../../../services/mastery/sumi_tutor_service.dart';
import '../../../services/user_service.dart';
import '../../../views/screens/spaced_repetition_screen.dart';
import '../../../view_models/mastery_view_model.dart';
import '../../../views/widgets/sumi_live_sandbox_overlay.dart';
import '../../../views/widgets/web/role_selection_dialog.dart';
import '../../../theme/web_theme.dart';

class ReviewScreenWeb extends StatefulWidget {
  final bool autoStartMission;
  const ReviewScreenWeb({super.key, this.autoStartMission = false});

  @override
  State<ReviewScreenWeb> createState() => _ReviewScreenWebState();
}

class _ReviewScreenWebState extends State<ReviewScreenWeb> {
  DailyMission? _dailyMission;
  bool _isLoading = true;

  // In-page Study Session State for Web
  bool _isStudying = false;
  List<Flashcard> _studyCards = [];
  int _currentCardIndex = 0;
  bool _isFlipped = false;
  int _correctCount = 0;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNewUser();
    });
  }

  Future<void> _checkNewUser() async {
    final prefs = await SharedPreferences.getInstance();
    final isNew = prefs.getBool('is_new_user') ?? false;
    if (isNew && mounted) {
      await prefs.remove('is_new_user');
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const RoleSelectionDialog(),
        );
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadDashboardData();
  }

  @override
  void didUpdateWidget(ReviewScreenWeb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoStartMission && !oldWidget.autoStartMission) {
      _startMission();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopwatch.stop();
    super.dispose();
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
      if (mounted) {
        setState(() {
          _dailyMission = mission;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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

      setState(() {
        _studyCards = cards;
        _isStudying = true;
        _isLoading = false;
        _currentCardIndex = 0;
        _isFlipped = false;
        _correctCount = 0;
      });
      _stopwatch.reset();
      _stopwatch.start();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _nextCard(bool known) {
    if (known) _correctCount++;

    final currentCard = _studyCards[_currentCardIndex];
    final authService = Provider.of<AuthService>(context, listen: false);
    final localDb = Provider.of<LocalDatabaseService>(context, listen: false);
    final userId = authService.currentUser?.uid;

    if (userId != null) {
      final srsService =
          SpacedRepetitionService(localDb.getSpacedRepetitionBox());
      srsService.updateReview(currentCard.id, known);
    }

    if (_currentCardIndex < _studyCards.length - 1) {
      setState(() {
        _currentCardIndex++;
        _isFlipped = false;
      });
    } else {
      _endStudySession();
    }
  }

  void _endStudySession() async {
    _stopwatch.stop();
    _timer?.cancel();

    final userId =
        Provider.of<AuthService>(context, listen: false).currentUser?.uid;
    if (userId != null) {
      final missionService =
          Provider.of<MissionService>(context, listen: false);
      final userService = UserService();

      double accuracy =
          _studyCards.isEmpty ? 0 : _correctCount / _studyCards.length;

      try {
        if (_dailyMission != null && !_dailyMission!.isCompleted) {
          await missionService.completeMission(
              userId, _dailyMission!, accuracy);
        }
        await userService.incrementItemsCompleted(userId);
        if (mounted) {
          await context
              .read<SumiTutorService>()
              .checkAndScheduleRetentionAlert(userId);
        }
      } catch (e) {
        debugPrint('Session complete error: $e');
      }

      await _loadDashboardData();
    }

    if (mounted) {
      setState(() => _isStudying = false);
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Session Complete! 🎉',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events_rounded,
                size: 64, color: Color(0xFFF59E0B)),
            const SizedBox(height: 16),
            Text(
              'You got $_correctCount out of ${_studyCards.length} correct!',
              style: GoogleFonts.outfit(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Time Spent: ${_formatDuration(_stopwatch.elapsed)}',
              style: GoogleFonts.inter(color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: WebColors.purplePrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Continue Learning'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
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

    if (_isStudying) {
      return _buildStudySession(isDark);
    }

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Consumer<MasteryViewModel?>(
          builder: (context, masteryVm, _) {
            if (_isLoading || (masteryVm != null && masteryVm.isLoading)) {
              return const Center(
                child:
                    CircularProgressIndicator(color: WebColors.purplePrimary),
              );
            }

            return RefreshIndicator(
              color: WebColors.purplePrimary,
              onRefresh: () async {
                await _loadDashboardData();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Top Header Bar
                        _buildTopHeader(user, isDark),
                        const SizedBox(height: 28),

                        // 2. Greeting Title
                        _buildGreeting(user, isDark),
                        const SizedBox(height: 24),

                        // 3. Responsive Main Layout
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isDesktop = constraints.maxWidth >= 950;
                            if (isDesktop) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Left Column
                                  Expanded(
                                    flex: 6,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildActiveDeckCard(
                                            masteryVm, isDark),
                                        const SizedBox(height: 24),
                                        _buildSumiInsightCard(
                                            masteryVm, isDark),
                                        const SizedBox(height: 28),
                                        _buildFocusAreasSection(
                                            masteryVm, isDark),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 28),
                                  // Right Column
                                  Expanded(
                                    flex: 4,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildStatsGrid(
                                            user, masteryVm, isDark),
                                        const SizedBox(height: 24),
                                        _buildDailyMissionCard(isDark),
                                        const SizedBox(height: 24),
                                        _buildQuickStudyCard(isDark),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }

                            // Mobile / Tablet Stacked Layout
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildStatsGrid(user, masteryVm, isDark),
                                const SizedBox(height: 20),
                                _buildActiveDeckCard(masteryVm, isDark),
                                const SizedBox(height: 20),
                                _buildSumiInsightCard(masteryVm, isDark),
                                const SizedBox(height: 20),
                                _buildDailyMissionCard(isDark),
                                const SizedBox(height: 28),
                                _buildFocusAreasSection(masteryVm, isDark),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
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
        CircleAvatar(
          radius: 20,
          backgroundColor: WebColors.purplePrimary.withValues(alpha: 0.1),
          backgroundImage:
              user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
          child: user?.photoURL == null
              ? Image.asset(
                  'assets/images/sumi.png',
                  width: 30,
                  height: 30,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.person_rounded,
                    color: WebColors.purplePrimary,
                    size: 22,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Text(
          'SumQuiz',
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        const Spacer(),
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
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF3E8FF),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 15)),
              const SizedBox(width: 6),
              Text(
                '$streak Day Streak',
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
        : 'Student';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_getGreeting()}\n$firstName',
          style: GoogleFonts.outfit(
            fontSize: 34,
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

  Widget _buildStatsGrid(
      UserModel? user, MasteryViewModel? masteryVm, bool isDark) {
    final streak = user?.missionCompletionStreak ?? 12;
    final retentionPct =
        masteryVm != null ? (masteryVm.retentionHealth * 100).toInt() : 88;

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
      childAspectRatio: 2.5,
      children: stats
          .map((s) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : const Color(0xFFE2E8F0),
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
                    Icon(s.icon, color: WebColors.purplePrimary, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.title,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color:
                              isDark ? Colors.white : const Color(0xFF1E293B),
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
    final activeTopicName =
        (masteryVm != null && masteryVm.priorityTopics.isNotEmpty)
            ? masteryVm.priorityTopics.first.name
            : 'Cellular Biology & Genetics';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : const Color(0xFFE2E8F0),
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
              Container(
                width: 58,
                height: 58,
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
                      size: 26,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activeTopicName,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Est. 5 mins active recall review',
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
          const SizedBox(height: 20),
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
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
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
    final activeTopicName =
        (masteryVm != null && masteryVm.priorityTopics.isNotEmpty)
            ? masteryVm.priorityTopics.first.name
            : 'Cellular Biology';
    final decayPct =
        (masteryVm != null && masteryVm.priorityTopics.isNotEmpty)
            ? (masteryVm.priorityTopics.first.forgettingRisk * 100).toInt()
            : 42;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Image.asset(
                    'assets/images/sumi.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.smart_toy_rounded,
                      color: Color(0xFF2563EB),
                      size: 26,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
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
                          color: const Color(0xFFEF4444),
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
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    showGeneralDialog(
                      context: context,
                      barrierDismissible: true,
                      barrierLabel: "Sumi Tutor",
                      pageBuilder: (context, _, __) =>
                          const SumiLiveSandboxOverlay(),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: const Text('Talk with Sumi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : const Color(0xFFE2E8F0),
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
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: const Color(0xFFF97316),
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt_rounded,
                        size: 14, color: Color(0xFFD97706)),
                    const SizedBox(width: 2),
                    Text(
                      '+50 XP',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _dailyMission?.title ?? 'Review 8 Key Cards',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : const Color(0xFFE2E8F0),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFFF97316)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$completed/$total cards reviewed today',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startMission,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                _dailyMission?.isCompleted == true
                    ? 'Mission Completed'
                    : 'Start Mission',
                style: GoogleFonts.inter(
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

  // ─── Quick Study Card ────────────────────────────────────────────────────────

  Widget _buildQuickStudyCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : const Color(0xFFE2E8F0),
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
              const Icon(Icons.flash_on_rounded,
                  color: WebColors.purplePrimary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Quick Actions',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _quickActionTile(
            icon: Icons.add_circle_outline_rounded,
            title: 'New Study Pack',
            subtitle: 'Upload PDF, text or link',
            onTap: () => context.go('/create-content'),
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          _quickActionTile(
            icon: Icons.menu_book_rounded,
            title: 'Open Library',
            subtitle: 'Browse all saved decks',
            onTap: () => context.go('/library'),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _quickActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: WebColors.purplePrimary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // ─── 7. Focus Areas Section ────────────────────────────────────────────────────

  Widget _buildFocusAreasSection(MasteryViewModel? masteryVm, bool isDark) {
    final topics = (masteryVm != null && masteryVm.priorityTopics.isNotEmpty)
        ? masteryVm.priorityTopics
        : [
            PriorityTopic(
              name: 'Cellular Respiration & Krebs',
              retentionScore: 0.82,
              totalCards: 18,
              forgettingRisk: 0.25,
            ),
            PriorityTopic(
              name: 'Genetics & Punnett Squares',
              retentionScore: 0.65,
              totalCards: 14,
              forgettingRisk: 0.45,
            ),
            PriorityTopic(
              name: 'Enzyme Kinetics & Catalysis',
              retentionScore: 0.90,
              totalCards: 22,
              forgettingRisk: 0.12,
            ),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Focus Areas',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            TextButton(
              onPressed: () => context.go('/library'),
              child: Text(
                'View All Library',
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
        ...topics.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildTopicCard(t, isDark),
            )),
      ],
    ).animate().fadeIn(delay: 250.ms, duration: 250.ms);
  }

  Widget _buildTopicCard(PriorityTopic topic, bool isDark) {
    final masteryPct = (topic.retentionScore * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : const Color(0xFFE2E8F0),
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: WebColors.purplePrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.style_rounded,
              color: WebColors.purplePrimary,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  topic.name,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${topic.totalCards} cards · $masteryPct% retention',
                  style:
                      GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SpacedRepetitionScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: WebColors.purplePrimary.withValues(alpha: 0.1),
              foregroundColor: WebColors.purplePrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Study',
              style:
                  GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Study Session Screen for Web ─────────────────────────────────────────────

  Widget _buildStudySession(bool isDark) {
    if (_studyCards.isEmpty) {
      return const Center(child: Text('No cards to study'));
    }

    final card = _studyCards[_currentCardIndex];
    final progress = (_currentCardIndex + 1) / _studyCards.length;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => setState(() => _isStudying = false),
        ),
        title: Text(
          'Daily Mission (${_currentCardIndex + 1}/${_studyCards.length})',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Text(
                _formatDuration(_stopwatch.elapsed),
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        WebColors.purplePrimary),
                  ),
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _isFlipped = !_isFlipped),
                    borderRadius: BorderRadius.circular(24),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(32),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark
                              ? Colors.white12
                              : WebColors.purplePrimary.withValues(alpha: 0.2),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isFlipped ? 'ANSWER' : 'QUESTION',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _isFlipped
                                  ? const Color(0xFF10B981)
                                  : WebColors.purplePrimary,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _isFlipped ? card.answer : card.question,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Click to ${_isFlipped ? 'hide' : 'reveal'} answer',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _nextCard(false),
                        icon: const Icon(Icons.close_rounded,
                            color: Color(0xFFEF4444)),
                        label: const Text('Again'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0xFFEF4444)),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _nextCard(true),
                        icon: const Icon(Icons.check_rounded,
                            color: Colors.white),
                        label: const Text('Got It!'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

