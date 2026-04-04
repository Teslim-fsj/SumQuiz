import 'package:flutter/foundation.dart' show kIsWeb;
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

    int indexToBranch(int index) {
      return index; 
    }

    int branchToIndex(int branch) {
      if (branch > 3) return -1; 
      return branch;
    }

    void onTap(int index) {
      final targetBranch = indexToBranch(index);
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
            bottomNavigationBar: BottomNavigationBar(
              items: [
                BottomNavigationBarItem(
                  icon: Icon(isTeacher
                      ? Icons.dashboard_outlined
                      : Icons.auto_awesome_mosaic_outlined),
                  activeIcon: Icon(isTeacher
                      ? Icons.dashboard
                      : Icons.auto_awesome_mosaic),
                  label: isTeacher ? 'Dashboard' : 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(isTeacher
                      ? Icons.inventory_2_outlined
                      : Icons.book_outlined),
                  activeIcon: Icon(
                      isTeacher ? Icons.inventory_2 : Icons.book),
                  label: isTeacher ? 'Content' : 'Library',
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.add_circle_outline),
                  activeIcon: const Icon(Icons.add_circle),
                  label: isTeacher ? 'Create' : 'New Set',
                ),
                BottomNavigationBarItem(
                  icon: Icon(isTeacher
                      ? Icons.analytics_outlined
                      : Icons.insights_outlined),
                  activeIcon: Icon(isTeacher
                      ? Icons.analytics
                      : Icons.insights),
                  label: isTeacher ? 'Analytics' : 'Progress',
                ),
              ],
              currentIndex: currentIdx == -1 ? 0 : currentIdx,
              onTap: onTap,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: theme.colorScheme.primary,
              unselectedItemColor:
                  theme.colorScheme.onSurface.withValues(alpha: 0.6),
              selectedFontSize: 10,
              unselectedFontSize: 10,
            ),
          );
        } else {
          return Scaffold(
            backgroundColor: theme.colorScheme.surface,
            body: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: _isExpanded ? 280 : 80,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                    border: Border(
                      right: BorderSide(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    boxShadow: [
                      if (!isDark)
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 15,
                          offset: const Offset(4, 0),
                        ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Header / Logo
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isExpanded) ...[
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    gradient: WebColors.HeroGradient,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Image.asset(
                                    'assets/images/sumquiz_logo.png',
                                    width: 24,
                                    height: 24,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Icon(Icons.school, color: Colors.white, size: 24),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  'SumQuiz',
                                  style: GoogleFonts.outfit(
                                    color: theme.colorScheme.onSurface,
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
                              Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: WebColors.HeroGradient,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Image.asset(
                                  'assets/images/sumquiz_logo.png',
                                  width: 24,
                                  height: 24,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.school, color: Colors.white, size: 24),
                                ),
                              ),
                            if (_isExpanded)
                              IconButton(
                                onPressed: () => setState(() => _isExpanded = !_isExpanded),
                                icon: Icon(
                                  Icons.menu_open_rounded,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                  size: 24,
                                ),
                                tooltip: 'Collapse',
                              ),
                          ],
                        ),
                      ),
                      
                      if (!_isExpanded)
                        IconButton(
                          onPressed: () => setState(() => _isExpanded = !_isExpanded),
                          icon: Icon(
                            Icons.menu_rounded,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            size: 24,
                          ),
                          tooltip: 'Expand',
                        ),

                      // Primary Action
                      Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: _isExpanded ? 16 : 12, vertical: 8),
                        child: InkWell(
                          onTap: () {
                            goToBranch(2);
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: EdgeInsets.symmetric(
                              horizontal: _isExpanded ? 16 : 0,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              gradient: WebColors.HeroGradient,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: _isExpanded
                                  ? MainAxisAlignment.start
                                  : MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_circle, color: Colors.white, size: 22),
                                if (_isExpanded) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      isTeacher ? 'Create Exam' : 'Build Study Pack',
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.auto_awesome, color: Colors.white70, size: 16),
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
                          padding: EdgeInsets.symmetric(horizontal: _isExpanded ? 12 : 8),
                          children: [
                            if (isTeacher) ...[
                              _buildSidebarItem(
                                icon: Icons.dashboard_outlined,
                                activeIcon: Icons.dashboard_rounded,
                                label: 'Dashboard',
                                isActive: widget.navigationShell.currentIndex == 0,
                                onTap: () => goToBranch(0),
                                isExpanded: _isExpanded,
                                theme: theme,
                              ),
                              _buildSidebarItem(
                                icon: Icons.inventory_2_outlined,
                                activeIcon: Icons.inventory_2_rounded,
                                label: 'Content Manager',
                                isActive: widget.navigationShell.currentIndex == 1,
                                onTap: () => goToBranch(1),
                                isExpanded: _isExpanded,
                                theme: theme,
                              ),
                              _buildSidebarItem(
                                icon: Icons.people_outline_rounded,
                                activeIcon: Icons.people_rounded,
                                label: 'Student Roster',
                                isActive: widget.navigationShell.currentIndex == 4,
                                onTap: () => goToBranch(4),
                                isExpanded: _isExpanded,
                                theme: theme,
                              ),
                              _buildSidebarItem(
                                icon: Icons.analytics_outlined,
                                activeIcon: Icons.analytics_rounded,
                                label: 'Analytics',
                                isActive: widget.navigationShell.currentIndex == 3,
                                onTap: () => goToBranch(3),
                                isExpanded: _isExpanded,
                                theme: theme,
                              ),
                              _buildSidebarItem(
                                icon: Icons.auto_awesome_rounded,
                                activeIcon: Icons.auto_awesome,
                                label: 'Class Intelligence',
                                isActive: widget.navigationShell.currentIndex == 5,
                                onTap: () => goToBranch(5),
                                isExpanded: _isExpanded,
                                theme: theme,
                              ),
                            ] else ...[
                              _buildSidebarItem(
                                icon: Icons.auto_awesome_mosaic_outlined,
                                activeIcon: Icons.auto_awesome_mosaic_rounded,
                                label: 'Home',
                                isActive: widget.navigationShell.currentIndex == 0,
                                onTap: () => goToBranch(0),
                                isExpanded: _isExpanded,
                                theme: theme,
                              ),
                              _buildSidebarItem(
                                icon: Icons.book_outlined,
                                activeIcon: Icons.book_rounded,
                                label: 'My Library',
                                isActive: widget.navigationShell.currentIndex == 1,
                                onTap: () => goToBranch(1),
                                isExpanded: _isExpanded,
                                theme: theme,
                              ),
                              _buildSidebarItem(
                                icon: Icons.insights_outlined,
                                activeIcon: Icons.insights_rounded,
                                label: 'Progress',
                                isActive: widget.navigationShell.currentIndex == 3,
                                onTap: () => goToBranch(3),
                                isExpanded: _isExpanded,
                                theme: theme,
                              ),
                            ],

                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: _isExpanded ? 16 : 8,
                                vertical: 24,
                              ),
                              child: Divider(
                                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                                thickness: 1,
                              ),
                            ),

                            _buildSidebarItem(
                              icon: Icons.person_outline,
                              activeIcon: Icons.person_rounded,
                              label: 'Profile',
                              isActive: widget.navigationShell.currentIndex == 6,
                              onTap: () => goToBranch(6),
                              isExpanded: _isExpanded,
                              theme: theme,
                            ),
                            _buildSidebarItem(
                              icon: Icons.settings_outlined,
                              activeIcon: Icons.settings_rounded,
                              label: 'Settings',
                              isActive: widget.navigationShell.currentIndex == 7,
                              onTap: () => goToBranch(7),
                              isExpanded: _isExpanded,
                              theme: theme,
                            ),
                          ],
                        ),
                      ),

                      // Upgrade to Pro Card
                      if (_isExpanded)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: isDark
                                  ? LinearGradient(
                                      colors: [
                                        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                        theme.colorScheme.surfaceContainer.withValues(alpha: 0.2),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color: isDark ? null : theme.colorScheme.primary.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                              ),
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
                                        color: theme.colorScheme.onSurface,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Unlock unlimited AI summaries and advanced study modes.',
                                  style: GoogleFonts.outfit(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () => context.push('/settings/subscription'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ).copyWith(
                                      backgroundColor: MaterialStateProperty.all(Colors.transparent),
                                    ),
                                    child: Ink(
                                      decoration: BoxDecoration(
                                        gradient: WebColors.PremiumGradient,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Container(
                                        alignment: Alignment.center,
                                        constraints: const BoxConstraints(minHeight: 40),
                                        child: Text(
                                          'Go Premium',
                                          style: GoogleFonts.outfit(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Bottom User Info
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: _isExpanded ? 24 : 16, vertical: 24),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.2)
                              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          border: Border(
                            top: BorderSide(
                              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              _isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 20,
                                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                                backgroundImage: user?.photoURL != null
                                    ? NetworkImage(user!.photoURL!)
                                    : null,
                                child: user?.photoURL == null
                                    ? Text(
                                        user?.displayName.characters.first.toUpperCase() ?? 'U',
                                        style: GoogleFonts.outfit(
                                          color: theme.colorScheme.primary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            if (_isExpanded) ...[
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      user?.displayName ?? 'User',
                                      style: GoogleFonts.outfit(
                                        color: theme.colorScheme.onSurface,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      isTeacher ? 'Pro Educator' : 'Learner',
                                      style: GoogleFonts.outfit(
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.verified_rounded,
                                color: theme.colorScheme.primary,
                                size: 16,
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

  Widget _buildSidebarItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required bool isExpanded,
    required ThemeData theme,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.symmetric(
        horizontal: isExpanded ? 16 : 0,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: isActive
            ? (isDark ? theme.colorScheme.primary.withValues(alpha: 0.15) : theme.colorScheme.primary.withValues(alpha: 0.08))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isActive
            ? Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                width: 1,
              )
            : Border.all(color: Colors.transparent),
      ),
      child: Row(
        mainAxisAlignment:
            isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          Icon(
            isActive ? activeIcon : icon,
            color: isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.5),
            size: 22,
          ),
          if (isExpanded) ...[
            const SizedBox(width: 16),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: isActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 15,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: isExpanded
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              hoverColor: theme.colorScheme.primary.withValues(alpha: 0.05),
              child: content,
            )
          : Tooltip(
              message: label,
              preferBelow: false,
              textStyle: GoogleFonts.outfit(color: Colors.white, fontSize: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(6),
              ),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                hoverColor: theme.colorScheme.primary.withValues(alpha: 0.05),
                child: content,
              ),
            ),
    );
  }
}
