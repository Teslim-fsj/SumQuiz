import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/cyber_neural_theme.dart';

class CatchUpWidget extends StatelessWidget {
  final List<String> missedConcepts;

  const CatchUpWidget({
    super.key,
    required this.missedConcepts,
  });

  @override
  Widget build(BuildContext context) {
    if (missedConcepts.isEmpty) return const SizedBox.shrink();

    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CyberNeuralColors.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_toggle_off, size: 14, color: CyberNeuralColors.amber),
              const SizedBox(width: 8),
              Text(
                'RAPID RECAP',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: CyberNeuralColors.amber,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...missedConcepts.take(3).map((concept) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: CyberNeuralColors.amber,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    concept,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: CyberNeuralColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          )),
          const SizedBox(height: 8),
          Text(
            '30s rolling summary active',
            style: GoogleFonts.inter(
              fontSize: 9,
              fontStyle: FontStyle.italic,
              color: CyberNeuralColors.textTertiary,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1, end: 0);
  }
}
