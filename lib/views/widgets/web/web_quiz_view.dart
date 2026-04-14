// Screen goal: User should be able to answer a question in under 3 seconds without scrolling. Question and all options must fit on one screen.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sumquiz/theme/web_theme.dart';
import 'package:sumquiz/models/local_quiz_question.dart';
import 'package:sumquiz/services/enhanced_ai_service.dart';

/// Question types that require a written answer and AI verification.
const _essayTypes = {
  'theory',
  'short answer',
  'essay',
  'short_answer',
  'theory/short answer',
  'theory (short answer/essay)',
  'open ended',
  'written',
  'short_answer_essay',
  'long answer',
  'theory / essay',
  'essay / theory',
  'subjective',
  'structured',
  'long_answer',
  'descriptive',
  'open-ended',
  'response',
  'free response',
  'written response',
};

bool _isEssayQuestion(LocalQuizQuestion q) {
  // If options are empty but we have a correct answer, it's likely a theory question
  if (q.options.isEmpty && q.correctAnswer.isNotEmpty) return true;
  
  if (q.questionType == null) return false;
  return _essayTypes.contains(q.questionType!.toLowerCase().trim());
}

class WebQuizView extends StatefulWidget {
  final String title;
  final String? subtitle;
  final List<LocalQuizQuestion> questions;
  final String? summaryContent;
  final Function(bool isCorrect)? onAnswer;
  final VoidCallback? onFinish;
  final VoidCallback? onShowSummary;
  final EnhancedAIService? aiService;

  const WebQuizView({
    super.key,
    required this.title,
    this.subtitle,
    required this.questions,
    this.summaryContent,
    this.onAnswer,
    this.onFinish,
    this.onShowSummary,
    this.aiService,
  });

  @override
  State<WebQuizView> createState() => _WebQuizViewState();
}

class _WebQuizViewState extends State<WebQuizView> {
  int _currentIndex = 0;
  int? _selectedIndex;
  bool _isAnswered = false;

  // Essay state
  final TextEditingController _essayController = TextEditingController();
  bool _isVerifying = false;
  Map<String, dynamic>? _aiFeedback;

  @override
  void dispose() {
    _essayController.dispose();
    super.dispose();
  }

  LocalQuizQuestion get _currentQuestion => widget.questions[_currentIndex];
  bool get _isEssay => _isEssayQuestion(_currentQuestion);

  void _onOptionSelected(int index) {
    if (_isAnswered) return;
    setState(() {
      _selectedIndex = index;
    });
  }

  void _submitAnswer() {
    if (_selectedIndex == null || _isAnswered) return;
    
    final isCorrect = widget.questions[_currentIndex].options[_selectedIndex!] == 
                      widget.questions[_currentIndex].correctAnswer;
    
    setState(() {
      _isAnswered = true;
    });

    widget.onAnswer?.call(isCorrect);
  }

  Future<void> _verifyWithAI() async {
    final text = _essayController.text.trim();
    if (text.isEmpty || widget.aiService == null) return;

    setState(() {
      _isVerifying = true;
      _aiFeedback = null;
    });

    try {
      final result = await widget.aiService!.verifyEssayAnswer(
        question: _currentQuestion.question,
        studentAnswer: text,
        referenceAnswer: _currentQuestion.correctAnswer,
      );

      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _aiFeedback = result;
        _isAnswered = true;
      });

      final isCorrect = (result['isCorrect'] as bool?) ?? false;
      widget.onAnswer?.call(isCorrect);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI verification failed: $e')),
      );
    }
  }

  void _nextQuestion() {
    if (_currentIndex < widget.questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedIndex = null;
        _isAnswered = false;
        _aiFeedback = null;
        _essayController.clear();
      });
    } else {
      widget.onFinish?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentQuestion = widget.questions[_currentIndex];
    final progress = (_currentIndex + 1) / widget.questions.length;

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
                      widget.subtitle?.toUpperCase() ?? 'CELL BIOLOGY : MODULE 4',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: WebColors.primary.withOpacity(0.6),
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.title,
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: WebColors.textPrimary,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Question ${_currentIndex + 1} of ${widget.questions.length}',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: WebColors.textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 6,
              width: double.infinity,
              color: WebColors.border.withOpacity(0.5),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Question Card
          _buildQuestionCard(currentQuestion.question),

          const SizedBox(height: 20),

          // Question Content
          if (_isEssay) ...[
            _buildEssayInput(theme),
            if (_aiFeedback != null) ...[
              const SizedBox(height: 24),
              _buildAiFeedbackCard(theme),
              if (_currentQuestion.correctAnswer.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildReferenceAnswerCard(theme),
              ],
            ],
          ] else ...[
            // Options
            ...List.generate(
              currentQuestion.options.length,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildOptionTile(
                  index,
                  currentQuestion.options[index],
                  _selectedIndex == index,
                  _isAnswered,
                  currentQuestion.options[index] == currentQuestion.correctAnswer,
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Action Buttons
          Row(
            children: [
              TextButton.icon(
                onPressed: _currentIndex > 0 ? () => setState(() => _currentIndex--) : null,
                icon: const Icon(Icons.arrow_back_rounded),
                label: Text('Previous', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                style: TextButton.styleFrom(foregroundColor: WebColors.textPrimary),
              ),
              const Spacer(),
              TextButton(
                onPressed: _nextQuestion,
                style: TextButton.styleFrom(foregroundColor: WebColors.textPrimary),
                child: Text('Skip for now', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 24),
              Container(
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: WebColors.subtleShadow,
                ),
                child: ElevatedButton(
                  onPressed: _isEssay 
                      ? (_isAnswered ? _nextQuestion : (_essayController.text.isNotEmpty ? _verifyWithAI : null))
                      : (_selectedIndex != null ? (_isAnswered ? _nextQuestion : _submitAnswer) : null),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isVerifying 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(
                        _isAnswered ? 'Next Question' : (_isEssay ? 'Verify with AI' : 'Submit Answer'),
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Refresher Card
          _buildRefresherCard(),
        ],
      ),
    );
  }

  Widget _buildEssayInput(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isAnswered
              ? (_aiFeedback?['isCorrect'] == true ? Colors.green : Colors.orange)
              : WebColors.border,
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: _essayController,
        maxLines: 8,
        enabled: !_isAnswered && !_isVerifying,
        style: GoogleFonts.outfit(fontSize: 15, color: WebColors.textPrimary, height: 1.5),
        decoration: InputDecoration(
          hintText: 'Type your detailed answer here...',
          hintStyle: GoogleFonts.outfit(color: WebColors.textTertiary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildAiFeedbackCard(ThemeData theme) {
    final score = _aiFeedback?['score'] as int? ?? 0;
    final feedback = _aiFeedback?['feedback']?.toString() ?? '';
    final isCorrect = _aiFeedback?['isCorrect'] as bool? ?? false;

    final Color accentColor = isCorrect ? Colors.green : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isCorrect ? Icons.check_circle_rounded : Icons.info_rounded, color: accentColor, size: 24),
              const SizedBox(width: 12),
              Text(
                'AI Score: $score%',
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: accentColor),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  isCorrect ? 'Correct' : 'Needs Review',
                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: accentColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            feedback,
            style: GoogleFonts.outfit(fontSize: 14, color: WebColors.textPrimary, height: 1.5),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildReferenceAnswerCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WebColors.backgroundAlt.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WebColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book_rounded, color: WebColors.textSecondary, size: 20),
              const SizedBox(width: 12),
              Text(
                'REFERENCE ANSWER',
                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: WebColors.textSecondary, letterSpacing: 1),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _currentQuestion.correctAnswer,
            style: GoogleFonts.outfit(fontSize: 14, color: WebColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }
  
  Widget _buildQuestionCard(String question) {
    String insight = 'Focus on the relationship between structure and function.';
    if (widget.summaryContent != null && widget.summaryContent!.length > 100) {
      // Very simple extraction: first sentence or snippet
      insight = widget.summaryContent!.split('.').first;
      if (insight.length > 80) insight = '${insight.substring(0, 77)}...';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: WebColors.border.withOpacity(0.5)),
        boxShadow: WebColors.subtleShadow,
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 0,
            child: Opacity(
              opacity: 0.1,
              child: Icon(Icons.school_rounded, size: 120, color: WebColors.primary),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome_rounded, size: 14, color: Color(0xFF6366F1)),
                    const SizedBox(width: 8),
                    Text(
                      'AI INSIGHT',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF6366F1),
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                insight,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: WebColors.primary.withOpacity(0.7),
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                question,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: WebColors.textPrimary,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile(int index, String text, bool isSelected, bool isAnswered, bool isCorrect) {
    String letter = String.fromCharCode(65 + index); // A, B, C, D
    
    Color borderColor = WebColors.border;
    Color letterBg = WebColors.backgroundAlt;
    Color letterColor = WebColors.textPrimary;
    
    if (isSelected) {
      borderColor = const Color(0xFF6366F1);
      letterBg = const Color(0xFF0F172A);
      letterColor = Colors.white;
    }

    if (isAnswered) {
      if (isCorrect) {
        borderColor = Colors.green;
        if (isSelected) letterBg = Colors.green;
      } else if (isSelected) {
        borderColor = Colors.red;
        letterBg = Colors.red;
      }
    }

    return GestureDetector(
      onTap: () => _onOptionSelected(index),
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF5F3FF).withOpacity(0.5) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? WebColors.subtleShadow : null,
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: letterBg,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                letter,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: letterColor,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: WebColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRefresherCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: WebColors.backgroundAlt.withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 160,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: const DecorationImage(
                image: NetworkImage('https://images.unsplash.com/photo-1550989460-0adf9ea622e2?q=80&w=1000'),
                fit: BoxFit.cover,
              ),
            ),
            child: const Center(
              child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 40),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Need a refresher?',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: WebColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'The Golgi apparatus acts like a cellular post office, processing molecules and sending them to their final destination.',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    color: WebColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: widget.onShowSummary,
                  icon: const Icon(Icons.smart_display_rounded, size: 18),
                  label: Text(
                    'Go back to summary',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
