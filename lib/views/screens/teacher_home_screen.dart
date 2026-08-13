import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/user_model.dart';
import '../../theme/web_theme.dart';

class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({super.key});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = Provider.of<UserModel?>(context);
    final isDark = theme.brightness == Brightness.dark;

    final displayName = user?.displayName ?? 'Teacher';
    final firstName = displayName.split(' ').first;

    final greeting = _getGreeting();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Top Header ─────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: WebColors.purplePrimary.withValues(alpha: 0.15),
                        backgroundImage: user?.photoURL != null
                            ? NetworkImage(user!.photoURL!)
                            : null,
                        child: user?.photoURL == null
                            ? Text(
                                firstName.characters.first.toUpperCase(),
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: WebColors.purplePrimary,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$greeting, $firstName',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => context.push('/settings'),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.settings_outlined,
                        size: 20,
                        color: isDark ? Colors.white70 : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 200.ms),

              const SizedBox(height: 24),

              // ── 2. Continue Teaching Hero Card ─────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6B5CE7), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6B5CE7).withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CONTINUE TEACHING',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Biology SS2',
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.people_alt_rounded,
                            size: 16, color: Colors.white70),
                        const SizedBox(width: 6),
                        Text(
                          '42 Students',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '•',
                            style: GoogleFonts.inter(color: Colors.white60),
                          ),
                        ),
                        const Icon(Icons.warning_amber_rounded,
                            size: 16, color: Color(0xFFFDE047)),
                        const SizedBox(width: 6),
                        Text(
                          '8 Need Attention',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFFDE047),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          context.push('/teacher/classroom/biology-ss2');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF6B5CE7),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Resume',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.05, end: 0),

              const SizedBox(height: 28),

              // ── 3. Quick Actions ──────────────────────────────────────────
              Text(
                'Quick Actions',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.4,
                children: [
                  _buildQuickActionCard(
                    context,
                    isDark: isDark,
                    icon: Icons.menu_book_rounded,
                    iconBg: const Color(0xFFF3E8FF),
                    iconColor: const Color(0xFF9333EA),
                    label: '+ Study Pack',
                    onTap: () => context.push('/create-content'),
                  ),
                  _buildQuickActionCard(
                    context,
                    isDark: isDark,
                    icon: Icons.quiz_rounded,
                    iconBg: const Color(0xFFEFF6FF),
                    iconColor: const Color(0xFF2563EB),
                    label: '+ Exam',
                    onTap: () => context.push('/create-content/exam-wizard'),
                  ),
                  _buildQuickActionCard(
                    context,
                    isDark: isDark,
                    icon: Icons.bookmark_added_rounded,
                    iconBg: const Color(0xFFFFF7ED),
                    iconColor: const Color(0xFFEA580C),
                    label: '+ Class',
                    onTap: () => _showCreateClassDialog(context),
                  ),
                  _buildQuickActionCard(
                    context,
                    isDark: isDark,
                    icon: Icons.upload_file_rounded,
                    iconBg: const Color(0xFFF5F3FF),
                    iconColor: const Color(0xFF7C3AED),
                    label: '+ Import',
                    onTap: () => context.push('/create-content'),
                  ),
                ],
              ).animate().fadeIn(duration: 300.ms),

              const SizedBox(height: 28),

              // ── 4. Recent Activity & Insights ─────────────────────────────
              Text(
                'Recent Activity & Insights',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 16),

              Container(
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
                child: Column(
                  children: [
                    // Activity item 1
                    _buildActivityTile(
                      isDark: isDark,
                      icon: Icons.person_add_rounded,
                      iconBg: const Color(0xFFEFF6FF),
                      iconColor: const Color(0xFF3B82F6),
                      titleSpan: TextSpan(
                        text: '12 new students joined ',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                        children: [
                          TextSpan(
                            text: 'Biology SS2',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      timeAgo: '2 hours ago',
                    ),
                    Divider(
                      height: 1,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0xFFF1F5F9),
                    ),
                    // Activity item 2
                    _buildActivityTile(
                      isDark: isDark,
                      icon: Icons.trending_up_rounded,
                      iconBg: const Color(0xFFFFF7ED),
                      iconColor: const Color(0xFFF97316),
                      titleSpan: TextSpan(
                        text: 'Average mastery ↑ increased by 4% this week',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      timeAgo: 'Today',
                    ),
                    Divider(
                      height: 1,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0xFFF1F5F9),
                    ),
                    // Sumi AI Insight Box
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
                            : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFBFDBFE).withValues(alpha: 0.6),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.withValues(alpha: 0.15),
                                      blurRadius: 6,
                                    )
                                  ],
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/images/sumi.png',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.smart_toy_rounded,
                                      color: Color(0xFF2563EB),
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Row(
                                children: [
                                  const Icon(Icons.auto_awesome_rounded,
                                      size: 14, color: Color(0xFF2563EB)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'SUMI AI INSIGHT',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                      color: const Color(0xFF2563EB),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Confusion detected in Genetics. 31% of students are missing mitosis questions.',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () {
                                context.push('/teacher/classroom/biology-ss2');
                              },
                              style: OutlinedButton.styleFrom(
                                backgroundColor: isDark
                                    ? const Color(0xFF1E293B)
                                    : Colors.white,
                                side: const BorderSide(color: Color(0xFF2563EB)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Generate Intervention',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF2563EB),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.arrow_forward_rounded,
                                      size: 16, color: Color(0xFF2563EB)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 350.ms),

              const SizedBox(height: 80), // Extra bottom padding for nav bar
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required bool isDark,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFF1F5F9),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityTile({
    required bool isDark,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required TextSpan titleSpan,
    required String timeAgo,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(text: titleSpan),
                const SizedBox(height: 4),
                Text(
                  timeAgo,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  void _showCreateClassDialog(BuildContext context) {
    final classNameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Create New Class',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: classNameController,
          decoration: InputDecoration(
            labelText: 'Class Name (e.g. Biology SS2)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Class created successfully!')),
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
