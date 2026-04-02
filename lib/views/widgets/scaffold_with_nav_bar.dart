import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
    void onTap(int index) {
      widget.navigationShell.goBranch(
        index,
        initialLocation: index == widget.navigationShell.currentIndex,
      );
    }

    final theme = Theme.of(context);
    final user = Provider.of<UserModel?>(context);
    final isTeacher = user?.role == UserRole.creator;
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          // Use BottomNavigationBar for narrow screens
          return Scaffold(
            body: widget.navigationShell,
            bottomNavigationBar: BottomNavigationBar(
              items: <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                    icon: Icon(isTeacher
                        ? Icons.dashboard_outlined
                        : Icons.home_outlined),
                    activeIcon: Icon(isTeacher ? Icons.dashboard : Icons.home),
                    label: isTeacher ? 'Dashboard' : 'Home'),
                BottomNavigationBarItem(
                    icon: Icon(isTeacher
                        ? Icons.assignment_outlined
                        : Icons.book_outlined),
                    activeIcon: Icon(isTeacher ? Icons.assignment : Icons.book),
                    label: isTeacher ? 'Exams' : 'Library'),
                BottomNavigationBarItem(
                    icon: const Icon(Icons.add_circle_outline),
                    activeIcon: const Icon(Icons.add_circle),
                    label: 'Create'),
                BottomNavigationBarItem(
                    icon: Icon(isTeacher
                        ? Icons.analytics_outlined
                        : Icons.show_chart_outlined),
                    activeIcon:
                        Icon(isTeacher ? Icons.analytics : Icons.show_chart),
                    label: isTeacher ? 'Analytics' : 'Progress'),
                BottomNavigationBarItem(
                    icon: const Icon(Icons.person_outline),
                    activeIcon: const Icon(Icons.person),
                    label: 'Profile'),
                BottomNavigationBarItem(
                    icon: const Icon(Icons.settings_outlined),
                    activeIcon: const Icon(Icons.settings),
                    label: 'Settings'),
              ],
              currentIndex: widget.navigationShell.currentIndex,
              onTap: onTap,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: theme.colorScheme.primary,
              unselectedItemColor:
                  theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          );
        } else {
          // Professional Web Sidebar (ChatGPT/Claude alike)
          return Scaffold(
            backgroundColor: theme.colorScheme.surface,
            body: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: _isExpanded ? 280 : 80,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF171717)
                        : const Color(0xFFF8FAFC),
                    border: Border(
                      right: BorderSide(
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 15,
                        offset: const Offset(2, 0),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Header / Logo
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: _isExpanded ? 20 : 0,
                          vertical: 24,
                        ),
                        child: Row(
                          mainAxisAlignment: _isExpanded
                              ? MainAxisAlignment.start
                              : MainAxisAlignment.center,
                          children: [
                            if (_isExpanded) ...[
                              Image.asset(
                                'assets/images/sumquiz_logo.png',
                                width: 32,
                                height: 32,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      gradient: WebColors.HeroGradient,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.school,
                                        color: Colors.white, size: 24),
                                  );
                                },
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'SumQuiz',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const Spacer(),
                            ],
                            IconButton(
                              onPressed: () =>
                                  setState(() => _isExpanded = !_isExpanded),
                              icon: Icon(
                                _isExpanded
                                    ? Icons.menu_open_rounded
                                    : Icons.menu_rounded,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                                size: 24,
                              ),
                              tooltip: _isExpanded ? 'Collapse' : 'Expand',
                            ),
                          ],
                        ),
                      ),

                      // Primary Action
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: InkWell(
                          onTap: () {
                            if (isTeacher) {
                              // Teachers go to Exam Creation screen
                              context.go('/exam-creation');
                            } else {
                              // Students go to Content/Study Pack creation
                              widget.navigationShell.goBranch(2);
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: EdgeInsets.symmetric(
                              horizontal: _isExpanded ? 16 : 0,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              gradient: WebColors.HeroGradient,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: _isExpanded
                                  ? MainAxisAlignment.start
                                  : MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_circle,
                                    color: Colors.white, size: 20),
                                if (_isExpanded) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      isTeacher
                                          ? 'Create Exam'
                                          : 'Build Study Pack',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.auto_awesome,
                                      color: Colors.white70, size: 14),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Navigation Items - Role-Based Workflows
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          children: [
                            // === TEACHER WORKFLOW ===
                            if (isTeacher) ...[
                              _buildSidebarItem(
                                icon: Icons.dashboard_outlined,
                                activeIcon: Icons.dashboard,
                                label: 'Dashboard',
                                isActive:
                                    widget.navigationShell.currentIndex == 0,
                                onTap: () => onTap(0),
                                isExpanded: _isExpanded,
                                theme: theme,
                              ),
                              _buildSidebarItem(
                                icon: Icons.inventory_2_outlined,
                                activeIcon: Icons.inventory_2,
                                label: 'Content Manager',
                                isActive:
                                    widget.navigationShell.currentIndex == 1,
                                onTap: () => onTap(1),
                                isExpanded: _isExpanded,
                                theme: theme,
                              ),
                              _buildSidebarItem(
                                icon: Icons.people_outline_rounded,
                                activeIcon: Icons.people_rounded,
                                label: 'Students',
                                isActive:
                                    widget.navigationShell.currentIndex == 2,
                                onTap: () => onTap(2),
                                isExpanded: _isExpanded,
                                theme: theme,
                              ),
                              _buildSidebarItem(
                                icon: Icons.analytics_outlined,
                                activeIcon: Icons.analytics,
                                label: 'Analytics',
                                isActive:
                                    widget.navigationShell.currentIndex == 3,
                                onTap: () => onTap(3),
                                isExpanded: _isExpanded,
                                theme: theme,
                              ),
                              _buildSidebarItem(
                                icon: Icons.auto_awesome_rounded,
                                activeIcon: Icons.auto_awesome,
                                label: 'AI Insights',
                                isActive:
                                    widget.navigationShell.currentIndex == 4,
                                onTap: () => onTap(4),
                                isExpanded: _isExpanded,
                                theme: theme,
                              ),
                            ] else
                              // === STUDENT WORKFLOW ===
                              ...[
                              _buildSidebarItem(
                                icon: Icons.auto_awesome_mosaic_outlined,
                                activeIcon: Icons.auto_awesome_mosaic,
                                label: 'Home',
                                isActive:
                                    widget.navigationShell.currentIndex == 0,
                                onTap: () => onTap(0),
                                isExpanded: _isExpanded,
                                theme: theme,
                              ),
                              _buildSidebarItem(
                                icon: Icons.book_outlined,
                                activeIcon: Icons.book,
                                label: 'My Library',
                                isActive:
                                    widget.navigationShell.currentIndex == 1,
                                onTap: () => onTap(1),
                                isExpanded: _isExpanded,
                                theme: theme,
                              ),
                              _buildSidebarItem(
                                icon: Icons.insights_outlined,
                                activeIcon: Icons.insights,
                                label: 'Progress',
                                isActive:
                                    widget.navigationShell.currentIndex == 2,
                                onTap: () => onTap(2),
                                isExpanded: _isExpanded,
                                theme: theme,
                              ),
                            ],

                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: _isExpanded ? 8 : 4,
                                vertical: 20,
                              ),
                              child: Divider(
                                color: theme.colorScheme.outlineVariant
                                    .withValues(alpha: 0.3),
                                thickness: 1,
                              ),
                            ),

                            _buildSidebarItem(
                              icon: Icons.person_outline,
                              activeIcon: Icons.person,
                              label: 'Profile',
                              isActive:
                                  widget.navigationShell.currentIndex == 4,
                              onTap: () => onTap(4),
                              isExpanded: _isExpanded,
                              theme: theme,
                            ),
                            _buildSidebarItem(
                              icon: Icons.settings_outlined,
                              activeIcon: Icons.settings,
                              label: 'Settings',
                              isActive:
                                  widget.navigationShell.currentIndex == 5,
                              onTap: () => onTap(5),
                              isExpanded: _isExpanded,
                              theme: theme,
                            ),
                          ],
                        ),
                      ),

                      // Bottom User Info
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 20),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.1)
                              : Colors.white,
                          border: Border(
                            top: BorderSide(
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: _isExpanded
                              ? MainAxisAlignment.start
                              : MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: theme.colorScheme.primary
                                  .withValues(alpha: 0.1),
                              backgroundImage: user?.photoURL != null
                                  ? NetworkImage(user!.photoURL!)
                                  : null,
                              child: user?.photoURL == null
                                  ? Text(
                                      user?.displayName.characters.first
                                              .toUpperCase() ??
                                          'U',
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            if (_isExpanded) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      user?.displayName ?? 'User',
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurface,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      isTeacher ? 'Pro Educator' : 'Learner',
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.5),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.verified_rounded,
                                color: theme.colorScheme.primary,
                                size: 14,
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
    final content = Container(
      padding: EdgeInsets.symmetric(
        horizontal: isExpanded ? 16 : 0,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: isActive
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment:
            isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          Icon(
            isActive ? activeIcon : icon,
            color: isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            size: 22,
          ),
          if (isExpanded) ...[
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: isActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
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
              child: content,
            )
          : Tooltip(
              message: label,
              preferBelow: false,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: content,
              ),
            ),
    );
  }
}
