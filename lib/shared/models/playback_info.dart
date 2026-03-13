class PlaybackInfo {
  const PlaybackInfo({
    required this.playSessionId,
    required this.mediaSources,
    required this.streamUrl,
  });

  final String? playSessionId;
  final List<PlaybackMediaSource> mediaSources;
  final String streamUrl;

  PlaybackMediaSource? get primaryMediaSource =>
      mediaSources.isEmpty ? null : mediaSources.first;

  String? get mediaSourceId => primaryMediaSource?.id;

  List<MediaStreamInfo> get subtitleStreams =>
      primaryMediaSource?.subtitleStreams ?? const <MediaStreamInfo>[];

  List<MediaStreamInfo> get audioStreams =>
      primaryMediaSource?.audioStreams ?? const <MediaStreamInfo>[];

  factory PlaybackInfo.fromJson(
    Map<String, dynamic> json, {
    required String fallbackUrl,
  }) {
    final mediaSources =
        (json['MediaSources'] as List<dynamic>? ?? <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(PlaybackMediaSource.fromJson)
            .where((PlaybackMediaSource source) => source.id.isNotEmpty)
            .toList();
    return PlaybackInfo(
      streamUrl: fallbackUrl,
      playSessionId: json['PlaySessionId']?.toString(),
      mediaSources: mediaSources,
    );
  }
}

class PlaybackMediaSource {
  const PlaybackMediaSource({
    required this.id,
    required this.container,
    required this.protocol,
    required this.name,
    required this.path,
    required this.supportsDirectPlay,
    required this.supportsDirectStream,
    required this.supportsTranscoding,
    required this.transcodingUrl,
    required this.directStreamUrl,
    required this.mediaStreams,
  });

  final String id;
  final String? container;
  final String? protocol;
  final String? name;
  final String? path;
  final bool supportsDirectPlay;
  final bool supportsDirectStream;
  final bool supportsTranscoding;
  final String? transcodingUrl;
  final String? directStreamUrl;
  final List<MediaStreamInfo> mediaStreams;

  List<MediaStreamInfo> get subtitleStreams =>
      mediaStreams
          .where((MediaStreamInfo item) => item.type == 'Subtitle')
          .toList();

  List<MediaStreamInfo> get audioStreams =>
      mediaStreams
          .where((MediaStreamInfo item) => item.type == 'Audio')
          .toList();

  factory PlaybackMediaSource.fromJson(Map<String, dynamic> json) {
    final streams =
        (json['MediaStreams'] as List<dynamic>? ?? <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(MediaStreamInfo.fromJson)
            .toList();
    return PlaybackMediaSource(
      id: json['Id']?.toString() ?? '',
      container: json['Container']?.toString(),
      protocol: json['Protocol']?.toString(),
      name: json['Name']?.toString(),
      path: json['Path']?.toString(),
      supportsDirectPlay: json['SupportsDirectPlay'] != false,
      supportsDirectStream: json['SupportsDirectStream'] != false,
      supportsTranscoding: json['SupportsTranscoding'] != false,
      transcodingUrl: json['TranscodingUrl']?.toString(),
      directStreamUrl: json['DirectStreamUrl']?.toString(),
      mediaStreams: streams,
    );
  }
}

class MediaStreamInfo {
  const MediaStreamInfo({
    required this.type,
    required this.index,
    required this.displayTitle,
    required this.language,
    required this.isDefault,
    required this.codec,
    required this.deliveryUrl,
    required this.isExternal,
  });

  final String type;
  final int index;
  final String displayTitle;
  final String? language;
  final bool isDefault;
  final String? codec;
  final String? deliveryUrl;
  final bool isExternal;

  factory MediaStreamInfo.fromJson(Map<String, dynamic> json) =>
      MediaStreamInfo(
        type: json['Type']?.toString() ?? 'Unknown',
        index: int.tryParse(json['Index']?.toString() ?? '') ?? 0,
        displayTitle:
            json['DisplayTitle']?.toString() ??
            json['Title']?.toString() ??
            json['Language']?.toString() ??
            'Unknown',
        language: json['Language']?.toString(),
        isDefault: json['IsDefault'] == true,
        codec: json['Codec']?.toString(),
        deliveryUrl: json['DeliveryUrl']?.toString(),
        isExternal: json['IsExternal'] == true,
      );
}
