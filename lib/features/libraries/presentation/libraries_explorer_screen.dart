import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/media_item.dart';
import '../../../shared/widgets/loading_grid.dart';
import '../../../shared/widgets/poster_card.dart';
import '../../auth/application/session_controller.dart' show jellyfinApiProvider, sessionControllerProvider;
import '../../home/presentation/home_screen.dart' show activeAccountProvider, homeSectionsProvider;
import 'library_screen.dart' show libraryItemsProvider, libraryQueryProvider, selectedLibraryProvider;

class LibrariesExplorerScreen extends ConsumerStatefulWidget {
  const LibrariesExplorerScreen({super.key});

  @override
  ConsumerState<LibrariesExplorerScreen> createState() =>
      _LibrariesExplorerScreenState();
}

class _LibrariesExplorerScreenState
    extends ConsumerState<LibrariesExplorerScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _queueSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      ref.read(libraryQueryProvider.notifier).state = v.trim();
      ref.invalidate(libraryItemsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final views = ref.watch(
      homeSectionsProvider.select(
        (value) => value.valueOrNull?.views ?? <MediaItem>[],
      ),
    );
    final sel = ref.watch(selectedLibraryProvider);
    final items = ref.watch(libraryItemsProvider);
    final acc = ref.watch(activeAccountProvider);
    final api = ref.watch(jellyfinApiProvider);
    final favs = ref.watch(
      sessionControllerProvider.select((s) => s.favoriteLiveChannels),
    );

    return Scaffold(
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          final cols = c.maxWidth > 980
              ? 5
              : c.maxWidth > 720
              ? 4
              : c.maxWidth > 520
              ? 3
              : 2;
          return CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    child: _ExploreHead(
                      selectedName:
                          sel == '__live_tv__'
                              ? 'live tv'
                              : sel == null
                              ? 'all media'
                              : views
                                  .firstWhere(
                                    (v) => v.id == sel,
                                    orElse: () => const MediaItem(
                                      id: '',
                                      name: 'library',
                                      type: 'Folder',
                                      overview: null,
                                      imageTag: null,
                                      backdropTag: null,
                                      parentBackdropTag: null,
                                      year: null,
                                      runtimeTicks: null,
                                      communityRating: null,
                                      criticRating: null,
                                      genres: <String>[],
                                      isFavorite: false,
                                      played: false,
                                      playbackPositionTicks: 0,
                                      parentIndexNumber: null,
                                      indexNumber: null,
                                      seriesName: null,
                                      albumArtist: null,
                                      childCount: null,
                                      primaryImageItemId: null,
                                      seriesId: null,
                                    ),
                                  )
                                  .name,
                      onChoose: () => _pickLibrary(context, views),
                      ctrl: _ctrl,
                      onSearch: _queueSearch,
                    ),
                  ),
                ),
              ),
              ...items.when(
                loading: () => <Widget>[
                  const SliverPadding(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 130),
                    sliver: SliverToBoxAdapter(child: LoadingGrid(count: 10)),
                  ),
                ],
                error: (Object e, StackTrace _) => <Widget>[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 130),
                    sliver: SliverToBoxAdapter(
                      child: FilledButton.icon(
                        onPressed: () => ref.invalidate(libraryItemsProvider),
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(
                          e.toString().replaceFirst('Exception: ', ''),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ],
                data: (List<MediaItem> data) {
                  if (data.isEmpty) {
                    return <Widget>[
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 130),
                        sliver: SliverToBoxAdapter(
                          child: _EmptyShelf(onReset: () {
                            _ctrl.clear();
                            ref.read(libraryQueryProvider.notifier).state = '';
                            ref.read(selectedLibraryProvider.notifier).state = null;
                            ref.invalidate(libraryItemsProvider);
                          }),
                        ),
                      ),
                    ];
                  }
                  return <Widget>[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          '${data.length} items',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 130),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate((BuildContext context, int idx) {
                          final item = data[idx];
                          return PosterCard(
                            item: item,
                            account: acc!,
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
                          );
                        }, childCount: data.length),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 18,
                          childAspectRatio: 0.62,
                        ),
                      ),
                    ),
                  ];
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickLibrary(BuildContext context, List<MediaItem> views) async {
    final picked = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      builder:
          (BuildContext context) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              children: <Widget>[
                const ListTile(title: Text('choose a library')),
                ListTile(
                  title: const Text('all media'),
                  onTap: () => Navigator.of(context).pop(null),
                ),
                ListTile(
                  title: const Text('live tv'),
                  onTap: () => Navigator.of(context).pop('__live_tv__'),
                ),
                ...views.map(
                  (v) => ListTile(
                    title: Text(v.name),
                    onTap: () => Navigator.of(context).pop(v.id),
                  ),
                ),
              ],
            ),
          ),
    );
    if (!mounted) return;
    ref.read(selectedLibraryProvider.notifier).state = picked;
    ref.invalidate(libraryItemsProvider);
  }
}

class _ExploreHead extends StatelessWidget {
  const _ExploreHead({
    required this.selectedName,
    required this.onChoose,
    required this.ctrl,
    required this.onSearch,
  });

  final String selectedName;
  final VoidCallback onChoose;
  final TextEditingController ctrl;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'explore',
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'current shelf  ·  $selectedName',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            Chip(
              avatar: const Icon(Icons.search_rounded, size: 16),
              label: const Text('search in shelf'),
              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
            ),
            if (selectedName == 'live tv')
              Chip(
                avatar: const Icon(Icons.sensors_rounded, size: 16),
                label: const Text('channels'),
                visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
              ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: ctrl,
          onChanged: onSearch,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: 'search inside the current shelf',
            suffixIcon:
                ctrl.text.isEmpty
                    ? IconButton(
                      onPressed: onChoose,
                      icon: const Icon(Icons.tune_rounded),
                    )
                    : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                          onPressed: () {
                            ctrl.clear();
                            onSearch('');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                        IconButton(
                          onPressed: onChoose,
                          icon: const Icon(Icons.tune_rounded),
                        ),
                      ],
                    ),
          ),
        ),
      ],
    );
  }
}

class _EmptyShelf extends StatelessWidget {
  const _EmptyShelf({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.video_library_outlined,
            size: 40,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 14),
          Text(
            'nothing matched here',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'try another shelf or clear the current search',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(onPressed: onReset, child: const Text('reset')),
        ],
      ),
    );
  }
}
