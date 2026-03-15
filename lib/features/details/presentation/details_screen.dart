import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/media_item.dart';
import '../../../shared/widgets/async_value_widget.dart';
import '../../../shared/widgets/poster_card.dart';
import '../../auth/application/session_controller.dart';
import '../../downloads/application/download_controller.dart';
import '../../home/presentation/home_screen.dart';

final itemDetailsProvider = FutureProvider.family<MediaItem, String>((
  Ref ref,
  String itemId,
) async {
  final acc = ref.watch(activeAccountProvider);
  if (acc == null) throw Exception('No active session.');
  return ref.watch(jellyfinApiProvider).getItem(acc, itemId);
});

final childItemsProvider = FutureProvider.family<List<MediaItem>, String>((
  Ref ref,
  String itemId,
) async {
  final acc = ref.watch(activeAccountProvider);
  if (acc == null) throw Exception('No active session.');
  return ref.watch(jellyfinApiProvider).getChildren(acc, itemId);
});

class DetailsScreen extends ConsumerWidget {
  const DetailsScreen({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(itemDetailsProvider(itemId));
    final acc = ref.watch(activeAccountProvider);
    final api = ref.watch(jellyfinApiProvider);
    final pinnedIds = ref.watch(
      sessionControllerProvider.select((s) => s.pinnedItems),
    );

    return Scaffold(
      body: AsyncValueWidget(
        value: item,
        onRetry: () => ref.invalidate(itemDetailsProvider(itemId)),
        builder: (MediaItem data) {
          if (acc == null) {
            return const Center(child: Text('No active session.'));
          }
          final backdropUrl =
              data.backdropTag != null
                  ? api.imageUrl(
                    acc,
                    data.id,
                    imageType: 'Backdrop',
                    tag: data.backdropTag,
                    maxWidth: 1600,
                  )
                  : null;
          final posterUrl =
              data.imageTag != null
                  ? api.imageUrl(
                    acc,
                    data.primaryImageItemId ?? data.id,
                    tag: data.imageTag,
                    maxWidth: 700,
                  )
                  : null;

          return Stack(
            children: <Widget>[
              Positioned.fill(
                child:
                    backdropUrl == null
                        ? DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[
                                Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                Theme.of(context).colorScheme.surface,
                              ],
                            ),
                          ),
                        )
                        : CachedNetworkImage(
                          imageUrl: backdropUrl,
                          fit: BoxFit.cover,
                          httpHeaders: <String, String>{
                            'X-Emby-Token': acc.accessToken,
                          },
                        ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Colors.black.withValues(alpha: 0.18),
                        Colors.black.withValues(alpha: 0.3),
                        Theme.of(context).colorScheme.surface,
                        Theme.of(context).colorScheme.surface,
                      ],
                      stops: const <double>[0, 0.28, 0.6, 1],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: CustomScrollView(
                  slivers: <Widget>[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                        child: _DetailsTop(
                          item: data,
                          onBack: () => Navigator.of(context).maybePop(),
                          onFav: () async {
                            await api.toggleFavorite(acc, data.id, data.isFavorite);
                            ref.invalidate(itemDetailsProvider(itemId));
                            ref.invalidate(homeSectionsProvider);
                          },
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1120),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 28, 20, 120),
                            child: Column(
                              children: <Widget>[
                                _HeroBand(
                                  item: data,
                                  posterUrl: posterUrl,
                                  isPinned: pinnedIds.contains(data.id),
                                  onPlay:
                                      () => _startPlayback(context, ref, data),
                                  onTogglePlayed: () async {
                                    await api.setPlayed(
                                      acc,
                                      data.id,
                                      !data.played,
                                    );
                                    ref.invalidate(itemDetailsProvider(itemId));
                                    ref.invalidate(homeSectionsProvider);
                                  },
                                  onPin: () async {
                                    await ref
                                        .read(sessionControllerProvider.notifier)
                                        .togglePinnedItem(data.id);
                                    ref.invalidate(homeSectionsProvider);
                                  },
                                  onDownload:
                                      data.type == 'Movie' ||
                                              data.type == 'Episode'
                                          ? () async {
                                            await ref
                                                .read(
                                                  downloadControllerProvider
                                                      .notifier,
                                                )
                                                .queue(data);
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'added ${data.name} to downloads',
                                                ),
                                              ),
                                            );
                                          }
                                          : null,
                                ),
                                const SizedBox(height: 22),
                                _OverviewBand(item: data),
                                if (data.genres.isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 18),
                                  _ChipBand(
                                    title: 'Genres',
                                    items: data.genres,
                                  ),
                                ],
                                if (<String>{
                                  'Series',
                                  'Season',
                                  'CollectionFolder',
                                  'BoxSet',
                                }.contains(data.type)) ...<Widget>[
                                  const SizedBox(height: 18),
                                  _ChildrenBand(itemId: itemId),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _startPlayback(
    BuildContext context,
    WidgetRef ref,
    MediaItem item,
  ) async {
    final sett = ref.read(clientSettingsProvider);
    final resumeTicks = item.playbackPositionTicks;
    var startTicks = 0;
    if (resumeTicks > 0 && sett.resumePlayback) {
      final shouldResume = await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        builder:
            (BuildContext context) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Resume playback',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Pick up where you left off or start again from the beginning.',
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(context).pop(true),
                        icon: const Icon(Icons.play_circle_filled_rounded),
                        label: const Text('Resume'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pop(false),
                        icon: const Icon(Icons.replay_rounded),
                        label: const Text('Start over'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      );
      startTicks = shouldResume == true ? resumeTicks : 0;
    }
    if (!context.mounted) return;
    context.push(
      '/player/${item.id}?title=${Uri.encodeComponent(item.name)}&startTicks=$startTicks',
    );
  }
}

class _DetailsTop extends StatelessWidget {
  const _DetailsTop({
    required this.item,
    required this.onBack,
    required this.onFav,
  });

  final MediaItem item;
  final VoidCallback onBack;
  final VoidCallback onFav;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: <Widget>[
        IconButton.filledTonal(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        FilledButton.tonalIcon(
          onPressed: onFav,
          icon: Icon(item.isFavorite ? Icons.favorite : Icons.favorite_border),
          label: Text(item.isFavorite ? 'Saved' : 'Save'),
        ),
      ],
    );
  }
}

class _HeroBand extends StatelessWidget {
  const _HeroBand({
    required this.item,
    required this.posterUrl,
    required this.isPinned,
    required this.onPlay,
    required this.onTogglePlayed,
    required this.onPin,
    required this.onDownload,
  });

  final MediaItem item;
  final String? posterUrl;
  final bool isPinned;
  final VoidCallback onPlay;
  final VoidCallback onTogglePlayed;
  final VoidCallback onPin;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final wide = MediaQuery.of(context).size.width > 860;
    final meta = <Widget>[
      if (item.year != null) _MetaPill(label: '${item.year}'),
      _MetaPill(label: item.type),
      if (item.communityRating != null)
        _MetaPill(
          label: item.communityRating!.toStringAsFixed(1),
          icon: Icons.star_rounded,
        ),
      if (item.runtimeTicks != null)
        _MetaPill(label: _fmtRuntime(item.runtimeTicks!)),
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.26),
        ),
      ),
      child:
          wide
              ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _PosterPane(item: item, posterUrl: posterUrl),
                  const SizedBox(width: 22),
                  Expanded(
                    child: _HeroInfo(
                      item: item,
                      meta: meta,
                      isPinned: isPinned,
                      onPlay: onPlay,
                      onTogglePlayed: onTogglePlayed,
                      onPin: onPin,
                      onDownload: onDownload,
                    ),
                  ),
                ],
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Center(child: _PosterPane(item: item, posterUrl: posterUrl)),
                  const SizedBox(height: 18),
                  _HeroInfo(
                    item: item,
                    meta: meta,
                    isPinned: isPinned,
                    onPlay: onPlay,
                    onTogglePlayed: onTogglePlayed,
                    onPin: onPin,
                    onDownload: onDownload,
                  ),
                ],
              ),
    );
  }
}

class _PosterPane extends StatelessWidget {
  const _PosterPane({required this.item, required this.posterUrl});

  final MediaItem item;
  final String? posterUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Hero(
      tag: 'poster-${item.id}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child:
            posterUrl == null
                ? Container(
                  width: 170,
                  height: 250,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.movie_creation_outlined, size: 42),
                )
                : CachedNetworkImage(
                  imageUrl: posterUrl!,
                  width: 170,
                  height: 250,
                  fit: BoxFit.cover,
                ),
      ),
    );
  }
}

class _HeroInfo extends StatelessWidget {
  const _HeroInfo({
    required this.item,
    required this.meta,
    required this.isPinned,
    required this.onPlay,
    required this.onTogglePlayed,
    required this.onPin,
    required this.onDownload,
  });

  final MediaItem item;
  final List<Widget> meta;
  final bool isPinned;
  final VoidCallback onPlay;
  final VoidCallback onTogglePlayed;
  final VoidCallback onPin;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          item.name,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            height: 0.94,
            letterSpacing: -1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          item.subtitle,
          style: theme.textTheme.titleMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),
        Wrap(spacing: 8, runSpacing: 8, children: meta),
        const SizedBox(height: 18),
        Text(
          item.overview ?? 'No overview available.',
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            FilledButton.icon(
              onPressed: onPlay,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(item.playbackPositionTicks > 0 ? 'Resume' : 'Play'),
            ),
            FilledButton.tonalIcon(
              onPressed: onTogglePlayed,
              icon: Icon(
                item.played
                    ? Icons.visibility_off_outlined
                    : Icons.check_circle_outline,
              ),
              label: Text(item.played ? 'Mark unplayed' : 'Mark played'),
            ),
            FilledButton.tonalIcon(
              onPressed: onPin,
              icon: Icon(
                isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              ),
              label: Text(isPinned ? 'Pinned' : 'Pin'),
            ),
            if (onDownload != null)
              FilledButton.tonalIcon(
                onPressed: onDownload,
                icon: const Icon(Icons.download_rounded),
                label: const Text('Download'),
              ),
          ],
        ),
      ],
    );
  }
}

class _OverviewBand extends StatelessWidget {
  const _OverviewBand({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(34),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Story',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            item.overview ?? 'No overview available.',
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _ChipBand extends StatelessWidget {
  const _ChipBand({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(34),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.map((String e) => Chip(label: Text(e))).toList(),
          ),
        ],
      ),
    );
  }
}

class _ChildrenBand extends ConsumerWidget {
  const _ChildrenBand({required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kids = ref.watch(childItemsProvider(itemId));
    final acc = ref.watch(activeAccountProvider);
    final api = ref.watch(jellyfinApiProvider);
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(34),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Contents',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          kids.when(
            data: (List<MediaItem> items) {
              if (items.isEmpty) {
                return Text(
                  'Nothing here yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
              }
              if (acc == null) {
                return const SizedBox.shrink();
              }
              return LayoutBuilder(
                builder: (BuildContext context, BoxConstraints c) {
                  final cols = c.maxWidth > 980
                      ? 5
                      : c.maxWidth > 760
                      ? 4
                      : c.maxWidth > 520
                      ? 3
                      : 2;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 18,
                      childAspectRatio: 0.58,
                    ),
                    itemBuilder: (BuildContext context, int i) {
                      final item = items[i];
                      return PosterCard(
                        item: item,
                        account: acc,
                        api: api,
                        compact: true,
                        onTap: () => context.push('/details/${item.id}'),
                      );
                    },
                  );
                },
              );
            },
            loading:
                () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
            error: (Object e, StackTrace _) => Text(e.toString()),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 16),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _fmtRuntime(int ticks) {
  final dur = Duration(microseconds: ticks ~/ 10);
  final fmt = DateFormat(dur.inHours > 0 ? 'H:mm:ss' : 'm:ss');
  return fmt.format(DateTime(0).add(dur));
}
