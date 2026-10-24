import 'dart:async';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sumquiz/services/iap_service.dart';
import 'package:uuid/uuid.dart';

import '../../models/user_model.dart';
import '../../models/local_quiz.dart';
import '../../models/local_quiz_question.dart';
import '../../services/enhanced_ai_service.dart';
import '../../services/local_database_service.dart';
import '../../services/usage_service.dart';
import '../../services/notification_integration.dart';
import '../../services/user_service.dart';
import '../../view_models/quiz_view_model.dart';
import '../widgets/upgrade_dialog.dart';
import '../widgets/quiz_view.dart';
import '../../services/firestore_service.dart';
import '../../services/export_service.dart';
import 'exam_creation_screen.dart';
import '../../services/teacher_service.dart';
import '../../models/teacher_models.dart';
import '../../services/spaced_repetition_service.dart';
import '../../models/local_flashcard.dart';
import 'package:collection/collection.dart';
import '../../providers/sumi_provider.dart';
import '../../models/sumi_emotion.dart';
import '../../widgets/sumi_mascot.dart';
import '../../services/mastery_service.dart';
import '../../services/mastery/sumi_tutor_service.dart';

enum QuizState { creation, loading, inProgress, finished, error }

class QuizScreen extends StatefulWidget {
  final LocalQuiz? quiz;
  final String? id;
  final String? initialText;
  final String? initialTitle;

  const QuizScreen({
    super.key,
    this.quiz,
    this.id,
    this.initialText,
    this.initialTitle,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  late final EnhancedAIService _aiService;
  final LocalDatabaseService _localDbService = LocalDatabaseService();
  late final SpacedRepetitionService _srsService;

  QuizState _state = QuizState.creation;
  String _loadingMessage = 'Generating Quiz...';
  String _errorMessage = '';
  final Stopwatch _stopwatch = Stopwatch();

  late List<LocalQuizQuestion> _questions;

  int _score = 0;
  final Map<String, dynamic> _questionAnswers = {};
  String? _quizId;
  late final ConfettiController _confettiController;
  int _quizAttempt = 0;
  bool _showQuestionReview = true;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 4));
    _localDbService.init().then((_) {
      if (!mounted) return;
      _aiService = EnhancedAIService(
          iapService: Provider.of<IAPService>(context, listen: false),
          localDb: _localDbService);
      _srsService =
          SpacedRepetitionService(_localDbService.getSpacedRepetitionBox());
    });
    _loadQuiz();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _textController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadQuiz() async {
    if (widget.quiz != null) {
      _questions = widget.quiz!.questions;
      _titleController.text = widget.quiz!.title;
      _quizId = widget.quiz!.id;
      _state = QuizState.inProgress;
      _stopwatch.start();
    } else if (widget.id != null) {
      setState(() {
        _state = QuizState.loading;
        _loadingMessage = 'Loading Quiz...';
      });

      try {
        LocalQuiz? quiz = await _localDbService.getQuiz(widget.id!);

        if (quiz == null) {
          if (!mounted) return;
          final user = Provider.of<UserModel?>(context, listen: false);
          if (user != null) {
            final firestore = FirestoreService();
            final fsDoc = await firestore.getQuiz(user.uid, widget.id!);
            if (fsDoc != null) {
              quiz = LocalQuiz(
                id: fsDoc.id,
                title: fsDoc.title,
                timestamp: fsDoc.timestamp.toDate(),
                userId: user.uid,
                questions: fsDoc.questions
                    .map((q) => q.toLocalQuizQuestion())
                    .toList(),
              );
              await _localDbService.saveQuiz(quiz);
            }
          }
        }

        if (quiz != null && mounted) {
          final q = quiz;
          setState(() {
            _questions = q.questions;
            _titleController.text = q.title;
            _quizId = q.id;
            _state = QuizState.inProgress;
            _stopwatch.start();
          });
        } else if (mounted) {
          setState(() {
            _state = QuizState.error;
            _errorMessage = 'Quiz not found.';
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _state = QuizState.error;
            _errorMessage = 'Error loading quiz: $e';
          });
        }
      }
    } else {
      _questions = [];
      _quizId = const Uuid().v4();
      _textController.text = widget.initialText ?? '';
      _titleController.text = widget.initialTitle ?? '';
      if (widget.initialText?.isNotEmpty == true) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _generateQuiz();
        });
      }
    }
    await _loadRelatedFlashcards();
  }

  Future<void> _loadRelatedFlashcards() async {
    if (_quizId == null) return;
    try {
      final folderId = await _localDbService.getParentFolderId(_quizId!);
      if (folderId != null) {
        final contents = await _localDbService.getFolderContents(folderId);
        final flashcardSetContent = contents.firstWhereOrNull((c) =>
            c.contentType == 'flashcardSet' || c.contentType == 'flashcards');
        if (flashcardSetContent != null) {
          final flashcardSet = await _localDbService
              .getFlashcardSet(flashcardSetContent.contentId);
          if (flashcardSet != null) {
            setState(() {
              _relatedFlashcards = flashcardSet.flashcards;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading related flashcards: $e');
    }
  }

  Future<void> _generateQuiz() async {
    if (_titleController.text.isEmpty || _textController.text.isEmpty) {
      setState(() {
        _state = QuizState.error;
        _errorMessage = 'Please provide both a title and text.';
      });
      return;
    }

    final userModel = Provider.of<UserModel?>(context, listen: false);
    final usageService = Provider.of<UsageService?>(context, listen: false);
    if (userModel == null || usageService == null) return;

    if (!userModel.isPro) {
      final canGenerate =
          await usageService.canPerformAction(userModel.uid, 'quizzes');
      if (!mounted) return;
      if (!canGenerate) {
        await NotificationIntegration.onUsageLimitHit(context);
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => const UpgradeDialog(featureName: 'quizzes'),
        );
        return;
      }
    }

    setState(() {
      _state = QuizState.loading;
      _loadingMessage = 'Generating quiz...';
      _resetQuizState();
    });

    try {
      final folderId = await _aiService.generateAndStoreOutputs(
        text: _textController.text,
        title: _titleController.text,
        requestedOutputs: ['quiz'],
        userId: userModel.uid,
        localDb: _localDbService,
        onProgress: (message) {
          setState(() {
            _loadingMessage = message;
          });
        },
      );

      if (!userModel.isPro) {
        await usageService.recordAction(userModel.uid, 'quizzes');
      }

      final content = await _localDbService.getFolderContents(folderId);

      if (content.isNotEmpty) {
        if (!mounted) return;
        await NotificationIntegration.onContentGenerated(
            context, userModel.uid, _titleController.text);
        if (!mounted) return;
        // Navigate to the results screen
        context.go('/library/results-view/$folderId');
      } else {
        throw Exception('AI service returned an empty quiz.');
      }
    } catch (e) {
      setState(() {
        _state = QuizState.error;
        _errorMessage = 'Error generating quiz: $e';
      });
    }
  }

  Future<void> _saveInProgress() async {
    if (_questions.isEmpty ||
        _titleController.text.isEmpty ||
        _quizId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Cannot save an empty quiz."),
        ));
      }
      return;
    }

    final user = Provider.of<UserModel?>(context, listen: false);
    if (user == null) return;

    final quizToSave = LocalQuiz(
      id: _quizId!,
      userId: user.uid,
      title: _titleController.text,
      questions: _questions,
      timestamp: DateTime.now(),
      scores: widget.quiz?.scores ?? [],
      timeSpent: (widget.quiz?.timeSpent ?? 0) + _stopwatch.elapsed.inSeconds,
    );

    try {
      await _localDbService.saveQuiz(quizToSave);
      if (mounted) {
        Provider.of<QuizViewModel>(context, listen: false).refresh();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Quiz progress saved!'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error saving progress: $e'),
        ));
      }
    }
  }

  Future<void> _saveQuizProgress() async {
    final user = Provider.of<UserModel?>(context, listen: false);
    final quizViewModel = Provider.of<QuizViewModel>(context, listen: false);
    if (user == null || _quizId == null) return;

    final percentageScore =
        _questions.isNotEmpty ? (_score / _questions.length) * 100.0 : 0.0;

    final currentSessionSeconds = _stopwatch.elapsed.inSeconds;

    var quizToSave = await _localDbService.getQuiz(_quizId!);

    if (quizToSave != null) {
      quizToSave.scores.add(percentageScore);
      quizToSave.timeSpent += currentSessionSeconds;
    } else {
      quizToSave = LocalQuiz(
        id: _quizId!,
        userId: user.uid,
        title: _titleController.text,
        questions: _questions,
        timestamp: DateTime.now(),
        scores: [percentageScore],
        timeSpent: (widget.quiz?.timeSpent ?? 0) + currentSessionSeconds,
      );
    }

    try {
      await _localDbService.saveQuiz(quizToSave);

      if (quizToSave.publicDeckId != null) {
        final firestoreService = FirestoreService();
        await firestoreService.incrementDeckMetric(
            quizToSave.publicDeckId!, 'completedCount');
      }

      quizViewModel.refresh();

      // Increment daily progress
      try {
        final userService = UserService();
        await userService.incrementItemsCompleted(user.uid);

        // If this quiz belongs to a shared deck, save the attempt for teacher analytics
        if (quizToSave.publicDeckId != null) {
          final teacherService = TeacherService();
          await teacherService.saveAttempt(StudentAttempt(
            attemptId: const Uuid().v4(),
            studentId: user.uid,
            studentName: user.displayName,
            contentId: quizToSave.publicDeckId!,
            score: percentageScore,
            totalQuestions: _questions.length,
            correctAnswers: _score,
            answers: Map<String, dynamic>.from(_questionAnswers),
            attemptedAt: DateTime.now(),
            timeTakenSeconds: currentSessionSeconds,
          ));
        }
      } catch (e) {
        debugPrint('Failed to increment progress or save attempt: $e');
      }

      // Schedule notifications after quiz completion
      if (mounted) {
        try {
          final topic = _titleController.text.split(' ').first;
          final score = percentageScore / 100.0;

          await NotificationIntegration.onQuizCompleted(
            context,
            topic,
            score,
          );
        } catch (e) {
          debugPrint('Failed to schedule notifications: $e');
        }
      }
    } catch (e) {
      debugPrint('Error saving quiz progress: $e');
    }
  }

  Future<void> _handleQuizFinished() async {
    _stopwatch.stop();

    // 1. Save score and progress immediately
    await _saveQuizProgress();

    // 2. Play celebratory confetti
    _confettiController.play();

    // 3. Emit mascot celebration
    if (mounted) {
      final percentage =
          _questions.isNotEmpty ? (_score / _questions.length) * 100.0 : 0.0;
      final sumi = context.read<SumiProvider>();
      if (percentage >= 80) {
        sumi.emitEvent(SumiEvent.streakIncreased);
      } else if (percentage >= 50) {
        sumi.emitEvent(SumiEvent.answerCorrect);
      }

      setState(() {
        _state = QuizState.finished;
      });
    }
  }

  Future<void> _saveInProgressAndExit() async {
    await _saveQuizProgress();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Progress saved!'),
    ));
    _exitQuiz();
  }

  Future<void> _exitQuiz() async {
    if (!mounted) return;
    if (_quizId != null) {
      final folderId = await _localDbService.getParentFolderId(_quizId!);
      if (folderId != null && mounted) {
        context.go('/library/results-view/$folderId');
        return;
      }
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/library');
    }
  }

  void _shareResult() {
    final percentage =
        _questions.isNotEmpty ? (_score / _questions.length) * 100.0 : 0.0;
    final title = _titleController.text.isNotEmpty
        ? _titleController.text
        : (widget.quiz?.title ?? 'Quiz');
    final message =
        "🎉 I scored ${percentage.toStringAsFixed(0)}% ($_score/${_questions.length}) on '$title' using SumQuiz! 🚀\n\nLevel up your learning with AI quizzes: https://sumquiz.app";
    Share.share(message);
  }

  void _resetQuizState() {
    _stopwatch.reset();
    _stopwatch.start();
    _confettiController.stop();
    setState(() {
      _quizAttempt++;
      _state = QuizState.inProgress;
      _score = 0;
      _questionAnswers.clear();
      _showQuestionReview = true;
    });
  }

  void _retry() {
    _stopwatch.reset();
    _confettiController.stop();
    setState(() {
      _quizAttempt++;
      _state = QuizState.creation;
      _errorMessage = '';
      _questionAnswers.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: _state == QuizState.creation
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ExamCreationScreen()),
                );
              },
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              icon: const Icon(Icons.school_rounded),
              label: Text('Create Exam',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ).animate().scale(delay: 200.ms)
          : null,
      appBar: _state == QuizState.inProgress
          ? _buildMinimalAppBar(theme, colorScheme)
          : _state == QuizState.finished
              ? AppBar(
                  title: Text(
                    'Quiz Results',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      color: colorScheme.primary,
                      fontSize: 22,
                    ),
                  ),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  centerTitle: true,
                  leading: IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: theme.colorScheme.onSurface),
                    onPressed: _exitQuiz,
                  ),
                )
              : AppBar(
                  title: Text(
                    widget.quiz == null ? 'Create Quiz' : 'Quiz Playground',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      color: colorScheme.primary,
                      fontSize: 22,
                    ),
                  ),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: BackButton(color: theme.colorScheme.onSurface),
                ),
      body: _buildContent(theme),
    );
  }

  PreferredSizeWidget _buildMinimalAppBar(
      ThemeData theme, ColorScheme colorScheme) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF334155)),
        onPressed: _saveInProgressAndExit,
      ),
      title: Text(
        'Quiz',
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w700,
          color: const Color(0xFF0F172A),
          fontSize: 18,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_horiz_rounded, color: Color(0xFF64748B)),
          onPressed: () {
            // Options menu (save progress or export)
            _showQuizOptions();
          },
        ),
      ],
    );
  }

  void _showQuizOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.bookmark_add_outlined),
              title: const Text('Save Progress'),
              onTap: () {
                Navigator.pop(context);
                _saveInProgress();
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Export as PDF'),
              onTap: () {
                Navigator.pop(context);
                _exportPdf();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _exportPdf() {
    final user = context.read<UserModel?>();
    if (user != null && !user.isPro) {
      showDialog(
        context: context,
        builder: (context) => const UpgradeDialog(featureName: 'PDF Export'),
      );
      return;
    }

    if (_quizId == null) return;

    final quizToExport = LocalQuiz(
      id: _quizId!,
      userId: user?.uid ?? '',
      title: _titleController.text,
      questions: _questions,
      timestamp: DateTime.now(),
      scores: widget.quiz?.scores ?? [],
    );

    ExportService().exportPdf(context, quiz: quizToExport);
  }

  Widget _buildContent(ThemeData theme) {
    switch (_state) {
      case QuizState.loading:
        return _buildLoadingState(theme);
      case QuizState.error:
        return _buildErrorState(theme);
      case QuizState.inProgress:
        return _buildQuizInterface();
      case QuizState.finished:
        return _buildResultScreen(theme);
      default:
        return _buildCreationForm(theme);
    }
  }

  Widget _buildLoadingState(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              _loadingMessage,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Crafting high-quality quiz items for you...",
              style: GoogleFonts.inter(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ).animate().fadeIn(),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(24),
            border:
                Border.all(color: colorScheme.error.withValues(alpha: 0.15)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded,
                  color: colorScheme.error, size: 64),
              const SizedBox(height: 24),
              Text(
                'Verification Failed',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text('Try Again',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(),
    );
  }

  Widget _buildCreationForm(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final canGenerate =
        _titleController.text.isNotEmpty && _textController.text.isNotEmpty;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Generate Smart Quiz',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w900,
                  fontSize: 32,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ).animate().fadeIn().slideY(begin: -0.2),
              const SizedBox(height: 8),
              Text(
                'Turn any lecture, document, or text material into an interactive study evaluation instantly.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 15,
                  height: 1.5,
                ),
              ).animate().fadeIn(delay: 100.ms).slideY(begin: -0.2),
              const SizedBox(height: 36),

              // Title Field Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.05)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.01),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quiz Title',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _titleController,
                      style: GoogleFonts.inter(fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'e.g., Biology: Chapter 5 - Photosynthesis',
                        hintStyle: GoogleFonts.inter(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.35),
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: theme.scaffoldBackgroundColor
                            .withValues(alpha: 0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: theme.dividerColor.withValues(alpha: 0.1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: theme.dividerColor.withValues(alpha: 0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: colorScheme.primary, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 20),

              // Content Field Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.05)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.01),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Study Material / Syllabus Notes',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _textController,
                      maxLines: 8,
                      style: GoogleFonts.inter(fontSize: 14, height: 1.6),
                      decoration: InputDecoration(
                        hintText:
                            'Paste your study document, chapter summaries, lecture transcripts, or articles here. Sumi will formulate adaptive questions based on this text...',
                        hintStyle: GoogleFonts.inter(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.35),
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: theme.scaffoldBackgroundColor
                            .withValues(alpha: 0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: theme.dividerColor.withValues(alpha: 0.1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: theme.dividerColor.withValues(alpha: 0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: colorScheme.primary, width: 2),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 300.ms),

              const SizedBox(height: 32),

              // Generate Button
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: canGenerate ? _generateQuiz : null,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: Text(
                    'Generate Evaluation',
                    style: GoogleFonts.outfit(
                        fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    elevation: 0,
                    shadowColor: colorScheme.primary.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    disabledBackgroundColor:
                        theme.disabledColor.withValues(alpha: 0.12),
                    disabledForegroundColor: theme.disabledColor,
                  ),
                ),
              ).animate().fadeIn(delay: 400.ms).scale(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuizInterface() {
    return Column(
      children: [
        Expanded(
          child: QuizView(
            key: ValueKey('quiz_view_$_quizAttempt'),
            title: _titleController.text,
            questions: _questions,
            aiService: _aiService,
            showSaveButton: false,
            onFinish: _handleQuizFinished,
            onAnswer: (bool isCorrect, LocalQuizQuestion question,
                [String? userAnswer]) async {
              final sumi = context.read<SumiProvider>();
              final localDb = context.read<LocalDatabaseService>();
              final mastery = context.read<MasteryService>();
              final user = Provider.of<UserModel?>(context, listen: false);

              if (user != null && _quizId != null) {
                localDb.getQuiz(_quizId!).then((quiz) {
                  if (!mounted) return;
                  if (quiz != null && quiz.topicIds.isNotEmpty) {
                    for (final topicId in quiz.topicIds) {
                      mastery.processSignal(LearningSignal(
                        topicId: topicId,
                        timestamp: DateTime.now(),
                        type: isCorrect
                            ? SignalType.quizCorrect
                            : SignalType.quizWrong,
                        metadata: {'userId': user.uid, 'context': 'quiz'},
                      ));
                    }
                  }

                  if (quiz != null && !isCorrect) {
                    final tutor = context.read<SumiTutorService>();
                    tutor
                        .getSocraticHint(
                      topicName: quiz.topicNames.isNotEmpty
                          ? quiz.topicNames.first
                          : 'this topic',
                      question: question.question,
                      wrongAnswer: '',
                      sourceName: quiz.sourceName,
                    )
                        .then((hint) {
                      sumi.showTutorMessage(hint, state: SumiState.confused);

                      // Auto-clear hint after 5 seconds
                      Future.delayed(const Duration(seconds: 5), () {
                        if (mounted) sumi.clearDialogue();
                      });
                    });
                  } else {
                    sumi.clearDialogue();
                  }
                });
              }

              final qIndex = _questions.indexOf(question);
              if (qIndex >= 0) {
                _questionAnswers['$qIndex'] = {
                  'correct': isCorrect,
                  'question': question.question,
                  'userAnswer': userAnswer,
                  'correctAnswer': question.correctAnswer,
                  'explanation': question.explanation,
                };
              }

              if (isCorrect) {
                sumi.emitEvent(SumiEvent.answerCorrect);
                setState(() {
                  _score++;
                });
              } else {
                sumi.emitEvent(SumiEvent.answerWrong);
                // Linking: Quiz Failure -> SRS Demotion
                if (user != null && _relatedFlashcards.isNotEmpty) {
                  // 1. Try text-based matching
                  final matched = await _srsService.demoteFlashcardByText(
                    user.uid,
                    _relatedFlashcards,
                    question.question,
                  );

                  // 2. Fallback to random demotion if no match (user penalty)
                  if (!matched) {
                    await _srsService.demoteRandomFromList(
                        user.uid, _relatedFlashcards);
                  }
                }
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResultScreen(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final total = _questions.length;
    final percentage = total > 0 ? (_score / total) * 100 : 0.0;
    final timeSpent = _stopwatch.elapsed.inSeconds;
    final minutes = timeSpent ~/ 60;
    final seconds = timeSpent % 60;
    final timeFormatted = '${minutes}m ${seconds}s';

    // Determine performance level, color, icon, dialogue
    final String performanceTitle;
    final String performanceSubtitle;
    final Color performanceColor;
    final SumiState mascotState;
    final String mascotDialogue;

    if (percentage >= 90) {
      performanceTitle = 'Flawless Mastery! 🏆';
      performanceSubtitle =
          'Exceptional job! You thoroughly mastered this quiz material.';
      performanceColor = const Color(0xFF10B981);
      mascotState = SumiState.celebrating;
      mascotDialogue =
          "Incredible score! You're a true genius at this topic! 🎉";
    } else if (percentage >= 70) {
      performanceTitle = 'Great Job! 🎉';
      performanceSubtitle =
          'Strong understanding! Your study efforts are paying off.';
      performanceColor = const Color(0xFF3B82F6);
      mascotState = SumiState.celebrating;
      mascotDialogue =
          "Well done! Your neural pathways are sharper than ever! 🚀";
    } else if (percentage >= 50) {
      performanceTitle = 'Good Effort! 🌱';
      performanceSubtitle =
          'Solid start! A quick review of the tricky questions will get you to mastery.';
      performanceColor = const Color(0xFFF59E0B);
      mascotState = SumiState.idle;
      mascotDialogue =
          "Good progress! Review the answers below to lock in key concepts. 💡";
    } else {
      performanceTitle = 'Keep Practicing! 💪';
      performanceSubtitle =
          'Learning is an iterative journey. Review what you missed and try again!';
      performanceColor = const Color(0xFFEC4899);
      mascotState = SumiState.thinking;
      mascotDialogue =
          "Don't fret! Reviewing mistakes is where real learning happens. 🧠";
    }

    return Stack(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Sumi Mascot reaction
                  Center(
                    child: SumiMascot(
                      state: mascotState,
                      size: 150,
                      dialogue: mascotDialogue,
                      showBubble: true,
                    )
                        .animate()
                        .scale(duration: 600.ms, curve: Curves.elasticOut),
                  ),

                  const SizedBox(height: 24),

                  // Performance Title & Subtitle
                  Text(
                    performanceTitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w900,
                      fontSize: 28,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),

                  const SizedBox(height: 8),

                  Text(
                    performanceSubtitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),

                  const SizedBox(height: 28),

                  // Score Celebration Hero Card
                  Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          performanceColor.withValues(alpha: 0.12),
                          performanceColor.withValues(alpha: 0.04),
                          theme.cardColor,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: performanceColor.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: performanceColor.withValues(alpha: 0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Circular percentage badge
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.cardColor,
                            border: Border.all(
                              color: performanceColor,
                              width: 4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: performanceColor.withValues(alpha: 0.25),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${percentage.toStringAsFixed(0)}%',
                                  style: GoogleFonts.outfit(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                    color: performanceColor,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Accuracy',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                            .animate(delay: 350.ms)
                            .scale(duration: 500.ms, curve: Curves.easeOutBack),

                        const SizedBox(height: 20),

                        Text(
                          '$_score of $total Questions Correct',
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Metrics Pill Row
                        Row(
                          children: [
                            _buildStatItem(
                              theme,
                              label: 'Score',
                              value: '$_score / $total',
                              icon: Icons.check_circle_rounded,
                              color: performanceColor,
                            ),
                            const SizedBox(width: 12),
                            _buildStatItem(
                              theme,
                              label: 'Time Spent',
                              value: timeFormatted,
                              icon: Icons.timer_rounded,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 12),
                            _buildStatItem(
                              theme,
                              label: 'Status',
                              value: percentage >= 70 ? 'Passed' : 'Practice',
                              icon: Icons.stars_rounded,
                              color: Colors.purple,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.15),

                  const SizedBox(height: 28),

                  // Question Breakdown Section (Accordion)
                  Container(
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: theme.dividerColor.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Theme(
                      data: theme.copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        initiallyExpanded: _showQuestionReview,
                        onExpansionChanged: (val) {
                          setState(() => _showQuestionReview = val);
                        },
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.quiz_rounded,
                              color: colorScheme.primary, size: 22),
                        ),
                        title: Text(
                          'Review Answers & Explanations',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          '${_questions.length} questions reviewed',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                        childrenPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        children: [
                          ...List.generate(_questions.length, (index) {
                            final q = _questions[index];
                            final answerInfo = _questionAnswers['$index'];
                            final isCorrect = answerInfo?['correct'] == true;
                            final userAnswer =
                                answerInfo?['userAnswer'] as String?;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: theme.scaffoldBackgroundColor
                                    .withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isCorrect
                                      ? Colors.green.withValues(alpha: 0.25)
                                      : Colors.red.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: isCorrect
                                              ? Colors.green
                                                  .withValues(alpha: 0.15)
                                              : Colors.red
                                                  .withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isCorrect
                                              ? Icons.check_rounded
                                              : Icons.close_rounded,
                                          color: isCorrect
                                              ? Colors.green
                                              : Colors.red,
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Question ${index + 1}',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: isCorrect
                                                    ? Colors.green
                                                    : Colors.red,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              q.question,
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    theme.colorScheme.onSurface,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // User Answer
                                  if (userAnswer != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isCorrect
                                            ? Colors.green
                                                .withValues(alpha: 0.08)
                                            : Colors.red
                                                .withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isCorrect
                                                ? Icons.check_circle_outline
                                                : Icons.cancel_outlined,
                                            size: 16,
                                            color: isCorrect
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Your Answer: $userAnswer',
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                color: isCorrect
                                                    ? Colors.green.shade800
                                                    : Colors.red.shade800,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  // Correct Answer if user was wrong
                                  if (!isCorrect &&
                                      q.correctAnswer.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.green.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.check_circle_rounded,
                                              size: 16, color: Colors.green),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Correct Answer: ${q.correctAnswer}',
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                color: Colors.green.shade800,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  // Explanation if available
                                  if (q.explanation != null &&
                                      q.explanation!.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.blue.withValues(alpha: 0.06),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.blue
                                              .withValues(alpha: 0.2),
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(Icons.lightbulb_outline_rounded,
                                              color: Colors.blue.shade600,
                                              size: 16),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              q.explanation!,
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: theme
                                                    .colorScheme.onSurface
                                                    .withValues(alpha: 0.8),
                                                height: 1.4,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ).animate(delay: 500.ms).fadeIn(),

                  const SizedBox(height: 32),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 54,
                          child: OutlinedButton.icon(
                            onPressed: _resetQuizState,
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(
                              'Retry Quiz',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color:
                                    theme.dividerColor.withValues(alpha: 0.2),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: SizedBox(
                          height: 54,
                          child: ElevatedButton.icon(
                            onPressed: _exitQuiz,
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: Text(
                              'Save & Continue',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ).animate(delay: 600.ms).fadeIn().slideY(begin: 0.2),

                  const SizedBox(height: 12),

                  Center(
                    child: TextButton.icon(
                      onPressed: _shareResult,
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: Text(
                        'Share Score with Friends',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ).animate(delay: 650.ms).fadeIn(),
                ],
              ),
            ),
          ),
        ),

        // Celebration Confetti
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            numberOfParticles: 45,
            gravity: 0.15,
            colors: const [
              Colors.amber,
              Colors.blue,
              Colors.green,
              Colors.purple,
              Colors.pink,
              Colors.orange,
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(
    ThemeData theme, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.dividerColor.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
