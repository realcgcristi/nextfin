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
      ),
      darkTheme: buildNextfinTheme(
        Brightness.dark,
        palette: sett.themePalette,
      ),
      builder: (BuildContext context, Widget? child) {
        final mood = themeMoodOf(context);
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[mood.appBackgroundTop, mood.appBackgroundBottom],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Positioned(
                top: -80,
                right: -30,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: mood.appGlow,
                          blurRadius: 120,
                          spreadRadius: 24,
                        ),
                      ],
                    ),
                    child: const SizedBox(width: 180, height: 180),
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
