import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WebStatsGrid extends StatelessWidget {
  final int dayStreak;
  final int itemsToday;
  final int dailyGoal;
  final int totalItems;
  final double studyTimeHours;

  const WebStatsGrid({
    super.key,
    required this.dayStreak,
    required this.itemsToday,
    required this.dailyGoal,
    required this.totalItems,
    required this.studyTimeHours,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildStatCard(
          title: 'DAY STREAK',
          value: '$dayStreak',
          unit: 'Days',
          icon: Icons.local_fire_department_rounded,
          iconColor: const Color(0xFF6366F1),
          badge: 'TOP 5% GLOBALLY',
          badgeColor: const Color(0xFFEEF2FF),
          badgeTextColor: const Color(0xFF6366F1),
        ),
        const SizedBox(width: 24),
        _buildStatCard(
          title: 'ITEMS COMPLETED TODAY',
          value: '$itemsToday',
          unit: '/ $dailyGoal',
          icon: Icons.check_circle_outline_rounded,
          iconColor: const Color(0xFF6366F1),
          child: _buildProgressBar(itemsToday / dailyGoal),
        ),
        const SizedBox(width: 24),
        _buildStatCard(
          title: 'TOTAL ITEMS CREATED',
          value: totalItems.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},'),
          unit: '',
          icon: Icons.add_circle_outline_rounded,
          iconColor: const Color(0xFF6366F1),
          badge: '+12% from last month',
          badgeColor: Colors.transparent,
          badgeTextColor: const Color(0xFF64748B),
        ),
        const SizedBox(width: 24),
        _buildStatCard(
          title: 'STUDY TIME',
          value: '${studyTimeHours.floor()}h ${((studyTimeHours % 1) * 60).round()}m',
          unit: '',
          icon: Icons.access_time_rounded,
          iconColor: const Color(0xFF6366F1),
          badge: '-5% focus drop detected',
          badgeColor: Colors.transparent,
          badgeTextColor: const Color(0xFFEF4444),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color iconColor,
    String? badge,
    Color? badgeColor,
    Color? badgeTextColor,
    Widget? child,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                Icon(icon, color: iconColor, size: 20),
              ],
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    unit,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeTextColor,
                  ),
                ),
              ),
            if (child != null) child,
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(double progress) {
    return Container(
      height: 8,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(4),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}
