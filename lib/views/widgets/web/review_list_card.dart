import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (dueItems.isEmpty) {
      return _buildEmptyState(theme);
    }

    final displayItems = dueItems.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Active Curriculums',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.displayLarge?.color,
              ),
            ),
            TextButton(
              onPressed: onReviewAll,
              child: Text(
                'View Library',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
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
          final cardsDue = item.flashcards.length;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.school_rounded, color: theme.colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.displayLarge?.color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$cardsDue units ready for review',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: theme.hintColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                _buildPriorityBadge(theme, cardsDue),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: () => onReviewItem(item),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    foregroundColor: theme.colorScheme.primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Review',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: (100 * index).ms).slideX(begin: -0.05, end: 0);
        }),
      ],
    );
  }

  Widget _buildPriorityBadge(ThemeData theme, int count) {
    final isHigh = count > 10;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isHigh ? const Color(0xFFEF4444).withOpacity(0.08) : theme.dividerColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        isHigh ? 'HIGH PRIORITY' : 'ROUTINE',
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: isHigh ? const Color(0xFFEF4444) : theme.hintColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.auto_awesome_motion_rounded,
                size: 48, color: theme.hintColor.withOpacity(0.2)),
            const SizedBox(height: 24),
            Text(
              'Library Synchronized',
              style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.displayLarge?.color),
            ),
            const SizedBox(height: 8),
            Text(
              'All your curriculums are up to date.',
              style: GoogleFonts.inter(fontSize: 14, color: theme.hintColor),
            ),
          ],
        ),
      ),
    );
  }
}
