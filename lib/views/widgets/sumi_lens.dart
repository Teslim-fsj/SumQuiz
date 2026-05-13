import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/cyber_neural_theme.dart';

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
    return Positioned(
      left: position.dx,
      top: position.dy - 60,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: CyberNeuralColors.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: CyberNeuralColors.cyan.withValues(alpha: 0.1),
                blurRadius: 10,
                spreadRadius: -2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildActionItem(context, 'Simplify', Icons.auto_awesome),
              _buildActionItem(context, 'Explain', Icons.psychology),
              _buildActionItem(context, 'Deep Dive', Icons.biotech),
              _buildActionItem(context, 'Quiz', Icons.quiz),
              const SizedBox(width: 8),
              Container(
                width: 1,
                height: 20,
                color: Colors.white10,
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () => onAction('more'),
                icon: const Icon(Icons.more_horiz, size: 18, color: Colors.white70),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 200.ms).scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack),
    );
  }

  Widget _buildActionItem(BuildContext context, String label, IconData icon) {
    return InkWell(
      onTap: () => onAction(label),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: CyberNeuralColors.cyan),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
