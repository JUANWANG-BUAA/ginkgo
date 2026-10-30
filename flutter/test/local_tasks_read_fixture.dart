import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/local_tasks.dart';

/// Test fixtures stay map-shaped for brevity; production receives a typed DTO,
/// so fixtures are lifted here in one place.
LocalTasksRead tasksRead(
  List<Map<String, dynamic>> rows, {
  FailureCode? failure,
}) => LocalTasksRead(
  data: [
    for (final row in rows)
      LocalTaskRecord(
        id: row['id'] as String,
        title: row['title'] as String,
        due: row['due'] as String? ?? '',
        completed: row['completed'] as bool? ?? false,
        sourceAssignmentId:
            ((row['source'] as Map?)?['assignment_id']) as String?,
      ),
  ],
  failure: failure,
);
