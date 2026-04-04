import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:sumquiz/theme/web_theme.dart';

class WebSummaryView extends StatelessWidget {
  final String title;
  final String content;
  final List<String> tags;
  final String? shareUrl;
  final int flashcardCount;
  final VoidCallback? onReviewList;

  const WebSummaryView({
    super.key,
    required this.title,
    required this.content,
    required this.tags,
    this.flashcardCount = 0,
    this.shareUrl,
    this.onReviewList,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tags
          if (tags.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((tag) => _buildTag(tag, context)).toList(),
            ).animate().fadeIn().slideX(begin: -0.1),
          
          const SizedBox(height: 24),

          // Title
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : WebColors.textPrimary,
              height: 1.2,
            ),
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),

          const SizedBox(height: 24),

          // Share Link Component
          _buildShareLink(context),
          
          const SizedBox(height: 48),

          // Summary Content
          _buildMarkdownContent(context),

          const SizedBox(height: 64),

          // Bottom Cards
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildKeyTermsCard(context),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildVisualContextCard(context),
              ),
            ],
          ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1),
        ],
      ),
    );
  }

  Widget _buildTag(String tag, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: WebColors.backgroundAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WebColors.border),
      ),
      child: Text(
        tag.startsWith('#') ? tag : '#$tag',
        style: GoogleFonts.outfit(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: WebColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildShareLink(BuildContext context) {
    final displayUrl = shareUrl ?? 'sunquiz.ai/shared/ph-syn-2024-energetics';
    return Container(
      width: 450,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: WebColors.backgroundAlt.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WebColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              displayUrl,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: WebColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: displayUrl));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Link copied to clipboard')),
              );
            },
            icon: const Icon(Icons.copy_all_rounded, size: 16),
            label: Text(
              'Copy Link',
              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: WebColors.primary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: WebColors.border),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkdownContent(BuildContext context) {
    final theme = Theme.of(context);
    return MarkdownBody(
      data: content,
      selectable: true,
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: GoogleFonts.outfit(
          fontSize: 18,
          height: 1.8,
          color: WebColors.textPrimary.withValues(alpha: 0.9),
        ),
        strong: const TextStyle(fontWeight: FontWeight.w800, color: WebColors.primary),
        h1: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, height: 2),
        h2: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w700, height: 1.8),
        listBullet: TextStyle(color: WebColors.primary, fontSize: 18),
      ),
    );
  }

  Widget _buildKeyTermsCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: WebColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded, color: Colors.white, size: 32),
          const SizedBox(height: 24),
          Text(
            'Key Terms Extracted',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$flashcardCount fundamental concepts identified for your flashcards.',
            style: GoogleFonts.outfit(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: onReviewList,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'REVIEW LIST',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w800, letterSpacing: 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualContextCard(BuildContext context) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        image: const DecorationImage(
          image: NetworkImage('https://images.unsplash.com/photo-1550989460-0adf9ea622e2?q=80&w=1000'),
          fit: BoxFit.cover,
        ),
        boxShadow: WebColors.cardShadow,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
        ),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'VISUAL CONTEXT',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white.withValues(alpha: 0.6),
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Thylakoid Membrane Structure',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
