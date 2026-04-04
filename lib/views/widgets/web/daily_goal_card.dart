import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sumquiz/theme/web_theme.dart';
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
    final progress =
        goalMinutes > 0 ? (timeSpentMinutes / goalMinutes).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WebColors.border),
        boxShadow: WebColors.subtleShadow,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            height: 90,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 90,
                  height: 90,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 8,
                    color: WebColors.purpleUltraLight,
                  ),
                ),
                SizedBox(
                  width: 90,
                  height: 90,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                    color: WebColors.purplePrimary,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$timeSpentMinutes',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: WebColors.textPrimary,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      'MINS',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: WebColors.textSecondary,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Study Goal',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: WebColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'You have studied for $timeSpentMinutes out of $goalMinutes minutes today.',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: WebColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildTag('Focus:', 'Deep'),
                    const SizedBox(width: 12),
                    _buildTag('Level:', 'High'),
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
        .slideY(begin: 0.05, curve: Curves.easeOut);
  }

  Widget _buildTag(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: WebColors.backgroundAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: WebColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: GoogleFonts.outfit(
                  fontSize: 12, color: WebColors.textSecondary)),
          const SizedBox(width: 4),
          Text(value,
              style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: WebColors.purplePrimary)),
        ],
      ),
    );
  }
}
