import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:sumquiz/models/public_deck.dart';
import 'package:sumquiz/models/teacher_models.dart';
import 'package:sumquiz/theme/web_theme.dart';

class ContentManager extends StatefulWidget {
  final List<PublicDeck> content;
  final Map<String, ContentAnalytics> analytics;
  final Function(PublicDeck) onEdit;
  final Function(PublicDeck) onDelete;
  final VoidCallback onCreateExam;
  final VoidCallback onCreatePack;

  const ContentManager({
    super.key,
    required this.content,
    required this.analytics,
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

  @override
  Widget build(BuildContext context) {
    final filteredContent = widget.content.where((c) => 
      c.title.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();

    final exams = filteredContent.where((c) => c.isExam).toList();
    final packs = filteredContent.where((c) => !c.isExam).toList();
    
    final displayedItems = _showExams ? exams : packs;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopBanner(),
          const SizedBox(height: 40),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 1, child: _buildSidebar(packs.length, exams.length)),
              const SizedBox(width: 40),
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

  Widget _buildTopBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF2E1A47), const Color(0xFF1E112A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text('CURRICULUM INTELLIGENCE', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 1.5)),
                ),
                const SizedBox(height: 24),
                Text(
                  'Master Your Academic\nContent Lifecycle.',
                  style: GoogleFonts.outfit(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1),
                ),
                const SizedBox(height: 16),
                Text(
                  'Orchestrate comprehensive study pathways. Convert\nlectures into quizzes, flashcards, and formal examinations\nwith AI-driven insights.',
                  style: GoogleFonts.outfit(fontSize: 16, color: Colors.white70, height: 1.5),
                ),
              ],
            ),
          ),
          Column(
            children: [
              _bannerStatCard('TOTAL MATERIALS', '${widget.content.length}'),
              const SizedBox(height: 16),
              _bannerStatCard('ACTIVE STUDENTS', '1.2k'),
            ],
          )
        ],
      ),
    );
  }
  
  Widget _bannerStatCard(String label, String value) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1)),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildSidebar(int packsCount, int examsCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSearchBar(),
        const SizedBox(height: 32),
        Text('CONTENT ENGINE', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 1)),
        const SizedBox(height: 16),
        _sidebarMenuButton('Study Packs', packsCount, !_showExams, () => setState(() => _showExams = false)),
        const SizedBox(height: 8),
        _sidebarMenuButton('Exams', examsCount, _showExams, () => setState(() => _showExams = true)),
        const SizedBox(height: 40),
        
        Text('STATUS FILTER', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 1)),
        const SizedBox(height: 16),
        _buildCheckbox('Published', widget.content.length, true),
        const SizedBox(height: 8),
        _buildCheckbox('Drafts', 0, false),
        
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.all(24),
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

  Widget _buildSearchBar() {
    return Container(
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

  Widget _sidebarMenuButton(String label, int count, bool isActive, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isActive ? WebColors.purplePrimary : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isActive ? WebColors.purplePrimary : const Color(0xFFE5E7EB)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.outfit(fontSize: 14, fontWeight: isActive ? FontWeight.bold : FontWeight.w600, color: isActive ? Colors.white : const Color(0xFF1F1F1F))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: isActive ? Colors.white.withOpacity(0.2) : const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
              child: Text('$count', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: isActive ? Colors.white : Colors.grey[700])),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckbox(String label, int count, bool isChecked) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: isChecked,
            onChanged: (v) {},
            activeColor: WebColors.purplePrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
        const SizedBox(width: 8),
        Text('$label ($count)', style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[800], fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildMainContentArea(List<PublicDeck> displayedItems) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_showExams ? 'Current Exams' : 'Current Study Packs', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w900)),
                Text('Managing ${displayedItems.length} active academic bundles', style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[600])),
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
        const SizedBox(height: 32),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 24,
            mainAxisSpacing: 24,
            childAspectRatio: 0.95,
          ),
          itemCount: displayedItems.length + 2, // adding creation/AI cards
          itemBuilder: (context, i) {
            if (i == displayedItems.length) {
              return _buildAiRecommendationCard();
            } else if (i == displayedItems.length + 1) {
              return _buildCreateNewCard();
            }
            return _contentCard(displayedItems[i]);
          },
        ),
      ],
    );
  }

  Widget _contentCard(PublicDeck deck) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: WebColors.cardShadow,
        border: Border.all(color: WebColors.border.withOpacity(0.5)),
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFEEF2FF), shape: BoxShape.circle),
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
          const SizedBox(height: 24),
          Text(deck.title, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Text('Updated ${DateFormat.MMMd().format(deck.publishedAt)}', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[500])),
          
          if (!deck.isExam) ...[
             const SizedBox(height: 24),
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
              if (true)
                 Text('${(widget.analytics[deck.id]?.engagementRate ?? 0).toStringAsFixed(1)}k active enrollments', style: GoogleFonts.outfit(color: WebColors.purplePrimary, fontWeight: FontWeight.bold, fontSize: 11))
              else
                 Expanded(
                   child: ElevatedButton(
                     onPressed: () => widget.onEdit(deck),
                     style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF1F1F1F), elevation: 0, side: const BorderSide(color: Color(0xFFE5E7EB)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                     child: const Text('Continue Editing'),
                   ),
                 ),
              
              Row(
                children: [
                  if (true) ...[
                     IconButton(icon: const Icon(Icons.share, size: 18, color: Colors.grey), onPressed: () {}),
                     IconButton(icon: const Icon(Icons.edit, size: 18, color: Colors.grey), onPressed: () => widget.onEdit(deck)),
                  ] else ...[
                     Container(decoration: const BoxDecoration(color: WebColors.purplePrimary, shape: BoxShape.circle), child: IconButton(icon: const Icon(Icons.play_arrow, color: Colors.white, size: 20), onPressed: () {})),
                  ]
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

  Widget _buildAiRecommendationCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF352554),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
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
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.white.withOpacity(0.2)), padding: const EdgeInsets.symmetric(vertical: 24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Dismiss'),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildCreateNewCard() {
    return InkWell(
      onTap: _showExams ? widget.onCreateExam : widget.onCreatePack,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: WebColors.purplePrimary.withOpacity(0.3), style: BorderStyle.none),
        ),
        child: CustomPaint(
          painter: DashedBorderPainter(color: WebColors.purplePrimary.withOpacity(0.4)),
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
