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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = Provider.of<UserModel?>(context);
    final isTeacher = user?.role == UserRole.creator;
    final isDark = theme.brightness == Brightness.dark;

    // For teachers on mobile: map 5 visible tabs to branches 0,1,2,3,5
    final List<int> teacherMobileBranches = [0, 1, 2, 3, 5];

    int branchToIndex(int branch) {
      if (isTeacher) {
        final idx = teacherMobileBranches.indexOf(branch);
        return idx; // -1 if not in list (e.g. branch 4,6,7)
      }
      if (branch > 3) return -1;
      return branch;
    }

    void onTap(int index) {
      final targetBranch = isTeacher ? teacherMobileBranches[index] : index;
      widget.navigationShell.goBranch(
        targetBranch,
        initialLocation: targetBranch == widget.navigationShell.currentIndex,
      );
    }

    void goToBranch(int branch) {
      widget.navigationShell.goBranch(
        branch,
        initialLocation: branch == widget.navigationShell.currentIndex,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          final currentIdx = branchToIndex(widget.navigationShell.currentIndex);
          return Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: widget.navigationShell,
            bottomNavigationBar: isTeacher
              ? BottomNavigationBar(
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.dashboard_outlined),
                      activeIcon: Icon(Icons.dashboard),
                      label: 'Dashboard',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.inventory_2_outlined),
                      activeIcon: Icon(Icons.inventory_2),
                      label: 'Content',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.add_circle_outline),
                      activeIcon: Icon(Icons.add_circle),
                      label: 'Create Exam',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.analytics_outlined),
                      activeIcon: Icon(Icons.analytics),
                      label: 'Analytics',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.auto_awesome_outlined),
                      activeIcon: Icon(Icons.auto_awesome),
                      label: 'AI Feedback',
                    ),
                  ],
                  currentIndex: currentIdx < 0 ? 0 : currentIdx,
                  onTap: onTap,
                  type: BottomNavigationBarType.fixed,
                  selectedItemColor: WebColors.purplePrimary,
                  unselectedItemColor: Colors.grey[500],
                  selectedFontSize: 10,
                  unselectedFontSize: 10,
                  selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  unselectedLabelStyle: GoogleFonts.inter(),
                )
              : BottomNavigationBar(
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.auto_awesome_mosaic_outlined),
                      activeIcon: Icon(Icons.auto_awesome_mosaic),
                      label: 'Home',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.book_outlined),
                      activeIcon: Icon(Icons.book),
                      label: 'Library',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.add_circle_outline),
                      activeIcon: Icon(Icons.add_circle),
                      label: 'New Set',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.insights_outlined),
                      activeIcon: Icon(Icons.insights),
                      label: 'Progress',
                    ),
                  ],
                  currentIndex: currentIdx == -1 ? 0 : currentIdx,
                  onTap: onTap,
                  type: BottomNavigationBarType.fixed,
                  selectedItemColor: WebColors.purplePrimary,
                  unselectedItemColor: Colors.grey[500],
                  selectedFontSize: 11,
                  unselectedFontSize: 11,
                  selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  unselectedLabelStyle: GoogleFonts.inter(),
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
                      // Header / Logo
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

                      // Primary Action - Pill Design
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: _isExpanded ? 20 : 12, vertical: 12),
                        child: InkWell(
                          onTap: () => goToBranch(2),
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
                              mainAxisAlignment: _isExpanded
                                  ? MainAxisAlignment.center
                                  : MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add, color: Colors.white, size: 20),
                                if (_isExpanded) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    isTeacher ? 'Create Exam' : 'Build Study Pack',
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

                      // Navigation Items
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
                                onTap: () => goToBranch(0),
                                isExpanded: _isExpanded,
                                isDark: isDark,
                              ),
                              _buildSidebarTab(
                                icon: Icons.inventory_2_outlined,
                                activeIcon: Icons.inventory_2_rounded,
                                label: 'Content Manager',
                                isActive: widget.navigationShell.currentIndex == 1,
                                onTap: () => goToBranch(1),
                                isExpanded: _isExpanded,
                                isDark: isDark,
                              ),
                              _buildSidebarTab(
                                icon: Icons.people_outline_rounded,
                                activeIcon: Icons.people_rounded,
                                label: 'Student Roster',
                                isActive: widget.navigationShell.currentIndex == 4,
                                onTap: () => goToBranch(4),
                                isExpanded: _isExpanded,
                                isDark: isDark,
                              ),
                              _buildSidebarTab(
                                icon: Icons.analytics_outlined,
                                activeIcon: Icons.analytics_rounded,
                                label: 'Analytics',
                                isActive: widget.navigationShell.currentIndex == 3,
                                onTap: () => goToBranch(3),
                                isExpanded: _isExpanded,
                                isDark: isDark,
                              ),
                              _buildSidebarTab(
                                icon: Icons.auto_awesome_rounded,
                                activeIcon: Icons.auto_awesome,
                                label: 'Class Intelligence',
                                isActive: widget.navigationShell.currentIndex == 5,
                                onTap: () => goToBranch(5),
                                isExpanded: _isExpanded,
                                isDark: isDark,
                              ),
                            ] else ...[
                              _buildSidebarTab(
                                icon: Icons.auto_awesome_mosaic_outlined,
                                activeIcon: Icons.auto_awesome_mosaic_rounded,
                                label: 'Home',
                                isActive: widget.navigationShell.currentIndex == 0,
                                onTap: () => goToBranch(0),
                                isExpanded: _isExpanded,
                                isDark: isDark,
                              ),
                              _buildSidebarTab(
                                icon: Icons.book_outlined,
                                activeIcon: Icons.book_rounded,
                                label: 'My Library',
                                isActive: widget.navigationShell.currentIndex == 1,
                                onTap: () => goToBranch(1),
                                isExpanded: _isExpanded,
                                isDark: isDark,
                              ),
                              _buildSidebarTab(
                                icon: Icons.insights_outlined,
                                activeIcon: Icons.insights_rounded,
                                label: 'Progress',
                                isActive: widget.navigationShell.currentIndex == 3,
                                onTap: () => goToBranch(3),
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
                              onTap: () => goToBranch(6),
                              isExpanded: _isExpanded,
                              isDark: isDark,
                            ),
                            _buildSidebarTab(
                              icon: Icons.settings_outlined,
                              activeIcon: Icons.settings_rounded,
                              label: 'Settings',
                              isActive: widget.navigationShell.currentIndex == 7,
                              onTap: () => goToBranch(7),
                              isExpanded: _isExpanded,
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),

                      // Upgrade to Pro Card - Premium Design
                      if (_isExpanded)
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

                      // Minimal User Profile Footer
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
