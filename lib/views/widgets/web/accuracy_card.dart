import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sumquiz/theme/web_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AccuracyCard extends StatelessWidget {
  final double accuracy;
  final double highestAccuracy;
  final double lowestAccuracy;

  const AccuracyCard({
    super.key,
    required this.accuracy,
    required this.highestAccuracy,
    required this.lowestAccuracy,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (accuracy * 100).toInt();
    final highestPerc = (highestAccuracy * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WebColors.border),
        boxShadow: WebColors.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$percentage%',
            style: GoogleFonts.outfit(
              fontSize: 48,
              fontWeight: FontWeight.w800,
              color: WebColors.purplePrimary,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'AVERAGE ACCURACY',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: WebColors.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text('Highest',
                  style: GoogleFonts.outfit(
                      fontSize: 14, color: WebColors.textSecondary)),
              const SizedBox(width: 12),
              Text(
                '$highestPerc%',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: WebColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: WebColors.backgroundAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: WebColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Consistency',
                    style: GoogleFonts.outfit(
                        fontSize: 13, color: WebColors.textSecondary)),
                Text('Master',
                    style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: WebColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: 100.ms)
        .slideY(begin: 0.05, curve: Curves.easeOut);
  }
}
