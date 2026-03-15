class MediaItem {
  const MediaItem({
    required this.id,
    required this.name,
    required this.type,
    required this.overview,
    required this.imageTag,
    required this.backdropTag,
    required this.parentBackdropTag,
    required this.year,
    required this.runtimeTicks,
    required this.communityRating,
    required this.criticRating,
    required this.genres,
    required this.isFavorite,
    required this.played,
    required this.playbackPositionTicks,
    required this.parentIndexNumber,
    required this.indexNumber,
    required this.seriesName,
    required this.albumArtist,
    required this.childCount,
    required this.primaryImageItemId,
    required this.seriesId,
  });

  final String id;
  final String name;
  final String type;
  final String? overview;
  final String? imageTag;
  final String? backdropTag;
  final String? parentBackdropTag;
  final int? year;
  final int? runtimeTicks;
  final double? communityRating;
  final int? criticRating;
  final List<String> genres;
  final bool isFavorite;
  final bool played;
  final int playbackPositionTicks;
  final int? parentIndexNumber;
  final int? indexNumber;
  final String? seriesName;
  final String? albumArtist;
  final int? childCount;
  final String? primaryImageItemId;
  final String? seriesId;

  String get displayType => switch (type) {
    'Movie' => 'movie',
    'Series' => 'show',
    'Season' => 'season',
    'Episode' => 'episode',
    'TvChannel' => 'live',
    'CollectionFolder' => 'collection',
    'Folder' => 'library',
    'ManualPlaylistsFolder' => 'playlist',
    'Playlist' => 'playlist',
    'MusicAlbum' => 'album',
    'Audio' => 'track',
    'Person' => 'person',
    _ => type.toLowerCase(),
  };

  String get subtitle {
    return switch (type) {
      'Movie' => year?.toString() ?? 'movie',
      'Series' => childCount == 1 ? '1 season' : '${childCount ?? 0} seasons',
      'Season' => 'season ${indexNumber ?? ''}'.trim(),
      'Episode' => _episodeLabel,
      'TvChannel' => 'channel',
      'CollectionFolder' => 'collection',
      'Folder' => 'library',
      'ManualPlaylistsFolder' => 'playlist',
      'MusicAlbum' => albumArtist ?? 'album',
      'Audio' => albumArtist ?? 'track',
      _ => displayType,
    };
  }

  String get _episodeLabel {
    final parts = <String>[];
    if (parentIndexNumber != null) {
      final ep = indexNumber?.toString().padLeft(2, '0');
      parts.add('s${parentIndexNumber!.toString().padLeft(2, '0')}${ep == null ? '' : 'e$ep'}');
    } else if (indexNumber != null) {
      parts.add('ep ${indexNumber!}');
    }
    if (seriesName?.isNotEmpty == true) parts.add(seriesName!);
    return parts.isEmpty ? 'episode' : parts.join('  ·  ');
  }

  double? get progress {
    if (runtimeTicks == null || runtimeTicks == 0) return null;
    return (playbackPositionTicks / runtimeTicks!).clamp(0.0, 1.0).toDouble();
  }

  String? get progressLabel {
    final p = progress;
    if (p == null || p <= 0) return null;
    final leftTicks = runtimeTicks! - playbackPositionTicks;
    if (leftTicks > 0) {
      final mins = Duration(microseconds: leftTicks ~/ 10).inMinutes;
      if (mins > 0) return '${mins}m left';
    }
    return '${(p * 100).round()}% watched';
  }

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    final userData =
        json['UserData'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final imageTags =
        json['ImageTags'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final backdropTags =
        json['BackdropImageTags'] as List<dynamic>? ?? <dynamic>[];
    return MediaItem(
      id: json['Id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['Name']?.toString() ?? json['name']?.toString() ?? 'Unknown',
      type: json['Type']?.toString() ?? json['type']?.toString() ?? 'Item',
      overview: json['Overview']?.toString(),
      imageTag:
          json['PrimaryImageTag']?.toString() ??
          imageTags['Primary']?.toString() ??
          imageTags['Thumb']?.toString(),
      backdropTag:
          json['BackdropImageTags'] is List<dynamic> && backdropTags.isNotEmpty
              ? backdropTags.first.toString()
              : null,
      parentBackdropTag:
          json['ParentBackdropImageTags'] is List<dynamic> &&
                  (json['ParentBackdropImageTags'] as List<dynamic>).isNotEmpty
              ? (json['ParentBackdropImageTags'] as List<dynamic>).first
                  .toString()
              : null,
      year: _asInt(json['ProductionYear']),
      runtimeTicks: _asInt(json['RunTimeTicks']),
      communityRating: _asDouble(json['CommunityRating']),
      criticRating: _asInt(json['CriticRating']),
      genres:
          (json['Genres'] as List<dynamic>? ?? <dynamic>[])
              .map((dynamic item) => item.toString())
              .toList(),
      isFavorite: userData['IsFavorite'] == true,
      played: userData['Played'] == true,
      playbackPositionTicks: _asInt(userData['PlaybackPositionTicks']) ?? 0,
      parentIndexNumber: _asInt(json['ParentIndexNumber']),
      indexNumber: _asInt(json['IndexNumber']),
      seriesName: json['SeriesName']?.toString(),
      albumArtist: json['AlbumArtist']?.toString(),
      childCount: _asInt(json['ChildCount']),
      primaryImageItemId: json['PrimaryImageItemId']?.toString(),
      seriesId: json['SeriesId']?.toString(),
    );
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  static double? _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}
