import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:sumquiz/theme/web_theme.dart';

class SharedTeacherWidgets {
  static Widget moduleHeader(String title, String subtitle, {bool isMobile = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: GoogleFonts.outfit(
                fontSize: isMobile ? 22 : 26,
                fontWeight: FontWeight.w900,
                color: WebColors.textPrimary)),
        const SizedBox(height: 4),
        Text(subtitle,
            style: GoogleFonts.outfit(
                fontSize: isMobile ? 12 : 14, color: WebColors.textSecondary)),
      ],
    );
  }

  static Widget sectionCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WebColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: WebColors.textSecondary),
              const SizedBox(width: 10),
              Text(title,
                  style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: WebColors.textPrimary)),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: WebColors.border),
          ),
          child,
        ],
      ),
    );
  }

  static Widget badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: GoogleFonts.outfit(
              fontSize: 10, fontWeight: FontWeight.w800, color: color)),
    );
  }

  static Widget emptyHint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(text,
          style: GoogleFonts.outfit(
              fontSize: 13,
              color: WebColors.textTertiary,
              fontStyle: FontStyle.italic)),
    );
  }

  static Widget emptyCard(String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WebColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 48, color: WebColors.textTertiary),
          const SizedBox(height: 16),
          Text(title,
              style: GoogleFonts.outfit(
                  fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(subtitle,
              style: GoogleFonts.outfit(
                  fontSize: 14, color: WebColors.textSecondary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  static Widget scoreChip(double score) {
    final color = score >= 70
        ? WebColors.success
        : score >= 50
            ? WebColors.accentOrange
            : WebColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('${score.toStringAsFixed(0)}%',
          style: GoogleFonts.outfit(
              fontSize: 12, fontWeight: FontWeight.w800, color: color)),
    );
  }

  static String relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat.yMMMd().format(dt);
  }
}
