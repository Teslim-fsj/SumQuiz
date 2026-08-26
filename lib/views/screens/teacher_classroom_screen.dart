import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sumquiz/models/public_deck.dart';
import 'package:sumquiz/models/teacher_models.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/teacher_service.dart';
import 'package:sumquiz/theme/web_theme.dart';

class TeacherClassroomScreen extends StatefulWidget {
  final String? classId;

  const TeacherClassroomScreen({super.key, this.classId});

  @override
  State<TeacherClassroomScreen> createState() => _TeacherClassroomScreenState();
}

class _TeacherClassroomScreenState extends State<TeacherClassroomScreen> {
  final _teacherService = TeacherService();
  late Future<_TeachingUnit?> _unit;

  @override
  void initState() {
    super.initState();
    _unit = _loadUnit();
  }

  Future<_TeachingUnit?> _loadUnit() async {
    final user = context.read<UserModel?>();
    if (user == null || widget.classId == null) return null;
    final content = await _teacherService.getTeacherContent(user.uid);
    PublicDeck? deck;
    for (final item in content) {
      if (item.id == widget.classId) {
        deck = item;
        break;
      }
    }
    if (deck == null) return null;
    final results = await Future.wait([
      _teacherService.getContentAnalytics(user.uid, deck),
      _teacherService.getStudentList(user.uid),
    ]);
    return _TeachingUnit(
      deck,
      results[0] as ContentAnalytics,
      (results[1] as List<StudentLink>)
          .where((student) => student.contentId == deck!.id)
          .toList(),
    );
  }

  Future<void> _refresh() async {
    setState(() => _unit = _loadUnit());
    await _unit;
  }

  void _copyShareCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Share code copied')));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDark ? Colors.white : const Color(0xFF1E293B);
    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Teaching activity',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w800,
            color: foreground,
          ),
        ),
      ),
      body: FutureBuilder<_TeachingUnit?>(
        future: _unit,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final unit = snapshot.data;
          if (unit == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search_off_outlined, size: 48),
                  const SizedBox(height: 12),
                  const Text('Teaching material not found'),
                  TextButton(
                    onPressed: () => context.go('/teacher/library'),
                    child: const Text('Open library'),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  unit.deck.title,
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: foreground,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  unit.deck.description.isEmpty
                      ? (unit.deck.isExam ? 'Exam' : 'Study pack')
                      : unit.deck.description,
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 18),
                _shareCard(unit.deck, isDark),
                const SizedBox(height: 20),
                _metrics(unit.analytics, unit.students.length, isDark),
                const SizedBox(height: 24),
                Text(
                  'Learners',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
                const SizedBox(height: 10),
                if (unit.students.isEmpty)
                  _emptyLearners(isDark)
                else
                  ...unit.students.map(
                    (student) => _studentCard(student, isDark),
                  ),
                if (unit.analytics.hardQuestions.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Questions to revisit',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: foreground,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...unit.analytics.hardQuestions.map(
                    (insight) => Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.lightbulb_outline,
                          color: Color(0xFFF59E0B),
                        ),
                        title: Text(
                          insight.questionText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${insight.failureRate.toStringAsFixed(0)}% answered incorrectly',
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _shareDeckNative(PublicDeck deck) {
    final shareText = deck.shareCode.isNotEmpty
        ? 'Practice "${deck.title}" on SumQuiz! Join with code: ${deck.shareCode} or open: https://sumquiz.com/deck?id=${deck.id}'
        : 'Practice "${deck.title}" on SumQuiz! https://sumquiz.com/deck?id=${deck.id}';

    Share.share(shareText, subject: 'SumQuiz: ${deck.title}');
  }

  Widget _shareCard(PublicDeck deck, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.share_outlined, color: WebColors.purplePrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Share with students',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  deck.shareCode.isEmpty
                      ? 'Open material to share its link'
                      : 'Code: ${deck.shareCode}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          if (deck.shareCode.isNotEmpty)
            IconButton(
              tooltip: 'Copy share code',
              onPressed: () => _copyShareCode(deck.shareCode),
              icon: const Icon(Icons.copy_outlined),
            ),
          IconButton(
            tooltip: 'Share link',
            onPressed: () => _shareDeckNative(deck),
            icon: const Icon(Icons.share_rounded),
          ),
          IconButton(
            tooltip: 'Preview as student',
            onPressed: () => context.push('/deck?id=${deck.id}'),
            icon: const Icon(Icons.open_in_new_rounded),
          ),
        ],
      ),
    );
  }

  Widget _metrics(ContentAnalytics analytics, int learners, bool isDark) {
    return Row(
      children: [
        _metric('Learners', '$learners', Icons.people_outline, isDark),
        const SizedBox(width: 10),
        _metric(
          'Attempts',
          '${analytics.numberOfAttempts}',
          Icons.fact_check_outlined,
          isDark,
        ),
        const SizedBox(width: 10),
        _metric(
          'Average',
          '${analytics.averageScore.toStringAsFixed(0)}%',
          Icons.insights_outlined,
          isDark,
        ),
      ],
    );
  }

  Widget _metric(String label, String value, IconData icon, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: WebColors.purplePrimary, size: 20),
            const SizedBox(height: 10),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyLearners(bool isDark) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Text(
      'No quiz attempts yet. Share this material with students to see their results here.',
    ),
  );

  Widget _studentCard(StudentLink student, bool isDark) => Card(
    child: ListTile(
      leading: CircleAvatar(
        child: Text(
          student.studentName.isEmpty
              ? '?'
              : student.studentName.characters.first.toUpperCase(),
        ),
      ),
      title: Text(student.studentName),
      subtitle: Text(
        '${student.totalAttempts} attempt${student.totalAttempts == 1 ? '' : 's'}',
      ),
      trailing: Text(
        '${student.averageScore.toStringAsFixed(0)}%',
        style: GoogleFonts.outfit(fontWeight: FontWeight.w800),
      ),
    ),
  );
}

class _TeachingUnit {
  final PublicDeck deck;
  final ContentAnalytics analytics;
  final List<StudentLink> students;

  const _TeachingUnit(this.deck, this.analytics, this.students);
}
