import '../application/contracts.dart';
import '../application/graduate_credit_map.dart';
import '../src/rust/api/live.dart' as live;

/// Projects the typed core result. Rust owns the arithmetic.
GraduateCreditMapRead decodeGraduateCreditMapRead(
  live.GraduateCreditMapResponse response,
) {
  final issue = GraduateCreditReadIssue.fromFailure(response.failure);
  // Data may accompany a failure only as a previous successful snapshot.
  final stale = response.failure != null;
  if (response.data == null ||
      issue?.kind == GraduateCreditIssueKind.authentication) {
    return GraduateCreditMapRead(
      issue:
          issue ??
          const GraduateCreditReadIssue(GraduateCreditIssueKind.unknown),
    );
  }
  return GraduateCreditMapRead(
    data: _map(response.data!),
    stale: stale,
    issue: issue,
  );
}

GraduateCreditMap _map(live.GraduateCreditMapDto dto) => GraduateCreditMap(
  summary: dto.summary == null ? null : _node(dto.summary!),
  nodes: List.unmodifiable(dto.nodes.map(_node)),
  notice: dto.notice,
);

GraduateCreditNode _node(live.GraduateCreditNodeDto dto) => GraduateCreditNode(
  sourceIndex: dto.sourceIndex,
  title: dto.title,
  progress: dto.progress == null ? null : _metrics(dto.progress!),
  rows: List.unmodifiable(
    dto.rows.map(
      (row) => GraduateCreditRow(
        title: row.title,
        detail: row.detail,
        isCourse: row.isCourse,
        completed: row.completed,
        credit: row.credit,
        semester: row.semester,
      ),
    ),
  ),
);

GraduateCreditMetrics _metrics(live.GraduateCreditMetricsDto dto) =>
    GraduateCreditMetrics(
      state: switch (dto.state) {
        live.GraduateCreditStateDto.unknown => GraduateCreditState.unknown,
        live.GraduateCreditStateDto.noMinimum => GraduateCreditState.noMinimum,
        live.GraduateCreditStateDto.incomplete =>
          GraduateCreditState.incomplete,
        live.GraduateCreditStateDto.requirementMet =>
          GraduateCreditState.requirementMet,
      },
      requiredCredits: dto.required_,
      earned: dto.earned,
      pending: dto.pending,
      remaining: dto.remaining,
      ratio: dto.ratio,
    );
