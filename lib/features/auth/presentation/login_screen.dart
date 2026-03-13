import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/session_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .login(
            serverUrl: _serverController.text,
            username: _usernameController.text,
            password: _passwordController.text,
          );
    } catch (error) {
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final theme = Theme.of(context);
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              theme.colorScheme.primaryContainer,
              theme.colorScheme.surface,
              theme.colorScheme.tertiaryContainer.withValues(alpha: 0.45),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: <Widget>[
              Positioned(
                top: -80,
                right: -40,
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Positioned(
                left: -70,
                bottom: 40,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.tertiary.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    children: <Widget>[
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withValues(
                            alpha: 0.78,
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.12,
                              ),
                              blurRadius: 24,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.play_circle_fill_rounded,
                          color: theme.colorScheme.primary,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Welcome to Nextfin',
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          height: 0.98,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withValues(
                            alpha: 0.82,
                          ),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.36,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Connect to your server',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Sign in with your Jellyfin server URL and account.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  TextFormField(
                                    controller: _serverController,
                                    decoration: const InputDecoration(
                                      labelText: 'Server URL',
                                      hintText: 'https://jellyfin.example.com',
                                      prefixIcon: Icon(Icons.dns_rounded),
                                    ),
                                    validator:
                                        (String? value) =>
                                            (value == null ||
                                                    value.trim().isEmpty)
                                                ? 'Enter a server URL.'
                                                : null,
                                  ),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _usernameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Username',
                                      prefixIcon: Icon(Icons.person_rounded),
                                    ),
                                    validator:
                                        (String? value) =>
                                            (value == null ||
                                                    value.trim().isEmpty)
                                                ? 'Enter your username.'
                                                : null,
                                  ),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Password',
                                      prefixIcon: Icon(Icons.lock_rounded),
                                    ),
                                    validator:
                                        (String? value) =>
                                            (value == null || value.isEmpty)
                                                ? 'Enter your password.'
                                                : null,
                                  ),
                                  if (_error != null) ...<Widget>[
                                    const SizedBox(height: 14),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.errorContainer,
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: Text(
                                        _error!,
                                        style: TextStyle(
                                          color:
                                              theme
                                                  .colorScheme
                                                  .onErrorContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      onPressed: _submitting ? null : _submit,
                                      icon:
                                          _submitting
                                              ? const SizedBox(
                                                height: 16,
                                                width: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                              : const Icon(Icons.login_rounded),
                                      label: const Text('Connect to Jellyfin'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (session.accounts.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface.withValues(
                              alpha: 0.74,
                            ),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.28),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Saved sessions',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ...session.accounts.map(
                                (account) => Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 8,
                                    ),
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          theme.colorScheme.primaryContainer,
                                      child: Icon(
                                        Icons.cloud_done_rounded,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                    title: Text(account.serverName),
                                    subtitle: Text(
                                      '${account.username} • ${account.serverUrl}',
                                    ),
                                    trailing: FilledButton.tonal(
                                      onPressed:
                                          () => ref
                                              .read(
                                                sessionControllerProvider
                                                    .notifier,
                                              )
                                              .switchAccount(account.id),
                                      child: const Text('Use'),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
