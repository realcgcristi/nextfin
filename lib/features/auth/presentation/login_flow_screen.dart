import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../application/session_controller.dart';

class LoginFlowScreen extends ConsumerStatefulWidget {
  const LoginFlowScreen({super.key});

  @override
  ConsumerState<LoginFlowScreen> createState() => _LoginFlowScreenState();
}

class _LoginFlowScreenState extends ConsumerState<LoginFlowScreen> {
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
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mood = themeMoodOf(context);
    final session = ref.watch(sessionControllerProvider);
    return Scaffold(
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.8, -0.9),
                  radius: 1.55,
                  colors: <Color>[
                    mood.appGlow.withValues(alpha: 0.28),
                    mood.appBackgroundTop,
                    mood.appBackgroundBottom,
                  ],
                  stops: const <double>[0, 0.34, 1],
                ),
              ),
            ),
          ),
          Positioned(
            top: -120,
            right: -90,
            child: IgnorePointer(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: <Widget>[
                    const SizedBox(height: 18),
                    Text(
                      'nextfin',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelLarge?.copyWith(
                        letterSpacing: 1.8,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'bring your\nserver with you',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'sign in once and drop straight into your jellyfin library',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withValues(alpha: 0.86),
                        borderRadius: BorderRadius.circular(34),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.28,
                          ),
                        ),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'connect',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 18),
                            TextFormField(
                              controller: _serverCtrl,
                              decoration: const InputDecoration(
                                labelText: 'server',
                                hintText: 'jellyfin.example.com',
                                prefixIcon: Icon(Icons.dns_rounded),
                              ),
                              validator:
                                  (String? v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'enter a server'
                                          : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _userCtrl,
                              decoration: const InputDecoration(
                                labelText: 'username',
                                prefixIcon: Icon(Icons.person_rounded),
                              ),
                              validator:
                                  (String? v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'enter a username'
                                          : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passCtrl,
                              obscureText: true,
                              onFieldSubmitted: (_) => _busy ? null : _submit(),
                              decoration: const InputDecoration(
                                labelText: 'password',
                                prefixIcon: Icon(Icons.lock_rounded),
                              ),
                              validator:
                                  (String? v) =>
                                      (v == null || v.isEmpty)
                                          ? 'enter a password'
                                          : null,
                            ),
                            if (_err != null) ...<Widget>[
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Text(
                                  _err!,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _busy ? null : _submit,
                                icon:
                                    _busy
                                        ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                        : const Icon(Icons.arrow_forward_rounded),
                                label: Text(_busy ? 'connecting' : 'enter'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (session.accounts.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 18),
                      _SavedRibbon(
                        session: session,
                        onUse:
                            (String id) => ref
                                .read(sessionControllerProvider.notifier)
                                .switchAccount(id),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedRibbon extends StatelessWidget {
  const _SavedRibbon({required this.session, required this.onUse});

  final dynamic session;
  final ValueChanged<String> onUse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'saved sessions',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 116,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: session.accounts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (BuildContext context, int idx) {
              final acc = session.accounts[idx];
              return SizedBox(
                width: 250,
                child: InkWell(
                  onTap: () => onUse(acc.id),
                  borderRadius: BorderRadius.circular(24),
                  child: Ink(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(24),
                    ),
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
                        const SizedBox(height: 6),
                        Text(
                          acc.username,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          acc.serverUrl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
