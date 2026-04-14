import 'dart:async';
// Screen goal: User should go through cards rapidly with minimal animation delay and no wasted space. Focus on repetition speed, not visual effects.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flip_card/flip_card.dart';
import 'package:sumquiz/theme/web_theme.dart';
import 'package:sumquiz/models/flashcard.dart';

class WebFlashcardsView extends StatefulWidget {
  final String title;
  final String? subtitle;
  final List<Flashcard> flashcards;
  final Function(int index, bool knewIt)? onReview;
  final VoidCallback? onFinish;

  const WebFlashcardsView({
    super.key,
    required this.title,
    this.subtitle,
    required this.flashcards,
    this.onReview,
    this.onFinish,
  });

  @override
  State<WebFlashcardsView> createState() => _WebFlashcardsViewState();
}

class _WebFlashcardsViewState extends State<WebFlashcardsView> {
  int _currentIndex = 0;
  bool _isFlipped = false;
  final GlobalKey<FlipCardState> _cardKey = GlobalKey<FlipCardState>();
  int _knewCount = 0;
  final Stopwatch _stopwatch = Stopwatch();
  late Timer _timer;
  String _timeString = '00:00';

  @override
  void initState() {
    super.initState();
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _timeString = _formatDuration(_stopwatch.elapsed);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  void _handleReview(bool knewIt) {
    if (knewIt) {
      _knewCount++;
    } else {
    }
    
    widget.onReview?.call(_currentIndex, knewIt);
    
    if (_currentIndex < widget.flashcards.length - 1) {
      if (_isFlipped) {
        _cardKey.currentState?.toggleCard();
      }
      setState(() {
        _currentIndex++;
        _isFlipped = false;
      });
    } else {
      widget.onFinish?.call();
    }
  }

  void _nextCard() {
    if (_currentIndex < widget.flashcards.length - 1) {
      if (_isFlipped) {
        _cardKey.currentState?.toggleCard();
      }
      setState(() {
        _currentIndex++;
        _isFlipped = false;
      });
    } else {
      widget.onFinish?.call();
    }
  }

  void _prevCard() {
    if (_currentIndex > 0) {
      if (_isFlipped) {
        _cardKey.currentState?.toggleCard();
      }
      setState(() {
        _currentIndex--;
        _isFlipped = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentCard = widget.flashcards[_currentIndex];
    final progress = (_currentIndex + 1) / widget.flashcards.length;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Flashcards Deck',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: WebColors.textPrimary,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle?.toUpperCase() ?? 'KNOWLEDGE RETENTION',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: WebColors.primary.withOpacity(0.6),
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Card ${_currentIndex + 1} of ${widget.flashcards.length}',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: WebColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 200,
                    height: 4,
                    decoration: BoxDecoration(
                      color: WebColors.border.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(
                        decoration: BoxDecoration(
                          color: WebColors.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Main Content Area with Flip Card
          Expanded(
            child: Row(
              children: [
                IconButton(
                  onPressed: _currentIndex > 0 ? _prevCard : null,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: BorderSide(color: WebColors.border),
                    padding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: FlipCard(
                    key: _cardKey,
                    onFlip: () => setState(() => _isFlipped = !_isFlipped),
                    front: _buildCardSide(currentCard.question, 'QUESTION', true),
                    back: _buildCardSide(currentCard.answer, 'ANSWER', false),
                  ),
                ),
                const SizedBox(width: 20),
                IconButton(
                  onPressed: _currentIndex < widget.flashcards.length - 1 ? _nextCard : null,
                  icon: const Icon(Icons.arrow_forward_ios_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: WebColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildReviewButton('Need Review', const Color(0xFFF97316), () => _handleReview(false)),
              const SizedBox(width: 24),
              _buildReviewButton('Known', const Color(0xFF10B981), () => _handleReview(true)),
            ],
          ),

          const SizedBox(height: 32),

          // Stats at the Bottom
          Row(
            children: [
              Expanded(child: _buildStatCard('Mastered', '$_knewCount/${widget.flashcards.length}', Icons.check_circle_rounded, const Color(0xFF22C55E))),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard('Study Time', _timeString, Icons.timer_rounded, const Color(0xFF6366F1))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardSide(String text, String label, bool isFront) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: WebColors.border.withOpacity(0.5)),
        boxShadow: WebColors.cardShadow,
      ),
      padding: const EdgeInsets.all(32),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: Text(
              (_currentIndex + 1).toString().padLeft(2, '0'),
              style: GoogleFonts.outfit(
                fontSize: 200,
                fontWeight: FontWeight.w900,
                color: WebColors.border.withOpacity(0.2),
                height: 1,
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: WebColors.primary.withOpacity(0.6),
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: WebColors.textPrimary,
                    height: 1.2,
                  ),
                ),
                if (isFront) ...[
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.touch_app_outlined, size: 20, color: WebColors.textTertiary),
                      const SizedBox(width: 8),
                      Text(
                        'Tap to reveal answer',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: WebColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewButton(String label, Color color, VoidCallback onPressed) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(label == 'Known' ? Icons.check_circle_outline_rounded : Icons.refresh_rounded,
                    color: color, size: 24),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WebColors.border.withOpacity(0.5)),
        boxShadow: WebColors.subtleShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: WebColors.textTertiary,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: WebColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
