import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../application/session_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
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
    if (!_formKey.currentState!.validate()) return;
    final sett = ref.read(clientSettingsProvider);
    final raw = _serverCtrl.text.trim();
    if (!sett.allowHttpServers && raw.startsWith('http://')) {
      setState(() => _err = 'http servers are disabled in settings');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .login(
            serverUrl: _serverCtrl.text,
            username: _userCtrl.text,
            password: _passCtrl.text,
          );
    } on AppException catch (e) {
      setState(() => _err = e.message);
    } catch (e) {
      setState(() => _err = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mood = themeMoodOf(context);

    return Scaffold(
      body: Stack(
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[mood.appBackgroundTop, mood.appBackgroundBottom],
              ),
            ),
            child: const SizedBox.expand(),
          ),
          Positioned(
            top: -120,
            left: -50,
            child: IgnorePointer(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: mood.appGlow.withValues(alpha: 0.34),
                ),
              ),
            ),
          ),
          Positioned(
            right: -80,
            bottom: -30,
            child: IgnorePointer(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary.withValues(alpha: 0.14),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints c) {
                    final wide = c.maxWidth >= 920;
                    return ListView(
                      padding: EdgeInsets.fromLTRB(
                        wide ? 28 : 20,
                        18,
                        wide ? 28 : 20,
                        28,
                      ),
                      children: <Widget>[
                        wide
                            ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Expanded(
                                  flex: 6,
                                  child: _HeroPanel(
                                    hasSaved: session.accounts.isNotEmpty,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  flex: 5,
                                  child: Column(
                                    children: <Widget>[
                                      _FormPanel(
                                        formKey: _formKey,
                                        serverCtrl: _serverCtrl,
                                        userCtrl: _userCtrl,
                                        passCtrl: _passCtrl,
                                        busy: _busy,
                                        err: _err,
                                        onSubmit: _submit,
                                      ),
                                      if (session.accounts.isNotEmpty) ...<Widget>[
                                        const SizedBox(height: 18),
                                        _SavedPanel(
                                          session: session,
                                          onUse:
                                              (String id) => ref
                                                  .read(
                                                    sessionControllerProvider
                                                        .notifier,
                                                  )
                                                  .switchAccount(id),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            )
                            : Column(
                              children: <Widget>[
                                const _HeroPanel(hasSaved: false),
                                const SizedBox(height: 16),
                                _FormPanel(
                                  formKey: _formKey,
                                  serverCtrl: _serverCtrl,
                                  userCtrl: _userCtrl,
                                  passCtrl: _passCtrl,
                                  busy: _busy,
                                  err: _err,
                                  onSubmit: _submit,
                                ),
                                if (session.accounts.isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 16),
                                  _SavedPanel(
                                    session: session,
                                    onUse:
                                        (String id) => ref
                                            .read(
                                              sessionControllerProvider.notifier,
                                            )
                                            .switchAccount(id),
                                  ),
                                ],
                              ],
                            ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.hasSaved});

  final bool hasSaved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mood = themeMoodOf(context);
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            mood.heroStart.withValues(alpha: 0.96),
            mood.heroEnd.withValues(alpha: 0.94),
          ],
        ),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  size: 36,
                  color: scheme.primary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  hasSaved ? 'pick a session or sign in' : 'connect to jellyfin',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 34),
          Text(
            'welcome to nextfin',
            style: theme.textTheme.labelLarge?.copyWith(
              letterSpacing: 1.2,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'your server\nin a better shell',
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w900,
              height: 0.92,
              letterSpacing: -1.4,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'sign in once then keep movies shows and progress in one clean place',
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const <Widget>[
              _MiniLine(icon: Icons.play_arrow_rounded, text: 'resume playback'),
              _MiniLine(icon: Icons.search_rounded, text: 'search everything'),
              _MiniLine(icon: Icons.palette_outlined, text: 'theme it your way'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniLine extends StatelessWidget {
  const _MiniLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.44),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(
            text,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FormPanel extends StatelessWidget {
  const _FormPanel({
    required this.formKey,
    required this.serverCtrl,
    required this.userCtrl,
    required this.passCtrl,
    required this.busy,
    required this.err,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController serverCtrl;
  final TextEditingController userCtrl;
  final TextEditingController passCtrl;
  final bool busy;
  final String? err;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(38),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(38),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'connect to your server',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'server address username and password',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 22),
                TextFormField(
                  controller: serverCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'server',
                    hintText: 'jellyfin.example.com or 192.168.1.2:8096',
                    prefixIcon: Icon(Icons.dns_rounded),
                  ),
                  validator:
                      (String? v) =>
                          (v == null || v.trim().isEmpty) ? 'enter a server' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: userCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'username',
                    prefixIcon: Icon(Icons.person_rounded),
                  ),
                  validator:
                      (String? v) =>
                          (v == null || v.trim().isEmpty) ? 'enter a username' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: passCtrl,
                  obscureText: true,
                  onFieldSubmitted: (_) => busy ? null : onSubmit(),
                  decoration: const InputDecoration(
                    labelText: 'password',
                    prefixIcon: Icon(Icons.lock_rounded),
                  ),
                  validator:
                      (String? v) => (v == null || v.isEmpty) ? 'enter a password' : null,
                ),
                if (err != null) ...<Widget>[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Text(
                      err!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: busy ? null : onSubmit,
                        icon:
                            busy
                                ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                                : const Icon(Icons.arrow_forward_rounded),
                        label: Text(busy ? 'connecting' : 'continue'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SavedPanel extends StatelessWidget {
  const _SavedPanel({required this.session, required this.onUse});

  final dynamic session;
  final ValueChanged<String> onUse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'saved sessions',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          ...session.accounts.map(
            (acc) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => onUse(acc.id),
                borderRadius: BorderRadius.circular(24),
                child: Ink(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.cloud_done_rounded,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              acc.serverName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${acc.username}  ·  ${acc.serverUrl}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
