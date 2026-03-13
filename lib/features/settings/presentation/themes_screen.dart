import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/app_storage.dart';
import '../../../core/theme/app_theme.dart';

class ThemesScreen extends ConsumerWidget {
  const ThemesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sett = ref.watch(clientSettingsProvider);
    final ctrl = ref.read(clientSettingsProvider.notifier);
    final mode = ref.watch(themeModeProvider);
    final mood = themeMoodOf(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Themes')),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.72, -0.95),
            radius: 1.08,
            colors: <Color>[
              mood.appGlow.withValues(alpha: 0.42),
              Colors.transparent,
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: <Widget>[
            Text(
              'Colors',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              paletteFor(sett.themePalette).name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            _ThemePreview(palette: sett.themePalette, themeMode: mode),
            const SizedBox(height: 22),
            SizedBox(
              height: 86,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: themePalettes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (BuildContext context, int index) {
                  final palette = themePalettes[index];
                  final selected = palette.id == sett.themePalette;
                  final activeMood =
                      mode == ThemeMode.light
                          ? palette.lightMood
                          : palette.darkMood;
                  return InkWell(
                    onTap:
                        () => ctrl.update(
                          sett.copyWith(themePalette: palette.id),
                        ),
                    borderRadius: BorderRadius.circular(24),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 164,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[
                            activeMood.previewTop,
                            activeMood.previewBottom,
                          ],
                        ),
                        border: Border.all(
                          color:
                              selected
                                  ? Theme.of(context).colorScheme.onSurface
                                  : activeMood.navBorder.withValues(
                                    alpha: 0.82,
                                  ),
                          width: selected ? 1.8 : 1,
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: activeMood.appGlow.withValues(alpha: 0.28),
                            blurRadius: 20,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Row(
                        children: <Widget>[
                          ...<Color>[
                            palette.lightSeed,
                            palette.darkSeed,
                            activeMood.navSurface,
                          ].map(
                            (Color color) => Container(
                              width: 15,
                              height: 15,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              palette.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (selected)
                            Icon(
                              Icons.check_circle_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.palette, required this.themeMode});

  final AppThemePalette palette;
  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    final brightness =
        themeMode == ThemeMode.light ? Brightness.light : Brightness.dark;
    final paletteDefinition = paletteFor(palette);
    final previewTheme = buildNextfinTheme(brightness, palette: palette);
    final mood =
        brightness == Brightness.light
            ? paletteDefinition.lightMood
            : paletteDefinition.darkMood;
    final scheme = previewTheme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[mood.previewTop, mood.previewBottom],
        ),
        border: Border.all(color: mood.navBorder.withValues(alpha: 0.78)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: mood.appGlow.withValues(alpha: 0.28),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.palette_rounded, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Text(
                paletteDefinition.name,
                style: previewTheme.textTheme.titleLarge?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: mood.navBorder),
            ),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.play_circle_fill_rounded,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Nextfin',
                        style: previewTheme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: mood.navSurface,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'av',
                        style: previewTheme.textTheme.labelLarge?.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  height: 112,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[mood.heroStart, mood.heroEnd],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: List<Widget>.generate(3, (int index) {
                    return Expanded(
                      child: Container(
                        height: 118,
                        margin: EdgeInsets.only(right: index == 2 ? 0 : 10),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: mood.navBorder.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: 0.42,
                    minHeight: 5,
                    backgroundColor: scheme.outlineVariant.withValues(
                      alpha: 0.4,
                    ),
                    valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
