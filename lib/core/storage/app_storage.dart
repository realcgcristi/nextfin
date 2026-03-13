import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/models/server_account.dart';

enum LayoutDensity { compact, comfortable }

enum StreamingQuality { auto, dataSaver, balanced, max }

enum PlaybackPreference { auto, directPlay, transcode }

enum AppThemePalette { nextfin, arctic, emerald, rose, cinema }

enum OrientationPreference { auto, portrait, landscape }

class ClientSettings {
  const ClientSettings({
    this.themePalette = AppThemePalette.nextfin,
    this.dynamicColor = true,
    this.layoutDensity = LayoutDensity.comfortable,
    this.defaultSubtitleLanguage = 'System default',
    this.autoEnableSubtitles = false,
    this.preferredAudioLanguage = 'System default',
    this.resumePlayback = true,
    this.skipIntroButton = true,
    this.doubleTapSeekSeconds = 10,
    this.rememberPlaybackSpeed = true,
    this.backgroundPlayback = false,
    this.pipAutoEnter = true,
    this.orientationPreference = OrientationPreference.auto,
    this.allowHttpServers = true,
    this.streamingQuality = StreamingQuality.auto,
    this.playbackPreference = PlaybackPreference.auto,
    this.showDebugPlaybackInfo = false,
    this.showApiResponses = false,
    this.verboseLogging = false,
  });

  final AppThemePalette themePalette;
  final bool dynamicColor;
  final LayoutDensity layoutDensity;
  final String defaultSubtitleLanguage;
  final bool autoEnableSubtitles;
  final String preferredAudioLanguage;
  final bool resumePlayback;
  final bool skipIntroButton;
  final double doubleTapSeekSeconds;
  final bool rememberPlaybackSpeed;
  final bool backgroundPlayback;
  final bool pipAutoEnter;
  final OrientationPreference orientationPreference;
  final bool allowHttpServers;
  final StreamingQuality streamingQuality;
  final PlaybackPreference playbackPreference;
  final bool showDebugPlaybackInfo;
  final bool showApiResponses;
  final bool verboseLogging;

  ClientSettings copyWith({
    AppThemePalette? themePalette,
    bool? dynamicColor,
    LayoutDensity? layoutDensity,
    String? defaultSubtitleLanguage,
    bool? autoEnableSubtitles,
    String? preferredAudioLanguage,
    bool? resumePlayback,
    bool? skipIntroButton,
    double? doubleTapSeekSeconds,
    bool? rememberPlaybackSpeed,
    bool? backgroundPlayback,
    bool? pipAutoEnter,
    OrientationPreference? orientationPreference,
    bool? allowHttpServers,
    StreamingQuality? streamingQuality,
    PlaybackPreference? playbackPreference,
    bool? showDebugPlaybackInfo,
    bool? showApiResponses,
    bool? verboseLogging,
  }) {
    return ClientSettings(
      themePalette: themePalette ?? this.themePalette,
      dynamicColor: dynamicColor ?? this.dynamicColor,
      layoutDensity: layoutDensity ?? this.layoutDensity,
      defaultSubtitleLanguage:
          defaultSubtitleLanguage ?? this.defaultSubtitleLanguage,
      autoEnableSubtitles: autoEnableSubtitles ?? this.autoEnableSubtitles,
      preferredAudioLanguage:
          preferredAudioLanguage ?? this.preferredAudioLanguage,
      resumePlayback: resumePlayback ?? this.resumePlayback,
      skipIntroButton: skipIntroButton ?? this.skipIntroButton,
      doubleTapSeekSeconds: doubleTapSeekSeconds ?? this.doubleTapSeekSeconds,
      rememberPlaybackSpeed:
          rememberPlaybackSpeed ?? this.rememberPlaybackSpeed,
      backgroundPlayback: backgroundPlayback ?? this.backgroundPlayback,
      pipAutoEnter: pipAutoEnter ?? this.pipAutoEnter,
      orientationPreference:
          orientationPreference ?? this.orientationPreference,
      allowHttpServers: allowHttpServers ?? this.allowHttpServers,
      streamingQuality: streamingQuality ?? this.streamingQuality,
      playbackPreference: playbackPreference ?? this.playbackPreference,
      showDebugPlaybackInfo:
          showDebugPlaybackInfo ?? this.showDebugPlaybackInfo,
      showApiResponses: showApiResponses ?? this.showApiResponses,
      verboseLogging: verboseLogging ?? this.verboseLogging,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'themePalette': themePalette.name,
    'dynamicColor': dynamicColor,
    'layoutDensity': layoutDensity.name,
    'defaultSubtitleLanguage': defaultSubtitleLanguage,
    'autoEnableSubtitles': autoEnableSubtitles,
    'preferredAudioLanguage': preferredAudioLanguage,
    'resumePlayback': resumePlayback,
    'skipIntroButton': skipIntroButton,
    'doubleTapSeekSeconds': doubleTapSeekSeconds,
    'rememberPlaybackSpeed': rememberPlaybackSpeed,
    'backgroundPlayback': backgroundPlayback,
    'pipAutoEnter': pipAutoEnter,
    'orientationPreference': orientationPreference.name,
    'allowHttpServers': allowHttpServers,
    'streamingQuality': streamingQuality.name,
    'playbackPreference': playbackPreference.name,
    'showDebugPlaybackInfo': showDebugPlaybackInfo,
    'showApiResponses': showApiResponses,
    'verboseLogging': verboseLogging,
  };

  factory ClientSettings.fromJson(Map<String, dynamic> json) {
    LayoutDensity density = LayoutDensity.comfortable;
    StreamingQuality quality = StreamingQuality.auto;
    PlaybackPreference playback = PlaybackPreference.auto;
    AppThemePalette palette = AppThemePalette.nextfin;
    OrientationPreference orientation = OrientationPreference.auto;
    try {
      palette = AppThemePalette.values.firstWhere(
        (AppThemePalette item) => item.name == json['themePalette'],
      );
    } catch (_) {}
    try {
      density = LayoutDensity.values.firstWhere(
        (LayoutDensity item) => item.name == json['layoutDensity'],
      );
    } catch (_) {}
    try {
      quality = StreamingQuality.values.firstWhere(
        (StreamingQuality item) => item.name == json['streamingQuality'],
      );
    } catch (_) {}
    try {
      playback = PlaybackPreference.values.firstWhere(
        (PlaybackPreference item) => item.name == json['playbackPreference'],
      );
    } catch (_) {}
    try {
      orientation = OrientationPreference.values.firstWhere(
        (OrientationPreference item) =>
            item.name == json['orientationPreference'],
      );
    } catch (_) {}
    return ClientSettings(
      themePalette: palette,
      dynamicColor: json['dynamicColor'] != false,
      layoutDensity: density,
      defaultSubtitleLanguage:
          json['defaultSubtitleLanguage']?.toString() ?? 'System default',
      autoEnableSubtitles: json['autoEnableSubtitles'] == true,
      preferredAudioLanguage:
          json['preferredAudioLanguage']?.toString() ?? 'System default',
      resumePlayback: json['resumePlayback'] != false,
      skipIntroButton: json['skipIntroButton'] != false,
      doubleTapSeekSeconds:
          (json['doubleTapSeekSeconds'] as num?)?.toDouble() ?? 10,
      rememberPlaybackSpeed: json['rememberPlaybackSpeed'] != false,
      backgroundPlayback: json['backgroundPlayback'] == true,
      pipAutoEnter: json['pipAutoEnter'] != false,
      orientationPreference: orientation,
      allowHttpServers: json['allowHttpServers'] != false,
      streamingQuality: quality,
      playbackPreference: playback,
      showDebugPlaybackInfo: json['showDebugPlaybackInfo'] == true,
      showApiResponses: json['showApiResponses'] == true,
      verboseLogging: json['verboseLogging'] == true,
    );
  }
}

class AppStorage {
  AppStorage(this._prefs);

  final SharedPreferences _prefs;

  static const _accountsKey = 'accounts';
  static const _activeAccountIdKey = 'active_account_id';
  static const _themeModeKey = 'theme_mode';
  static const _recentSearchesKey = 'recent_searches';
  static const _clientSettingsKey = 'client_settings';

  List<ServerAccount> loadAccounts() {
    final raw = _prefs.getStringList(_accountsKey) ?? <String>[];
    return raw
        .map(
          (String entry) =>
              ServerAccount.fromJson(jsonDecode(entry) as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> saveAccounts(List<ServerAccount> accounts) async {
    await _prefs.setStringList(
      _accountsKey,
      accounts
          .map((ServerAccount account) => jsonEncode(account.toJson()))
          .toList(),
    );
  }

  String? loadActiveAccountId() => _prefs.getString(_activeAccountIdKey);

  Future<void> saveActiveAccountId(String? value) async {
    if (value == null) {
      await _prefs.remove(_activeAccountIdKey);
      return;
    }
    await _prefs.setString(_activeAccountIdKey, value);
  }

  ThemeMode loadThemeMode() {
    final raw = _prefs.getString(_themeModeKey);
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    final raw = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _prefs.setString(_themeModeKey, raw);
  }

  List<String> loadRecentSearches() =>
      _prefs.getStringList(_recentSearchesKey) ?? <String>[];

  Future<void> saveRecentSearches(List<String> values) async {
    await _prefs.setStringList(_recentSearchesKey, values.take(8).toList());
  }

  ClientSettings loadClientSettings() {
    final raw = _prefs.getString(_clientSettingsKey);
    if (raw == null || raw.isEmpty) {
      return const ClientSettings();
    }
    try {
      return ClientSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const ClientSettings();
    }
  }

  Future<void> saveClientSettings(ClientSettings settings) async {
    await _prefs.setString(_clientSettingsKey, jsonEncode(settings.toJson()));
  }
}
