import '../application/contracts.dart';
import '../application/library_stats.dart';
import '../src/rust/api/live.dart' as live;

LibraryStatsRead decodeLibraryStats(live.LibraryStatsResponse response) {
  final data = response.data;
  if (data == null) {
    return LibraryStatsRead(
      failure: response.failure ?? FailureCode.changedResponse,
    );
  }
  return LibraryStatsRead(
    data: LibraryStatsSnapshot(
      fetchedAt: data.fetchedAt,
      fromCache: data.fromCache,
      campuses: List.unmodifiable(
        data.campuses.map(
          (campus) => LibraryCampusStats(
            id: campus.id,
            name: campus.name,
            people: campus.people,
            readingRooms: List.unmodifiable(
              campus.readingRooms.map(
                (room) => ReadingRoom(name: room.name, people: room.people),
              ),
            ),
            seats: _pair(campus.seats),
            studyRooms: _pair(campus.studyRooms),
            lockers: _pair(campus.lockers),
          ),
        ),
      ),
    ),
    failure: response.failure,
  );
}

CountPair? _pair(live.CountPairDto? pair) => pair == null
    ? null
    : CountPair(available: pair.available, total: pair.total);
