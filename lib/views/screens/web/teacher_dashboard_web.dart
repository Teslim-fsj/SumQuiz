import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:sumquiz/models/public_deck.dart';
import 'package:sumquiz/models/teacher_models.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/auth_service.dart';
import 'package:sumquiz/services/enhanced_ai_service.dart';
import 'package:sumquiz/services/teacher_service.dart';

import 'teacher/widgets/dashboard_overview.dart';
import 'teacher/widgets/content_manager.dart';
import 'teacher/widgets/student_registry.dart';
import 'teacher/widgets/analytics_view.dart';
import 'teacher/widgets/feedback_insights.dart';

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
  final String? studentId;

  const TeacherDashboardWeb({
    super.key,
    this.module = 'dashboard',
    this.studentId,
  });

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
    if ((_activeModule == _NavModule.analytics || _activeModule == _NavModule.students) && _trends.isEmpty) {
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
    if (_uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);

    try {
      // Use individual catchErrors so one failure doesn't stop the rest
      final results = await Future.wait([
        _svc.getTeacherStats(_uid!).catchError((e) {
          debugPrint('Stats Load Error: $e');
          return TeacherStats(totalExams: 0, totalStudyPacks: 0, totalStudents: 0, activeStudents: 0, averageScore: 0, totalAttempts: 0);
        }),
        _svc.getTeacherContent(_uid!).catchError((e) {
          debugPrint('Content Load Error: $e');
          return <PublicDeck>[];
        }),
        _svc.getStudentList(_uid!).catchError((e) {
          debugPrint('Students Load Error: $e');
          return <StudentLink>[];
        }),
        _svc.getRecentActivity(_uid!).catchError((e) {
          debugPrint('Activity Load Error: $e');
          return <ActivityItem>[];
        }),
      ]).timeout(const Duration(seconds: 10), onTimeout: () => [
        TeacherStats(totalExams: 0, totalStudyPacks: 0, totalStudents: 0, activeStudents: 0, averageScore: 0, totalAttempts: 0),
        <PublicDeck>[],
        <StudentLink>[],
        <ActivityItem>[],
      ]);

      if (!mounted) return;
      setState(() {
        _stats = results[0] as TeacherStats;
        _content = results[1] as List<PublicDeck>;
        _students = results[2] as List<StudentLink>;
        _activity = results[3] as List<ActivityItem>;
      });

      if (_activeModule == _NavModule.analytics || _activeModule == _NavModule.students) {
        _loadTrends();
      }
    } catch (e) {
      debugPrint('Teacher Dashboard Critical Load Error: $e');
      // Set default stats so UI can render
      if (mounted && _stats == null) {
        setState(() {
          _stats = TeacherStats(totalExams: 0, totalStudyPacks: 0, totalStudents: 0, activeStudents: 0, averageScore: 0, totalAttempts: 0);
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
          buffer.writeln(
              '  Q${q.questionIndex + 1}: "${q.questionText}" – ${q.failureRate.toStringAsFixed(0)}% failure rate');
        }
      }

      if (buffer.isEmpty) {
        setState(() {
          _feedbackInsight =
              'No attempt data yet. Share your content and ask students to attempt it to get AI insights.';
          _isGeneratingFeedback = false;
        });
        return;
      }

      final result = await ai.generatePedagogicalInsights(failureData: buffer.toString());
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
    // Allow access if user is Pro OR if they are a Creator (Teacher)
    if (userModel != null && !userModel.isPro && userModel.role != UserRole.creator) {
      return _buildUpgradeView();
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_stats == null) {
      return _buildErrorState();
    }

    return _buildModuleContent(userModel);
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(
            'Failed to load dashboard data',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _loadAll,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ─── Module Content Dispatcher ──────────────────────────────────────────────

  // ─── Module Dispatcher ──────────────────────────────────────────────────────

  Widget _buildModuleContent(UserModel? userModel) {
    return switch (_activeModule) {
      _NavModule.dashboard => StreamBuilder<List<ActivityItem>>(
          stream: _svc.getActivityStream(userModel?.uid ?? ''),
          initialData: _activity,
          builder: (context, snapshot) {
            return DashboardOverview(
              stats: _stats,
              activity: snapshot.data ?? _activity,
              content: _content,
              analytics: _analytics,
              trends: _trends,
            );
          },
        ),
      _NavModule.content => ContentManager(
          content: _content,
          stats: _stats,
          analytics: _analytics,
          onEdit: _editDeck,
          onDelete: _confirmDelete,
          onCreateExam: () => context.go('/create-content/exam-wizard'),
          onCreatePack: () => context.go('/create-content'),
        ),
      _NavModule.students => LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 900) {
              return DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    Container(
                      color: Theme.of(context).cardColor,
                      child: TabBar(
                        labelColor: Theme.of(context).colorScheme.primary,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: Theme.of(context).colorScheme.primary,
                        tabs: const [Tab(text: 'Roster'), Tab(text: 'Analytics')],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          StudentRegistry(
                            students: _students,
                            onInviteStudent: _showInviteStudentDialog,
                          ),
                          AnalyticsView(
                            content: _content,
                            students: _students,
                            trends: _trends,
                            analytics: _analytics,
                            selectedStudentId: widget.studentId,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }
            return StudentRegistry(
              students: _students,
              onInviteStudent: _showInviteStudentDialog,
            );
          },
        ),
      _NavModule.analytics => AnalyticsView(
          content: _content,
          students: _students,
          trends: _trends,
          analytics: _analytics,
          selectedStudentId: widget.studentId,
        ),
      _NavModule.feedback => FeedbackInsights(
          feedbackInsight: _feedbackInsight,
          isGeneratingFeedback: _isGeneratingFeedback,
          onGenerateFeedback: _generateAiFeedback,
          analytics: _analytics,
          content: _content,
          onEditDeck: _editDeck,
        ),
    };
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
    final theme = Theme.of(context);
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
                      fontSize: 13,
                      color:
                          theme.colorScheme.onSurface.withOpacity(0.6))),
              const SizedBox(height: 20),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Student Email',
                  hintText: 'student@example.com',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeController,
                decoration: InputDecoration(
                  labelText: 'Content Share Code',
                  hintText: 'e.g. AB123',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
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
                                content:
                                    Text('Student registered successfully')),
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
                backgroundColor: theme.colorScheme.primary,
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
    final theme = Theme.of(context);
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
                backgroundColor: theme.colorScheme.error,
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

  // ─── Upgrade View ────────────────────────────────────────────────────────────

  Widget _buildUpgradeView() {
    final theme = Theme.of(context);
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.school_rounded,
                  size: 32, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text('Unlock the Educator Toolkit',
                style: GoogleFonts.outfit(
                    fontSize: 22, fontWeight: FontWeight.w900),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Get access to the full 5-module teacher dashboard: create exams, track students, view analytics, and AI-powered feedback.',
              style: GoogleFonts.outfit(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 13,
                  height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push('/settings/subscription'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
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
    );
  }

}
