import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../models/daily_mission.dart';

class DailyMissionCard extends StatelessWidget {
  final DailyMission? mission;
  final bool isLoading;
  final VoidCallback onStart;

  const DailyMissionCard({
    super.key,
    required this.mission,
    required this.isLoading,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompleted = mission?.isCompleted ?? false;

    if (isLoading) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.05)),
        ),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary.withValues(alpha: 0.5)),
          ),
        ),
      );
    }

    if (mission == null) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.05)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.hintColor.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.flag_outlined, size: 32, color: theme.hintColor.withValues(alpha: 0.3)),
            ),
            const SizedBox(height: 20),
            Text(
              "No active mission",
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: theme.hintColor),
            ),
            const SizedBox(height: 8),
            Text(
              "Study more to unlock missions.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: theme.hintColor.withValues(alpha: 0.6)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isCompleted ? theme.colorScheme.primary.withValues(alpha: 0.03) : theme.cardColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isCompleted 
              ? theme.colorScheme.primary.withValues(alpha: 0.2)
              : theme.dividerColor.withValues(alpha: 0.05),
        ),
        boxShadow: [
          if (!isCompleted)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isCompleted ? theme.colorScheme.primary.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isCompleted ? Icons.check_circle_rounded : Icons.auto_awesome_rounded,
                  color: isCompleted ? theme.colorScheme.primary : Colors.orange,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'DAILY MISSION',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: isCompleted ? theme.colorScheme.primary : theme.hintColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            mission!.title,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isCompleted ? theme.colorScheme.primary : theme.textTheme.displayLarge?.color,
            ),
          ),
          const SizedBox(height: 28),
          if (isCompleted)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.stars_rounded, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Text(
                    'Mission Accomplished',
                    style: GoogleFonts.inter(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95))
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onStart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  elevation: 4,
                  shadowColor: theme.colorScheme.primary.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_arrow_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Launch Mission', 
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 400.ms),
        ],
      ),
    );
  }
}
