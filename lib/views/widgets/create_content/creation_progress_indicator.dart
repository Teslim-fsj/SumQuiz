import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sumquiz/theme/web_theme.dart';

class CreationProgressIndicator extends StatelessWidget {
  final String message;
  final double? progress;

  const CreationProgressIndicator({
    super.key,
    required this.message,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Determine current pipeline step based on message
    int activeStep = 0;
    if (message.toLowerCase().contains('analyzing') || message.toLowerCase().contains('reading')) {
      activeStep = 0;
    } else if (message.toLowerCase().contains('generating') || message.toLowerCase().contains('creating')) {
      activeStep = 1;
    } else if (message.toLowerCase().contains('finalizing') || message.toLowerCase().contains('done') || message.toLowerCase().contains('complete')) {
      activeStep = 2;
    } else {
      activeStep = 1; // Default to middle step
    }

    return Stack(
      children: [
        // 1. Animated Background Blobs
        _buildBackgroundExtras(),
        
        // 2. Main Content
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark 
                  ? Colors.black.withOpacity(0.4) 
                  : Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // A. Premium Progress Ring
                    _buildPremiumRing(theme),
                    
                    const SizedBox(height: 40),
                    
                    // B. Strategic Messaging
                    _buildMainTitle(theme),
                    
                    const SizedBox(height: 32),
                    
                    // C. AI Synthesis Pipeline
                    _buildPipeline(theme, activeStep),
                    
                    const SizedBox(height: 24),
                    
                    // D. Detailed Status
                    Text(
                      message,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                        fontWeight: FontWeight.w500,
                      ),
                    ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds),
                  ],
                ),
              ),
            ),
          ),
        ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutCubic),
      ],
    );
  }

  Widget _buildBackgroundExtras() {
    return Stack(
      children: [
        Positioned(
          top: 100,
          right: -50,
          child: _buildBlob(const Color(0xFF6366F1), 300),
        ).animate(onPlay: (c) => c.repeat(reverse: true)).moveY(begin: 0, end: 100, duration: 10.seconds),
        Positioned(
          bottom: 100,
          left: -80,
          child: _buildBlob(const Color(0xFFEC4899), 250),
        ).animate(onPlay: (c) => c.repeat(reverse: true)).moveX(begin: 0, end: 80, duration: 8.seconds),
      ],
    );
  }

  Widget _buildBlob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.0),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumRing(ThemeData theme) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer glow
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.primary.withOpacity(0.05),
          ),
        ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1), duration: 2.seconds),
        
        // Spinning Dash ring
        SizedBox(
          width: 110,
          height: 110,
          child: CircularProgressIndicator(
            value: progress ?? 0.7,
            strokeWidth: 2,
            strokeCap: StrokeCap.round,
            color: theme.colorScheme.primary.withOpacity(0.3),
            backgroundColor: Colors.transparent,
          ),
        ).animate(onPlay: (c) => c.repeat()).rotate(duration: 3.seconds),

        // Main Progress Indicator
        SizedBox(
          width: 90,
          height: 90,
          child: CircularProgressIndicator(
            strokeWidth: 6,
            strokeCap: StrokeCap.round,
            value: progress,
            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
          ),
        ),

        // Central AI Gem
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            gradient: WebColors.PremiumGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withOpacity(0.4),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 26),
        ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1.5.seconds, color: Colors.white24),
      ],
    );
  }

  Widget _buildMainTitle(ThemeData theme) {
    return Column(
      children: [
        Text(
          'SumQuiz AI is working',
          style: GoogleFonts.outfit(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
        ).animate().fadeIn(delay: 200.ms),
        const SizedBox(height: 8),
        Container(
          height: 2,
          width: 40,
          decoration: BoxDecoration(
            gradient: WebColors.PremiumGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ).animate().scaleX(begin: 0, end: 1, duration: 800.ms),
      ],
    );
  }

  Widget _buildPipeline(ThemeData theme, int activeStep) {
    return Column(
      children: [
        _buildPipelineStep('Deep Content Analysis', activeStep >= 0, activeStep == 0, theme),
        _buildPipelineStep('Knowledge Synthesis', activeStep >= 1, activeStep == 1, theme),
        _buildPipelineStep('Structuring Study Pack', activeStep >= 2, activeStep == 2, theme),
      ],
    );
  }

  Widget _buildPipelineStep(String label, bool isDone, bool isActive, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive 
                  ? theme.colorScheme.primary 
                  : (isDone ? WebColors.success : theme.colorScheme.onSurface.withOpacity(0.1)),
            ),
            child: isDone && !isActive 
                ? const Icon(Icons.check, size: 8, color: Colors.white)
                : null,
          ).animate(target: isActive ? 1 : 0).scale(duration: 400.ms).shimmer(duration: 1.seconds),
          const SizedBox(width: 16),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive 
                  ? theme.colorScheme.onSurface 
                  : theme.colorScheme.onSurface.withValues(alpha: isDone ? 0.6 : 0.2),
            ),
          ),
        ],
      ),
    );
  }
}
