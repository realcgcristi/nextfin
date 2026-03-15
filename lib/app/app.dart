import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/routing/app_router.dart';
import '../core/storage/app_storage.dart';
import '../core/theme/app_theme.dart';

class NextfinApp extends ConsumerWidget {
  const NextfinApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nav = ref.watch(appRouterProvider);
    final mode = ref.watch(themeModeProvider);
    final sett = ref.watch(clientSettingsProvider);

    return MaterialApp.router(
      title: 'Nextfin',
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: buildNextfinTheme(
        Brightness.light,
        palette: sett.themePalette,
        density: sett.layoutDensity,
      ),
      darkTheme: buildNextfinTheme(
        Brightness.dark,
        palette: sett.themePalette,
        density: sett.layoutDensity,
      ),
      builder: (BuildContext context, Widget? child) {
        final mood = themeMoodOf(context);
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.78, -0.88),
              radius: 1.6,
              colors: <Color>[
                Color.alphaBlend(
                  mood.appGlow.withValues(alpha: 0.22),
                  mood.appBackgroundTop,
                ),
                mood.appBackgroundTop,
                mood.appBackgroundBottom,
              ],
              stops: const <double>[0, 0.42, 1],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Positioned(
                top: -110,
                left: -40,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: mood.appGlow.withValues(alpha: 0.9),
                          blurRadius: 180,
                          spreadRadius: 42,
                        ),
                      ],
                    ),
                    child: const SizedBox(width: 260, height: 260),
                  ),
                ),
              ),
              Positioned(
                right: -90,
                top: 120,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: mood.appGlow.withValues(alpha: 0.52),
                          blurRadius: 200,
                          spreadRadius: 44,
                        ),
                      ],
                    ),
                    child: const SizedBox(width: 240, height: 240),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Colors.transparent,
                          Colors.transparent,
                          mood.appBackgroundBottom.withValues(alpha: 0.42),
                        ],
                        stops: const <double>[0, 0.62, 1],
                      ),
                    ),
                  ),
                ),
              ),
              if (child != null) Positioned.fill(child: child),
            ],
          ),
        );
      },
      routerConfig: nav,
    );
  }
}

class NextfinBootstrapFailureApp extends StatelessWidget {
  const NextfinBootstrapFailureApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildNextfinTheme(
        Brightness.dark,
        palette: AppThemePalette.nextfin,
        density: LayoutDensity.comfortable,
      ),
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.error_outline_rounded, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Nextfin could not finish startup.',
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(message, textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
