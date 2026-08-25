import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../../services/local_database_service.dart';
import '../../services/spaced_repetition_service.dart';
import '../../models/local_flashcard.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/sumi_mascot.dart';
import '../../models/sumi_emotion.dart';
import '../../services/mastery_service.dart';

class SpacedRepetitionScreen extends StatefulWidget {
  const SpacedRepetitionScreen({super.key});

  @override
  State<SpacedRepetitionScreen> createState() => _SpacedRepetitionScreenState();
}

class _SpacedRepetitionScreenState extends State<SpacedRepetitionScreen> {
  late SpacedRepetitionService _spacedRepetitionService;
  late MasteryService _masteryService;
  late LocalDatabaseService _dbService;
  late ConfettiController _confettiController;

  List<LocalFlashcard> _dueFlashcards = [];
  List<LocalFlashcard> _allFlashcards = [];
  final Map<String, List<String>> _flashcardToTopicIds = {};

  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isFlipping = false;
  String _message = '';

  final GlobalKey<FlipCardState> _flipCardKey = GlobalKey<FlipCardState>();

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 1));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoading) {
      _initializeAndLoad();
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  String? _getUserId() {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.currentUser?.uid != null) return auth.currentUser!.uid;
    final userModel = Provider.of<UserModel?>(context, listen: false);
    return userModel?.uid;
  }

  Future<void> _initializeAndLoad() async {
    _spacedRepetitionService =
        Provider.of<SpacedRepetitionService>(context, listen: false);
    _masteryService = Provider.of<MasteryService>(context, listen: false);
    _dbService = Provider.of<LocalDatabaseService>(context, listen: false);
    await _loadDueFlashcards();
  }

  Future<void> _loadDueFlashcards() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _message = '';
    });

    try {
      final uid = _getUserId();
      if (uid != null && uid.isNotEmpty) {
        final allFlashcardSets = await _dbService.getAllFlashcardSets(uid);

        // Build topic mapping
        _flashcardToTopicIds.clear();
        final List<LocalFlashcard> allLocalFlashcards = [];
        for (var set in allFlashcardSets) {
          for (var card in set.flashcards) {
            allLocalFlashcards.add(card);
            _flashcardToTopicIds[card.id] = set.topicIds;
          }
        }

        _allFlashcards = allLocalFlashcards;

        final flashcards = await _spacedRepetitionService.getDueFlashcards(
            uid, allLocalFlashcards);

        if (!mounted) return;

        setState(() {
          _dueFlashcards = flashcards;
          _isLoading = false;
          _currentIndex = 0;
          if (flashcards.isEmpty) {
            if (allLocalFlashcards.isEmpty) {
              _message = 'No flashcards found in your library yet.';
            } else {
              _message = 'All due cards reviewed! Great job keeping up.';
            }
          }
        });
      } else {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _message = 'Please log in to review your flashcards.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _message = 'An error occurred: $e';
      });
    }
  }

  void _startPracticeAll() {
    if (_allFlashcards.isEmpty) return;
    setState(() {
      _dueFlashcards = List.from(_allFlashcards)..shuffle();
      _currentIndex = 0;
      _isFlipping = false;
      _message = '';
    });
  }

  void _flipCard() {
    if (!_isFlipping) {
      _flipCardKey.currentState?.toggleCard();
      setState(() {
        _isFlipping = true;
      });
    }
  }

  Future<void> _processReview(int quality) async {
    if (_currentIndex >= _dueFlashcards.length) return;

    final flashcard = _dueFlashcards[_currentIndex];
    try {
      // 1. Update SRS Data
      await _spacedRepetitionService.updateReview(flashcard.id, quality >= 3,
          quality: quality);

      // 2. Emit Mastery Signals (Neural Link)
      if (!mounted) return;
      final uid = _getUserId();
      if (uid != null) {
        final topicIds = _flashcardToTopicIds[flashcard.id] ?? [];
        for (final topicId in topicIds) {
          await _masteryService.processSignal(LearningSignal(
            topicId: topicId,
            type: quality >= 3
                ? SignalType.flashcardSuccess
                : SignalType.flashcardFailure,
            magnitude: quality / 5.0,
            timestamp: DateTime.now(),
          ));
        }
      }

      _showStabilityGain(quality);

      if (_currentIndex < _dueFlashcards.length - 1) {
        Future.delayed(300.ms, () {
          if (mounted) {
            setState(() {
              _currentIndex++;
              _isFlipping = false;
            });
            _flipCardKey.currentState?.toggleCard();
          }
        });
      } else {
        setState(() {
          _message = 'Great job! Session complete!';
          _dueFlashcards.clear();
          _confettiController.play();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showStabilityGain(int quality) {
    String gainText = quality >= 4
        ? '+15% Stability'
        : (quality >= 3 ? '+5% Stability' : '-20% Stability');
    Color gainColor = quality >= 3 ? Colors.greenAccent : Colors.redAccent;

    // This would ideally be a floating animation over the card
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(gainText,
            style: TextStyle(color: gainColor, fontWeight: FontWeight.bold)),
        duration: 500.ms,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Review Session',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                fontSize: 20)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          Container(color: theme.scaffoldBackgroundColor),
          SafeArea(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                        color: theme.colorScheme.primary))
                : _dueFlashcards.isEmpty
                    ? _buildCompletionOrMessageView(theme)
                    : _buildFlashcardReview(theme),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [Colors.cyan, Colors.blue, Colors.indigo],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialCard(ThemeData theme,
      {required Widget child, Color? borderColor}) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: borderColor ?? theme.dividerColor.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildCompletionOrMessageView(ThemeData theme) {
    final hasAvailable = _allFlashcards.isNotEmpty;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SumiMascot(
              state: hasAvailable ? SumiState.celebrating : SumiState.curious,
              size: 110,
            ).animate().scale().fadeIn(),
            const SizedBox(height: 24),
            Text(
              _message,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
            const SizedBox(height: 12),
            Text(
              hasAvailable
                  ? 'You have ${_allFlashcards.length} total flashcards in your library.'
                  : 'Add study notes or upload materials to start active recall.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            if (hasAvailable) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _startPracticeAll,
                  icon: const Icon(Icons.bolt_rounded),
                  label: Text('Practice All Cards (${_allFlashcards.length})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    textStyle: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 12),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.go('/create-content');
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create Study Pack'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    textStyle: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(
                      color: theme.dividerColor.withValues(alpha: 0.2)),
                ),
                child: Text('Return Home',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ).animate().fadeIn(delay: 400.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildFlashcardReview(ThemeData theme) {
    if (_currentIndex >= _dueFlashcards.length) {
      return _buildCompletionOrMessageView(theme);
    }

    final flashcard = _dueFlashcards[_currentIndex];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          _buildHeader(theme),
          const SizedBox(height: 32),
          Expanded(
            child: FlipCard(
              key: _flipCardKey,
              flipOnTouch: false,
              front:
                  _buildCardSide('QUESTION', flashcard.question, true, theme),
              back: _buildCardSide('REVEALED', flashcard.answer, false, theme),
            ),
          ),
          const SizedBox(height: 32),
          _buildActionArea(theme),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              Animate(
                effects: [
                  ScaleEffect(
                    begin: const Offset(0, 1),
                    end: const Offset(1, 1),
                    alignment: Alignment.centerLeft,
                    duration: 500.ms,
                  ),
                ],
                child: Container(
                  height: 12,
                  width: MediaQuery.of(context).size.width *
                      ((_currentIndex + 1) / _dueFlashcards.length),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.secondary
                      ],
                    ),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Text('${_currentIndex + 1}/${_dueFlashcards.length}',
            style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
      ],
    );
  }

  Widget _buildActionArea(ThemeData theme) {
    return SizedBox(
      height: 140,
      child: _isFlipping
          ? _buildQualitySelector(theme).animate().fadeIn().slideY(begin: 0.2)
          : _buildShowAnswerButton(theme).animate().fadeIn().scale(),
    );
  }

  Widget _buildCardSide(
      String label, String content, bool isQuestion, ThemeData theme) {
    return _buildMaterialCard(
      theme,
      borderColor:
          isQuestion ? null : theme.colorScheme.primary.withValues(alpha: 0.3),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        padding: const EdgeInsets.all(40.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label,
                    style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2)),
                Icon(isQuestion ? Icons.help_outline : Icons.auto_awesome,
                    color: theme.colorScheme.primary.withValues(alpha: 0.5)),
              ],
            ),
            const Spacer(),
            SingleChildScrollView(
              child: Text(content,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(height: 1.4, fontWeight: FontWeight.w600)),
            ),
            const Spacer(),
            if (isQuestion)
              Text('TAP TO FLIP',
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                      letterSpacing: 1)),
          ],
        ),
      ),
    );
  }

  Widget _buildShowAnswerButton(ThemeData theme) {
    return Center(
      child: GestureDetector(
        onTap: _flipCard,
        child: _buildMaterialCard(
          theme,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.visibility_rounded),
                const SizedBox(width: 12),
                Text('REVEAL ANSWER',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQualitySelector(ThemeData theme) {
    return Column(
      children: [
        Text('How well did you know this?',
            style: theme.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildQualityBtn('Blackout', Colors.grey, 0, theme),
            _buildQualityBtn('Hard', Colors.orange, 2, theme),
            _buildQualityBtn('Good', Colors.blue, 4, theme),
            _buildQualityBtn('Easy', Colors.green, 5, theme),
          ],
        ),
      ],
    );
  }

  Widget _buildQualityBtn(String label, Color color, int val, ThemeData theme) {
    return Column(
      children: [
        IconButton.filled(
          onPressed: () => _processReview(val),
          icon: Icon(_getIconForQuality(val)),
          style: IconButton.styleFrom(
            backgroundColor: color.withValues(alpha: 0.1),
            foregroundColor: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.labelSmall?.copyWith(fontSize: 10)),
      ],
    );
  }

  IconData _getIconForQuality(int q) {
    if (q == 0) return Icons.sentiment_very_dissatisfied;
    if (q == 2) return Icons.sentiment_dissatisfied;
    if (q == 4) return Icons.sentiment_satisfied;
    return Icons.sentiment_very_satisfied;
  }
}
