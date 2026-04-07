import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sumquiz/theme/web_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

class InteractivePreviewCard extends StatelessWidget {
  final String question;
  final VoidCallback? onClipPressed;
  final VoidCallback? onStartSession;

  const InteractivePreviewCard({
    super.key,
    required this.question,
    this.onClipPressed,
    this.onStartSession,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: WebColors.purplePrimary.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: WebColors.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: WebColors.purpleUltraLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: WebColors.purplePrimary.withOpacity(0.2)),
                ),
                child: Text(
                  'INSTANT FLASHCARD',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: WebColors.purplePrimary,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              InkWell(
                onTap: onClipPressed,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: WebColors.backgroundAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.content_copy_rounded,
                      size: 18, color: WebColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '"$question"',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontStyle: FontStyle.italic,
              color: WebColors.textPrimary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onStartSession,
              style: ElevatedButton.styleFrom(
                backgroundColor: WebColors.purplePrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Instant Start',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.05);
  }
}
