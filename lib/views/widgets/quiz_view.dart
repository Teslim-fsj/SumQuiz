import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sumquiz/services/enhanced_ai_service.dart';
import 'package:sumquiz/theme/web_theme.dart';
import '../../models/local_quiz_question.dart';

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

class QuizView extends StatefulWidget {
  final String title;
  final List<LocalQuizQuestion> questions;
  final VoidCallback? onFinish;
  final bool showSaveButton;
  final VoidCallback? onSaveProgress;
  final void Function(bool isCorrect, LocalQuizQuestion question)? onAnswer;
  final EnhancedAIService? aiService;

  const QuizView({
    super.key,
    required this.title,
    required this.questions,
    this.onFinish,
    this.showSaveButton = false,
    this.onSaveProgress,
    this.onAnswer,
    this.aiService,
  });

  @override
  State<QuizView> createState() => _QuizViewState();
}

class _QuizViewState extends State<QuizView> {
  int _currentQuestionIndex = 0;
  int? _selectedAnswerIndex;
  bool _answerWasSelected = false;

  // Essay-mode state
  final TextEditingController _essayController = TextEditingController();
  bool _isVerifying = false;
  Map<String, dynamic>? _aiFeedback;

  @override
  void dispose() {
    _essayController.dispose();
    super.dispose();
  }

  LocalQuizQuestion get _currentQuestion =>
      widget.questions[_currentQuestionIndex];

  bool get _isEssay => _isEssayQuestion(_currentQuestion);

  void _onAnswerSelected(int index) {
    if (_answerWasSelected) return;
    setState(() {
      _selectedAnswerIndex = index;
      _answerWasSelected = true;
    });
    if (widget.onAnswer != null) {
      final isCorrect =
          _currentQuestion.options[index] == _currentQuestion.correctAnswer;
      widget.onAnswer!(isCorrect, _currentQuestion);
    }
  }

  Future<void> _verifyWithAI() async {
    final text = _essayController.text.trim();
    if (text.isEmpty) return;
    if (widget.aiService == null) return;

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
        _answerWasSelected = true;
      });

      final isCorrect = (result['isCorrect'] as bool?) ?? false;
      widget.onAnswer?.call(isCorrect, _currentQuestion);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleNextQuestion() {
    if (!_answerWasSelected) return;
    if (_currentQuestionIndex < widget.questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswerIndex = null;
        _answerWasSelected = false;
        _aiFeedback = null;
        _essayController.clear();
      });
    } else {
      widget.onFinish?.call();
    }
  }

  void _handlePreviousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
        _selectedAnswerIndex = null;
        _answerWasSelected = false;
        _aiFeedback = null;
        _essayController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isWeb = size.width > 800;
    final isMobile = size.width < 600;

    if (widget.questions.isEmpty) {
      return Center(
          child: Text("No questions available.",
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.onSurface)));
    }

    final double progress =
        (_currentQuestionIndex + 1) / widget.questions.length;

    return Column(
      children: [
        _buildTopBar(progress, theme),
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: isWeb ? 40.0 : 16.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 10),
                      _buildQuestionCard(theme, isMobile),
                      const SizedBox(height: 20),

                      // Render differently based on question type
                      if (_isEssay) ...[
                        _buildEssayInput(theme),
                        if (_aiFeedback != null) ...[
                          const SizedBox(height: 20),
                          _buildAiFeedbackCard(theme, isMobile),
                        ],
                        if (_currentQuestion.correctAnswer.isNotEmpty &&
                            _aiFeedback != null) ...[
                          const SizedBox(height: 16),
                          _buildReferenceAnswerCard(theme, isMobile),
                        ],
                      ] else ...[
                        if (isWeb)
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            childAspectRatio: 4.0,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 12,
                            children: List.generate(
                                _currentQuestion.options.length, (index) {
                              return _buildOptionTile(
                                  index, _currentQuestion, theme, false);
                            }),
                          ).animate().slideX(begin: 0.1).fade()
                        else
                          ...List.generate(_currentQuestion.options.length,
                              (index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: _buildOptionTile(
                                  index, _currentQuestion, theme, true),
                            );
                          }).animate().slideX(begin: 0.1).fade(),
                      ],

                      // Explanation for MCQ after answer revealed
                      if (!_isEssay &&
                          _answerWasSelected &&
                          _currentQuestion.explanation != null) ...[
                        const SizedBox(height: 16),
                        _buildExplanationCard(theme, isMobile),
                      ],

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        _buildBottomBar(theme, isMobile),
      ],
    );
  }

  Widget _buildTopBar(double progress, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '${_currentQuestionIndex + 1}/${widget.questions.length}',
            style: GoogleFonts.inter(
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(ThemeData theme, bool isMobile) {
    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16, vertical: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          _currentQuestion.question,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
            fontSize: isMobile ? 20 : 22,
            height: 1.3,
          ),
          textAlign: TextAlign.left,
        )
            .animate(key: ValueKey(_currentQuestionIndex))
            .fadeIn(duration: 400.ms)
            .slideX(begin: 0.05, end: 0, curve: Curves.easeOut),
      ),
    );
  }

  Widget _buildEssayInput(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _answerWasSelected
                  ? (_aiFeedback?['isCorrect'] == true
                      ? Colors.green
                      : Colors.orange)
                  : theme.dividerColor,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: _essayController,
            maxLines: 6,
            enabled: !_answerWasSelected && !_isVerifying,
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.6,
              color: theme.colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              hintText: 'Type your detailed answer here...',
              hintStyle: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
              ),
              filled: false,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(20),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 16),
        if (!_answerWasSelected)
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: (_essayController.text.trim().isNotEmpty &&
                      !_isVerifying &&
                      widget.aiService != null)
                  ? _verifyWithAI
                  : null,
              icon: _isVerifying
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onPrimary,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(
                _isVerifying ? 'Verifying...' : 'Verify with AI',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.secondary,
                foregroundColor: theme.colorScheme.onSecondary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
      ],
    ).animate().fadeIn();
  }

  Widget _buildAiFeedbackCard(ThemeData theme, bool isMobile) {
    final score = _aiFeedback!['score'] as int? ?? 0;
    final feedback = _aiFeedback!['feedback']?.toString() ?? '';
    final isCorrect = _aiFeedback!['isCorrect'] as bool? ?? false;

    final Color accentColor = isCorrect ? Colors.green : Colors.orange;
    final IconData icon =
        isCorrect ? Icons.check_circle_rounded : Icons.info_rounded;

    return AnimatedContainer(
      duration: 400.ms,
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: accentColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: isMobile ? 16 : 22),
              const SizedBox(width: 10),
              Text(
                'AI Score: $score%',
                style: (isMobile
                        ? theme.textTheme.labelLarge
                        : theme.textTheme.titleMedium)
                    ?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isCorrect ? 'Correct' : 'Needs Work',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 8 : 14),
          Text(
            feedback,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
              height: 1.4,
              fontSize: isMobile ? 12 : 14,
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildReferenceAnswerCard(ThemeData theme, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 10 : 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📚 Reference Answer',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: isMobile ? 10 : 11,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _currentQuestion.correctAnswer,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              height: 1.4,
              fontSize: isMobile ? 12 : 14,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 50.ms);
  }

  Widget _buildExplanationCard(ThemeData theme, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 10 : 16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline_rounded,
              color: Colors.blue.shade600, size: isMobile ? 16 : 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Explanation',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.blue.shade700,
                    fontSize: isMobile ? 10 : 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentQuestion.explanation!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    height: 1.4,
                    fontSize: isMobile ? 12 : 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildBottomBar(ThemeData theme, bool isMobile) {
    final bool canProceed = _answerWasSelected;
    final primaryColor = const Color(0xFF3B82F6); // Blue

    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: SizedBox(
        height: 56,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: canProceed ? _handleNextQuestion : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            disabledBackgroundColor: const Color(0xFF94A3B8),
            disabledForegroundColor: Colors.white,
          ),
          child: Text(
            _currentQuestionIndex < widget.questions.length - 1
                ? 'Next'
                : 'Finish Quiz',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile(
      int index, LocalQuizQuestion question, ThemeData theme, bool isMobile) {
    bool isSelected = _selectedAnswerIndex == index;
    bool isCorrect = question.options[index] == question.correctAnswer;
    final primaryColor = const Color(0xFF3B82F6); // Blue

    Color borderColor = Colors.white;
    Color backgroundColor = Colors.white;
    Color badgeColor = const Color(0xFFF1F5F9); // Light Grey
    Color badgeTextColor = const Color(0xFF334155); // Dark Grey
    Color textColor = const Color(0xFF0F172A);

    if (_answerWasSelected) {
      if (isCorrect) {
        borderColor = Colors.green;
        backgroundColor = Colors.green.withValues(alpha: 0.05);
        badgeColor = Colors.green;
        badgeTextColor = Colors.white;
      } else if (isSelected) {
        borderColor = Colors.red;
        backgroundColor = Colors.red.withValues(alpha: 0.05);
        badgeColor = Colors.red;
        badgeTextColor = Colors.white;
      }
    } else if (isSelected) {
      borderColor = primaryColor;
      backgroundColor = primaryColor.withValues(alpha: 0.05);
      badgeColor = primaryColor;
      badgeTextColor = Colors.white;
      textColor = primaryColor;
    }

    final String optionLetter = String.fromCharCode(65 + index);

    return GestureDetector(
      onTap: () => _onAnswerSelected(index),
      child: AnimatedContainer(
        duration: 250.ms,
        curve: Curves.easeInOut,
        padding:
            EdgeInsets.symmetric(horizontal: 20, vertical: isMobile ? 16 : 20),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected || (_answerWasSelected && (isCorrect || isSelected))
                    ? borderColor
                    : const Color(0xFFF1F5F9),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  optionLetter,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: badgeTextColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                question.options[index],
                style: GoogleFonts.inter(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  height: 1.3,
                ),
              ),
            ),
            if (isSelected && !_answerWasSelected)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 16),
              ),
            if (_answerWasSelected && isCorrect)
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 16),
              ),
            if (_answerWasSelected && isSelected && !isCorrect)
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 16),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassContainer(
      {required Widget child,
      EdgeInsetsGeometry? padding,
      required ThemeData theme}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
