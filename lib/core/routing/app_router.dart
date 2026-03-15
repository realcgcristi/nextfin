import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/session_controller.dart';
import '../../features/auth/presentation/login_flow_screen.dart';
import '../../features/details/presentation/details_screen.dart';
import '../../features/downloads/presentation/downloads_screen.dart';
import '../../features/home/presentation/home_editorial_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/libraries/presentation/libraries_explorer_screen.dart';
import '../../features/player/presentation/player_screen.dart';
import '../../features/search/presentation/search_canvas_screen.dart';
import '../../features/settings/presentation/settings_hub_screen.dart';
import '../../features/settings/presentation/themes_studio_screen.dart';
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
            (BuildContext context, GoRouterState state) =>
                const LoginFlowScreen(),
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
                        const HomeEditorialScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/libraries',
                builder:
                    (BuildContext context, GoRouterState state) =>
                        const LibrariesExplorerScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/search',
                builder:
                    (BuildContext context, GoRouterState state) =>
                        const SearchCanvasScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/settings',
                builder:
                    (BuildContext context, GoRouterState state) =>
                        const SettingsHubScreen(),
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
              filePath: state.uri.queryParameters['filePath'],
              initialPositionTicks:
                  int.tryParse(state.uri.queryParameters['startTicks'] ?? '') ??
                  0,
            ),
      ),
      GoRoute(
        path: '/themes',
        builder:
            (BuildContext context, GoRouterState state) =>
                const ThemesStudioScreen(),
      ),
      GoRoute(
        path: '/history',
        builder:
            (BuildContext context, GoRouterState state) =>
                const HistoryScreen(),
      ),
      GoRoute(
        path: '/downloads',
        builder:
            (BuildContext context, GoRouterState state) =>
                const DownloadsScreen(),
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
