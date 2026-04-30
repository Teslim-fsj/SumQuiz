import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../theme/web_theme.dart';

class ScaffoldWithNavBar extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const ScaffoldWithNavBar({super.key, required this.navigationShell});

  @override
  State<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

class _ScaffoldWithNavBarState extends State<ScaffoldWithNavBar> {
  bool _isExpanded = true;

  int _branchToIndex(int branch, bool isTeacher) {
    if (isTeacher) {
      final List<int> teacherMobileBranches = [0, 1, 4, 5, 6];
      final idx = teacherMobileBranches.indexOf(branch);
      return idx;
    }
    // Student mapping: Home(0), Library(1), Progress(3), Profile(6)
    if (branch == 0) return 0;
    if (branch == 1) return 1;
    if (branch == 3) return 2;
    if (branch == 6) return 3;
    return -1;
  }

  void _onTap(int index, bool isTeacher) {
    int targetBranch;
    if (isTeacher) {
      final List<int> teacherMobileBranches = [0, 1, 4, 5, 6];
      targetBranch = teacherMobileBranches[index];
    } else {
      // Student mapping: index 0 -> branch 0, 1 -> 1, 2 -> 3, 3 -> 6
      final studentBranches = [0, 1, 3, 6];
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
        if (constraints.maxWidth < 900) {
          final currentIdx = _branchToIndex(widget.navigationShell.currentIndex, isTeacher);
          return Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: widget.navigationShell,
            floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                if (isTeacher) {
                  _showCreateOptions(context, theme);
                } else {
                  context.go('/create-content');
                }
              },
              backgroundColor: WebColors.purplePrimary,
              elevation: 4,
              shape: const CircleBorder(),
              child: const Icon(Icons.add, color: Colors.white, size: 32),
            ),
            bottomNavigationBar: isTeacher
              ? BottomAppBar(
                  padding: EdgeInsets.zero,
                  notchMargin: 8,
                  shape: const CircularNotchedRectangle(),
                  color: theme.cardColor.withValues(alpha: 0.9),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMobileNavItem(
                        icon: Icons.dashboard_outlined,
                        activeIcon: Icons.dashboard,
                        label: 'Home',
                        isActive: currentIdx == 0,
                        onTap: () => _onTap(0, isTeacher),
                      ),
                      _buildMobileNavItem(
                        icon: Icons.inventory_2_outlined,
                        activeIcon: Icons.inventory_2,
                        label: 'Content',
                        isActive: currentIdx == 1,
                        onTap: () => _onTap(1, isTeacher),
                      ),
                      const SizedBox(width: 48), // Space for FAB
                      _buildMobileNavItem(
                        icon: Icons.people_outline,
                        activeIcon: Icons.people,
                        label: 'Class',
                        isActive: currentIdx == 2,
                        onTap: () => _onTap(2, isTeacher),
                      ),
                      _buildMobileNavItem(
                        icon: Icons.auto_awesome_rounded,
                        activeIcon: Icons.auto_awesome,
                        label: 'Insights',
                        isActive: currentIdx == 3,
                        onTap: () => _onTap(3, isTeacher),
                      ),
                      _buildMobileNavItem(
                        icon: Icons.person_outline,
                        activeIcon: Icons.person,
                        label: 'Profile',
                        isActive: currentIdx == 4,
                        onTap: () => _onTap(4, isTeacher),
                      ),
                    ],
                  ),
                )
              : BottomAppBar(
                  padding: EdgeInsets.zero,
                  notchMargin: 8,
                  shape: const CircularNotchedRectangle(),
                  color: theme.cardColor.withValues(alpha: 0.9),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMobileNavItem(
                        icon: Icons.auto_awesome_mosaic_outlined,
                        activeIcon: Icons.auto_awesome_mosaic,
                        label: 'Home',
                        isActive: currentIdx == 0,
                        onTap: () => _onTap(0, isTeacher),
                      ),
                      _buildMobileNavItem(
                        icon: Icons.book_outlined,
                        activeIcon: Icons.book,
                        label: 'Library',
                        isActive: currentIdx == 1,
                        onTap: () => _onTap(1, isTeacher),
                      ),
                      const SizedBox(width: 48), // Space for FAB
                      _buildMobileNavItem(
                        icon: Icons.insights_outlined,
                        activeIcon: Icons.insights,
                        label: 'Progress',
                        isActive: currentIdx == 2,
                        onTap: () => _onTap(2, isTeacher),
                      ),
                      _buildMobileNavItem(
                        icon: Icons.person_outline,
                        activeIcon: Icons.person,
                        label: 'Profile',
                        isActive: currentIdx == 3,
                        onTap: () => _onTap(3, isTeacher),
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
                  width: _isExpanded ? 280 : 80,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    border: Border(
                      right: BorderSide(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200]!,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isExpanded) ...[
                              Image.asset(
                                'assets/images/sumquiz_logo.png',
                                width: 28,
                                height: 28,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.school, color: WebColors.purplePrimary, size: 28),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'SumQuiz',
                                  style: GoogleFonts.outfit(
                                    color: isDark ? Colors.white : const Color(0xFF1F1F1F),
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
                                      const Icon(Icons.school, color: WebColors.purplePrimary, size: 28),
                                ),
                              ),
                            if (_isExpanded)
                              IconButton(
                                onPressed: () => setState(() => _isExpanded = !_isExpanded),
                                icon: Icon(
                                  Icons.chevron_left_rounded,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
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
                          onPressed: () => setState(() => _isExpanded = !_isExpanded),
                          icon: Icon(
                            Icons.chevron_right_rounded,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            size: 28,
                          ),
                          tooltip: 'Expand',
                        ),

                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: _isExpanded ? 20 : 12, vertical: 12),
                        child: InkWell(
                          onTap: () {
                            if (isTeacher) {
                              context.go('/create-content/exam-wizard');
                            } else {
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
                                  color: WebColors.purplePrimary.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add, color: Colors.white, size: 20),
                                if (_isExpanded) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    isTeacher ? 'Create Exam' : 'Create Study Pack',
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
                          padding: EdgeInsets.symmetric(horizontal: _isExpanded ? 16 : 8),
                          children: [
                            if (isTeacher) ...[
                              _buildSidebarTab(
                                icon: Icons.dashboard_outlined,
                                activeIcon: Icons.dashboard_rounded,
                                label: 'Dashboard',
                                isActive: widget.navigationShell.currentIndex == 0,
                                onTap: () => _goToBranch(0),
                                isExpanded: _isExpanded,
                                isDark: isDark,
                              ),
                              _buildSidebarTab(
                                icon: Icons.inventory_2_outlined,
                                activeIcon: Icons.inventory_2_rounded,
                                label: 'Content Manager',
                                isActive: widget.navigationShell.currentIndex == 1,
                                onTap: () => _goToBranch(1),
                                isExpanded: _isExpanded,
                                isDark: isDark,
                              ),
                              _buildSidebarTab(
                                icon: Icons.people_outline_rounded,
                                activeIcon: Icons.people_rounded,
                                label: 'Student Roster',
                                isActive: widget.navigationShell.currentIndex == 4,
                                onTap: () => _goToBranch(4),
                                isExpanded: _isExpanded,
                                isDark: isDark,
                              ),
                              _buildSidebarTab(
                                icon: Icons.analytics_outlined,
                                activeIcon: Icons.analytics_rounded,
                                label: 'Analytics',
                                isActive: widget.navigationShell.currentIndex == 3,
                                onTap: () => _goToBranch(3),
                                isExpanded: _isExpanded,
                                isDark: isDark,
                              ),
                              _buildSidebarTab(
                                icon: Icons.auto_awesome_rounded,
                                activeIcon: Icons.auto_awesome,
                                label: 'Class Intelligence',
                                isActive: widget.navigationShell.currentIndex == 5,
                                onTap: () => _goToBranch(5),
                                isExpanded: _isExpanded,
                                isDark: isDark,
                              ),
                            ] else ...[
                              _buildSidebarTab(
                                icon: Icons.auto_awesome_mosaic_outlined,
                                activeIcon: Icons.auto_awesome_mosaic_rounded,
                                label: 'Home',
                                isActive: widget.navigationShell.currentIndex == 0,
                                onTap: () => _goToBranch(0),
                                isExpanded: _isExpanded,
                                isDark: isDark,
                              ),
                              _buildSidebarTab(
                                icon: Icons.book_outlined,
                                activeIcon: Icons.book_rounded,
                                label: 'My Library',
                                isActive: widget.navigationShell.currentIndex == 1,
                                onTap: () => _goToBranch(1),
                                isExpanded: _isExpanded,
                                isDark: isDark,
                              ),
                              _buildSidebarTab(
                                icon: Icons.insights_outlined,
                                activeIcon: Icons.insights_rounded,
                                label: 'Progress',
                                isActive: widget.navigationShell.currentIndex == 3,
                                onTap: () => _goToBranch(3),
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
                                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200]!,
                                thickness: 1,
                              ),
                            ),

                            _buildSidebarTab(
                              icon: Icons.person_outline,
                              activeIcon: Icons.person_rounded,
                              label: 'Profile',
                              isActive: widget.navigationShell.currentIndex == 6,
                              onTap: () => _goToBranch(6),
                              isExpanded: _isExpanded,
                              isDark: isDark,
                            ),
                            _buildSidebarTab(
                              icon: Icons.settings_outlined,
                              activeIcon: Icons.settings_rounded,
                              label: 'Settings',
                              isActive: widget.navigationShell.currentIndex == 7,
                              onTap: () => _goToBranch(7),
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
                                      const Icon(Icons.stars_rounded, color: Color(0xFFFACC15), size: 20),
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
                        padding: EdgeInsets.symmetric(horizontal: _isExpanded ? 24 : 16, vertical: 24),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200]!,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: _isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: WebColors.purplePrimary.withValues(alpha: 0.1),
                              backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                              child: user?.photoURL == null
                                  ? Text(
                                      user?.displayName.characters.first.toUpperCase() ?? 'U',
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
                                        color: isDark ? Colors.white : const Color(0xFF1F1F1F),
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
                                        color: isDark ? Colors.grey[500] : Colors.grey[600],
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

  void _showCreateOptions(BuildContext context, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Create New Content',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            _buildCreateOption(
              context,
              title: 'Exam / Quiz',
              subtitle: 'Structured assessment with advanced analytics',
              icon: Icons.assignment_outlined,
              color: WebColors.purplePrimary,
              onTap: () {
                Navigator.pop(context);
                context.go('/create-content/exam-wizard');
              },
            ),
            const SizedBox(height: 16),
            _buildCreateOption(
              context,
              title: 'Study Pack',
              subtitle: 'Summaries, Quizzes, and Flashcards from any source',
              icon: Icons.auto_awesome_outlined,
              color: const Color(0xFF0D9488),
              onTap: () {
                Navigator.pop(context);
                _goToBranch(2);
              },
            ),
            const SizedBox(height: 16),
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

  Widget _buildCreateOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: theme.dividerColor),
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
    Color activeBg = isDark ? WebColors.purplePrimary.withValues(alpha: 0.2) : const Color(0xFFEEF2FF);
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
        mainAxisAlignment: isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
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
              hoverColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200],
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
                hoverColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200],
                child: content,
              ),
            ),
    );
  }
}
