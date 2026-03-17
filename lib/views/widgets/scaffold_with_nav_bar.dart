import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../theme/web_theme.dart';

class ScaffoldWithNavBar extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const ScaffoldWithNavBar({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    void onTap(int index) {
      navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      );
    }

    final theme = Theme.of(context);
    final user = Provider.of<UserModel?>(context);
    final isTeacher = user?.role == UserRole.creator;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          // Use BottomNavigationBar for narrow screens
          return Scaffold(
            body: navigationShell,
            bottomNavigationBar: BottomNavigationBar(
              items: <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                    icon: Icon(isTeacher ? Icons.dashboard_outlined : Icons.home_outlined),
                    activeIcon: Icon(isTeacher ? Icons.dashboard : Icons.home),
                    label: isTeacher ? 'Dashboard' : 'Home'),
                BottomNavigationBarItem(
                    icon: Icon(isTeacher ? Icons.assignment_outlined : Icons.book_outlined),
                    activeIcon: Icon(isTeacher ? Icons.assignment : Icons.book),
                    label: isTeacher ? 'Exams' : 'Library'),
                BottomNavigationBarItem(
                    icon: const Icon(Icons.add_circle_outline),
                    activeIcon: const Icon(Icons.add_circle),
                    label: 'Create'),
                BottomNavigationBarItem(
                    icon: Icon(isTeacher ? Icons.analytics_outlined : Icons.show_chart_outlined),
                    activeIcon: Icon(isTeacher ? Icons.analytics : Icons.show_chart),
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
              currentIndex: navigationShell.currentIndex,
              onTap: onTap,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: theme.colorScheme.primary,
              unselectedItemColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          );
        } else {
          // Professional Web Sidebar (ChatGPT/Claude alike)
          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            body: Row(
              children: [
                Container(
                  width: 280,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A), // Dark slate like ChatGPT
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(2, 0),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Header / Logo
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.school, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'SumQuiz',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Primary Action
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: InkWell(
                          onTap: () => navigationShell.goBranch(2), // Create tab
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: WebColors.PremiumGradient,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: WebColors.accent.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.add_circle, color: WebColors.textPrimary, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    isTeacher ? 'Create New Exam' : 'Build Study Pack',
                                    style: const TextStyle(
                                      color: WebColors.textPrimary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.auto_awesome, color: Color(0xFFB45309), size: 14),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Navigation Items
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          children: [
                            _buildSidebarItem(
                              icon: isTeacher ? Icons.dashboard_outlined : Icons.auto_awesome_mosaic_outlined,
                              activeIcon: isTeacher ? Icons.dashboard : Icons.auto_awesome_mosaic,
                              label: isTeacher ? 'Dashboard' : 'Learning Home',
                              isActive: navigationShell.currentIndex == 0,
                              onTap: () => onTap(0),
                            ),
                            _buildSidebarItem(
                              icon: isTeacher ? Icons.assignment_outlined : Icons.inventory_2_outlined,
                              activeIcon: isTeacher ? Icons.assignment : Icons.inventory_2,
                              label: isTeacher ? 'Teaching Library' : 'My Library',
                              isActive: navigationShell.currentIndex == 1,
                              onTap: () => onTap(1),
                            ),
                            _buildSidebarItem(
                              icon: isTeacher ? Icons.analytics_outlined : Icons.insights_outlined,
                              activeIcon: isTeacher ? Icons.analytics : Icons.insights,
                              label: isTeacher ? 'Analytics' : 'Study Progress',
                              isActive: navigationShell.currentIndex == 3,
                              onTap: () => onTap(3),
                            ),
                            
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 20),
                              child: Divider(color: Colors.white12, thickness: 1),
                            ),
                            
                            _buildSidebarItem(
                              icon: Icons.person_outline,
                              activeIcon: Icons.person,
                              label: 'Profile',
                              isActive: navigationShell.currentIndex == 4,
                              onTap: () => onTap(4),
                            ),
                            _buildSidebarItem(
                              icon: Icons.settings_outlined,
                              activeIcon: Icons.settings,
                              label: 'Settings',
                              isActive: navigationShell.currentIndex == 5,
                              onTap: () => onTap(5),
                            ),
                          ],
                        ),
                      ),
                      
                      // Bottom User Info
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.2),
                          border: const Border(top: BorderSide(color: Colors.white10)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                              backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                              child: user?.photoURL == null 
                                ? Text(user?.displayName.characters.first.toUpperCase() ?? 'U', 
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))
                                : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    user?.displayName ?? 'User Name',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    isTeacher ? 'Educator Plan' : 'Standard Plan',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => onTap(5),
                              icon: const Icon(Icons.more_horiz, color: Colors.white54, size: 20),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: navigationShell,
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
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                isActive ? activeIcon : icon,
                color: isActive ? Colors.white : Colors.white60,
                size: 22,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.white60,
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
