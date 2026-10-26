import 'dart:convert';

/// Typed projection of `ginkgo_domain::features::library_stats` payloads
/// (camelCase). Public library-website values only.

class CountPair {
  const CountPair({required this.available, required this.total});

  CountPair.fromJson(Map<String, dynamic> json)
    : this(available: json['available'] as int, total: json['total'] as int);

  final int available, total;
}

class ReadingRoom {
  ReadingRoom.fromJson(Map<String, dynamic> json)
    : name = json['name'] as String,
      people = json['people'] as int;

  final String name;
  final int people;
}

class LibraryCampusStats {
  LibraryCampusStats.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      name = json['name'] as String,
      people = json['people'] as int,
      readingRooms = (json['readingRooms'] as List? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(ReadingRoom.fromJson)
          .toList(growable: false),
      seats = _pair(json['seats']),
      studyRooms = _pair(json['studyRooms']),
      lockers = _pair(json['lockers']);

  final String id, name;
  final int people;
  final List<ReadingRoom> readingRooms;
  final CountPair? seats, studyRooms, lockers;

  static CountPair? _pair(Object? json) =>
      json == null ? null : CountPair.fromJson(json as Map<String, dynamic>);
}

class LibraryStatsSnapshot {
  LibraryStatsSnapshot._(this.campuses, this.fetchedAt, this.fromCache);

  final List<LibraryCampusStats> campuses;

  /// Raw school timestamp; Beijing formatting stays a presentation concern.
  final String? fetchedAt;
  final bool fromCache;
}

LibraryStatsSnapshot libraryStats(String payload) {
  final decoded = jsonDecode(payload) as Map<String, dynamic>;
  return LibraryStatsSnapshot._(
    (decoded['campuses'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(LibraryCampusStats.fromJson)
        .toList(growable: false),
    decoded['fetchedAt'] as String?,
    decoded['fromCache'] == true,
  );
}
