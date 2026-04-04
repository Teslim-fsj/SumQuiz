import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WebProgressHeader extends StatelessWidget {
  final String userName;
  final int weeklyGoalPercentage;
  final VoidCallback onDownloadReport;

  const WebProgressHeader({
    super.key,
    required this.userName,
    required this.weeklyGoalPercentage,
    required this.onDownloadReport,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Keep it up, $userName! 👋',
                  style: GoogleFonts.outfit(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'You are on track to beat your weekly goal by ',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '$weeklyGoalPercentage%.',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        color: const Color(0xFF6366F1),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Row(
              children: [
                _buildDateBadge(),
                const SizedBox(width: 16),
                _buildDownloadButton(),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        'Week of Oct 24', // Placeholder date
        style: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF475569),
        ),
      ),
    );
  }

  Widget _buildDownloadButton() {
    return ElevatedButton(
      onPressed: onDownloadReport,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4338CA),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      child: Text(
        'Download Report',
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }
}
