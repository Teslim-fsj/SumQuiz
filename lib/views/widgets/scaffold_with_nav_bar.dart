import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';

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
          // Use NavigationRail for wider screens
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: onTap,
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: Colors.white,
                   indicatorColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                  selectedIconTheme:
                      IconThemeData(color: theme.colorScheme.primary),
                  unselectedIconTheme:
                      IconThemeData(color: Colors.grey.shade400),
                  selectedLabelTextStyle: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12),
                  unselectedLabelTextStyle: TextStyle(
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                      fontSize: 12),
                  useIndicator: true,
                  // indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Optional custom shape
                  destinations: <NavigationRailDestination>[
                    NavigationRailDestination(
                        icon: Icon(isTeacher ? Icons.dashboard_outlined : Icons.home_outlined),
                        selectedIcon: Icon(isTeacher ? Icons.dashboard : Icons.home),
                        label: Text(isTeacher ? 'Dashboard' : 'Home')),
                    NavigationRailDestination(
                        icon: Icon(isTeacher ? Icons.assignment_outlined : Icons.book_outlined),
                        selectedIcon: Icon(isTeacher ? Icons.assignment : Icons.book),
                        label: Text(isTeacher ? 'Exams' : 'Library')),
                    NavigationRailDestination(
                        icon: const Icon(Icons.add_circle_outline),
                        selectedIcon: const Icon(Icons.add_circle),
                        label: const Text('Create')),
                    NavigationRailDestination(
                        icon: Icon(isTeacher ? Icons.analytics_outlined : Icons.show_chart_outlined),
                        selectedIcon: Icon(isTeacher ? Icons.analytics : Icons.show_chart),
                        label: Text(isTeacher ? 'Analytics' : 'Progress')),
                    NavigationRailDestination(
                        icon: const Icon(Icons.person_outline),
                        selectedIcon: const Icon(Icons.person),
                        label: const Text('Profile')),
                    NavigationRailDestination(
                        icon: const Icon(Icons.settings_outlined),
                        selectedIcon: const Icon(Icons.settings),
                        label: const Text('Settings')),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
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
}
