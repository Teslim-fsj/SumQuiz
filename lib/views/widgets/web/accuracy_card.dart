import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sumquiz/theme/web_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AccuracyCard extends StatelessWidget {
  final double accuracy; // 0.0 to 1.0
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
    final lowestPerc = (lowestAccuracy * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: WebColors.glassDecoration(
        blur: 12,
        opacity: 0.05,
        color: WebColors.surface,
        borderRadius: 24,
      ).copyWith(
        boxShadow: WebColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Accuracy (Last 7 Days)',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: WebColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              // Circular Chart
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: CircularProgressIndicator(
                        value: 1.0,
                        strokeWidth: 10,
                        color: WebColors.accent.withOpacity(0.1),
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: CircularProgressIndicator(
                        value: accuracy, // Dynamic
                        strokeWidth: 10,
                        color: WebColors.success,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Text(
                      '$percentage%',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: WebColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Stats
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatRow('Highest', '$highestPerc%'),
                  const SizedBox(height: 8),
                  _buildStatRow('Lowest', '$lowestPerc%'),
                ],
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.1);
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: GoogleFonts.outfit(
            color: WebColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.outfit(
            color: WebColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
