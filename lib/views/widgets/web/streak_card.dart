import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sumquiz/theme/web_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

class StreakCard extends StatelessWidget {
  final int streakDays;

  const StreakCard({super.key, required this.streakDays});

  @override
  Widget build(BuildContext context) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final currentDayOfWeek = DateTime.now().weekday; // 1=Mon, 7=Sun

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WebColors.border),
        boxShadow: WebColors.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STREAK HISTORY',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: WebColors.textSecondary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(days.length, (index) {
              final dayNum = index + 1;
              final isCompleted =
                  dayNum < currentDayOfWeek && index < streakDays;
              final isToday = dayNum == currentDayOfWeek;
              final isFuture = dayNum > currentDayOfWeek;

              return _buildDayBubble(
                  days[index], isCompleted, isToday, isFuture);
            }),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.05);
  }

  Widget _buildDayBubble(
      String label, bool isCompleted, bool isToday, bool isFuture) {
    return Column(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: isCompleted
                ? WebColors.purplePrimary
                : isToday
                    ? WebColors.purpleUltraLight
                    : WebColors.backgroundAlt,
            shape: BoxShape.circle,
            border: isToday
                ? Border.all(color: WebColors.purplePrimary, width: 2)
                : null,
          ),
          alignment: Alignment.center,
          child: isCompleted
              ? const Icon(Icons.check_rounded,
                  color: Colors.white, size: 18)
              : isFuture
                  ? const Icon(Icons.lock_rounded,
                      color: WebColors.textTertiary, size: 14)
                  : isToday
                      ? const Icon(Icons.circle,
                          color: WebColors.purplePrimary, size: 8)
                      : null,
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color:
                isCompleted ? WebColors.textPrimary : WebColors.textTertiary,
          ),
        ),
      ],
    );
  }
}
