import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

class WebLibraryEmptyState extends StatelessWidget {
  final VoidCallback onBuildPack;
  final VoidCallback onCreateNew;

  const WebLibraryEmptyState({
    super.key,
    required this.onBuildPack,
    required this.onCreateNew,
  });

  @override
  Widget build(BuildContext context) {
    
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Illustration
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    shape: BoxShape.circle,
                  ),
                ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                Icon(Icons.folder_open_rounded, size: 80, color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
                Positioned(
                  right: 20,
                  top: 20,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF6366F1), size: 24),
                  ),
                ).animate().slideY(begin: 0.5, end: 0, duration: 800.ms).fadeIn(),
                Positioned(
                  left: 10,
                  bottom: 30,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.menu_book_rounded, color: Color(0xFF6366F1), size: 20),
                  ),
                ).animate().slideX(begin: -0.5, end: 0, duration: 800.ms).fadeIn(),
              ],
            ),
            const SizedBox(height: 48),
            Text(
              'Your library is empty',
              style: GoogleFonts.outfit(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Text(
                'Start creating content to populate your library. Let AI transform your documents into structured learning paths.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: const Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: onBuildPack,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    elevation: 10,
                    shadowColor: const Color(0xFF6366F1).withValues(alpha: 0.4),
                  ),
                  child: Text('Build Study Pack', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: onCreateNew,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE0E7FF).withValues(alpha: 0.5),
                    foregroundColor: const Color(0xFF4338CA),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    elevation: 0,
                  ),
                  child: Text('Create New', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}
