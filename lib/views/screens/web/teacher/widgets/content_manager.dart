import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:sumquiz/models/public_deck.dart';
import 'package:sumquiz/models/teacher_models.dart';
import 'package:sumquiz/theme/web_theme.dart';
import 'shared_teacher_widgets.dart';

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
  
  @override
  Widget build(BuildContext context) {
    final filteredContent = widget.content.where((c) => 
      c.title.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();

    final exams = filteredContent.where((c) => c.isExam).toList();
    final packs = filteredContent.where((c) => !c.isExam).toList();

    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(40, 40, 40, 0),
            child: Row(
              children: [
                Expanded(
                  child: SharedTeacherWidgets.moduleHeader(
                    'Content', 
                    'Manage your exams and study packs'
                  ),
                ),
                _buildSearchBar(),
                const SizedBox(width: 24),
                ElevatedButton.icon(
                  onPressed: widget.onCreateExam,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Exam'),
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14)),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: widget.onCreatePack,
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Study Pack'),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14)),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'Exams'),
                Tab(text: 'Study Packs'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildContentGrid(exams),
                _buildContentGrid(packs),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      width: 300,
      height: 44,
      decoration: BoxDecoration(
        color: WebColors.backgroundAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WebColors.border),
      ),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Search content...',
          hintStyle: GoogleFonts.outfit(fontSize: 13, color: WebColors.textTertiary),
          prefixIcon: const Icon(Icons.search, size: 18, color: WebColors.textTertiary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildContentGrid(List<PublicDeck> items) {
    if (items.isEmpty) {
      return Center(
          child: SharedTeacherWidgets.emptyHint('No content here yet. Create your first piece!'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(40),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 1.3,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => _contentCard(items[i]),
    );
  }

  Widget _contentCard(PublicDeck deck) {
    final a = widget.analytics[deck.id];
    return Container(
      decoration: WebColors.glassDecoration(
        blur: 15,
        opacity: 0.1,
        color: WebColors.surface,
        borderRadius: 20,
      ).copyWith(
        boxShadow: WebColors.cardShadow,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (deck.isExam ? WebColors.purplePrimary : WebColors.secondary)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  deck.isExam
                      ? Icons.assignment_outlined
                      : Icons.library_books_outlined,
                  color:
                      deck.isExam ? WebColors.purplePrimary : WebColors.secondary,
                  size: 18,
                ),
              ),
              const Spacer(),
              SharedTeacherWidgets.badge(deck.isExam ? 'Exam' : 'Pack',
                  deck.isExam ? WebColors.purplePrimary : WebColors.secondary),
            ],
          ),
          const SizedBox(height: 12),
          Text(deck.title,
              style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: WebColors.textPrimary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          Text(DateFormat.yMMMd().format(deck.publishedAt),
              style: GoogleFonts.outfit(
                  fontSize: 11, color: WebColors.textTertiary)),
          const Spacer(),
          if (a != null) ...[
            Row(
              children: [
                _miniStat(Icons.group_outlined, '${a.numberOfAttempts}'),
                const SizedBox(width: 12),
                _miniStat(Icons.star_outline, '${a.averageScore.toStringAsFixed(0)}%'),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showShareModal(deck),
                  icon: const Icon(Icons.share_outlined, size: 14),
                  label: const Text('Share'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => widget.onEdit(deck),
                icon: const Icon(Icons.edit_outlined, size: 16),
                tooltip: 'Edit',
                style: IconButton.styleFrom(
                    backgroundColor: WebColors.backgroundAlt),
              ),
              IconButton(
                onPressed: () => widget.onDelete(deck),
                icon: const Icon(Icons.delete_outline, size: 16,
                    color: WebColors.error),
                tooltip: 'Delete',
                style: IconButton.styleFrom(
                    backgroundColor: WebColors.error.withValues(alpha: 0.08)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showShareModal(PublicDeck deck) {
    final link = 'https://sumquiz.xyz/s/${deck.shareCode}';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Share: ${deck.title}',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _shareRow('Code', deck.shareCode, Icons.tag),
            const SizedBox(height: 16),
            _shareRow('Link', link, Icons.link),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: WebColors.backgroundAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(Icons.qr_code_2, size: 80),
                  const SizedBox(height: 8),
                  Text(link,
                      style: GoogleFonts.outfit(
                          fontSize: 11, color: WebColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _shareRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: WebColors.textSecondary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.outfit(
                    fontSize: 10,
                    color: WebColors.textTertiary,
                    fontWeight: FontWeight.w600)),
            Text(value,
                style: GoogleFonts.outfit(
                    fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.copy, size: 16),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$label copied!')),
            );
          },
        ),
      ],
    );
  }

  Widget _miniStat(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 12, color: WebColors.textTertiary),
        const SizedBox(width: 4),
        Text(value,
            style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: WebColors.textSecondary)),
      ],
    );
  }
}
