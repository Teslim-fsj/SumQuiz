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
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Text(
            'Choose Your Knowledge Source',
            style: GoogleFonts.outfit(
              fontSize: 44,
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
          const SizedBox(height: 60),

          // Top row: 3 cards
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SourceCard(
                  title: 'Doc / PDF',
                  description: 'Upload textbooks, research papers, or study guides for deep structural analysis.',
                  icon: Icons.description_outlined,
                  buttonText: 'UPLOAD FILES',
                  accentColor: const Color(0xFF3300FF),
                  onPressed: onUploadFiles,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _SourceCard(
                  title: 'Text / Quick Topic',
                  description: 'Paste raw text or just type a subject to let the AI build a comprehensive study set.',
                  icon: Icons.edit_note_rounded,
                  buttonText: 'WRITE NOW',
                  accentColor: const Color(0xFF7C4DFF),
                  onPressed: onWriteNow,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _SourceCard(
                  title: 'YouTube / Web Link',
                  description: 'Convert educational videos or online articles into interactive quizzes instantly.',
                  icon: Icons.language_rounded,
                  buttonText: 'IMPORT URL',
                  accentColor: const Color(0xFF4A90E2),
                  onPressed: onImportUrl,
                  showVideoPreview: true,
                ),
              ),
            ],
          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.05, end: 0),

          const SizedBox(height: 24),

          // Bottom row: 2 cards
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SourceCard(
                  title: 'Images / Snap',
                  description: 'Snap a photo of your handwritten notes or whiteboards to digitize your learning.',
                  icon: Icons.camera_alt_outlined,
                  buttonText: 'SCAN PAGE',
                  accentColor: const Color(0xFF7C4DFF),
                  onPressed: onScanPage,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _SourceCard(
                  title: 'Audio',
                  description: 'Upload lecture recordings or voice memos. Perfect for auditory learners.',
                  icon: Icons.mic_none_rounded,
                  buttonText: 'LISTEN & LEARN',
                  accentColor: const Color(0xFF7C4DFF),
                  onPressed: onListenAndLearn,
                ),
              ),
              const SizedBox(width: 24),
              // Invisible spacer to maintain grid alignment
              const Expanded(child: SizedBox()),
            ],
          ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.05, end: 0),

          const SizedBox(height: 48),

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
      ),
    );
  }
}

class _SourceCard extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final String buttonText;
  final Color accentColor;
  final VoidCallback onPressed;
  final bool showVideoPreview;

  const _SourceCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.buttonText,
    required this.accentColor,
    required this.onPressed,
    this.showVideoPreview = false,
  });

  @override
  State<_SourceCard> createState() => _SourceCardState();
}

class _SourceCardState extends State<_SourceCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _isHovered ? widget.accentColor.withValues(alpha: 0.3) : const Color(0xFFE8ECF4),
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? widget.accentColor.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.03),
                blurRadius: _isHovered ? 30 : 20,
                offset: Offset(0, _isHovered ? 12 : 8),
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
                  color: widget.accentColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(widget.icon, color: widget.accentColor, size: 28),
              ),
              const SizedBox(height: 24),
              Text(
                widget.title,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.description,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF666666),
                ),
              ),
              if (widget.showVideoPreview) ...[
                const SizedBox(height: 20),
                Container(
                  height: 100,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0720),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              TextButton(
                onPressed: widget.onPressed,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.buttonText,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: widget.accentColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 16, color: widget.accentColor),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
