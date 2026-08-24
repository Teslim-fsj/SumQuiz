import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/auth_service.dart';
import '../../../providers/sync_provider.dart';
import '../../../services/local_database_service.dart';
import '../../../services/spaced_repetition_service.dart';
import '../../../models/flashcard.dart';
import '../../../models/flashcard_set.dart';
import '../../../models/user_model.dart';
import '../../../models/daily_mission.dart';
import '../../../services/mission_service.dart';
import '../../../services/mastery/sumi_tutor_service.dart';
import '../../../services/user_service.dart';
import '../../../views/screens/spaced_repetition_screen.dart';
import '../../../view_models/mastery_view_model.dart';
import '../../../views/screens/flashcards_screen.dart';
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
                                child: DailyGoalCard(
                                  goalMinutes: _dailyGoalMinutes,
                                  timeSpentMinutes: _timeSpentMinutes,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Bottom: Curriculums + Right rail
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: ReviewListCard(
                                  dueCount: _dueCount,
                                  dueItems: _dueFlashcardSets,
                                  onReviewAll: () {
                                    context.push('/spaced-repetition');
                                  },
                                  onReviewItem: _startSetReview,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  children: [
                                    InteractivePreviewCard(
                                      question: _previewQuestion,
                                      onClipPressed: () {
                                        Clipboard.setData(ClipboardData(
                                            text: _previewQuestion));
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Question copied to clipboard!'),
                                            backgroundColor: theme
                                                .colorScheme.tertiaryContainer,
                                          ),
                                        );
                                      },
                                      onStartSession: () async {
                                        final localDb =
                                            Provider.of<LocalDatabaseService>(
                                                context,
                                                listen: false);
                                        final authService =
                                            Provider.of<AuthService>(context,
                                                listen: false);
                                        final sets =
                                            await localDb.getAllFlashcardSets(
                                                authService.currentUser?.uid ??
                                                    '');
                                        if (sets.isNotEmpty) {
                                          _startSetReview(sets.first);
                                        } else {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                                    content: Text(
                                                        'No study sets found. Create one first!')));
                                          }
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    FocusTimerCard(),
                                    const SizedBox(height: 12),
                                    StreakCard(
                                        streakDays:
                                            user?.missionCompletionStreak ?? 0),
                                  ],
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

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Widget _buildHeader(UserModel? user) {
    final theme = Theme.of(context);
    final streak = user?.missionCompletionStreak ?? 0;
    final accuracyPct = (_accuracy * 100).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${_getGreeting()}, ${user?.displayName.split(' ').first ?? 'Scholar'}',
              style: GoogleFonts.outfit(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.displayLarge?.color,
              ),
            ),
            const SizedBox(width: 24),
            if (streak > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFFF59E0B).withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department_rounded,
                        color: Color(0xFFF59E0B), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '$streak Day Streak',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(
            style: GoogleFonts.inter(
              fontSize: 16,
              color: theme.hintColor,
            ),
            children: [
              const TextSpan(text: 'Your current precision is '),
              TextSpan(
                text: '$accuracyPct%',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const TextSpan(text: '. Ready for today\'s mastery mission?'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStudySession() {
    final theme = Theme.of(context);
    return Container(
      color: Colors.white,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [theme.colorScheme.surface, Colors.white],
              ),
            ),
          ),
          Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 28),
                      onPressed: () {
                        _stopwatch.stop();
                        _timer?.cancel();
                        setState(() => _isStudying = false);
                      },
                      tooltip: 'Exit Session',
                      style: IconButton.styleFrom(
                        backgroundColor: theme.colorScheme.surface,
                        foregroundColor: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'SESSION PROGRESS',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                  letterSpacing: 1.5,
                                ),
                              ),
                              Text(
                                '${_currentCardIndex + 1} / ${_studyCards.length}',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.secondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: LinearProgressIndicator(
                              value:
                                  (_currentCardIndex + 1) / _studyCards.length,
                              backgroundColor: theme.colorScheme.surface,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  theme.colorScheme.secondary),
                              minHeight: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 40),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: theme.colorScheme.outline
                                .withValues(alpha: 0.1)),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10)
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.timer_outlined,
                              size: 22, color: theme.colorScheme.secondary),
                          const SizedBox(width: 12),
                          Text(
                            _formatDuration(_stopwatch.elapsed),
                            style: GoogleFonts.jetBrainsMono(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Center(
                child: _build3DFlashcard(),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(32),
                child: _isFlipped
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildControlButton(
                              Icons.close,
                              "Forgot",
                              Colors.red[100]!,
                              Colors.red,
                              () => _nextCard(false)),
                          const SizedBox(width: 32),
                          _buildControlButton(
                              Icons.check,
                              "Remembered",
                              Colors.green[100]!,
                              Colors.green,
                              () => _nextCard(true)),
                        ],
                      ).animate().fadeIn(duration: 200.ms)
                    : ElevatedButton.icon(
                        onPressed: () => setState(() => _isFlipped = true),
                        icon: const Icon(Icons.flip),
                        label: const Text('Show Answer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 48, vertical: 24),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _build3DFlashcard() {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => setState(() => _isFlipped = !_isFlipped),
      child: TweenAnimationBuilder(
        tween: Tween<double>(begin: 0, end: _isFlipped ? 180 : 0),
        duration: const Duration(milliseconds: 400),
        builder: (context, double val, child) {
          bool isBack = val >= 90;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(val * pi / 180),
            child: Container(
              width: 640,
              height: 420,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.5)),
                boxShadow: isBack
                    ? [
                        BoxShadow(
                          color: theme.colorScheme.tertiaryContainer
                              .withValues(alpha: 0.1),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                        ),
                      ]
                    : null,
              ),
              child: isBack
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(pi),
                      child: _buildCardContent(
                          _studyCards[_currentCardIndex].answer, true),
                    )
                  : _buildCardContent(
                      _studyCards[_currentCardIndex].question, false),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCardContent(String text, bool isAnswer) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isAnswer
                  ? Colors.green[50]
                  : theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isAnswer ? 'ANSWER' : 'QUESTION',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isAnswer ? Colors.green : theme.colorScheme.primary,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(
      IconData icon, String label, Color bg, Color fg, VoidCallback onTap) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(icon, color: fg, size: 32),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(color: fg, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildSrsBanner(BuildContext context) {
    bool isDue = _dueCount > 0;
    String timeText = "";

    if (!isDue && _nextReviewDate != null) {
      final now = DateTime.now();
      final diff = _nextReviewDate!.difference(now);
      if (diff.inHours > 0) {
        timeText = "in ${diff.inHours}h ${diff.inMinutes % 60}m";
      } else if (diff.inMinutes > 0) {
        timeText = "in ${diff.inMinutes}m";
      } else {
        timeText = "any moment now";
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4C3BCF), Color(0xFF6B5CE7), Color(0xFF7C6FF0)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B5CE7).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child:
                const Icon(Icons.bolt_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDue
                      ? '$_dueCount Items Due for Review'
                      : 'All Caught Up! ✓',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isDue
                      ? 'Keep your streak alive! Consistent reviews improve long-term retention by 300%.'
                      : 'Your next scheduled review is $timeText.',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          OutlinedButton(
            onPressed: () {
              context.push('/spaced-repetition');
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white, width: 1.5),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              isDue ? 'Review\nAll' : 'Browse',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }
}
