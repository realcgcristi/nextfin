import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../shared/models/jellyfin_user.dart';
import '../../shared/models/media_item.dart';
import '../../shared/models/playback_info.dart';
import '../../shared/models/search_results.dart';
import '../../shared/models/server_account.dart';
import '../compatibility/compatibility.dart';
import '../error/app_exception.dart';

class AuthResult {
  const AuthResult({required this.account, required this.user});

  final ServerAccount account;
  final JellyfinUser user;
}

class HomeSections {
  const HomeSections({
    required this.views,
    required this.resumeItems,
    required this.latestItems,
    required this.latestMovies,
    required this.latestShows,
    required this.recentlyPlayed,
    required this.nextUpItems,
    required this.favorites,
  });

  final List<MediaItem> views;
  final List<MediaItem> resumeItems;
  final List<MediaItem> latestItems;
  final List<MediaItem> latestMovies;
  final List<MediaItem> latestShows;
  final List<MediaItem> recentlyPlayed;
  final List<MediaItem> nextUpItems;
  final List<MediaItem> favorites;
}

class PlaybackUrlPreview {
  const PlaybackUrlPreview({
    required this.statusCode,
    required this.contentType,
    this.body,
  });

  final int statusCode;
  final String? contentType;
  final String? body;
}

class JellyfinApi {
  JellyfinApi({Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options
      ..connectTimeout = const Duration(seconds: 12)
      ..receiveTimeout = const Duration(seconds: 20)
      ..sendTimeout = const Duration(seconds: 20)
      ..validateStatus = (int? status) => status != null && status < 500;
  }

  final Dio _dio;
  final _compatibility = const CompatibilityInspector();
  static const _clientName = 'Nextfin';
  static const _deviceName = 'Nextfin Flutter';
  static const _deviceId = 'nextfin-flutter';
  static const _version = '0.1.0';

  String normalizeServerUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const NetworkException('Enter your Jellyfin server URL.');
    }
    final hasScheme =
        trimmed.startsWith('http://') || trimmed.startsWith('https://');
    final normalized = (hasScheme ? trimmed : 'https://$trimmed').replaceAll(
      RegExp(r'/*$'),
      '',
    );
    final uri = Uri.tryParse(normalized);
    if (uri == null || uri.host.isEmpty) {
      throw const NetworkException('That server URL is not valid.');
    }
    return normalized;
  }

  Future<AuthResult> authenticate({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    final baseUrl = normalizeServerUrl(serverUrl);
    final publicInfo = await _getMap(baseUrl, '/System/Info/Public');

    final response = await _dio.post<Map<String, dynamic>>(
      '$baseUrl/Users/AuthenticateByName',
      data: <String, dynamic>{'Username': username, 'Pw': password},
      options: Options(
        headers: <String, dynamic>{'X-Emby-Authorization': _authHeader()},
      ),
    );

    if (response.statusCode != 200 || response.data == null) {
      throw const AuthenticationException(
        'Login failed. Check your credentials.',
      );
    }

    final data = response.data!;
    final user = JellyfinUser.fromJson(
      data['User'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
    final accessToken = data['AccessToken']?.toString();

    if (user.id.isEmpty || accessToken == null || accessToken.isEmpty) {
      throw const AuthenticationException(
        'Server returned an incomplete session.',
      );
    }

    final endpointAvailability = await _probeEndpoints(
      baseUrl,
      accessToken,
      user.id,
    );
    final systemInfo = await _getMap(
      baseUrl,
      '/System/Info',
      token: accessToken,
    ).catchError((Object _) => publicInfo);

    final capabilities = _compatibility.infer(
      systemInfo: systemInfo,
      endpointAvailability: endpointAvailability,
    );

    final serverName =
        systemInfo['ServerName']?.toString() ??
        publicInfo['ServerName']?.toString() ??
        Uri.parse(baseUrl).host;

    final account = ServerAccount(
      id: '$baseUrl::${user.id}',
      serverUrl: baseUrl,
      serverName: serverName,
      userId: user.id,
      username: user.name,
      accessToken: accessToken,
      capabilities: capabilities,
    );

    return AuthResult(account: account, user: user);
  }

  Future<HomeSections> loadHome(ServerAccount account) async {
    final views = await getUserViews(account);
    final futures =
        await Future.wait<List<MediaItem>>(<Future<List<MediaItem>>>[
          getResumeItems(account),
          getLatestItems(account),
          getLatestMovies(account),
          getLatestShows(account),
          getRecentlyPlayed(account),
          if (account.capabilities.supportsNextUp)
            getNextUp(account)
          else
            getLatestEpisodes(account),
          getFavoriteItems(account),
        ]);
    return HomeSections(
      views: views,
      resumeItems: futures[0],
      latestItems: futures[1],
      latestMovies: futures[2],
      latestShows: futures[3],
      recentlyPlayed: futures[4],
      nextUpItems: futures[5],
      favorites: futures[6],
    );
  }

  Future<List<MediaItem>> getUserViews(ServerAccount account) async {
    final response = await _getMap(
      account.serverUrl,
      '/Users/${account.userId}/Views',
      token: account.accessToken,
      query: <String, dynamic>{'IncludeExternalContent': true},
    );
    return _readItems(response);
  }

  Future<List<MediaItem>> getResumeItems(ServerAccount account) async {
    final response = await _getMap(
      account.serverUrl,
      '/Users/${account.userId}/Items/Resume',
      token: account.accessToken,
      query: <String, dynamic>{'Limit': 20, 'Fields': _itemFields},
    );
    return _readItems(response);
  }

  Future<List<MediaItem>> getLatestItems(
    ServerAccount account, {
    String? parentId,
  }) async {
    final response = await _getList(
      account.serverUrl,
      '/Users/${account.userId}/Items/Latest',
      token: account.accessToken,
      query: <String, dynamic>{
        'Limit': 24,
        'ParentId': parentId,
        'Fields': _itemFields,
      },
    );
    return response.map(MediaItem.fromJson).toList();
  }

  Future<List<MediaItem>> getLatestEpisodes(ServerAccount account) async {
    final response = await _getMap(
      account.serverUrl,
      '/Users/${account.userId}/Items',
      token: account.accessToken,
      query: <String, dynamic>{
        'Recursive': true,
        'Limit': 12,
        'IncludeItemTypes': 'Episode',
        'SortBy': 'DateCreated',
        'SortOrder': 'Descending',
        'Fields': _itemFields,
      },
    );
    return _readItems(response);
  }

  Future<List<MediaItem>> getLatestMovies(ServerAccount account) async {
    final response = await _getMap(
      account.serverUrl,
      '/Users/${account.userId}/Items',
      token: account.accessToken,
      query: <String, dynamic>{
        'Recursive': true,
        'Limit': 16,
        'IncludeItemTypes': 'Movie',
        'SortBy': 'DateCreated',
        'SortOrder': 'Descending',
        'Fields': _itemFields,
      },
    );
    return _readItems(response);
  }

  Future<List<MediaItem>> getLatestShows(ServerAccount account) async {
    final response = await _getMap(
      account.serverUrl,
      '/Users/${account.userId}/Items',
      token: account.accessToken,
      query: <String, dynamic>{
        'Recursive': true,
        'Limit': 16,
        'IncludeItemTypes': 'Series',
        'SortBy': 'DateCreated',
        'SortOrder': 'Descending',
        'Fields': _itemFields,
      },
    );
    return _readItems(response);
  }

  Future<List<MediaItem>> getRecentlyPlayed(ServerAccount account) async {
    final response = await _getMap(
      account.serverUrl,
      '/Users/${account.userId}/Items',
      token: account.accessToken,
      query: <String, dynamic>{
        'Recursive': true,
        'Limit': 16,
        'Filters': 'IsPlayed',
        'SortBy': 'DatePlayed',
        'SortOrder': 'Descending',
        'Fields': _itemFields,
      },
    );
    return _readItems(response);
  }

  Future<List<MediaItem>> getNextUp(ServerAccount account) async {
    final response = await _getMap(
      account.serverUrl,
      '/Shows/NextUp',
      token: account.accessToken,
      query: <String, dynamic>{
        'UserId': account.userId,
        'Limit': 12,
        'Fields': _itemFields,
      },
    );
    return _readItems(response);
  }

  Future<List<MediaItem>> getFavoriteItems(ServerAccount account) async {
    final response = await _getMap(
      account.serverUrl,
      '/Users/${account.userId}/Items',
      token: account.accessToken,
      query: <String, dynamic>{
        'Recursive': true,
        'Filters': 'IsFavorite',
        'Limit': 20,
        'Fields': _itemFields,
      },
    );
    return _readItems(response);
  }

  Future<List<MediaItem>> getLibraryItems(
    ServerAccount account, {
    String? parentId,
    String? searchTerm,
  }) async {
    final response = await _getMap(
      account.serverUrl,
      '/Users/${account.userId}/Items',
      token: account.accessToken,
      query: <String, dynamic>{
        'ParentId': parentId,
        'Recursive': parentId != null,
        'SearchTerm': searchTerm,
        'SortBy': 'SortName',
        'SortOrder': 'Ascending',
        'Fields': _itemFields,
        'Limit': 100,
      },
    );
    return _readItems(response);
  }

  Future<SearchResults> search(ServerAccount account, String query) async {
    final searchTerm = query.trim();
    if (searchTerm.isEmpty) {
      return const SearchResults(
        movies: <MediaItem>[],
        series: <MediaItem>[],
        episodes: <MediaItem>[],
        people: <MediaItem>[],
        other: <MediaItem>[],
      );
    }

    final results = <MediaItem>[];
    final searchQuery = <String, dynamic>{
      'SearchTerm': searchTerm,
      'Recursive': true,
      'Limit': 50,
      'EnableUserData': true,
      'Fields': _itemFields,
    };

    final typedResponse = await _getMap(
      account.serverUrl,
      '/Users/${account.userId}/Items',
      token: account.accessToken,
      query: searchQuery,
    );
    var typedItems = _readItems(typedResponse);
    if (kDebugMode) {
      debugPrint(
        'Nextfin search: /Users/${account.userId}/Items searchTerm="$searchTerm" returned ${typedItems.length} raw items',
      );
    }
    if (typedItems.isEmpty) {
      final fallbackResponse = await _getMap(
        account.serverUrl,
        '/Items',
        token: account.accessToken,
        query: <String, dynamic>{...searchQuery, 'UserId': account.userId},
      ).catchError((Object _) => <String, dynamic>{});
      typedItems = _readItems(fallbackResponse);
      if (kDebugMode) {
        debugPrint(
          'Nextfin search fallback: /Items searchTerm="$searchTerm" returned ${typedItems.length} raw items',
        );
      }
    }
    results.addAll(typedItems);

    if (account.capabilities.supportsSearchHints) {
      final hintResponse = await _getMap(
        account.serverUrl,
        '/Search/Hints',
        token: account.accessToken,
        query: <String, dynamic>{
          'SearchTerm': searchTerm,
          'UserId': account.userId,
          'IncludeItemTypes': 'Movie,Series,Episode,Season,BoxSet',
          'Limit': 24,
        },
      ).catchError((Object _) => <String, dynamic>{});
      final hints = _readSearchHints(hintResponse);
      if (kDebugMode) {
        debugPrint(
          'Nextfin search hints: searchTerm="$searchTerm" returned ${hints.length} hints',
        );
      }
      results.addAll(hints);
    }

    final peopleResponse = await _getMap(
      account.serverUrl,
      '/Persons',
      token: account.accessToken,
      query: <String, dynamic>{
        'SearchTerm': searchTerm,
        'UserId': account.userId,
        'Recursive': true,
        'Limit': 12,
        'Fields': _itemFields,
      },
    ).catchError((Object _) => <String, dynamic>{});
    final people = _readItems(peopleResponse);
    if (kDebugMode) {
      debugPrint(
        'Nextfin people search: searchTerm="$searchTerm" returned ${people.length} people/items',
      );
    }
    results.addAll(people);

    final deduped = <String, MediaItem>{};
    for (final item in results) {
      if (item.id.isEmpty) continue;
      deduped[item.id] = item;
    }

    final all = deduped.values.toList();
    if (kDebugMode) {
      debugPrint(
        'Nextfin search: searchTerm="$searchTerm" displaying ${all.length} unique items',
      );
    }
    all.sort((MediaItem a, MediaItem b) {
      final scoreA = _searchRank(a.type);
      final scoreB = _searchRank(b.type);
      if (scoreA != scoreB) return scoreA.compareTo(scoreB);
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return SearchResults(
      movies: all.where((MediaItem item) => item.type == 'Movie').toList(),
      series: all.where((MediaItem item) => item.type == 'Series').toList(),
      episodes: all.where((MediaItem item) => item.type == 'Episode').toList(),
      people: all.where((MediaItem item) => item.type == 'Person').toList(),
      other:
          all
              .where(
                (MediaItem item) =>
                    !<String>{
                      'Movie',
                      'Series',
                      'Episode',
                      'Person',
                    }.contains(item.type),
              )
              .toList(),
    );
  }

  Future<MediaItem> getItem(ServerAccount account, String itemId) async {
    final response = await _getMap(
      account.serverUrl,
      '/Users/${account.userId}/Items/$itemId',
      token: account.accessToken,
      query: <String, dynamic>{'Fields': _itemFields},
    );
    return MediaItem.fromJson(response);
  }

  Future<List<MediaItem>> getChildren(
    ServerAccount account,
    String parentId,
  ) async {
    final response = await _getMap(
      account.serverUrl,
      '/Users/${account.userId}/Items',
      token: account.accessToken,
      query: <String, dynamic>{
        'ParentId': parentId,
        'Fields': _itemFields,
        'SortBy': 'ParentIndexNumber,IndexNumber,SortName',
        'SortOrder': 'Ascending',
      },
    );
    return _readItems(response);
  }

  Future<PlaybackInfo> getPlaybackInfo(
    ServerAccount account,
    String itemId,
  ) async {
    final fallbackUrl = masterStreamUrl(account, itemId);
    if (kDebugMode) {
      debugPrint(
        'Nextfin playback: item=$itemId playback info request started',
      );
    }
    if (!account.capabilities.supportsPlaybackInfo) {
      if (kDebugMode) {
        debugPrint(
          'Nextfin playback: item=$itemId PlaybackInfo unsupported, using fallback stream URL',
        );
      }
      return PlaybackInfo.fromJson(
        <String, dynamic>{},
        fallbackUrl: fallbackUrl,
      );
    }
    final response = await _dio.post<Map<String, dynamic>>(
      '${account.serverUrl}/Items/$itemId/PlaybackInfo',
      queryParameters: <String, dynamic>{'UserId': account.userId},
      data: <String, dynamic>{
        'UserId': account.userId,
        'AutoOpenLiveStream': true,
        'EnableDirectPlay': true,
        'EnableDirectStream': true,
        'EnableTranscoding': true,
        'DeviceProfile': <String, dynamic>{
          'Name': 'Nextfin',
          'MaxStreamingBitrate': 120000000,
          'DirectPlayProfiles': <Map<String, dynamic>>[
            <String, dynamic>{'Type': 'Video'},
            <String, dynamic>{'Type': 'Audio'},
          ],
          'TranscodingProfiles': <Map<String, dynamic>>[
            <String, dynamic>{
              'Type': 'Video',
              'Container': 'mp4',
              'Protocol': 'http',
              'VideoCodec': 'h264,hevc,av1',
              'AudioCodec': 'aac,mp3,ac3,eac3',
              'MaxAudioChannels': '6',
            },
            <String, dynamic>{
              'Type': 'Video',
              'Container': 'ts',
              'Protocol': 'hls',
              'VideoCodec': 'h264,hevc,av1',
              'AudioCodec': 'aac,mp3,ac3,eac3',
              'MaxAudioChannels': '6',
            },
          ],
        },
      },
      options: Options(headers: _headers(account.accessToken)),
    );
    if (response.statusCode == 401) {
      throw const AuthenticationException('Session expired. Sign in again.');
    }
    if (response.statusCode != 200 || response.data == null) {
      throw NetworkException(
        'Could not get playback info from the server.',
        code: '${response.statusCode}',
      );
    }
    if (kDebugMode) {
      debugPrint(
        'Nextfin playback: item=$itemId playback info response status ${response.statusCode}',
      );
    }
    final info = PlaybackInfo.fromJson(
      response.data ?? <String, dynamic>{},
      fallbackUrl: fallbackUrl,
    );
    if (kDebugMode) {
      debugPrint(
        'Nextfin playback: item=$itemId parsed ${info.mediaSources.length} media source(s)',
      );
      for (final source in info.mediaSources) {
        debugPrint(
          'Nextfin playback: source id=${source.id} container=${source.container} protocol=${source.protocol} directPlay=${source.supportsDirectPlay} directStream=${source.supportsDirectStream} transcode=${source.supportsTranscoding}',
        );
      }
    }
    return info;
  }

  String masterStreamUrl(
    ServerAccount account,
    String itemId, {
    String? mediaSourceId,
    String? playSessionId,
    int? audioStreamIndex,
    int? subtitleStreamIndex,
  }) {
    return Uri.parse('${account.serverUrl}/Videos/$itemId/master.m3u8')
        .replace(
          queryParameters: <String, dynamic>{
            'api_key': account.accessToken,
            'deviceId': _deviceId,
            'UserId': account.userId,
            if (mediaSourceId != null && mediaSourceId.isNotEmpty)
              'MediaSourceId': mediaSourceId,
            if (playSessionId != null && playSessionId.isNotEmpty)
              'PlaySessionId': playSessionId,
            if (audioStreamIndex != null)
              'AudioStreamIndex': audioStreamIndex.toString(),
            if (subtitleStreamIndex != null)
              'SubtitleStreamIndex': subtitleStreamIndex.toString(),
          },
        )
        .toString();
  }

  List<PlaybackCandidate> playbackCandidates(
    ServerAccount account,
    String itemId, {
    required PlaybackInfo playbackInfo,
    int? audioStreamIndex,
    int? subtitleStreamIndex,
  }) {
    final candidates = <PlaybackCandidate>[];
    final seen = <String>{};
    final sources =
        playbackInfo.mediaSources.isEmpty
            ? <PlaybackMediaSource?>[null]
            : (List<PlaybackMediaSource>.from(playbackInfo.mediaSources)
              ..sort(_playbackSourcePriority));

    void addCandidate({
      required String url,
      required String kind,
      PlaybackMediaSource? source,
    }) {
      if (url.isEmpty || !seen.add(url)) return;
      candidates.add(PlaybackCandidate(url: url, kind: kind, source: source));
    }

    for (final source in sources) {
      final transcodingUrl = source?.transcodingUrl;
      if (source?.supportsTranscoding == true &&
          transcodingUrl != null &&
          transcodingUrl.isNotEmpty) {
        addCandidate(
          url: _resolvePlaybackUrl(account, transcodingUrl),
          kind: 'transcode',
          source: source,
        );
      }
      final sourceDirectStreamUrl = source?.directStreamUrl;
      if (source?.supportsDirectStream == true &&
          sourceDirectStreamUrl != null &&
          sourceDirectStreamUrl.isNotEmpty) {
        addCandidate(
          url: _resolvePlaybackUrl(account, sourceDirectStreamUrl),
          kind: 'direct',
          source: source,
        );
      }
      addCandidate(
        url: directStreamUrl(account, itemId, mediaSourceId: source?.id),
        kind: source == null ? 'fallback-direct' : 'direct-endpoint',
        source: source,
      );
      if (source == null) {
        addCandidate(
          url: masterStreamUrl(
            account,
            itemId,
            mediaSourceId: source?.id,
            playSessionId: playbackInfo.playSessionId,
            audioStreamIndex: audioStreamIndex,
            subtitleStreamIndex: subtitleStreamIndex,
          ),
          kind: 'master',
          source: source,
        );
      }
    }

    return candidates;
  }

  Future<String?> loadSubtitleFile({
    required ServerAccount account,
    required String itemId,
    required String mediaSourceId,
    required MediaStreamInfo stream,
  }) async {
    final streamUrl =
        (stream.deliveryUrl != null && stream.deliveryUrl!.isNotEmpty)
            ? _resolvePlaybackUrl(account, stream.deliveryUrl!)
            : Uri.parse(
                  '${account.serverUrl}/Videos/$itemId/$mediaSourceId/Subtitles/${stream.index}/Stream.vtt',
                )
                .replace(
                  queryParameters: <String, dynamic>{
                    'api_key': account.accessToken,
                  },
                )
                .toString();
    final response = await _dio.get<String>(
      streamUrl,
      options: Options(
        responseType: ResponseType.plain,
        headers: _headers(account.accessToken),
      ),
    );
    return response.data;
  }

  String directStreamUrl(
    ServerAccount account,
    String itemId, {
    String? mediaSourceId,
  }) {
    final uri = Uri.parse('${account.serverUrl}/Videos/$itemId/stream').replace(
      queryParameters: <String, dynamic>{
        'static': 'true',
        'api_key': account.accessToken,
        'deviceId': _deviceId,
        'UserId': account.userId,
        if (mediaSourceId != null && mediaSourceId.isNotEmpty)
          'MediaSourceId': mediaSourceId,
      },
    );
    return uri.toString();
  }

  Map<String, String> playerHeaders(ServerAccount account) => <String, String>{
    'X-Emby-Token': account.accessToken,
  };

  Future<PlaybackUrlPreview> previewPlaybackUrl(
    ServerAccount account,
    String url, {
    required bool expectText,
  }) async {
    final response = await _dio.getUri<dynamic>(
      Uri.parse(url),
      options: Options(
        headers: <String, dynamic>{
          ...playerHeaders(account),
          if (!expectText) 'Range': 'bytes=0-1023',
        },
        followRedirects: false,
        maxRedirects: 0,
        validateStatus: (int? status) => status != null && status < 600,
        responseType: expectText ? ResponseType.plain : ResponseType.stream,
        sendTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ),
    );
    if (!expectText) {
      await (response.data as ResponseBody?)?.stream.listen((_) {}).cancel();
    }
    return PlaybackUrlPreview(
      statusCode: response.statusCode ?? 0,
      contentType: response.headers.value(Headers.contentTypeHeader),
      body: expectText ? response.data?.toString() : null,
    );
  }

  Future<int> probePlaybackUrl(ServerAccount account, String url) async {
    try {
      final response = await _dio.headUri<void>(
        Uri.parse(url),
        options: Options(
          headers: playerHeaders(account),
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );
      return response.statusCode ?? 0;
    } on DioException catch (_) {
      return 200;
    }
  }

  String imageUrl(
    ServerAccount account,
    String itemId, {
    String imageType = 'Primary',
    String? tag,
    int? maxWidth,
  }) {
    return Uri.parse('${account.serverUrl}/Items/$itemId/Images/$imageType')
        .replace(
          queryParameters: <String, dynamic>{
            if (tag != null) 'tag': tag,
            if (maxWidth != null) 'maxWidth': maxWidth.toString(),
            'quality': '90',
          },
        )
        .toString();
  }

  Future<void> toggleFavorite(
    ServerAccount account,
    String itemId,
    bool isFavorite,
  ) async {
    final method = isFavorite ? _dio.delete<void> : _dio.post<void>;
    await method(
      '${account.serverUrl}/Users/${account.userId}/FavoriteItems/$itemId',
      options: Options(headers: _headers(account.accessToken)),
    );
  }

  Future<void> setPlayed(
    ServerAccount account,
    String itemId,
    bool played,
  ) async {
    final uri =
        '${account.serverUrl}/Users/${account.userId}/${played ? 'PlayedItems' : 'UnplayedItems'}/$itemId';
    await _dio.post<void>(
      uri,
      options: Options(headers: _headers(account.accessToken)),
    );
  }

  Future<void> reportProgress({
    required ServerAccount account,
    required String itemId,
    required Duration position,
    required bool paused,
    String? playSessionId,
  }) async {
    await _dio.post<void>(
      '${account.serverUrl}/Sessions/Playing/Progress',
      data: <String, dynamic>{
        'ItemId': itemId,
        'PositionTicks': position.inMicroseconds * 10,
        'IsPaused': paused,
        'CanSeek': true,
        if (playSessionId != null) 'PlaySessionId': playSessionId,
      },
      options: Options(headers: _headers(account.accessToken)),
    );
  }

  Future<void> reportStopped({
    required ServerAccount account,
    required String itemId,
    required Duration position,
    String? playSessionId,
  }) async {
    await _dio.post<void>(
      '${account.serverUrl}/Sessions/Playing/Stopped',
      data: <String, dynamic>{
        'ItemId': itemId,
        'PositionTicks': position.inMicroseconds * 10,
        if (playSessionId != null) 'PlaySessionId': playSessionId,
      },
      options: Options(headers: _headers(account.accessToken)),
    );
  }

  int _searchRank(String type) => switch (type) {
    'Movie' => 0,
    'Series' => 1,
    'Episode' => 2,
    'Person' => 3,
    _ => 4,
  };

  Future<Map<String, bool>> _probeEndpoints(
    String baseUrl,
    String token,
    String userId,
  ) async {
    final checks = <String, String>{
      'Shows/NextUp': '/Shows/NextUp?UserId=$userId&Limit=1',
      'Items/PlaybackInfo':
          '/Items/00000000000000000000000000000000/PlaybackInfo?UserId=$userId',
      'Users/Views': '/Users/$userId/Views',
      'Search/Hints': '/Search/Hints?SearchTerm=test&UserId=$userId&Limit=1',
      'Items/InstantMix': '/Items/InstantMix?UserId=$userId&Limit=1',
    };

    final entries = await Future.wait<MapEntry<String, bool>>(
      checks.entries.map((MapEntry<String, String> entry) async {
        try {
          final response = await _dio.get<void>(
            '$baseUrl${entry.value}',
            options: Options(headers: _headers(token)),
          );
          final status = response.statusCode ?? 0;
          final available =
              status == 200 || status == 204 || status == 400 || status == 404;
          return MapEntry<String, bool>(entry.key, available && status != 404);
        } on DioException catch (_) {
          return MapEntry<String, bool>(entry.key, false);
        }
      }),
    );
    return Map<String, bool>.fromEntries(entries);
  }

  Future<Map<String, dynamic>> _getMap(
    String baseUrl,
    String path, {
    String? token,
    Map<String, dynamic>? query,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$baseUrl$path',
        queryParameters: query,
        options: Options(
          headers:
              token == null
                  ? <String, dynamic>{'X-Emby-Authorization': _authHeader()}
                  : _headers(token),
        ),
      );
      if (response.statusCode == 401) {
        throw const AuthenticationException('Session expired. Sign in again.');
      }
      if (response.statusCode != 200 || response.data == null) {
        throw NetworkException(
          'Request failed for $path',
          code: '${response.statusCode}',
        );
      }
      return response.data!;
    } on DioException catch (error) {
      throw _mapDioError(error);
    } on SocketException catch (error) {
      throw NetworkException('Could not reach the server.', details: error);
    }
  }

  Future<List<Map<String, dynamic>>> _getList(
    String baseUrl,
    String path, {
    String? token,
    Map<String, dynamic>? query,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '$baseUrl$path',
        queryParameters: query,
        options: Options(headers: _headers(token ?? '')),
      );
      final data = response.data ?? <dynamic>[];
      return data.whereType<Map<String, dynamic>>().toList();
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  List<MediaItem> _readItems(Map<String, dynamic> data) {
    final items =
        data['Items'] as List<dynamic>? ??
        data['items'] as List<dynamic>? ??
        <dynamic>[];
    return items
        .whereType<Map<String, dynamic>>()
        .map(MediaItem.fromJson)
        .toList();
  }

  List<MediaItem> _readSearchHints(Map<String, dynamic> data) {
    final hints = data['SearchHints'] as List<dynamic>? ?? <dynamic>[];
    return hints.whereType<Map<String, dynamic>>().map((hint) {
      final normalized = <String, dynamic>{
        ...hint,
        'Id': hint['Id'] ?? hint['ItemId'],
        'Type': hint['Type'] ?? hint['ItemType'],
      };
      return MediaItem.fromJson(normalized);
    }).toList();
  }

  AppException _mapDioError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return const NetworkException('The server timed out. Try again.');
    }
    if (error.response?.statusCode == 401) {
      return const AuthenticationException('Authentication failed.');
    }
    if (error.response?.statusCode == 404) {
      return const CompatibilityException(
        'This endpoint is unavailable on the server.',
      );
    }
    if (error.error is HandshakeException) {
      return const NetworkException(
        'TLS handshake failed. If the server uses a self-signed certificate, platform trust settings may block it.',
      );
    }
    return NetworkException(
      'Network request failed.',
      code: error.response?.statusCode?.toString(),
      details: error.message,
    );
  }

  Map<String, dynamic> _headers(String token) => <String, dynamic>{
    'X-Emby-Authorization': _authHeader(token: token),
    if (token.isNotEmpty) 'X-Emby-Token': token,
  };

  String _authHeader({String? token}) =>
      'MediaBrowser Client="$_clientName", Device="$_deviceName", DeviceId="$_deviceId", Version="$_version"${token == null ? '' : ', Token="$token"'}';

  String _resolvePlaybackUrl(ServerAccount account, String url) {
    final resolved = Uri.parse(account.serverUrl).resolve(url);
    final query = Map<String, String>.from(resolved.queryParameters);
    query.putIfAbsent('api_key', () => account.accessToken);
    query.putIfAbsent('deviceId', () => _deviceId);
    query.putIfAbsent('UserId', () => account.userId);
    return resolved.replace(queryParameters: query).toString();
  }

  static const String _itemFields =
      'Overview,Genres,PrimaryImageAspectRatio,Path,BackdropImageTags,ParentBackdropImageTags,PrimaryImageTag,ChildCount,CommunityRating,CriticRating,RunTimeTicks,MediaSources';

  String resolvePlaybackReference(
    ServerAccount account,
    String baseUrl,
    String reference,
  ) {
    final resolved = Uri.parse(baseUrl).resolve(reference);
    final query = Map<String, String>.from(resolved.queryParameters);
    query.putIfAbsent('api_key', () => account.accessToken);
    query.putIfAbsent('deviceId', () => _deviceId);
    query.putIfAbsent('UserId', () => account.userId);
    return resolved.replace(queryParameters: query).toString();
  }

  int _playbackSourcePriority(PlaybackMediaSource? a, PlaybackMediaSource? b) {
    if (a == null || b == null) return 0;
    final scoreA = _playbackSourceScore(a);
    final scoreB = _playbackSourceScore(b);
    return scoreB.compareTo(scoreA);
  }

  int _playbackSourceScore(PlaybackMediaSource source) {
    var score = 0;
    if (source.supportsTranscoding &&
        source.transcodingUrl?.isNotEmpty == true) {
      score += 50;
    }
    if (source.transcodingUrl?.contains('.mp4') == true) score += 18;
    if (source.transcodingUrl?.contains('.m3u8') == true) score -= 8;
    if (source.protocol?.toLowerCase() == 'file') score += 5;
    if (source.supportsDirectPlay) score += 8;
    if (source.container case final String container) {
      if (<String>{
        'mp4',
        'm4v',
        'webm',
        'mkv',
      }.contains(container.toLowerCase())) {
        score += 10;
      }
    }
    return score;
  }
}

class PlaybackCandidate {
  const PlaybackCandidate({
    required this.url,
    required this.kind,
    required this.source,
  });

  final String url;
  final String kind;
  final PlaybackMediaSource? source;

  bool get isHls =>
      source?.protocol?.toLowerCase() == 'hls' || url.contains('.m3u8');
}
