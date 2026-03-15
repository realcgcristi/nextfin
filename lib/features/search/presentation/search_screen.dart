import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/networking/jellyfin_api.dart';
import '../../../shared/models/media_item.dart';
import '../../../shared/models/search_results.dart';
import '../../../shared/models/server_account.dart';
import '../../../shared/widgets/poster_card.dart';
import '../../auth/application/session_controller.dart';
import '../../home/presentation/home_screen.dart';

final searchResultsProvider = FutureProvider.family<SearchResults, String>((
  Ref ref,
  String query,
) async {
  final account = ref.watch(activeAccountProvider);
  if (account == null) throw Exception('No active session.');
  return ref.watch(jellyfinApiProvider).search(account, query);
});

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final account = ref.watch(activeAccountProvider);
    final api = ref.watch(jellyfinApiProvider);
    final res =
        _query.isEmpty ? null : ref.watch(searchResultsProvider(_query));

    return Scaffold(
      resizeToAvoidBottomInset: true,
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
                    child: _SearchTop(
                      ctrl: _ctrl,
                      query: _query,
                      recent: session.recentSearches,
                      onChanged: _onChanged,
                      onRecent: (String value) {
                        _ctrl.text = value;
                        setState(() => _query = value);
                      },
                      onClearRecent:
                          session.recentSearches.isEmpty
                              ? null
                              : () => ref
                                  .read(sessionControllerProvider.notifier)
                                  .clearRecentSearches(),
                      onSubmit:
                          (String value) => ref
                              .read(sessionControllerProvider.notifier)
                              .saveRecentSearch(value),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 130),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    child:
                        _query.isEmpty
                            ? const _SearchIntro()
                            : res!.when(
                              data: (SearchResults data) {
                                if (data.isEmpty) {
                                  return const _SearchState(
                                    title: 'No results',
                                    body:
                                        'nothing matched that search try something broader',
                                    icon: Icons.search_off_rounded,
                                  );
                                }
                                return Column(
                                  key: ValueKey<String>(_query),
                                  children: <Widget>[
                                    _SearchGroup(
                                      title: 'Movies',
                                      items: data.movies,
                                      account: account!,
                                      api: api,
                                    ),
                                    _SearchGroup(
                                      title: 'Shows',
                                      items: data.series,
                                      account: account,
                                      api: api,
                                    ),
                                    _SearchGroup(
                                      title: 'Episodes',
                                      items: data.episodes,
                                      account: account,
                                      api: api,
                                    ),
                                    _SearchGroup(
                                      title: 'People',
                                      items: data.people,
                                      account: account,
                                      api: api,
                                    ),
                                    _SearchGroup(
                                      title: 'More',
                                      items: data.other,
                                      account: account,
                                      api: api,
                                    ),
                                  ],
                                );
                              },
                              loading:
                                  () => const _SearchState(
                                    title: 'Searching',
                                    body: 'looking through your jellyfin server',
                                    icon: Icons.hourglass_top_rounded,
                                    loading: true,
                                  ),
                              error:
                                  (Object error, StackTrace _) => _SearchState(
                                    title: 'Search failed',
                                    body: error
                                        .toString()
                                        .replaceFirst('Exception: ', ''),
                                    icon: Icons.cloud_off_rounded,
                                    action: FilledButton.icon(
                                      onPressed: () => setState(() {}),
                                      icon: const Icon(Icons.refresh_rounded),
                                      label: const Text('Retry'),
                                    ),
                                  ),
                            ),
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

class _SearchTop extends StatelessWidget {
  const _SearchTop({
    required this.ctrl,
    required this.query,
    required this.recent,
    required this.onChanged,
    required this.onRecent,
    required this.onClearRecent,
    required this.onSubmit,
  });

  final TextEditingController ctrl;
  final String query;
  final List<String> recent;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onRecent;
  final VoidCallback? onClearRecent;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Search',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            height: 0.94,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'find anything on your server fast',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.74),
            borderRadius: BorderRadius.circular(34),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.34),
            ),
          ),
          child: Column(
            children: <Widget>[
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'movies, shows, episodes, people',
                ),
                onChanged: onChanged,
                onSubmitted: onSubmit,
              ),
              if (query.isEmpty && recent.isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: <Widget>[
                      Text(
                        'recent',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      if (onClearRecent != null)
                        TextButton(
                          onPressed: onClearRecent,
                          child: const Text('Clear'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        recent
                            .map(
                              (String item) => ActionChip(
                                label: Text(item),
                                onPressed: () => onRecent(item),
                              ),
                            )
                            .toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SearchIntro extends StatelessWidget {
  const _SearchIntro();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(34),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.manage_search_rounded,
              size: 34,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Search your whole server',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'movies, people, episodes, box sets, and whatever else jellyfin knows about',
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

class _SearchGroup extends StatelessWidget {
  const _SearchGroup({
    required this.title,
    required this.items,
    required this.account,
    required this.api,
  });

  final String title;
  final List<MediaItem> items;
  final ServerAccount account;
  final JellyfinApi api;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 286,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (BuildContext context, int idx) {
                final item = items[idx];
                return SizedBox(
                  width: 156,
                  child: PosterCard(
                    item: item,
                    account: account,
                    api: api,
                    compact: true,
                    onTap: () => context.push('/details/${item.id}'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchState extends StatelessWidget {
  const _SearchState({
    required this.title,
    required this.body,
    required this.icon,
    this.loading = false,
    this.action,
  });

  final String title;
  final String body;
  final IconData icon;
  final bool loading;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(34),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(icon, size: 34, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (loading) ...<Widget>[
            const SizedBox(height: 18),
            const CircularProgressIndicator(),
          ],
          if (action != null) ...<Widget>[
            const SizedBox(height: 18),
            action!,
          ],
        ],
      ),
    );
  }
}
