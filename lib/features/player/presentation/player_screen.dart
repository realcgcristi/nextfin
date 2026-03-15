import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../core/networking/jellyfin_api.dart';
import '../../../core/storage/app_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/media_item.dart';
import '../../../shared/models/playback_info.dart';
import '../../../shared/models/server_account.dart';
import '../../auth/application/session_controller.dart';
import '../../home/presentation/home_screen.dart';

final playbackInfoProvider = FutureProvider.family<PlaybackBundle, String>((
  Ref ref,
  String itemId,
) async {
  final account = ref.watch(activeAccountProvider);
  if (account == null) throw Exception('No active session.');
  final api = ref.watch(jellyfinApiProvider);
  final sett = ref.watch(clientSettingsProvider);
  final info = await api.getPlaybackInfo(
    account,
    itemId,
    quality: sett.streamingQuality,
    pref: sett.playbackPreference,
  );
  return PlaybackBundle(account: account, info: info);
});

class PlaybackBundle {
  const PlaybackBundle({required this.account, required this.info});

  final ServerAccount account;
  final PlaybackInfo info;
}

enum PlaybackStartupStage {
  loadingPlaybackInfo,
  selectingSource,
  initializingPlayer,
  ready,
  error,
}

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({
    super.key,
    required this.itemId,
    required this.title,
    this.initialPositionTicks = 0,
    this.filePath,
  });

  final String itemId;
  final String title;
  final int initialPositionTicks;
  final String? filePath;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen>
    with WidgetsBindingObserver {
  static const MethodChannel _platform = MethodChannel('nextfin/player');
  VideoPlayerController? _controller;
  Timer? _progressTimer;
  Timer? _overlayTimer;
  Timer? _timelineTimer;
  Timer? _pipFeedbackTimer;
  bool _showControls = true;
  bool _initializing = false;
  String? _error;
  String? _subtitleMessage;
  int? _selectedAudioIndex;
  int? _selectedSubtitleIndex;
  PlaybackBundle? _bundle;
  PlaybackMediaSource? _activeSource;
  PlaybackStartupStage _stage = PlaybackStartupStage.loadingPlaybackInfo;
  String _stageMessage = 'Contacting your Jellyfin server...';
  bool? _lastBuffering;
  bool? _lastPlaying;
  String? _lastAttemptKey;
  bool _isFullscreen = false;
  bool _isInPip = false;
  Duration? _pendingSeek;
  bool _pendingAutoPlay = true;
  bool _exitHandled = false;
  DateTime? _lastLiveEdgeSeek;
  MediaItem? _itemMeta;
  MediaItem? _nextUp;
  List<MediaItem> _liveSwitchItems = const <MediaItem>[];
  bool _loadingLiveSwitch = false;
  Timer? _nextUpTimer;
  int _nextUpCountdown = 5;
  bool _nextUpCancelled = false;

  bool get _isLive =>
      _activeSource?.isLiveTvLike == true || _bundle?.info.primaryMediaSource?.isLiveTvLike == true;
  bool get _isLocalFile => widget.filePath?.isNotEmpty == true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _platform.setMethodCallHandler(_handlePlatformCall);
    unawaited(_setPlayerScreenActive(true));
    unawaited(_applyOrientationPref());
  }

  @override
  void dispose() {
    _overlayTimer?.cancel();
    _progressTimer?.cancel();
    _timelineTimer?.cancel();
    _pipFeedbackTimer?.cancel();
    _nextUpTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (!_exitHandled) {
      unawaited(_handleExit());
    }
    super.dispose();
  }

  Future<void> _disposeController({required bool reportStop}) async {
    final controller = _controller;
    final bundle = _bundle;
    final isLive = _isLive;
    _controller = null;
    if (controller != null) {
      await controller.pause();
      if (reportStop && !isLive) {
        final duration = controller.value.duration;
        final position = controller.value.position;
        final finished =
            duration.inMilliseconds > 0 &&
            position.inMilliseconds >= (duration.inMilliseconds * 0.92).round();
        if (bundle != null) {
          await ref
              .read(jellyfinApiProvider)
              .reportStopped(
                account: bundle.account,
                itemId: widget.itemId,
                position: position,
                playSessionId: bundle.info.playSessionId,
              );
          if (finished) {
            await ref
                .read(jellyfinApiProvider)
                .setPlayed(bundle.account, widget.itemId, true);
          }
        }
      }
      await controller.dispose();
    }
  }

  Future<void> _initializePlayer(PlaybackBundle bundle) async {
    if (_initializing) return;
    _lastAttemptKey = _attemptKey(bundle);
    setState(() {
      _initializing = true;
      _error = null;
      _subtitleMessage = null;
    });
    final api = ref.read(jellyfinApiProvider);

    try {
      if (_controller != null) {
        await _disposeController(reportStop: false);
      }
      _bundle = bundle;
      _itemMeta = null;
      _nextUp = null;
      _nextUpCancelled = false;
      _nextUpTimer?.cancel();
      _nextUpTimer = null;
      _primeTrackPrefs(bundle);
      unawaited(_loadItemCtx(bundle.account));
      _log('selected item id=${widget.itemId} title="${widget.title}"');
      _updateStage(
        PlaybackStartupStage.selectingSource,
        'Selecting the best stream for this device...',
      );
      final controller = await _buildController(bundle, api);
      _updateStage(PlaybackStartupStage.ready, 'Playback ready');
      final isLive = _activeSource?.isLiveTvLike == true;
      if (isLive) {
        await ref
            .read(sessionControllerProvider.notifier)
            .addRecentLiveChannel(widget.itemId);
        ref.invalidate(homeSectionsProvider);
      }
      final resumePosition =
          isLive ? Duration.zero : (_pendingSeek ?? _initialResumePosition);
      if (resumePosition > Duration.zero) {
        await controller.seekTo(resumePosition);
      }
      if (_pendingAutoPlay) {
        await controller.play();
      } else {
        await controller.pause();
      }
      controller.addListener(_handlePlaybackTick);
      await _syncAndroidPlaybackState();
      _refreshTimelineTicker(force: true);

      _progressTimer?.cancel();
      if (!isLive) {
        _progressTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
          final value = controller.value;
          if (!value.isInitialized || bundle.info.playSessionId == null) return;
          await ref
              .read(jellyfinApiProvider)
              .reportProgress(
                account: bundle.account,
                itemId: widget.itemId,
                position: value.position,
                paused: !value.isPlaying,
                playSessionId: bundle.info.playSessionId,
              );
        });
      }

      if (mounted) {
        setState(() => _controller = controller);
        _armOverlayTimer();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _stage = PlaybackStartupStage.error;
          _stageMessage = 'Playback startup failed.';
          _error =
              'Could not start playback. ${error.toString().replaceFirst('Exception: ', '')}';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _initializing = false);
      } else {
        _initializing = false;
      }
    }
  }

  Future<void> _initializeLocalPlayer() async {
    if (_initializing) return;
    setState(() {
      _initializing = true;
      _error = null;
      _subtitleMessage = null;
    });
    try {
      if (_controller != null) {
        await _disposeController(reportStop: false);
      }
      _updateStage(
        PlaybackStartupStage.initializingPlayer,
        'Opening your downloaded file...',
      );
      final ctrl = VideoPlayerController.file(File(widget.filePath!));
      await ctrl.initialize();
      if (!ctrl.value.isInitialized) {
        throw Exception('Video player did not enter a ready state.');
      }
      await ctrl.play();
      ctrl.addListener(_handlePlaybackTick);
      if (mounted) {
        setState(() {
          _controller = ctrl;
          _stage = PlaybackStartupStage.ready;
        });
        _armOverlayTimer();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _stage = PlaybackStartupStage.error;
          _error =
              'Could not start playback. ${error.toString().replaceFirst('Exception: ', '')}';
        });
      }
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  Future<void> _handleExit() async {
    if (_exitHandled) return;
    _exitHandled = true;
    _overlayTimer?.cancel();
    _progressTimer?.cancel();
    _timelineTimer?.cancel();
    _pipFeedbackTimer?.cancel();
    _nextUpTimer?.cancel();
    await _setPlayerScreenActive(false);
    await _clearAndroidPlaybackState();
    final controller = _controller;
    if (controller != null) {
      controller.removeListener(_handlePlaybackTick);
      if (controller.value.isPlaying) {
        await controller.pause();
      }
      await _disposeController(reportStop: true);
    }
    await _restoreWindowMode();
  }

  Future<VideoPlayerController> _buildController(
    PlaybackBundle bundle,
    JellyfinApi api,
  ) async {
    final candidates = api.playbackCandidates(
      bundle.account,
      widget.itemId,
      playbackInfo: bundle.info,
      pref: ref.read(clientSettingsProvider).playbackPreference,
      audioStreamIndex: _selectedAudioIndex,
      subtitleStreamIndex: _selectedSubtitleIndex,
    );
    Object? lastError;
    if (candidates.isEmpty) {
      throw Exception('No playable media source found.');
    }
    for (final candidate in candidates) {
      VideoPlayerController? controller;
      try {
        _activeSource = candidate.source;
        _updateStage(
          PlaybackStartupStage.selectingSource,
          'Preparing ${candidate.kind} stream...',
        );
        _log(
          'selected media source id=${candidate.source?.id ?? 'fallback'} container=${candidate.source?.container ?? 'unknown'} protocol=${candidate.source?.protocol ?? 'unknown'} kind=${candidate.kind} live=${candidate.isLive}',
        );
        _log('final stream URL=${candidate.url}');
        _log('auth token present=${bundle.account.accessToken.isNotEmpty}');
        _updateStage(
          PlaybackStartupStage.initializingPlayer,
          'Initializing the video player...',
        );
        controller = VideoPlayerController.networkUrl(
          Uri.parse(candidate.url),
          httpHeaders: <String, String>{
            ...api.playerHeaders(bundle.account),
            ...candidate.headers,
          },
          formatHint: candidate.isHls ? VideoFormat.hls : null,
        );
        _log('player controller initialize() started');
        await controller.initialize().timeout(
          const Duration(seconds: 18),
          onTimeout: () {
            throw TimeoutException('Playback initialization timed out.');
          },
        );
        if (!controller.value.isInitialized) {
          throw Exception('Video player did not enter a ready state.');
        }
        _log('player controller initialize() completed');
        if (candidate.isLive && controller.value.duration > Duration.zero) {
          final dur = controller.value.duration;
          final pos = controller.value.position;
          if (dur > const Duration(seconds: 30) &&
              pos + const Duration(seconds: 4) < dur) {
            _lastLiveEdgeSeek = DateTime.now();
            unawaited(
              controller.seekTo(
                dur > const Duration(seconds: 1)
                    ? dur - const Duration(seconds: 1)
                    : dur,
              ),
            );
          }
        }
        await _applySubtitles(api, bundle, controller);
        _log(
          'player ready duration=${controller.value.duration} size=${controller.value.size}',
        );
        return controller;
      } catch (error) {
        await controller?.dispose();
        _log('player startup candidate failed: $error');
        lastError = await _diagnosePlaybackFailure(
          api: api,
          bundle: bundle,
          candidate: candidate,
          error: error,
        );
      }
    }
    throw lastError ??
        Exception('No playable stream was returned by the server.');
  }

  Future<Object> _diagnosePlaybackFailure({
    required JellyfinApi api,
    required PlaybackBundle bundle,
    required PlaybackCandidate candidate,
    required Object error,
  }) async {
    try {
      final preview = await api.previewPlaybackUrl(
        bundle.account,
        candidate.url,
        expectText: candidate.isHls,
        extraHeaders: candidate.headers,
      );
      _log(
        'stream preview after failure status=${preview.statusCode} contentType=${preview.contentType}',
      );
      if (preview.statusCode == 401 || preview.statusCode == 403) {
        return Exception('The media request was rejected by the server.');
      }
      if (preview.statusCode == 404) {
        return Exception('The server did not return a playable stream.');
      }
      if (candidate.isLive && preview.statusCode == 500) {
        return Exception(
          'The live tv stream failed on the server (HTTP 500) at ${Uri.parse(candidate.url).path}.',
        );
      }
      if (preview.statusCode < 200 || preview.statusCode >= 400) {
        return Exception(
          'The media stream failed with HTTP ${preview.statusCode}.',
        );
      }
      if (candidate.isHls &&
          preview.body != null &&
          !preview.body!.contains('#EXTM3U')) {
        return Exception('The server returned an invalid HLS playlist.');
      }
    } catch (previewError) {
      _log('stream preview after failure also failed: $previewError');
    }
    if (candidate.isLive) {
      return Exception(
        'Could not create the live tv stream from ${Uri.parse(candidate.url).path}. ${error.toString().replaceFirst('Exception: ', '')}',
      );
    }
    return error;
  }

  Future<void> _applySubtitles(
    JellyfinApi api,
    PlaybackBundle bundle,
    VideoPlayerController controller,
  ) async {
    if (_selectedSubtitleIndex == null) {
      await _clearSubtitleTrack(controller);
      return;
    }
    final selectedSubtitle =
        (_activeSource?.subtitleStreams ?? bundle.info.subtitleStreams)
            .where(
              (MediaStreamInfo stream) =>
                  stream.index == _selectedSubtitleIndex,
            )
            .firstOrNull;
    if (selectedSubtitle == null) return;
    try {
      final mediaSourceId = _activeSource?.id;
      if (mediaSourceId == null || mediaSourceId.isEmpty) {
        if (mounted) {
          setState(() {
            _subtitleMessage =
                'Subtitles are unavailable for the selected playback source.';
          });
        }
        return;
      }
      final subtitleText = await api.loadSubtitleFile(
        account: bundle.account,
        itemId: widget.itemId,
        mediaSourceId: mediaSourceId,
        stream: selectedSubtitle,
      );
      if (subtitleText != null && subtitleText.trim().isNotEmpty) {
        await controller.setClosedCaptionFile(
          Future<ClosedCaptionFile>.value(
            WebVTTCaptionFile(_normalizeWebVtt(subtitleText)),
          ),
        );
        if (mounted) {
          setState(() => _subtitleMessage = null);
        }
      } else if (mounted) {
        setState(() {
          _subtitleMessage =
              'This subtitle track is unavailable in a supported format.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _subtitleMessage = 'Subtitles could not be attached for this stream.';
        });
      }
    }
  }

  Future<void> _clearSubtitleTrack(VideoPlayerController controller) async {
    await controller.setClosedCaptionFile(
      Future<ClosedCaptionFile>.value(WebVTTCaptionFile('WEBVTT\n\n')),
    );
    if (mounted) {
      setState(() => _subtitleMessage = null);
    }
  }

  void _handlePlaybackTick() {
    final controller = _controller;
    if (controller == null || !mounted) return;
    final value = controller.value;
    if (_lastBuffering != value.isBuffering) {
      _lastBuffering = value.isBuffering;
      _log('buffering state changed=${value.isBuffering}');
    }
    if (_lastPlaying != value.isPlaying) {
      _lastPlaying = value.isPlaying;
      _log('player state changed isPlaying=${value.isPlaying}');
      unawaited(_syncAndroidPlaybackState());
      _refreshTimelineTicker(force: true);
    }
    if (value.hasError) {
      _log('player reported error=${value.errorDescription}');
      setState(() {
        _error =
            'Video playback failed. ${value.errorDescription ?? 'The player reported an unknown error.'}';
        _stage = PlaybackStartupStage.error;
      });
      return;
    }
    if (_isLive && !value.isPlaying && !value.isBuffering && mounted) {
      unawaited(_controller?.play());
    }
    if (_isLive &&
        value.duration > Duration.zero &&
        value.position >= value.duration - const Duration(seconds: 2) &&
        (value.isPlaying || value.isBuffering == false)) {
      final now = DateTime.now();
      if (_lastLiveEdgeSeek == null ||
          now.difference(_lastLiveEdgeSeek!) > const Duration(seconds: 4)) {
        _lastLiveEdgeSeek = now;
        unawaited(controller.seekTo(value.duration));
      }
    }
    _handleEpisodeUx(value);
    if (controller.value.position >= controller.value.duration &&
        controller.value.duration > Duration.zero) {
      if (!_isLive) {
        setState(() => _showControls = true);
      }
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _armOverlayTimer();
  }

  void _armOverlayTimer() {
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && (_controller?.value.isPlaying ?? false)) {
        setState(() => _showControls = false);
      }
    });
  }

  void _refreshTimelineTicker({bool force = false}) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      _timelineTimer?.cancel();
      _timelineTimer = null;
      return;
    }
    if (!controller.value.isPlaying) {
      _timelineTimer?.cancel();
      _timelineTimer = null;
      if (force && mounted) {
        setState(() {});
      }
      return;
    }
    if (_timelineTimer != null && !force) return;
    _timelineTimer?.cancel();
    _timelineTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final active = _controller;
      if (active == null || !mounted) return;
      if (!active.value.isInitialized || !active.value.isPlaying) {
        _timelineTimer?.cancel();
        _timelineTimer = null;
        if (mounted) {
          setState(() {});
        }
        return;
      }
      setState(() {});
    });
  }

  Future<void> _loadItemCtx(ServerAccount account) async {
    try {
      final api = ref.read(jellyfinApiProvider);
      final item = await api.getItem(account, widget.itemId);
      MediaItem? next;
      if (item.type == 'Episode') {
        final nextUp = await api.getNextUp(account);
        next =
            nextUp
                .where(
                  (e) =>
                      e.id != item.id &&
                      ((item.seriesId?.isNotEmpty == true &&
                              e.seriesId == item.seriesId) ||
                          (item.seriesName?.isNotEmpty == true &&
                              e.seriesName == item.seriesName)),
                )
                .firstOrNull ??
            nextUp.where((e) => e.id != item.id).firstOrNull;
      }
      if (!mounted) return;
      setState(() {
        _itemMeta = item;
        _nextUp = next;
      });
    } catch (error) {
      _log('item context load failed: $error');
    }
  }

  bool get _showSkipIntro {
    final item = _itemMeta;
    final ctrl = _controller;
    if (item == null || ctrl == null) return false;
    final sett = ref.read(clientSettingsProvider);
    return !_isLive &&
        sett.skipIntroButton &&
        item.type == 'Episode' &&
        ctrl.value.isInitialized &&
        ctrl.value.position < const Duration(seconds: 95);
  }

  bool get _showNextUpCard =>
      !_isLive &&
      _itemMeta?.type == 'Episode' &&
      _nextUp != null &&
      !_nextUpCancelled &&
      _nextUpTimer != null;

  void _handleEpisodeUx(VideoPlayerValue value) {
    if (_isLive || _itemMeta?.type != 'Episode' || _nextUp == null) return;
    if (!value.isInitialized || value.duration <= Duration.zero) return;
    final remaining = value.duration - value.position;
    if (remaining <= const Duration(seconds: 75) &&
        remaining > Duration.zero &&
        value.isPlaying &&
        !_nextUpCancelled &&
        _nextUpTimer == null) {
      _nextUpCountdown = 5;
      _nextUpTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_nextUpCountdown <= 1) {
          timer.cancel();
          _nextUpTimer = null;
          await _playNextUp();
          return;
        }
        setState(() => _nextUpCountdown -= 1);
      });
      setState(() {});
    }
    if ((!value.isPlaying || remaining > const Duration(seconds: 80)) &&
        _nextUpTimer != null) {
      _nextUpTimer?.cancel();
      _nextUpTimer = null;
      if (mounted) setState(() {});
    }
  }

  Future<void> _playNextUp() async {
    final next = _nextUp;
    if (next == null || !mounted) return;
    await _handleExit();
    if (!mounted) return;
    context.pushReplacement(
      '/player/${next.id}?title=${Uri.encodeComponent(next.name)}&startTicks=0',
    );
  }

  Future<void> _skipIntro() async {
    final ctrl = _controller;
    if (ctrl == null) return;
    final target = const Duration(seconds: 90);
    final dur = ctrl.value.duration;
    final seekTo =
        dur > Duration.zero && target > dur ? dur : target;
    await ctrl.seekTo(seekTo);
    _armOverlayTimer();
    if (mounted) setState(() {});
  }

  Future<void> _showChannelSwitcher() async {
    final bundle = _bundle;
    if (!mounted || bundle == null || _loadingLiveSwitch) return;
    setState(() => _loadingLiveSwitch = true);
    try {
      final api = ref.read(jellyfinApiProvider);
      final session = ref.read(sessionControllerProvider);
      final channels = await api.getLiveTvChannels(bundle.account);
      if (!mounted) return;
      final byId = <String, MediaItem>{for (final item in channels) item.id: item};
      final favIds = session.favoriteLiveChannels;
      final recentIds = session.recentLiveChannels;
      final fav = favIds.map((id) => byId[id]).whereType<MediaItem>().toList();
      final recent = recentIds
          .where((id) => !favIds.contains(id))
          .map((id) => byId[id])
          .whereType<MediaItem>()
          .toList();
      final others = channels
          .where((item) => !favIds.contains(item.id) && !recentIds.contains(item.id))
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _liveSwitchItems = <MediaItem>[...fav, ...recent, ...others];
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'could not load channels ${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
      return;
    } finally {
      if (mounted) setState(() => _loadingLiveSwitch = false);
    }
    if (!mounted) return;
    final picked = await showModalBottomSheet<MediaItem>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final session = ref.read(sessionControllerProvider);
        final favIds = session.favoriteLiveChannels.toSet();
        final recentIds = session.recentLiveChannels.toSet();
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.74,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              itemCount: _liveSwitchItems.length + 1,
              itemBuilder: (context, idx) {
                if (idx == 0) {
                  return const ListTile(
                    title: Text('channels'),
                    subtitle: Text('favorites and recent channels stay near the top'),
                  );
                }
                final item = _liveSwitchItems[idx - 1];
                final isFav = favIds.contains(item.id);
                final isRecent = recentIds.contains(item.id);
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                  onTap: () => Navigator.of(context).pop(item),
                  leading: Icon(
                    isFav
                        ? Icons.favorite_rounded
                        : isRecent
                            ? Icons.history_rounded
                            : Icons.tv_rounded,
                  ),
                  title: Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    isFav
                        ? 'favorite channel'
                        : isRecent
                            ? 'recent channel'
                            : 'all channels',
                  ),
                );
              },
            ),
          ),
        );
      },
    );
    if (picked == null || !mounted || picked.id == widget.itemId) return;
    await _handleExit();
    if (!mounted) return;
    context.pushReplacement(
      '/player/${picked.id}?title=${Uri.encodeComponent(picked.name)}&startTicks=0',
    );
  }

  Future<void> _showInfoSheet() async {
    final src = _activeSource;
    final ctrl = _controller;
    if (src == null || ctrl == null) return;
    final video = src.mediaStreams.where((s) => s.type == 'Video').firstOrNull;
    final audio = src.mediaStreams.where((s) => s.type == 'Audio').firstOrNull;
    final size = ctrl.value.size;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
            children: <Widget>[
              const ListTile(title: Text('media info')),
              ListTile(
                title: const Text('video'),
                subtitle: Text(
                  '${size.width.round()}x${size.height.round()}  ·  ${video?.codec?.toUpperCase() ?? src.container?.toUpperCase() ?? 'unknown'}',
                ),
              ),
              ListTile(
                title: const Text('audio'),
                subtitle: Text(
                  audio?.codec?.toUpperCase() ?? '${src.audioStreams.length} track(s)',
                ),
              ),
              ListTile(
                title: const Text('stream'),
                subtitle: Text(
                  '${src.protocol?.toLowerCase() ?? 'unknown'}  ·  ${src.container?.toLowerCase() ?? 'unknown'}',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _seekRelative(Duration offset) async {
    final controller = _controller;
    if (controller == null) return;
    final target = controller.value.position + offset;
    final bounded =
        target < Duration.zero
            ? Duration.zero
            : (target > controller.value.duration
                ? controller.value.duration
                : target);
    await controller.seekTo(bounded);
    _armOverlayTimer();
  }

  Future<void> _showTrackPicker({
    required String title,
    required List<MediaStreamInfo> streams,
    required int? selected,
    required ValueChanged<int?> onSelected,
    bool allowOff = false,
    bool requiresReinitialize = false,
  }) async {
    final result = await showModalBottomSheet<int?>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              ListTile(title: Text(title)),
              if (allowOff)
                RadioListTile<int?>(
                  title: const Text('Off'),
                  value: null,
                  groupValue: selected,
                  onChanged: (int? value) => Navigator.of(context).pop(value),
                ),
              ...streams.map(
                (stream) => RadioListTile<int?>(
                  title: Text(stream.displayTitle),
                  subtitle:
                      stream.language == null ? null : Text(stream.language!),
                  value: stream.index,
                  groupValue: selected,
                  onChanged: (int? value) => Navigator.of(context).pop(value),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (result == selected || !mounted) return;
    final controller = _controller;
    if (controller != null &&
        controller.value.isInitialized &&
        requiresReinitialize) {
      _pendingSeek = controller.value.position;
      _pendingAutoPlay = controller.value.isPlaying;
    }
    onSelected(result);
    if (!requiresReinitialize && controller != null && _bundle != null) {
      await _applySubtitles(
        ref.read(jellyfinApiProvider),
        _bundle!,
        controller,
      );
      return;
    }
    if (_bundle != null) {
      await _initializePlayer(_bundle!);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null) return;
    final settings = ref.read(clientSettingsProvider);
    if (state == AppLifecycleState.paused &&
        !_isInPip &&
        !settings.backgroundPlayback) {
      unawaited(controller.pause());
      unawaited(_syncAndroidPlaybackState());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLocalFile) {
      final controller = _controller;
      if (!_initializing && controller == null && _error == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          unawaited(_initializeLocalPlayer());
        });
      }
      if (_error != null) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: _PlayerErrorState(
            title: widget.title,
            message: _error!,
            onRetry: () {
              setState(() {
                _error = null;
              });
              unawaited(_initializeLocalPlayer());
            },
          ),
        );
      }
      if (_initializing || controller == null || !controller.value.isInitialized) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: _PlayerLoadingState(
            title: widget.title,
            stage: PlaybackStartupStage.initializingPlayer,
            message: 'Opening your download...',
          ),
        );
      }
    }
    final playback = ref.watch(playbackInfoProvider(widget.itemId));
    if (_isLocalFile) {
      final controller = _controller!;
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, Object? _) async {
          if (didPop) return;
          await _handleExit();
          if (context.mounted) Navigator.of(context).pop();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
            onTap: _toggleControls,
            child: Stack(
              children: <Widget>[
                Center(
                  child: AspectRatio(
                    aspectRatio:
                        controller.value.aspectRatio == 0
                            ? 16 / 9
                            : controller.value.aspectRatio,
                    child: VideoPlayer(controller),
                  ),
                ),
                AnimatedOpacity(
                  opacity: _showControls ? 1 : 0,
                  duration: const Duration(milliseconds: 160),
                  child: IgnorePointer(
                    ignoring: !_showControls,
                    child: _PlayerOverlay(
                      title: widget.title,
                      controller: controller,
                      subtitleMessage: null,
                      subtitleCount: 0,
                      audioCount: 0,
                      isLive: false,
                      isFullscreen: _isFullscreen,
                      isInPip: _isInPip,
                      onBack: () async {
                        await _handleExit();
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      onPlayPause: () async {
                        if (controller.value.isPlaying) {
                          await controller.pause();
                        } else {
                          await controller.play();
                        }
                        setState(() {});
                      },
                      onRewind: () => _seekRelative(_seekStep * -1),
                      onForward: () => _seekRelative(_seekStep),
                      onSubtitle: () {},
                      onAudio: () {},
                      onFullscreen: _toggleFullscreen,
                      onPip: _enterPip,
                      onChannels: null,
                      onInfo: _showInfoSheet,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? _) async {
        if (didPop) return;
        await _handleExit();
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: playback.when(
          data: (bundle) {
            final attemptKey = _attemptKey(bundle);
            final shouldAutoInitialize =
                !_initializing &&
                _controller == null &&
                _lastAttemptKey != attemptKey &&
                _error == null;
            if (shouldAutoInitialize) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                unawaited(_initializePlayer(bundle));
              });
            }

            final controller = _controller;
            if (_error != null) {
              return _PlayerErrorState(
                title: widget.title,
                message: _error!,
                diagnostics:
                    ref.read(clientSettingsProvider).showDebugPlaybackInfo
                        ? 'Stage: ${_stage.name}\nMessage: $_stageMessage\nSource: ${_activeSource?.id ?? 'none'}'
                        : null,
                onRetry: () {
                  setState(() {
                    _error = null;
                    _lastAttemptKey = null;
                  });
                  unawaited(_initializePlayer(bundle));
                },
              );
            }
            if (_initializing ||
                controller == null ||
                !controller.value.isInitialized) {
              return _PlayerLoadingState(
                title: widget.title,
                stage: _stage,
                message: _stageMessage,
              );
            }

            return GestureDetector(
              onTap: _toggleControls,
              child: Stack(
                children: <Widget>[
                  Center(
                    child: AspectRatio(
                      aspectRatio:
                          controller.value.aspectRatio == 0
                              ? 16 / 9
                              : controller.value.aspectRatio,
                      child: VideoPlayer(controller),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 118),
                          child: ClosedCaption(
                            text: controller.value.caption.text,
                            textStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              shadows: <Shadow>[
                                Shadow(blurRadius: 8, color: Colors.black),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  AnimatedOpacity(
                    opacity: _showControls ? 1 : 0,
                    duration: const Duration(milliseconds: 160),
                    child: IgnorePointer(
                      ignoring: !_showControls,
                      child: _PlayerOverlay(
                        title: widget.title,
                        controller: controller,
                        subtitleMessage: _subtitleMessage,
                        subtitleCount:
                            (_activeSource?.subtitleStreams ??
                                    bundle.info.subtitleStreams)
                                .length,
                        audioCount:
                            (_activeSource?.audioStreams ??
                                    bundle.info.audioStreams)
                                .length,
                        onBack: () async {
                          await _handleExit();
                          if (context.mounted) Navigator.of(context).pop();
                        },
                        onPlayPause: () async {
                          if (controller.value.isPlaying) {
                            await controller.pause();
                          } else {
                            await controller.play();
                          }
                          setState(() {});
                          _armOverlayTimer();
                          await _syncAndroidPlaybackState();
                        },
                        isLive: _isLive,
                        isFullscreen: _isFullscreen,
                        isInPip: _isInPip,
                        onFullscreen: _toggleFullscreen,
                        onPip: _enterPip,
                        onRewind: () => _seekRelative(_seekStep * -1),
                        onForward: () => _seekRelative(_seekStep),
                        onSubtitle:
                            () => _showTrackPicker(
                              title: 'Subtitles',
                              streams:
                                  _activeSource?.subtitleStreams ??
                                  bundle.info.subtitleStreams,
                              selected: _selectedSubtitleIndex,
                              allowOff: true,
                              onSelected: (int? value) {
                                setState(() => _selectedSubtitleIndex = value);
                              },
                              requiresReinitialize: false,
                            ),
                        onAudio:
                            () => _showTrackPicker(
                              title: 'Audio tracks',
                              streams:
                                  _activeSource?.audioStreams ??
                                  bundle.info.audioStreams,
                              selected: _selectedAudioIndex,
                              onSelected: (int? value) {
                                setState(() => _selectedAudioIndex = value);
                              },
                              requiresReinitialize: true,
                            ),
                        onChannels: _isLive ? _showChannelSwitcher : null,
                        onInfo: _showInfoSheet,
                      ),
                    ),
                  ),
                  if (_showSkipIntro)
                    Positioned(
                      right: 20,
                      top: 104,
                      child: SafeArea(
                        child: FilledButton.tonalIcon(
                          onPressed: _skipIntro,
                          icon: const Icon(Icons.fast_forward_rounded),
                          label: const Text('skip intro'),
                        ),
                      ),
                    ),
                  if (_showNextUpCard)
                    Positioned(
                      right: 18,
                      bottom: 248,
                      child: SafeArea(
                        child: Container(
                          width: 240,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.78),
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                'next episode in $_nextUpCountdown',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _nextUp!.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: FilledButton.tonal(
                                      onPressed: _playNextUp,
                                      child: const Text('play now'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {
                                        _nextUpTimer?.cancel();
                                        _nextUpTimer = null;
                                        setState(() => _nextUpCancelled = true);
                                      },
                                      child: const Text('cancel'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
          loading:
              () => _PlayerLoadingState(
                title: widget.title,
                stage: PlaybackStartupStage.loadingPlaybackInfo,
                message: 'Requesting playback info from your server...',
              ),
          error:
              (Object error, StackTrace _) => _PlayerErrorState(
                title: widget.title,
                message: error.toString().replaceFirst('Exception: ', ''),
                diagnostics:
                    ref.read(clientSettingsProvider).showDebugPlaybackInfo
                        ? 'Stage: loadingPlaybackInfo'
                        : null,
                onRetry:
                    () => ref.invalidate(playbackInfoProvider(widget.itemId)),
              ),
        ),
      ),
    );
  }

  void _updateStage(PlaybackStartupStage stage, String message) {
    _stage = stage;
    _stageMessage = message;
    if (mounted) {
      setState(() {});
    }
  }

  void _log(String message) {
    if (kDebugMode && ref.read(clientSettingsProvider).verboseLogging) {
      debugPrint('Nextfin playback: $message');
    }
  }

  Duration get _initialResumePosition =>
      Duration(microseconds: widget.initialPositionTicks ~/ 10);

  Duration get _seekStep => Duration(
    seconds: ref.read(clientSettingsProvider).doubleTapSeekSeconds.round(),
  );

  void _primeTrackPrefs(PlaybackBundle bundle) {
    final sett = ref.read(clientSettingsProvider);
    _selectedAudioIndex ??= _pickAudio(bundle.info.audioStreams, sett);
    if (sett.autoEnableSubtitles) {
      _selectedSubtitleIndex ??= _pickSub(bundle.info.subtitleStreams, sett);
    }
  }

  int? _pickAudio(List<MediaStreamInfo> streams, ClientSettings sett) {
    if (streams.isEmpty) return null;
    final match = _pickByLang(streams, sett.preferredAudioLanguage);
    if (match != null) return match;
    return streams
        .firstWhere(
          (MediaStreamInfo s) => s.isDefault,
          orElse: () => streams.first,
        )
        .index;
  }

  int? _pickSub(List<MediaStreamInfo> streams, ClientSettings sett) {
    if (streams.isEmpty) return null;
    final match = _pickByLang(streams, sett.defaultSubtitleLanguage);
    if (match != null) return match;
    final def = streams.where((MediaStreamInfo s) => s.isDefault).firstOrNull;
    return def?.index;
  }

  int? _pickByLang(List<MediaStreamInfo> streams, String pref) {
    if (pref == 'System default') return null;
    final want = pref.toLowerCase();
    final hit =
        streams
            .where(
              (MediaStreamInfo s) =>
                  (s.language ?? '').toLowerCase() == want ||
                  s.displayTitle.toLowerCase().contains(want),
            )
            .firstOrNull;
    return hit?.index;
  }

  String _normalizeWebVtt(String source) {
    final trimmed = source.trimLeft();
    if (trimmed.startsWith('WEBVTT')) return source;
    return 'WEBVTT\n\n$source';
  }

  Future<void> _toggleFullscreen() async {
    _isFullscreen = !_isFullscreen;
    await SystemChrome.setPreferredOrientations(
      _isFullscreen
          ? <DeviceOrientation>[
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]
          : <DeviceOrientation>[DeviceOrientation.portraitUp],
    );
    await SystemChrome.setEnabledSystemUIMode(
      _isFullscreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
    if (mounted) setState(() {});
  }

  Future<void> _restoreWindowMode() async {
    _isFullscreen = false;
    await _applyOrientationPref();
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (mounted) setState(() {});
  }

  Future<void> _applyOrientationPref() async {
    final pref = ref.read(clientSettingsProvider).orientationPreference;
    if (_isFullscreen) return;
    switch (pref) {
      case OrientationPreference.auto:
        await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
        return;
      case OrientationPreference.portrait:
        await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
          DeviceOrientation.portraitUp,
        ]);
        return;
      case OrientationPreference.landscape:
        await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        return;
    }
  }

  Future<void> _enterPip() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    await _syncAndroidPlaybackState();
    _pipFeedbackTimer?.cancel();
    final size = controller.value.size;
    try {
      final available = await _platform
          .invokeMethod<bool>('enterPip', <String, dynamic>{
            'width': size.width <= 0 ? 16 : size.width.round(),
            'height': size.height <= 0 ? 9 : size.height.round(),
          });
      if (available != true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Picture-in-Picture is unavailable.')),
        );
        return;
      }
      _pipFeedbackTimer = Timer(const Duration(milliseconds: 700), () {
        if (mounted && !_isInPip) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not enter Picture-in-Picture.'),
            ),
          );
        }
      });
    } catch (error) {
      _log('pip enter failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not enter Picture-in-Picture.')),
        );
      }
    }
  }

  Future<void> _syncAndroidPlaybackState() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final settings = ref.read(clientSettingsProvider);
    try {
      await _platform.invokeMethod<void>('setMediaSession', <String, dynamic>{
        'title': widget.title,
        'playing': controller.value.isPlaying,
        'position': _isLive ? 0 : controller.value.position.inMilliseconds,
        'duration': _isLive ? 0 : controller.value.duration.inMilliseconds,
        'allowAutoPip': settings.pipAutoEnter,
      });
    } catch (error) {
      _log('media session sync failed: $error');
    }
  }

  Future<void> _clearAndroidPlaybackState() async {
    try {
      await _platform.invokeMethod<void>('clearMediaSession');
    } catch (error) {
      _log('media session clear failed: $error');
    }
  }

  Future<void> _setPlayerScreenActive(bool active) async {
    try {
      await _platform.invokeMethod<void>('setPlayerScreenActive', <String, dynamic>{
        'active': active,
      });
    } catch (error) {
      _log('player screen active sync failed: $error');
    }
  }

  Future<void> _handlePlatformAction(String action) async {
    final controller = _controller;
    if (controller == null) return;
    switch (action) {
      case 'playPause':
        if (controller.value.isPlaying) {
          await controller.pause();
        } else {
          await controller.play();
        }
        await _syncAndroidPlaybackState();
        break;
      case 'stop':
        await _handleExit();
        if (mounted) Navigator.of(context).maybePop();
        break;
      default:
        break;
    }
  }

  Future<void> _handlePipChanged(bool inPip) async {
    _pipFeedbackTimer?.cancel();
    _isInPip = inPip;
    if (!mounted) return;
    setState(() {
      if (inPip) {
        _showControls = false;
      }
    });
  }

  Future<void> _handlePlatformCall(MethodCall call) async {
    if (call.method == 'mediaAction') {
      await _handlePlatformAction(call.arguments.toString());
    } else if (call.method == 'pipChanged') {
      await _handlePipChanged(call.arguments == true);
    }
  }

  String _attemptKey(PlaybackBundle bundle) {
    return <Object?>[
      bundle.account.id,
      bundle.info.playSessionId,
      bundle.info.mediaSourceId,
      _selectedAudioIndex,
      _selectedSubtitleIndex,
      widget.itemId,
    ].join('|');
  }
}

class _PlayerOverlay extends StatelessWidget {
  const _PlayerOverlay({
    required this.title,
    required this.controller,
    required this.subtitleMessage,
    required this.subtitleCount,
    required this.audioCount,
    required this.isLive,
    required this.isFullscreen,
    required this.isInPip,
    required this.onBack,
    required this.onPlayPause,
    required this.onRewind,
    required this.onForward,
    required this.onSubtitle,
    required this.onAudio,
    required this.onFullscreen,
    required this.onPip,
    required this.onChannels,
    required this.onInfo,
  });

  final String title;
  final VideoPlayerController controller;
  final String? subtitleMessage;
  final int subtitleCount;
  final int audioCount;
  final bool isLive;
  final bool isFullscreen;
  final bool isInPip;
  final VoidCallback onBack;
  final VoidCallback onPlayPause;
  final VoidCallback onRewind;
  final VoidCallback onForward;
  final VoidCallback onSubtitle;
  final VoidCallback onAudio;
  final VoidCallback onFullscreen;
  final VoidCallback onPip;
  final VoidCallback? onChannels;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.black.withValues(alpha: 0.58),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.84),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                children: <Widget>[
                  _OverlayDockButton(
                    onPressed: onBack,
                    icon: Icons.arrow_back_rounded,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  if (subtitleMessage != null) ...<Widget>[
                    const Icon(
                      Icons.info_outline_rounded,
                      color: Colors.white70,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                  ],
                  _TopOverlayIconButton(
                    onPressed: onInfo,
                    icon: Icons.info_outline_rounded,
                  ),
                  const SizedBox(width: 6),
                  _TopOverlayIconButton(
                    onPressed: onPip,
                    icon:
                        isInPip
                            ? Icons.picture_in_picture_alt_rounded
                            : Icons.picture_in_picture_rounded,
                  ),
                  const SizedBox(width: 6),
                  _TopOverlayIconButton(
                    onPressed: onFullscreen,
                    icon:
                        isFullscreen
                            ? Icons.fullscreen_exit_rounded
                            : Icons.fullscreen_rounded,
                  ),
                ],
              ),
            ),
            const Spacer(),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 18),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    Colors.black.withValues(alpha: 0.42),
                    Colors.black.withValues(alpha: 0.66),
                  ],
                ),
                borderRadius: BorderRadius.circular(34),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.34),
                    blurRadius: 36,
                    offset: const Offset(0, 22),
                  ),
                ],
              ),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child:
                            isLive
                                ? const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Text(
                                      '●',
                                      style: TextStyle(
                                        color: Color(0xFFFF5F6D),
                                        fontSize: 13,
                                        height: 1,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    SizedBox(width: 7),
                                    Text(
                                      'live',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                )
                                : Text(
                                  controller.value.isPlaying
                                      ? 'Playing'
                                      : 'Paused',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                      ),
                      const Spacer(),
                      if (subtitleCount > 0)
                        _MiniOverlayChip(
                          icon: Icons.subtitles_rounded,
                          label: '$subtitleCount sub',
                        ),
                      if (audioCount > 0) ...<Widget>[
                        const SizedBox(width: 8),
                        _MiniOverlayChip(
                          icon: Icons.graphic_eq_rounded,
                          label: '$audioCount audio',
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (!isLive)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        _ControlButton(
                          icon: Icons.replay_10_rounded,
                          onPressed: onRewind,
                        ),
                        const SizedBox(width: 16),
                        FilledButton(
                          onPressed: onPlayPause,
                          style: FilledButton.styleFrom(
                            backgroundColor: scheme.primaryContainer.withValues(alpha: 0.94),
                            foregroundColor: scheme.onPrimaryContainer,
                            minimumSize: const Size(92, 92),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            elevation: 0,
                          ),
                          child: Icon(
                            controller.value.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 44,
                          ),
                        ),
                        const SizedBox(width: 16),
                        _ControlButton(
                          icon: Icons.forward_10_rounded,
                          onPressed: onForward,
                        ),
                      ],
                    )
                  else
                    Center(
                      child: FilledButton.tonalIcon(
                        onPressed: onPlayPause,
                        icon: Icon(
                          controller.value.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        label: Text(
                          controller.value.isPlaying ? 'pause live' : 'resume live',
                        ),
                      ),
                    ),
                  const SizedBox(height: 22),
                  if (!isLive) ...<Widget>[
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: VideoProgressIndicator(
                          controller,
                          allowScrubbing: true,
                          colors: VideoProgressColors(
                            playedColor: scheme.primary,
                            bufferedColor: Colors.white.withValues(alpha: 0.2),
                            backgroundColor: Colors.transparent,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Text(
                          _formatDuration(controller.value.position),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatDuration(controller.value.duration),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ] else
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'live playback stays on the current stream',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      if (subtitleCount > 0)
                        _ActionPill(
                          icon: Icons.subtitles_rounded,
                          label: 'Subtitles',
                          onPressed: onSubtitle,
                        ),
                      if (audioCount > 0)
                        _ActionPill(
                          icon: Icons.graphic_eq_rounded,
                          label: 'Audio',
                          onPressed: onAudio,
                        ),
                      if (isLive && onChannels != null)
                        _ActionPill(
                          icon: Icons.tv_rounded,
                          label: 'channels',
                          onPressed: onChannels!,
                        ),
                    ],
                  ),
                  if (subtitleMessage != null) ...<Widget>[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        subtitleMessage!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopOverlayIconButton extends StatelessWidget {
  const _TopOverlayIconButton({required this.onPressed, required this.icon});

  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.24),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.12),
        foregroundColor: Colors.white,
        minimumSize: const Size(68, 68),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
      child: Icon(icon, size: 30),
    );
  }
}

class _OverlayDockButton extends StatelessWidget {
  const _OverlayDockButton({required this.onPressed, required this.icon});

  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.24),
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: Icon(icon),
    );
  }
}

class _MiniOverlayChip extends StatelessWidget {
  const _MiniOverlayChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerLoadingState extends StatelessWidget {
  const _PlayerLoadingState({
    required this.title,
    required this.stage,
    required this.message,
  });

  final String title;
  final PlaybackStartupStage stage;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    switch (stage) {
                      PlaybackStartupStage.loadingPlaybackInfo =>
                        'Loading playback info',
                      PlaybackStartupStage.selectingSource =>
                        'Selecting stream',
                      PlaybackStartupStage.initializingPlayer =>
                        'Preparing playback',
                      PlaybackStartupStage.ready => 'Starting playback',
                      PlaybackStartupStage.error => 'Playback failed',
                    },
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerErrorState extends StatelessWidget {
  const _PlayerErrorState({
    required this.title,
    required this.message,
    this.diagnostics,
    required this.onRetry,
  });

  final String title;
  final String message;
  final String? diagnostics;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.play_disabled_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 42,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Playback failed',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (diagnostics != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        diagnostics!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:$minutes:$seconds';
  }
  return '${duration.inMinutes}:$seconds';
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
