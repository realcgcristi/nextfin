import 'dart:math';

import 'server_capabilities.dart';

class CompatibilityInspector {
  const CompatibilityInspector();

  ServerCapabilities infer({
    required Map<String, dynamic> systemInfo,
    required Map<String, bool> endpointAvailability,
  }) {
    final version =
        systemInfo['Version']?.toString() ??
        systemInfo['version']?.toString() ??
        'unknown';
    final notes = <String>[];
    final probed = endpointAvailability.keys.toList()..sort();

    final supportsNextUp = endpointAvailability['Shows/NextUp'] ?? false;
    final supportsPlaybackInfo =
        endpointAvailability['Items/PlaybackInfo'] ?? true;
    final supportsUserViews = endpointAvailability['Users/Views'] ?? true;
    final supportsSearchHints = endpointAvailability['Search/Hints'] ?? true;
    final supportsInstantMix =
        endpointAvailability['Items/InstantMix'] ?? false;

    if (version == 'unknown') {
      notes.add('Server did not expose a stable version string.');
    }
    if (!supportsNextUp) {
      notes.add(
        'Next Up endpoint missing; home screen falls back to latest episodes.',
      );
    }
    if (!supportsSearchHints) {
      notes.add(
        'Search hints unavailable; global search uses items query fallback.',
      );
    }
    if (!supportsPlaybackInfo) {
      notes.add('PlaybackInfo unavailable; player uses direct stream URLs.');
    }

    return ServerCapabilities(
      version: version,
      supportsNextUp: supportsNextUp,
      supportsResume: true,
      supportsPlaybackInfo: supportsPlaybackInfo,
      supportsInstantMix: supportsInstantMix,
      supportsUserViews: supportsUserViews,
      supportsSearchHints: supportsSearchHints,
      probedEndpoints: probed,
      notes: notes,
    );
  }

  int score(ServerCapabilities capabilities) {
    var score = 0;
    if (capabilities.supportsNextUp) score += 2;
    if (capabilities.supportsPlaybackInfo) score += 3;
    if (capabilities.supportsSearchHints) score += 1;
    if (capabilities.supportsUserViews) score += 1;
    if (capabilities.supportsInstantMix) score += 1;
    return max(score, 1);
  }
}
