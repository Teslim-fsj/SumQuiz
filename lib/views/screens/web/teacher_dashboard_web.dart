import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:sumquiz/models/public_deck.dart';
import 'package:sumquiz/models/teacher_models.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/auth_service.dart';
import 'package:sumquiz/services/enhanced_ai_service.dart';
import 'package:sumquiz/services/teacher_service.dart';
import 'package:sumquiz/theme/web_theme.dart';

// ─── Nav Items ────────────────────────────────────────────────────────────────

enum _NavModule {
  dashboard,
  content,
  students,
  analytics,
  feedback,
}

// ─── Main Widget ──────────────────────────────────────────────────────────────

class TeacherDashboardWeb extends StatefulWidget {
  final String module;
  const TeacherDashboardWeb({super.key, this.module = 'dashboard'});

  @override
  State<TeacherDashboardWeb> createState() => _TeacherDashboardWebState();
}

class _TeacherDashboardWebState extends State<TeacherDashboardWeb> {
  final _svc = TeacherService();
  late _NavModule _activeModule;

  TeacherStats? _stats;
  List<PublicDeck> _content = [];
  List<StudentLink> _students = [];
  List<ActivityItem> _activity = [];
  final Map<String, ContentAnalytics> _analytics = {};
  Map<String, int> _trends = {};
  String? _feedbackInsight;

  bool _isLoading = true;
  bool _isGeneratingFeedback = false;
  String? _uid;

  @override
  void initState() {
    super.initState();
    _activeModule = _getModuleFromWidget();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  @override
  void didUpdateWidget(TeacherDashboardWeb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.module != widget.module) {
      setState(() {
        _activeModule = _getModuleFromWidget();
      });
      _onModuleChanged();
    }
  }

  _NavModule _getModuleFromWidget() {
    return switch (widget.module) {
      'content' => _NavModule.content,
      'students' => _NavModule.students,
      'analytics' => _NavModule.analytics,
      'feedback' => _NavModule.feedback,
      _ => _NavModule.dashboard,
    };
  }

  void _onModuleChanged() {
    if (_activeModule == _NavModule.analytics && _trends.isEmpty) {
      _loadTrends();
      for (final deck in _content) {
        _loadAnalyticsForContent(deck);
      }
    }
    if (_activeModule == _NavModule.feedback && _feedbackInsight == null) {
      for (final deck in _content) {
        _loadAnalyticsForContent(deck);
      }
    }
  }

  Future<void> _loadTrends() async {
    if (_uid == null) return;
    final t = await _svc.getCompletionTrends(_uid!);
    if (mounted) setState(() => _trends = t);
  }

  Future<void> _loadAll() async {
    _uid = Provider.of<AuthService>(context, listen: false).currentUser?.uid;
    if (_uid == null) return;
    setState(() => _isLoading = true);

    final results = await Future.wait([
      _svc.getTeacherStats(_uid!),
      _svc.getTeacherContent(_uid!),
      _svc.getStudentList(_uid!),
      _svc.getRecentActivity(_uid!),
    ]);

    if (!mounted) return;
    setState(() {
      _stats = results[0] as TeacherStats;
      _content = results[1] as List<PublicDeck>;
      _students = results[2] as List<StudentLink>;
      _activity = results[3] as List<ActivityItem>;
      _isLoading = false;
    });

    if (_activeModule == _NavModule.analytics) {
      _loadTrends();
    }
  }

  Future<void> _loadAnalyticsForContent(PublicDeck deck) async {
    if (_analytics.containsKey(deck.id)) return;
    final a = await _svc.getContentAnalytics(deck);
    if (mounted) setState(() => _analytics[deck.id] = a);
  }

  Future<void> _generateAiFeedback() async {
    if (_content.isEmpty) return;
    setState(() => _isGeneratingFeedback = true);

    try {
      final ai = Provider.of<EnhancedAIService>(context, listen: false);
      final buffer = StringBuffer();
      for (final a in _analytics.values) {
        if (a.hardQuestions.isEmpty) continue;
        buffer.writeln('Content: ${a.contentTitle}');
        for (final q in a.hardQuestions) {
          buffer.writeln('  Q${q.questionIndex + 1}: "${q.questionText}" – ${q.failureRate.toStringAsFixed(0)}% failure rate');
        }
      }

      if (buffer.isEmpty) {
        setState(() {
          _feedbackInsight = 'No attempt data yet. Share your content and ask students to attempt it to get AI insights.';
          _isGeneratingFeedback = false;
        });
        return;
      }

      final prompt = '''You are an educational analytics AI. A teacher has the following exam question failure data:

$buffer

Write 3–5 concise, actionable insights for the teacher. For each insight:
1. Identify the concept students are struggling with.
2. Explain why they likely missed it.
3. Suggest one specific teaching/revision action.

Format: Use bullet points. Keep it professional and direct. Max 200 words.''';

      final result = await ai.refineContent(prompt);
      if (mounted) {
        setState(() {
          _feedbackInsight = result;
          _isGeneratingFeedback = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _feedbackInsight = 'Failed to generate insights: $e';
          _isGeneratingFeedback = false;
        });
      }
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final userModel = context.watch<UserModel?>();
    if (userModel != null && !userModel.isPro) return _buildUpgradeView();

    return Scaffold(
      backgroundColor: WebColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildModuleContent(),
    );
  }

  // ─── Module Content Dispatcher ──────────────────────────────────────────────

  // ─── Module Dispatcher ──────────────────────────────────────────────────────

  Widget _buildModuleContent() {
    return switch (_activeModule) {
      _NavModule.dashboard => _buildDashboardModule(),
      _NavModule.content => _buildContentModule(),
      _NavModule.students => _buildStudentsModule(),
      _NavModule.analytics => _buildAnalyticsModule(),
      _NavModule.feedback => _buildFeedbackModule(),
    };
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MODULE 1 — DASHBOARD
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildDashboardModule() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _moduleHeader('Dashboard', 'Live overview of your teaching activity'),
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
    final s = _stats;
    return Row(
      children: [
        _statCard('Exams Created', '${s?.totalExams ?? 0}',
            Icons.assignment_outlined, WebColors.purplePrimary),
        const SizedBox(width: 16),
        _statCard('Study Packs', '${s?.totalStudyPacks ?? 0}',
            Icons.library_books_outlined, WebColors.secondary),
        const SizedBox(width: 16),
        _statCard('Total Students', '${s?.totalStudents ?? 0}',
            Icons.people_outline, WebColors.blueInfo),
        const SizedBox(width: 16),
        _statCard('Active (7d)', '${s?.activeStudents ?? 0}',
            Icons.bolt_rounded, WebColors.success),
        const SizedBox(width: 16),
        _statCard('Avg Score', '${s?.averageScore.toStringAsFixed(0) ?? 0}%',
            Icons.star_outline_rounded, WebColors.accentOrange),
        const SizedBox(width: 16),
        _statCard('Total Attempts', '${s?.totalAttempts ?? 0}',
            Icons.timeline_rounded, WebColors.error),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
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
      ).animate().fadeIn(delay: (100 * (_NavModule.values.indexOf(_NavModule.dashboard))).ms),
    );
  }

  Widget _buildActivityFeed() {
    return _sectionCard(
      'Recent Activity',
      Icons.rss_feed_rounded,
      Column(
        children: _activity.isEmpty
            ? [
                _emptyHint('No activity yet. Share your content with students!'),
              ]
            : _activity.map((item) => _activityTile(item)).toList(),
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
                  '${item.subtitle} • ${_relativeTime(item.timestamp)}',
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
    final lowEngagement = _content
        .where((c) =>
            (_analytics[c.id]?.engagementRate ?? 0) < 30 &&
            _analytics.containsKey(c.id))
        .take(3)
        .toList();
    final topContent = _content
        .where((c) =>
            (_analytics[c.id]?.averageScore ?? 0) > 70 &&
            _analytics.containsKey(c.id))
        .take(3)
        .toList();

    return Column(
      children: [
        _sectionCard(
          'Top Content',
          Icons.emoji_events_outlined,
          topContent.isEmpty
              ? _emptyHint(
                  'No analytics yet. Generate activity to see top performers.')
              : Column(
                  children: topContent.map((d) {
                    final a = _analytics[d.id]!;
                    return _insightRow(d.title,
                        '${a.averageScore.toStringAsFixed(0)}% avg', Colors.green);
                  }).toList(),
                ),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          'Needs Attention',
          Icons.report_problem_outlined,
          lowEngagement.isEmpty
              ? _emptyHint('All content is performing well.')
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(tag,
                style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MODULE 2 — CONTENT
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildContentModule() {
    final exams = _content.where((c) => c.isExam).toList();
    final packs = _content.where((c) => !c.isExam).toList();

    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(40, 40, 40, 0),
            child: Row(
              children: [
                Expanded(
                    child: _moduleHeader(
                        'Content', 'Manage your exams and study packs')),
                ElevatedButton.icon(
                  onPressed: () => context.push('/exam-creation'),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Exam'),
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14)),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => context.push('/create'),
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Study Pack'),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14)),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'Exams'),
                Tab(text: 'Study Packs'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildContentGrid(exams),
                _buildContentGrid(packs),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentGrid(List<PublicDeck> items) {
    if (items.isEmpty) {
      return Center(
          child: _emptyHint('No content here yet. Create your first piece!'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(40),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 1.3,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => _contentCard(items[i]),
    );
  }

  Widget _contentCard(PublicDeck deck) {
    final a = _analytics[deck.id];
    return Container(
      decoration: WebColors.glassDecoration(
        blur: 15,
        opacity: 0.1,
        color: WebColors.surface,
        borderRadius: 20,
      ).copyWith(
        boxShadow: WebColors.cardShadow,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (deck.isExam ? WebColors.purplePrimary : WebColors.secondary)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  deck.isExam
                      ? Icons.assignment_outlined
                      : Icons.library_books_outlined,
                  color:
                      deck.isExam ? WebColors.purplePrimary : WebColors.secondary,
                  size: 18,
                ),
              ),
              const Spacer(),
              _badge(deck.isExam ? 'Exam' : 'Pack',
                  deck.isExam ? WebColors.purplePrimary : WebColors.secondary),
            ],
          ),
          const SizedBox(height: 12),
          Text(deck.title,
              style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: WebColors.textPrimary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          Text(DateFormat.yMMMd().format(deck.publishedAt),
              style: GoogleFonts.outfit(
                  fontSize: 11, color: WebColors.textTertiary)),
          const Spacer(),
          if (a != null) ...[
            Row(
              children: [
                _miniStat(Icons.group_outlined, '${a.numberOfAttempts}'),
                const SizedBox(width: 12),
                _miniStat(Icons.star_outline, '${a.averageScore.toStringAsFixed(0)}%'),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showShareModal(deck),
                  icon: const Icon(Icons.share_outlined, size: 14),
                  label: const Text('Share'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _editDeck(deck),
                icon: const Icon(Icons.edit_outlined, size: 16),
                tooltip: 'Edit',
                style: IconButton.styleFrom(
                    backgroundColor: WebColors.backgroundAlt),
              ),
              IconButton(
                onPressed: () => _confirmDelete(deck),
                icon: const Icon(Icons.delete_outline, size: 16,
                    color: WebColors.error),
                tooltip: 'Delete',
                style: IconButton.styleFrom(
                    backgroundColor: WebColors.error.withValues(alpha: 0.08)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showShareModal(PublicDeck deck) {
    final link = 'https://sumquiz.xyz/s/${deck.shareCode}';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Share: ${deck.title}',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _shareRow('Code', deck.shareCode, Icons.tag),
            const SizedBox(height: 16),
            _shareRow('Link', link, Icons.link),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: WebColors.backgroundAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(Icons.qr_code_2, size: 80),
                  const SizedBox(height: 8),
                  Text(link,
                      style: GoogleFonts.outfit(
                          fontSize: 11, color: WebColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _shareRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: WebColors.textSecondary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.outfit(
                    fontSize: 10,
                    color: WebColors.textTertiary,
                    fontWeight: FontWeight.w600)),
            Text(value,
                style: GoogleFonts.outfit(
                    fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.copy, size: 16),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$label copied!')),
            );
          },
        ),
      ],
    );
  }

  void _editDeck(PublicDeck deck) {
    if (deck.isExam) {
      context.push('/exam-creation?id=${deck.id}');
    } else {
      final type = deck.type;
      context.push('/create/$type?id=${deck.id}');
    }
  }

  void _showInviteStudentDialog() {
    final emailController = TextEditingController();
    final codeController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Invite Student',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  'Manually link a student to your content using its share code.',
                  style: GoogleFonts.outfit(
                      fontSize: 13, color: WebColors.textSecondary)),
              const SizedBox(height: 20),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Student Email',
                  hintText: 'student@example.com',
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeController,
                decoration: InputDecoration(
                  labelText: 'Content Share Code',
                  hintText: 'e.g. AB123',
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (emailController.text.isEmpty ||
                          codeController.text.isEmpty) {
                        return;
                      }
                      setDialogState(() => isSubmitting = true);
                      try {
                        await _svc.registerStudentWithCode(
                            _uid!,
                            emailController.text.trim(),
                            codeController.text.toUpperCase().trim());
                        if (context.mounted) {
                          Navigator.pop(context);
                          _loadAll(); // Refresh
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Student registered successfully')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          setDialogState(() => isSubmitting = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: ${e.toString()}')),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: WebColors.purplePrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Register'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(PublicDeck deck) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Content'),
        content: Text('Delete "${deck.title}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: WebColors.error,
                foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _svc.deleteContent(deck.id);
      await _loadAll();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MODULE 3 — STUDENTS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStudentsModule() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _moduleHeader('Students',
                    'Registry of all students engaging with your content'),
              ),
              ElevatedButton.icon(
                onPressed: _showInviteStudentDialog,
                icon: const Icon(Icons.person_add_outlined, size: 18),
                label: const Text('Invite Student'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WebColors.purplePrimary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          if (_students.isEmpty)
            _emptyCard('No students yet',
                'Share your content with students to see them here.')
          else
            _buildStudentTable(),
        ],
      ),
    );
  }

  Widget _buildStudentTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WebColors.border),
      ),
      child: Column(
        children: [
          // Header Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: WebColors.backgroundAlt,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                _tableHeader('Student', flex: 3),
                _tableHeader('Last Active', flex: 2),
                _tableHeader('Attempts'),
                _tableHeader('Avg Score'),
                _tableHeader('Completion'),
              ],
            ),
          ),
          // Rows
          ..._students.map((s) => _studentRow(s)),
        ],
      ),
    );
  }

  Widget _tableHeader(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(text,
          style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: WebColors.textSecondary,
              letterSpacing: 0.5)),
    );
  }

  Widget _studentRow(StudentLink s) {
    final isActive = s.lastActiveAt != null &&
        s.lastActiveAt!.isAfter(DateTime.now().subtract(const Duration(days: 7)));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: WebColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor:
                      WebColors.purplePrimary.withValues(alpha: 0.15),
                  child: Text(
                    s.studentName.isNotEmpty ? s.studentName[0].toUpperCase() : '?',
                    style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: WebColors.purplePrimary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.studentName,
                          style: GoogleFonts.outfit(
                              fontSize: 13, fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis),
                      if (s.studentEmail.isNotEmpty)
                        Text(s.studentEmail,
                            style: GoogleFonts.outfit(
                                fontSize: 11, color: WebColors.textTertiary),
                            overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive ? WebColors.success : WebColors.border,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  s.lastActiveAt != null
                      ? _relativeTime(s.lastActiveAt!)
                      : 'Never',
                  style: GoogleFonts.outfit(
                      fontSize: 12, color: WebColors.textSecondary),
                ),
              ],
            ),
          ),
          Expanded(
              child: Text('${s.totalAttempts}',
                  style: GoogleFonts.outfit(
                      fontSize: 13, fontWeight: FontWeight.w700))),
          Expanded(
            child: _scoreChip(s.averageScore),
          ),
          Expanded(
            child: _progressBar(s.completionRate / 100),
          ),
        ],
      ),
    );
  }

  Widget _scoreChip(double score) {
    final color = score >= 70
        ? WebColors.success
        : score >= 50
            ? WebColors.accentOrange
            : WebColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('${score.toStringAsFixed(0)}%',
          style: GoogleFonts.outfit(
              fontSize: 12, fontWeight: FontWeight.w800, color: color)),
    );
  }

  Widget _progressBar(double value) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: WebColors.backgroundAlt,
              valueColor: AlwaysStoppedAnimation(WebColors.blueInfo),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('${(value * 100).toStringAsFixed(0)}%',
            style: GoogleFonts.outfit(
                fontSize: 11, color: WebColors.textSecondary)),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MODULE 4 — ANALYTICS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildAnalyticsModule() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _moduleHeader('Analytics',
              'Detailed insights about content and student performance'),
          const SizedBox(height: 32),
          if (_content.isEmpty)
            _emptyCard('No content to analyze',
                'Create and share content to generate analytics data.')
          else ...[
            _buildClassOverview(),
            const SizedBox(height: 32),
            _buildTrendSection(),
            const SizedBox(height: 32),
            _buildContentAnalyticsList(),
          ],
        ],
      ),
    );
  }

  Widget _buildTrendSection() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: WebColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Activity Trends',
              style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: WebColors.textPrimary)),
          Text('Total student attempts over the last 30 days',
              style: GoogleFonts.outfit(
                  fontSize: 12, color: WebColors.textTertiary)),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            width: double.infinity,
            child: _TrendChart(data: _trends),
          ),
        ],
      ),
    );
  }

  Widget _buildClassOverview() {
    final sorted = List<StudentLink>.from(_students)
      ..sort((a, b) => b.averageScore.compareTo(a.averageScore));
    final topStudents = sorted.take(3).toList();
    final weakStudents = sorted.reversed.take(3).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _sectionCard(
            'Top Performers',
            Icons.emoji_events_outlined,
            Column(
              children: topStudents.isEmpty
                  ? [_emptyHint('No student data yet')]
                  : topStudents.asMap().entries.map((e) {
                      return _rankRow(e.key + 1, e.value);
                    }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _sectionCard(
            'Needs Support',
            Icons.support_outlined,
            Column(
              children: weakStudents.isEmpty
                  ? [_emptyHint('No student data yet')]
                  : weakStudents.map((s) => _rankRow(0, s, showWarning: true)).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _rankRow(int rank, StudentLink s, {bool showWarning = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          if (rank > 0)
            SizedBox(
              width: 24,
              child: Text('#$rank',
                  style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: rank == 1 ? WebColors.accentOrange : WebColors.textTertiary)),
            )
          else
            const SizedBox(width: 24),
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
          _scoreChip(s.averageScore),
        ],
      ),
    );
  }

  Widget _buildContentAnalyticsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Content Performance',
            style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: WebColors.textPrimary)),
        const SizedBox(height: 16),
        _buildTrendSection(),
        const SizedBox(height: 32),
        ..._content.map((deck) {
          final a = _analytics[deck.id];
          return _contentAnalyticsRow(deck, a);
        }),
      ],
    );
  }

  Widget _contentAnalyticsRow(PublicDeck deck, ContentAnalytics? a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WebColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(deck.title,
                    style: GoogleFonts.outfit(
                        fontSize: 14, fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis),
                Text(deck.isExam ? 'Exam' : 'Study Pack',
                    style: GoogleFonts.outfit(
                        fontSize: 11, color: WebColors.textTertiary)),
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
                fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        Text(label,
            style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: WebColors.textTertiary)),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MODULE 5 — AI FEEDBACK
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildFeedbackModule() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _moduleHeader('AI Feedback Engine',
                    'Identify hard questions and improvement opportunities'),
              ),
              ElevatedButton.icon(
                onPressed: _isGeneratingFeedback ? null : _generateAiFeedback,
                icon: _isGeneratingFeedback
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome, size: 16),
                label:
                    Text(_isGeneratingFeedback ? 'Analyzing...' : 'Generate Insights'),
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14)),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // AI Insight Box
          if (_feedbackInsight != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    WebColors.purplePrimary.withValues(alpha: 0.06),
                    WebColors.blueInfo.withValues(alpha: 0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: WebColors.purplePrimary.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome,
                          color: WebColors.purplePrimary, size: 20),
                      const SizedBox(width: 10),
                      Text('AI-Generated Teaching Insights',
                          style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: WebColors.purplePrimary)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(_feedbackInsight!,
                      style: GoogleFonts.outfit(
                          fontSize: 14,
                          height: 1.7,
                          color: WebColors.textPrimary)),
                ],
              ),
            ).animate().fadeIn()
          else
            _emptyCard('No insights yet',
                'Click "Generate Insights" above. AI will analyze your students\' attempts and identify the most difficult questions and commonly missed concepts.'),
          const SizedBox(height: 32),
          // Per-content hard questions
          _buildHardQuestionsList(),
        ],
      ),
    );
  }

  Widget _buildHardQuestionsList() {
    final contentWithData = _analytics.values
        .where((a) => a.hardQuestions.isNotEmpty)
        .toList();

    if (contentWithData.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Hard Question Analysis',
            style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: WebColors.textPrimary)),
        const SizedBox(height: 16),
        ...contentWithData.map((a) => _hardQuestionsCard(a)),
      ],
    );
  }

  Widget _hardQuestionsCard(ContentAnalytics a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WebColors.border),
      ),
      child: ExpansionTile(
        title: Text(a.contentTitle,
            style: GoogleFonts.outfit(
                fontSize: 14, fontWeight: FontWeight.w800)),
        subtitle: Text('${a.hardQuestions.length} problem areas detected',
            style: GoogleFonts.outfit(
                fontSize: 12, color: WebColors.textTertiary)),
        children: a.hardQuestions.map((q) => _questionInsightTile(a, q)).toList(),
      ),
    );
  }

  Widget _questionInsightTile(ContentAnalytics a, QuestionInsight q) {
    final failColor = q.failureRate > 60
        ? WebColors.error
        : q.failureRate > 40
            ? WebColors.accentOrange
            : WebColors.yellowTip;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: WebColors.border))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: failColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.warning_amber_rounded, color: failColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Q${q.questionIndex + 1}: ${q.questionText}',
                    style: GoogleFonts.outfit(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(
                    '${q.failureRate.toStringAsFixed(0)}% of students answered incorrectly',
                    style: GoogleFonts.outfit(
                        fontSize: 11, color: WebColors.textTertiary)),
              ],
            ),
          ),
          Column(
            children: [
              _badge('${q.failureRate.toStringAsFixed(0)}% fail', failColor),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  // Find the deck and navigate to edit
                  final deck = _content.firstWhere((d) => d.id == a.contentId);
                  _editDeck(deck);
                },
                icon: const Icon(Icons.build_circle_outlined, size: 14),
                label: const Text('Fix'),
                style: TextButton.styleFrom(
                  foregroundColor: WebColors.purplePrimary,
                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Upgrade View ────────────────────────────────────────────────────────────

  Widget _buildUpgradeView() {
    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(48),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: WebColors.cardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: WebColors.purplePrimary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.school_rounded,
                    size: 48, color: WebColors.purplePrimary),
              ),
              const SizedBox(height: 24),
              Text('Unlock the Educator Toolkit',
                  style: GoogleFonts.outfit(
                      fontSize: 28, fontWeight: FontWeight.w900),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Text(
                'Get access to the full 5-module teacher dashboard: create exams, track students, view analytics, and AI-powered feedback.',
                style: GoogleFonts.outfit(
                    color: WebColors.textSecondary, fontSize: 14, height: 1.6),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.push('/settings/subscription'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(20),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Upgrade to Pro'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Continue as Student')),
            ],
          ),
        ).animate().fadeIn().scale(),
      ),
    );
  }

  // ─── Shared Helpers ──────────────────────────────────────────────────────────

  Widget _moduleHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: GoogleFonts.outfit(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: WebColors.textPrimary)),
        const SizedBox(height: 4),
        Text(subtitle,
            style: GoogleFonts.outfit(
                fontSize: 14, color: WebColors.textSecondary)),
      ],
    );
  }

  Widget _sectionCard(String title, IconData icon, Widget child) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WebColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: WebColors.textSecondary),
              const SizedBox(width: 10),
              Text(title,
                  style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: WebColors.textPrimary)),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: WebColors.border),
          ),
          child,
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: GoogleFonts.outfit(
              fontSize: 10, fontWeight: FontWeight.w800, color: color)),
    );
  }

  Widget _miniStat(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 12, color: WebColors.textTertiary),
        const SizedBox(width: 4),
        Text(value,
            style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: WebColors.textSecondary)),
      ],
    );
  }

  Widget _emptyHint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(text,
          style: GoogleFonts.outfit(
              fontSize: 13,
              color: WebColors.textTertiary,
              fontStyle: FontStyle.italic)),
    );
  }

  Widget _emptyCard(String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WebColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 48, color: WebColors.textTertiary),
          const SizedBox(height: 16),
          Text(title,
              style: GoogleFonts.outfit(
                  fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(subtitle,
              style: GoogleFonts.outfit(
                  fontSize: 14, color: WebColors.textSecondary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat.yMMMd().format(dt);
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
    final maxValue = values.reduce((curr, next) => curr > next ? curr : next);

    return CustomPaint(
      painter:
          _TrendPainter(values: values, maxValue: maxValue == 0 ? 1 : maxValue),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<double> values;
  final double maxValue;

  _TrendPainter({required this.values, required this.maxValue});

  @override
  void paint(Canvas canvas, Size size) {
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

    if (values.length < 2) return;

    final stepX = size.width / (values.length - 1);

    for (int i = 0; i < values.length; i++) {
      final x = i * stepX;
      final y = size.height - (values[i] / maxValue * size.height);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
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
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
