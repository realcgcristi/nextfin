import 'package:flutter_test/flutter_test.dart';
import 'package:nextfin/shared/models/media_item.dart';

void main() {
  test('MediaItem parses sparse Jellyfin payloads defensively', () {
    final item = MediaItem.fromJson(<String, dynamic>{
      'Id': '123',
      'Name': 'Sample Movie',
      'Type': 'Movie',
      'UserData': <String, dynamic>{
        'IsFavorite': true,
        'PlaybackPositionTicks': '3000',
      },
    });

    expect(item.id, '123');
    expect(item.name, 'Sample Movie');
    expect(item.type, 'Movie');
    expect(item.isFavorite, isTrue);
    expect(item.playbackPositionTicks, 3000);
    expect(item.genres, isEmpty);
  });
}
