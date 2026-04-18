import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:sumquiz/models/public_deck.dart';
import 'package:sumquiz/models/teacher_models.dart';
import 'package:sumquiz/theme/web_theme.dart';
import 'shared_teacher_widgets.dart';

class AnalyticsView extends StatelessWidget {
  final List<PublicDeck> content;
  final List<StudentLink> students;
  final Map<String, int> trends;
  final Map<String, ContentAnalytics> analytics;
  final String? selectedStudentId;

  const AnalyticsView({
    super.key,
    required this.content,
    required this.students,
    required this.trends,
    required this.analytics,
    this.selectedStudentId,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;
        
        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SharedTeacherWidgets.moduleHeader('AI Performance Analytics',
                  'Synthesized failure patterns and targeted interventions', isMobile: isMobile),
              const SizedBox(height: 24),
              if (content.isEmpty)
                SharedTeacherWidgets.emptyCard('No content to analyze',
                    'Create and share content to generate analytics data.')
              else ...[
                if (selectedStudentId != null)
                   _buildStudentContextBanner(context, isMobile: isMobile),
                const SizedBox(height: 16),
                _buildClassOverview(isMobile: isMobile),
                const SizedBox(height: 24),
                _buildTrendSection(isMobile: isMobile),
                const SizedBox(height: 32),
                _buildContentAnalyticsList(isMobile: isMobile),
              ],
            ],
          ),
        );
      }
    );
  }

  Widget _buildStudentContextBanner(BuildContext context, {bool isMobile = false}) {
    final student = students.firstWhere((s) => s.studentId == selectedStudentId, 
        orElse: () => StudentLink(
            studentId: '', 
            studentName: 'Unknown', 
            studentEmail: '',
            contentId: '',
            contentTitle: '',
            averageScore: 0, 
            joinedAt: DateTime.now(),
            totalAttempts: 0
        ));
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: WebColors.purplePrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WebColors.purplePrimary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_search_rounded, color: WebColors.purplePrimary, size: 20),
          const SizedBox(width: 12),
          Text(
            'Showing analytics for: ',
            style: GoogleFonts.outfit(fontSize: 14, color: WebColors.textSecondary),
          ),
          Text(
            student.studentName,
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: WebColors.purplePrimary),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => context.go('/progress'),
            child: const Text('Clear Filter', style: TextStyle(fontSize: 12)),
          )
        ],
      ),
    );
  }

  Widget _buildTrendSection({bool isMobile = false}) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: WebColors.border),
        boxShadow: WebColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Activity Trends',
              style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: WebColors.textPrimary)),
          Text('Total student attempts over the last 30 days',
              style: GoogleFonts.outfit(
                  fontSize: 13, color: WebColors.textTertiary)),
          const SizedBox(height: 24),
          SizedBox(
            height: isMobile ? 150 : 200,
            width: double.infinity,
            child: _TrendChart(data: trends),
          ),
        ],
      ),
    );
  }

  Widget _buildClassOverview({bool isMobile = false}) {
    final filteredStudents = selectedStudentId != null 
        ? students.where((s) => s.studentId == selectedStudentId).toList()
        : students;

    final sorted = List<StudentLink>.from(filteredStudents)
      ..sort((a, b) => b.averageScore.compareTo(a.averageScore));
      
    final topStudents = sorted.take(3).toList();
    final weakStudents = sorted.where((s) => s.averageScore < 50).toList();

    final topPerformers = SharedTeacherWidgets.sectionCard(
      title: 'Top Performers',
      icon: Icons.emoji_events_outlined,
      child: Column(
        children: topStudents.isEmpty
            ? [SharedTeacherWidgets.emptyHint('No student data yet')]
            : topStudents.asMap().entries.map((e) {
                return _rankRow(e.key + 1, e.value);
              }).toList(),
      ),
    );

    final needsSupport = SharedTeacherWidgets.sectionCard(
      title: 'Needs Support',
      icon: Icons.support_outlined,
      child: Column(
        children: weakStudents.isEmpty
            ? [SharedTeacherWidgets.emptyHint('No low scores tracked')]
            : weakStudents.map((s) => _rankRow(0, s, showWarning: true)).toList(),
      ),
    );

    if (isMobile) {
      return Column(
        children: [
          topPerformers,
          const SizedBox(height: 16),
          needsSupport,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: topPerformers),
        const SizedBox(width: 24),
        Expanded(child: needsSupport),
      ],
    );
  }

  Widget _rankRow(int rank, StudentLink s, {bool showWarning = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (rank > 0)
            SizedBox(
              width: 24,
              child: Text('#$rank',
                  style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: rank == 1 ? WebColors.accentOrange : WebColors.textTertiary)),
            )
          else
            const SizedBox(width: 24, child: Icon(Icons.warning_amber_rounded, size: 14, color: WebColors.error)),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 14,
            backgroundColor: WebColors.backgroundAlt,
            child: Text(
              s.studentName.isNotEmpty ? s.studentName[0] : '?',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(s.studentName,
                style: GoogleFonts.outfit(
                    fontSize: 13, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
          SharedTeacherWidgets.scoreChip(s.averageScore),
        ],
      ),
    );
  }

  Widget _buildContentAnalyticsList({bool isMobile = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Content Performance',
            style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: WebColors.textPrimary)),
        const SizedBox(height: 16),
        ...content.map((deck) {
          final a = analytics[deck.id];
          return _contentAnalyticsRow(deck, a, isMobile: isMobile);
        }),
      ],
    );
  }

  Widget _contentAnalyticsRow(PublicDeck deck, ContentAnalytics? a, {bool isMobile = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WebColors.border.withValues(alpha: 0.5)),
        boxShadow: WebColors.cardShadow,
      ),
      child: isMobile
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(deck.title,
                        style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis),
                  ),
                  SharedTeacherWidgets.badge(
                    deck.isExam ? 'Exam' : 'Pack',
                    deck.isExam ? WebColors.purplePrimary : WebColors.secondary
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _analyticsMini('Attempts', '${a?.numberOfAttempts ?? 0}', WebColors.blueInfo),
                  _analyticsMini('Avg Score', '${a?.averageScore.toStringAsFixed(0) ?? 0}%', WebColors.success),
                  _analyticsMini('Rate', '${a?.completionRate.toStringAsFixed(0) ?? 0}%', WebColors.secondary),
                ],
              )
            ],
          )
        : Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(deck.title,
                        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis),
                    SharedTeacherWidgets.badge(
                      deck.isExam ? 'Exam' : 'Study Pack',
                      deck.isExam ? WebColors.purplePrimary : WebColors.secondary
                    ),
                  ],
                ),
              ),
              Expanded(
                  child: _analyticsMini('Attempts',
                      '${a?.numberOfAttempts ?? 0}', WebColors.blueInfo)),
              Expanded(
                  child: _analyticsMini('Avg Score',
                      '${a?.averageScore.toStringAsFixed(0) ?? 0}%', WebColors.success)),
              Expanded(
                  child: _analyticsMini('Completion',
                      '${a?.completionRate.toStringAsFixed(0) ?? 0}%', WebColors.secondary)),
            ],
          ),
    );
  }

  Widget _analyticsMini(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: GoogleFonts.outfit(
                fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        Text(label,
            style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: WebColors.textTertiary)),
      ],
    );
  }
}

class _TrendChart extends StatelessWidget {
  final Map<String, int> data;
  const _TrendChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('No trend data available'));
    }

    final sortedKeys = data.keys.toList()..sort();
    final values = sortedKeys.map((k) => data[k]!.toDouble()).toList();
    final maxValue = values.isEmpty ? 1.0 : values.reduce((curr, next) => curr > next ? curr : next);

    return CustomPaint(
      painter: _TrendPainter(
        values: values, 
        maxValue: maxValue == 0 ? 1 : maxValue,
        isDark: Theme.of(context).brightness == Brightness.dark,
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<double> values;
  final double maxValue;
  final bool isDark;

  _TrendPainter({required this.values, required this.maxValue, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final paint = Paint()
      ..color = WebColors.purplePrimary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
            WebColors.purplePrimary.withValues(alpha: 0.2),
            WebColors.purplePrimary.withValues(alpha: 0.0)
          ])
          .createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();

    final stepX = size.width / (values.length - 1);

    for (int i = 0; i < values.length; i++) {
      final x = i * stepX;
      final y = size.height - (values[i] / maxValue * size.height);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        final prevX = (i - 1) * stepX;
        final prevY = size.height - (values[i - 1] / maxValue * size.height);
        final cx = (prevX + x) / 2;
        path.quadraticBezierTo(prevX, prevY, cx, (prevY + y) / 2);
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }

      if (i == values.length - 1) {
        fillPath.lineTo(x, size.height);
        fillPath.close();
      }
    }

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
    
    final pointPaint = Paint()
      ..color = WebColors.purplePrimary
      ..style = PaintingStyle.fill;
      
    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < values.length; i++) {
      if (values.length > 20 && i % 3 != 0) continue;
      
      final x = i * stepX;
      final y = size.height - (values[i] / maxValue * size.height);
      canvas.drawCircle(Offset(x, y), 4, pointPaint);
      canvas.drawCircle(Offset(x, y), 4, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
