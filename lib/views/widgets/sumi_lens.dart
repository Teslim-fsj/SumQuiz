import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SumiLensMenu extends StatelessWidget {
  final Offset position;
  final Function(String action) onAction;

  const SumiLensMenu({
    super.key,
    required this.position,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Positioned(
      left: position.dx,
      top: position.dy - 70,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildActionItem(theme, 'Simplify', Icons.auto_awesome_rounded),
              _buildActionItem(theme, 'Explain', Icons.psychology_rounded),
              _buildActionItem(theme, 'Deep Dive', Icons.biotech_rounded),
              _buildActionItem(theme, 'Quiz', Icons.quiz_rounded),
              const SizedBox(width: 8),
              Container(
                width: 1,
                height: 20,
                color: theme.dividerColor.withOpacity(0.1),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () => onAction('more'),
                icon: Icon(Icons.more_horiz_rounded, size: 20, color: theme.hintColor),
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 200.ms).scale(
        alignment: Alignment.bottomCenter,
        begin: const Offset(0.9, 0.9), 
        curve: Curves.easeOutBack
      ),
    );
  }

  Widget _buildActionItem(ThemeData theme, String label, IconData icon) {
    return InkWell(
      onTap: () => onAction(label),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
