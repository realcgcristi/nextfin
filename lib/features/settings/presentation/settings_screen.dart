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
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        children: <Widget>[
          _SettingsHero(account: account),
          const SizedBox(height: 18),
          _SettingsCategoryCard(
            icon: Icons.palette_outlined,
            title: 'Appearance',
            description: 'Themes, layout density, and visual styling.',
            child: Column(
              children: <Widget>[
                _SegmentedThemePicker(themeMode: mode),
                const SizedBox(height: 12),
                _NavigationRow(
                  icon: Icons.palette_outlined,
                  title: 'Themes',
                  description: paletteFor(sett.themePalette).name,
                  onTap: () => context.push('/themes'),
                ),
                const SizedBox(height: 14),
                _SwitchRow(
                  icon: Icons.color_lens_outlined,
                  title: 'Dynamic color',
                  description:
                      'Use Material You style accent behavior where available.',
                  value: sett.dynamicColor,
                  onChanged:
                      (bool value) => ctrl.update(
                        sett.copyWith(dynamicColor: value),
                      ),
                ),
                const SizedBox(height: 12),
                _DropdownRow<LayoutDensity>(
                  icon: Icons.density_medium_rounded,
                  title: 'Layout density',
                  description:
                      'Choose between compact and comfortable spacing.',
                  value: sett.layoutDensity,
                  items: LayoutDensity.values,
                  labelBuilder:
                      (LayoutDensity item) => switch (item) {
                        LayoutDensity.compact => 'Compact',
                        LayoutDensity.comfortable => 'Comfortable',
                      },
                  onChanged:
                      (LayoutDensity? value) => ctrl.update(
                        sett.copyWith(
                          layoutDensity: value ?? sett.layoutDensity,
                        ),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SettingsCategoryCard(
            icon: Icons.play_circle_outline_rounded,
            title: 'Playback',
            description:
                'Subtitles, language preferences, and resume behavior.',
            child: Column(
              children: <Widget>[
                _DropdownRow<String>(
                  icon: Icons.subtitles_outlined,
                  title: 'Default subtitle language',
                  description: 'Applied when subtitle tracks are available.',
                  value: sett.defaultSubtitleLanguage,
                  items: const <String>[
                    'System default',
                    'English',
                    'Spanish',
                    'French',
                    'Japanese',
                  ],
                  labelBuilder: (String value) => value,
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
                  description:
                      'Turn subtitles on automatically when tracks exist.',
                  value: sett.autoEnableSubtitles,
                  onChanged:
                      (bool value) => ctrl.update(
                        sett.copyWith(autoEnableSubtitles: value),
                      ),
                ),
                const SizedBox(height: 12),
                _DropdownRow<String>(
                  icon: Icons.graphic_eq_rounded,
                  title: 'Preferred audio language',
                  description:
                      'Used when the server offers multiple audio tracks.',
                  value: sett.preferredAudioLanguage,
                  items: const <String>[
                    'System default',
                    'English',
                    'Spanish',
                    'French',
                    'Japanese',
                  ],
                  labelBuilder: (String value) => value,
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
                  description:
                      'Offer resume when Jellyfin reports partial progress.',
                  value: sett.resumePlayback,
                  onChanged:
                      (bool value) => ctrl.update(
                        sett.copyWith(resumePlayback: value),
                      ),
                ),
                const SizedBox(height: 12),
                _SwitchRow(
                  icon: Icons.skip_next_rounded,
                  title: 'Show skip intro button',
                  description:
                      'Expose skip intro when metadata is available later.',
                  value: sett.skipIntroButton,
                  onChanged:
                      (bool value) => ctrl.update(
                        sett.copyWith(skipIntroButton: value),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SettingsCategoryCard(
            icon: Icons.smart_display_outlined,
            title: 'Player Behavior',
            description: 'PiP, orientation, gestures, and fullscreen handling.',
            child: Column(
              children: <Widget>[
                _SliderRow(
                  icon: Icons.double_arrow_rounded,
                  title: 'Double tap seek duration',
                  description:
                      '${sett.doubleTapSeekSeconds.round()} seconds',
                  value: sett.doubleTapSeekSeconds,
                  min: 5,
                  max: 30,
                  divisions: 5,
                  onChanged:
                      (double value) => ctrl.update(
                        sett.copyWith(doubleTapSeekSeconds: value),
                      ),
                ),
                const SizedBox(height: 12),
                _SwitchRow(
                  icon: Icons.speed_rounded,
                  title: 'Remember playback speed',
                  description:
                      'Keep the last playback speed for future sessions.',
                  value: sett.rememberPlaybackSpeed,
                  onChanged:
                      (bool value) => ctrl.update(
                        sett.copyWith(rememberPlaybackSpeed: value),
                      ),
                ),
                const SizedBox(height: 12),
                _SwitchRow(
                  icon: Icons.headphones_rounded,
                  title: 'Background playback',
                  description:
                      'Allow playback to continue when the app is not visible.',
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
                  description:
                      'Enter Picture-in-Picture when leaving the app during playback.',
                  value: sett.pipAutoEnter,
                  onChanged:
                      (bool value) => ctrl.update(
                        sett.copyWith(pipAutoEnter: value),
                      ),
                ),
                const SizedBox(height: 12),
                _DropdownRow<OrientationPreference>(
                  icon: Icons.screen_rotation_alt_rounded,
                  title: 'Orientation preference',
                  description:
                      'Choose how the player should favor portrait or landscape.',
                  value: sett.orientationPreference,
                  items: OrientationPreference.values,
                  labelBuilder:
                      (OrientationPreference item) => switch (item) {
                        OrientationPreference.auto => 'Automatic',
                        OrientationPreference.portrait => 'Portrait first',
                        OrientationPreference.landscape => 'Landscape first',
                      },
                  onChanged:
                      (OrientationPreference? value) =>
                          ctrl.update(
                            sett.copyWith(
                              orientationPreference:
                                  value ?? sett.orientationPreference,
                            ),
                          ),
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.fullscreen_rounded,
                  title: 'Fullscreen behavior',
                  description:
                      'Use the in-player fullscreen control for immersive playback.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SettingsCategoryCard(
            icon: Icons.cloud_outlined,
            title: 'Connectivity',
            description: 'Server access, HTTP allowance, and stream strategy.',
            child: Column(
              children: <Widget>[
                _SwitchRow(
                  icon: Icons.http_rounded,
                  title: 'Allow HTTP servers',
                  description:
                      'Permit connections to local Jellyfin instances over HTTP.',
                  value: sett.allowHttpServers,
                  onChanged:
                      (bool value) => ctrl.update(
                        sett.copyWith(allowHttpServers: value),
                      ),
                ),
                const SizedBox(height: 12),
                _DropdownRow<StreamingQuality>(
                  icon: Icons.network_wifi_rounded,
                  title: 'Streaming quality',
                  description:
                      'Set your preferred balance between quality and data usage.',
                  value: sett.streamingQuality,
                  items: StreamingQuality.values,
                  labelBuilder:
                      (StreamingQuality item) => switch (item) {
                        StreamingQuality.auto => 'Auto',
                        StreamingQuality.dataSaver => 'Data saver',
                        StreamingQuality.balanced => 'Balanced',
                        StreamingQuality.max => 'Maximum quality',
                      },
                  onChanged:
                      (StreamingQuality? value) => ctrl.update(
                        sett.copyWith(
                          streamingQuality: value ?? sett.streamingQuality,
                        ),
                      ),
                ),
                const SizedBox(height: 12),
                _DropdownRow<PlaybackPreference>(
                  icon: Icons.video_settings_rounded,
                  title: 'Playback mode',
                  description:
                      'Prefer direct play, transcoding, or let the app decide.',
                  value: sett.playbackPreference,
                  items: PlaybackPreference.values,
                  labelBuilder:
                      (PlaybackPreference item) => switch (item) {
                        PlaybackPreference.auto => 'Automatic',
                        PlaybackPreference.directPlay => 'Prefer direct play',
                        PlaybackPreference.transcode => 'Prefer transcode',
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
                  description: net
                      .map((ConnectivityResult item) => item.name)
                      .join(', '),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SettingsCategoryCard(
            icon: Icons.manage_accounts_outlined,
            title: 'Accounts',
            description: 'Manage your connected Jellyfin sessions.',
            child: Column(
              children: <Widget>[
                _InfoRow(
                  icon: Icons.cloud_done_rounded,
                  title: account?.serverName ?? 'No connected server',
                  description:
                      account == null
                          ? 'Connect a Jellyfin server to start streaming.'
                          : '${account.username} • ${account.serverUrl}',
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed:
                        () =>
                            ref
                                .read(sessionControllerProvider.notifier)
                                .logout(),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Sign out of current session'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SettingsCategoryCard(
            icon: Icons.developer_mode_outlined,
            title: 'Developer Options',
            description:
                'Diagnostics, playback traces, and compatibility detail.',
            child: Column(
              children: <Widget>[
                _SwitchRow(
                  icon: Icons.bug_report_outlined,
                  title: 'Show debug playback info',
                  description: 'Surface playback diagnostics in the player UI.',
                  value: sett.showDebugPlaybackInfo,
                  onChanged:
                      (bool value) => ctrl.update(
                        sett.copyWith(showDebugPlaybackInfo: value),
                      ),
                ),
                const SizedBox(height: 12),
                _SwitchRow(
                  icon: Icons.data_object_rounded,
                  title: 'Show Jellyfin API responses',
                  description:
                      'Keep verbose request-response details available for debugging.',
                  value: sett.showApiResponses,
                  onChanged:
                      (bool value) => ctrl.update(
                        sett.copyWith(showApiResponses: value),
                      ),
                ),
                const SizedBox(height: 12),
                _SwitchRow(
                  icon: Icons.terminal_rounded,
                  title: 'Verbose logging',
                  description:
                      'Enable additional debug output during development.',
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
                  description: (account?.capabilities.notes ??
                          <String>['No diagnostics'])
                      .join('\n'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SettingsCategoryCard(
            icon: Icons.info_outline_rounded,
            title: 'About',
            description: 'Build details and credits.',
            child: Column(
              children: <Widget>[
                _InfoRow(
                  icon: Icons.apps_rounded,
                  title: 'Nextfin',
                  description: 'a jellyfin client made with love, v1.0.1',
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.verified_rounded,
                  title: 'Server version',
                  description: account?.capabilities.version ?? 'unknown',
                ),
                const SizedBox(height: 12),
                const _InfoRow(
                  icon: Icons.favorite_outline_rounded,
                  title: 'Credits',
                  description: 'made with love by av',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsHero extends StatelessWidget {
  const _SettingsHero({required this.account});

  final ServerAccount? account;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mood = themeMoodOf(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[mood.heroStart, mood.heroEnd],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: mood.appGlow.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.74),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.tune_rounded, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Nextfin settings',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  account == null
                      ? 'Configure the app before connecting to Jellyfin.'
                      : 'Signed in as ${account?.username ?? 'Guest'} on ${account?.serverName ?? 'your server'}.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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

class _SettingsCategoryCard extends StatelessWidget {
  const _SettingsCategoryCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _SegmentedThemePicker extends ConsumerWidget {
  const _SegmentedThemePicker({required this.themeMode});

  final ThemeMode themeMode;

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
      selected: <ThemeMode>{themeMode},
      onSelectionChanged:
          (Set<ThemeMode> selection) =>
              ref.read(themeModeProvider.notifier).update(selection.first),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title),
      subtitle: Text(description),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}

class _NavigationRow extends StatelessWidget {
  const _NavigationRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title),
      subtitle: Text(description),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

class _DropdownRow<T> extends StatelessWidget {
  const _DropdownRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.items,
    required this.labelBuilder,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String description;
  final T value;
  final List<T> items;
  final String Function(T) labelBuilder;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: theme.colorScheme.primary),
          title: Text(title),
          subtitle: Text(description),
        ),
        DropdownButtonFormField<T>(
          value: value,
          items:
              items
                  .map(
                    (T item) => DropdownMenuItem<T>(
                      value: item,
                      child: Text(labelBuilder(item)),
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
    required this.description,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String description;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: theme.colorScheme.primary),
          title: Text(title),
          subtitle: Text(description),
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
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title),
      subtitle: Text(description),
    );
  }
}
