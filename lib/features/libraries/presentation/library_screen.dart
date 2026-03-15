import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/networking/jellyfin_api.dart';
import '../../../shared/models/media_item.dart';
import '../../../shared/widgets/async_value_widget.dart';
import '../../../shared/widgets/loading_grid.dart';
import '../../../shared/widgets/poster_card.dart';
import '../../auth/application/session_controller.dart';
import '../../home/presentation/home_screen.dart';

final libraryQueryProvider = StateProvider<String>((Ref ref) => '');
final selectedLibraryProvider = StateProvider<String?>((Ref ref) => null);

final libraryItemsProvider = FutureProvider<List<MediaItem>>((Ref ref) async {
  final account = ref.watch(activeAccountProvider);
  if (account == null) throw Exception('No session');
  final sel = ref.watch(selectedLibraryProvider);
  final items = await ref
      .watch(jellyfinApiProvider)
      .getLibraryItems(
        account,
        parentId: sel,
        searchTerm: ref.watch(libraryQueryProvider),
      );
  if (sel == '__live_tv__') {
    final favs = ref.watch(
      sessionControllerProvider.select((s) => s.favoriteLiveChannels),
    );
    items.sort((a, b) {
      final af = favs.contains(a.id) ? 0 : 1;
      final bf = favs.contains(b.id) ? 0 : 1;
      if (af != bf) return af.compareTo(bf);
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  }
  return items;
});

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(activeAccountProvider);
    final views = ref.watch(
      homeSectionsProvider.select(
        (AsyncValue<HomeSections> value) =>
            value.valueOrNull?.views ?? <MediaItem>[],
      ),
    );
    final items = ref.watch(libraryItemsProvider);
    final api = ref.watch(jellyfinApiProvider);
    final sel = ref.watch(selectedLibraryProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(libraryItemsProvider.future),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: _LibraryTop(
                        views: views,
                        selectedId: sel,
                        onSelect: (String? value) {
                          ref.read(selectedLibraryProvider.notifier).state = value;
                          ref.invalidate(libraryItemsProvider);
                        },
                        onQuery: (String value) {
                          ref.read(libraryQueryProvider.notifier).state = value;
                          ref.invalidate(libraryItemsProvider);
                        },
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 130),
                    child: AsyncValueWidget(
                      value: items,
                      onRetry: () => ref.invalidate(libraryItemsProvider),
                      loading: const LoadingGrid(count: 10),
                      builder: (List<MediaItem> data) {
                        if (data.isEmpty) {
                          return const _LibraryEmpty();
                        }
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: data.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.62,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 20,
                              ),
                          itemBuilder: (BuildContext context, int idx) {
                            final item = data[idx];
                            return PosterCard(
                              item: item,
                              account: account!,
                              api: api,
                              onTap: () => context.push('/details/${item.id}'),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryTop extends StatelessWidget {
  const _LibraryTop({
    required this.views,
    required this.selectedId,
    required this.onSelect,
    required this.onQuery,
  });

  final List<MediaItem> views;
  final String? selectedId;
  final ValueChanged<String?> onSelect;
  final ValueChanged<String> onQuery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Libraries',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            height: 0.95,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'browse the shelves on your server without digging through menus',
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
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'filter the current library',
                ),
                onChanged: onQuery,
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    FilterChip(
                      label: const Text('All'),
                      selected: selectedId == null,
                      onSelected: (_) => onSelect(null),
                    ),
                    ...views.map(
                      (MediaItem view) => FilterChip(
                        label: Text(view.name),
                        selected: selectedId == view.id,
                        onSelected:
                            (_) => onSelect(selectedId == view.id ? null : view.id),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LibraryEmpty extends StatelessWidget {
  const _LibraryEmpty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              Icons.video_library_outlined,
              color: theme.colorScheme.primary,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No matching media',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'try another library or clear the current filter',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
