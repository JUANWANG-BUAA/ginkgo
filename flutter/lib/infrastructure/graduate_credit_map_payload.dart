import 'dart:convert';

import '../application/contracts.dart' show ReadOnlyResponse;
import '../application/graduate_credit_map.dart';

/// Decodes the core projection, not a school response. Rust owns arithmetic.
GraduateCreditMapRead decodeGraduateCreditMapRead(ReadOnlyResponse response) {
  final issue = GraduateCreditReadIssue.fromFailure(response.failure);
  if (response.payload == null ||
      issue?.kind == GraduateCreditIssueKind.authentication ||
      (issue != null && !response.stale)) {
    return GraduateCreditMapRead(
      issue:
          issue ??
          const GraduateCreditReadIssue(GraduateCreditIssueKind.unknown),
    );
  }
  return GraduateCreditMapRead(
    data: decodeGraduateCreditMap(jsonDecode(response.payload!)),
    stale: response.stale,
    issue: issue,
  );
}

GraduateCreditMap decodeGraduateCreditMap(Object? value) {
  final map = value as Map<String, dynamic>;
  return GraduateCreditMap(
    summary: map['summary'] == null ? null : _node(map['summary']),
    nodes: (map['nodes'] as List).map(_node),
    notice: map['notice'] as String?,
  );
}

GraduateCreditNode _node(Object? value) {
  final map = value as Map<String, dynamic>;
  final index = map['sourceIndex'] as int;
  if (index < 0) throw const FormatException('学分条目索引无效');
  return GraduateCreditNode(
    sourceIndex: index,
    title: map['title'] as String,
    progress: map['progress'] == null ? null : _metrics(map['progress']),
    rows: (map['rows'] as List).map((value) {
      final row = value as Map<String, dynamic>;
      return GraduateCreditRow(
        title: row['title'] as String,
        detail: row['detail'] as String,
        isCourse: row['isCourse'] as bool? ?? false,
        completed: row['completed'] as bool?,
        credit: _number(row['credit']),
        semester: row['semester'] as String?,
      );
    }),
  );
}

double? _number(Object? value) {
  if (value == null) return null;
  final number = (value as num).toDouble();
  if (!number.isFinite || number < 0) {
    throw const FormatException('学分投影数值无效');
  }
  return number;
}

GraduateCreditMetrics _metrics(Object? value) {
  final map = value as Map<String, dynamic>;
  final ratio = _number(map['ratio']);
  if (ratio != null && ratio > 1) throw const FormatException('学分比例无效');
  return GraduateCreditMetrics(
    state: GraduateCreditState.values.byName(map['state'] as String),
    requiredCredits: _number(map['required']),
    earned: _number(map['earned']),
    pending: _number(map['pending']),
    remaining: _number(map['remaining']),
    ratio: ratio,
  );
}
