import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          // Mobile: Glassmorphic Bottom Navigation
          return Scaffold(
            extendBody: true, // Allow body to extend behind the nav bar
            body: navigationShell,
            bottomNavigationBar: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor.withValues(alpha: 0.7),
                    border: Border(
                      top: BorderSide(
                        color: theme.dividerColor.withValues(alpha: 0.2),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: BottomNavigationBar(
                    items: const <BottomNavigationBarItem>[
                      BottomNavigationBarItem(
                          icon: Icon(Icons.book_outlined),
                          activeIcon: Icon(Icons.book),
                          label: 'Library'),
                      BottomNavigationBarItem(
                          icon: Icon(Icons.school_outlined),
                          activeIcon: Icon(Icons.school),
                          label: 'Review'),
                      BottomNavigationBarItem(
                          icon: Icon(Icons.add_circle_outline),
                          activeIcon: Icon(Icons.add_circle),
                          label: 'Create'),
                      BottomNavigationBarItem(
                          icon: Icon(Icons.show_chart_outlined),
                          activeIcon: Icon(Icons.show_chart),
                          label: 'Progress'),
                    ],
                    currentIndex: navigationShell.currentIndex,
                    onTap: _onTap,
                    type: BottomNavigationBarType.fixed,
                    backgroundColor: Colors.transparent, // Important
                    elevation: 0,
                    selectedItemColor: theme.colorScheme.primary,
                    unselectedItemColor:
                        theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    selectedLabelStyle: theme.textTheme.labelMedium
                        ?.copyWith(fontWeight: FontWeight.w600, fontSize: 12),
                    unselectedLabelStyle: theme.textTheme.labelMedium
                        ?.copyWith(fontWeight: FontWeight.w400, fontSize: 12),
                  ),
                ),
              ),
            ),
          );
        } else {
          // Desktop/Tablet: Glassmorphic Navigation Rail
          return Scaffold(
            body: Row(
              children: [
                ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.cardColor.withValues(alpha: 0.7),
                        border: Border(
                          right: BorderSide(
                            color: theme.dividerColor.withValues(alpha: 0.2),
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: NavigationRail(
                        selectedIndex: navigationShell.currentIndex,
                        onDestinationSelected: _onTap,
                        labelType: NavigationRailLabelType.all,
                        backgroundColor: Colors.transparent,
                        destinations: const <NavigationRailDestination>[
                          NavigationRailDestination(
                              icon: Icon(Icons.book_outlined),
                              selectedIcon: Icon(Icons.book),
                              label: Text('Library')),
                          NavigationRailDestination(
                              icon: Icon(Icons.school_outlined),
                              selectedIcon: Icon(Icons.school),
                              label: Text('Review')),
                          NavigationRailDestination(
                              icon: Icon(Icons.add_circle_outline),
                              selectedIcon: Icon(Icons.add_circle),
                              label: Text('Create')),
                          NavigationRailDestination(
                              icon: Icon(Icons.show_chart_outlined),
                              selectedIcon: Icon(Icons.show_chart),
                              label: Text('Progress')),
                        ],
                        selectedIconTheme:
                            IconThemeData(color: theme.colorScheme.primary),
                        unselectedIconTheme: IconThemeData(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5)),
                        selectedLabelTextStyle:
                            theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        unselectedLabelTextStyle:
                            theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ),
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
}
