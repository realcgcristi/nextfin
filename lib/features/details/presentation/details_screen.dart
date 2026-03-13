import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/application/session_controller.dart';
import '../../home/presentation/home_screen.dart';
import '../../../shared/models/media_item.dart';
import '../../../shared/widgets/async_value_widget.dart';

final itemDetailsProvider = FutureProvider.family<MediaItem, String>((
  Ref ref,
  String itemId,
) async {
  final account = ref.watch(activeAccountProvider);
  if (account == null) throw Exception('No active session.');
  return ref.watch(jellyfinApiProvider).getItem(account, itemId);
});

final childItemsProvider = FutureProvider.family<List<MediaItem>, String>((
  Ref ref,
  String itemId,
) async {
  final account = ref.watch(activeAccountProvider);
  if (account == null) throw Exception('No active session.');
  return ref.watch(jellyfinApiProvider).getChildren(account, itemId);
});

class DetailsScreen extends ConsumerWidget {
  const DetailsScreen({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(itemDetailsProvider(itemId));
    final account = ref.watch(activeAccountProvider);
    final api = ref.watch(jellyfinApiProvider);
    return Scaffold(
      body: AsyncValueWidget(
        value: item,
        onRetry: () => ref.invalidate(itemDetailsProvider(itemId)),
        builder: (data) {
          if (account == null) {
            return const Center(child: Text('No active session.'));
          }
          final backdropUrl =
              data.backdropTag != null
                  ? api.imageUrl(
                    account,
                    data.id,
                    imageType: 'Backdrop',
                    tag: data.backdropTag,
                    maxWidth: 1280,
                  )
                  : null;
          final posterUrl =
              data.imageTag != null
                  ? api.imageUrl(
                    account,
                    data.primaryImageItemId ?? data.id,
                    tag: data.imageTag,
                    maxWidth: 460,
                  )
                  : null;
          return CustomScrollView(
            slivers: <Widget>[
              SliverAppBar.large(
                pinned: true,
                expandedHeight: 320,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(data.name),
                  background: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      if (backdropUrl != null)
                        CachedNetworkImage(
                          imageUrl: backdropUrl,
                          fit: BoxFit.cover,
                          httpHeaders: <String, String>{
                            'X-Emby-Token': account.accessToken,
                          },
                        ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              Colors.transparent,
                              Theme.of(context).colorScheme.surface,
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                sliver: SliverList.list(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color:
                            Theme.of(context).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Hero(
                                tag: 'poster-${data.id}',
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child:
                                      posterUrl == null
                                          ? Container(
                                            width: 118,
                                            height: 172,
                                            color:
                                                Theme.of(context)
                                                    .colorScheme
                                                    .surfaceContainerHighest,
                                            child: const Icon(
                                              Icons.movie_creation_outlined,
                                            ),
                                          )
                                          : CachedNetworkImage(
                                            imageUrl: posterUrl,
                                            width: 118,
                                            height: 172,
                                            fit: BoxFit.cover,
                                            httpHeaders: <String, String>{
                                              'X-Emby-Token':
                                                  account.accessToken,
                                            },
                                          ),
                                ),
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      data.name,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      data.subtitle,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium?.copyWith(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              if (data.year != null)
                                Chip(label: Text(data.year.toString())),
                              Chip(label: Text(data.type)),
                              if (data.communityRating != null)
                                Chip(
                                  avatar: const Icon(
                                    Icons.star_rounded,
                                    size: 18,
                                  ),
                                  label: Text(
                                    data.communityRating!.toStringAsFixed(1),
                                  ),
                                ),
                              if (data.criticRating != null)
                                Chip(
                                  label: Text('Critic ${data.criticRating}'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            data.overview ?? 'No overview available.',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _startPlayback(context, ref, data),
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: Text(
                              data.playbackPositionTicks > 0
                                  ? 'Resume'
                                  : 'Play',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.tonalIcon(
                          onPressed: () async {
                            await api.toggleFavorite(
                              account,
                              data.id,
                              data.isFavorite,
                            );
                            if (!context.mounted) return;
                            ref.invalidate(itemDetailsProvider(itemId));
                            ref.invalidate(homeSectionsProvider);
                          },
                          icon: Icon(
                            data.isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                          ),
                          label: Text(
                            data.isFavorite ? 'Favorited' : 'Favorite',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        await api.setPlayed(account, data.id, !data.played);
                        ref.invalidate(itemDetailsProvider(itemId));
                      },
                      icon: Icon(
                        data.played
                            ? Icons.visibility_off_outlined
                            : Icons.check_circle_outline,
                      ),
                      label: Text(
                        data.played ? 'Mark Unplayed' : 'Mark Played',
                      ),
                    ),
                    if (data.genres.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            data.genres
                                .map((String genre) => Chip(label: Text(genre)))
                                .toList(),
                      ),
                    ],
                    if (<String>{
                      'Series',
                      'Season',
                      'CollectionFolder',
                      'BoxSet',
                    }.contains(data.type)) ...<Widget>[
                      const SizedBox(height: 26),
                      Text(
                        'Contents',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Consumer(
                        builder: (
                          BuildContext context,
                          WidgetRef ref,
                          Widget? child,
                        ) {
                          final children = ref.watch(
                            childItemsProvider(itemId),
                          );
                          return children.when(
                            data:
                                (items) => Column(
                                  children:
                                      items
                                          .map(
                                            (item) => Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 12,
                                              ),
                                              child: Card(
                                                child: ListTile(
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          24,
                                                        ),
                                                  ),
                                                  title: Text(item.name),
                                                  subtitle: Text(item.subtitle),
                                                  trailing:
                                                      item.runtimeTicks == null
                                                          ? null
                                                          : Text(
                                                            _formatRuntime(
                                                              item.runtimeTicks!,
                                                            ),
                                                          ),
                                                  onTap:
                                                      () => context.push(
                                                        '/details/${item.id}',
                                                      ),
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                ),
                            loading:
                                () => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                            error:
                                (Object error, StackTrace _) =>
                                    Text(error.toString()),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatRuntime(int ticks) {
    final duration = Duration(microseconds: ticks ~/ 10);
    final formatter = DateFormat(duration.inHours > 0 ? 'H:mm:ss' : 'm:ss');
    return formatter.format(DateTime(0).add(duration));
  }

  Future<void> _startPlayback(
    BuildContext context,
    WidgetRef ref,
    MediaItem item,
  ) async {
    final settings = ref.read(clientSettingsProvider);
    final resumeTicks = item.playbackPositionTicks;
    var startTicks = 0;
    if (resumeTicks > 0 && settings.resumePlayback) {
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
