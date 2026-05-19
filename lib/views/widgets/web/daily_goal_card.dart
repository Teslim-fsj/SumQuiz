import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

class DailyGoalCard extends StatelessWidget {
  final int goalMinutes;
  final int timeSpentMinutes;

  const DailyGoalCard({
    super.key,
    required this.goalMinutes,
    required this.timeSpentMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = goalMinutes > 0
        ? (timeSpentMinutes / goalMinutes).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 8,
                    color: theme.colorScheme.primary.withOpacity(0.05),
                  ),
                ),
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                    color: theme.colorScheme.primary,
                    strokeCap: StrokeCap.round,
                  ),
                ).animate().scale(
                    begin: const Offset(0.9, 0.9),
                    duration: 1.seconds,
                    curve: Curves.easeOutBack),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$timeSpentMinutes',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: theme.textTheme.displayLarge?.color,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      'MIN',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: theme.hintColor,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Commitment',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.displayLarge?.color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'You\'ve achieved $timeSpentMinutes out of $goalMinutes minutes today.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: theme.hintColor,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildBadge(theme, 'INTENSE', const Color(0xFFF59E0B)),
                    const SizedBox(width: 12),
                    _buildBadge(theme, 'FOCUSED', const Color(0xFF0D9488)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: 200.ms)
        .slideY(begin: 0.05, end: 0);
  }

  Widget _buildBadge(ThemeData theme, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
