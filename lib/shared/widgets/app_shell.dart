import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final mood = themeMoodOf(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: mood.navSurface.withValues(alpha: 0.89),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: mood.navBorder.withValues(alpha: 0.74),
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: mood.appGlow.withValues(alpha: 0.16),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: NavigationBar(
                        backgroundColor: Colors.transparent,
                        height: 68,
                        selectedIndex: navigationShell.currentIndex,
                        destinations: const <Widget>[
                          NavigationDestination(
                            icon: Icon(Icons.home_outlined),
                            selectedIcon: Icon(Icons.home),
                            label: 'Home',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.video_library_outlined),
                            selectedIcon: Icon(Icons.video_library),
                            label: 'Libraries',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.search),
                            label: 'Search',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.settings_outlined),
                            selectedIcon: Icon(Icons.settings),
                            label: 'Settings',
                          ),
                        ],
                        onDestinationSelected: (int index) {
                          navigationShell.goBranch(
                            index,
                            initialLocation: index == navigationShell.currentIndex,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
