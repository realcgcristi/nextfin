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
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              mood.appBackgroundTop,
              Color.alphaBlend(
                mood.appGlow.withValues(alpha: 0.16),
                mood.appBackgroundBottom,
              ),
            ],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Row(
                        children: <Widget>[
                          IconButton.filledTonal(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Themes',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        height: 0.95,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  paletteFor(sett.themePalette).name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 130),
                    child: Column(
                      children: <Widget>[
                        _ThemeLabPreview(
                          palette: sett.themePalette,
                          mode: mode,
                        ),
                        const SizedBox(height: 20),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: themePalettes.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 1.45,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                          itemBuilder: (BuildContext context, int idx) {
                            final item = themePalettes[idx];
                            final selected = item.id == sett.themePalette;
                            final activeMood =
                                mode == ThemeMode.light
                                    ? item.lightMood
                                    : item.darkMood;
                            return InkWell(
                              onTap:
                                  () => ctrl.update(
                                    sett.copyWith(themePalette: item.id),
                                  ),
                              borderRadius: BorderRadius.circular(30),
                              child: Ink(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(30),
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
                                            ? Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                            : activeMood.navBorder.withValues(
                                              alpha: 0.66,
                                            ),
                                    width: selected ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Row(
                                      children: <Widget>[
                                        ...<Color>[
                                          item.lightSeed,
                                          item.darkSeed,
                                          activeMood.navSurface,
                                        ].map(
                                          (Color color) => Container(
                                            width: 16,
                                            height: 16,
                                            margin: const EdgeInsets.only(right: 6),
                                            decoration: BoxDecoration(
                                              color: color,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        if (selected)
                                          Icon(
                                            Icons.check_circle_rounded,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                      ],
                                    ),
                                    const Spacer(),
                                    Text(
                                      item.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeLabPreview extends StatelessWidget {
  const _ThemeLabPreview({required this.palette, required this.mode});

  final AppThemePalette palette;
  final ThemeMode mode;

  @override
  Widget build(BuildContext context) {
    final brightness =
        mode == ThemeMode.light ? Brightness.light : Brightness.dark;
    final def = paletteFor(palette);
    final mood = brightness == Brightness.light ? def.lightMood : def.darkMood;
    final previewTheme = buildNextfinTheme(
      brightness,
      palette: palette,
      density: LayoutDensity.comfortable,
    );
    final scheme = previewTheme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(38),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[mood.previewTop, mood.previewBottom],
        ),
        border: Border.all(color: mood.navBorder.withValues(alpha: 0.74)),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  def.name,
                  style: previewTheme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: mood.navSurface,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text('preview'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Column(
              children: <Widget>[
                Container(
                  height: 70,
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
                  children: List<Widget>.generate(3, (int idx) {
                    return Expanded(
                      child: Container(
                        height: 120,
                        margin: EdgeInsets.only(right: idx == 2 ? 0 : 10),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: 0.44,
                    minHeight: 6,
                    backgroundColor:
                        scheme.outlineVariant.withValues(alpha: 0.34),
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
