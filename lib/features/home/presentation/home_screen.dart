import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/networking/jellyfin_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/application/session_controller.dart';
import '../../../shared/models/server_account.dart';
import '../../../shared/widgets/async_value_widget.dart';
import '../../../shared/widgets/loading_grid.dart';
import '../../../shared/widgets/poster_card.dart';
import '../../../shared/widgets/section_block.dart';

final activeAccountProvider = Provider<ServerAccount?>(
  (Ref ref) => ref.watch(sessionControllerProvider).activeAccount,
);

final homeSectionsProvider = FutureProvider<HomeSections>((Ref ref) async {
  final account = ref.watch(activeAccountProvider);
  if (account == null) throw Exception('No active session.');
  return ref.watch(jellyfinApiProvider).loadHome(account);
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(activeAccountProvider);
    final api = ref.watch(jellyfinApiProvider);
    final sections = ref.watch(homeSectionsProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Text(
          'Nextfin',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 20, top: 8, bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => context.go('/settings'),
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerLow.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.7),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      account?.username ?? '',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(homeSectionsProvider.future),
        child: AsyncValueWidget(
          value: sections,
          onRetry: () => ref.invalidate(homeSectionsProvider),
          loading: const Padding(
            padding: EdgeInsets.all(20),
            child: LoadingGrid(),
          ),
          builder: (data) {
            final activeAccount = account!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        activeAccount.serverName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      'Pull to refresh',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _HeroPanel(account: account),
                const SizedBox(height: 10),
                SectionBlock(
                  title: 'Continue Watching',
                  subtitle: 'Pick up exactly where you left off',
                  child: _HorizontalRail(
                    items: data.resumeItems,
                    account: activeAccount,
                    api: api,
                  ),
                ),
                SectionBlock(
                  title: 'Recently Added',
                  subtitle: 'Fresh additions across your whole server',
                  child: _HorizontalRail(
                    items: data.latestItems,
                    account: activeAccount,
                    api: api,
                  ),
                ),
                SectionBlock(
                  title: 'Latest Movies',
                  subtitle: 'Recently added films ready to watch',
                  child: _HorizontalRail(
                    items: data.latestMovies,
                    account: activeAccount,
                    api: api,
                  ),
                ),
                SectionBlock(
                  title: 'Latest Shows',
                  subtitle: 'Fresh series and returning favorites',
                  child: _HorizontalRail(
                    items: data.latestShows,
                    account: activeAccount,
                    api: api,
                  ),
                ),
                SectionBlock(
                  title: 'Recently Played',
                  subtitle: 'Quick return to titles you finished or sampled',
                  child: _HorizontalRail(
                    items: data.recentlyPlayed,
                    account: activeAccount,
                    api: api,
                  ),
                ),
                SectionBlock(
                  title: 'Next Up',
                  subtitle:
                      activeAccount.capabilities.supportsNextUp
                          ? 'Personalized picks from your in-progress shows'
                          : 'Fallback mode for servers without Next Up',
                  child: _HorizontalRail(
                    items: data.nextUpItems,
                    account: activeAccount,
                    api: api,
                  ),
                ),
                SectionBlock(
                  title: 'Libraries',
                  subtitle: 'Jump into the major spaces on this server',
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children:
                        data.views
                            .map(
                              (item) => ActionChip(
                                label: Text(item.name),
                                avatar: const Icon(Icons.folder_outlined),
                                onPressed:
                                    () => context.go(
                                      '/libraries?parent=${item.id}',
                                    ),
                              ),
                            )
                            .toList(),
                  ),
                ),
                SectionBlock(
                  title: 'Favorites',
                  subtitle: 'Shortcuts to the titles you care about',
                  child: _HorizontalRail(
                    items: data.favorites,
                    account: activeAccount,
                    api: api,
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

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.account});

  final ServerAccount? account;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mood = themeMoodOf(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[mood.heroStart, mood.heroEnd],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: mood.appGlow.withValues(alpha: 0.18),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Connected',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      account?.serverName ?? 'Jellyfin server',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.64),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  account?.username ?? 'Guest',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Your libraries, continue watching, and recommendations are ready.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _HeroChip(
                icon: Icons.cloud_done_outlined,
                label: account?.serverUrl.replaceFirst('https://', '') ?? '',
              ),
              _HeroChip(
                icon: Icons.tune_rounded,
                label: 'Jellyfin ${account?.capabilities.version ?? 'unknown'}',
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => GoRouter.of(context).go('/search'),
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Search'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => GoRouter.of(context).go('/libraries'),
                  icon: const Icon(Icons.grid_view_rounded),
                  label: const Text('Browse libraries'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Text(label, style: theme.textTheme.labelLarge),
        ],
      ),
    );
  }
}

class _HorizontalRail extends StatelessWidget {
  const _HorizontalRail({
    required this.items,
    required this.account,
    required this.api,
  });

  final List<dynamic> items;
  final ServerAccount account;
  final JellyfinApi api;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Nothing here yet. As the server provides more data, this row fills in automatically.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }
    return SizedBox(
      height: 292,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder:
            (BuildContext context, int index) => SizedBox(
              width: 150,
              child: PosterCard(
                item: items[index],
                account: account,
                api: api,
                onTap: () => context.push('/details/${items[index].id}'),
              ),
            ),
      ),
    );
  }
}
