import 'package:flutter_test/flutter_test.dart';
import 'package:nextfin/core/compatibility/compatibility.dart';

void main() {
  test('Compatibility inspector derives fallbacks from probes', () {
    const inspector = CompatibilityInspector();
    final capabilities = inspector.infer(
      systemInfo: <String, dynamic>{'Version': '10.8.13'},
      endpointAvailability: <String, bool>{
        'Shows/NextUp': false,
        'Items/PlaybackInfo': true,
        'Users/Views': true,
        'Search/Hints': false,
        'Items/InstantMix': false,
      },
    );

    expect(capabilities.version, '10.8.13');
    expect(capabilities.supportsNextUp, isFalse);
    expect(capabilities.supportsPlaybackInfo, isTrue);
    expect(capabilities.notes, isNotEmpty);
  });
}
