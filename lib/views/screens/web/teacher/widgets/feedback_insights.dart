import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sumquiz/models/public_deck.dart';
import 'package:sumquiz/models/teacher_models.dart';
import 'package:sumquiz/theme/web_theme.dart';

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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text('Class Intelligence', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF1F1F1F), letterSpacing: -1)),
                   const SizedBox(height: 8),
                   Text('Synthesizing recent data points into actionable insights for your class.', style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF6B7280))),
                ],
              ),
              ElevatedButton.icon(
                onPressed: isGeneratingFeedback ? null : onGenerateFeedback,
                icon: isGeneratingFeedback ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: WebColors.purplePrimary)) : const Icon(Icons.auto_awesome),
                label: Text(isGeneratingFeedback ? 'Analyzing...' : (feedbackInsight == null ? 'Generate Insights' : 'Refresh Insights')),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 2, child: _buildCriticalStrugglePoints()),
              const SizedBox(width: 24),
              Expanded(flex: 1, child: _buildPerformanceMix()),
            ],
          ),
          
          const SizedBox(height: 20),
          _buildCurriculumMastery(),
          
          const SizedBox(height: 20),
          _buildTargetedInterventions(),
        ],
      ),
    );
  }

  Widget _buildCriticalStrugglePoints() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: WebColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline, color: WebColors.purplePrimary),
              const SizedBox(width: 12),
              Text('AI FEEDBACK SYNTHESIS', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: WebColors.purplePrimary, letterSpacing: 1.5)),
            ],
          ),
          const SizedBox(height: 12),
          Text('Critical Struggle Points', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          
          if (feedbackInsight == null)
             Text('Run the AI generator to discover deep learning patterns and struggles.', style: TextStyle(color: Colors.grey[500]))
          else
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: WebColors.purplePrimary.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('AI Insight Highlight', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 12),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFF3E8FF), borderRadius: BorderRadius.circular(20)), child: Text('High Priority', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: WebColors.purplePrimary))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(feedbackInsight!, style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[700], height: 1.5)),
                  const SizedBox(height: 16),
                  Text('Review Topic Strategy →', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: WebColors.purplePrimary)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMix() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: WebColors.purplePrimary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: WebColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PERFORMANCE MIX', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 1.5)),
          const Spacer(),
          Center(
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.2), width: 12),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('72%', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
                    Text('AVERAGE MASTERY', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 1)),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          _mixRow('Conceptual', '68%'),
          const SizedBox(height: 16),
          _mixRow('Practical', '76%'),
        ],
      ),
    );
  }
  
  Widget _mixRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white54, shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Text(label, style: GoogleFonts.outfit(fontSize: 14, color: Colors.white)),
          ],
        ),
        Text(value, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }

  Widget _buildCurriculumMastery() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: WebColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SUBJECT TOPIC BREAKDOWN', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 1.5)),
          const SizedBox(height: 16),
          Text('Curriculum Mastery', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               _topicBar('LINEAR VARIABLES', 0.42, Colors.red[400]!),
               _topicBar('HISTORICAL CONTEXT', 0.88, const Color(0xFFC4B5FD)),
               _topicBar('VARIABLE ANALYSIS', 0.65, WebColors.purplePrimary),
               _topicBar('STATISTICAL LOGIC', 0.94, const Color(0xFF4C1D95)),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _topicBar(String label, double heightPerc, Color color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(label, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[600]), overflow: TextOverflow.ellipsis)),
                Text('${(heightPerc*100).toInt()}%', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
               height: 100 * heightPerc,
               width: double.infinity,
               decoration: BoxDecoration(
                 color: color,
                 borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
               ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetedInterventions() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: WebColors.cardShadow,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Targeted Interventions', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(flex: 2, child: Text('STUDENT', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 1))),
              Expanded(flex: 1, child: Text('PERFORMANCE CLUSTER', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 1))),
              Expanded(flex: 3, child: Text('AI INSIGHT', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 1))),
              Expanded(flex: 1, child: Text('INTERVENTION', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 1))),
              const Expanded(flex: 1, child: Align(alignment: Alignment.centerRight, child: Text('ACTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.transparent)))),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 16),
          _interventionRow('AM', 'Alex Murphy', 'Declining', 'High effort, low retention in quantitative reasoning.', 'GUIDED PRACTICE', 'Email Parent', WebColors.purplePrimary),
          _interventionRow('ST', 'Sarah Tan', 'Top Tier', 'Ready for advanced variable integration modules.', 'EXTENSION TASK', 'Assign Task', Colors.grey[300]!, textCol: Colors.black87),
          _interventionRow('JP', 'James Park', 'Steady', 'Inconsistent terminology usage in written responses.', 'VOCAB REVIEW', 'Note AI', Colors.grey[300]!, textCol: Colors.black87),
        ],
      ),
    );
  }
  
  Widget _interventionRow(String initials, String name, String cluster, String insight, String intervention, String action, Color actionBtnColor, {Color textCol = Colors.white}) {
    final clusterColor = cluster == 'Declining' ? Colors.red[100] : (cluster == 'Top Tier' ? Colors.green[100] : Colors.grey[200]);
    final clusterTextInfo = cluster == 'Declining' ? Colors.red[800] : (cluster == 'Top Tier' ? Colors.green[800] : Colors.grey[700]);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                CircleAvatar(backgroundColor: const Color(0xFFF3E8FF), child: Text(initials, style: const TextStyle(color: WebColors.purplePrimary, fontWeight: FontWeight.bold))),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold)),
                    Text('Class A', style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: clusterColor, borderRadius: BorderRadius.circular(12)),
                child: Text(cluster, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: clusterTextInfo)),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text('"$insight"', style: GoogleFonts.outfit(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey[700])),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFF3E8FF), borderRadius: BorderRadius.circular(12)),
              child: Text(intervention, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: WebColors.purplePrimary)),
            ),
          ),
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(backgroundColor: actionBtnColor, foregroundColor: textCol, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                child: Text(action, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
