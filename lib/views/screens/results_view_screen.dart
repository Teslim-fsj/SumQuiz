import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/services/local_database_service.dart';

import 'package:sumquiz/services/export_service.dart';
import 'package:sumquiz/models/local_summary.dart';
import 'package:sumquiz/models/local_quiz.dart';
import 'package:sumquiz/models/local_flashcard_set.dart';
import 'package:sumquiz/models/local_quiz_question.dart';
import 'package:sumquiz/models/local_flashcard.dart';
import 'package:sumquiz/views/widgets/upgrade_dialog.dart';
import 'package:flutter/services.dart';
import 'package:sumquiz/models/flashcard.dart';
import 'package:sumquiz/views/widgets/summary_view.dart';
import 'package:sumquiz/views/widgets/quiz_view.dart';
import 'package:sumquiz/views/widgets/flashcards_view.dart';
import 'package:go_router/go_router.dart';
import 'package:sumquiz/models/public_deck.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/firestore_service.dart';
import 'package:uuid/uuid.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sumquiz/views/widgets/share_deck_dialog.dart';
import 'package:sumquiz/utils/share_code_generator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ResultsViewScreen extends StatefulWidget {
  final String folderId;

  const ResultsViewScreen({super.key, required this.folderId});

  @override
  State<ResultsViewScreen> createState() => _ResultsViewScreenState();
}

class _ResultsViewScreenState extends State<ResultsViewScreen> {
  int _selectedTab = 0;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isSaved = false; // Track save status
  bool _isPublishing = false;

  LocalSummary? _summary;
  LocalQuiz? _quiz;
  LocalFlashcardSet? _flashcardSet;

  final List<String> _availableTabs = [];

  String get _currentTitle {
    if (_summary != null) return _summary!.title;
    if (_quiz != null) return _quiz!.title;
    if (_flashcardSet != null) return _flashcardSet!.title;
    return 'Untitled Result';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final db = context.read<LocalDatabaseService>();

      // Load folder to check if it's already saved
      final folder = await db.getFolder(widget.folderId);
      if (folder != null) {
        _isSaved = folder.isSaved;
      }

      final contents = await db.getFolderContents(widget.folderId);

      for (var content in contents) {
        if (content.contentType == 'summary') {
          _summary = await db.getSummary(content.contentId);
        } else if (content.contentType == 'quiz') {
          _quiz = await db.getQuiz(content.contentId);
        } else if (content.contentType == 'flashcardSet') {
          _flashcardSet = await db.getFlashcardSet(content.contentId);
        }
      }

      _updateAvailableTabs();
    } catch (e) {
      _errorMessage = 'Failed to load results: $e';
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _exportContent(BuildContext context, UserModel user,
      {bool exportAll = false,
      bool summary = false,
      bool quiz = false,
      bool flashcards = false}) {
    if (!user.isPro) {
      showDialog(
        context: context,
        builder: (context) => const UpgradeDialog(featureName: 'PDF Export'),
      );
      return;
    }

    if (_summary == null && _quiz == null && _flashcardSet == null) return;

    // Construct temp local models
    LocalSummary? localSummary;
    if ((exportAll || summary) && _summary != null) {
      localSummary = LocalSummary(
          id: 'temp',
          title: _summary!.title,
          content: _summary!.content,
          tags: [],
          timestamp: DateTime.now(),
          userId: user.uid,
          isSynced: false);
    }

    LocalQuiz? localQuiz;
    if ((exportAll || quiz) && _quiz != null) {
      localQuiz = LocalQuiz(
          id: 'temp',
          title: _summary!.title,
          questions: _quiz!.questions
              .map((q) => LocalQuizQuestion(
                  question: q.question,
                  options: q.options,
                  correctAnswer: q.correctAnswer))
              .toList(),
          timestamp: DateTime.now(),
          userId: user.uid,
          isSynced: false);
    }

    LocalFlashcardSet? localFlash;
    if ((exportAll || flashcards) && _flashcardSet != null) {
      localFlash = LocalFlashcardSet(
          id: 'temp',
          title: _summary!.title,
          flashcards: _flashcardSet!.flashcards
              .map(
                  (f) => LocalFlashcard(question: f.question, answer: f.answer))
              .toList(),
          timestamp: DateTime.now(),
          userId: user.uid,
          isSynced: false);
    }

    ExportService().exportPdf(context,
        summary: localSummary, quiz: localQuiz, flashcardSet: localFlash);
  }

  void _updateAvailableTabs() {
    _availableTabs.clear();
    if (_summary != null) _availableTabs.add('Summary');
    if (_quiz != null) _availableTabs.add('Quizzes');
    if (_flashcardSet != null) _availableTabs.add('Flashcards');

    if (_selectedTab >= _availableTabs.length) {
      _selectedTab = 0;
    }
  }

  Future<void> _publishDeck() async {
    if (!mounted) return;
    final user = context.read<UserModel?>();
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to share decks')),
      );
      return;
    }

    if (_summary == null || _quiz == null || _flashcardSet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wait for content to finish loading.')));
      return;
    }

    setState(() => _isPublishing = true);

    // Removed Pro check to allow viral growth

    try {
      final shareCode = ShareCodeGenerator.generate();
      final publicDeckId = const Uuid().v4();

      final publicDeck = PublicDeck(
        id: publicDeckId,
        creatorId: user.uid,
        creatorName: user.displayName,
        title: _currentTitle,
        description: "Generated from $_currentTitle",
        shareCode: shareCode,
        summaryData: {
          'content': _summary!.content,
          'tags': _summary!.tags,
        },
        quizData: {
          'questions': _quiz!.questions.map((q) => q.toMap()).toList(),
        },
        flashcardData: {
          'flashcards':
              _flashcardSet!.flashcards.map((f) => f.toMap()).toList(),
        },
        publishedAt: DateTime.now(),
      );

      final publishedDeck = await FirestoreService().publishDeck(publicDeck);

      if (!mounted) return;

      final origin = kIsWeb ? Uri.base.origin : 'https://sumquiz.xyz';
      final shareLink = (publishedDeck.slug != null && publishedDeck.slug!.isNotEmpty)
          ? '$origin/s/${publishedDeck.slug}'
          : '$origin/deck?code=$shareCode';

      final String message = user.role == UserRole.student
          ? '🔥 I challenge you! I just finished "${_currentTitle}" on SumQuiz. Can you beat my knowledge score? Try it here: $shareLink #SumQuiz #StudyHard'
          : 'Check out this study pack I created on SumQuiz: "${_currentTitle}". It will save you hours of reading! Access it here: $shareLink';

      await Share.share(message, subject: 'SumQuiz: $_currentTitle');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error publishing: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
    }
  }

  Future<void> _saveToLibrary() async {
    try {
      final db = context.read<LocalDatabaseService>();
      final folder = await db.getFolder(widget.folderId);

      if (folder != null) {
        // Mark the folder as saved
        folder.isSaved = true;
        await db.saveFolder(folder);

        if (mounted) {
          setState(() => _isSaved = true);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Content saved to your library!'),
              backgroundColor: Theme.of(context).colorScheme.secondary,
              action: SnackBarAction(
                label: 'View Library',
                textColor: Colors.white,
                onPressed: () => context.go('/library'),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.onSurface),
          onPressed: () => context.go('/'),
        ),
        title: Text(
          'Results',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          Consumer<UserModel?>(builder: (context, user, _) {
            if (user != null) {
              return IconButton(
                icon: Icon(Icons.download_rounded,
                    color: theme.colorScheme.primary),
                tooltip: 'Export PDF',
                onPressed: () => _exportContent(context, user, exportAll: true),
              );
            }
            return const SizedBox.shrink();
          }),
          Consumer<UserModel?>(builder: (context, user, _) {
            if (user != null) {
              final isStudent = user.role == UserRole.student;
              return IconButton(
                icon: Icon(
                  isStudent ? Icons.share_rounded : Icons.public,
                  color: theme.colorScheme.primary,
                ),
                tooltip: isStudent ? 'Challenge Study Buddy' : 'Publish Deck',
                onPressed: _publishDeck,
              );
            }
            return const SizedBox.shrink();
          }),
          // Show different icon based on save status
          IconButton(
            icon: Icon(
              _isSaved
                  ? Icons.library_add_check
                  : Icons.library_add_check_outlined,
              color: _isSaved ? Colors.green : theme.colorScheme.primary,
            ),
            tooltip: _isSaved ? 'Saved to Library' : 'Save to Library',
            onPressed: _isSaved ? null : _saveToLibrary,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Animated Background
          Animate(
            onPlay: (controller) => controller.repeat(reverse: true),
            effects: [
              CustomEffect(
                duration: 10.seconds,
                builder: (context, value, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                theme.colorScheme.surface,
                                Color.lerp(theme.colorScheme.surface,
                                    theme.colorScheme.primaryContainer, value)!,
                              ]
                            : [
                                const Color(0xFFE0F7FA),
                                Color.lerp(const Color(0xFFE0F7FA),
                                    const Color(0xFFB2EBF2), value)!,
                              ],
                      ),
                    ),
                    child: child,
                  );
                },
              )
            ],
            child: Container(),
          ),
          SafeArea(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                        color: theme.colorScheme.primary))
                    : _errorMessage != null
                    ? Center(
                        child: Text(_errorMessage!,
                            style: theme.textTheme.bodyLarge
                                ?.copyWith(color: theme.colorScheme.error)))
                    : Column(
                        children: [
                          _buildOutputSelector(theme)
                              .animate()
                              .fadeIn()
                              .slideY(begin: -0.2),
                          Expanded(
                              child: _buildSelectedTabView(theme)
                                  .animate()
                                  .fadeIn(delay: 200.ms)),
                          _buildSharingCTA(theme, isDark),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutputSelector(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 48,
      decoration: BoxDecoration(
        color: theme.cardColor.withOpacity(0.8),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: List.generate(_availableTabs.length, (index) {
          final isSelected = _selectedTab == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = index),
              child: AnimatedContainer(
                duration: 200.ms,
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Text(
                    _availableTabs[index],
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSelectedTabView(ThemeData theme) {
    if (_availableTabs.isEmpty) return const SizedBox.shrink();

    final selectedTabName = _availableTabs[_selectedTab];

    switch (selectedTabName) {
      case 'Summary':
        return _buildSummaryTab(theme);
      case 'Quizzes':
        return _buildQuizzesTab(theme);
      case 'Flashcards':
        return _buildFlashcardsTab(theme);
      default:
        return Container();
    }
  }

  Widget _buildSummaryTab(ThemeData theme) {
    if (_summary == null) {
      return Center(
          child:
              Text('No summary available.', style: theme.textTheme.bodyMedium));
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SummaryView(
        title: _summary!.title,
        content: _summary!.content,
        tags: _summary!.tags,
        showActions: true,
        onCopy: () {
          Clipboard.setData(ClipboardData(text: _summary!.content));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Summary copied to clipboard')),
            );
          }
        },
      ),
    );
  }

  Widget _buildQuizzesTab(ThemeData theme) {
    if (_quiz == null) {
      return Center(
          child: Text('No quiz available.', style: theme.textTheme.bodyMedium));
    }

    return QuizView(
      title: _quiz!.title,
      questions: _quiz!.questions,
      onAnswer: (bool isCorrect, LocalQuizQuestion question) {},
      onFinish: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Quiz practice finished!')),
          );
        }
      },
    );
  }

  Widget _buildFlashcardsTab(ThemeData theme) {
    if (_flashcardSet == null || _flashcardSet!.flashcards.isEmpty) {
      return Center(
          child: Text('No flashcards available.',
              style: theme.textTheme.bodyMedium));
    }

    final flashcards = _flashcardSet!.flashcards
        .map((f) => Flashcard(
              id: f.id,
              question: f.question,
              answer: f.answer,
            ))
        .toList();

    return FlashcardsView(
      title: _flashcardSet!.title,
      flashcards: flashcards,
      onReview: (int index, bool knewIt, {int? quality}) {},
      onFinish: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Flashcard review finished!')),
          );
        }
      },
    );
  }

  Widget _buildSharingCTA(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor.withOpacity(0.9),
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _isPublishing ? null : _publishDeck,
                icon: _isPublishing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.share_rounded, size: 24),
                label: Text(
                  _isPublishing ? 'PUBLISHING...' : 'CHALLENGE A STUDY BUDDY',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  elevation: 8,
                  shadowColor: theme.colorScheme.primary.withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share this study pack and track who beats your score!',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    ).animate().slideY(begin: 1.0, curve: Curves.easeOutQuad, duration: 600.ms);
  }
}
