import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

class GenerationLoadingOverlay extends StatelessWidget {
  final String message;
  final String subMessage;
  final VoidCallback? onCancel;

  const GenerationLoadingOverlay({
    super.key,
    this.message = 'Generating Content...',
    this.subMessage = 'Processing with AI...',
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Positioned.fill(
      child: Container(
        color: isDark 
            ? Colors.black.withOpacity(0.7)
            : theme.scaffoldBackgroundColor.withOpacity(0.8),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: isDark ? 0.2 : 0.8),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Spinning Gradient Ring
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primary.withOpacity(0.1),
                        ),
                      ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds),
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: CircularProgressIndicator(
                          strokeWidth: 4,
                          valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                          backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                        ),
                      ),
                      Icon(Icons.auto_awesome, color: theme.colorScheme.primary, size: 24)
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scaleXY(begin: 0.8, end: 1.2, duration: 1.seconds),
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  Text(
                    message,
                    style: GoogleFonts.outfit(
                      color: theme.textTheme.headlineMedium?.color,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ).animate(onPlay: (c) => c.repeat()).shimmer(
                        duration: 3.seconds,
                        color: theme.colorScheme.primary.withOpacity(0.2),
                      ),
                      
                  const SizedBox(height: 12),
                  
                  Text(
                    subMessage,
                    style: GoogleFonts.outfit(
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  if (onCancel != null) ...[
                    const SizedBox(height: 32),
                    TextButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: Text(
                        'Cancel',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        backgroundColor: Colors.redAccent.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                    ).animate().fadeIn(delay: 2.seconds),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}
