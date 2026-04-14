import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WebFeatureInfoCards extends StatelessWidget {
  const WebFeatureInfoCards({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildInfoCard(
          icon: Icons.lightbulb_outline_rounded,
          title: 'Did you know?',
          subtitle: 'You can import PDF, EPUB, or web links directly to generate instant summaries and flashcards.',
          iconColor: const Color(0xFF6366F1),
          bgColor: const Color(0xFFEEF2FF),
        ),
        const SizedBox(width: 24),
        _buildInfoCard(
          icon: Icons.bolt_rounded,
          title: 'Fast Generation',
          subtitle: 'Our latest model processes 100+ pages of technical content in under 45 seconds.',
          iconColor: const Color(0xFFF59E0B),
          bgColor: const Color(0xFFFFF7ED),
        ),
        const SizedBox(width: 24),
        _buildInfoCard(
          icon: Icons.sync_rounded,
          title: 'Always Synced',
          subtitle: 'Your library stays updated across all devices, including mobile and desktop applications.',
          iconColor: const Color(0xFF10B981),
          bgColor: const Color(0xFFECFDF5),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: bgColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: bgColor.withOpacity(0.8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: const Color(0xFF64748B),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
