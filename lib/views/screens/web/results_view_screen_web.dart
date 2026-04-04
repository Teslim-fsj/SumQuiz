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

      // Check if the provided ID is a folder or a content ID
      final folder = await db.getFolder(targetFolderId);
      if (folder == null) {
        // Not a direct folder, check if it's a content item
        final parentId = await db.getParentFolderId(targetFolderId);
        if (parentId != null) {
          targetFolderId = parentId;
        }
      }

      final contents = await db.getFolderContents(targetFolderId);

      // If still no contents, try to load as standalone content
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

      // Final tab selection safety check
      if (_selectedTab == 0 && _summary == null) {
        if (_quiz != null) _selectedTab = 1;
        else if (_flashcardSet != null) _selectedTab = 2;
      }
    } catch (e) {
      _errorMessage = 'Failed to load results: $e';
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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

    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            const Text('Content saved to your library!'),
          ],
        ),
        backgroundColor: theme.colorScheme.secondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        width: 400,
      ),
    );
    context.go('/library');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: _isLoading
            ? Center(
                child:
                    CircularProgressIndicator(color: theme.colorScheme.primary))
            : _errorMessage != null
                ? Center(child: _buildErrorState())
                : Column(
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSidebar(),
                              const SizedBox(width: 32),
                              Expanded(child: _buildContentArea()),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
        const SizedBox(height: 16),
        Text(
          _errorMessage!,
          style: TextStyle(fontSize: 18, color: theme.colorScheme.onSurface),
        ),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: () => context.go('/library'),
          child: const Text('Return to Library'),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(bottom: BorderSide(color: WebColors.border.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          // Logo
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: WebColors.PremiumGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Text(
                'SumQuiz',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : WebColors.primary,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          
          const Spacer(),

          // Navigation Links (Placeholder)
          _buildTopNavLink('Home'),
          _buildTopNavLink('Library'),
          _buildTopNavLink('Stats'),

          const Spacer(),

          // AI Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: WebColors.backgroundAlt,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, size: 14, color: WebColors.primary),
                const SizedBox(width: 8),
                Text(
                  'AI GENERATED',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: WebColors.primary,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 24),
          
          // Theme Toggle (Icon only for now)
              IconButton(
                icon: const Icon(Icons.dark_mode_outlined, size: 20),
                onPressed: () {
                  // TODO: Toggle app-wide theme via provider
                },
                color: WebColors.textPrimary,
              ),

          const SizedBox(width: 12),

          // Save to Library Button
          Container(
            height: 48,
            decoration: BoxDecoration(
              gradient: WebColors.PremiumGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: WebColors.subtleShadow,
            ),
            child: ElevatedButton.icon(
              onPressed: _saveToLibrary,
              icon: const Icon(Icons.bookmark_add_rounded, color: Colors.white, size: 18),
              label: Text(
                'Save to Library',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          
          const SizedBox(width: 16),

          // Profile
          CircleAvatar(
            radius: 20,
            backgroundColor: WebColors.backgroundAlt,
            child: const Icon(Icons.person_rounded, color: WebColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildTopNavLink(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: WebColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    final theme = Theme.of(context);
    return Container(
      width: 320,
      padding: const EdgeInsets.fromLTRB(0, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Navigation Group
          _buildSidebarItem(0, 'Summary Notes', Icons.article_rounded),
          const SizedBox(height: 8),
          _buildSidebarItem(1, 'Practice Quiz', Icons.quiz_rounded),
          const SizedBox(height: 8),
          _buildSidebarItem(2, 'Flashcards Deck', Icons.style_rounded, showCheck: true),

          const Spacer(),

          // AI Insights Card (New)
          _buildAiInsightsCard(),

          const SizedBox(height: 48),

          // Settings / Support (New)
          _buildSecondaryMenuItem('SETTINGS', Icons.settings_rounded),
          const SizedBox(height: 12),
          _buildSecondaryMenuItem('SUPPORT', Icons.help_outline_rounded),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index, String label, IconData icon, {bool showCheck = false}) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? WebColors.primary.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? WebColors.primary : WebColors.textSecondary,
              size: 22,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? WebColors.primary : WebColors.textSecondary,
                ),
              ),
            ),
            if (showCheck && isSelected)
              const Icon(Icons.check_circle_rounded, color: WebColors.primary, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildAiInsightsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: WebColors.PremiumGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: WebColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text(
                'AI Flashcard Insights',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Key terms extracted for ${_summary?.title ?? "your content"}:',
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: (_summary?.tags ?? ['Scanning content...'])
                .map((tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
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
    );
  }

  Widget _buildSecondaryMenuItem(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: WebColors.textSecondary, size: 18),
        const SizedBox(width: 12),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: WebColors.textSecondary,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildContentArea() {
    return _buildSelectedTabView()
        .animate(key: ValueKey(_selectedTab))
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.05, end: 0, curve: Curves.easeOut);
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
      subtitle: _summary?.title, // Use summary title as subtitle
      questions: _quiz!.questions,
      summaryContent: _summary?.content,
      aiService: aiService,
      onAnswer: (isCorrect) {
        _totalQuestionsAnswered++;
        if (isCorrect) _correctAnswers++;
        
        final auth = context.read<AuthService>();
        if (auth.currentUser != null) {
          ProgressService().logAccuracy(auth.currentUser!.uid, isCorrect ? 1.0 : 0.0);
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
        .map((f) => Flashcard(
              id: f.id,
              question: f.question,
              answer: f.answer,
            ))
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
          final srs = SpacedRepetitionService(context
              .read<LocalDatabaseService>()
              .getSpacedRepetitionBox());
          srs.updateFlashcardProgress(auth.currentUser!.uid,
              _flashcardSet!.id, flashcards[index].id, knewIt);
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
    if (durationSeconds < 5) return; // Ignore very short sessions

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
