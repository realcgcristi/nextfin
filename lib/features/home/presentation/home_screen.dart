import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/networking/jellyfin_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/media_item.dart';
import '../../../shared/models/server_account.dart';
import '../../../shared/widgets/async_value_widget.dart';
import '../../../shared/widgets/loading_grid.dart';
import '../../../shared/widgets/poster_card.dart';
import '../../auth/application/session_controller.dart';

final activeAccountProvider = Provider<ServerAccount?>(
  (Ref ref) => ref.watch(sessionControllerProvider).activeAccount,
);

final homeSectionsProvider = FutureProvider<HomeSections>((Ref ref) async {
  final account = ref.watch(activeAccountProvider);
  if (account == null) throw Exception('No active session.');
  final recentLiveIds =
      ref.watch(sessionControllerProvider.select((s) => s.recentLiveChannels));
  final favoriteLiveIds =
      ref.watch(sessionControllerProvider.select((s) => s.favoriteLiveChannels));
  final pinnedIds =
      ref.watch(sessionControllerProvider.select((s) => s.pinnedItems));
  return ref.watch(jellyfinApiProvider).loadHome(
    account,
    recentLiveIds: recentLiveIds,
    favoriteLiveIds: favoriteLiveIds,
    pinnedIds: pinnedIds,
  );
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final acc = ref.watch(activeAccountProvider);
    final api = ref.watch(jellyfinApiProvider);
    final data = ref.watch(homeSectionsProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(homeSectionsProvider.future),
        child: AsyncValueWidget(
          value: data,
          onRetry: () => ref.invalidate(homeSectionsProvider),
          loading: const Padding(
            padding: EdgeInsets.all(20),
            child: LoadingGrid(count: 6),
          ),
          builder: (HomeSections sections) {
            final account = acc!;
            return CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: SafeArea(
                    bottom: false,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                          child: _HomeTop(
                            account: account,
                            onProfile: () => context.go('/settings'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                        child: _HomeHero(
                          account: account,
                          resumeCount: sections.resumeItems.length,
                          onSearch: () => context.go('/search'),
                          onBrowse: () => context.go('/libraries'),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 130),
                        child: Column(
                          children: <Widget>[
                            _HomeRail(
                              title: 'Continue watching',
                              subtitle: 'pick up where you stopped',
                              items: sections.resumeItems,
                              account: account,
                              api: api,
                              emphasized: true,
                            ),
                            _HomeRail(
                              title: 'Recently added',
                              subtitle: 'fresh from your server',
                              items: sections.latestItems,
                              account: account,
                              api: api,
                            ),
                            _HomeGridSection(
                              title: 'Libraries',
                              subtitle: 'jump straight into the big shelves',
                              views: sections.views,
                            ),
                            _HomeRail(
                              title: 'Movies',
                              subtitle: 'new films ready to queue up',
                              items: sections.latestMovies,
                              account: account,
                              api: api,
                            ),
                            _HomeRail(
                              title: 'Shows',
                              subtitle: 'series and returning favorites',
                              items: sections.latestShows,
                              account: account,
                              api: api,
                            ),
                            _HomeRail(
                              title: 'Recent',
                              subtitle: 'what you touched lately',
                              items: sections.recentlyPlayed,
                              account: account,
                              api: api,
                            ),
                            _HomeRail(
                              title: 'For you',
                              subtitle:
                                  account.capabilities.supportsNextUp
                                      ? 'next up from active shows'
                                      : 'fallback picks from your server',
                              items: sections.nextUpItems,
                              account: account,
                              api: api,
                            ),
                            _HomeRail(
                              title: 'Favorites',
                              subtitle: 'your shortcuts',
                              items: sections.favorites,
                              account: account,
                              api: api,
                            ),
                          ],
                        ),
                      ),
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

class _HomeTop extends StatelessWidget {
  const _HomeTop({required this.account, required this.onProfile});

  final ServerAccount account;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'nextfin',
                style: theme.textTheme.labelLarge?.copyWith(
                  letterSpacing: 1.6,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your server',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 0.94,
                ),
              ),
            ],
          ),
        ),
        _ProfileDock(account: account, onTap: onProfile),
      ],
    );
  }
}

class _HomeHero extends StatelessWidget {
  const _HomeHero({
    required this.account,
    required this.resumeCount,
    required this.onSearch,
    required this.onBrowse,
  });

  final ServerAccount account;
  final int resumeCount;
  final VoidCallback onSearch;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mood = themeMoodOf(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[mood.heroStart, mood.heroEnd],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: mood.appGlow.withValues(alpha: 0.18),
            blurRadius: 40,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  account.serverName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 0.98,
                  ),
                ),
              ),
              _TinyPill(label: 'jellyfin ${account.capabilities.version}'),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'signed in as ${account.username}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: <Widget>[
              Expanded(
                child: _HeroMetric(
                  label: 'ready now',
                  value: '$resumeCount',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HeroMetric(
                  label: 'server',
                  value: account.serverUrl.replaceFirst('https://', '').replaceFirst('http://', ''),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: onSearch,
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Search'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onBrowse,
                  icon: const Icon(Icons.grid_view_rounded),
                  label: const Text('Browse'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HomeRail extends StatelessWidget {
  const _HomeRail({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.account,
    required this.api,
    this.emphasized = false,
  });

  final String title;
  final String subtitle;
  final List<MediaItem> items;
  final ServerAccount account;
  final JellyfinApi api;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
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
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            _EmptyCard(message: 'nothing here yet')
          else
            SizedBox(
              height: emphasized ? 336 : 296,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (BuildContext context, int idx) {
                  final item = items[idx];
                  return SizedBox(
                    width: emphasized ? 188 : 156,
                    child: PosterCard(
                      item: item,
                      account: account,
                      api: api,
                      compact: !emphasized,
                      onTap: () => context.push('/details/${item.id}'),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _HomeGridSection extends StatelessWidget {
  const _HomeGridSection({
    required this.title,
    required this.subtitle,
    required this.views,
  });

  final String title;
  final String subtitle;
  final List<MediaItem> views;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
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
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: views.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (BuildContext context, int idx) {
              final item = views[idx];
              return InkWell(
                onTap: () => context.go('/libraries?parent=${item.id}'),
                borderRadius: BorderRadius.circular(28),
                child: Ink(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow.withValues(
                      alpha: 0.9,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.4,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.folder_outlined,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProfileDock extends StatelessWidget {
  const _ProfileDock({required this.account, required this.onTap});

  final ServerAccount account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.44),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              account.username,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TinyPill extends StatelessWidget {
  const _TinyPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Text(message),
    );
  }
}
