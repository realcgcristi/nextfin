import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/networking/jellyfin_api.dart';
import '../models/media_item.dart';
import '../models/server_account.dart';

class PosterCard extends StatelessWidget {
  const PosterCard({
    super.key,
    required this.item,
    required this.account,
    required this.api,
    this.onTap,
    this.onLongPress,
    this.compact = false,
  });

  final MediaItem item;
  final ServerAccount account;
  final JellyfinApi api;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progress = item.progress;
    final imageUrl =
        item.imageTag == null
            ? null
            : api.imageUrl(
              account,
              item.id,
              tag: item.imageTag,
              maxWidth: compact ? 300 : 420,
            );
    return RepaintBoundary(
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Hero(
                tag: 'poster-${item.id}',
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.34),
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 28,
                        offset: const Offset(0, 18),
                      ),
                    ],
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        scheme.surfaceContainerHighest,
                        scheme.surfaceContainer,
                      ],
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      if (imageUrl != null)
                        CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          httpHeaders: <String, String>{
                            'X-Emby-Token': account.accessToken,
                          },
                        )
                      else
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[
                                scheme.surfaceContainerHighest,
                                scheme.primaryContainer.withValues(alpha: 0.42),
                              ],
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              _placeholderIcon(item.type),
                              size: 36,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.center,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.2),
                              Colors.black.withValues(alpha: 0.72),
                            ],
                            stops: const <double>[0, 0.54, 1],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.32),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Text(
                            item.displayType,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 14,
                        right: 14,
                        bottom: progress != null && progress > 0 ? 22 : 14,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.34),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                item.name,
                                maxLines: compact ? 1 : 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                  height: 1.02,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                              if (item.progressLabel != null) ...<Widget>[
                                const SizedBox(height: 5),
                                Text(
                                  item.progressLabel!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.88),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (progress != null && progress > 0)
                        Positioned(
                          left: 14,
                          right: 14,
                          bottom: 12,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 4,
                                backgroundColor: Colors.transparent,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  scheme.primaryContainer,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (!compact) ...<Widget>[
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  if (item.communityRating != null)
                    Icon(Icons.star_rounded, size: 16, color: scheme.tertiary),
                  if (item.communityRating != null) const SizedBox(width: 4),
                  if (item.communityRating != null)
                    Text(
                      item.communityRating!.toStringAsFixed(1),
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _placeholderIcon(String type) => switch (type) {
    'Movie' => Icons.movie_creation_outlined,
    'Series' => Icons.live_tv_rounded,
    'Episode' => Icons.smart_display_rounded,
    'TvChannel' => Icons.sensors_rounded,
    'Folder' || 'CollectionFolder' => Icons.video_library_outlined,
    'ManualPlaylistsFolder' || 'Playlist' => Icons.queue_music_rounded,
    _ => Icons.movie_creation_outlined,
  };
}
