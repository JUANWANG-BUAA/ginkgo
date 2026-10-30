import 'package:ginkgo_mirror/shared/school_timestamp.dart';
import 'package:ginkgo_mirror/application/environment.dart';
import 'package:ginkgo_mirror/application/failures.dart';

/// Device-local personal task. Completion never changes a school assignment.
class LocalTaskRecord {
  const LocalTaskRecord({
    required this.id,
    required this.title,
    required this.due,
    required this.completed,
    this.sourceAssignmentId,
  });

  final String id;
  final String title;

  /// Empty means no deadline; legacy dates and RFC3339 instants are preserved.
  final String due;
  final bool completed;
  final String? sourceAssignmentId;
}

bool isLocalTaskDue(String value) {
  if (value.isEmpty) return true;
  if (RegExp(r'^[0-9]{4}-[0-9]{2}-[0-9]{2}$').hasMatch(value)) {
    final date = DateTime.tryParse(value);
    return date != null && date.toIso8601String().startsWith(value);
  }
  final match = RegExp(
    r'^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(?:[.][0-9]{1,9})?(Z|[+-]([0-9]{2}):([0-9]{2}))$',
  ).firstMatch(value);
  if (match == null || parseSchoolTimestamp(value) == null) return false;
  return match[1] == 'Z' ||
      (int.parse(match[2]!) <= 23 && int.parse(match[3]!) <= 59);
}

/// School wall-clock timestamps have no offset; explicitly use Beijing time.
String localTaskDueFromHomework(String? value) {
  final raw = value?.trim() ?? '';
  if (isLocalTaskDue(raw)) return raw;
  // Only unzoned wall time may gain an offset. Bad offsets stay unknown.
  if (RegExp(r'(Z|[+-][0-9]{2}:?[0-9]{2})$').hasMatch(raw)) return '';
  if (parseSchoolTimestamp(raw) == null) return '';
  // Preserve original fractional seconds, which the display parser discards.
  final normalized = raw.replaceFirst(' ', 'T');
  final withSeconds = normalized.length == 16 ? '$normalized:00' : normalized;
  return '$withSeconds+08:00';
}

String localTaskDueLabel(String due) {
  if (due.isEmpty) return '无截止时间';
  if (due.length == 10) return '$due（仅日期）';
  final wall = parseSchoolTimestamp(due);
  if (wall == null) return due;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${wall.year}-${two(wall.month)}-${two(wall.day)} '
      '${two(wall.hour)}:${two(wall.minute)}（北京时间）';
}

class LocalTasksRead {
  const LocalTasksRead({this.data, this.failure});
  final List<LocalTaskRecord>? data;
  final FailureCode? failure;
}

abstract interface class LocalTaskGateway implements MirrorEnvironment {
  Future<LocalTasksRead> editTasks({
    required String root,
    required String action,
    String? id,
    String? title,
    String? due,
    bool? completed,
  });
}

/// The only JSON decoding path shared by Today, Tasks and homework linking.
Future<List<LocalTaskRecord>> editLocalTasks(
  LocalTaskGateway service, {
  required String root,
  required String action,
  String? id,
  String? title,
  String? due,
  bool? completed,
}) async {
  final result = await service.editTasks(
    root: root,
    action: action,
    id: id,
    title: title,
    due: due,
    completed: completed,
  );
  final data = result.data;
  if (result.failure != null || data == null) {
    throw const FormatException('Local tasks unavailable');
  }
  return data;
}
