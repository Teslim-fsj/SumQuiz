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

  @override
  Widget build(BuildContext context) {
    if (dueCount == 0) return const SizedBox();

    final displayItems = dueItems.take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.access_time_filled_rounded,
                    color: WebColors.accent, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Due for Review',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: WebColors.textPrimary,
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: onReviewAll,
              child: Text(
                'Review All ($dueCount)',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  color: WebColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: displayItems.map((item) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: GestureDetector(
                  onTap: () => onReviewItem(item),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: WebColors.border),
                      boxShadow: WebColors.subtleShadow,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: WebColors.pinkAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.style_rounded,
                              color: WebColors.pinkAccent),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: WebColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                                Text(
                                  '${item.flashcards.length} cards due',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    color: WebColors.pinkAccent,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: WebColors.textTertiary),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1);
  }
}
