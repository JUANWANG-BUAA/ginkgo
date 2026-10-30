import 'package:ginkgo_mirror/application/contracts.dart';

/// Public library-website values only.

class CountPair {
  const CountPair({required this.available, required this.total});
  final int available, total;
}

class ReadingRoom {
  const ReadingRoom({required this.name, required this.people});
  final String name;
  final int people;
}

class LibraryCampusStats {
  const LibraryCampusStats({
    required this.id,
    required this.name,
    required this.people,
    required this.readingRooms,
    this.seats,
    this.studyRooms,
    this.lockers,
  });

  final String id, name;
  final int people;
  final List<ReadingRoom> readingRooms;

  /// Absent means the school did not publish that resource, not zero.
  final CountPair? seats, studyRooms, lockers;
}

class LibraryStatsSnapshot {
  const LibraryStatsSnapshot({
    required this.campuses,
    required this.fetchedAt,
    required this.fromCache,
  });

  final List<LibraryCampusStats> campuses;

  /// Raw school timestamp; Beijing formatting stays a presentation concern.
  final String? fetchedAt;
  final bool fromCache;
}

class LibraryStatsRead {
  const LibraryStatsRead({this.data, this.failure});
  final LibraryStatsSnapshot? data;
  final FailureCode? failure;
}
