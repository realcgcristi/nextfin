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
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: mood.navSurface.withValues(alpha: 0.84),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: mood.navBorder.withValues(alpha: 0.36),
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: mood.appGlow.withValues(alpha: 0.12),
                            blurRadius: 18,
                            spreadRadius: 1,
                            offset: const Offset(0, 8),
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
