import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/library_stats.dart';

/// Test fixtures stay map-shaped; production now receives a typed DTO, so
/// fixtures are lifted here in one place.
LibraryStatsRead statsRead(Map<String, dynamic>? json, {FailureCode? failure}) {
  if (json == null) return LibraryStatsRead(failure: failure);
  return LibraryStatsRead(
    data: LibraryStatsSnapshot(
      fetchedAt: json['fetchedAt'] as String?,
      fromCache: json['fromCache'] == true,
      campuses: [
        for (final campus
            in (json['campuses'] as List? ?? const [])
                .cast<Map<String, dynamic>>())
          LibraryCampusStats(
            id: campus['id'] as String? ?? '',
            name: campus['name'] as String? ?? '',
            people: campus['people'] as int? ?? 0,
            readingRooms: [
              for (final room
                  in (campus['readingRooms'] as List? ?? const [])
                      .cast<Map<String, dynamic>>())
                ReadingRoom(
                  name: room['name'] as String,
                  people: room['people'] as int,
                ),
            ],
            seats: _pair(campus['seats']),
            studyRooms: _pair(campus['studyRooms']),
            lockers: _pair(campus['lockers']),
          ),
      ],
    ),
    failure: failure,
  );
}

CountPair? _pair(Object? json) => json == null
    ? null
    : CountPair(
        available: (json as Map<String, dynamic>)['available'] as int,
        total: json['total'] as int,
      );
