import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CyberNeuralColors {
  // Core Backgrounds
  static const Color background = Color(0xFF0F0F11); // Premium Graphite
  static const Color surface = Color(0xFF18181B); // Zinc 900
  static const Color surfaceAlt = Color(0xFF27272A); // Zinc 800

  // Neural Accents
  static const Color cyan = Color(0xFF22D3EE); // Neural Blue
  static const Color purple = Color(0xFFA855F7); // Deep Purple
  static const Color gold = Color(0xFFEAB308); // Neural Gold for highlights
  static const Color alert = Color(0xFFF43F5E); // Rose 500
  static const Color success = Color(0xFF10B981); // Emerald 500
  static const Color amber = Color(0xFFF59E0B); // Amber for important
  
  // Waveform States
  static const Color toneExciting = Color(0xFFFACC15); // Warm Yellow
  static const Color toneAnalytical = Color(0xFF3B82F6); // Cool Blue
  static const Color toneIntense = Color(0xFF8B5CF6); // Electric Purple
  static const Color toneCalm = Color(0xFF2DD4BF); // Soft Cyan

  // Text
  static const Color textPrimary = Color(0xFFFAFAFA); // White/Zinc 50
  static const Color textSecondary = Color(0xFFA1A1AA); // Zinc 400
  static const Color textTertiary = Color(0xFF52525B); // Zinc 600

  // Gradients
  static const LinearGradient neuralGradient = LinearGradient(
    colors: [cyan, purple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGlow = LinearGradient(
    colors: [gold, Colors.transparent],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

class CyberNeuralTheme {
  static ThemeData get theme {
    final base = ThemeData.dark();
    
    return base.copyWith(
      scaffoldBackgroundColor: CyberNeuralColors.background,
      colorScheme: const ColorScheme.dark(
        primary: CyberNeuralColors.cyan,
        secondary: CyberNeuralColors.purple,
        surface: CyberNeuralColors.surface,
        error: CyberNeuralColors.alert,
        onSurface: CyberNeuralColors.textPrimary,
        primaryContainer: CyberNeuralColors.surfaceAlt,
      ),
      
      dividerTheme: DividerThemeData(
        color: CyberNeuralColors.surfaceAlt.withValues(alpha: 0.5),
        thickness: 1,
      ),

      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: CyberNeuralColors.textPrimary,
          letterSpacing: -0.5,
        ),
        displayMedium: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: CyberNeuralColors.textPrimary,
          letterSpacing: -0.3,
        ),
        titleLarge: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: CyberNeuralColors.textPrimary,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 15,
          height: 1.6,
          color: CyberNeuralColors.textPrimary,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          height: 1.5,
          color: CyberNeuralColors.textSecondary,
        ),
        labelSmall: GoogleFonts.jetBrainsMono(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: CyberNeuralColors.cyan,
        ),
      ),
      
      cardTheme: CardThemeData(
        color: CyberNeuralColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
      ),
      
      popupMenuTheme: PopupMenuThemeData(
        color: CyberNeuralColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.white10),
        ),
        elevation: 8,
      ),
    );
  }
}

