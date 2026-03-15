import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/media_item.dart';
import '../../../shared/models/search_results.dart';
import '../../../shared/widgets/poster_card.dart';
import '../../auth/application/session_controller.dart' show jellyfinApiProvider, sessionControllerProvider;
import '../../home/presentation/home_screen.dart' show activeAccountProvider, homeSectionsProvider;
import 'search_screen.dart' show searchResultsProvider;

class SearchCanvasScreen extends ConsumerStatefulWidget {
  const SearchCanvasScreen({super.key});

  @override
  ConsumerState<SearchCanvasScreen> createState() => _SearchCanvasScreenState();
}

class _SearchCanvasScreenState extends ConsumerState<SearchCanvasScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  String _q = '';

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 160), () {
      if (!mounted) return;
      setState(() => _q = v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final acc = ref.watch(activeAccountProvider);
    final api = ref.watch(jellyfinApiProvider);
    final res = _q.isEmpty ? null : ref.watch(searchResultsProvider(_q));
    final home = ref.watch(homeSectionsProvider).valueOrNull;
    final sugg =
        <String>[
          ...session.recentSearches,
          ...?home?.recentlyPlayed.map((e) => e.name),
          ...?home?.latestItems.map((e) => e.name),
        ].fold<List<String>>(<String>[], (list, item) {
          if (item.trim().isEmpty ||
              list.any((v) => v.toLowerCase() == item.toLowerCase())) {
            return list;
          }
          return <String>[...list, item];
        }).take(8).toList();

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: _SearchDock(
                ctrl: _ctrl,
                onChanged: _onChanged,
                onSubmitted: (String v) {
                  if (v.trim().isNotEmpty) {
                    ref.read(sessionControllerProvider.notifier).saveRecentSearch(v);
                  }
                },
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 120),
                child:
                    _q.isEmpty
                        ? _SearchBlank(
                          recent: session.recentSearches,
                          sugg: sugg,
                          onPick: (String v) {
                            _ctrl.text = v;
                            setState(() => _q = v);
                          },
                          onClear:
                              session.recentSearches.isEmpty
                                  ? null
                                  : () => ref
                                      .read(sessionControllerProvider.notifier)
                                      .clearRecentSearches(),
                        )
                        : res!.when(
                          data:
                              (SearchResults data) => _ResultsBody(
                                q: _q,
                                data: data,
                                acc: acc!,
                                api: api,
                              ),
                          loading:
                              () => const _SearchInfo(
                                icon: Icons.hourglass_top_rounded,
                                title: 'searching',
                                body: 'looking through your server',
                              ),
                          error:
                              (Object e, StackTrace _) => _SearchInfo(
                                icon: Icons.cloud_off_rounded,
                                title: 'search failed',
                                body: e.toString().replaceFirst('Exception: ', ''),
                              ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchDock extends StatelessWidget {
  const _SearchDock({
    required this.ctrl,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController ctrl;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'search',
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: ctrl,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: 'movies shows episodes channels people',
            suffixIcon:
                ctrl.text.isEmpty
                    ? null
                    : IconButton(
                      onPressed: () {
                        ctrl.clear();
                        onChanged('');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
          ),
        ),
      ],
    );
  }
}

class _SearchBlank extends StatelessWidget {
  const _SearchBlank({
    required this.recent,
    required this.sugg,
    required this.onPick,
    required this.onClear,
  });

  final List<String> recent;
  final List<String> sugg;
  final ValueChanged<String> onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 130),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'start with a title cast member or series',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'search stays light until you actually type',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (sugg.isNotEmpty) ...<Widget>[
          const SizedBox(height: 20),
          Text(
            'you might be looking for',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sugg
                .map(
                  (item) => ActionChip(
                    label: Text(
                      item,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () => onPick(item),
                  ),
                )
                .toList(),
          ),
        ],
        if (recent.isNotEmpty) ...<Widget>[
          const SizedBox(height: 22),
          Row(
            children: <Widget>[
              Text(
                'recent',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              if (onClear != null)
                TextButton(onPressed: onClear, child: const Text('clear')),
            ],
          ),
          const SizedBox(height: 10),
          ...recent.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => onPick(item),
                borderRadius: BorderRadius.circular(22),
                child: Ink(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.history_rounded),
                      const SizedBox(width: 12),
                      Expanded(child: Text(item)),
                      const Icon(Icons.north_west_rounded),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ResultsBody extends StatelessWidget {
  const _ResultsBody({
    required this.q,
    required this.data,
    required this.acc,
    required this.api,
  });

  final String q;
  final SearchResults data;
  final dynamic acc;
  final dynamic api;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const _SearchInfo(
        icon: Icons.search_off_rounded,
        title: 'no matches',
        body: 'try something broader or shorter',
      );
    }
    return ListView(
      key: ValueKey<String>(q),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 130),
      children: <Widget>[
        _ResultRail(
          title: 'channels',
          items:
              data.other.where((MediaItem item) => item.type == 'TvChannel').toList(),
          acc: acc,
          api: api,
        ),
        _ResultRail(title: 'movies', items: data.movies, acc: acc, api: api),
        _ResultRail(title: 'shows', items: data.series, acc: acc, api: api),
        _ResultRail(title: 'episodes', items: data.episodes, acc: acc, api: api),
        _ResultRail(title: 'people', items: data.people, acc: acc, api: api),
        _ResultRail(
          title: 'more',
          items:
              data.other.where((MediaItem item) => item.type != 'TvChannel').toList(),
          acc: acc,
          api: api,
        ),
      ],
    );
  }
}

class _ResultRail extends StatelessWidget {
  const _ResultRail({
    required this.title,
    required this.items,
    required this.acc,
    required this.api,
  });

  final String title;
  final List<MediaItem> items;
  final dynamic acc;
  final dynamic api;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 272,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemBuilder: (BuildContext context, int idx) {
                final item = items[idx];
                return SizedBox(
                  width: 170,
                  child: PosterCard(
                    item: item,
                    account: acc,
                    api: api,
                    onTap: () => context.push('/details/${item.id}'),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemCount: items.length.clamp(0, 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchInfo extends StatelessWidget {
  const _SearchInfo({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 38, color: theme.colorScheme.primary),
              const SizedBox(height: 14),
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
            ],
          ),
        ),
      ),
    );
  }
}
