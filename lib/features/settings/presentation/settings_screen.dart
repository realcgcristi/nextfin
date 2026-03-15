import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/app_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/server_account.dart';
import '../../auth/application/session_controller.dart';
import '../../home/presentation/home_screen.dart';

final connectivityProvider = FutureProvider<List<ConnectivityResult>>((
  Ref ref,
) async {
  return Connectivity().checkConnectivity();
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(activeAccountProvider);
    final mode = ref.watch(themeModeProvider);
    final sett = ref.watch(clientSettingsProvider);
    final net =
        ref.watch(connectivityProvider).valueOrNull ?? <ConnectivityResult>[];
    final ctrl = ref.read(clientSettingsProvider.notifier);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: _SettingsTop(account: account),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 130),
                  child: Column(
                    children: <Widget>[
                      _SetCard(
                        title: 'Appearance',
                        note: 'theme, tone, and density',
                        child: Column(
                          children: <Widget>[
                            _SegMode(mode: mode),
                            const SizedBox(height: 14),
                            _GoRow(
                              icon: Icons.palette_outlined,
                              title: 'Themes',
                              body: paletteFor(sett.themePalette).name,
                              onTap: () => context.push('/themes'),
                            ),
                            const SizedBox(height: 12),
                            _DropRow<LayoutDensity>(
                              icon: Icons.density_medium_rounded,
                              title: 'Density',
                              body: 'compact or comfortable spacing',
                              value: sett.layoutDensity,
                              items: LayoutDensity.values,
                              label:
                                  (LayoutDensity item) => switch (item) {
                                    LayoutDensity.compact => 'Compact',
                                    LayoutDensity.comfortable => 'Comfortable',
                                  },
                              onChanged:
                                  (LayoutDensity? value) => ctrl.update(
                                    sett.copyWith(
                                      layoutDensity:
                                          value ?? sett.layoutDensity,
                                    ),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SetCard(
                        title: 'Playback',
                        note: 'language, resume, subtitles',
                        child: Column(
                          children: <Widget>[
                            _DropRow<String>(
                              icon: Icons.subtitles_outlined,
                              title: 'Subtitle language',
                              body: 'used when tracks are available',
                              value: sett.defaultSubtitleLanguage,
                              items: const <String>[
                                'System default',
                                'English',
                                'Spanish',
                                'French',
                                'Japanese',
                              ],
                              label: (String value) => value,
                              onChanged:
                                  (String? value) => ctrl.update(
                                    sett.copyWith(
                                      defaultSubtitleLanguage:
                                          value ?? sett.defaultSubtitleLanguage,
                                    ),
                                  ),
                            ),
                            const SizedBox(height: 12),
                            _SwitchRow(
                              icon: Icons.closed_caption_disabled_outlined,
                              title: 'Auto-enable subtitles',
                              body: 'turn them on when tracks exist',
                              value: sett.autoEnableSubtitles,
                              onChanged:
                                  (bool value) => ctrl.update(
                                    sett.copyWith(autoEnableSubtitles: value),
                                  ),
                            ),
                            const SizedBox(height: 12),
                            _DropRow<String>(
                              icon: Icons.graphic_eq_rounded,
                              title: 'Audio language',
                              body: 'pick your preferred track first',
                              value: sett.preferredAudioLanguage,
                              items: const <String>[
                                'System default',
                                'English',
                                'Spanish',
                                'French',
                                'Japanese',
                              ],
                              label: (String value) => value,
                              onChanged:
                                  (String? value) => ctrl.update(
                                    sett.copyWith(
                                      preferredAudioLanguage:
                                          value ?? sett.preferredAudioLanguage,
                                    ),
                                  ),
                            ),
                            const SizedBox(height: 12),
                            _SwitchRow(
                              icon: Icons.restore_rounded,
                              title: 'Resume playback',
                              body: 'offer resume when jellyfin reports progress',
                              value: sett.resumePlayback,
                              onChanged:
                                  (bool value) => ctrl.update(
                                    sett.copyWith(resumePlayback: value),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SetCard(
                        title: 'Player',
                        note: 'pip, orientation, seek behavior',
                        child: Column(
                          children: <Widget>[
                            _SliderRow(
                              icon: Icons.double_arrow_rounded,
                              title: 'Seek duration',
                              body: '${sett.doubleTapSeekSeconds.round()} seconds',
                              value: sett.doubleTapSeekSeconds,
                              min: 5,
                              max: 30,
                              divisions: 5,
                              onChanged:
                                  (double value) => ctrl.update(
                                    sett.copyWith(
                                      doubleTapSeekSeconds: value,
                                    ),
                                  ),
                            ),
                            const SizedBox(height: 12),
                            _SwitchRow(
                              icon: Icons.headphones_rounded,
                              title: 'Background playback',
                              body: 'keep playing when the app is not visible',
                              value: sett.backgroundPlayback,
                              onChanged:
                                  (bool value) => ctrl.update(
                                    sett.copyWith(backgroundPlayback: value),
                                  ),
                            ),
                            const SizedBox(height: 12),
                            _SwitchRow(
                              icon: Icons.picture_in_picture_alt_rounded,
                              title: 'PiP auto-enter',
                              body: 'enter picture in picture when leaving',
                              value: sett.pipAutoEnter,
                              onChanged:
                                  (bool value) => ctrl.update(
                                    sett.copyWith(pipAutoEnter: value),
                                  ),
                            ),
                            const SizedBox(height: 12),
                            _DropRow<OrientationPreference>(
                              icon: Icons.screen_rotation_alt_rounded,
                              title: 'Orientation',
                              body: 'choose the default player posture',
                              value: sett.orientationPreference,
                              items: OrientationPreference.values,
                              label:
                                  (OrientationPreference item) => switch (item) {
                                    OrientationPreference.auto => 'Automatic',
                                    OrientationPreference.portrait => 'Portrait first',
                                    OrientationPreference.landscape => 'Landscape first',
                                  },
                              onChanged:
                                  (OrientationPreference? value) => ctrl.update(
                                    sett.copyWith(
                                      orientationPreference:
                                          value ?? sett.orientationPreference,
                                    ),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SetCard(
                        title: 'Network',
                        note: 'server access and stream strategy',
                        child: Column(
                          children: <Widget>[
                            _SwitchRow(
                              icon: Icons.http_rounded,
                              title: 'Allow HTTP servers',
                              body: 'permit local non-https jellyfin servers',
                              value: sett.allowHttpServers,
                              onChanged:
                                  (bool value) => ctrl.update(
                                    sett.copyWith(allowHttpServers: value),
                                  ),
                            ),
                            const SizedBox(height: 12),
                            _DropRow<StreamingQuality>(
                              icon: Icons.network_wifi_rounded,
                              title: 'Streaming quality',
                              body: 'balance quality and bandwidth',
                              value: sett.streamingQuality,
                              items: StreamingQuality.values,
                              label:
                                  (StreamingQuality item) => switch (item) {
                                    StreamingQuality.auto => 'Auto',
                                    StreamingQuality.dataSaver => 'Data saver',
                                    StreamingQuality.balanced => 'Balanced',
                                    StreamingQuality.max => 'Maximum quality',
                                  },
                              onChanged:
                                  (StreamingQuality? value) => ctrl.update(
                                    sett.copyWith(
                                      streamingQuality:
                                          value ?? sett.streamingQuality,
                                    ),
                                  ),
                            ),
                            const SizedBox(height: 12),
                            _DropRow<PlaybackPreference>(
                              icon: Icons.video_settings_rounded,
                              title: 'Playback mode',
                              body: 'prefer direct play or transcoding',
                              value: sett.playbackPreference,
                              items: PlaybackPreference.values,
                              label:
                                  (PlaybackPreference item) => switch (item) {
                                    PlaybackPreference.auto => 'Automatic',
                                    PlaybackPreference.directPlay =>
                                      'Prefer direct play',
                                    PlaybackPreference.transcode =>
                                      'Prefer transcode',
                                  },
                              onChanged:
                                  (PlaybackPreference? value) => ctrl.update(
                                    sett.copyWith(
                                      playbackPreference:
                                          value ?? sett.playbackPreference,
                                    ),
                                  ),
                            ),
                            const SizedBox(height: 12),
                            _InfoRow(
                              icon: Icons.wifi_tethering_rounded,
                              title: 'Current connectivity',
                              body: net.map((ConnectivityResult item) => item.name).join(', '),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SetCard(
                        title: 'Account',
                        note: 'current server and session',
                        child: Column(
                          children: <Widget>[
                            _InfoRow(
                              icon: Icons.cloud_done_rounded,
                              title: account?.serverName ?? 'No connected server',
                              body:
                                  account == null
                                      ? 'connect a jellyfin server to start'
                                      : '${account.username} • ${account.serverUrl}',
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed:
                                    () => ref
                                        .read(sessionControllerProvider.notifier)
                                        .logout(),
                                icon: const Icon(Icons.logout_rounded),
                                label: const Text('Sign out'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SetCard(
                        title: 'Developer',
                        note: 'diagnostics and logging',
                        child: Column(
                          children: <Widget>[
                            _SwitchRow(
                              icon: Icons.bug_report_outlined,
                              title: 'Show debug playback info',
                              body: 'surface playback diagnostics in player',
                              value: sett.showDebugPlaybackInfo,
                              onChanged:
                                  (bool value) => ctrl.update(
                                    sett.copyWith(showDebugPlaybackInfo: value),
                                  ),
                            ),
                            const SizedBox(height: 12),
                            _SwitchRow(
                              icon: Icons.terminal_rounded,
                              title: 'Verbose logging',
                              body: 'print extra debug output',
                              value: sett.verboseLogging,
                              onChanged:
                                  (bool value) => ctrl.update(
                                    sett.copyWith(verboseLogging: value),
                                  ),
                            ),
                            const SizedBox(height: 12),
                            _InfoRow(
                              icon: Icons.rule_folder_outlined,
                              title: 'Compatibility notes',
                              body:
                                  (account?.capabilities.notes ??
                                          <String>['No diagnostics'])
                                      .join('\n'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SetCard(
                        title: 'About',
                        note: 'build details and credits',
                        child: Column(
                          children: <Widget>[
                            const _InfoRow(
                              icon: Icons.apps_rounded,
                              title: 'Nextfin',
                              body: 'a jellyfin client made with love, v1.0.1',
                            ),
                            const SizedBox(height: 12),
                            _InfoRow(
                              icon: Icons.verified_rounded,
                              title: 'Server version',
                              body: account?.capabilities.version ?? 'unknown',
                            ),
                            const SizedBox(height: 12),
                            const _InfoRow(
                              icon: Icons.favorite_outline_rounded,
                              title: 'Credits',
                              body: 'made with love by av',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTop extends StatelessWidget {
  const _SettingsTop({required this.account});

  final ServerAccount? account;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mood = themeMoodOf(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(38),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[mood.heroStart, mood.heroEnd],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Settings',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              height: 0.95,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            account == null
                ? 'configure the app before connecting'
                : 'signed in as ${account?.username} on ${account?.serverName}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SetCard extends StatelessWidget {
  const _SetCard({
    required this.title,
    required this.note,
    required this.child,
  });

  final String title;
  final String note;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.34),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            note,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _SegMode extends ConsumerWidget {
  const _SegMode({required this.mode});

  final ThemeMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SegmentedButton<ThemeMode>(
      segments: const <ButtonSegment<ThemeMode>>[
        ButtonSegment<ThemeMode>(
          value: ThemeMode.system,
          icon: Icon(Icons.brightness_auto_rounded),
          label: Text('System'),
        ),
        ButtonSegment<ThemeMode>(
          value: ThemeMode.dark,
          icon: Icon(Icons.dark_mode_rounded),
          label: Text('Dark'),
        ),
        ButtonSegment<ThemeMode>(
          value: ThemeMode.light,
          icon: Icon(Icons.light_mode_rounded),
          label: Text('Light'),
        ),
      ],
      selected: <ThemeMode>{mode},
      onSelectionChanged:
          (Set<ThemeMode> value) =>
              ref.read(themeModeProvider.notifier).update(value.first),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.body,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(body),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}

class _GoRow extends StatelessWidget {
  const _GoRow({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(body),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

class _DropRow<T> extends StatelessWidget {
  const _DropRow({
    required this.icon,
    required this.title,
    required this.body,
    required this.value,
    required this.items,
    required this.label,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String body;
  final T value;
  final List<T> items;
  final String Function(T) label;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(body),
        ),
        DropdownButtonFormField<T>(
          value: value,
          items:
              items
                  .map(
                    (T item) => DropdownMenuItem<T>(
                      value: item,
                      child: Text(label(item)),
                    ),
                  )
                  .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.icon,
    required this.title,
    required this.body,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String body;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(body),
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: '${value.round()}s',
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(body),
    );
  }
}
