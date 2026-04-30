import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/web_theme.dart';
import '../../../services/auth_service.dart';
import '../../../services/local_database_service.dart';
import '../../../services/spaced_repetition_service.dart';
import '../../../services/progress_service.dart';
import '../../../services/firestore_service.dart';
import '../../../models/flashcard.dart';
import '../../../models/local_flashcard.dart';
import '../../../models/local_flashcard_set.dart';
import '../../../models/user_model.dart';
import '../../../models/daily_mission.dart';
import '../../../services/mission_service.dart';
import '../../../services/user_service.dart';
import '../../widgets/web/active_mission_card.dart';
import '../../widgets/web/streak_card.dart';
import '../../widgets/web/accuracy_card.dart';
import '../../widgets/web/review_list_card.dart';
import '../../widgets/web/focus_timer_card.dart';
import '../../widgets/web/daily_goal_card.dart';
import '../../widgets/web/interactive_preview_card.dart';
import '../../widgets/web/role_selection_dialog.dart';

class ReviewScreenWeb extends StatefulWidget {
  final bool autoStartMission;
  const ReviewScreenWeb({super.key, this.autoStartMission = false});

  @override
  State<ReviewScreenWeb> createState() => _ReviewScreenWebState();
}

class _ReviewScreenWebState extends State<ReviewScreenWeb> {
  DailyMission? _dailyMission;
  bool _isLoading = true;
  String? _error;
  DateTime? _nextReviewDate;
  int _dueCount = 0;
  double _accuracy = 0.0;
  int _dailyGoalMinutes = 60;
  int _timeSpentMinutes = 0;
  String _previewQuestion = "What is the 'event loop' in JavaScript?";

  // Study Session State
  bool _isStudying = false;
  List<Flashcard> _studyCards = [];
  int _currentCardIndex = 0;
  bool _isFlipped = false;
  int _correctCount = 0;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;

  List<LocalFlashcardSet> _dueFlashcardSets = []; // Updated type
  late SpacedRepetitionService _srsService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNewUser();
      
      // Auto-start mission if requested via deep link
      if (widget.autoStartMission) {
        _fetchAndStartMission();
      }
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
  void dispose() {
    _timer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.uid;

    if (userId == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = "User not found.";
        });
      }
      return;
    }

    final missionService = Provider.of<MissionService>(context, listen: false);
    final localDb = Provider.of<LocalDatabaseService>(context, listen: false);
    final firestoreService =
        Provider.of<FirestoreService>(context, listen: false);

    try {
      final mission = await missionService.generateDailyMission(userId);

      await localDb.init();
      _srsService =
          SpacedRepetitionService(localDb.getSpacedRepetitionBox());
      final stats = await _srsService.getStatistics(userId);
      final nextDate = _srsService.getNextReviewDate(userId);

      final progressService = ProgressService();
      // Use recent accuracy for last 7 days
      final avgAccuracy = await progressService.getRecentAccuracyStats(userId);
      // Get time spent TODAY only
      final totalTimeSpentSeconds =
          await progressService.getTimeSpentToday(userId);

      // Fetch flashcard sets with Firestore fallback
      List<LocalFlashcardSet> allSets =
          await localDb.getAllFlashcardSets(userId);
      if (allSets.isEmpty) {
        final fsSets = await firestoreService.streamFlashcardSets(userId).first;
        if (fsSets.isNotEmpty) {
          allSets = fsSets
              .map((s) => LocalFlashcardSet(
                    id: s.id,
                    title: s.title,
                    timestamp: s.timestamp.toDate(),
                    userId: userId,
                    flashcards: s.flashcards
                        .map((f) => LocalFlashcard(
                              question: f.question,
                              answer: f.answer,
                            ))
                        .toList(),
                  ))
              .toList();
        }
      }

      if (!mounted) return;

      final dueIds = await _srsService.getDueItems(userId);
      _dueFlashcardSets = allSets.where((s) => s.flashcards.any((f) => dueIds.contains(f.id))).toList();

      // If none are due but we have sets, show some anyway to avoid empty state
      if (_dueFlashcardSets.isEmpty && allSets.isNotEmpty) {
        _dueFlashcardSets = allSets.take(3).toList();
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      int dailyGoal = 60;
      int timeSpentToday = 0;
      String lastQuestion = "What is the 'event loop' in JavaScript?";

      if (userDoc.exists) {
        final userData = userDoc.data();
        dailyGoal = userData?['dailyGoal'] as int? ?? 60;
      }

      // Convert seconds to minutes for display
      timeSpentToday = (totalTimeSpentSeconds / 60).round();

      if (allSets.isNotEmpty && allSets.first.flashcards.isNotEmpty) {
        lastQuestion = allSets.first.flashcards.first.question;
      }

      if (mounted) {
        setState(() {
          _dailyMission = mission;
          _dueCount = stats['dueForReviewCount'] as int? ?? 0;
          _nextReviewDate = nextDate;
          // Extract average from the stats map
          _accuracy = avgAccuracy['average'] ?? 0.0;
          _dailyGoalMinutes = dailyGoal;
          _timeSpentMinutes = timeSpentToday;
          _previewQuestion = lastQuestion;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = "Error loading dashboard: $e";
        });
      }
    }
  }

  Future<void> _fetchAndStartMission() async {
    if (_dailyMission == null) return;

    if (_dailyMission!.isCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text("You've already completed today's mission! Great job!")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.uid;
      final localDb = Provider.of<LocalDatabaseService>(context, listen: false);

      if (userId == null) throw Exception("User ID null");

      final missionService = Provider.of<MissionService>(context, listen: false);
      final cards = await missionService.fetchMissionCards(userId, _dailyMission!.flashcardIds);

      if (cards.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Could not find mission cards. Using random cards instead.')));
          
          final allSets = await localDb.getAllFlashcardSets(userId);
          final allFlashcards = allSets.expand((s) => s.flashcards).map((c) => Flashcard(
            id: c.id,
            question: c.question,
            answer: c.answer,
          )).toList();
          
          _studyCards = allFlashcards.take(5).toList();
        }
      } else {
        _studyCards = cards;
      }

      if (_studyCards.isEmpty) {
        throw Exception("No flashcards found to study.");
      }

      _startStudySession();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to start mission: $e")));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _startSetReview(LocalFlashcardSet set) async {
    setState(() => _isLoading = true);
    try {
      _studyCards = set.flashcards
          .map((c) => Flashcard(
                id: c.id,
                question: c.question,
                answer: c.answer,
              ))
          .toList();
      _startStudySession();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to load set: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  void _startStudySession() {
    setState(() {
      _isStudying = true;
      _isLoading = false;
      _currentCardIndex = 0;
      _isFlipped = false;
      _correctCount = 0;
    });
    _stopwatch.reset();
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
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

      // Update completion stats
      double accuracy =
          _studyCards.isEmpty ? 0 : _correctCount / _studyCards.length;

      // Wrap in try-catch to ensure we return to dashboard even if analytics fail
      try {
        if (_dailyMission != null && !_dailyMission!.isCompleted) {
          await missionService.completeMission(
              userId, _dailyMission!, accuracy);
        }
        await userService.incrementItemsCompleted(userId);

        // Save progress details with proper logging
        final progressService = ProgressService();
        await progressService.logAccuracy(userId, accuracy);

        // Log the complete study session for cross-platform tracking
        await progressService.logStudySession(
          userId: userId,
          accuracy: accuracy,
          durationSeconds: _stopwatch.elapsed.inSeconds,
        );
      } catch (e) {
        debugPrint('Analytics error: $e');
      }

      await _loadDashboardData();
    }

    setState(() {
      _isStudying = false;
    });

    _showCompletionDialog();
  }

  void _showCompletionDialog() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Session Complete!',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/web/success_illustration.png',
                height: 120),
            const SizedBox(height: 16),
            Text('You got $_correctCount out of ${_studyCards.length} correct!',
                style: GoogleFonts.outfit(
                    fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Time: ${_formatDuration(_stopwatch.elapsed)}',
                style: GoogleFonts.outfit(
                    color: theme.colorScheme.onSurface.withOpacity(0.7))),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Great!'),
          ),
        ],
      ),
    );
  }

  void _showMissionDetails(BuildContext context) {
    if (_dailyMission == null) return;
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Daily Mission',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.surface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              _dailyMission!.title,
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Complete the curated quiz sets for today to earn extra XP and maintain your streak.',
              style: GoogleFonts.outfit(
                fontSize: 16,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _fetchAndStartMission();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _dailyMission?.isCompleted == true
                      ? 'Mission Completed'
                      : 'Start Mission',
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _nextCard(bool known) {
    if (known) _correctCount++;

    // Update SRS progress for the individual card
    final currentCard = _studyCards[_currentCardIndex];
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.uid;
    if (userId != null) {
      _srsService.updateReview(currentCard.id, known);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = Provider.of<UserModel?>(context);

    if (_isStudying) {
      return _buildStudySession();
    }

    return Container(
      color: theme.colorScheme.surface,
      child: _isLoading
          ? Center(
              child:
                  CircularProgressIndicator(color: theme.colorScheme.primary))
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: TextStyle(
                          color: theme.colorScheme.onSurface, fontSize: 18)))
              : SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1280),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(user),
                          const SizedBox(height: 12),
                          _buildSrsBanner(context),
                          const SizedBox(height: 12),
                          // Three stat cards in a row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ActiveMissionCard(
                                  mission: _dailyMission,
                                  onStart: _fetchAndStartMission,
                                  onDetails: () {
                                    _showMissionDetails(context);
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: AccuracyCard(
                                  accuracy: _accuracy,
                                  highestAccuracy: _accuracy,
                                  lowestAccuracy: _accuracy,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
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
                                            backgroundColor: theme.colorScheme
                                                .tertiaryContainer,
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
                                            user?.missionCompletionStreak ??
                                                0),
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
    final streak = user?.missionCompletionStreak ?? 0;
    final accuracyPct = (_accuracy * 100).toInt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${_getGreeting()}, ${user?.displayName.split(' ').first ?? 'Scholar'}!',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: WebColors.textPrimary,
              ),
            ),
            const SizedBox(width: 16),
            if (streak > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: WebColors.purpleUltraLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: WebColors.purplePrimary.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department_rounded,
                        color: WebColors.purplePrimary, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      '$streak-Day Streak',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: WebColors.purplePrimary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: WebColors.textSecondary,
            ),
            children: [
              const TextSpan(
                  text: 'Ready to master your knowledge today? You\'re performing at '),
              TextSpan(
                text: '$accuracyPct%',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  color: WebColors.textPrimary,
                  decoration: TextDecoration.underline,
                ),
              ),
              const TextSpan(text: ' accuracy this week.'),
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
                                      .withOpacity(0.5),
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
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: theme.colorScheme.outline
                                .withOpacity(0.1)),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.05),
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
                    color: theme.colorScheme.outline.withOpacity(0.5)),
                boxShadow: isBack
                    ? [
                        BoxShadow(
                          color: theme.colorScheme.tertiaryContainer
                              .withOpacity(0.1),
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
            color: const Color(0xFF6B5CE7).withOpacity(0.3),
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
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 28),
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
                    color: Colors.white.withOpacity(0.85),
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
