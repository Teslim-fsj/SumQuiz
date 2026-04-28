import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sumquiz/models/flashcard.dart';
import 'package:sumquiz/models/local_flashcard_set.dart';
import 'package:sumquiz/models/local_quiz.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/views/widgets/upgrade_dialog.dart';
import 'package:sumquiz/services/firestore_service.dart';
import 'package:sumquiz/models/public_deck.dart';
import 'package:sumquiz/utils/share_code_generator.dart';
import 'package:uuid/uuid.dart';
import 'package:sumquiz/services/spaced_repetition_service.dart';
import 'package:sumquiz/services/local_database_service.dart';
import 'package:sumquiz/services/auth_service.dart';
import 'package:sumquiz/services/progress_service.dart';
import 'package:sumquiz/models/local_summary.dart';
import 'package:sumquiz/views/widgets/web/web_summary_view.dart';
import 'package:sumquiz/views/widgets/web/web_quiz_view.dart';
import 'package:sumquiz/views/widgets/web/web_flashcards_view.dart';
import 'package:sumquiz/services/enhanced_ai_service.dart';
import 'package:sumquiz/theme/web_theme.dart';
import 'package:share_plus/share_plus.dart';

class ResultsViewScreenWeb extends StatefulWidget {
  final String folderId;
  final int initialTab;

  const ResultsViewScreenWeb({
    super.key,
    required this.folderId,
    this.initialTab = 0,
  });

  @override
  State<ResultsViewScreenWeb> createState() => _ResultsViewScreenWebState();
}

class _ResultsViewScreenWebState extends State<ResultsViewScreenWeb> {
  late int _selectedTab;
  bool _isLoading = true;
  String? _errorMessage;

  LocalSummary? _summary;
  LocalQuiz? _quiz;
  LocalFlashcardSet? _flashcardSet;

  // Study session tracking
  DateTime? _sessionStartTime;
  int _correctAnswers = 0;
  int _totalQuestionsAnswered = 0;
  int _knewCardsCount = 0;
  int _totalCardsReviewed = 0;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final db = context.read<LocalDatabaseService>();
      String targetFolderId = widget.folderId;

      final folder = await db.getFolder(targetFolderId);
      if (folder == null) {
        final parentId = await db.getParentFolderId(targetFolderId);
        if (parentId != null) {
          targetFolderId = parentId;
        }
      }

      final contents = await db.getFolderContents(targetFolderId);

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

      if (_selectedTab == 0 && _summary == null) {
        if (_quiz != null) {
          _selectedTab = 1;
        } else if (_flashcardSet != null) {
          _selectedTab = 2;
        }
      }
    } catch (e) {
      _errorMessage = 'Failed to load results: $e';
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _publishDeck() async {
    final user = context.read<UserModel?>();
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to share packs')),
      );
      return;
    }

    if (_summary == null || _quiz == null || _flashcardSet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wait for content to finish loading.')));
      return;
    }

    // Students and Teachers can now share decks regardless of Pro status
    // to allow for viral growth and student collaboration.

    try {
      final shareCode = ShareCodeGenerator.generate();
      final publicDeckId = const Uuid().v4();

      final publicDeck = PublicDeck(
        id: publicDeckId,
        creatorId: user.uid,
        creatorName: user.displayName,
        title: _summary?.title ??
            _quiz?.title ??
            _flashcardSet?.title ??
            'Study Pack',
        description: "Shared Study Pack",
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

      final origin = Uri.base.origin;
      final shareLink =
          (publishedDeck.slug != null && publishedDeck.slug!.isNotEmpty)
              ? '$origin/s/${publishedDeck.slug}'
              : '$origin/deck?code=$shareCode';

      final String message = user.role == UserRole.student
          ? 'I just finished "${publicDeck.title}" on SumQuiz! Can you beat my score? Check it out here: $shareLink'
          : 'Check out this study pack I created on SumQuiz: "${publicDeck.title}". Access it here: $shareLink';

      await Share.share(message, subject: 'SumQuiz: ${publicDeck.title}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error sharing: $e')));
      }
    }
  }

  void _saveToLibrary() {
    final user = context.read<UserModel?>();
    if (user != null && !user.isPro) {
      showDialog(
        context: context,
        builder: (context) => const UpgradeDialog(featureName: 'Sharing Decks'),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text('Content saved to your library!'),
          ],
        ),
        backgroundColor: WebColors.purplePrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        width: 400,
      ),
    );
    context.go('/library');
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(
            child: CircularProgressIndicator(color: WebColors.purplePrimary))
        : _errorMessage != null
            ? Center(child: _buildErrorState())
            : Column(
                children: [
                  _buildInlineHeader(),
                  Expanded(
                    child: _buildContentArea(),
                  ),
                ],
              );
  }

  Widget _buildInlineHeader() {
    final title =
        _summary?.title ?? _quiz?.title ?? _flashcardSet?.title ?? 'Study Pack';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
            bottom: BorderSide(color: WebColors.border.withOpacity(0.5))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row with actions
          Row(
            children: [
              // Back button
              IconButton(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/library'),
                icon: const Icon(Icons.arrow_back_rounded,
                    color: WebColors.textPrimary),
                tooltip: 'Back',
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: WebColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // AI Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: WebColors.backgroundAlt,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        size: 14, color: WebColors.purplePrimary),
                    const SizedBox(width: 8),
                    Text(
                      'AI GENERATED',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: WebColors.purplePrimary,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Share button
              Consumer<UserModel?>(builder: (context, user, _) {
                if (user == null) return const SizedBox.shrink();
                final isStudent = user.role == UserRole.student;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: IconButton(
                    onPressed: _publishDeck,
                    icon: Icon(
                      isStudent ? Icons.share_rounded : Icons.public,
                      color: WebColors.purplePrimary,
                      size: 24,
                    ),
                    tooltip: isStudent
                        ? 'Challenge Study Buddy'
                        : 'Publish to World',
                  ),
                );
              }),
              // Save button
              ElevatedButton.icon(
                onPressed: _saveToLibrary,
                icon: const Icon(Icons.bookmark_add_rounded, size: 18),
                label: Text('Save to Library',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WebColors.purplePrimary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tab pills
          Row(
            children: [
              _buildTabPill(0, 'Summary Notes', Icons.article_rounded),
              const SizedBox(width: 8),
              _buildTabPill(1, 'Practice Quiz', Icons.quiz_rounded),
              const SizedBox(width: 8),
              _buildTabPill(2, 'Flashcards', Icons.style_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabPill(int index, String label, IconData icon) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? WebColors.purplePrimary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? WebColors.purplePrimary.withOpacity(0.3)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 18,
                color: isSelected
                    ? WebColors.purplePrimary
                    : WebColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected
                    ? WebColors.purplePrimary
                    : WebColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main content
          Expanded(
            flex: 4,
            child: _buildSelectedTabView()
                .animate(key: ValueKey(_selectedTab))
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.05, end: 0, curve: Curves.easeOut),
          ),
          // AI Insights sidebar (only show if summary exists)
          if (_summary != null) ...[
            const SizedBox(width: 16),
            SizedBox(
              width: 240,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 16),
                child: _buildAiInsightsCard(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAiInsightsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4C3BCF), Color(0xFF6B5CE7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4C3BCF).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text(
                'AI Insights',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Key terms extracted for "${_summary?.title ?? "your content"}":',
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: Colors.white.withOpacity(0.8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: (_summary?.tags ?? ['Scanning content...'])
                .map((tag) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tag,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.1);
  }

  Widget _buildSelectedTabView() {
    switch (_selectedTab) {
      case 0:
        return _buildSummaryTab();
      case 1:
        return _buildQuizzesTab();
      case 2:
        return _buildFlashcardsTab();
      default:
        return _buildEmptyTab();
    }
  }

  Widget _buildSummaryTab() {
    if (_summary == null) return _buildEmptyTab();
    return WebSummaryView(
      title: _summary!.title,
      content: _summary!.content,
      tags: _summary!.tags,
      flashcardCount: _flashcardSet?.flashcards.length ?? 0,
      onReviewList: () => setState(() => _selectedTab = 2),
    );
  }

  Widget _buildQuizzesTab() {
    if (_quiz == null) return _buildEmptyTab();
    final aiService = context.read<EnhancedAIService>();
    return WebQuizView(
      title: _quiz!.title,
      subtitle: _summary?.title,
      questions: _quiz!.questions,
      summaryContent: _summary?.content,
      aiService: aiService,
      onAnswer: (isCorrect) {
        _totalQuestionsAnswered++;
        if (isCorrect) _correctAnswers++;
        final auth = context.read<AuthService>();
        if (auth.currentUser != null) {
          ProgressService()
              .logAccuracy(auth.currentUser!.uid, isCorrect ? 1.0 : 0.0);
        }
      },
      onShowSummary: () => setState(() => _selectedTab = 0),
      onFinish: () {
        _finalizeCurrentSession();
        _sessionStartTime = null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quiz completed! Progress saved.')),
        );
      },
    );
  }

  Widget _buildFlashcardsTab() {
    if (_flashcardSet == null) return _buildEmptyTab();
    final flashcards = _flashcardSet!.flashcards
        .map((f) => Flashcard(id: f.id, question: f.question, answer: f.answer))
        .toList();
    return WebFlashcardsView(
      title: _flashcardSet!.title,
      subtitle: _summary?.title,
      flashcards: flashcards,
      onReview: (index, knewIt) {
        _totalCardsReviewed++;
        if (knewIt) _knewCardsCount++;
        final auth = context.read<AuthService>();
        if (auth.currentUser != null) {
          final srs = SpacedRepetitionService(
              context.read<LocalDatabaseService>().getSpacedRepetitionBox());
          srs.updateFlashcardProgress(auth.currentUser!.uid, _flashcardSet!.id,
              flashcards[index].id, knewIt);
        }
      },
      onFinish: () {
        _finalizeCurrentSession();
        _sessionStartTime = null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Flashcard session complete!')),
        );
        setState(() {
          _selectedTab = 0;
          _sessionStartTime = null;
        });
      },
    );
  }

  void _finalizeCurrentSession() {
    if (_sessionStartTime == null) return;
    final durationSeconds =
        DateTime.now().difference(_sessionStartTime!).inSeconds;
    if (durationSeconds < 5) return;
    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    if (user == null) return;

    double accuracy = 0.0;
    if (_selectedTab == 1 && _totalQuestionsAnswered > 0) {
      accuracy = _correctAnswers / _totalQuestionsAnswered;
    } else if (_selectedTab == 2 && _totalCardsReviewed > 0) {
      accuracy = _knewCardsCount / _totalCardsReviewed;
    }

    ProgressService().logStudySession(
      userId: user.uid,
      accuracy: accuracy,
      durationSeconds: durationSeconds,
      setId: widget.folderId,
    );
  }

  Widget _buildErrorState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
        const SizedBox(height: 16),
        Text(_errorMessage!, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: () => context.go('/library'),
          child: const Text('Return to Library'),
        ),
      ],
    );
  }

  Widget _buildEmptyTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No content available',
              style: TextStyle(color: Colors.grey, fontSize: 18)),
        ],
      ),
    );
  }
}
