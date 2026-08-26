import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/services/local_database_service.dart';

import 'package:sumquiz/models/local_summary.dart';
import 'package:sumquiz/models/local_quiz.dart';
import 'package:sumquiz/models/local_flashcard_set.dart';
import 'package:sumquiz/models/local_quiz_question.dart';
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
import 'package:sumquiz/utils/share_code_generator.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ResultsViewScreen extends StatefulWidget {
  final String folderId;
  final int initialTab;

  const ResultsViewScreen({
    super.key,
    required this.folderId,
    this.initialTab = 0,
  });

  @override
  State<ResultsViewScreen> createState() => _ResultsViewScreenState();
}

class _ResultsViewScreenState extends State<ResultsViewScreen> {
  int _selectedTab = 0;
  bool _isLoading = true;
  String? _errorMessage;

  LocalSummary? _summary;
  LocalQuiz? _quiz;
  LocalFlashcardSet? _flashcardSet;

  final List<String> _availableTabs = [];

  String get _currentTitle {
    if (_summary != null) return _summary!.title;
    if (_quiz != null) return _quiz!.title;
    if (_flashcardSet != null) return _flashcardSet!.title;
    return 'Knowledge Synthesis';
  }

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final db = context.read<LocalDatabaseService>();
      var targetFolderId = widget.folderId;

      final folder = await db.getFolder(targetFolderId);
      if (folder == null) {
        final parentId = await db.getParentFolderId(targetFolderId);
        if (parentId != null) targetFolderId = parentId;
      }

      var contents = await db.getFolderContents(targetFolderId);

      if (contents.isEmpty) {
        _summary = await db.getSummary(targetFolderId);
        _quiz = await db.getQuiz(targetFolderId);
        _flashcardSet = await db.getFlashcardSet(targetFolderId);
      } else {
      for (var content in contents) {
        if (content.contentType == 'summary') {
          _summary = await db.getSummary(content.contentId);
        } else if (content.contentType == 'quiz') {
          _quiz = await db.getQuiz(content.contentId);
        } else if (content.contentType == 'flashcardSet') {
          _flashcardSet = await db.getFlashcardSet(content.contentId);
        }
      }
      }

      _updateAvailableTabs();
      _applyInitialTab();
    } catch (e) {
      _errorMessage = 'Failed to synchronize results: $e';
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _updateAvailableTabs() {
    _availableTabs.clear();
    if (_summary != null) _availableTabs.add('Synthesis');
    if (_quiz != null) _availableTabs.add('Practice');
    if (_flashcardSet != null) _availableTabs.add('Flashcards');

    if (_selectedTab >= _availableTabs.length) {
      _selectedTab = 0;
    }
  }

  void _applyInitialTab() {
    if (_availableTabs.isEmpty) return;
    const tabNames = ['Synthesis', 'Practice', 'Flashcards'];
    final preferred = widget.initialTab.clamp(0, tabNames.length - 1);
    final idx = _availableTabs.indexOf(tabNames[preferred]);
    if (idx >= 0) _selectedTab = idx;
  }

  Future<void> _publishDeck() async {
    if (!mounted) return;
    final user = context.read<UserModel?>();
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to share synthesis')),
      );
      return;
    }

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
        summaryData: _summary != null
            ? {
                'content': _summary!.content,
                'tags': _summary!.tags,
              }
            : {},
        quizData: _quiz != null
            ? {
                'questions': _quiz!.questions.map((q) => q.toMap()).toList(),
              }
            : {},
        flashcardData: _flashcardSet != null
            ? {
                'flashcards':
                    _flashcardSet!.flashcards.map((f) => f.toMap()).toList(),
              }
            : {},
        noteData: {},
        publishedAt: DateTime.now(),
      );

      final publishedDeck = await FirestoreService().publishDeck(publicDeck);

      if (!mounted) return;

      final origin = kIsWeb ? Uri.base.origin : 'https://sumquiz.com';
      final shareLink =
          (publishedDeck.slug != null && publishedDeck.slug!.isNotEmpty)
              ? '$origin/s/${publishedDeck.slug}'
              : '$origin/deck?code=$shareCode';

      final String message =
          'Check out this synthesis I created on SumQuiz: "$_currentTitle". $shareLink';

      await SharePlus.instance.share(
        ShareParams(
          text: message,
          subject: 'SumQuiz Synthesis: $_currentTitle',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error sharing: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.go('/library'),
        ),
        title: Text(
          'Study Hub',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, size: 20),
            onPressed: _publishDeck,
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState(theme)
          : _errorMessage != null
              ? _buildErrorState(theme)
              : _buildMainContent(theme),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(Color(0xFF0D9488))),
          const SizedBox(height: 24),
          Text('Synchronizing Knowledge...',
              style: GoogleFonts.inter(color: theme.hintColor)),
        ],
      ).animate().fadeIn(),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(_errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: theme.hintColor)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => setState(() {
                _isLoading = true;
                _loadData();
              }),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(ThemeData theme) {
    return Column(
      children: [
        _buildTabSelector(theme),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: KeyedSubtree(
              key: ValueKey(_selectedTab),
              child: _buildSelectedTabView(theme),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabSelector(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
      ),
      child: Row(
        children: List.generate(_availableTabs.length, (index) {
          final isSelected = _selectedTab == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    _availableTabs[index],
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : theme.hintColor,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    ).animate().fadeIn().slideY(begin: -0.1, end: 0);
  }

  Widget _buildSelectedTabView(ThemeData theme) {
    if (_availableTabs.isEmpty) return const SizedBox.shrink();

    final selectedTabName = _availableTabs[_selectedTab];

    switch (selectedTabName) {
      case 'Synthesis':
        return _buildSummaryTab(theme);
      case 'Practice':
        return _buildQuizzesTab(theme);
      case 'Flashcards':
        return _buildFlashcardsTab(theme);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSummaryTab(ThemeData theme) {
    if (_summary == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SummaryView(
        title: _summary!.title,
        content: _summary!.content,
        tags: _summary!.tags,
        showActions: true,
        onCopy: () {
          Clipboard.setData(ClipboardData(text: _summary!.content));
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Synthesis copied!')));
        },
        onGenerateQuiz: _quiz == null
            ? () {
                // If quiz doesn't exist, navigate to creation
                context.push('/create-content', extra: {
                  'initialText': _summary!.content,
                  'initialTitle': _summary!.title,
                  'mode': 'quiz'
                });
              }
            : () => setState(
                () => _selectedTab = _availableTabs.indexOf('Practice')),
      ),
    );
  }

  Widget _buildQuizzesTab(ThemeData theme) {
    if (_quiz == null) return const SizedBox.shrink();

    return QuizView(
      title: _quiz!.title,
      questions: _quiz!.questions,
      onAnswer: (bool isCorrect, LocalQuizQuestion question) {},
      onFinish: () {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Practice complete!')));
      },
    );
  }

  Widget _buildFlashcardsTab(ThemeData theme) {
    if (_flashcardSet == null || _flashcardSet!.flashcards.isEmpty)
      return const SizedBox.shrink();

    final flashcards = _flashcardSet!.flashcards
        .map((f) => Flashcard(id: f.id, question: f.question, answer: f.answer))
        .toList();

    return FlashcardsView(
      title: _flashcardSet!.title,
      flashcards: flashcards,
      onReview: (int index, bool knewIt, {int? quality}) {},
      onFinish: () {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Review complete!')));
      },
    );
  }
}
