import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sumquiz/theme/web_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sumquiz/models/local_flashcard_set.dart';

class ReviewListCard extends StatelessWidget {
  final int dueCount;
  final List<LocalFlashcardSet> dueItems;
  final VoidCallback onReviewAll;
  final Function(LocalFlashcardSet) onReviewItem;

  const ReviewListCard({
    super.key,
    required this.dueCount,
    required this.dueItems,
    required this.onReviewAll,
    required this.onReviewItem,
  });

  static const List<IconData> _subjectIcons = [
    Icons.biotech_rounded,
    Icons.calculate_rounded,
    Icons.language_rounded,
    Icons.science_rounded,
    Icons.history_edu_rounded,
  ];

  static const List<Color> _iconColors = [
    WebColors.purplePrimary,
    Color(0xFF3B82F6),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEC4899),
  ];

  @override
  Widget build(BuildContext context) {
    if (dueItems.isEmpty) {
      return _buildEmptyState();
    }

    final displayItems = dueItems.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Active Curriculums',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: WebColors.textPrimary,
              ),
            ),
            TextButton(
              onPressed: onReviewAll,
              child: Text(
                'View All Library',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  color: WebColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...displayItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final icon = _subjectIcons[index % _subjectIcons.length];
          final iconColor = _iconColors[index % _iconColors.length];
          final cardsDue = item.flashcards.length;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: WebColors.border),
              boxShadow: WebColors.subtleShadow,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: WebColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.flashcards.length} cards available',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: WebColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cardsDue > 0
                        ? WebColors.purpleUltraLight
                        : WebColors.backgroundAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$cardsDue ITEMS DUE',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: cardsDue > 0
                          ? WebColors.purplePrimary
                          : WebColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => onReviewItem(item),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WebColors.backgroundAlt,
                    foregroundColor: WebColors.textPrimary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Start',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(delay: (150 * index).ms)
              .slideX(begin: -0.05);
        }),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WebColors.border),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.library_books_rounded,
                size: 48, color: WebColors.textTertiary),
            const SizedBox(height: 12),
            Text(
              'No study sets yet',
              style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: WebColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              'Create flashcard sets to see them here',
              style: GoogleFonts.outfit(
                  fontSize: 14, color: WebColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
