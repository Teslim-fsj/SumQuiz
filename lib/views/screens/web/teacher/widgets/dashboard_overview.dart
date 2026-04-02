import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sumquiz/models/public_deck.dart';
import 'package:sumquiz/models/teacher_models.dart';
import 'package:sumquiz/theme/web_theme.dart';
import 'shared_teacher_widgets.dart';

class DashboardOverview extends StatelessWidget {
  final TeacherStats? stats;
  final List<ActivityItem> activity;
  final List<PublicDeck> content;
  final Map<String, ContentAnalytics> analytics;

  const DashboardOverview({
    super.key,
    required this.stats,
    required this.activity,
    required this.content,
    required this.analytics,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SharedTeacherWidgets.moduleHeader(
            'Dashboard',
            'Live overview of your teaching activity',
          ),
          const SizedBox(height: 32),
          _buildStatsRow(),
          const SizedBox(height: 40),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _buildActivityFeed()),
              const SizedBox(width: 24),
              Expanded(flex: 2, child: _buildQuickInsights()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final s = stats;
    return Row(
      children: [
        _statCard('Exams Created', '${s?.totalExams ?? 0}',
            Icons.assignment_outlined, WebColors.purplePrimary, 0),
        const SizedBox(width: 16),
        _statCard('Study Packs', '${s?.totalStudyPacks ?? 0}',
            Icons.library_books_outlined, WebColors.secondary, 1),
        const SizedBox(width: 16),
        _statCard('Total Students', '${s?.totalStudents ?? 0}',
            Icons.people_outline, WebColors.blueInfo, 2),
        const SizedBox(width: 16),
        _statCard('Active (7d)', '${s?.activeStudents ?? 0}',
            Icons.bolt_rounded, WebColors.success, 3),
        const SizedBox(width: 16),
        _statCard('Avg Score', '${s?.averageScore.toStringAsFixed(0) ?? 0}%',
            Icons.star_outline_rounded, WebColors.accentOrange, 4),
        const SizedBox(width: 16),
        _statCard('Total Attempts', '${s?.totalAttempts ?? 0}',
            Icons.timeline_rounded, WebColors.error, 5),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color, int index) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: WebColors.glassDecoration(
          blur: 15,
          opacity: 0.1,
          color: WebColors.surface,
          borderRadius: 16,
        ).copyWith(
          boxShadow: WebColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(value,
                style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: WebColors.textPrimary)),
            Text(label,
                style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: WebColors.textTertiary)),
          ],
        ),
      ).animate().fadeIn(delay: (100 * index).ms).slideY(begin: 0.1, curve: Curves.easeOutQuad),
    );
  }

  Widget _buildActivityFeed() {
    return SharedTeacherWidgets.sectionCard(
      title: 'Recent Activity',
      icon: Icons.rss_feed_rounded,
      child: Column(
        children: activity.isEmpty
            ? [
                SharedTeacherWidgets.emptyHint(
                    'No activity yet. Share your content with students!'),
              ]
            : activity.map((item) => _activityTile(item)).toList(),
      ),
    );
  }

  Widget _activityTile(ActivityItem item) {
    final iconData = item.type == 'attempt'
        ? Icons.play_circle_outline_rounded
        : item.type == 'creation'
            ? Icons.add_circle_outline_rounded
            : Icons.warning_amber_rounded;
    final color = item.type == 'attempt'
        ? WebColors.blueInfo
        : item.type == 'creation'
            ? WebColors.success
            : WebColors.accentOrange;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(iconData, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: WebColors.textPrimary)),
                Text(
                  '${item.subtitle} • ${SharedTeacherWidgets.relativeTime(item.timestamp)}',
                  style: GoogleFonts.outfit(
                      fontSize: 11, color: WebColors.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickInsights() {
    final lowEngagement = content
        .where((c) =>
            (analytics[c.id]?.engagementRate ?? 0) < 30 &&
            analytics.containsKey(c.id))
        .take(3)
        .toList();
    final topContent = content
        .where((c) =>
            (analytics[c.id]?.averageScore ?? 0) > 70 &&
            analytics.containsKey(c.id))
        .take(3)
        .toList();

    return Column(
      children: [
        SharedTeacherWidgets.sectionCard(
          title: 'Top Content',
          icon: Icons.emoji_events_outlined,
          child: topContent.isEmpty
              ? SharedTeacherWidgets.emptyHint(
                  'No analytics yet. Generate activity to see top performers.')
              : Column(
                  children: topContent.map((d) {
                    final a = analytics[d.id]!;
                    return _insightRow(d.title,
                        '${a.averageScore.toStringAsFixed(0)}% avg', Colors.green);
                  }).toList(),
                ),
        ),
        const SizedBox(height: 16),
        SharedTeacherWidgets.sectionCard(
          title: 'Needs Attention',
          icon: Icons.report_problem_outlined,
          child: lowEngagement.isEmpty
              ? SharedTeacherWidgets.emptyHint('All content is performing well.')
              : Column(
                  children: lowEngagement.map((d) {
                    return _insightRow(
                        d.title, 'Low engagement', WebColors.accentOrange);
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _insightRow(String title, String tag, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: WebColors.textPrimary),
                overflow: TextOverflow.ellipsis),
          ),
          SharedTeacherWidgets.badge(tag, color),
        ],
      ),
    );
  }
}
