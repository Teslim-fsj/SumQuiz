import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/user_model.dart';
import '../../theme/web_theme.dart';
import '../../providers/create_content_provider.dart';
import '../widgets/sumi_live_sandbox_overlay.dart';

class ScaffoldWithNavBar extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const ScaffoldWithNavBar({super.key, required this.navigationShell});

  @override
  State<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

class _ScaffoldWithNavBarState extends State<ScaffoldWithNavBar> {
  bool _isExpanded = true;
  bool _sidebarInitialized = false;

  int _branchToIndex(int branch, bool isTeacher) {
    if (isTeacher) {
      // Teacher mapping: Home(0), Classroom(3), Library(1), Sumi AI(4)
      if (branch == 0) return 0;
      if (branch == 3) return 1;
      if (branch == 1) return 2;
      if (branch == 4) return 3;
      return 0;
    }
    // Student mapping: Home(0), Library(1), Profile(5)
    if (branch == 0) return 0;
    if (branch == 1) return 1;
    if (branch == 5) return 2;
    return 0;
  }

  void _onTap(int index, bool isTeacher) {
    int targetBranch;
    if (isTeacher) {
      final teacherBranches = [0, 3, 1, 4];
      targetBranch = teacherBranches[index];
    } else {
      // Student 3-tab mapping: Home(0), Library(1), Profile(5)
      final studentBranches = [0, 1, 5];
      targetBranch = studentBranches[index];
    }
    widget.navigationShell.goBranch(
      targetBranch,
      initialLocation: targetBranch == widget.navigationShell.currentIndex,
    );
  }

  void _goToBranch(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = Provider.of<UserModel?>(context);
    final isTeacher = user?.role == UserRole.creator;
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Auto-initialize sidebar expansion based on screen width
        if (!_sidebarInitialized) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _isExpanded = constraints.maxWidth >= 1200;
                _sidebarInitialized = true;
              });
            }
          });
        }

        if (constraints.maxWidth < 900) {
          final currentIdx =
              _branchToIndex(widget.navigationShell.currentIndex, isTeacher);
          return Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            extendBody: true,
            body: Stack(
              children: [
                widget.navigationShell,
                // Central / Floating + Create FAB
                Positioned(
                  right: 16,
                  bottom: 80,
                  child: FloatingActionButton(
                    onPressed: () => _showCreateSheet(context, isTeacher),
                    backgroundColor: WebColors.purplePrimary,
                    elevation: 6,
                    shape: const CircleBorder(),
                    child: const Icon(Icons.add_rounded,
                        color: Colors.white, size: 28),
                  )
                      .animate()
                      .scale(
                          delay: 100.ms,
                          duration: 300.ms,
                          curve: Curves.easeOutBack),
                ),
              ],
            ),
            bottomNavigationBar: BottomAppBar(
              height: 64,
              color: theme.cardColor.withValues(alpha: 0.97),
              elevation: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: isTeacher
                    ? [
                        _buildMobileNavItem(
                          icon: Icons.home_outlined,
                          activeIcon: Icons.home_rounded,
                          label: 'Home',
                          isActive: currentIdx == 0,
                          onTap: () => _onTap(0, true),
                        ),
                        _buildMobileNavItem(
                          icon: Icons.school_outlined,
                          activeIcon: Icons.school_rounded,
                          label: 'Classroom',
                          isActive: currentIdx == 1,
                          onTap: () => _onTap(1, true),
                        ),
                        _buildMobileNavItem(
                          icon: Icons.folder_outlined,
                          activeIcon: Icons.folder_rounded,
                          label: 'Library',
                          isActive: currentIdx == 2,
                          onTap: () => _onTap(2, true),
                        ),
                        _buildMobileNavItem(
                          icon: Icons.smart_toy_outlined,
                          activeIcon: Icons.smart_toy_rounded,
                          label: 'Sumi AI',
                          isActive: currentIdx == 3,
                          onTap: () => _onTap(3, true),
                        ),
                      ]
                    : [
                        _buildMobileNavItem(
                          icon: Icons.home_outlined,
                          activeIcon: Icons.home_rounded,
                          label: 'Home',
                          isActive: currentIdx == 0,
                          onTap: () => _onTap(0, false),
                        ),
                        _buildMobileNavItem(
                          icon: Icons.menu_book_outlined,
                          activeIcon: Icons.menu_book_rounded,
                          label: 'Library',
                          isActive: currentIdx == 1,
                          onTap: () => _onTap(1, false),
                        ),
                        _buildMobileNavItem(
                          icon: Icons.person_outline,
                          activeIcon: Icons.person_rounded,
                          label: 'Profile',
                          isActive: currentIdx == 2,
                          onTap: () => _onTap(2, false),
                        ),
                      ],
              ),
            ),
          );
        } else {
          return Scaffold(
            backgroundColor: isDark ? const Color(0xFF020617) : Colors.white,
            body: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.fastOutSlowIn,
                  width: _isExpanded ? 260 : 72,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    border: Border(
                      right: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey[200]!,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 24, horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isExpanded) ...[
                              Image.asset(
                                'assets/images/sumquiz_logo.png',
                                width: 28,
                                height: 28,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.school,
                                        color: WebColors.purplePrimary,
                                        size: 28),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'SumQuiz',
                                  style: GoogleFonts.outfit(
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF1F1F1F),
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                            if (!_isExpanded)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Image.asset(
                                  'assets/images/sumquiz_logo.png',
                                  width: 28,
                                  height: 28,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.school,
                                          color: WebColors.purplePrimary,
                                          size: 28),
                                ),
                              ),
                            if (_isExpanded)
                              IconButton(
                                onPressed: () =>
                                    setState(() => _isExpanded = !_isExpanded),
                                icon: Icon(
                                  Icons.chevron_left_rounded,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                  size: 28,
                                ),
                                tooltip: 'Collapse',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                splashRadius: 24,
                              ),
                          ],
                        ),
                      ),
                      if (!_isExpanded)
                        IconButton(
                          onPressed: () =>
                              setState(() => _isExpanded = !_isExpanded),
                          icon: Icon(
                            Icons.chevron_right_rounded,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            size: 28,
                          ),
                          tooltip: 'Expand',
                        ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: _isExpanded ? 20 : 12, vertical: 12),
                        child: InkWell(
                          onTap: () {
                            if (isTeacher) {
                              context.go('/create-content/exam-wizard');
                            } else {
                              Provider.of<CreateContentProvider>(context,
                                      listen: false)
                                  .reset();
                              _goToBranch(2);
                            }
                          },
                          borderRadius: BorderRadius.circular(100),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: EdgeInsets.symmetric(
                              horizontal: _isExpanded ? 20 : 0,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: WebColors.purplePrimary,
                              borderRadius: BorderRadius.circular(100),
                              boxShadow: [
                                BoxShadow(
                                  color: WebColors.purplePrimary
                                      .withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add,
                                    color: Colors.white, size: 20),
                                if (_isExpanded) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    isTeacher
                                        ? 'Create Exam'
                                        : 'Create Study Pack',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.symmetric(
                              horizontal: _isExpanded ? 16 : 8),
                          children: [
                             if (isTeacher) ...[
                              _buildSidebarTab(
                                icon: Icons.home_outlined,
                                activeIcon: Icons.home_rounded,
                                label: 'Home',
                                isActive:
                                    widget.navigationShell.currentIndex == 0,
                                onTap: () => _goToBranch(0),
                                isExpanded: _isExpanded,
                                isDark: isDark,
                              ),
                              _buildSidebarTab(
                                icon: Icons.school_outlined,
                                activeIcon: Icons.school_rounded,
                                label: 'Classroom',
                                isActive:
                                    widget.navigationShell.currentIndex == 3,
                                onTap: () => _goToBranch(3),
                                isExpanded: _isExpanded,
                                isDark: isDark,
                              ),
                              _buildSidebarTab(
                                icon: Icons.folder_outlined,
                                activeIcon: Icons.folder_rounded,
                                label: 'Library',
                                isActive:
                                    widget.navigationShell.currentIndex == 1,
                                onTap: () => _goToBranch(1),
                                isExpanded: _isExpanded,
                                isDark: isDark,
                              ),
                              _buildSidebarTab(
                                icon: Icons.smart_toy_outlined,
                                activeIcon: Icons.smart_toy_rounded,
                                label: 'Sumi AI',
                                isActive:
                                    widget.navigationShell.currentIndex == 4,
                                onTap: () => _goToBranch(4),
                                isExpanded: _isExpanded,
                                isDark: isDark,
                              ),
                            ] else ...[
                              _buildSidebarTab(
                                icon: Icons.home_outlined,
                                activeIcon: Icons.home_rounded,
                                label: 'Home',
                                isActive:
                                    widget.navigationShell.currentIndex == 0,
                                onTap: () => _goToBranch(0),
                                isExpanded: _isExpanded,
                                isDark: isDark,
                              ),
                              _buildSidebarTab(
                                icon: Icons.menu_book_outlined,
                                activeIcon: Icons.menu_book_rounded,
                                label: 'Library',
                                isActive:
                                    widget.navigationShell.currentIndex == 1,
                                onTap: () => _goToBranch(1),
                                isExpanded: _isExpanded,
                                isDark: isDark,
                              ),
                            ],
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: _isExpanded ? 4 : 8,
                                vertical: 24,
                              ),
                              child: Divider(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : Colors.grey[200]!,
                                thickness: 1,
                              ),
                            ),
                            _buildSidebarTab(
                              icon: Icons.person_outline,
                              activeIcon: Icons.person_rounded,
                              label: 'Profile',
                              isActive:
                                  widget.navigationShell.currentIndex == 5,
                              onTap: () => _goToBranch(5),
                              isExpanded: _isExpanded,
                              isDark: isDark,
                            ),
                            _buildSidebarTab(
                              icon: Icons.settings_outlined,
                              activeIcon: Icons.settings_rounded,
                              label: 'Settings',
                              isActive:
                                  widget.navigationShell.currentIndex == 6,
                              onTap: () => _goToBranch(6),
                              isExpanded: _isExpanded,
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),
                      if (_isExpanded && user?.isPro == false)
                        Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: InkWell(
                            onTap: () => context.push('/settings/subscription'),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2E1A47),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.stars_rounded,
                                          color: Color(0xFFFACC15), size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Upgrade to Pro',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Unlock unlimited AI summaries and advanced study modes.',
                                    style: GoogleFonts.inter(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: _isExpanded ? 24 : 16, vertical: 24),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.grey[200]!,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: _isExpanded
                              ? MainAxisAlignment.start
                              : MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: WebColors.purplePrimary
                                  .withValues(alpha: 0.1),
                              backgroundImage: user?.photoURL != null
                                  ? NetworkImage(user!.photoURL!)
                                  : null,
                              child: user?.photoURL == null
                                  ? Text(
                                      user?.displayName.characters.first
                                              .toUpperCase() ??
                                          'U',
                                      style: GoogleFonts.outfit(
                                        color: WebColors.purplePrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            if (_isExpanded) ...[
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user?.displayName ?? 'User',
                                      style: GoogleFonts.inter(
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF1F1F1F),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isTeacher ? 'Pro Educator' : 'Learner',
                                      style: GoogleFonts.inter(
                                        color: isDark
                                            ? Colors.grey[500]
                                            : Colors.grey[600],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ClipRRect(child: widget.navigationShell),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  void _showCreateSheet(BuildContext context, bool isTeacher) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor =
        isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Title
                Center(
                  child: Text(
                    'Create something',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    'Add material or start learning',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: subColor,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── STUDY section ──────────────────────────────────────────
                Text(
                  'STUDY',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: subColor,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _sheetItem(
                              context: context,
                              icon: Icons.smart_toy_rounded,
                              iconBg: const Color(0xFF3B82F6),
                              label: 'Ask Sumi',
                              isDark: isDark,
                              onTap: () {
                                Navigator.pop(context);
                                showGeneralDialog(
                                  context: context,
                                  barrierDismissible: true,
                                  barrierLabel: 'Sumi',
                                  pageBuilder: (ctx, _, __) =>
                                      const SumiLiveSandboxOverlay(),
                                );
                              },
                            ),
                          ),
                          Container(
                              width: 1,
                              height: 72,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.grey[100]),
                          Expanded(
                            child: _sheetItem(
                              context: context,
                              icon: Icons.edit_note_rounded,
                              iconBg: const Color(0xFF8B5CF6),
                              label: 'New Note',
                              isDark: isDark,
                              onTap: () {
                                Navigator.pop(context);
                                context.push('/notes/new');
                              },
                            ),
                          ),
                        ],
                      ),
                      Divider(
                          height: 1,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.grey[100]),
                      Row(
                        children: [
                          Expanded(
                            child: _sheetItem(
                              context: context,
                              icon: Icons.text_fields_rounded,
                              iconBg: const Color(0xFF7C3AED),
                              label: 'Paste Research',
                              isDark: isDark,
                              onTap: () {
                                Navigator.pop(context);
                                Provider.of<CreateContentProvider>(context,
                                        listen: false)
                                    .reset();
                                context.go('/create-content');
                              },
                            ),
                          ),
                          Container(
                              width: 1,
                              height: 72,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.grey[100]),
                          Expanded(
                            child: _sheetItem(
                              context: context,
                              icon: Icons.audio_file_rounded,
                              iconBg: const Color(0xFF22C55E),
                              label: 'Audio Brief',
                              isDark: isDark,
                              onTap: () {
                                Navigator.pop(context);
                                Provider.of<CreateContentProvider>(context,
                                        listen: false)
                                    .reset();
                                context.go('/create-content');
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── IMPORT section ─────────────────────────────────────────
                Text(
                  'IMPORT',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: subColor,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _sheetItem(
                              context: context,
                              icon: Icons.picture_as_pdf_rounded,
                              iconBg: const Color(0xFFF59E0B),
                              label: 'Upload PDF',
                              isDark: isDark,
                              onTap: () {
                                Navigator.pop(context);
                                Provider.of<CreateContentProvider>(context,
                                        listen: false)
                                    .reset();
                                context.go('/create-content');
                              },
                            ),
                          ),
                          Container(
                              width: 1,
                              height: 72,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.grey[100]),
                          Expanded(
                            child: _sheetItem(
                              context: context,
                              icon: Icons.camera_alt_rounded,
                              iconBg: const Color(0xFF06B6D4),
                              label: 'Scan / Image',
                              isDark: isDark,
                              onTap: () {
                                Navigator.pop(context);
                                Provider.of<CreateContentProvider>(context,
                                        listen: false)
                                    .reset();
                                context.go('/create-content');
                              },
                            ),
                          ),
                        ],
                      ),
                      Divider(
                          height: 1,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.grey[100]),
                      Row(
                        children: [
                          Expanded(
                            child: _sheetItem(
                              context: context,
                              icon: Icons.play_circle_fill_rounded,
                              iconBg: const Color(0xFFEF4444),
                              label: 'YouTube',
                              isDark: isDark,
                              onTap: () {
                                Navigator.pop(context);
                                Provider.of<CreateContentProvider>(context,
                                        listen: false)
                                    .reset();
                                context.go('/create-content');
                              },
                            ),
                          ),
                          Container(
                              width: 1,
                              height: 72,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.grey[100]),
                          Expanded(
                            child: _sheetItem(
                              context: context,
                              icon: Icons.language_rounded,
                              iconBg: const Color(0xFF64B5F6),
                              label: 'Web',
                              isDark: isDark,
                              onTap: () {
                                Navigator.pop(context);
                                Provider.of<CreateContentProvider>(context,
                                        listen: false)
                                    .reset();
                                context.go('/create-content');
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Teacher: also show Create Exam option
                if (isTeacher) ...[
                  const SizedBox(height: 20),
                  Text(
                    'EDUCATOR',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: subColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/create-content/exam-wizard');
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 18),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6B5CE7)
                                  .withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.assignment_rounded,
                                color: Color(0xFF6B5CE7), size: 22),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Create Formal Exam',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded,
                              color: subColor, size: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetItem({
    required BuildContext context,
    required IconData icon,
    required Color iconBg,
    required String label,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconBg, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? WebColors.purplePrimary : Colors.grey[500],
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? WebColors.purplePrimary : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildSidebarTab({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required bool isExpanded,
    required bool isDark,
  }) {
    Color activeBg = isDark
        ? WebColors.purplePrimary.withValues(alpha: 0.2)
        : const Color(0xFFEEF2FF);
    Color activeForeground = isDark ? Colors.white : WebColors.purplePrimary;
    Color inactiveForeground = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.symmetric(
        horizontal: isExpanded ? 16 : 0,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: isActive ? activeBg : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment:
            isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          Icon(
            isActive ? activeIcon : icon,
            color: isActive ? activeForeground : inactiveForeground,
            size: 22,
          ),
          if (isExpanded) ...[
            const SizedBox(width: 16),
            Text(
              label,
              style: GoogleFonts.inter(
                color: isActive ? activeForeground : inactiveForeground,
                fontSize: 14,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: isExpanded
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              hoverColor: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey[200],
              child: content,
            )
          : Tooltip(
              message: label,
              preferBelow: false,
              textStyle: GoogleFonts.inter(color: Colors.white, fontSize: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(6),
              ),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                hoverColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey[200],
                child: content,
              ),
            ),
    );
  }
}
