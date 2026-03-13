import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/networking/jellyfin_api.dart';
import '../../auth/application/session_controller.dart';
import '../../home/presentation/home_screen.dart';
import '../../../shared/models/media_item.dart';
import '../../../shared/widgets/async_value_widget.dart';
import '../../../shared/widgets/loading_grid.dart';
import '../../../shared/widgets/poster_card.dart';

final libraryQueryProvider = StateProvider<String>((Ref ref) => '');
final selectedLibraryProvider = StateProvider<String?>((Ref ref) => null);

final libraryItemsProvider = FutureProvider<List<MediaItem>>((Ref ref) async {
  final account = ref.watch(activeAccountProvider);
  if (account == null) throw Exception('No session');
  return ref
      .watch(jellyfinApiProvider)
      .getLibraryItems(
        account,
        parentId: ref.watch(selectedLibraryProvider),
        searchTerm: ref.watch(libraryQueryProvider),
      );
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Libraries'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(88),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Filter within the current library',
              ),
              onChanged: (String value) {
                ref.read(libraryQueryProvider.notifier).state = value;
                ref.invalidate(libraryItemsProvider);
              },
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(libraryItemsProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Library filters',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (BuildContext context, int index) {
                        final selected =
                            ref.watch(selectedLibraryProvider) ==
                            views[index].id;
                        return FilterChip(
                          label: Text(views[index].name),
                          selected: selected,
                          onSelected: (_) {
                            ref.read(selectedLibraryProvider.notifier).state =
                                selected ? null : views[index].id;
                            ref.invalidate(libraryItemsProvider);
                          },
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemCount: views.length,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AsyncValueWidget(
              value: items,
              onRetry: () => ref.invalidate(libraryItemsProvider),
              loading: const LoadingGrid(count: 10),
              builder: (data) {
                if (data.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No media matched the current library and filters.',
                      ),
                    ),
                  );
                }
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: data.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.62,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemBuilder:
                      (BuildContext context, int index) => PosterCard(
                        item: data[index],
                        account: account!,
                        api: api,
                        onTap: () => context.push('/details/${data[index].id}'),
                      ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
