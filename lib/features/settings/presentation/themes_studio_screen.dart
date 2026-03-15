import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';

class ThemesStudioScreen extends ConsumerWidget {
  const ThemesStudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sett = ref.watch(clientSettingsProvider);
    final ctrl = ref.read(clientSettingsProvider.notifier);
    final mode = ref.watch(themeModeProvider);
    final brightness = switch (mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => MediaQuery.platformBrightnessOf(context),
    };
    final palette = paletteFor(sett.themePalette);
    final preview = buildNextfinTheme(
      brightness,
      palette: sett.themePalette,
      density: sett.layoutDensity,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('themes')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: <Widget>[
          _StudioPreview(theme: preview, name: palette.name),
          const SizedBox(height: 24),
          Text(
            'palette lab',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          ...themePalettes.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PaletteCard(
                item: item,
                selected: item.id == sett.themePalette,
                onTap: () => ctrl.update(sett.copyWith(themePalette: item.id)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioPreview extends StatelessWidget {
  const _StudioPreview({required this.theme, required this.name});

  final ThemeData theme;
  final String name;

  @override
  Widget build(BuildContext context) {
    final mood = theme.extension<ThemeMood>()!;
    return Container(
      height: 320,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[mood.previewTop, mood.previewBottom],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            name,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Row(
              children: <Widget>[
                Expanded(
                  flex: 6,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('nextfin', style: theme.textTheme.labelLarge),
                        const SizedBox(height: 8),
                        Text(
                          'movie night',
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          height: 72,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 4,
                  child: Column(
                    children: <Widget>[
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                      ),
                    ],
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

class _PaletteCard extends StatelessWidget {
  const _PaletteCard({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final ThemePaletteDefinition item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.64)
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: <Widget>[
            Row(
              children: <Widget>[
                _Dot(color: item.lightSeed),
                const SizedBox(width: 8),
                _Dot(color: item.darkSeed),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (selected) const Icon(Icons.check_circle_rounded),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}
