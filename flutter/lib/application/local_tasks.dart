import 'dart:convert';

import 'package:ginkgo_mirror/shared/school_timestamp.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';

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

  factory LocalTaskRecord.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final due = json['due'];
    final completed = json['completed'];
    if (id is! String ||
        id.trim().isEmpty ||
        title is! String ||
        title.trim().isEmpty ||
        due is! String ||
        !isLocalTaskDue(due) ||
        completed is! bool) {
      throw const FormatException('Invalid local task fields');
    }
    String? assignmentId;
    final source = json['source'];
    if (source != null) {
      if (source is! Map<String, dynamic> ||
          source['kind'] != 'homework' ||
          source['assignment_id'] is! String ||
          (source['assignment_id'] as String).trim().isEmpty) {
        throw const FormatException('Invalid local task source');
      }
      assignmentId = source['assignment_id'] as String;
    }
    return LocalTaskRecord(
      id: id,
      title: title,
      due: due,
      completed: completed,
      sourceAssignmentId: assignmentId,
    );
  }
}

/// Fail closed: null, malformed lists/rows and duplicate ids are not empty data.
List<LocalTaskRecord> parseLocalTasksPayload(String? payload) {
  if (payload == null) throw const FormatException('Missing tasks payload');
  final decoded = jsonDecode(payload);
  if (decoded is! List) throw const FormatException('Expected tasks list');
  final ids = <String>{};
  return List.unmodifiable(
    decoded.map((row) {
      if (row is! Map<String, dynamic>) {
        throw const FormatException('Invalid task row');
      }
      final task = LocalTaskRecord.fromJson(row);
      if (!ids.add(task.id)) throw const FormatException('Duplicate task id');
      return task;
    }),
  );
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
  if (result.failure != null || result.stale) {
    throw const FormatException('Local tasks unavailable');
  }
  return parseLocalTasksPayload(result.payload);
}
