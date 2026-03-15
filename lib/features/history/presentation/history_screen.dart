import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/media_item.dart';
import '../../../shared/widgets/async_value_widget.dart';
import '../../../shared/widgets/loading_grid.dart';
import '../../../shared/widgets/poster_card.dart';
import '../../auth/application/session_controller.dart';
import '../../home/presentation/home_screen.dart';

final watchHistoryProvider = FutureProvider<List<MediaItem>>((Ref ref) async {
  final acc = ref.watch(activeAccountProvider);
  if (acc == null) throw Exception('No active session.');
  final api = ref.watch(jellyfinApiProvider);
  final recentLive =
      ref.watch(sessionControllerProvider.select((s) => s.recentLiveChannels));
  final watched = await api.getRecentlyPlayed(acc);
  final live =
      recentLive.isEmpty ? <MediaItem>[] : await api.getItemsByIds(acc, recentLive);
  return <MediaItem>[
    ...live,
    ...watched.where((item) => !live.any((liveItem) => liveItem.id == item.id)),
  ];
});

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final acc = ref.watch(activeAccountProvider);
    final api = ref.watch(jellyfinApiProvider);
    final data = ref.watch(watchHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('watch history')),
      body: AsyncValueWidget(
        value: data,
        onRetry: () => ref.invalidate(watchHistoryProvider),
        loading: const Padding(
          padding: EdgeInsets.all(20),
          child: LoadingGrid(count: 8),
        ),
        builder: (List<MediaItem> items) {
          if (items.isEmpty) {
            return const Center(child: Text('nothing watched yet'));
          }
          return LayoutBuilder(
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
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 130),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate((BuildContext context, int idx) {
                        final item = items[idx];
                        return PosterCard(
                          item: item,
                          account: acc!,
                          api: api,
                          onTap: () => context.push('/details/${item.id}'),
                        );
                      }, childCount: items.length),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 18,
                        childAspectRatio: 0.62,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
