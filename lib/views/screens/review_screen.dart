import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:developer' as developer;
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';

import '../../services/auth_service.dart';
import '../../providers/sync_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/local_database_service.dart';
import '../../models/flashcard.dart';
import '../../models/flashcard_set.dart';
import '../../models/user_model.dart';
import '../../models/daily_mission.dart';
import '../../services/mission_service.dart';
import '../../services/user_service.dart';
import 'flashcards_screen.dart';
import 'summary_screen.dart';
import '../../services/mastery/recommendation_service.dart';
import 'package:sumquiz/views/screens/spaced_repetition_screen.dart';
import '../../services/spaced_repetition_service.dart';
import 'package:rxdart/rxdart.dart';
import '../../providers/sumi_provider.dart';
import '../../services/mastery/sumi_tutor_service.dart';
import '../widgets/sumi_live_sandbox_overlay.dart';
import '../../models/sumi_emotion.dart';
import '../../widgets/sumi_mascot.dart';
import '../../models/local_summary.dart';
import '../../models/local_quiz.dart';
import '../../models/local_flashcard_set.dart';
import 'package:sumquiz/view_models/mastery_view_model.dart';
import 'package:sumquiz/views/widgets/knowledge_graph_view.dart';
import 'quiz_screen.dart';
import '../widgets/neural_alert_banner.dart';
import '../../theme/cyber_neural_theme.dart';

class ReviewScreen extends StatefulWidget {
  final bool autoStartMission;
  const ReviewScreen({super.key, this.autoStartMission = false});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  DailyMission? _dailyMission;
  bool _isLoading = true;
  String? _error;
  int _dueCount = 0;
  DateTime? _nextReviewDate;
  double _masteryScore = 0.0;

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

    // Ensure local DB is ready
    final localDb = Provider.of<LocalDatabaseService>(context, listen: false);
    await localDb.init();

    // Trigger and await background sync to refresh content from Firestore
    if (mounted) {
      await Provider.of<SyncProvider>(context, listen: false).syncData();
    }

    // Load both mission and SRS stats concurrently
    await Future.wait([
      _loadMission(),
      _loadSrsStats(),
    ]);

    // Auto-start mission if requested via deep link
    if (widget.autoStartMission) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startMission();
      });
    }
  }

  Future<void> _loadSrsStats() async {
    if (!mounted) return;
    final userId =
        Provider.of<AuthService>(context, listen: false).currentUser?.uid;
    if (userId == null) return;

    try {
      final localDb = Provider.of<LocalDatabaseService>(context, listen: false);
      // init() is now handled in _loadDashboardData
      final srsService =
          SpacedRepetitionService(localDb.getSpacedRepetitionBox());
      final stats = await srsService.getStatistics(userId);
      final nextDate = srsService.getNextReviewDate(userId);
      final mastery = srsService.getMasteryScore(userId);

      if (mounted) {
        setState(() {
          _dueCount = stats['dueForReviewCount'] as int? ?? 0;
          _nextReviewDate = nextDate;
          _masteryScore = mastery;
        });
      }
    } catch (e) {
      developer.log('Error loading SRS stats', error: e);
    }
  }

  Future<void> _loadMission() async {
    if (!mounted) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.uid;

    if (userId == null) {
      setState(() {
        _isLoading = false;
        _error = "User not found.";
      });
      return;
    }

    try {
      final missionService =
          Provider.of<MissionService>(context, listen: false);
      final mission = await missionService.generateDailyMission(userId);

      setState(() {
        _dailyMission = mission;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = "Error loading mission: $e";
      });
    }
  }

  Future<List<Flashcard>> _fetchMissionCards(List<String> cardIds) async {
    final userId =
        Provider.of<AuthService>(context, listen: false).currentUser?.uid;
    if (userId == null) return [];

    final missionService = Provider.of<MissionService>(context, listen: false);
    return await missionService.fetchMissionCards(userId, cardIds);
  }

  Future<void> _startMission() async {
    if (_dailyMission == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No mission available. Please create some study content first.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final cards = await _fetchMissionCards(_dailyMission!.flashcardIds);

      if (cards.isEmpty) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Mission flashcards could not be found locally. Please try syncing again.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.white),
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'SYNC',
                textColor: Colors.white,
                onPressed: () => _loadDashboardData(),
              ),
            ),
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
        await _completeMission(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = "Failed to start mission: $e";
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Error starting mission: ${e.toString().split(':').first}"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _completeMission(double score) async {
    if (_dailyMission == null) return;

    final userId =
        Provider.of<AuthService>(context, listen: false).currentUser?.uid;
    if (userId == null) return;

    final missionService = Provider.of<MissionService>(context, listen: false);
    await missionService.completeMission(userId, _dailyMission!, score);

    final userService = UserService();
    await userService.incrementItemsCompleted(userId);

    _loadDashboardData();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Review & Progress',
            style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1A237E))),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_outlined,
                color: isDark ? Colors.white : const Color(0xFF1A237E)),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No new notifications')),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.settings,
                color: isDark ? Colors.white : const Color(0xFF1A237E)),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Animated Background
          Animate(
            onPlay: (controller) => controller.repeat(reverse: true),
            effects: [
              CustomEffect(
                duration: 6.seconds,
                builder: (context, value, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                const Color(0xFF0F172A),
                                Color.lerp(const Color(0xFF0F172A),
                                    const Color(0xFF1E293B), value)!
                              ]
                            : [
                                const Color(0xFFF3F4F6),
                                Color.lerp(const Color(0xFFE8EAF6),
                                    const Color(0xFFC5CAE9), value)!
                              ],
                      ),
                    ),
                    child: child,
                  );
                },
              )
            ],
            child: Container(),
          ),

          SafeArea(
            child: Consumer<MasteryViewModel>(
              builder: (context, masteryVm, _) {
                if (masteryVm.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                return _buildNeuralDashboard(user, masteryVm, theme);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNeuralDashboard(UserModel? user, MasteryViewModel masteryVm, ThemeData theme) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final highRisk = masteryVm.highRiskTopics;
    
    return RefreshIndicator(
      onRefresh: () async {
        await _loadDashboardData();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 24, vertical: isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildNeuralHeader(user, theme),
            const SizedBox(height: 16),

            if (highRisk.isNotEmpty)
              NeuralAlertBanner(
                title: "DEGRADATION DETECTED",
                description: "${highRisk.first.name} nodes reaching ${(highRisk.first.forgettingRisk * 100).toStringAsFixed(0)}% forgetting threshold.",
                onAction: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SpacedRepetitionScreen())),
                onIgnore: () {},
              ),
            
            const SizedBox(height: 24),
            _buildRetentionHealthCard(masteryVm, theme),
            
            const SizedBox(height: 24),
            _buildSumiProactiveSection(theme),
            
            const SizedBox(height: 24),
            _buildLiveSandboxLink(theme),

            const SizedBox(height: 24),
            _buildNeuralHotspots(masteryVm, theme),

            const SizedBox(height: 24),
            _buildNeuralHistory(user, theme),

            const SizedBox(height: 24),
            _buildDailyMissionSection(theme),

            const SizedBox(height: 24),
            _buildLearningMomentum(user, theme),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildNeuralHeader(UserModel? user, ThemeData theme) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NEURAL HUB',
              style: GoogleFonts.jetBrainsMono(
                color: CyberNeuralColors.cyan,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              user?.displayName?.toUpperCase() ?? 'LEARNER',
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const Spacer(),
        _buildStreakBadge(user, theme),
      ],
    ).animate().fadeIn().slideY(begin: -0.2);
  }

  Widget _buildStreakBadge(UserModel? user, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 20),
          const SizedBox(width: 4),
          Text(
            '${user?.missionCompletionStreak ?? 0}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSumiProactiveSection(ThemeData theme) {
    return Consumer<SumiProvider>(
      builder: (context, sumi, _) {
        return Center(
          child: Column(
            children: [
              SumiMascot(
                state: sumi.currentState,
                size: 100,
                dialogue: sumi.dialogue,
              ).animate(onPlay: (c) => c.repeat(reverse: true))
               .scale(duration: 2.seconds, begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05)),
              const SizedBox(height: 12),
              _buildGlassCard(
                theme: theme,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Text(
                  sumi.dialogue ?? "Ready to strengthen your neural pathways?",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                ),
              ).animate().fadeIn(delay: 400.ms),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRetentionHealthCard(MasteryViewModel masteryVm, ThemeData theme) {
    final score = masteryVm.overallMastery;
    return GestureDetector(
      onTap: () => context.push('/progress'),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: CyberNeuralColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: CyberNeuralColors.cyan.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('NEURAL STATUS HUB', 
                  style: GoogleFonts.jetBrainsMono(
                    fontWeight: FontWeight.bold, 
                    letterSpacing: 1.5,
                    fontSize: 12,
                    color: CyberNeuralColors.textSecondary,
                  )),
                const Icon(Icons.tune_rounded, size: 18, color: CyberNeuralColors.cyan),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${(score * 100).toStringAsFixed(0)}',
                  style: GoogleFonts.outfit(
                    fontSize: 56, 
                    fontWeight: FontWeight.w900, 
                    color: Colors.white,
                    height: 1,
                  )),
                const Padding(
                  padding: EdgeInsets.only(bottom: 8.0, left: 4),
                  child: Text('%', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: CyberNeuralColors.cyan)),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('+4.2% Stability', style: GoogleFonts.jetBrainsMono(color: CyberNeuralColors.cyan, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Container(
                      height: 4,
                      width: 100,
                      decoration: BoxDecoration(
                        color: CyberNeuralColors.cyan.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: score,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: CyberNeuralColors.neuralGradient,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMiniStat("Active Nodes", "1,042"),
                _buildMiniStat("At Risk", "14", isAlert: true),
                _buildMiniStat("Sync Rate", "94%"),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1);
  }

  Widget _buildMiniStat(String label, String value, {bool isAlert = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.jetBrainsMono(fontSize: 10, color: CyberNeuralColors.textSecondary)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: isAlert ? CyberNeuralColors.alert : Colors.white)),
      ],
    );
  }

  Widget _buildNeuralHotspots(MasteryViewModel masteryVm, ThemeData theme) {
    final hotspots = masteryVm.highRiskTopics.take(2).toList();
    if (hotspots.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('NEURAL HOTSPOTS', 
          style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.redAccent)),
        const SizedBox(height: 12),
        ...hotspots.map((topic) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildGlassCard(
            theme: theme,
            borderColor: Colors.redAccent.withValues(alpha: 0.2),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.flash_on_rounded, color: Colors.redAccent),
              ),
              title: Text(topic.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Forgetting Risk: ${(topic.forgettingRisk * 100).toStringAsFixed(0)}%'),
              trailing: IconButton.filledTonal(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SpacedRepetitionScreen())),
                icon: const Icon(Icons.psychology_rounded),
                style: IconButton.styleFrom(foregroundColor: Colors.redAccent),
              ),
            ),
          ),
        )),
      ],
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildDailyMissionSection(ThemeData theme) {
    final isCompleted = _dailyMission?.isCompleted ?? false;
    return _buildMissionCard(isCompleted, theme);
  }

  Widget _buildLearningMomentum(UserModel? user, ThemeData theme) {
    return _buildGlassCard(
      theme: theme,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: Colors.amber),
              const SizedBox(width: 12),
              Text('NEURAL MOMENTUM', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('${user?.currentMomentum?.toStringAsFixed(0) ?? 0} XP', style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (user?.itemsCompletedToday ?? 0) / (user?.dailyGoal ?? 5),
              minHeight: 10,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildLiveSandboxLink(ThemeData theme) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => const SumiLiveSandboxOverlay(),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.secondary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mic_none_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "NEURAL LINK LIVE",
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    "Instant voice tutoring session",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
          ],
        ),
      ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 3.seconds, color: Colors.white24),
    );
  }

  Widget _buildNeuralHistory(UserModel? user, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('NEURAL HISTORY', 
          style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: _buildRecentActivity(user, theme),
        ),
      ],
    ).animate().fadeIn(delay: 350.ms);
  }



  Widget _buildGlassCard(
      {required Widget child,
      EdgeInsets? padding,
      Color? borderColor,
      required ThemeData theme}) {
    final isDark = theme.brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor.withValues(alpha: isDark ? 0.5 : 0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: borderColor ?? theme.dividerColor.withValues(alpha: 0.2),
                width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildPremiumStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required LinearGradient gradient,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.surface,
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: gradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: iconColor.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 12),
          Text(value,
              style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface)),
          const SizedBox(height: 2),
          Text(title,
              style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8))),
          Text(subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildPremiumGoalCard(UserModel? user, ThemeData theme) {
    final current = user?.itemsCompletedToday ?? 0;
    final target = user?.dailyGoal ?? 5;
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    final isDone = current >= target;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.surface,
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDone
              ? Colors.green.withValues(alpha: 0.3)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDone
                        ? [Colors.green, Colors.lightGreen]
                        : [
                            theme.colorScheme.primary,
                            theme.colorScheme.secondary
                          ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: isDone
                          ? Colors.green.withValues(alpha: 0.3)
                          : theme.colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  isDone ? Icons.check_circle : Icons.track_changes,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              if (isDone)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: const Text('COMPLETED',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      )),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('$current/$target',
              style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface)),
          const SizedBox(height: 2),
          Text('Daily Goal',
              style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8))),
          Text(isDone ? 'Goal achieved! 🎉' : 'Keep going!',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: isDone
                      ? Colors.green
                      : theme.colorScheme.onSurface.withValues(alpha: 0.6))),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor:
                  theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
              color: isDone ? Colors.green : theme.colorScheme.primary,
              minHeight: 6,
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildMissionCard(bool isCompleted, ThemeData theme) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    // Handle case where daily mission is null
    if (_dailyMission == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No Mission Available',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Create some study content first to generate your daily mission.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.go('/create-content'),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create Study Content'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ),
          ],
        ),
      ).animate().fadeIn().slideY(begin: 0.1);
    }

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.surface,
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCompleted
              ? Colors.green.withValues(alpha: 0.3)
              : theme.colorScheme.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? Colors.green.withValues(alpha: 0.1)
                      : theme.colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCompleted
                      ? Icons.check_circle_rounded
                      : Icons.rocket_launch_rounded,
                  color: isCompleted ? Colors.green : theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCompleted ? 'Mission Accomplished!' : "Today's Mission",
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (!isCompleted)
                      Text('Boost your momentum now',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6))),
                  ],
                ),
              ),
              if (isCompleted)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: const Text('COMPLETED',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      )),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (!isCompleted) ...[
            // Mission metrics row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMissionMetric(Icons.timelapse,
                    "${_dailyMission!.estimatedTimeMinutes}m", theme),
                _buildMissionMetric(Icons.style,
                    "${_dailyMission!.flashcardIds.length} cards", theme),
                _buildMissionMetric(Icons.speed,
                    "+${_dailyMission!.momentumReward} pts", theme),
              ],
            ),
            const SizedBox(height: 16),
            // Start mission button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: _startMission,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  elevation: 4,
                  shadowColor: theme.colorScheme.primary.withValues(alpha: 0.4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_arrow, color: Colors.white),
                    const SizedBox(width: 12),
                    Text('Start Mission',
                        style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onPrimary)),
                  ],
                ),
              ),
            ),
          ] else ...[
            // Completion message
            Text(
              "You've earned +${_dailyMission!.momentumReward} momentum score today!",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8)),
            ),
            const SizedBox(height: 16),
            // Growth CTA when finished
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Text('Ready for more?',
                      style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary)),
                  const SizedBox(height: 8),
                  Text('Generate a new quiz to strengthen your knowledge.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.7))),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/create'),
                    icon: const Icon(Icons.auto_awesome, size: 20),
                    label: const Text('Create New Content'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1);
  }

  Widget _buildMissionMetric(IconData icon, String label, ThemeData theme) {
    return Column(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF5C6BC0)),
        const SizedBox(height: 4),
        Text(label,
            style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8))),
      ],
    );
  }

  Widget _buildRecentActivity(UserModel? user, ThemeData theme) {
    if (user == null) return const SizedBox();
    final localDb = Provider.of<LocalDatabaseService>(context, listen: false);

    final firestoreService = FirestoreService();

    return StreamBuilder(
      stream: Rx.combineLatest4(
        localDb.watchAllFlashcardSets(user.uid),
        localDb.watchAllQuizzes(user.uid),
        localDb.watchAllSummaries(user.uid),
        firestoreService.streamAllItems(user.uid),
        (sets, quizzes, summaries, fsItems) {
          // Combine local items
          final all = <dynamic>[
            ...sets,
            ...quizzes,
            ...summaries,
          ];

          // Add Firestore items if not already present locally
          final localIds = all.map((e) => e.id as String).toSet();

          final fsSummaries = fsItems['summaries'] ?? [];
          for (var item in fsSummaries) {
            if (!localIds.contains(item.id)) {
              all.add(LocalSummary(
                id: item.id,
                title: item.title,
                content: item.description ?? '', // Fallback description
                timestamp: item.timestamp.toDate(),
                userId: user.uid,
              ));
            }
          }

          final fsQuizzes = fsItems['quizzes'] ?? [];
          for (var item in fsQuizzes) {
            if (!localIds.contains(item.id)) {
              all.add(LocalQuiz(
                id: item.id,
                title: item.title,
                timestamp: item.timestamp.toDate(),
                userId: user.uid,
                questions: [], // Empty questions for preview only
              ));
            }
          }

          final fsFlashcards = fsItems['flashcards'] ?? [];
          for (var item in fsFlashcards) {
            if (!localIds.contains(item.id)) {
              all.add(LocalFlashcardSet(
                id: item.id,
                title: item.title,
                timestamp: item.timestamp.toDate(),
                userId: user.uid,
                flashcards: [], // Empty flashcards for preview only
              ));
            }
          }

          // Safe sort with null checks
          all.sort((a, b) {
            final aTime = (a is LocalSummary)
                ? a.timestamp
                : (a is LocalQuiz
                    ? a.timestamp
                    : (a as LocalFlashcardSet).timestamp);
            final bTime = (b is LocalSummary)
                ? b.timestamp
                : (b is LocalQuiz
                    ? b.timestamp
                    : (b as LocalFlashcardSet).timestamp);
            return bTime.compareTo(aTime);
          });

          return all.take(10).toList();
        },
      ).shareReplay(maxSize: 1),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data as List<dynamic>;

        if (items.isEmpty) {
          return Center(
              child: Text('No recent activity',
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.6))));
        }

        return ListView.builder(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            String title = item.title;
            IconData icon = Icons.article_rounded;
            Color color = Colors.blue;
            String type = 'Summary';

            if (item is LocalFlashcardSet) {
              icon = Icons.style_rounded;
              color = const Color(0xFFEC4899); // Pink
              type = 'Flashcards';
            } else if (item is LocalQuiz) {
              icon = Icons.quiz_rounded;
              color = const Color(0xFFF59E0B); // Orange
              type = 'Quiz';
            } else {
              color = const Color(0xFF0D9488); // Teal (Summary)
            }

            return Container(
              width: 130,
              margin: const EdgeInsets.only(right: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardColor.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: theme.dividerColor.withValues(alpha: 0.5)),
                    ),
                    child: InkWell(
                      onTap: () {
                        if (item is LocalFlashcardSet) {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => FlashcardsScreen(
                                      flashcardSet: FlashcardSet(
                                          id: item.id,
                                          title: item.title,
                                          flashcards: item.flashcards
                                              .map((f) => Flashcard(
                                                  id: f.id,
                                                  question: f.question,
                                                  answer: f.answer))
                                              .toList(),
                                          timestamp: Timestamp.fromDate(
                                              item.timestamp)))));
                        } else if (item is LocalQuiz) {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => QuizScreen(quiz: item)));
                        } else if (item is LocalSummary) {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      SummaryScreen(summary: item)));
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                shape: BoxShape.circle),
                            child: Icon(icon, color: color, size: 24),
                          ),
                          const Spacer(),
                          Text(title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface)),
                          const SizedBox(height: 4),
                          Text(type,
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.6))),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSrsBanner(ThemeData theme) {
    if (_dueCount == 0) {
      if (_nextReviewDate == null) return const SizedBox.shrink();

      // Show "Next Review" info
      final now = DateTime.now();
      final diff = _nextReviewDate!.difference(now);
      String timeText;
      if (diff.inHours > 0) {
        timeText = "in ${diff.inHours}h ${diff.inMinutes % 60}m";
      } else if (diff.inMinutes > 0) {
        timeText = "in ${diff.inMinutes}m";
      } else {
        timeText = "any moment now";
      }

      return _buildGlassCard(
        theme: theme,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle),
              child: Icon(Icons.timer_outlined,
                  color: theme.colorScheme.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('All Caught Up! ✓',
                      style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface)),
                  Text('Next review session $timeText',
                      style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6))),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SpacedRepetitionScreen(),
          ),
        );
        _loadSrsStats(); // Refresh count on return
      },
      child: _buildGlassCard(
        theme: theme,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        borderColor: Colors.amber.withValues(alpha: 0.3),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  shape: BoxShape.circle),
              child: const Icon(Icons.notifications_active_rounded,
                  color: Colors.amber, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$_dueCount Quick Reviews Due',
                      style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface)),
                  Text('Keep your streak alive!',
                      style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6))),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: theme.disabledColor, size: 16),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: -0.2);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Widget _buildBrainState(UserModel? user, ThemeData theme) {
    if (user == null) return const SizedBox.shrink();

    return Consumer<RecommendationService>(
      builder: (context, recService, child) {
        final recs = recService.getDailyRecommendations(user.uid);

        if (recs.isEmpty) return const SizedBox.shrink();

        // Trigger Sumi Alert if we have high-priority recommendations
        if (recs.any((r) => r.priorityScore > 0.6)) {
          final tutor = context.read<SumiTutorService>();
          final greeting = tutor.getProactiveGreeting(
              user.uid, user.displayName ?? 'Student');

          WidgetsBinding.instance.addPostFrameCallback((_) {
            final sumi = context.read<SumiProvider>();
            sumi.showTutorMessage(greeting, state: SumiState.analytical);
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Image.asset('assets/images/sumi.png', width: 24, height: 24),
                  const SizedBox(width: 8),
                  Text("Today's Brain State",
                      style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface)),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Premium Live Sandbox Trigger
            GestureDetector(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const SumiLiveSandboxOverlay(),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.mic_none_rounded,
                          color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Sumi Live Sandbox",
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "Instant voice tutoring from any resource",
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios,
                        color: Colors.white, size: 16),
                  ],
                ),
              )
                  .animate(onPlay: (c) => c.repeat())
                  .shimmer(duration: 3.seconds, color: Colors.white24),
            ),

            const SizedBox(height: 24),
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: recs.length,
                itemBuilder: (context, index) {
                  final rec = recs[index];
                  return Container(
                    width: 260,
                    margin: const EdgeInsets.only(right: 12),
                    child: _buildGlassCard(
                      theme: theme,
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _getRecommendationIcon(rec.type, theme),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  rec.topic.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            rec.description,
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.7)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          SizedBox(
                            width: double.infinity,
                            height: 32,
                            child: ElevatedButton(
                              onPressed: () =>
                                  _handleRecommendationAction(context, rec),
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                backgroundColor:
                                    theme.colorScheme.primary.withValues(alpha: 0.1),
                                foregroundColor: theme.colorScheme.primary,
                                elevation: 0,
                              ),
                              child: Text(rec.actionLabel,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _getRecommendationIcon(RecommendationType type, ThemeData theme) {
    IconData icon;
    Color color;

    switch (type) {
      case RecommendationType.quickRefresh:
        icon = Icons.bolt_rounded;
        color = Colors.amber;
        break;
      case RecommendationType.weaknessDrill:
        icon = Icons.biotech_rounded;
        color = Colors.redAccent;
        break;
      case RecommendationType.deepDive:
        icon = Icons.auto_stories_rounded;
        color = Colors.blueAccent;
        break;
      case RecommendationType.stableMaintenance:
        icon = Icons.verified_user_rounded;
        color = Colors.greenAccent;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 16),
    );
  }

  void _handleRecommendationAction(
      BuildContext context, StudyRecommendation rec) {
    switch (rec.type) {
      case RecommendationType.quickRefresh:
      case RecommendationType.weaknessDrill:
        // Navigate to Quiz/Flashcards for this topic
        // For now, go to the content generation screen to create more or library
        context.push('/library');
        break;
      case RecommendationType.deepDive:
        context.push('/library');
        break;
      case RecommendationType.stableMaintenance:
        context.push('/library');
        break;
    }
  }
}
