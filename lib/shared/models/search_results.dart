import 'media_item.dart';

class SearchResults {
  const SearchResults({
    required this.movies,
    required this.series,
    required this.episodes,
    required this.people,
    required this.other,
  });

  final List<MediaItem> movies;
  final List<MediaItem> series;
  final List<MediaItem> episodes;
  final List<MediaItem> people;
  final List<MediaItem> other;

  bool get isEmpty =>
      movies.isEmpty &&
      series.isEmpty &&
      episodes.isEmpty &&
      people.isEmpty &&
      other.isEmpty;
}
