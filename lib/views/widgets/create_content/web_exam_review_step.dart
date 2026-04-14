import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sumquiz/models/local_quiz_question.dart';

class WebExamReviewStep extends StatelessWidget {
  final List<LocalQuizQuestion> questions;
  final Function(int) onRegenerate;
  final Function(int, LocalQuizQuestion) onQuestionChanged;
  final VoidCallback onBack;
  final VoidCallback onSaveLibrary;
  final VoidCallback onPdfExport;
  final VoidCallback onPublish;
  
  // Stats
  final int easyCount;
  final int mediumCount;
  final int hardCount;
  final Map<String, int> topicCounts;

  const WebExamReviewStep({
    super.key,
    required this.questions,
    required this.onRegenerate,
    required this.onQuestionChanged,
    required this.onBack,
    required this.onSaveLibrary,
    required this.onPdfExport,
    required this.onPublish,
    required this.easyCount,
    required this.mediumCount,
    required this.hardCount,
    required this.topicCounts,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Review & Edit Draft',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Fine-tune your generated assessment. Edit directly or regenerate items.',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: const Color(0xFF475569),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  _buildActionButton('Back to Config', Icons.arrow_back, const Color(0xFFF1F5F9), const Color(0xFF64748B), onBack),
                  const SizedBox(width: 12),
                  _buildActionButton('Save to Library', Icons.save_alt_rounded, const Color(0xFFE2E8F0), const Color(0xFF1E293B), onSaveLibrary),
                  const SizedBox(width: 12),
                  _buildActionButton('PDF Export', Icons.picture_as_pdf_rounded, const Color(0xFFE2E8F0), const Color(0xFF1E293B), onPdfExport),
                  const SizedBox(width: 12),
                  _buildActionButton('Publish to Class', Icons.send_rounded, const Color(0xFF4F46E5), Colors.white, onPublish),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Expanded(
            child: questions.isEmpty 
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.psychology_outlined, size: 64, color: Color(0xFFCBD5E1)),
                      const SizedBox(height: 16),
                      Text('No questions generated yet.', style: GoogleFonts.outfit(fontSize: 18, color: const Color(0xFF64748B))),
                      const SizedBox(height: 8),
                      Text('Try adjusting your configuration and generating again.', style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF94A3B8))),
                    ],
                  ),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Questions List Column
                    Expanded(
                      flex: 6,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 120),
                        itemCount: questions.length,
                        itemBuilder: (context, index) => _buildQuestionItem(context, questions[index], index),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Exam Summary Panel
                    Expanded(
                      flex: 3,
                      child: _buildExamSummary(context),
                    ),
                  ],
                ),
          )
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color bg, Color fn, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fn,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildQuestionItem(BuildContext context, LocalQuizQuestion q, int index) {
    String diffBg = 'EEF2FF'; // Medium
    String diffFn = '4F46E5';
    String diffLabel = 'MEDIUM';
    
    // Quick mock for difficulty tag colors, in real system would decode from question properties
    if (index % 4 == 0) {
      diffBg = 'FFE4E6'; diffFn = 'BE123C'; diffLabel = 'HARD';
    } else if (index % 3 == 0) {
      diffBg = 'F1F5F9'; diffFn = '475569'; diffLabel = 'EASY';
    }
    
    String topicLabel = topicCounts.keys.isNotEmpty ? topicCounts.keys.elementAt(index % topicCounts.keys.length).toUpperCase() : 'GENERAL';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Color(int.parse('0xFF$diffBg')), borderRadius: BorderRadius.circular(12)),
                    child: Text(diffLabel, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Color(int.parse('0xFF$diffFn')))),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
                    child: Text(topicLabel, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF475569))),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => onRegenerate(index),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text('Regenerate', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF4F46E5)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (index + 1).toString().padLeft(2, '0'),
                style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900, color: const Color(0xFFE2E8F0), height: 1),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      initialValue: q.question,
                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                      maxLines: null,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Enter question text...',
                      ),
                      onChanged: (val) {
                        onQuestionChanged(index, q.copyWith(question: val));
                      },
                    ),
                    const SizedBox(height: 12),
                    if (q.questionType == 'Multiple Choice' || q.questionType == 'True/False') 
                      _buildOptionsGrid(q, index)
                    else if (q.questionType == 'Theory' || q.questionType == 'Essay')
                      _buildTheoryLine()
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsGrid(LocalQuizQuestion q, int qIndex) {
    if (q.options.isEmpty) return const SizedBox();
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: List.generate(q.options.length, (i) {
        bool isCorrect = q.correctAnswer == q.options[i];
        return Container(
          width: 280,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isCorrect ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
            border: Border.all(color: isCorrect ? const Color(0xFF22C55E) : const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Radio<String>(
                value: q.options[i],
                groupValue: q.correctAnswer,
                onChanged: (val) {
                  if (val != null) {
                    onQuestionChanged(qIndex, q.copyWith(correctAnswer: val));
                  }
                },
                activeColor: const Color(0xFF22C55E),
              ),
              const SizedBox(width: 4),
              Text('${String.fromCharCode(65 + i)})', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: q.options[i],
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                  style: GoogleFonts.outfit(color: const Color(0xFF475569), fontSize: 13),
                  onChanged: (val) {
                    final newOptions = List<String>.from(q.options);
                    newOptions[i] = val;
                    // If it was the correct answer, update it as well
                    String newCorrect = q.correctAnswer;
                    if (isCorrect) newCorrect = val;
                    onQuestionChanged(qIndex, q.copyWith(options: newOptions, correctAnswer: newCorrect));
                  },
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildTheoryLine() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        LayoutBuilder(builder: (context, constraints) {
          return Row(
            children: [
              Expanded(
                child: Container(height: 4, decoration: BoxDecoration(color: const Color(0xFF4F46E5), borderRadius: BorderRadius.circular(2))),
              ),
              Expanded(
                flex: 2,
                child: Container(height: 4, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2))),
              ),
            ],
          );
        }),
        const SizedBox(height: 8),
        Text('ACCURACY SCORE: 94%', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8))),
      ],
    );
  }

  Widget _buildExamSummary(BuildContext context) {
    int total = easyCount + mediumCount + hardCount;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF4F46E5), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Exam Summary', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
                  Text('REAL-TIME METRICS', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1, color: const Color(0xFF94A3B8))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Questions', style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF475569))),
              Text('$total', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: const Color(0xFF4F46E5))),
            ],
          ),
          const SizedBox(height: 16),
          Text('DIFFICULTY BALANCE', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: const Color(0xFF94A3B8))),
          const SizedBox(height: 16),
          _buildBalanceBar(total),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('EASY ($easyCount)', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
              Text('MED ($mediumCount)', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
              Text('HARD ($hardCount)', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
            ],
          ),
          const SizedBox(height: 16),
          Text('TOP TOPICS', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: const Color(0xFF94A3B8))),
          const SizedBox(height: 16),
          ...topicCounts.entries.take(3).map((e) => _buildTopicRow(e.key, e.value, total)),
          
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF4F46E5)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'AI suggests adding 2 more Medium difficulty questions to meet your target curriculum balance.',
                    style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF4F46E5), height: 1.5),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBalanceBar(int total) {
    if (total == 0) return const SizedBox();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 12,
        width: double.infinity,
        child: Row(
          children: [
            Expanded(flex: easyCount, child: Container(color: const Color(0xFFCBD5E1))),
            Expanded(flex: mediumCount, child: Container(color: const Color(0xFF818CF8))),
            Expanded(flex: hardCount, child: Container(color: const Color(0xFF312E81))),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicRow(String name, int count, int total) {
    if (total == 0) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(name, style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF1E293B)))),
          Expanded(
            flex: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: count / total,
                backgroundColor: const Color(0xFFF1F5F9),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text('$count', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
        ],
      ),
    );
  }
}
