import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/teacher_models.dart';
import '../../models/user_model.dart';
import '../../services/teacher_service.dart';
import '../../theme/web_theme.dart';

class TeacherClassroomScreen extends StatefulWidget {
  final String? classId;

  const TeacherClassroomScreen({super.key, this.classId});

  @override
  State<TeacherClassroomScreen> createState() => _TeacherClassroomScreenState();
}

class _TeacherClassroomScreenState extends State<TeacherClassroomScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TeacherService _teacherService = TeacherService();

  List<StudentLink> _students = [];
  bool _isLoading = true;
  String _className = 'Biology SS2';
  final String _classCode = 'BIO-842';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (widget.classId != null && widget.classId!.isNotEmpty) {
      _className = widget.classId!.replaceAll('-', ' ').toUpperCase();
    }
    _loadData();
  }

  Future<void> _loadData() async {
    final user = Provider.of<UserModel?>(context, listen: false);
    if (user != null) {
      final list = await _teacherService.getStudentList(user.uid);
      if (mounted) {
        setState(() {
          _students = list;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/teacher');
            }
          },
        ),
        title: Text(
          'SumQuiz',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: WebColors.purplePrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              color: isDark ? Colors.white70 : const Color(0xFF64748B),
            ),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Header Section ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _className,
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.people_outline_rounded,
                          size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        '32 Students Enrolled',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Class Code & Invite Row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E293B)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Code: ',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              Text(
                                _classCode,
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1E293B),
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.copy_rounded,
                                    size: 18, color: WebColors.purplePrimary),
                                onPressed: () {
                                  Clipboard.setData(
                                      ClipboardData(text: _classCode));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Class code copied!'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => _showInviteDialog(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: WebColors.purplePrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.person_add_rounded, size: 18),
                        label: Text(
                          'Invite',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Tab Bar ──────────────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: WebColors.purplePrimary,
                indicatorWeight: 3,
                labelColor: WebColors.purplePrimary,
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                tabs: const [
                  Tab(text: 'Analytics'),
                  Tab(text: 'Students'),
                  Tab(text: 'Assignments'),
                ],
              ),
            ),

            // ── Tab Views ────────────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAnalyticsTab(isDark),
                  _buildStudentsTab(isDark),
                  _buildAssignmentsTab(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab 1: Analytics (Matching Mockup 2) ───────────────────────────────────
  Widget _buildAnalyticsTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // 1. Class Mastery Average Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 14,
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
                Text(
                  'Class Mastery Average',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '85%',
                      style: GoogleFonts.outfit(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: WebColors.purplePrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '↑ 4% this week',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Gauge Progress Ring
                SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: CircularProgressIndicator(
                          value: 0.85,
                          strokeWidth: 14,
                          backgroundColor: WebColors.purplePrimary.withValues(alpha: 0.12),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            WebColors.purplePrimary,
                          ),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Text(
                        'Good',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 200.ms),

          const SizedBox(height: 20),

          // 2. Sumi AI Insight Box
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
                  : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFFBFDBFE).withValues(alpha: 0.6),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                        Text(
                          'Sumi AI Insight',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1D4ED8),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Text(
                        'LEARNING GAP DETECTED',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.5,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                    children: [
                      TextSpan(
                        text: '31% of students ',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1D4ED8),
                        ),
                      ),
                      const TextSpan(
                        text: 'consistently miss questions related to ',
                      ),
                      TextSpan(
                        text: 'Cellular Mitosis Stages ',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1D4ED8),
                        ),
                      ),
                      const TextSpan(
                        text: 'across the last 3 assignments.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Generating targeted revision plan...'),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: Text(
                      'Generate Targeted Revision Plan',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 250.ms),

          const SizedBox(height: 20),

          // 3. Needs Attention Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 14,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: Color(0xFFDC2626), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Needs Attention',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '4 Students',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                _buildStudentAttentionRow(
                  name: 'Sarah Jenkins',
                  mastery: '42% Mastery',
                  color: const Color(0xFFDC2626),
                  avatarUrl: 'https://i.pravatar.cc/150?img=1',
                  isDark: isDark,
                ),
                const Divider(height: 16),
                _buildStudentAttentionRow(
                  name: 'David Chen',
                  mastery: '48% Mastery',
                  color: const Color(0xFFDC2626),
                  avatarUrl: 'https://i.pravatar.cc/150?img=2',
                  isDark: isDark,
                ),
                const Divider(height: 16),
                _buildStudentAttentionRow(
                  name: 'Marcus King',
                  mastery: '55% Mastery',
                  color: const Color(0xFFD97706),
                  initials: 'MK',
                  initialsBg: const Color(0xFF3B82F6),
                  isDark: isDark,
                ),
                const Divider(height: 16),
                _buildStudentAttentionRow(
                  name: 'Aisha Patel',
                  mastery: '58% Mastery',
                  color: const Color(0xFFD97706),
                  avatarUrl: 'https://i.pravatar.cc/150?img=5',
                  isDark: isDark,
                ),

                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    _tabController.animateTo(1);
                  },
                  child: Text(
                    'View All Students',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: WebColors.purplePrimary,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── Tab 2: Students List ───────────────────────────────────────────────────
  Widget _buildStudentsTab(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search students...',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: _students.isEmpty
              ? _buildMockStudentsList(isDark)
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _students.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final student = _students[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: WebColors.purplePrimary.withValues(alpha: 0.1),
                          child: Text(
                            student.studentName.characters.first.toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: WebColors.purplePrimary,
                            ),
                          ),
                        ),
                        title: Text(
                          student.studentName,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                        subtitle: Text(
                          '${student.averageScore.toStringAsFixed(0)}% Avg Score • ${student.totalAttempts} attempts',
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMockStudentsList(bool isDark) {
    final mockList = [
      {'name': 'Sarah Jenkins', 'score': '42%', 'status': 'Needs Help'},
      {'name': 'David Chen', 'score': '48%', 'status': 'Needs Help'},
      {'name': 'Marcus King', 'score': '55%', 'status': 'Average'},
      {'name': 'Aisha Patel', 'score': '58%', 'status': 'Average'},
      {'name': 'Emmanuel Okafor', 'score': '92%', 'status': 'Excellent'},
      {'name': 'Grace Adebayo', 'score': '88%', 'status': 'Excellent'},
      {'name': 'John Doe', 'score': '76%', 'status': 'Good'},
    ];

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: mockList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = mockList[index];
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: WebColors.purplePrimary.withValues(alpha: 0.1),
              child: Text(
                item['name']!.characters.first,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: WebColors.purplePrimary,
                ),
              ),
            ),
            title: Text(
              item['name']!,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            subtitle: Text('Mastery: ${item['score']}'),
            trailing: Chip(
              label: Text(
                item['status']!,
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
              ),
              backgroundColor: item['status'] == 'Needs Help'
                  ? const Color(0xFFFEE2E2)
                  : const Color(0xFFDCFCE7),
              side: BorderSide.none,
            ),
          ),
        );
      },
    );
  }

  // ── Tab 3: Assignments List ────────────────────────────────────────────────
  Widget _buildAssignmentsTab(bool isDark) {
    final mockAssignments = [
      {'title': 'Cellular Biology Quiz 1', 'due': 'Due Friday', 'submissions': '28/32'},
      {'title': 'Genetics Midterm Practice', 'due': 'Due Next Mon', 'submissions': '15/32'},
      {'title': 'Evolutionary Theory Essay', 'due': 'Closed', 'submissions': '32/32'},
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: mockAssignments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = mockAssignments[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: WebColors.purplePrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.assignment_outlined,
                    color: WebColors.purplePrimary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title']!,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item['due']} • Submissions: ${item['submissions']}',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStudentAttentionRow({
    required String name,
    required String mastery,
    required Color color,
    String? avatarUrl,
    String? initials,
    Color? initialsBg,
    required bool isDark,
  }) {
    return Row(
      children: [
        if (avatarUrl != null)
          CircleAvatar(
            radius: 18,
            backgroundImage: NetworkImage(avatarUrl),
          )
        else if (initials != null)
          CircleAvatar(
            radius: 18,
            backgroundColor: initialsBg ?? Colors.blue,
            child: Text(
              initials,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          )
        else
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey[300],
            child: Text(
              name.characters.first,
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                mastery,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.chevron_right_rounded,
          color: isDark ? Colors.grey[600] : const Color(0xFF94A3B8),
          size: 20,
        ),
      ],
    );
  }

  void _showInviteDialog(BuildContext context) {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Invite Student to $_className',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Share code $_classCode or invite via email:',
                style: GoogleFonts.inter(fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Student Email',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
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
                const SnackBar(content: Text('Invitation sent!')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: WebColors.purplePrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Send Invite'),
          ),
        ],
      ),
    );
  }
}
