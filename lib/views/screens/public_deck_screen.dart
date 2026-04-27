import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:sumquiz/models/public_deck.dart';
import 'package:sumquiz/models/user_model.dart';
import 'package:sumquiz/services/firestore_service.dart';
import 'package:sumquiz/services/local_database_service.dart';
import 'package:sumquiz/models/local_summary.dart';
import 'package:sumquiz/models/local_quiz.dart';
import 'package:sumquiz/models/local_flashcard_set.dart';
import 'package:sumquiz/models/local_quiz_question.dart';
import 'package:sumquiz/models/local_flashcard.dart';
import 'package:uuid/uuid.dart';

class PublicDeckScreen extends StatefulWidget {
  final String? deckId;
  final String? slug;
  final String? code;

  const PublicDeckScreen({super.key, this.deckId, this.slug, this.code});

  @override
  State<PublicDeckScreen> createState() => _PublicDeckScreenState();
}

class _PublicDeckScreenState extends State<PublicDeckScreen> {
  bool _isLoading = true;
  PublicDeck? _deck;
  String? _error;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    if (widget.slug != null) {
      _fetchDeckBySlug();
    } else if (widget.deckId != null) {
      _fetchDeck();
    } else if (widget.code != null) {
      _fetchDeckByCode();
    }
  }

  Future<void> _fetchDeckByCode() async {
    try {
      final deck = await FirestoreService().fetchPublicDeckByCode(widget.code!);
      _handleDeckResponse(deck);
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> _fetchDeckBySlug() async {
    try {
      final deck = await FirestoreService().fetchPublicDeckBySlug(widget.slug!);
      _handleDeckResponse(deck);
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> _fetchDeck() async {
    try {
      final deck = await FirestoreService().fetchPublicDeck(widget.deckId!);
      _handleDeckResponse(deck);
    } catch (e) {
      _handleError(e);
    }
  }

  void _handleDeckResponse(PublicDeck? deck) {
    if (deck == null) {
      if (mounted) {
        setState(() {
          _error = 'Deck not found or has been removed.';
          _isLoading = false;
        });
      }
      return;
    }

    // Record View for Creator Bonus
    if (mounted) {
      final user = context.read<UserModel?>();
      if (user != null) {
        FirestoreService().recordDeckView(deck.id, user.uid);
      }
    }

    if (mounted) {
      setState(() {
        _deck = deck;
        _isLoading = false;
      });
    }
  }

  void _handleError(dynamic e) {
    debugPrint('Error fetching deck: $e');
    if (mounted) {
      setState(() {
        _error = 'Failed to load deck. Please check your connection.';
        _isLoading = false;
      });
    }
  }

  Future<void> _importDeck() async {
    if (_deck == null) return;

    final user = context.read<UserModel?>();
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to import this deck.')));
      
      // Save current location for post-login redirect
      final currentPath = GoRouterState.of(context).uri.toString();
      context.push('/auth?redirect=${Uri.encodeComponent(currentPath)}');
      return;
    }

    setState(() => _isImporting = true);

    try {
      final localDb = LocalDatabaseService();
      // Ensure DB initialized? Usually done in main. assume yes.

      // Check if deck with same publicDeckId already exists
      final existingFlashcardSets = await localDb.getAllFlashcardSets(user.uid);
      final existingQuiz = await localDb.getAllQuizzes(user.uid);
      final existingSummary = await localDb.getAllSummaries(user.uid);

      // Check for existing items with the same publicDeckId
      final existingFlashcardSet = existingFlashcardSets.firstWhere(
        (set) => set.publicDeckId == _deck!.id,
        orElse: () => LocalFlashcardSet.empty(),
      );

      final existingQuizItem = existingQuiz.firstWhere(
        (quiz) => quiz.publicDeckId == _deck!.id,
        orElse: () => LocalQuiz.empty(),
      );

      final existingSummaryItem = existingSummary.firstWhere(
        (summary) => summary.publicDeckId == _deck!.id,
        orElse: () => LocalSummary.empty(),
      );

      // Don't import if deck already exists (any component already exists)
      if (existingFlashcardSet.id.isNotEmpty ||
          existingQuizItem.id.isNotEmpty ||
          existingSummaryItem.id.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('This deck has already been imported.')));
          setState(() => _isImporting = false);
        }
        return;
      }

      // 1. Save Summary
      if (_deck!.summaryData.isNotEmpty) {
        final summary = LocalSummary(
          id: const Uuid().v4(),
          userId: user.uid,
          title: _deck!.title,
          content: _deck!.summaryData['content'] ?? '',
          tags: List<String>.from(_deck!.summaryData['tags'] ?? []),
          timestamp: DateTime.now(),
          isSynced: false,
          isReadOnly: true,
          publicDeckId: _deck!.id,
          creatorName: _deck!.creatorName,
        );
        await localDb.saveSummary(summary);
      }

      // 2. Save Quiz
      if (_deck!.quizData.isNotEmpty) {
        final questionsList = (_deck!.quizData['questions'] as List?) ?? [];
        final questions = questionsList
            .map((q) => LocalQuizQuestion(
                  question: q['question'] ?? '',
                  options: List<String>.from(q['options'] ?? []),
                  correctAnswer: q['correctAnswer'] ?? '',
                ))
            .toList();

        final quiz = LocalQuiz(
          id: const Uuid().v4(),
          userId: user.uid,
          title: _deck!.title, // Use deck title
          questions: questions,
          timestamp: DateTime.now(),
          isSynced: false,
          isReadOnly: true,
          publicDeckId: _deck!.id,
          creatorName: _deck!.creatorName,
        );
        await localDb.saveQuiz(quiz);
      }

      // 3. Save Flashcards
      if (_deck!.flashcardData.isNotEmpty) {
        final cardsList = (_deck!.flashcardData['flashcards'] as List?) ?? [];
        final cards = cardsList
            .map((c) => LocalFlashcard(
                  question: c['question'] ?? '',
                  answer: c['answer'] ?? '',
                ))
            .toList();

        final flashcards = LocalFlashcardSet(
          id: const Uuid().v4(),
          userId: user.uid,
          title: _deck!.title,
          flashcards: cards,
          timestamp: DateTime.now(),
          isSynced: false,
          isReadOnly: true,
          publicDeckId: _deck!.id,
          creatorName: _deck!.creatorName,
        );
        await localDb.saveFlashcardSet(flashcards);
      }

      // 4. Update Metrics
      await FirestoreService()
          .incrementDeckMetric(_deck!.id, 'startedCount');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Deck imported to Library!')));
        context.go('/library');
      }
    } catch (e) {
      debugPrint('Error importing deck: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error importing deck: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null || _deck == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text(_error ?? 'Deck not found')),
      );
    }

    return Title(
      title: '${_deck!.title} | SumQuiz',
      color: Colors.blue,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_deck!.title),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          ),
        ),
        extendBodyBehindAppBar: true,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.shade50,
                Colors.white,
                Colors.purple.shade50,
              ],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 800),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 32),
                      _buildContentOverview(),
                      const SizedBox(height: 48),
                      _buildImportSection(),
                      const SizedBox(height: 48),
                      _buildFooter(),
                    ],
                  ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _deck!.isExam ? 'PUBLIC EXAM' : 'STUDY DECK',
            style: const TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _deck!.title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Curated by ${_deck!.creatorName}',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontStyle: FontStyle.italic,
                color: Colors.grey[600],
              ),
          textAlign: TextAlign.center,
        ),
        if (_deck!.description.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            _deck!.description,
            style: TextStyle(color: Colors.grey[700], height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildContentOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What\'s inside',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildContentCard(
          Icons.summarize,
          'Comprehensive Summary',
          'Key concepts and detailed analysis distilled from the source material.',
          _deck!.summaryData.isNotEmpty,
        ),
        _buildContentCard(
          Icons.quiz,
          'Interactive Quiz',
          'Practice questions to test your understanding and reinforce learning.',
          _deck!.quizData.isNotEmpty,
        ),
        _buildContentCard(
          Icons.style,
          'Active Recall Flashcards',
          'Spaced repetition cards for efficient long-term memorization.',
          _deck!.flashcardData.isNotEmpty,
        ),
      ],
    );
  }

  Widget _buildImportSection() {
    final user = context.watch<UserModel?>();

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.auto_awesome, color: Colors.amber, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Ready to master this topic?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            user == null
                ? 'Join thousands of students using SumQuiz to accelerate their learning. Import this deck to your library for free.'
                : 'Add this curated content to your personal library to start practicing immediately.',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isImporting ? null : _importDeck,
              icon: _isImporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(user == null ? Icons.login : Icons.add_to_photos),
              label: Text(_isImporting
                  ? 'Importing...'
                  : (user == null ? 'Sign up to Import' : 'Add to My Library')),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(20),
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
          if (user == null) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.push('/auth'),
              child: const Text('Already have an account? Log in'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const Divider(),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Powered by '),
            Text(
              'SumQuiz AI',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[700]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContentCard(IconData icon, String title, String subtitle, bool exists) {
    if (!exists) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.blue),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
        ],
      ),
    );
  }
}
