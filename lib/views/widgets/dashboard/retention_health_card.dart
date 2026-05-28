import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

class RetentionHealthCard extends StatelessWidget {
  final double score;
  final VoidCallback onTap;

  const RetentionHealthCard({
    super.key,
    required this.score,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Retention Mastery',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.displayLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Long-term memory stability',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: theme.hintColor,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.psychology_rounded,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  (score * 100).toStringAsFixed(0),
                  style: GoogleFonts.outfit(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    color: theme.colorScheme.onSurface,
                  ),
                ).animate().scale(
                    begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6.0, left: 4),
                  child: Text(
                    '%',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Stack(
              children: [
                Container(
                  height: 8,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: score.clamp(0.0, 1.0),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.primary.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ).animate().fadeIn().scaleX(
                      begin: 0,
                      alignment: Alignment.centerLeft,
                      duration: 1.seconds,
                      curve: Curves.easeOutCubic),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
