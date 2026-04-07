import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/local_database_service.dart';
import 'package:sumquiz/models/local_summary.dart';
import 'package:sumquiz/models/local_quiz.dart';
import 'package:sumquiz/models/local_flashcard_set.dart';
import 'package:sumquiz/services/progress_service.dart';
import 'package:sumquiz/views/widgets/web/web_progress_header.dart';
import 'package:sumquiz/views/widgets/web/web_stats_grid.dart';
import 'package:sumquiz/views/widgets/web/web_xp_card.dart';
import 'package:sumquiz/views/widgets/web/web_consistency_map.dart';

class ProgressScreenWeb extends StatefulWidget {
  const ProgressScreenWeb({super.key});

  @override
  State<ProgressScreenWeb> createState() => _ProgressScreenWebState();
}

class _ProgressScreenWebState extends State<ProgressScreenWeb> {
  int _itemsCreated = 0;
  double _studyTime = 0;
  int _dayStreak = 0;
  int _itemsToday = 0;
  int _dailyGoal = 5;
  int _milestoneProgress = 0;
  int _milestoneGoal = 100;
  String _milestoneTitle = 'Knowledge Master I';
  List<int> _weeklyActivity = List.filled(7, 0);
  bool _isLoading = true;

  final List<String> _tips = [
    'Taking short breaks every 25 minutes helps maintain high levels of focus. Try the Pomodoro technique!',
    'Try teaching what you just learned to someone else - it is the best way to solidify your knowledge.',
    'Reviewing your flashcards right before bed can improve memory retention.',
    'Active recall is more effective than passive reading. Test yourself frequently!',
    'Organizing your study material into folders helps your brain categorize information better.',
    'Consistent 15-minute daily sessions are better than a 3-hour marathon once a week.',
  ];
  late String _currentTip;

  @override
  void initState() {
    super.initState();
    _currentTip = _tips[DateTime.now().second % _tips.length];
    _loadStats();
  }

  Future<void> _loadStats() async {
    final user = context.read<UserModel?>();
    if (user == null) return;

    final db = context.read<LocalDatabaseService>();
    final progressService = ProgressService();

    try {
      final summariesCount = await progressService.getSummariesCount(user.uid);
      final quizzesCount = await progressService.getQuizzesCount(user.uid);
      final flashcardsCount =
          await progressService.getFlashcardsCount(user.uid);
      final totalSeconds = await progressService.getTotalTimeSpent(user.uid);

      final summaries = await db.getAllSummaries(user.uid);
      final quizzes = await db.getAllQuizzes(user.uid);
      final flashcards = await db.getAllFlashcardSets(user.uid);

      final totalCreated = summaries.length +
          summariesCount +
          quizzes.length +
          quizzesCount +
          flashcards.length +
          flashcardsCount;

      // Milestone logic
      final milestones = [
        {'title': 'Knowledge Master I', 'goal': 50},
        {'title': 'Knowledge Master II', 'goal': 100},
        {'title': 'Knowledge Master III', 'goal': 250},
        {'title': 'Knowledge Master IV', 'goal': 500},
        {'title': 'Knowledge Guru', 'goal': 1000},
      ];

      var currentMilestone = milestones[0];
      for (var m in milestones) {
        if (totalCreated < (m['goal'] as int)) {
          currentMilestone = m;
          break;
        }
        currentMilestone = m;
      }

      setState(() {
        _itemsCreated = totalCreated;
        _itemsToday = user.itemsCompletedToday;
        _dailyGoal = user.dailyGoal > 0 ? user.dailyGoal : 5;
        _studyTime = totalSeconds / 3600; // to hours
        _dayStreak = user.missionCompletionStreak;
        _milestoneGoal = currentMilestone['goal'] as int;
        _milestoneTitle = currentMilestone['title'] as String;
        _milestoneProgress = totalCreated;
        _weeklyActivity =
            _calculateWeeklyActivity(summaries, quizzes, flashcards);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<int> _calculateWeeklyActivity(List<LocalSummary> summaries,
      List<LocalQuiz> quizzes, List<LocalFlashcardSet> flashcards) {
    final activity = List.filled(7, 0);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    void processItems(List<dynamic> items) {
      for (var item in items) {
        final itemDate = item.timestamp;
        final date = DateTime(itemDate.year, itemDate.month, itemDate.day);
        final daysDiff = today.difference(date).inDays;
        if (daysDiff >= 0 && daysDiff < 7) {
          activity[6 - daysDiff]++;
        }
      }
    }

    processItems(summaries);
    processItems(quizzes);
    processItems(flashcards);

    return activity;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = Provider.of<UserModel?>(context);

    return Container(
      color: const Color(0xFFF8FAFC),
      child: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: theme.colorScheme.primary))
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            WebProgressHeader(
                              userName: user?.displayName.split(' ').first ?? 'Scholar',
                              weeklyGoalPercentage: 15, // Sample value
                              onDownloadReport: () {},
                            ),
                            const SizedBox(height: 16),
                            WebStatsGrid(
                              dayStreak: _dayStreak,
                              itemsToday: _itemsToday,
                              dailyGoal: _dailyGoal,
                              totalItems: _itemsCreated,
                              studyTimeHours: _studyTime,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 3, child: _buildWeeklyActivity()),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    children: [
                                      WebXPCard(
                                        tierName: _milestoneTitle,
                                        currentXP: (_milestoneProgress * 10).toInt(), // 10 XP per item
                                        nextLevelXP: (_milestoneGoal * 10).toInt(),
                                      ),
                                      const SizedBox(height: 16),
                                      _buildAchievementsGrid(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            WebConsistencyMap(
                              engagementData: List.generate(168, (i) => i % 5), // Sample data
                            ),
                            const SizedBox(height: 16),
                            _buildAICoachTip(),
                            const SizedBox(height: 24),
                            _buildFooter(),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // --- Removed legacy builders ---

  Widget _buildWeeklyActivity() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Weekly Activity',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Items created per day',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Text(
                      'Last 7 Days',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF475569),
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF475569), size: 18),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
          SizedBox(
            height: 300,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (_weeklyActivity.reduce((a, b) => a > b ? a : b) + 2).toDouble(),
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
                        final now = DateTime.now();
                        final date = now.subtract(Duration(days: 6 - value.toInt()));
                        return Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: Text(
                            days[date.weekday - 1],
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(7, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: _weeklyActivity[i].toDouble(),
                        color: i == 6 ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
                        width: 48,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsGrid() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Achievements',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Text(
                'VIEW ALL',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF6366F1),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildAchievementBadge(Icons.auto_awesome_rounded, const Color(0xFFC7D2FE), true),
              _buildAchievementBadge(Icons.speed_rounded, const Color(0xFFC7D2FE), true),
              _buildAchievementBadge(Icons.school_rounded, const Color(0xFFC7D2FE), true),
              _buildAchievementBadge(Icons.lock_rounded, const Color(0xFFF1F5F9), false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementBadge(IconData icon, Color color, bool unlocked) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: unlocked ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8), size: 24),
    );
  }

  Widget _buildAICoachTip() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.lightbulb_rounded, color: Color(0xFF6366F1), size: 24),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI LEARNING COACH',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF6366F1),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _currentTip,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: const Color(0xFF0F172A),
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Removed legacy builders ---

  // --- Removed legacy builders ---

  Widget _buildFooter() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(colors: [
              theme.colorScheme.primary,
              theme.colorScheme.tertiary
            ]).createShader(bounds),
            child: Text(
              'SumQuiz',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '© 2026 SumQuiz Learning Analytics',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Documentation | Privacy | Support',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
