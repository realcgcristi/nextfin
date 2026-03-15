import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/storage/app_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/server_account.dart';
import '../../auth/application/session_controller.dart';
import '../../home/presentation/home_screen.dart' show activeAccountProvider;
import 'settings_screen.dart' show connectivityProvider;

class SettingsHubScreen extends ConsumerWidget {
  const SettingsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final acc = ref.watch(activeAccountProvider);
    final session = ref.watch(sessionControllerProvider);
    final mode = ref.watch(themeModeProvider);
    final sett = ref.watch(clientSettingsProvider);
    final net = ref.watch(connectivityProvider).valueOrNull ?? <ConnectivityResult>[];
    final ctrl = ref.read(clientSettingsProvider.notifier);

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: _SettingsLead(acc: acc, net: net),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 130),
              child: Column(
                children: <Widget>[
                  _Bucket(
                    title: 'look and feel',
                    child: Column(
                      children: <Widget>[
                        SegmentedButton<ThemeMode>(
                          segments: const <ButtonSegment<ThemeMode>>[
                            ButtonSegment(value: ThemeMode.system, label: Text('system')),
                            ButtonSegment(value: ThemeMode.dark, label: Text('dark')),
                            ButtonSegment(value: ThemeMode.light, label: Text('light')),
                          ],
                          selected: <ThemeMode>{mode},
                          onSelectionChanged: (Set<ThemeMode> value) {
                            ref.read(themeModeProvider.notifier).update(value.first);
                          },
                        ),
                        const SizedBox(height: 12),
                        _GoTile(
                          icon: Icons.palette_outlined,
                          title: 'themes',
                          body: paletteFor(sett.themePalette).name,
                          onTap: () => context.push('/themes'),
                        ),
                        const SizedBox(height: 12),
                        _GoTile(
                          icon: Icons.history_rounded,
                          title: 'watch history',
                          body: 'movies episodes and channels you opened lately',
                          onTap: () => context.push('/history'),
                        ),
                        const SizedBox(height: 12),
                        _GoTile(
                          icon: Icons.download_rounded,
                          title: 'downloads',
                          body: 'offline files and download progress',
                          onTap: () => context.push('/downloads'),
                        ),
                        const SizedBox(height: 12),
                        _DropTile<LayoutDensity>(
                          icon: Icons.density_medium_rounded,
                          title: 'density',
                          value: sett.layoutDensity,
                          items: LayoutDensity.values,
                          label: (v) => v == LayoutDensity.compact ? 'compact' : 'comfortable',
                          onChanged: (v) => ctrl.update(sett.copyWith(layoutDensity: v ?? sett.layoutDensity)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Bucket(
                    title: 'playback',
                    child: Column(
                      children: <Widget>[
                        _SwitchTile(
                          icon: Icons.restore_rounded,
                          title: 'resume playback',
                          body: 'use saved progress when it exists',
                          value: sett.resumePlayback,
                          onChanged: (v) => ctrl.update(sett.copyWith(resumePlayback: v)),
                        ),
                        const SizedBox(height: 12),
                        _SwitchTile(
                          icon: Icons.closed_caption_off_rounded,
                          title: 'auto subtitles',
                          body: 'turn them on when matching tracks exist',
                          value: sett.autoEnableSubtitles,
                          onChanged: (v) => ctrl.update(sett.copyWith(autoEnableSubtitles: v)),
                        ),
                        const SizedBox(height: 12),
                        _DropTile<String>(
                          icon: Icons.subtitles_rounded,
                          title: 'subtitle language',
                          value: sett.defaultSubtitleLanguage,
                          items: const <String>['System default', 'English', 'Spanish', 'French', 'Japanese'],
                          label: (v) => v,
                          onChanged: (v) => ctrl.update(sett.copyWith(defaultSubtitleLanguage: v ?? sett.defaultSubtitleLanguage)),
                        ),
                        const SizedBox(height: 12),
                        _DropTile<String>(
                          icon: Icons.graphic_eq_rounded,
                          title: 'audio language',
                          value: sett.preferredAudioLanguage,
                          items: const <String>['System default', 'English', 'Spanish', 'French', 'Japanese'],
                          label: (v) => v,
                          onChanged: (v) => ctrl.update(sett.copyWith(preferredAudioLanguage: v ?? sett.preferredAudioLanguage)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Bucket(
                    title: 'device behavior',
                    child: Column(
                      children: <Widget>[
                        _SliderTile(
                          title: 'seek jump',
                          icon: Icons.double_arrow_rounded,
                          value: sett.doubleTapSeekSeconds,
                          text: '${sett.doubleTapSeekSeconds.round()} seconds',
                          onChanged: (v) => ctrl.update(sett.copyWith(doubleTapSeekSeconds: v)),
                        ),
                        const SizedBox(height: 12),
                        _SwitchTile(
                          icon: Icons.picture_in_picture_alt_rounded,
                          title: 'auto enter pip',
                          body: 'drop into picture in picture when leaving playback',
                          value: sett.pipAutoEnter,
                          onChanged: (v) => ctrl.update(sett.copyWith(pipAutoEnter: v)),
                        ),
                        const SizedBox(height: 12),
                        _SwitchTile(
                          icon: Icons.headphones_rounded,
                          title: 'background playback',
                          body: 'keep video audio alive outside the player',
                          value: sett.backgroundPlayback,
                          onChanged: (v) => ctrl.update(sett.copyWith(backgroundPlayback: v)),
                        ),
                        const SizedBox(height: 12),
                        _DropTile<OrientationPreference>(
                          icon: Icons.screen_rotation_alt_rounded,
                          title: 'orientation',
                          value: sett.orientationPreference,
                          items: OrientationPreference.values,
                          label: (v) => switch (v) {
                            OrientationPreference.auto => 'auto',
                            OrientationPreference.portrait => 'portrait',
                            OrientationPreference.landscape => 'landscape',
                          },
                          onChanged: (v) => ctrl.update(sett.copyWith(orientationPreference: v ?? sett.orientationPreference)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Bucket(
                    title: 'account',
                    child: _AccountSection(session: session, active: acc),
                  ),
                  const SizedBox(height: 16),
                  _Bucket(
                    title: 'network and debug',
                    child: Column(
                      children: <Widget>[
                        _SwitchTile(
                          icon: Icons.http_rounded,
                          title: 'allow http servers',
                          body: 'plain http is useful for local jellyfin boxes',
                          value: sett.allowHttpServers,
                          onChanged: (v) => ctrl.update(sett.copyWith(allowHttpServers: v)),
                        ),
                        const SizedBox(height: 12),
                        _DropTile<StreamingQuality>(
                          icon: Icons.hd_rounded,
                          title: 'streaming quality',
                          value: sett.streamingQuality,
                          items: StreamingQuality.values,
                          label: (v) => v.name,
                          onChanged: (v) => ctrl.update(sett.copyWith(streamingQuality: v ?? sett.streamingQuality)),
                        ),
                        const SizedBox(height: 12),
                        _DropTile<PlaybackPreference>(
                          icon: Icons.tune_rounded,
                          title: 'playback mode',
                          value: sett.playbackPreference,
                          items: PlaybackPreference.values,
                          label: (v) => v.name,
                          onChanged: (v) => ctrl.update(sett.copyWith(playbackPreference: v ?? sett.playbackPreference)),
                        ),
                        const SizedBox(height: 12),
                        _SwitchTile(
                          icon: Icons.bug_report_outlined,
                          title: 'show playback debug',
                          body: 'surface internal playback details on errors',
                          value: sett.showDebugPlaybackInfo,
                          onChanged: (v) => ctrl.update(sett.copyWith(showDebugPlaybackInfo: v)),
                        ),
                        const SizedBox(height: 12),
                        _SwitchTile(
                          icon: Icons.terminal_rounded,
                          title: 'verbose logging',
                          body: 'extra player and api logs while debugging',
                          value: sett.verboseLogging,
                          onChanged: (v) => ctrl.update(sett.copyWith(verboseLogging: v)),
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
    );
  }
}

class _AccountSection extends ConsumerWidget {
  const _AccountSection({required this.session, required this.active});

  final SessionState session;
  final ServerAccount? active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.account_circle_rounded,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      active?.username ?? 'no account',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      active == null
                          ? 'sign in to add a jellyfin session'
                          : '${active!.serverName}  ·  ${active!.serverUrl}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _GoTile(
          icon: Icons.person_add_alt_1_rounded,
          title: 'add account',
          body: 'save another jellyfin session on this device',
          onTap: () => _showAddAccount(context, ref),
        ),
        const SizedBox(height: 12),
        if (session.accounts.length > 1)
          _GoTile(
            icon: Icons.swap_horiz_rounded,
            title: 'switch account',
            body: 'jump between saved sessions',
            onTap: () => _showAccountSwitcher(context, ref),
          ),
        if (session.accounts.length > 1) const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.logout_rounded),
          title: const Text('sign out'),
          subtitle: const Text('remove the current saved session from this device'),
          onTap: active == null
              ? null
              : () async {
                  await ref.read(sessionControllerProvider.notifier).logout();
                },
        ),
      ],
    );
  }

  Future<void> _showAccountSwitcher(BuildContext context, WidgetRef ref) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
            children: <Widget>[
              const ListTile(title: Text('saved sessions')),
              ...session.accounts.map(
                (acc) => ListTile(
                  leading: Icon(
                    acc.id == active?.id
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                  ),
                  title: Text(acc.username),
                  subtitle: Text(
                    '${acc.serverName}  ·  ${acc.serverUrl}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: acc.id == active?.id
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () => Navigator.of(context).pop(acc.id),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (picked == null || picked == active?.id) return;
    await ref.read(sessionControllerProvider.notifier).switchAccount(picked);
  }

  Future<void> _showAddAccount(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) => const _AddAccountSheet(),
    );
  }
}

class _AddAccountSheet extends ConsumerStatefulWidget {
  const _AddAccountSheet();

  @override
  ConsumerState<_AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends ConsumerState<_AddAccountSheet> {
  final _serverCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _serverCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final server = _serverCtrl.text.trim();
    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text;
    if (_busy) return;
    if (server.isEmpty || user.isEmpty || pass.isEmpty) {
      setState(() => _err = 'fill in server username and password');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await ref.read(sessionControllerProvider.notifier).login(
        serverUrl: server,
        username: user,
        password: pass,
      );
      if (mounted) Navigator.of(context).pop();
    } on AppException catch (e) {
      if (mounted) setState(() => _err = e.message);
    } catch (e) {
      if (mounted) {
        setState(() => _err = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + inset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'add account',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _serverCtrl,
              decoration: const InputDecoration(
                labelText: 'server',
                prefixIcon: Icon(Icons.dns_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _userCtrl,
              decoration: const InputDecoration(
                labelText: 'username',
                prefixIcon: Icon(Icons.person_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passCtrl,
              obscureText: true,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'password',
                prefixIcon: Icon(Icons.lock_rounded),
              ),
            ),
            if (_err != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _err!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_rounded),
                label: Text(_busy ? 'adding account' : 'add account'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsLead extends StatelessWidget {
  const _SettingsLead({required this.acc, required this.net});

  final ServerAccount? acc;
  final List<ConnectivityResult> net;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'settings',
          style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      acc?.serverName ?? 'no server',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      acc == null ? 'signed out' : '${acc!.username}  ·  ${net.map((e) => e.name).join(', ')}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: () => context.go('/home'),
                child: const Text('done'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Bucket extends StatelessWidget {
  const _Bucket({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _GoTile extends StatelessWidget {
  const _GoTile({required this.icon, required this.title, required this.body, required this.onTap});
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(body),
    trailing: const Icon(Icons.arrow_forward_rounded),
  );
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({required this.icon, required this.title, required this.body, required this.value, required this.onChanged});
  final IconData icon;
  final String title;
  final String body;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
    value: value,
    onChanged: onChanged,
    secondary: Icon(icon),
    title: Text(title),
    subtitle: Text(body),
    contentPadding: EdgeInsets.zero,
  );
}

class _DropTile<T> extends StatelessWidget {
  const _DropTile({required this.icon, required this.title, required this.value, required this.items, required this.label, required this.onChanged});
  final IconData icon;
  final String title;
  final T value;
  final List<T> items;
  final String Function(T) label;
  final ValueChanged<T?> onChanged;
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    value: value,
    items: items.map((item) => DropdownMenuItem<T>(value: item, child: Text(label(item)))).toList(),
    onChanged: onChanged,
    decoration: InputDecoration(
      labelText: title,
      prefixIcon: Icon(icon),
    ),
  );
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({required this.title, required this.icon, required this.value, required this.text, required this.onChanged});
  final String title;
  final IconData icon;
  final double value;
  final String text;
  final ValueChanged<double> onChanged;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon),
              const SizedBox(width: 10),
              Expanded(child: Text(title)),
              Text(text),
            ],
          ),
          Slider(
            value: value,
            min: 5,
            max: 30,
            divisions: 5,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
