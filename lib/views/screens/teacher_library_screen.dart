import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/public_deck.dart';
import '../../models/user_model.dart';
import '../../services/teacher_service.dart';
import '../../theme/web_theme.dart';

class TeacherLibraryScreen extends StatefulWidget {
  const TeacherLibraryScreen({super.key});

  @override
  State<TeacherLibraryScreen> createState() => _TeacherLibraryScreenState();
}

class _TeacherLibraryScreenState extends State<TeacherLibraryScreen> {
  final TeacherService _teacherService = TeacherService();
  int _selectedTabIndex = 0; // 0 = Study Packs, 1 = Exams
  String _searchQuery = '';
  List<PublicDeck> _contentList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    final user = Provider.of<UserModel?>(context, listen: false);
    if (user != null) {
      final list = await _teacherService.getTeacherContent(user.uid);
      if (mounted) {
        setState(() {
          _contentList = list;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark
            ? const Color(0xFF0F172A)
            : const Color(0xFFF8FAFC),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateOptions(context),
        backgroundColor: WebColors.purplePrimary,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title & Subtitle ──────────────────────────────────────────
              Text(
                'Library',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage your teaching materials and study packs.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 20),

              // ── Search Input ──────────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.2 : 0.03,
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search materials...',
                    hintStyle: GoogleFonts.inter(
                      color: const Color(0xFF94A3B8),
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF94A3B8),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Segmented Tab Bar ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTabIndex = 0),
                        child: AnimatedContainer(
                          duration: 150.ms,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedTabIndex == 0
                                ? (isDark
                                      ? const Color(0xFF334155)
                                      : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _selectedTabIndex == 0
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 4,
                                    ),
                                  ]
                                : [],
                          ),
                          child: Center(
                            child: Text(
                              'Study Packs',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: _selectedTabIndex == 0
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: _selectedTabIndex == 0
                                    ? WebColors.purplePrimary
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTabIndex = 1),
                        child: AnimatedContainer(
                          duration: 150.ms,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedTabIndex == 1
                                ? (isDark
                                      ? const Color(0xFF334155)
                                      : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _selectedTabIndex == 1
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 4,
                                    ),
                                  ]
                                : [],
                          ),
                          child: Center(
                            child: Text(
                              'Exams',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: _selectedTabIndex == 1
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: _selectedTabIndex == 1
                                    ? WebColors.purplePrimary
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Content Cards ─────────────────────────────────────────────
              _buildContentCards(isDark),

              const SizedBox(height: 20),

              // ── AI Suggestion Card ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFBFDBFE).withValues(alpha: 0.6),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.smart_toy_outlined,
                            size: 14,
                            color: Color(0xFF2563EB),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'AI Suggestion',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Generate Quiz from 'Cell Biology Fundamentals'",
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Based on recent student completion rates.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () => context.push('/create-content'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Create',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 350.ms),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContentCards(bool isDark) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Filter content list by tab & search query
    final isExamTab = _selectedTabIndex == 1;
    final filtered = _contentList.where((deck) {
      final matchesTab = isExamTab ? deck.isExam : !deck.isExam;
      final matchesSearch =
          _searchQuery.isEmpty ||
          deck.title.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesTab && matchesSearch;
    }).toList();

    if (filtered.isEmpty) {
      return _buildEmptyState(isDark, isExamTab);
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final deck = filtered[index];
        return _buildDeckCard(
          isDark: isDark,
          type: deck.isExam ? 'Exam' : 'Pack',
          status: 'Published',
          statusColor: WebColors.purplePrimary,
          title: deck.title,
          enrolledText: '👥 ${deck.startedCount} Enrolled',
          actionText: 'Manage →',
          onActionTap: () => context.push('/create-content?id=${deck.id}'),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark, bool isExamTab) {
    final label = isExamTab ? 'exam' : 'study pack';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.library_add_outlined,
            size: 42,
            color: WebColors.purplePrimary,
          ),
          const SizedBox(height: 12),
          Text(
            'No ${isExamTab ? 'exams' : 'study packs'} yet',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Create a $label, then share it with your students.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => context.push(
              isExamTab ? '/create-content/exam-wizard' : '/create-content',
            ),
            child: Text('Create $label'),
          ),
        ],
      ),
    );
  }

  Widget _buildMockCards(bool isDark) {
    return Column(
      children: [
        _buildDeckCard(
          isDark: isDark,
          type: 'Pack',
          status: '✓ Published',
          statusColor: const Color(0xFF7C3AED),
          statusBg: const Color(0xFFF3E8FF),
          title: 'Cell Biology Fundamentals',
          enrolledText: '👥 124 Enrolled',
          actionText: 'Manage →',
          onActionTap: () {},
        ),
        const SizedBox(height: 14),
        _buildDeckCard(
          isDark: isDark,
          type: 'Exam',
          status: '📝 Draft',
          statusColor: const Color(0xFF64748B),
          statusBg: const Color(0xFFF1F5F9),
          title: 'Midterm: Genetics',
          enrolledText: '👥 -- Enrolled',
          actionText: 'Edit ✏️',
          onActionTap: () => context.push('/create-content/exam-wizard'),
        ),
        const SizedBox(height: 14),
        _buildDeckCard(
          isDark: isDark,
          type: 'Pack',
          status: '🔒 Private',
          statusColor: const Color(0xFFB45309),
          statusBg: const Color(0xFFFEF3C7),
          title: 'Advanced Evolutionary Theory',
          enrolledText: '👥 5 Enrolled',
          actionText: 'Manage →',
          onActionTap: () {},
        ),
      ],
    );
  }

  Widget _buildDeckCard({
    required bool isDark,
    required String type,
    required String status,
    required Color statusColor,
    Color? statusBg,
    required String title,
    required String enrolledText,
    required String actionText,
    required VoidCallback onActionTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badges row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  type,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusBg ?? statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          Divider(
            height: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFF1F5F9),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                enrolledText,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
              InkWell(
                onTap: onActionTap,
                child: Text(
                  actionText,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: WebColors.purplePrimary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCreateOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Create Content',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(
                Icons.quiz_rounded,
                color: WebColors.purplePrimary,
              ),
              title: const Text('New Exam / Quiz'),
              subtitle: const Text('Structured assessment with AI generation'),
              onTap: () {
                Navigator.pop(context);
                context.push('/create-content/exam-wizard');
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.menu_book_rounded,
                color: Color(0xFF0D9488),
              ),
              title: const Text('New Study Pack'),
              subtitle: const Text('Summaries, quizzes & flashcards'),
              onTap: () {
                Navigator.pop(context);
                context.push('/create-content');
              },
            ),
          ],
        ),
      ),
    );
  }
}
