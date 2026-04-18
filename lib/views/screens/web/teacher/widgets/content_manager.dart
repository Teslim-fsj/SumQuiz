import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:sumquiz/models/public_deck.dart';
import 'package:sumquiz/models/teacher_models.dart';
import 'package:sumquiz/theme/web_theme.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:sumquiz/models/local_quiz_question.dart';
import 'package:sumquiz/services/exam_pdf_generator.dart';

class ContentManager extends StatefulWidget {
  final List<PublicDeck> content;
  final Map<String, ContentAnalytics> analytics;
  final TeacherStats? stats;
  final Function(PublicDeck) onEdit;
  final Function(PublicDeck) onDelete;
  final VoidCallback onCreateExam;
  final VoidCallback onCreatePack;

  const ContentManager({
    super.key,
    required this.content,
    required this.analytics,
    required this.stats,
    required this.onEdit,
    required this.onDelete,
    required this.onCreateExam,
    required this.onCreatePack,
  });

  @override
  State<ContentManager> createState() => _ContentManagerState();
}

class _ContentManagerState extends State<ContentManager> {
  String _searchQuery = '';
  bool _showExams = false; // toggle between study packs and exams
  bool _filterPublished = true;
  bool _filterDrafts = false;

  @override
  Widget build(BuildContext context) {
    final filteredContent = widget.content.where((c) {
      final matchesSearch = c.title.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesStatus = (c.isPublished && _filterPublished) || (!c.isPublished && _filterDrafts);
      return matchesSearch && matchesStatus;
    }).toList();

    final exams = filteredContent.where((c) => c.isExam).toList();
    final packs = filteredContent.where((c) => !c.isExam).toList();
    
    final displayedItems = _showExams ? exams : packs;
    
    // Status counts should also respect the search query for consistency
    final searchFiltered = widget.content.where((c) => 
      c.title.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    final publishedCount = searchFiltered.where((c) => c.isPublished).length;
    final draftCount = searchFiltered.where((c) => !c.isPublished).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;
        
        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBanner(isMobile: isMobile),
              const SizedBox(height: 24),
              if (isMobile) ...[
                _buildSearchBar(isMobile: true),
                const SizedBox(height: 20),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _sidebarMenuButton('Study Packs', packs.length, !_showExams, () => setState(() => _showExams = false), isMobile: true),
                      const SizedBox(width: 8),
                      _sidebarMenuButton('Exams', exams.length, _showExams, () => setState(() => _showExams = true), isMobile: true),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildMainContentArea(displayedItems, isMobile: true),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 1, child: _buildSidebar(packs.length, exams.length, publishedCount, draftCount)),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 3,
                      child: _buildMainContentArea(displayedItems),
                    ),
                  ],
                ),
            ],
          ),
        );
      }
    );
  }

  Future<void> _exportDeckPdf(PublicDeck deck) async {
    final messenger = ScaffoldMessenger.of(context);
    final raw = deck.quizData['questions'];
    if (raw is! List || raw.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
            content: Text('This item has no exam questions to export as PDF.')),
      );
      return;
    }
    final questions = <LocalQuizQuestion>[];
    for (final item in raw) {
      if (item is Map) {
        questions.add(
            LocalQuizQuestion.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    if (questions.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Could not read questions for this deck.')),
      );
      return;
    }
    try {
      final titleFromQuiz = deck.quizData['title'];
      final title = titleFromQuiz is String && titleFromQuiz.trim().isNotEmpty
          ? titleFromQuiz.trim()
          : deck.title;
      final pdfGen = ExamPdfGenerator();
      final config = ExamPdfConfig(
        schoolName: 'SUMQUIZ ACADEMY',
        examTitle: title,
        subject: title,
        classLevel: 'General',
        durationMinutes: 60,
        shareCode: deck.shareCode,
        includeAnswerSheet: true,
        includeMarkingScheme: false,
      );
      final doc = pdfGen.generateStudentPaper(
        questions: questions,
        config: config,
      );
      final bytes = await doc.save();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: '$title.pdf',
      );
      try {
        await Printing.sharePdf(bytes: bytes, filename: '$title.pdf');
      } catch (_) {}
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('PDF export failed: $e')),
      );
    }
  }

  Widget _buildTopBanner({bool isMobile = false}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E1A47), Color(0xFF1E112A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: isMobile 
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                child: Text('CURRICULUM INTELLIGENCE', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 1.2)),
              ),
              const SizedBox(height: 16),
              Text(
                'Manage Content Lifecycle',
                style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _bannerStatCard('MATERIALS', '${widget.content.length}', isMobile: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _bannerStatCard('STUDENTS', '${widget.stats?.totalStudents ?? 0}', isMobile: true)),
                ],
              )
            ],
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                      child: Text('CURRICULUM INTELLIGENCE', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 1.2)),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Manage Content Lifecycle',
                      style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Orchestrate study pathways. Convert lectures into quizzes and exams with AI insights.',
                      style: GoogleFonts.outfit(fontSize: 12, color: Colors.white70, height: 1.4),
                    ),
                  ],
                ),
              ),
               Column(
                children: [
                  _bannerStatCard('TOTAL MATERIALS', '${widget.content.length}'),
                  const SizedBox(height: 16),
                  _bannerStatCard('ACTIVE STUDENTS', '${widget.stats?.activeStudents ?? 0}'),
                ],
              )
            ],
          ),
    );
  }
  
  Widget _bannerStatCard(String label, String value, {bool isMobile = false}) {
    return Container(
      width: isMobile ? null : 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 0.8)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildSidebar(int packsCount, int examsCount, int publishedCount, int draftCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSearchBar(),
        const SizedBox(height: 24),
        Text('CONTENT ENGINE', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 1)),
        const SizedBox(height: 16),
        _sidebarMenuButton('Study Packs', packsCount, !_showExams, () => setState(() => _showExams = false)),
        const SizedBox(height: 8),
        _sidebarMenuButton('Exams', examsCount, _showExams, () => setState(() => _showExams = true)),
        const SizedBox(height: 24),
        
        Text('STATUS FILTER', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 1)),
        const SizedBox(height: 16),
        _buildCheckbox('Published', publishedCount, _filterPublished, (v) => setState(() => _filterPublished = v ?? true)),
        const SizedBox(height: 8),
        _buildCheckbox('Drafts', draftCount, _filterDrafts, (v) => setState(() => _filterDrafts = v ?? false)),
        
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.psychology, color: WebColors.purplePrimary, size: 20)),
              const SizedBox(height: 16),
              Text('Content Performance Insight', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('"Recent packs show 40% higher retention rates among students."', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[700], height: 1.5)),
              const SizedBox(height: 16),
              Text('VIEW ANALYSIS →', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: WebColors.purplePrimary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar({bool isMobile = false}) {
    return Container(
      width: isMobile ? double.infinity : null,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: WebColors.border),
      ),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Search curriculum...',
          hintStyle: GoogleFonts.outfit(fontSize: 14, color: WebColors.textTertiary),
          prefixIcon: const Icon(Icons.search, size: 20, color: WebColors.textTertiary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _sidebarMenuButton(String label, int count, bool isActive, VoidCallback onTap, {bool isMobile = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20, vertical: isMobile ? 12 : 14),
        decoration: BoxDecoration(
          color: isActive ? WebColors.purplePrimary : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isActive ? WebColors.purplePrimary : const Color(0xFFE5E7EB)),
        ),
        child: Row(
          mainAxisSize: isMobile ? MainAxisSize.min : MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.outfit(fontSize: isMobile ? 13 : 14, fontWeight: isActive ? FontWeight.bold : FontWeight.w600, color: isActive ? Colors.white : const Color(0xFF1F1F1F))),
            if (isMobile) const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: isActive ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
              child: Text('$count', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: isActive ? Colors.white : Colors.grey[700])),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckbox(String label, int count, bool isChecked, Function(bool?) onChange) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: isChecked,
            onChanged: onChange,
            activeColor: WebColors.purplePrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
        const SizedBox(width: 8),
        Text('$label ($count)', style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[800], fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildMainContentArea(List<PublicDeck> displayedItems, {bool isMobile = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isMobile)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_showExams ? 'Current Exams' : 'Current Study Packs', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900)),
                  Text('Managing ${displayedItems.length} active bundles', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
              Row(
                children: [
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: WebColors.border), shape: BoxShape.circle), child: const Icon(Icons.filter_list, size: 20)),
                  const SizedBox(width: 12),
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: WebColors.border), shape: BoxShape.circle), child: const Icon(Icons.sort, size: 20)),
                ],
              ),
            ],
          ),
        if (displayedItems.isEmpty) 
          _buildEmptyState()
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isMobile ? 1 : 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: isMobile ? 1.1 : 0.95,
            ),
            itemCount: displayedItems.length + (isMobile ? 1 : 2), // adding creation/AI cards
            itemBuilder: (context, i) {
              if (i == displayedItems.length) {
                return isMobile ? _buildCreateNewCard(isMobile: true) : _buildAiRecommendationCard();
              } else if (i == displayedItems.length + 1) {
                return _buildCreateNewCard();
              }
              return _contentCard(displayedItems[i], isMobile: isMobile);
            },
          ),
      ],
    );
  }

  Widget _contentCard(PublicDeck deck, {bool isMobile = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: WebColors.cardShadow,
        border: Border.all(color: WebColors.border.withValues(alpha: 0.5)),
      ),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(color: Color(0xFFEEF2FF), shape: BoxShape.circle),
                child: Icon(deck.isExam ? Icons.assignment : Icons.science, color: WebColors.purplePrimary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.circle, color: Color(0xFF166534), size: 6),
                    const SizedBox(width: 6),
                    Text('PUBLIC', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF166534))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(deck.title, style: GoogleFonts.outfit(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.w800, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Text('Updated ${DateFormat.MMMd().format(deck.publishedAt)}', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[500])),
          
          if (!deck.isExam) ...[
             SizedBox(height: isMobile ? 16 : 24),
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 _statBubble(Icons.article, 'Summary'),
                 _statBubble(Icons.quiz, '12 Quizzes'),
                 _statBubble(Icons.style, '45 Cards'),
               ],
             )
          ],
          
          const Spacer(),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text('${((widget.analytics[deck.id]?.engagementRate ?? 0) * 12).toInt()} enrollments', 
                          style: GoogleFonts.outfit(color: WebColors.purplePrimary, fontWeight: FontWeight.bold, fontSize: 11)),
                     const SizedBox(height: 2),
                     Text('Code: ${deck.shareCode}', style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                   ],
                 ),
               ),
              
              Row(
                children: [
                   IconButton(
                     tooltip: 'Download PDF',
                     icon: const Icon(Icons.picture_as_pdf_outlined, size: 18, color: Colors.grey), 
                     onPressed: () => _exportDeckPdf(deck),
                   ),
                   IconButton(
                     tooltip: 'Edit',
                     icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.grey), 
                     onPressed: () => widget.onEdit(deck)
                   ),
                   IconButton(
                     tooltip: 'Delete',
                     icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.grey), 
                     onPressed: () => widget.onDelete(deck)
                   ),
                ],
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _statBubble(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Icon(icon, size: 16, color: WebColors.purplePrimary),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[700])),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.inventory_2_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _searchQuery.isNotEmpty 
                ? 'No matching results' 
                : 'No ${_showExams ? 'Exams' : 'Study Packs'} Created Yet',
            style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty 
                ? 'Try adjusting your search terms or filters.'
                : 'Start building your curriculum by creating your first ${_showExams ? 'formal exam' : 'study pack'}.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _showExams ? widget.onCreateExam : widget.onCreatePack,
            icon: const Icon(Icons.add),
            label: Text('Create First ${_showExams ? 'Exam' : 'Pack'}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: WebColors.purplePrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiRecommendationCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF352554),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Text('RECOMMENDED AI GENERATION', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 1)),
          ),
          const SizedBox(height: 20),
          Text('Advanced\nMacroeconomics\nPack', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2)),
          const SizedBox(height: 12),
          Text('Our AI has analyzed your recent lectures and synthesized a 3-part study bundle with specialized focus on Keynesian multipliers.', style: GoogleFonts.outfit(fontSize: 12, color: Colors.white70, height: 1.5)),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: widget.onCreatePack,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF352554), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Review &\nDeploy', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.white.withValues(alpha: 0.2)), padding: const EdgeInsets.symmetric(vertical: 24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Dismiss'),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildCreateNewCard({bool isMobile = false}) {
    return InkWell(
      onTap: _showExams ? widget.onCreateExam : widget.onCreatePack,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: WebColors.purplePrimary.withValues(alpha: 0.3), style: BorderStyle.none),
        ),
        child: CustomPaint(
          painter: DashedBorderPainter(color: WebColors.purplePrimary.withValues(alpha: 0.4)),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.add, color: WebColors.purplePrimary, size: 32),
                ),
                const SizedBox(height: 24),
                Text('Create New ${_showExams ? 'Exam' : 'Pack'}', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('Start from scratch or use AI generator', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  DashedBorderPainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
      
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(24)));
      
    // A proper dashed dash effect would require PathMetrics, but for simplicity:
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
