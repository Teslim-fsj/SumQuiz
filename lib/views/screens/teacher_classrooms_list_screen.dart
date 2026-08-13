import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../theme/web_theme.dart';

class TeacherClassroomsListScreen extends StatelessWidget {
  const TeacherClassroomsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final mockClasses = [
      {
        'id': 'biology-ss2',
        'title': 'Biology SS2',
        'studentsCount': 42,
        'attentionCount': 8,
        'code': 'BIO-842',
        'color': const Color(0xFF6B5CE7),
      },
      {
        'id': 'chemistry-ss1',
        'title': 'Chemistry SS1',
        'studentsCount': 28,
        'attentionCount': 2,
        'code': 'CHM-101',
        'color': const Color(0xFF2563EB),
      },
      {
        'id': 'physics-ss3',
        'title': 'Physics SS3',
        'studentsCount': 35,
        'attentionCount': 5,
        'code': 'PHY-302',
        'color': const Color(0xFF0D9488),
      },
    ];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        elevation: 0,
        title: Text(
          'My Classes',
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _showCreateClassDialog(context),
            icon: const Icon(Icons.add_circle_outline_rounded,
                color: WebColors.purplePrimary),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: mockClasses.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final cls = mockClasses[index];
            final Color cardColor = cls['color'] as Color;

            return InkWell(
              onTap: () {
                context.push('/teacher/classroom/${cls['id']}');
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : const Color(0xFFF1F5F9),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: cardColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.school_rounded,
                          color: cardColor, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cls['title'] as String,
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                '👥 ${cls['studentsCount']} Students',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              if ((cls['attentionCount'] as int) > 0) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '• ⚠️ ${cls['attentionCount']} Attention',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFD97706),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: Color(0xFF94A3B8)),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: (200 + index * 50).ms);
          },
        ),
      ),
    );
  }

  void _showCreateClassDialog(BuildContext context) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Create Class', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: 'Class Name (e.g. Biology SS2)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Class created successfully')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: WebColors.purplePrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
