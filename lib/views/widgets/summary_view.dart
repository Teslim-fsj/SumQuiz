import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class SummaryView extends StatelessWidget {
  final String title;
  final String content;
  final List<String> tags;
  final VoidCallback? onCopy;
  final VoidCallback? onGenerateQuiz;
  final bool showActions;

  const SummaryView({
    super.key,
    required this.title,
    required this.content,
    required this.tags,
    this.onCopy,
    this.onGenerateQuiz,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.displayLarge?.color,
              height: 1.2,
            ),
          ).animate().fadeIn().slideY(begin: 0.1, end: 0),

          const SizedBox(height: 16),

          // Tags
          if (tags.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((tag) {
                final cleanTag = tag.startsWith('#') ? tag : '#$tag';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    cleanTag,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF0D9488),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
            ).animate().fadeIn(delay: 100.ms),

          const SizedBox(height: 32),

          // Action Row
          if (showActions) ...[
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.copy_rounded,
                    label: 'Copy',
                    onTap: onCopy,
                    theme: theme,
                  ),
                ),
                if (onGenerateQuiz != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: onGenerateQuiz,
                      icon: const Icon(Icons.quiz_rounded, size: 18),
                      label: Text('Practice Quiz', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ],
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 32),
            Divider(color: theme.dividerColor.withOpacity(0.1)),
            const SizedBox(height: 32),
          ],

          // Content
          MarkdownBody(
            data: content,
            selectable: true,
            styleSheet: MarkdownStyleSheet(
              p: GoogleFonts.inter(fontSize: 16, height: 1.7, color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8)),
              h1: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, height: 2),
              h2: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, height: 1.8),
              h3: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, height: 1.6),
              listBullet: GoogleFonts.inter(fontSize: 16, color: const Color(0xFF0D9488)),
            ),
          ).animate().fadeIn(delay: showActions ? 300.ms : 200.ms),
          
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback? onTap, required ThemeData theme}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: theme.hintColor),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: theme.hintColor)),
          ],
        ),
      ),
    );
  }
}
