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
    this.compact = false,
  });

  final MediaItem item;
  final ServerAccount account;
  final JellyfinApi api;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress =
        item.runtimeTicks == null || item.runtimeTicks == 0
            ? null
            : (item.playbackPositionTicks / item.runtimeTicks!)
                .clamp(0.0, 1.0)
                .toDouble();
    final imageUrl =
        item.imageTag == null
            ? null
            : api.imageUrl(
              account,
              item.id,
              tag: item.imageTag,
              maxWidth: compact ? 300 : 420,
            );
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Hero(
              tag: 'poster-${item.id}',
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.45,
                    ),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 20,
                      offset: const Offset(0, 12),
                    ),
                  ],
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      theme.colorScheme.surfaceContainerHighest,
                      theme.colorScheme.surfaceContainer,
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
                      const Center(
                        child: Icon(Icons.movie_creation_outlined, size: 36),
                      ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.08),
                            Colors.black.withValues(alpha: 0.48),
                          ],
                          stops: const <double>[0.35, 0.7, 1],
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
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          item.type,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: progress != null && progress > 0 ? 22 : 16,
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
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.84),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (progress != null && progress > 0)
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 4,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.18,
                            ),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              theme.colorScheme.primaryContainer,
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
                  Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: theme.colorScheme.tertiary,
                  ),
                if (item.communityRating != null) const SizedBox(width: 4),
                if (item.communityRating != null)
                  Text(
                    item.communityRating!.toStringAsFixed(1),
                    style: theme.textTheme.labelMedium,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
