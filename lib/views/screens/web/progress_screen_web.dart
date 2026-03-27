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
import 'package:sumquiz/theme/web_theme.dart';
import 'package:go_router/go_router.dart';

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
    final user = Provider.of<UserModel?>(context);

    return Scaffold(
      backgroundColor: WebColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: WebColors.primary))
          : Row(
              children: [
                _buildSidebar(context),
                Expanded(
                  child: Column(
                    children: [
                      _buildModernHeader(user),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1100),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildTopHeader(user),
                                  const SizedBox(height: 32),
                                  _buildStatsRow(),
                                  const SizedBox(height: 32),
                                  _buildMainContent(),
                                  const SizedBox(height: 32),
                                  _buildAchievementsSection(),
                                  const SizedBox(height: 40),
                                  _buildFooter(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: WebColors.surface,
        border: const Border(right: BorderSide(color: WebColors.border)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: WebColors.HeroGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  'SUMQUIZ',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    color: WebColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildSidebarItem(Icons.dashboard_rounded, 'Overview', false, onTap: () => context.go('/review')),
          _buildSidebarItem(Icons.library_books_rounded, 'Library', false, onTap: () => context.go('/library')),
          _buildSidebarItem(Icons.analytics_rounded, 'Progress', true),
          _buildSidebarItem(Icons.settings_rounded, 'Settings', false),
          const Spacer(),
          _buildSidebarItem(Icons.logout_rounded, 'Sign Out', false),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String label, bool isActive, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? WebColors.primary.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isActive ? WebColors.primary : WebColors.textSecondary,
                size: 22,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? WebColors.primary : WebColors.textSecondary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernHeader(UserModel? user) {
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        border: const Border(bottom: BorderSide(color: WebColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Progress & Analytics',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: WebColors.textPrimary,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded),
                onPressed: () {},
                style: IconButton.styleFrom(
                  backgroundColor: WebColors.backgroundAlt,
                  padding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: WebColors.AccentGradient,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: WebColors.subtleShadow,
                ),
                child: const Icon(Icons.person_rounded, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader(UserModel? user) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Keep it up, ${user?.displayName.split(' ').first ?? 'Student'}! 👏',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: WebColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You\'re on track to hit your weekly learning goals.',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: WebColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: WebColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: WebColors.border),
                boxShadow: WebColors.cardShadow,
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 16, color: WebColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    'Last 7 Days',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            InkWell(
              onTap: () => context.go('/library'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: WebColors.HeroGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: WebColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  'Start New Quiz',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _buildStreakCard()),
        const SizedBox(width: 24),
        Expanded(child: _buildGoalCompletionCard()),
      ],
    );
  }

  Widget _buildStreakCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: WebColors.glassDecoration(
        blur: 15,
        opacity: 0.05,
        color: WebColors.surface,
        borderRadius: 24,
      ).copyWith(
        boxShadow: WebColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF08A).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.local_fire_department,
                    color: Color(0xFFEAB308), size: 24),
              ),
              const Spacer(),
              Row(
                children: List.generate(
                  4,
                  (index) => Container(
                    margin: const EdgeInsets.only(left: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: index < 3
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).dividerColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '$_dayStreak',
            style: GoogleFonts.outfit(
              fontSize: 48,
              fontWeight: FontWeight.w800,
              color: WebColors.textPrimary,
              letterSpacing: -2,
            ),
          ),
          Text(
            'DAY STREAK',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFEAB308),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'You\'re in the top 5% of learners this week! Keep the flame alive.',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: WebColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCompletionCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: WebColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: WebColors.border),
        boxShadow: WebColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withAlpha(26),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'ITEMS COMPLETED TODAY',
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Daily Goal Completion',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: WebColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '${(_itemsToday / _dailyGoal * 100).round()}% Complete',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: WebColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$_itemsToday/$_dailyGoal',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: WebColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (_itemsToday / _dailyGoal).clamp(0.0, 1.0),
              backgroundColor: WebColors.border,
              color: WebColors.primary,
              minHeight: 12,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildMetricBox(
                  'Total Created', '$_itemsCreated', Icons.edit, Colors.blue),
              const SizedBox(width: 16),
              _buildMetricBox(
                  'Study Time',
                  '${_studyTime.toStringAsFixed(1)}hrs',
                  Icons.access_time,
                  Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricBox(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withAlpha(26),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(51)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: WebColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 2, child: _buildWeeklyActivity()),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            children: [
              _buildMilestoneCard(),
              const SizedBox(height: 24),
              _buildQuickTipCard(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyActivity() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: WebColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: WebColors.border),
        boxShadow: WebColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly Activity',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: WebColors.textPrimary,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (_weeklyActivity.reduce((a, b) => a > b ? a : b) + 1)
                    .toDouble(),
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const days = [
                          'Mon',
                          'Tue',
                          'Wed',
                          'Thu',
                          'Fri',
                          'Sat',
                          'Sun'
                        ];
                        final now = DateTime.now();
                        final date =
                            now.subtract(Duration(days: 6 - value.toInt()));
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            days[date.weekday - 1],
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: value.toInt() == 6
                                  ? WebColors.primary
                                  : WebColors.textTertiary,
                              fontWeight: value.toInt() == 6
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(7, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: _weeklyActivity[i].toDouble(),
                        color: i == 6
                            ? WebColors.primary
                            : WebColors.primary.withValues(alpha: 0.2),
                        width: 16,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6)),
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

  Widget _buildMilestoneCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: WebColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: WebColors.border),
        boxShadow: WebColors.cardShadow,
      ),
      child: Stack(
        children: [
          Positioned(
            right: 10,
            top: 10,
            child: Opacity(
              opacity: 0.1,
              child: Transform.rotate(
                angle: 0.3,
                child: const Icon(Icons.emoji_events,
                    size: 80, color: WebColors.primary),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.emoji_events_outlined,
                      color: WebColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'NEXT MILESTONE',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: WebColors.primary,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                _milestoneTitle,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: WebColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _milestoneProgress >= _milestoneGoal
                    ? 'Congratulations! You reached this milestone. Keep going for the next one.'
                    : 'Complete ${(_milestoneGoal - _milestoneProgress).toInt()} more items to unlock this badge.',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: WebColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (_milestoneProgress / _milestoneGoal).clamp(0.0, 1.0),
                  backgroundColor: WebColors.border,
                  color: WebColors.primary,
                  minHeight: 10,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$_milestoneProgress/$_milestoneGoal Items',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: WebColors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTipCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline,
                  color: Color(0xFFD97706), size: 20),
              const SizedBox(width: 8),
              Text(
                'Quick Tip',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFD97706),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _currentTip,
            style: GoogleFonts.outfit(
              fontSize: 15,
              color: const Color(0xFF92400E),
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Achievements',
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: WebColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 20),
        _buildRecentAchievements(),
      ],
    );
  }

  Widget _buildRecentAchievements() {
    final user = Provider.of<UserModel?>(context);
    final totalItems = user?.totalDecksGenerated ?? 0;
    final streak = user?.missionCompletionStreak ?? 0;

    return Row(
      children: [
        _buildAchievementCard(
          totalItems >= 50 ? 'Knowledge Master' : 'Scholar in Training',
          '$totalItems items curated',
          Icons.school,
          totalItems >= 50 ? Colors.amber : Colors.blueGrey,
        ),
        const SizedBox(width: 16),
        _buildAchievementCard(
          _studyTime >= 10 ? 'Deep Learner' : 'Consistent Learner',
          '${_studyTime.toStringAsFixed(1)} hours study',
          Icons.timer_outlined,
          _studyTime >= 10 ? Colors.orange : Colors.blue,
        ),
        const SizedBox(width: 16),
        _buildAchievementCard(
          streak >= 7 ? 'Legendary Streak' : 'Rising Star',
          '$streak day streak',
          Icons.bolt,
          streak >= 7 ? Colors.purple : Colors.teal,
        ),
      ],
    );
  }

  Widget _buildAchievementCard(
      String title, String subtitle, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: WebColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: WebColors.border),
          boxShadow: WebColors.cardShadow,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: WebColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: WebColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => WebColors.HeroGradient.createShader(bounds),
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
              color: WebColors.textTertiary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Documentation | Privacy | Support',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: WebColors.textTertiary,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
