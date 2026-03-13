import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/session_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/details/presentation/details_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/libraries/presentation/library_screen.dart';
import '../../features/player/presentation/player_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/settings/presentation/themes_screen.dart';
import '../../features/startup/presentation/startup_screen.dart';
import '../../shared/widgets/app_shell.dart';

final _routerRefreshProvider = Provider<_RouterRefresh>((Ref ref) {
  final refresh = _RouterRefresh(ref);
  ref.listen<SessionState>(sessionControllerProvider, (_, __) {
    refresh.bump();
  });
  ref.onDispose(refresh.dispose);
  return refresh;
});

final appRouterProvider = Provider<GoRouter>((Ref ref) {
  final refresh = ref.watch(_routerRefreshProvider);
  final router = GoRouter(
    initialLocation: '/startup',
    refreshListenable: refresh,
    redirect: (BuildContext context, GoRouterState state) {
      final session = refresh.session;
      final authenticated = session.isAuthenticated;
      final onStartup = state.matchedLocation == '/startup';
      final onLogin = state.matchedLocation == '/login';
      if (onStartup) return null;
      if (!authenticated && !onLogin) return '/login';
      if (authenticated && onLogin) return '/home';
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/startup',
        builder:
            (BuildContext context, GoRouterState state) =>
                const StartupScreen(),
      ),
      GoRoute(
        path: '/login',
        builder:
            (BuildContext context, GoRouterState state) => const LoginScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (
          BuildContext context,
          GoRouterState state,
          StatefulNavigationShell navigationShell,
        ) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/home',
                builder:
                    (BuildContext context, GoRouterState state) =>
                        const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/libraries',
                builder:
                    (BuildContext context, GoRouterState state) =>
                        const LibraryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/search',
                builder:
                    (BuildContext context, GoRouterState state) =>
                        const SearchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/settings',
                builder:
                    (BuildContext context, GoRouterState state) =>
                        const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/details/:id',
        builder:
            (BuildContext context, GoRouterState state) =>
                DetailsScreen(itemId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/player/:id',
        builder:
            (BuildContext context, GoRouterState state) => PlayerScreen(
              itemId: state.pathParameters['id'] ?? '',
              title: state.uri.queryParameters['title'] ?? 'Playback',
              initialPositionTicks:
                  int.tryParse(state.uri.queryParameters['startTicks'] ?? '') ??
                  0,
            ),
      ),
      GoRoute(
        path: '/themes',
        pageBuilder:
            (BuildContext context, GoRouterState state) => CustomTransitionPage(
              key: state.pageKey,
              transitionDuration: const Duration(milliseconds: 240),
              child: const ThemesScreen(),
              transitionsBuilder:
                  (
                    BuildContext context,
                    Animation<double> animation,
                    Animation<double> secondaryAnimation,
                    Widget child,
                  ) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.04, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
            ),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this._ref);

  final Ref _ref;

  SessionState get session => _ref.read(sessionControllerProvider);

  void bump() => notifyListeners();
}
