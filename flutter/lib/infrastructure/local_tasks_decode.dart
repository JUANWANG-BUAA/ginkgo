import '../application/contracts.dart';
import '../application/local_tasks.dart';
import '../src/rust/api/live.dart' as live;

/// Local records are validated by the Rust store on write, so the projection
/// here only maps fields; a failure never degrades into an empty list.
LocalTasksRead decodeLocalTasks(live.LocalTasksResponse response) {
  final rows = response.data;
  if (rows == null) {
    return LocalTasksRead(
      failure: response.failure ?? FailureCode.changedResponse,
    );
  }
  return LocalTasksRead(
    data: List.unmodifiable(
      rows.map(
        (row) => LocalTaskRecord(
          id: row.id,
          title: row.title,
          due: row.due,
          completed: row.completed,
          sourceAssignmentId: row.sourceAssignmentId,
        ),
      ),
    ),
    failure: response.failure,
  );
}
