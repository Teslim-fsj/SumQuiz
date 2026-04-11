import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;
        
        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isMobile) ...[
                SharedTeacherWidgets.moduleHeader('AI Feedback',
                    'Failure patterns & interventions', isMobile: true),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isGeneratingFeedback ? null : onGenerateFeedback,
                        icon: isGeneratingFeedback 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: WebColors.purplePrimary)) 
                          : const Icon(Icons.auto_awesome),
                        label: Text(isGeneratingFeedback ? 'Analyzing...' : (feedbackInsight == null ? 'Generate Insights' : 'Refresh Insights')),
                        style: ElevatedButton.styleFrom(
                           backgroundColor: WebColors.purplePrimary,
                           foregroundColor: Colors.white,
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                           padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SharedTeacherWidgets.moduleHeader('AI Feedback & Insights',
                        'Synthesized failure patterns and targeted interventions'),
                    ElevatedButton.icon(
                      onPressed: isGeneratingFeedback ? null : onGenerateFeedback,
                      icon: isGeneratingFeedback ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: WebColors.purplePrimary)) : const Icon(Icons.auto_awesome),
                      label: Text(isGeneratingFeedback ? 'Analyzing...' : (feedbackInsight == null ? 'Generate Insights' : 'Refresh Insights')),
                      style: ElevatedButton.styleFrom(
                         backgroundColor: WebColors.purplePrimary,
                         foregroundColor: Colors.white,
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                         padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 24),
              
              if (isMobile) ...[
                _buildCriticalStrugglePoints(isMobile: true),
                const SizedBox(height: 16),
                _buildPerformanceMix(isMobile: true),
                const SizedBox(height: 24),
              ] else
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 2, child: _buildCriticalStrugglePoints()),
                      const SizedBox(width: 24),
                      Expanded(flex: 1, child: _buildPerformanceMix()),
                    ],
                  ),
                ),
              
              const SizedBox(height: 24),
              _buildCurriculumMastery(isMobile: isMobile),
              
              const SizedBox(height: 24),
              _buildTargetedInterventions(isMobile: isMobile),
            ],
          ),
        );
      }
    );
  }

  Widget _buildCriticalStrugglePoints({bool isMobile = false}) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 24 : 40),
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
              padding: EdgeInsets.all(isMobile ? 16 : 24),
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
                      if (!isMobile) ...[
                        const SizedBox(width: 12),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFF3E8FF), borderRadius: BorderRadius.circular(20)), child: Text('High Priority', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: WebColors.purplePrimary))),
                      ],
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

  Widget _buildPerformanceMix({bool isMobile = false}) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 24 : 40),
      decoration: BoxDecoration(
        color: WebColors.purplePrimary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: WebColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PERFORMANCE MIX', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 1.5)),
          SizedBox(height: isMobile ? 32 : 12),
          Center(
            child: Container(
              width: isMobile ? 120 : 140,
              height: isMobile ? 120 : 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.2), width: 12),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('72%', style: GoogleFonts.outfit(fontSize: isMobile ? 28 : 32, fontWeight: FontWeight.w900, color: Colors.white)),
                    Text('AVERAGE MASTERY', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 1)),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: isMobile ? 32 : 12),
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

  Widget _buildCurriculumMastery({bool isMobile = false}) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 24 : 40),
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
          const SizedBox(height: 32),
          if (isMobile) ...[
            _topicRowMobile('LINEAR VARIABLES', 0.42, Colors.red[400]!),
            const SizedBox(height: 16),
            _topicRowMobile('HISTORICAL CONTEXT', 0.88, const Color(0xFFC4B5FD)),
            const SizedBox(height: 16),
            _topicRowMobile('VARIABLE ANALYSIS', 0.65, WebColors.purplePrimary),
            const SizedBox(height: 16),
            _topicRowMobile('STATISTICAL LOGIC', 0.94, const Color(0xFF4C1D95)),
          ] else
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

  Widget _topicRowMobile(String label, double val, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700])),
            Text('${(val*100).toInt()}%', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: val,
            backgroundColor: const Color(0xFFF1F5F9),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 10,
          ),
        ),
      ],
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

  Widget _buildTargetedInterventions({bool isMobile = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: WebColors.cardShadow,
      ),
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Targeted Interventions', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800)),
              if (isMobile) const Icon(Icons.auto_fix_high, color: WebColors.purplePrimary, size: 18),
            ],
          ),
          const SizedBox(height: 24),
          if (!isMobile)
            Row(
              children: [
                Expanded(flex: 2, child: Text('STUDENT', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 1))),
                Expanded(flex: 1, child: Text('PERFORMANCE CLUSTER', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 1))),
                Expanded(flex: 3, child: Text('AI INSIGHT', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 1))),
                Expanded(flex: 1, child: Text('INTERVENTION', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 1))),
                const Expanded(flex: 1, child: Align(alignment: Alignment.centerRight, child: Text('ACTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.transparent)))),
              ],
            ),
          if (!isMobile) const Divider(height: 1, color: Color(0xFFF3F4F6)),
          if (!isMobile) const SizedBox(height: 16),
          _interventionRow('AM', 'Alex Murphy', 'Declining', 'High effort, low retention in quantitative reasoning.', 'GUIDED PRACTICE', 'Email Parent', WebColors.purplePrimary, isMobile: isMobile),
          _interventionRow('ST', 'Sarah Tan', 'Top Tier', 'Ready for advanced variable integration modules.', 'EXTENSION TASK', 'Assign Task', Colors.grey[300]!, textCol: Colors.black87, isMobile: isMobile),
          _interventionRow('JP', 'James Park', 'Steady', 'Inconsistent terminology usage in written responses.', 'VOCAB REVIEW', 'Note AI', Colors.grey[300]!, textCol: Colors.black87, isMobile: isMobile),
        ],
      ),
    );
  }
  
  Widget _interventionRow(String initials, String name, String cluster, String insight, String intervention, String action, Color actionBtnColor, {Color textCol = Colors.white, bool isMobile = false}) {
    final clusterColor = cluster == 'Declining' ? Colors.red[100] : (cluster == 'Top Tier' ? Colors.green[100] : Colors.grey[200]);
    final clusterTextInfo = cluster == 'Declining' ? Colors.red[800] : (cluster == 'Top Tier' ? Colors.green[800] : Colors.grey[700]);

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 16, backgroundColor: const Color(0xFFF3E8FF), child: Text(initials, style: const TextStyle(fontSize: 12, color: WebColors.purplePrimary, fontWeight: FontWeight.bold))),
                const SizedBox(width: 12),
                Expanded(child: Text(name, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: clusterColor, borderRadius: BorderRadius.circular(20)),
                  child: Text(cluster, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: clusterTextInfo)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('"$insight"', style: GoogleFonts.outfit(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey[700])),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFF3E8FF), borderRadius: BorderRadius.circular(12)),
                  child: Text(intervention, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: WebColors.purplePrimary)),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(backgroundColor: actionBtnColor, foregroundColor: textCol, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: Text(action, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            )
          ],
        ),
      );
    }

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
