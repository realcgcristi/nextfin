import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/networking/jellyfin_api.dart';
import '../../../shared/models/media_item.dart';
import '../../../shared/models/server_account.dart';
import '../../../shared/widgets/loading_grid.dart';
import '../../../shared/widgets/poster_card.dart';
import '../../auth/application/session_controller.dart';
import 'home_screen.dart' show activeAccountProvider, homeSectionsProvider;

class HomeEditorialScreen extends ConsumerWidget {
  const HomeEditorialScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final acc = ref.watch(activeAccountProvider);
    final api = ref.watch(jellyfinApiProvider);
    final data = ref.watch(homeSectionsProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(homeSectionsProvider.future),
        child: data.when(
          loading:
              () => const Padding(
                padding: EdgeInsets.all(20),
                child: LoadingGrid(count: 6),
              ),
          error:
              (Object e, StackTrace _) => Center(
                child: FilledButton.icon(
                  onPressed: () => ref.invalidate(homeSectionsProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(
                    e.toString().replaceFirst('Exception: ', ''),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          data: (HomeSections s) {
            final account = acc!;
            final activeSeriesIds = <String>{
              ...s.resumeItems
                  .where((item) => item.seriesId?.isNotEmpty == true)
                  .map((item) => item.seriesId!),
              ...s.recentlyPlayed
                  .where((item) => item.seriesId?.isNotEmpty == true)
                  .map((item) => item.seriesId!),
            };
            final hotNextUp =
                s.nextUpItems
                    .where((item) => activeSeriesIds.contains(item.seriesId))
                    .toList();
            final restNextUp =
                s.nextUpItems
                    .where((item) => !activeSeriesIds.contains(item.seriesId))
                    .toList();
            final lead = <MediaItem>[
              ...s.pinnedItems,
              ...s.resumeItems,
              ...hotNextUp,
              ...s.recentlyPlayed,
              ...restNextUp,
              ...s.latestItems,
              ...s.latestMovies,
            ].fold<List<MediaItem>>(<MediaItem>[], (list, item) {
              if (list.any((e) => e.id == item.id)) return list;
              return <MediaItem>[...list, item];
            });
            return CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: _TopLine(account: account),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: _LeadCarousel(
                      items: lead,
                      account: account,
                      api: api,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: _ServerRibbon(
                      account: account,
                      onSearch: () => context.go('/search'),
                      onLibraries: () => context.go('/libraries'),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 130),
                    child: Column(
                      children: <Widget>[
                        if (s.pinnedItems.isNotEmpty)
                          _DeckSection(
                            title: 'pinned',
                            strap: 'your own shortcuts stay pinned near the top',
                            items: s.pinnedItems,
                            account: account,
                            api: api,
                          ),
                        if (s.favoriteLiveChannels.isNotEmpty)
                          _DeckSection(
                            title: 'favorite channels',
                            strap: 'your saved live picks stay right up front',
                            items: s.favoriteLiveChannels,
                            account: account,
                            api: api,
                          ),
                        if (s.recentLiveChannels.isNotEmpty)
                          _DeckSection(
                            title: 'live now',
                            strap: 'jump back into channels you opened lately',
                            items: s.recentLiveChannels,
                            account: account,
                            api: api,
                          ),
                        _DeckSection(
                          title: 'continue watching',
                          strap: 'pick up without scrolling through menus',
                          items: s.resumeItems,
                          account: account,
                          api: api,
                        ),
                        _MiniMosaic(
                          title: 'rooms',
                          strap: 'jump straight into the bigger shelves',
                          items: s.views,
                        ),
                        _DeckSection(
                          title: 'just added',
                          strap: 'fresh drops from the server',
                          items: s.latestItems,
                          account: account,
                          api: api,
                        ),
                        _DeckSection(
                          title: 'recently played',
                          strap: 'easy ways back into what you touched last',
                          items: s.recentlyPlayed,
                          account: account,
                          api: api,
                        ),
                        _DeckSection(
                          title: 'movies',
                          strap: 'new films and easy rewatches',
                          items: s.latestMovies,
                          account: account,
                          api: api,
                        ),
                        _DeckSection(
                          title: 'shows',
                          strap: 'series, episodes, and next nights',
                          items: s.latestShows,
                          account: account,
                          api: api,
                        ),
                        _DeckSection(
                          title: 'for tonight',
                          strap: 'next-up picks that are ready now',
                          items: s.nextUpItems,
                          account: account,
                          api: api,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TopLine extends StatelessWidget {
  const _TopLine({required this.account});

  final ServerAccount account;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = TimeOfDay.now();
    final greet = switch (now.hour) {
      < 5 => 'good night',
      < 12 => 'good morning',
      < 18 => 'good afternoon',
      _ => 'good evening',
    };
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'nextfin',
                style: theme.textTheme.labelLarge?.copyWith(
                  letterSpacing: 1.4,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                greet,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: () => context.go('/settings'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            minimumSize: const Size(0, 42),
            visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          icon: const Icon(Icons.account_circle_rounded, size: 18),
          label: Text(
            account.username,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _LeadCarousel extends StatelessWidget {
  const _LeadCarousel({
    required this.items,
    required this.account,
    required this.api,
  });

  final List<MediaItem> items;
  final ServerAccount account;
  final JellyfinApi api;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return SizedBox(
      height: 324,
      child: PageView.builder(
        controller: PageController(viewportFraction: 0.88),
        itemCount: items.length.clamp(1, 6),
        itemBuilder: (BuildContext context, int idx) {
          final item = items[idx];
          final imageUrl =
              item.backdropTag != null
                  ? api.imageUrl(
                    account,
                    item.id,
                    imageType: 'Backdrop',
                    tag: item.backdropTag,
                    maxWidth: 1400,
                  )
                  : item.imageTag != null
                  ? api.imageUrl(account, item.id, tag: item.imageTag, maxWidth: 800)
                  : null;
          return Padding(
            padding: const EdgeInsets.only(right: 14),
            child: InkWell(
              onTap: () => context.push('/details/${item.id}'),
              borderRadius: BorderRadius.circular(36),
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(36),
                  color: theme.colorScheme.surfaceContainerHigh,
                  image:
                      imageUrl == null
                          ? null
                          : DecorationImage(
                            image: NetworkImage(imageUrl),
                            fit: BoxFit.cover,
                            colorFilter: ColorFilter.mode(
                              Colors.black.withValues(alpha: 0.22),
                              BlendMode.darken,
                            ),
                          ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(36),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: <Color>[
                        Colors.black.withValues(alpha: 0.82),
                        Colors.black.withValues(alpha: 0.24),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          item.displayType,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          height: 0.94,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => context.push('/details/${item.id}'),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(
                          item.playbackPositionTicks > 0 ? 'resume' : 'open',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ServerRibbon extends StatelessWidget {
  const _ServerRibbon({
    required this.account,
    required this.onSearch,
    required this.onLibraries,
  });

  final ServerAccount account;
  final VoidCallback onSearch;
  final VoidCallback onLibraries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  account.serverName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'signed in as ${account.username}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: onSearch,
            icon: const Icon(Icons.search_rounded),
            visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: onLibraries,
            icon: const Icon(Icons.grid_view_rounded),
            visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
          ),
        ],
      ),
    );
  }
}

class _DeckSection extends ConsumerWidget {
  const _DeckSection({
    required this.title,
    required this.strap,
    required this.items,
    required this.account,
    required this.api,
  });

  final String title;
  final String strap;
  final List<MediaItem> items;
  final ServerAccount account;
  final JellyfinApi api;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final favs = ref.watch(
      sessionControllerProvider.select((s) => s.favoriteLiveChannels),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            strap,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 278,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemBuilder: (BuildContext context, int idx) {
                final item = items[idx];
                return SizedBox(
                  width: 172,
                  child: PosterCard(
                    item: item,
                    account: account,
                    api: api,
                    onTap: () => context.push('/details/${item.id}'),
                    onLongPress:
                        item.type == 'TvChannel'
                            ? () async {
                              await ref
                                  .read(sessionControllerProvider.notifier)
                                  .toggleFavoriteLiveChannel(item.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      favs.contains(item.id)
                                          ? 'removed from favorite channels'
                                          : 'saved to favorite channels',
                                    ),
                                  ),
                                );
                              }
                            }
                            : null,
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemCount: items.length.clamp(0, 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMosaic extends StatelessWidget {
  const _MiniMosaic({
    required this.title,
    required this.strap,
    required this.items,
  });

  final String title;
  final String strap;
  final List<MediaItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            strap,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              final cols = c.maxWidth > 720 ? 3 : 2;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length.clamp(0, 6),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.4,
                ),
                itemBuilder: (BuildContext context, int idx) {
                  final item = items[idx];
                  return InkWell(
                    onTap: () => context.go('/libraries'),
                    borderRadius: BorderRadius.circular(24),
                    child: Ink(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.video_library_rounded,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
