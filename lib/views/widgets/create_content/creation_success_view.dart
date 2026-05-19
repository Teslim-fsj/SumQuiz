import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sumquiz/widgets/sumi_mascot.dart';
import 'package:sumquiz/models/sumi_emotion.dart';

class CreationSuccessView extends StatelessWidget {
  final String title;
  final VoidCallback onViewPack;
  final VoidCallback onReset;

  const CreationSuccessView({
    super.key,
    required this.title,
    required this.onViewPack,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.primary.withValues(alpha: 0.05),
            theme.scaffoldBackgroundColor,
          ],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Celebratory Mascot
              const SumiMascot(
                state: SumiState.celebrating,
                size: 200,
                dialogue: "We did it! Your study materials are ready.",
              ).animate().scale(duration: 800.ms, curve: Curves.elasticOut),
              const SizedBox(height: 48),
              Text(
                'Neural Pack Complete!',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
              const SizedBox(height: 16),
              Text(
                'Sumi has structured your materials for:',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurfaceVariant,
                ),
              ).animate().fadeIn(delay: 400.ms),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.primary,
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: 500.ms)
                  .scale(begin: const Offset(0.8, 0.8)),
              const SizedBox(height: 56),
              // Primary Action
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onViewPack,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 8,
                    shadowColor: colorScheme.primary.withValues(alpha: 0.4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.rocket_launch_rounded),
                      const SizedBox(width: 12),
                      Text(
                        'Enter Study Mode',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.2, end: 0),
              const SizedBox(height: 20),
              // Secondary Action
              TextButton(
                onPressed: onReset,
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                ),
                child: Text(
                  'Create Another Neural Pack',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ).animate().fadeIn(delay: 900.ms),
            ],
          ),
        ),
      ),
    );
  }
}
