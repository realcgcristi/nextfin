class ServerCapabilities {
  const ServerCapabilities({
    required this.version,
    required this.supportsNextUp,
    required this.supportsResume,
    required this.supportsPlaybackInfo,
    required this.supportsInstantMix,
    required this.supportsUserViews,
    required this.supportsSearchHints,
    required this.probedEndpoints,
    required this.notes,
  });

  final String version;
  final bool supportsNextUp;
  final bool supportsResume;
  final bool supportsPlaybackInfo;
  final bool supportsInstantMix;
  final bool supportsUserViews;
  final bool supportsSearchHints;
  final List<String> probedEndpoints;
  final List<String> notes;

  factory ServerCapabilities.unknown() => const ServerCapabilities(
    version: 'unknown',
    supportsNextUp: false,
    supportsResume: true,
    supportsPlaybackInfo: true,
    supportsInstantMix: false,
    supportsUserViews: true,
    supportsSearchHints: true,
    probedEndpoints: <String>[],
    notes: <String>['Server info not fetched yet.'],
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': version,
    'supportsNextUp': supportsNextUp,
    'supportsResume': supportsResume,
    'supportsPlaybackInfo': supportsPlaybackInfo,
    'supportsInstantMix': supportsInstantMix,
    'supportsUserViews': supportsUserViews,
    'supportsSearchHints': supportsSearchHints,
    'probedEndpoints': probedEndpoints,
    'notes': notes,
  };

  factory ServerCapabilities.fromJson(Map<String, dynamic> json) =>
      ServerCapabilities(
        version: json['version']?.toString() ?? 'unknown',
        supportsNextUp: json['supportsNextUp'] == true,
        supportsResume: json['supportsResume'] != false,
        supportsPlaybackInfo: json['supportsPlaybackInfo'] != false,
        supportsInstantMix: json['supportsInstantMix'] == true,
        supportsUserViews: json['supportsUserViews'] != false,
        supportsSearchHints: json['supportsSearchHints'] != false,
        probedEndpoints:
            (json['probedEndpoints'] as List<dynamic>? ?? <dynamic>[])
                .map((dynamic item) => item.toString())
                .toList(),
        notes:
            (json['notes'] as List<dynamic>? ?? <dynamic>[])
                .map((dynamic item) => item.toString())
                .toList(),
      );
}
