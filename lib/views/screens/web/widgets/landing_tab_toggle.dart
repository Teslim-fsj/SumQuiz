import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sumquiz/theme/web_theme.dart';

enum LandingTab { student, educator, creator }

class LandingTabToggle extends StatelessWidget {
  final LandingTab currentTab;
  final bool isDark;

  const LandingTabToggle({
    super.key,
    required this.currentTab,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 600;

      return Container(
        margin: EdgeInsets.only(top: isMobile ? 24 : 36, bottom: 20),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 4,
          runSpacing: 4,
          children: [
            _buildPill(
              context: context,
              title: 'STUDENTS',
              icon: Icons.school_rounded,
              isSelected: currentTab == LandingTab.student,
              activeColor: WebColors.purplePrimary,
              onTap: () {
                if (currentTab != LandingTab.student) {
                  context.go('/landing');
                }
              },
            ),
            _buildPill(
              context: context,
              title: 'TEACHERS',
              icon: Icons.workspace_premium_rounded,
              isSelected: currentTab == LandingTab.educator,
              activeColor: const Color(0xFF1D4ED8), // Deep vibrant blue
              onTap: () {
                if (currentTab != LandingTab.educator) {
                  context.go('/educators');
                }
              },
            ),
            _buildPill(
              context: context,
              title: 'CREATORS & PARTNERS',
              icon: Icons.stars_rounded,
              isSelected: currentTab == LandingTab.creator,
              activeColor: const Color(0xFF7C3AED), // Vibrant purple-violet
              onTap: () {
                if (currentTab != LandingTab.creator) {
                  context.go('/creator-program');
                }
              },
            ),
          ],
        ),
      );
    });
  }

  Widget _buildPill({
    required BuildContext context,
    required String title,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white60 : Colors.grey[600]),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.inter(
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.grey[700]),
                fontSize: 12,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
