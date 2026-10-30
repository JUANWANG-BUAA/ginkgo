import '../application/contracts.dart';
import '../application/shuttle.dart';
import '../src/rust/api/live.dart' as live;

ShuttleTimetableRead decodeShuttleTimetable(
  live.ShuttleTimetableResponse response,
) {
  final data = response.data;
  if (data == null) {
    return ShuttleTimetableRead(
      failure: response.failure ?? FailureCode.changedResponse,
    );
  }
  return ShuttleTimetableRead(
    data: ShuttleTimetable(
      source: data.source,
      liveSource: data.liveSource,
      tables: List.unmodifiable(
        data.tables.map(
          (table) => ShuttleTable(
            left: table.left,
            right: table.right,
            sections: List.unmodifiable(
              table.sections.map(
                (section) => ShuttleSection(
                  label: section.label,
                  left: List.unmodifiable(
                    section.left.map(
                      (run) => ShuttleRun(
                        index: run.index,
                        time: run.time,
                        capacity: run.capacity,
                      ),
                    ),
                  ),
                  right: List.unmodifiable(
                    section.right.map(
                      (run) => ShuttleRun(
                        index: run.index,
                        time: run.time,
                        capacity: run.capacity,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    failure: response.failure,
  );
}
