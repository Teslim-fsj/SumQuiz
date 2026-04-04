import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

class WebSourceSelection extends StatelessWidget {
  final Function(String type) onTranslate;
  final VoidCallback onUploadFiles;
  final VoidCallback onWriteNow;
  final VoidCallback onImportUrl;
  final VoidCallback onScanPage;
  final VoidCallback onListenAndLearn;

  const WebSourceSelection({
    super.key,
    required this.onTranslate,
    required this.onUploadFiles,
    required this.onWriteNow,
    required this.onImportUrl,
    required this.onScanPage,
    required this.onListenAndLearn,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 60),
        Text(
          'Choose Your Knowledge Source',
          style: GoogleFonts.outfit(
            fontSize: 48,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1A1A1A),
            height: 1.1,
          ),
        ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0),
        const SizedBox(height: 16),
        Text(
          'Transform any information into mastery. Select your material to begin\nthe generation process.',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF666666),
            height: 1.5,
          ),
        ).animate().fadeIn(delay: 200.ms),
        const SizedBox(height: 80),
        
        // Grid of Sources
        Expanded(
          child: SingleChildScrollView(
            child: Wrap(
                spacing: 40,
                runSpacing: 40,
                alignment: WrapAlignment.center,
                children: [
                  _SourceCard(
                    title: 'Doc / PDF',
                    description: 'Upload textbooks, research papers, or study guides for deep structural analysis.',
                    icon: Icons.description_outlined,
                    buttonText: 'UPLOAD FILES',
                    accentColor: const Color(0xFFFF4B4B),
                    onPressed: onUploadFiles,
                  ),
                  _SourceCard(
                    title: 'Text / Quick Topic',
                    description: 'Paste raw text or just type a subject to let the AI build a comprehensive study set.',
                    icon: Icons.edit_note_rounded,
                    buttonText: 'WRITE NOW',
                    accentColor: const Color(0xFF7C4DFF),
                    onPressed: onWriteNow,
                  ),
                  _SourceCard(
                    title: 'YouTube / Web Link',
                    description: 'Convert educational videos or online articles into interactive quizzes instantly.',
                    icon: Icons.language_rounded,
                    buttonText: 'IMPORT URL',
                    accentColor: const Color(0xFF4A90E2),
                    onPressed: onImportUrl,
                    isLarge: true,
                  ),
                  _SourceCard(
                    title: 'Images / Snap',
                    description: 'Snap a photo of your handwritten notes or whiteboards to digitize your learning.',
                    icon: Icons.camera_alt_outlined,
                    buttonText: 'SCAN PAGE',
                    accentColor: const Color(0xFF7C4DFF),
                    onPressed: onScanPage,
                  ),
                  _SourceCard(
                    title: 'Audio',
                    description: 'Upload lecture recordings or voice memos. Perfect for auditory learners.',
                    icon: Icons.mic_none_rounded,
                    buttonText: 'LISTEN & LEARN',
                    accentColor: const Color(0xFF7C4DFF),
                    onPressed: onListenAndLearn,
                  ),
                ],
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.05, end: 0),
          ),
        ),
        
        // Footer Status
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F2FF).withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF7C4DFF),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'AI Engine Status: ',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF666666),
                ),
              ),
              Text(
                'Ready to ingest new data',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF3300FF),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 800.ms),
        const SizedBox(height: 40),
      ],
    );
  }
}

class _SourceCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final String buttonText;
  final Color accentColor;
  final VoidCallback onPressed;
  final bool isLarge;

  const _SourceCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.buttonText,
    required this.accentColor,
    required this.onPressed,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isLarge ? 320 : 300,
      height: 440,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: accentColor, size: 28),
          ),
          const SizedBox(height: 40),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: GoogleFonts.outfit(
              fontSize: 16,
              height: 1.5,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF666666),
            ),
          ),
          const Spacer(),
          if (isLarge) ...[
             Container(
               height: 140,
               width: double.infinity,
               decoration: BoxDecoration(
                 color: const Color(0xFF0F0720),
                 borderRadius: BorderRadius.circular(16),
               ),
               child: Center(
                 child: Container(
                   width: 48,
                   height: 48,
                   decoration: BoxDecoration(
                     color: Colors.white.withValues(alpha: 0.2),
                     shape: BoxShape.circle,
                   ),
                   child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                 ),
               ),
             ),
             const SizedBox(height: 24),
          ],
          TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  buttonText,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 18, color: accentColor),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
