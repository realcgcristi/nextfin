import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/networking/jellyfin_api.dart';
import '../../../shared/models/media_item.dart';
import '../../../shared/models/server_account.dart';
import '../../auth/application/session_controller.dart';
import '../../home/presentation/home_screen.dart';
import '../../../shared/models/search_results.dart';
import '../../../shared/widgets/poster_card.dart';

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
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final account = ref.watch(activeAccountProvider);
    final api = ref.watch(jellyfinApiProvider);
    final results =
        _query.isEmpty ? null : ref.watch(searchResultsProvider(_query));
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
        children: <Widget>[
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Movies, shows, episodes, collections...',
            ),
            onChanged: _onChanged,
            onSubmitted:
                (String value) => ref
                    .read(sessionControllerProvider.notifier)
                    .saveRecentSearch(value),
          ),
          const SizedBox(height: 18),
          if (_query.isEmpty && session.recentSearches.isNotEmpty) ...<Widget>[
            Row(
              children: <Widget>[
                const Expanded(child: Text('Recent searches')),
                TextButton(
                  onPressed:
                      () =>
                          ref
                              .read(sessionControllerProvider.notifier)
                              .clearRecentSearches(),
                  child: const Text('Clear'),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  session.recentSearches
                      .map(
                        (item) => ActionChip(
                          label: Text(item),
                          onPressed: () {
                            _controller.text = item;
                            setState(() => _query = item);
                          },
                        ),
                      )
                      .toList(),
            ),
          ],
          if (_query.isNotEmpty && results != null)
            results.when(
              data: (data) {
                if (data.isEmpty) {
                  return const _SearchStateCard(
                    icon: Icons.search_off_rounded,
                    title: 'No results found',
                    message: 'Try a broader search term or check the spelling.',
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _ResultSection(
                      title: 'Movies',
                      items: data.movies,
                      account: account!,
                      api: api,
                    ),
                    _ResultSection(
                      title: 'Shows',
                      items: data.series,
                      account: account,
                      api: api,
                    ),
                    _ResultSection(
                      title: 'Episodes',
                      items: data.episodes,
                      account: account,
                      api: api,
                    ),
                    _ResultSection(
                      title: 'People',
                      items: data.people,
                      account: account,
                      api: api,
                    ),
                    _ResultSection(
                      title: 'More',
                      items: data.other,
                      account: account,
                      api: api,
                    ),
                  ],
                );
              },
              loading:
                  () => const _SearchStateCard(
                    icon: Icons.hourglass_top_rounded,
                    title: 'Searching your server',
                    message: 'Finding movies, shows, episodes, and people...',
                    loading: true,
                  ),
              error:
                  (Object error, StackTrace _) => _SearchStateCard(
                    icon: Icons.cloud_off_rounded,
                    title: 'Search failed',
                    message: error.toString().replaceFirst('Exception: ', ''),
                    actionLabel: 'Retry',
                    onAction: () => setState(() {}),
                  ),
            ),
        ],
      ),
    );
  }
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({
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
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 258,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemBuilder: (BuildContext context, int index) {
                final item = items[index];
                return SizedBox(
                  width: 148,
                  child: PosterCard(
                    item: item,
                    account: account,
                    api: api,
                    compact: true,
                    onTap: () => context.push('/details/${item.id}'),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemCount: items.length,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchStateCard extends StatelessWidget {
  const _SearchStateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.loading = false,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool loading;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            Icon(icon, size: 38, color: theme.colorScheme.primary),
            const SizedBox(height: 14),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (loading) ...<Widget>[
              const SizedBox(height: 18),
              const CircularProgressIndicator(),
            ],
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: 18),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
