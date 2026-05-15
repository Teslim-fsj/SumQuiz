import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

class StreakCard extends StatelessWidget {
  final int streakDays;

  const StreakCard({super.key, required this.streakDays});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final currentDayOfWeek = DateTime.now().weekday; // 1=Mon, 7=Sun

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              Text(
                'STREAK HISTORY',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: theme.hintColor,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(days.length, (index) {
              final dayNum = index + 1;
              final isCompleted = dayNum < currentDayOfWeek && (currentDayOfWeek - dayNum) < streakDays;
              final isToday = dayNum == currentDayOfWeek;
              final isFuture = dayNum > currentDayOfWeek;

              return _buildDayBubble(theme, days[index], isCompleted, isToday, isFuture);
            }),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildDayBubble(ThemeData theme, String label, bool isCompleted, bool isToday, bool isFuture) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isCompleted
                ? theme.colorScheme.primary
                : isToday
                    ? theme.colorScheme.primary.withOpacity(0.1)
                    : theme.dividerColor.withOpacity(0.05),
            shape: BoxShape.circle,
            border: isToday
                ? Border.all(color: theme.colorScheme.primary, width: 2)
                : null,
          ),
          alignment: Alignment.center,
          child: isCompleted
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
              : isToday
                  ? Icon(Icons.bolt_rounded, color: theme.colorScheme.primary, size: 16)
                  : isFuture
                      ? Icon(Icons.lock_rounded, color: theme.hintColor.withOpacity(0.2), size: 12)
                      : null,
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
            color: isToday ? theme.colorScheme.primary : theme.hintColor,
          ),
        ),
      ],
    );
  }
}
