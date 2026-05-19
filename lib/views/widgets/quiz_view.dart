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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_isEssay)
                      Text(
                        'Essay / Theory',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.showSaveButton && widget.onSaveProgress != null)
                IconButton(
                  icon: Icon(Icons.save_alt, color: theme.colorScheme.primary),
                  onPressed: widget.onSaveProgress,
                ).animate().scale(),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: theme.disabledColor.withValues(alpha: 0.2),
              valueColor:
                  AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(ThemeData theme, bool isMobile) {
    return _buildGlassContainer(
      theme: theme,
      padding: EdgeInsets.all(isMobile ? 24 : 40),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'QUESTION ${_currentQuestionIndex + 1} OF ${widget.questions.length}',
                style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0),
              ),
              if (_currentQuestion.questionType != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isEssay
                        ? theme.colorScheme.secondary.withValues(alpha: 0.15)
                        : theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    _currentQuestion.questionType!.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _isEssay
                          ? theme.colorScheme.secondary
                          : theme.colorScheme.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: isMobile ? 24 : 32),
          Text(
            _currentQuestion.question,
            style: (isMobile
                    ? theme.textTheme.headlineSmall
                    : theme.textTheme.headlineLarge)
                ?.copyWith(
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.onSurface,
              height: 1.2,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          )
              .animate(key: ValueKey(_currentQuestionIndex))
              .fadeIn(duration: 400.ms)
              .scale(begin: const Offset(0.98, 0.98), curve: Curves.easeOut),
        ],
      ),
    ).animate().slideY(begin: 0.05, end: 0, duration: 500.ms, curve: Curves.easeOut).fade();
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
        border: Border.all(color: accentColor.withValues(alpha: 0.4), width: 1.5),
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

    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          // Back Button
          if (_currentQuestionIndex > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: _handlePreviousQuestion,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: WebColors.primary.withValues(alpha: 0.3)),
                    padding:
                        EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_back_rounded,
                          color: WebColors.primary, size: 20),
                      if (!isMobile) ...[
                        const SizedBox(width: 8),
                        const Text('Back',
                            style: TextStyle(color: WebColors.primary)),
                      ],
                    ],
                  ),
                ),
              ),
            ),

          // Main Action Button (Next/Finish)
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: canProceed ? _handleNextQuestion : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: WebColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: WebColors.border,
                  disabledForegroundColor: WebColors.textTertiary,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _currentQuestionIndex < widget.questions.length - 1
                          ? (isMobile ? 'Next' : 'Next Question')
                          : 'Finish Quiz',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        fontSize: isMobile ? 15 : 16,
                        color:
                            canProceed ? Colors.white : WebColors.textTertiary,
                      ),
                    ),
                    if (_currentQuestionIndex <
                        widget.questions.length - 1) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile(
      int index, LocalQuizQuestion question, ThemeData theme, bool isMobile) {
    bool isSelected = _selectedAnswerIndex == index;
    bool isCorrect = question.options[index] == question.correctAnswer;
    final colorScheme = theme.colorScheme;

    Color borderColor = theme.dividerColor.withValues(alpha: 0.1);
    Color backgroundColor = theme.cardColor.withValues(alpha: 0.6);
    IconData icon = Icons.circle_outlined;
    Color iconColor = theme.disabledColor;
    Color textColor = theme.colorScheme.onSurface;

    // Convert index to option letter (A, B, C, D)
    final String optionLetter = String.fromCharCode(65 + index);

    if (_answerWasSelected) {
      if (isCorrect) {
        borderColor = Colors.green;
        backgroundColor = Colors.green.withValues(alpha: 0.08);
        icon = Icons.check_circle_rounded;
        iconColor = Colors.green;
        textColor = Colors.green.shade700;
      } else if (isSelected) {
        borderColor = Colors.red;
        backgroundColor = Colors.red.withValues(alpha: 0.08);
        icon = Icons.cancel_rounded;
        iconColor = Colors.red;
        textColor = Colors.red.shade700;
      } else {
        backgroundColor = theme.cardColor.withValues(alpha: 0.25);
        textColor = theme.colorScheme.onSurface.withValues(alpha: 0.4);
      }
    } else if (isSelected) {
      borderColor = colorScheme.primary;
      backgroundColor = colorScheme.primary.withValues(alpha: 0.05);
      iconColor = colorScheme.primary;
    }

    return GestureDetector(
      onTap: () => _onAnswerSelected(index),
      child: AnimatedContainer(
        duration: 250.ms,
        curve: Curves.easeInOut,
        padding:
            EdgeInsets.symmetric(horizontal: 20, vertical: isMobile ? 16 : 20),
        decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor,
              width: 1.5,
            ),
            boxShadow: [
              if (isSelected && !_answerWasSelected)
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              if (_answerWasSelected && (isCorrect || isSelected))
                BoxShadow(
                  color: (isCorrect ? Colors.green : Colors.red).withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ]),
        child: Row(
          children: [
            // Neat Academic Letter Badge (A, B, C, D)
            Container(
              width: isMobile ? 32 : 36,
              height: isMobile ? 32 : 36,
              decoration: BoxDecoration(
                color: _answerWasSelected
                    ? (isCorrect
                        ? Colors.green.withValues(alpha: 0.15)
                        : (isSelected
                            ? Colors.red.withValues(alpha: 0.15)
                            : theme.disabledColor.withValues(alpha: 0.05)))
                    : (isSelected
                        ? colorScheme.primary.withValues(alpha: 0.15)
                        : theme.dividerColor.withValues(alpha: 0.05)),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _answerWasSelected
                      ? (isCorrect
                          ? Colors.green
                          : (isSelected ? Colors.red : Colors.transparent))
                      : (isSelected ? colorScheme.primary : theme.dividerColor.withValues(alpha: 0.1)),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: _answerWasSelected && (isCorrect || isSelected)
                    ? Icon(icon, color: iconColor, size: isMobile ? 18 : 20)
                    : Text(
                        optionLetter,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? 14 : 15,
                          color: _answerWasSelected
                              ? (isCorrect
                                  ? Colors.green.shade700
                                  : (isSelected ? Colors.red.shade700 : theme.hintColor))
                              : (isSelected ? colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                        ),
                      ),
              ),
            ),
            SizedBox(width: isMobile ? 16 : 20),
            Expanded(
              child: Text(
                question.options[index],
                style: GoogleFonts.inter(
                  color: textColor,
                  fontWeight: (isSelected || (_answerWasSelected && isCorrect))
                      ? FontWeight.w700
                      : FontWeight.w500,
                  fontSize: isMobile ? 15 : 17,
                  height: 1.3,
                ),
              ),
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
