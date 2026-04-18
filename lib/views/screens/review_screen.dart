import 'dart:ui';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

import '../../services/auth_service.dart';
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
import 'quiz_screen.dart';
import '../../models/local_summary.dart';
import '../../models/local_quiz.dart';
import '../../models/local_flashcard_set.dart';
import 'package:sumquiz/views/screens/spaced_repetition_screen.dart';
import '../../services/spaced_repetition_service.dart';
import 'package:rxdart/rxdart.dart';
import 'exam_creation_screen.dart';
import '../../services/content_extraction_service.dart';
import '../../utils/cancellation_token.dart';
import '../../utils/youtube_pro_gate.dart';
import '../../services/usage_service.dart';
import '../../services/iap_service.dart';
import '../widgets/extraction_progress_dialog.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/upgrade_dialog.dart';
import '../../services/extraction_result_cache.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../../providers/create_content_provider.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

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

  Future<void> _loadDashboardData() async {
    // Load both mission and SRS stats concurrently
    await Future.wait([
      _loadMission(),
      _loadSrsStats(),
    ]);
  }

  Future<void> _loadSrsStats() async {
    if (!mounted) return;
    final userId =
        Provider.of<AuthService>(context, listen: false).currentUser?.uid;
    if (userId == null) return;

    try {
      final localDb = Provider.of<LocalDatabaseService>(context, listen: false);
      await localDb.init();
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

    final localDb = Provider.of<LocalDatabaseService>(context, listen: false);
    final sets = await localDb.getAllFlashcardSets(userId);

    final allCards = sets.expand((s) => s.flashcards).map((localCard) {
      return Flashcard(
        id: localCard.id,
        question: localCard.question,
        answer: localCard.answer,
      );
    }).toList();

    return allCards.where((c) => cardIds.contains(c.id)).toList();
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Could not find mission cards. They might be deleted.\nPlease create new study content.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
          setState(() => _isLoading = false);
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
            icon: Icon(Icons.settings,
                color: isDark ? Colors.white : const Color(0xFF1A237E)),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      floatingActionButton: SpeedDial(
        icon: Icons.add,
        activeIcon: Icons.close,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        activeBackgroundColor: theme.colorScheme.primaryContainer,
        activeForegroundColor: theme.colorScheme.onPrimaryContainer,
        elevation: 8,
        spacing: 12,
        spaceBetweenChildren: 8,
        tooltip: 'Create New Content',
        children: [
          SpeedDialChild(
            child: const Icon(Icons.school_rounded),
            label: 'Tutor Exam',
            backgroundColor: const Color(0xFF6B5CE7), // purplePrimary
            foregroundColor: Colors.white,
            onTap: () => context.push('/exam-creation'),
          ),
          SpeedDialChild(
            child: const Icon(Icons.picture_as_pdf),
            label: 'Upload Doc',
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            onTap: () => _handleSourceSelection(context, 'pdf', ['pdf', 'doc', 'docx', 'txt']),
          ),
          SpeedDialChild(
            child: const Icon(Icons.link),
            label: 'Web Link',
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            onTap: () => _showUrlInputDialog(context),
          ),
          SpeedDialChild(
            child: const Icon(Icons.play_circle_fill_rounded),
            label: 'YouTube',
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            onTap: () => _showUrlInputDialog(context, isYoutube: true),
          ),
          SpeedDialChild(
            child: const Icon(Icons.camera_alt),
            label: 'Images',
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            onTap: () => _handleSourceSelection(context, 'image', ['jpg', 'jpeg', 'png', 'webp']),
          ),
          SpeedDialChild(
            child: const Icon(Icons.audiotrack),
            label: 'Audio',
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            onTap: () => _handleSourceSelection(context, 'audio', ['mp3', 'wav', 'm4a', 'aac']),
          ),
          SpeedDialChild(
            child: const Icon(Icons.text_fields),
            label: 'Text/Topic',
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            onTap: () => _showTextInputDialog(context),
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Text(_error!, style: theme.textTheme.bodyMedium))
                    : _buildMissionDashboard(user, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionDashboard(UserModel? user, ThemeData theme) {
    // Show helpful message if mission is null instead of blank screen
    if (_dailyMission == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _buildGlassCard(
            theme: theme,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary.withOpacity(0.1),
                        theme.colorScheme.secondary.withOpacity(0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.auto_awesome_rounded,
                      size: 64, color: theme.colorScheme.primary),
                ).animate().scale(duration: 800.ms, curve: Curves.elasticOut),
                const SizedBox(height: 32),
                Text(
                  'Your Learning Journey Awaits',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 16),
                Text(
                  'Transform any content into personalized study materials.\nStart by summarizing a document or article.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 400.ms),
                const SizedBox(height: 40),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.secondary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/create'),
                    icon: const Icon(Icons.auto_awesome, size: 24),
                    label: const Text('Generate My First Mission',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 20),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ).animate().scale(delay: 600.ms),
              ],
            ),
          ),
        ),
      );
    }
    final isCompleted = _dailyMission!.isCompleted;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Premium Welcome Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withOpacity(0.1),
                  theme.colorScheme.secondary.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.secondary,
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child:
                      Icon(Icons.auto_awesome, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back,',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withOpacity(0.7),
                        ),
                      ),
                      Text(
                        user?.displayName ?? 'Learner',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_fire_department,
                          color: Colors.amber[700], size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '${user?.missionCompletionStreak ?? 0} day streak',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.amber[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn().slideX(),

          const SizedBox(height: 24),

          // SRS Banner
          _buildSrsBanner(theme),
          const SizedBox(height: 24),

          // Premium Mastery Overview
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.surface,
                  theme.colorScheme.surfaceContainerHighest
                      .withOpacity(0.3),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                // Circular progress with enhanced styling
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 80,
                      width: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary.withOpacity(0.1),
                            theme.colorScheme.secondary.withOpacity(0.05),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 70,
                      width: 70,
                      child: CircularProgressIndicator(
                        value: _masteryScore / 100,
                        strokeWidth: 8,
                        color: const Color(0xFF0D9488), // secondaryTeal
                        backgroundColor: theme.colorScheme.outlineVariant
                            .withOpacity(0.2),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.auto_awesome_rounded,
                          color: Color(0xFF0D9488), size: 28),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Knowledge Mastery',
                          style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.8))),
                      const SizedBox(height: 8),
                      Text(
                          '${_masteryScore.toStringAsFixed(1)}% Overall Proficiency',
                          style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onSurface)),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _masteryScore / 100,
                        backgroundColor: theme.colorScheme.outlineVariant
                            .withOpacity(0.2),
                        color: const Color(0xFF0D9488),
                        borderRadius: BorderRadius.circular(10),
                        minHeight: 8,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer
                        .withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color:
                            theme.colorScheme.primary.withOpacity(0.2)),
                  ),
                  child: TextButton(
                    onPressed: () => context.push('/progress'),
                    child: const Text('View Insights',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 100.ms).slideX(),

          const SizedBox(height: 24),

          // Premium Stats Row
          Row(
            children: [
              Expanded(
                child: _buildPremiumStatCard(
                  title: 'Learning Momentum',
                  value: (user?.currentMomentum ?? 0).toStringAsFixed(0),
                  subtitle: 'XP Points',
                  icon: Icons.local_fire_department_rounded,
                  iconColor: Colors.orange,
                  gradient: const LinearGradient(
                    colors: [Colors.orange, Colors.deepOrange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  theme: theme,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildPremiumGoalCard(user, theme),
              ),
            ],
          ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.1),

          const SizedBox(height: 24),

          // Mission Card
          _buildMissionCard(isCompleted, theme),

          const SizedBox(height: 32),

          // Recent Activity
          Text('Jump Back In',
              style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withOpacity(0.8))),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: _buildRecentActivity(user, theme),
          ).animate().fadeIn(delay: 400.ms),

          const SizedBox(height: 24),
        ],
      ),
    );
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
                color: borderColor ?? theme.dividerColor.withOpacity(0.2),
                width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.surface,
            theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: gradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: iconColor.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 20),
          Text(value,
              style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface)),
          const SizedBox(height: 4),
          Text(title,
              style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withOpacity(0.8))),
          Text(subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6))),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.surface,
            theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDone
              ? Colors.green.withOpacity(0.3)
              : theme.colorScheme.outlineVariant.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
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
                          ? Colors.green.withOpacity(0.3)
                          : theme.colorScheme.primary.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(
                  isDone ? Icons.check_circle : Icons.track_changes,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              if (isDone)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: Colors.green.withOpacity(0.3)),
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
          Text('$current/$target',
              style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface)),
          const SizedBox(height: 4),
          Text('Daily Goal',
              style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withOpacity(0.8))),
          Text(isDone ? 'Goal achieved! 🎉' : 'Keep going!',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: isDone
                      ? Colors.green
                      : theme.colorScheme.onSurface.withOpacity(0.6))),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor:
                  theme.colorScheme.outlineVariant.withOpacity(0.2),
              color: isDone ? Colors.green : theme.colorScheme.primary,
              minHeight: 10,
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildMissionCard(bool isCompleted, ThemeData theme) {
    // Handle case where daily mission is null
    if (_dailyMission == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withOpacity(0.3),
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
                    color: theme.colorScheme.primary.withOpacity(0.1),
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
                                .withOpacity(0.6)),
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
                onPressed: () => context.push('/create'),
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.surface,
            theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCompleted
              ? Colors.green.withOpacity(0.3)
              : theme.colorScheme.primary.withOpacity(0.3),
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
                      ? Colors.green.withOpacity(0.1)
                      : theme.colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCompleted
                      ? Icons.check_circle_rounded
                      : Icons.rocket_launch_rounded,
                  color: isCompleted ? Colors.green : theme.colorScheme.primary,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCompleted ? 'Mission Accomplished!' : "Today's Mission",
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (!isCompleted)
                      Text('Boost your momentum now',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.6))),
                  ],
                ),
              ),
              if (isCompleted)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: Colors.green.withOpacity(0.3)),
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
            const SizedBox(height: 24),
            // Start mission button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _startMission,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  elevation: 4,
                  shadowColor: theme.colorScheme.primary.withOpacity(0.4),
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
                  color: theme.colorScheme.onSurface.withOpacity(0.8)),
            ),
            const SizedBox(height: 16),
            // Growth CTA when finished
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    theme.colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.2)),
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
                              .withOpacity(0.7))),
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
                color: theme.colorScheme.onSurface.withOpacity(0.8))),
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
                          theme.colorScheme.onSurface.withOpacity(0.6))));
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
              width: 150,
              margin: const EdgeInsets.only(right: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardColor.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: theme.dividerColor.withOpacity(0.5)),
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
                                color: color.withOpacity(0.1),
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
                                      .withOpacity(0.6))),
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
                  color: theme.colorScheme.primary.withOpacity(0.1),
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
                              .withOpacity(0.6))),
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
        borderColor: Colors.amber.withOpacity(0.3),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
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
                              .withOpacity(0.6))),
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

  Future<void> _checkAccess(
      {required VoidCallback action,
      required String actionType}) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user == null) {
      showError('User not logged in.');
      return;
    }

  void showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // --- NEW SOURCE SELECTION LOGIC (Matching CreateContentScreen) ---

  Future<void> handleSourceSelection(BuildContext context, String type, List<String> extensions) async {
    final user = Provider.of<UserModel?>(context, listen: false);
    if (user != null && !user.isPro && type != 'pdf') {
       showDialog(context: context, builder: (_) => UpgradeDialog(featureName: '$type Uploads'));
       return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: extensions,
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final file = result.files.single;
        final provider = Provider.of<CreateContentProvider>(context, listen: false);
        
        provider.setSource(
          type,
          fileName: file.name,
          bytes: file.bytes,
          mime: getMimeType(file.name),
        );
        
        if (mounted) {
          context.go('/create-content');
        }
      }
    } catch (e) {
      showError('Error selecting file: $e');
    }
  }

  void showTextInputDialog(BuildContext context) {
    final textController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 24,
          left: 24,
          right: 24,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter Topic or Notes',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: textController,
              maxLines: 8,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Type your topic here (e.g. Photosynthesis) or paste your long notes...',
                hintStyle: GoogleFonts.outfit(color: Colors.grey),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final text = textController.text.trim();
                if (text.isNotEmpty) {
                  final provider = Provider.of<CreateContentProvider>(context, listen: false);
                  Navigator.pop(context);
                  final isTopic = text.split(' ').length <= 8;
                  provider.setSource(isTopic ? 'topic' : 'text', text: text);
                  context.go('/create-content');
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Next'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void showUrlInputDialog(BuildContext context, {bool isYoutube = false}) {
    final textController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 24,
          left: 24,
          right: 24,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isYoutube ? 'Enter YouTube Link' : 'Enter Web Link',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: textController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: isYoutube ? 'https://youtube.com/watch?v=...' : 'https://example.com/article',
                hintStyle: GoogleFonts.outfit(color: Colors.grey),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(isYoutube ? Icons.play_circle_outline_rounded : Icons.link_rounded),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final url = textController.text.trim();
                if (url.isNotEmpty && url.startsWith('http')) {
                  final u = Provider.of<UserModel?>(context, listen: false);
                  final lower = url.toLowerCase();
                  final looksYt = lower.contains('youtube.com/') ||
                      lower.contains('youtu.be/') ||
                      lower.contains('m.youtube.com/');
                  if (looksYt && !userMayImportFromYouTube(u)) {
                    showDialog<void>(
                      context: context,
                      builder: (_) =>
                          const UpgradeDialog(featureName: 'YouTube import'),
                    );
                    return;
                  }
                  
                  final provider = Provider.of<CreateContentProvider>(context, listen: false);
                  Navigator.pop(context);
                  provider.setSource('link', text: url);
                  context.go('/create-content');
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Next'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String getMimeType(String name) {
    final ext = name.split('.').last.toLowerCase();
    const map = {
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'txt': 'text/plain',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'mp3': 'audio/mpeg',
      'wav': 'audio/wav',
      'm4a': 'audio/mp4',
    };
    return map[ext] ?? 'application/octet-stream';
  }
}
