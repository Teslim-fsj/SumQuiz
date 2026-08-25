import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/models/teacher_models.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/teacher_service.dart';
import 'package:sumquiz/theme/web_theme.dart';

class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({super.key});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  final _teacherService = TeacherService();
  late Future<_DashboardData> _dashboard;

  @override
  void initState() {
    super.initState();
    _dashboard = _loadDashboard();
  }

  Future<_DashboardData> _loadDashboard() async {
    final user = context.read<UserModel?>();
    if (user == null) return const _DashboardData(TeacherStats(), []);
    final data = await Future.wait([
      _teacherService.getTeacherStats(user.uid),
      _teacherService.getRecentActivity(user.uid),
    ]);
    return _DashboardData(
      data[0] as TeacherStats,
      data[1] as List<ActivityItem>,
    );
  }

  Future<void> _refresh() async {
    setState(() => _dashboard = _loadDashboard());
    await _dashboard;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = context.watch<UserModel?>();
    final foreground = isDark ? Colors.white : const Color(0xFF1E293B);
    final name = (user?.displayName ?? 'Teacher').split(' ').first;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: FutureBuilder<_DashboardData>(
          future: _dashboard,
          builder: (context, snapshot) {
            final data = snapshot.data;
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Hello, $name',
                          style: GoogleFonts.outfit(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: foreground,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => context.push('/settings'),
                        icon: const Icon(Icons.settings_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Create, share, and review learning progress.',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 24),
                  _quickActions(isDark),
                  const SizedBox(height: 28),
                  Text(
                    'Teaching overview',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: foreground,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (snapshot.connectionState != ConnectionState.done)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(28),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else
                    _stats(data?.stats ?? const TeacherStats(), isDark),
                  const SizedBox(height: 28),
                  Text(
                    'Recent activity',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: foreground,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (snapshot.connectionState != ConnectionState.done)
                    const SizedBox.shrink()
                  else if ((data?.activity ?? []).isEmpty)
                    _emptyActivity(isDark)
                  else
                    ...(data!.activity.map(
                      (item) => _activityCard(item, isDark),
                    )),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _quickActions(bool isDark) => Row(
        children: [
          Expanded(
            child: _action(
              'Create study pack',
              Icons.auto_stories_outlined,
              () => context.push('/create-content'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _action(
              'Create exam',
              Icons.quiz_outlined,
              () => context.push('/create-content/exam-wizard'),
            ),
          ),
        ],
      );

  Widget _action(String label, IconData icon, VoidCallback onTap) =>
      OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 19),
        label: Text(
          label,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );

  Widget _stats(TeacherStats stats, bool isDark) => GridView.count(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisCount: 2,
    mainAxisSpacing: 10,
    crossAxisSpacing: 10,
    childAspectRatio: 1.7,
    children: [
      _stat(
        'Study packs',
        '${stats.totalStudyPacks}',
        Icons.menu_book_outlined,
        isDark,
      ),
      _stat('Exams', '${stats.totalExams}', Icons.quiz_outlined, isDark),
      _stat('Learners', '${stats.totalStudents}', Icons.people_outline, isDark),
      _stat(
        'Average score',
        '${stats.averageScore.toStringAsFixed(0)}%',
        Icons.trending_up_outlined,
        isDark,
      ),
    ],
  );

  Widget _stat(String label, String value, IconData icon, bool isDark) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: WebColors.purplePrimary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _emptyActivity(bool isDark) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Text(
      'Activity will appear here after students open and complete your shared materials.',
    ),
  );

  Widget _activityCard(ActivityItem item, bool isDark) => Card(
    child: ListTile(
      leading: Icon(
        item.type == 'attempt'
            ? Icons.fact_check_outlined
            : Icons.publish_outlined,
        color: WebColors.purplePrimary,
      ),
      title: Text(item.title),
      subtitle: Text(item.subtitle),
      onTap: item.contentId == null
          ? null
          : () => context.push('/teacher/classroom/${item.contentId}'),
    ),
  );
}

class _DashboardData {
  final TeacherStats stats;
  final List<ActivityItem> activity;

  const _DashboardData(this.stats, this.activity);
}
