import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sumquiz/models/public_deck.dart';
import 'package:sumquiz/models/teacher_models.dart';
import 'package:sumquiz/theme/web_theme.dart';
import 'shared_teacher_widgets.dart';

class FeedbackInsights extends StatelessWidget {
  final String? feedbackInsight;
  final bool isGeneratingFeedback;
  final VoidCallback onGenerateFeedback;
  final Map<String, ContentAnalytics> analytics;
  final List<PublicDeck> content;
  final Function(PublicDeck) onEditDeck;

  const FeedbackInsights({
    super.key,
    required this.feedbackInsight,
    required this.isGeneratingFeedback,
    required this.onGenerateFeedback,
    required this.analytics,
    required this.content,
    required this.onEditDeck,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SharedTeacherWidgets.moduleHeader('AI Feedback Engine',
                    'Identify hard questions and improvement opportunities'),
              ),
              ElevatedButton.icon(
                onPressed: isGeneratingFeedback ? null : onGenerateFeedback,
                icon: isGeneratingFeedback
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome, size: 16),
                label:
                    Text(isGeneratingFeedback ? 'Analyzing...' : 'Generate Insights'),
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14)),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // AI Insight Box
          if (feedbackInsight != null)
            _buildAiInsightBox()
          else
            SharedTeacherWidgets.emptyCard('No insights yet',
                'Click "Generate Insights" above. AI will analyze your students\' attempts and identify the most difficult questions and commonly missed concepts.'),
          const SizedBox(height: 32),
          // Per-content hard questions
          _buildHardQuestionsList(),
        ],
      ),
    );
  }

  Widget _buildAiInsightBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            WebColors.purplePrimary.withValues(alpha: 0.08),
            WebColors.blueInfo.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: WebColors.purplePrimary.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: WebColors.purplePrimary.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: WebColors.purplePrimary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome,
                    color: WebColors.purplePrimary, size: 20),
              ),
              const SizedBox(width: 12),
              Text('AI-Generated Teaching Insights',
                  style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: WebColors.purplePrimary)),
            ],
          ),
          const SizedBox(height: 20),
          Text(feedbackInsight!,
              style: GoogleFonts.outfit(
                  fontSize: 15,
                  height: 1.8,
                  color: WebColors.textPrimary)),
          const SizedBox(height: 20),
          _buildActionItem('Review the specific questions below to identify gaps.'),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.05);
  }

  Widget _buildActionItem(String text) {
    return Row(
      children: [
        const Icon(Icons.lightbulb_outline_rounded, size: 16, color: WebColors.accentOrange),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, 
            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: WebColors.textSecondary)
          ),
        ),
      ],
    );
  }

  Widget _buildHardQuestionsList() {
    final contentWithData = analytics.values
        .where((a) => a.hardQuestions.isNotEmpty)
        .toList();

    if (contentWithData.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Hard Question Analysis',
            style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: WebColors.textPrimary)),
        const SizedBox(height: 20),
        ...contentWithData.map((a) => _hardQuestionsCard(a)),
      ],
    );
  }

  Widget _hardQuestionsCard(ContentAnalytics a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WebColors.border),
      ),
      child: Theme(
        data: ThemeData().copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(a.contentTitle,
              style: GoogleFonts.outfit(
                  fontSize: 14, fontWeight: FontWeight.w800)),
          subtitle: Text('${a.hardQuestions.length} problem areas detected',
              style: GoogleFonts.outfit(
                  fontSize: 12, color: WebColors.textTertiary)),
          children: a.hardQuestions.map((q) => _questionInsightTile(a, q)).toList(),
        ),
      ),
    );
  }

  Widget _questionInsightTile(ContentAnalytics a, QuestionInsight q) {
    final failColor = q.failureRate > 60
        ? WebColors.error
        : q.failureRate > 40
            ? WebColors.accentOrange
            : WebColors.yellowTip;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: WebColors.border))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: failColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.warning_amber_rounded, color: failColor, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Q${q.questionIndex + 1}: ${q.questionText}',
                    style: GoogleFonts.outfit(
                        fontSize: 13, fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: q.failureRate / 100,
                    backgroundColor: WebColors.backgroundAlt,
                    valueColor: AlwaysStoppedAnimation(failColor),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                    '${q.failureRate.toStringAsFixed(0)}% of students answered incorrectly',
                    style: GoogleFonts.outfit(
                        fontSize: 11, color: WebColors.textTertiary)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            children: [
              SharedTeacherWidgets.badge('${q.failureRate.toStringAsFixed(0)}% fail', failColor),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  final deck = content.firstWhere((d) => d.id == a.contentId);
                  onEditDeck(deck);
                },
                icon: const Icon(Icons.build_circle_outlined, size: 16),
                label: const Text('Fix'),
                style: TextButton.styleFrom(
                  foregroundColor: WebColors.purplePrimary,
                  textStyle: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
