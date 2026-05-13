import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/cyber_neural_theme.dart';

class GhostLinkIndicator extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const GhostLinkIndicator({
    super.key,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: CyberNeuralColors.cyan.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: CyberNeuralColors.cyan.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link, size: 10, color: CyberNeuralColors.cyan),
            const SizedBox(width: 4),
            Text(
              'GHOST LINK',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: CyberNeuralColors.cyan,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().shimmer(color: Colors.white.withValues(alpha: 0.1));
  }
}
