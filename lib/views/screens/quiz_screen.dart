import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
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
  String? _quizId;
  List<LocalFlashcard> _relatedFlashcards = [];

  @override
  void initState() {
    super.initState();
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

  Future<void> _saveFinalScoreAndExit({bool navigateToResults = true}) async {
    final user = Provider.of<UserModel?>(context, listen: false);
    final quizViewModel = Provider.of<QuizViewModel>(context, listen: false);
    if (user == null || _quizId == null) return;

    final percentageScore =
        _questions.isNotEmpty ? (_score / _questions.length) * 100.0 : 0.0;

    _stopwatch.stop();
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
            answers: {}, // We can expand this in the future
            attemptedAt: DateTime.now(),
            timeTakenSeconds: currentSessionSeconds,
          ));
        }
      } catch (e) {
        debugPrint('Failed to increment progress or save attempt: $e');
      }

      // 🔔 Schedule notifications after quiz completion
      if (mounted) {
        try {
          // Use title as topic since LocalQuiz doesn't have tags
          final topic = _titleController.text.split(' ').first;
          final score = percentageScore / 100.0; // Convert to 0-1 range

          await NotificationIntegration.onQuizCompleted(
            context,
            topic,
            score,
          );
        } catch (e) {
          debugPrint('Failed to schedule notifications: $e');
        }
      }

      if (mounted) {
        if (navigateToResults) {
          context.push('/post-study-results', extra: {
            'score': _score,
            'totalQuestions': _questions.length,
            'timeSpentSeconds': currentSessionSeconds,
            'title': _titleController.text,
            'type': 'quiz',
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Final score saved!'),
          ));
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error saving final score: $e'),
        ));
      }
    }
  }

  void _resetQuizState() {
    _stopwatch.reset();
    _stopwatch.start();
    setState(() {
      _state = QuizState.inProgress;
      _score = 0;
    });
  }

  void _retry() {
    _stopwatch.reset();
    setState(() {
      _state = QuizState.creation;
      _errorMessage = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ExamCreationScreen()),
          );
        },
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        icon: const Icon(Icons.school_rounded),
        label: Text('Create Exam', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
      ).animate().scale(delay: 200.ms),
      appBar: AppBar(
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
        actions: [
          if (_state == QuizState.inProgress)
            IconButton(
              icon: const Icon(Icons.bookmark_add_outlined),
              onPressed: _saveInProgress,
              tooltip: 'Save Progress',
            ),
          if (_state != QuizState.creation && _state != QuizState.loading)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Export PDF',
              onPressed: () {
                final user = context.read<UserModel?>();
                if (user != null && !user.isPro) {
                  showDialog(
                    context: context,
                    builder: (context) =>
                        const UpgradeDialog(featureName: 'PDF Export'),
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
              },
            ),
        ],
        bottom: widget.quiz?.creatorName != null
            ? PreferredSize(
                preferredSize: const Size.fromHeight(40),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_outline_rounded,
                            size: 14,
                            color: colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Created by ${widget.quiz!.creatorName}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: _buildContent(theme),
    );
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
            border: Border.all(color: colorScheme.error.withValues(alpha: 0.15)),
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
                label: Text('Try Again', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
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
                  border: Border.all(color: theme.dividerColor.withValues(alpha: 0.05)),
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
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: theme.scaffoldBackgroundColor.withValues(alpha: 0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: colorScheme.primary, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                  border: Border.all(color: theme.dividerColor.withValues(alpha: 0.05)),
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
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: theme.scaffoldBackgroundColor.withValues(alpha: 0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: colorScheme.primary, width: 2),
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
                    style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    elevation: 0,
                    shadowColor: colorScheme.primary.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    disabledBackgroundColor: theme.disabledColor.withValues(alpha: 0.12),
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
        Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: Consumer<SumiProvider>(
            builder: (context, sumiProvider, child) {
              return SumiMascot(
                state: sumiProvider.currentState,
                size: 100,
                dialogue: sumiProvider.dialogue,
              );
            },
          ),
        ),
        Expanded(
          child: QuizView(
            title: _titleController.text,
            questions: _questions,
            aiService: _aiService,
            showSaveButton: false,
            onFinish: () => _saveFinalScoreAndExit(navigateToResults: true),
            onAnswer: (bool isCorrect, LocalQuizQuestion question) async {
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
                    tutor.getSocraticHint(
                      topicName: quiz.topicNames.isNotEmpty
                          ? quiz.topicNames.first
                          : 'this topic',
                      question: question.question,
                      wrongAnswer: '',
                      sourceName: quiz.sourceName,
                    ).then((hint) {
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
    final percentage =
        _questions.isNotEmpty ? (_score / _questions.length) * 100 : 0;

    // Determine performance level
    String performanceText;
    Color performanceColor;
    IconData performanceIcon;

    if (percentage >= 90) {
      performanceText = 'Outstanding!';
      performanceColor = Colors.green;
      performanceIcon = Icons.emoji_events_rounded;
    } else if (percentage >= 70) {
      performanceText = 'Great Job!';
      performanceColor = Colors.blue;
      performanceIcon = Icons.thumb_up_rounded;
    } else if (percentage >= 50) {
      performanceText = 'Good Effort!';
      performanceColor = Colors.orange;
      performanceIcon = Icons.star_rounded;
    } else {
      performanceText = 'Keep Trying!';
      performanceColor = Colors.grey;
      performanceIcon = Icons.sentiment_satisfied_rounded;
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: performanceColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  performanceIcon,
                  size: 80,
                  color: performanceColor,
                ),
              )
                  .animate()
                  .scale(duration: 600.ms, curve: Curves.elasticOut)
                  .then()
                  .shake(),

              const SizedBox(height: 32),

              // Performance Text
              Text(
                performanceText,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 24),

              // Score Display
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Column(
                  children: [
                    Text(
                      '${percentage.toStringAsFixed(0)}%',
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontSize: 72,
                        fontWeight: FontWeight.w800,
                        color: performanceColor,
                        height: 1,
                      ),
                    ).animate(delay: 300.ms).fadeIn().scale(),
                    const SizedBox(height: 16),
                    Text(
                      '$_score out of ${_questions.length} correct',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.2),

              const SizedBox(height: 40),

              // Action Buttons
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _saveFinalScoreAndExit,
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text(
                    'Save & Exit',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ).animate(delay: 500.ms).fadeIn().slideY(begin: 0.2),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _resetQuizState,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text(
                    'Retry Quiz',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: theme.dividerColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ).animate(delay: 600.ms).fadeIn().slideY(begin: 0.2),
            ],
          ),
        ),
      ),
    );
  }
}
