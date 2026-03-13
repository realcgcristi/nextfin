import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../../core/networking/jellyfin_api.dart';
import '../../../core/theme/app_theme.dart';
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
  final info = await api.getPlaybackInfo(account, itemId);
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
  });

  final String itemId;
  final String title;
  final int initialPositionTicks;

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _platform.setMethodCallHandler(_handlePlatformCall);
  }

  @override
  void dispose() {
    _overlayTimer?.cancel();
    _progressTimer?.cancel();
    _timelineTimer?.cancel();
    _pipFeedbackTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (!_exitHandled) {
      unawaited(_handleExit());
    }
    super.dispose();
  }

  Future<void> _disposeController({required bool reportStop}) async {
    final controller = _controller;
    final bundle = _bundle;
    _controller = null;
    if (controller != null) {
      await controller.pause();
      if (reportStop) {
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
      _log('selected item id=${widget.itemId} title="${widget.title}"');
      _updateStage(
        PlaybackStartupStage.selectingSource,
        'Selecting the best stream for this device...',
      );
      final controller = await _buildController(bundle, api);
      _updateStage(PlaybackStartupStage.ready, 'Playback ready');
      final resumePosition = _pendingSeek ?? _initialResumePosition;
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

  Future<void> _handleExit() async {
    if (_exitHandled) return;
    _exitHandled = true;
    _overlayTimer?.cancel();
    _progressTimer?.cancel();
    _timelineTimer?.cancel();
    _pipFeedbackTimer?.cancel();
    final controller = _controller;
    if (controller != null) {
      if (controller.value.isPlaying) {
        await controller.pause();
      }
      await _disposeController(reportStop: true);
    }
    await _clearAndroidPlaybackState();
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
          'selected media source id=${candidate.source?.id ?? 'fallback'} container=${candidate.source?.container ?? 'unknown'} protocol=${candidate.source?.protocol ?? 'unknown'} kind=${candidate.kind}',
        );
        _log('final stream URL=${candidate.url}');
        _log('auth token present=${bundle.account.accessToken.isNotEmpty}');
        final preview = await api.previewPlaybackUrl(
          bundle.account,
          candidate.url,
          expectText: false,
        );
        _log(
          'stream preview status=${preview.statusCode} contentType=${preview.contentType}',
        );
        if (preview.statusCode == 401 || preview.statusCode == 403) {
          throw Exception('The media request was rejected by the server.');
        }
        if (preview.statusCode == 404) {
          throw Exception('The server did not return a playable stream.');
        }
        if (preview.statusCode < 200 || preview.statusCode >= 400) {
          throw Exception(
            'The media stream failed with HTTP ${preview.statusCode}.',
          );
        }
        _updateStage(
          PlaybackStartupStage.initializingPlayer,
          'Initializing the video player...',
        );
        controller = VideoPlayerController.networkUrl(
          Uri.parse(candidate.url),
          httpHeaders: api.playerHeaders(bundle.account),
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
        await _applySubtitles(api, bundle, controller);
        _log(
          'player ready duration=${controller.value.duration} size=${controller.value.size}',
        );
        return controller;
      } catch (error) {
        await controller?.dispose();
        _log('player startup candidate failed: $error');
        lastError = error;
      }
    }
    throw lastError ??
        Exception('No playable stream was returned by the server.');
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
    if (controller.value.position >= controller.value.duration &&
        controller.value.duration > Duration.zero) {
      setState(() => _showControls = true);
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
    final playback = ref.watch(playbackInfoProvider(widget.itemId));
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
                    kDebugMode
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
                    duration: const Duration(milliseconds: 240),
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
                        isFullscreen: _isFullscreen,
                        isInPip: _isInPip,
                        onFullscreen: _toggleFullscreen,
                        onPip: _enterPip,
                        onRewind:
                            () => _seekRelative(const Duration(seconds: -10)),
                        onForward:
                            () => _seekRelative(const Duration(seconds: 10)),
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
                diagnostics: kDebugMode ? 'Stage: loadingPlaybackInfo' : null,
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
    if (kDebugMode) {
      debugPrint('Nextfin playback: $message');
    }
  }

  Duration get _initialResumePosition =>
      Duration(microseconds: widget.initialPositionTicks ~/ 10);

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
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (mounted) setState(() {});
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
        'position': controller.value.position.inMilliseconds,
        'duration': controller.value.duration.inMilliseconds,
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
  });

  final String title;
  final VideoPlayerController controller;
  final String? subtitleMessage;
  final int subtitleCount;
  final int audioCount;
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.black.withValues(alpha: 0.5),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.74),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: <Widget>[
                  FilledButton.tonal(
                    onPressed: onBack,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.22),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(48, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
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
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.24),
                    blurRadius: 24,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                children: <Widget>[
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
                          backgroundColor: scheme.primaryContainer.withValues(
                            alpha: 0.94,
                          ),
                          foregroundColor: scheme.onPrimaryContainer,
                          minimumSize: const Size(88, 88),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
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
                  ),
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: VideoProgressIndicator(
                      controller,
                      allowScrubbing: true,
                      colors: VideoProgressColors(
                        playedColor: scheme.primaryContainer,
                        bufferedColor: Colors.white.withValues(alpha: 0.28),
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Text(
                        _formatDuration(controller.value.position),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatDuration(controller.value.duration),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      if (subtitleCount > 0)
                        Expanded(
                          child: TextButton.icon(
                            onPressed: onSubtitle,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.06,
                              ),
                            ),
                            icon: const Icon(Icons.subtitles_rounded),
                            label: const Text('Subtitles'),
                          ),
                        ),
                      if (subtitleCount > 0 && audioCount > 0)
                        const SizedBox(width: 10),
                      if (audioCount > 0)
                        Expanded(
                          child: TextButton.icon(
                            onPressed: onAudio,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.06,
                              ),
                            ),
                            icon: const Icon(Icons.graphic_eq_rounded),
                            label: const Text('Audio'),
                          ),
                        ),
                    ],
                  ),
                  if (subtitleMessage != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        subtitleMessage!,
                        style: const TextStyle(color: Colors.white70),
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
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(16),
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
        backgroundColor: Colors.white.withValues(alpha: 0.16),
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 64),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      child: Icon(icon, size: 30),
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
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(24),
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
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white60),
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
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.play_disabled_rounded,
                    color: Colors.white,
                    size: 42,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Playback failed',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  if (diagnostics != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        diagnostics!,
                        style: const TextStyle(
                          color: Colors.white60,
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
