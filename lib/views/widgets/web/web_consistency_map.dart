import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WebConsistencyMap extends StatelessWidget {
  final List<int> engagementData; // 0-4 values for intensity

  const WebConsistencyMap({
    super.key,
    required this.engagementData,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Consistency Map',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Daily engagement over the last 6 months',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              _buildLegend(),
            ],
          ),
          const SizedBox(height: 16),
          _buildHeatmapGrid(),
        ],
      ),
    );
  }

  Widget _buildHeatmapGrid() {
    // We'll show a sample grid of 7 rows (days) and ~25 columns (weeks)
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(24, (weekIndex) {
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Column(
              children: List.generate(7, (dayIndex) {
                // Determine color based on intensity
                final dataIndex = weekIndex * 7 + dayIndex;
                final intensity = engagementData.length > dataIndex ? engagementData[dataIndex] : 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _getColorForIntensity(intensity),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      children: [
        Text(
          'Less',
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(width: 8),
        _buildLegendBox(0),
        const SizedBox(width: 4),
        _buildLegendBox(1),
        const SizedBox(width: 4),
        _buildLegendBox(2),
        const SizedBox(width: 4),
        _buildLegendBox(3),
        const SizedBox(width: 4),
        _buildLegendBox(4),
        const SizedBox(width: 8),
        Text(
          'More',
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendBox(int intensity) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: _getColorForIntensity(intensity),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Color _getColorForIntensity(int intensity) {
    switch (intensity) {
      case 0: return const Color(0xFFF1F5F9);
      case 1: return const Color(0xFFC7D2FE);
      case 2: return const Color(0xFF818CF8);
      case 3: return const Color(0xFF4F46E5);
      case 4: return const Color(0xFF312E81);
      default: return const Color(0xFFF1F5F9);
    }
  }
}
