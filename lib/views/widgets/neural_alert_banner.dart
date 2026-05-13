import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/cyber_neural_theme.dart';

class NeuralAlertBanner extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback? onIgnore;
  final VoidCallback? onAction;
  final String actionLabel;

  const NeuralAlertBanner({
    super.key,
    required this.title,
    required this.description,
    this.onIgnore,
    this.onAction,
    this.actionLabel = "SHIELD NODES",
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: CyberNeuralColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: CyberNeuralColors.alert.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: CyberNeuralColors.alert.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Alert Accent Bar
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: Container(color: CyberNeuralColors.alert),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: CyberNeuralColors.alert,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title.toUpperCase(),
                        style: GoogleFonts.jetBrainsMono(
                          color: CyberNeuralColors.alert.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onIgnore,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          "IGNORE",
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onAction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CyberNeuralColors.surfaceAlt,
                          foregroundColor: CyberNeuralColors.cyan,
                          side: BorderSide(color: CyberNeuralColors.cyan.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.shield_outlined, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              actionLabel,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1, end: 0);
  }
}
