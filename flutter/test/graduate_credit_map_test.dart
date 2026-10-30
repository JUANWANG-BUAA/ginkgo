import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/infrastructure/graduate_credit_map_payload.dart';
import 'package:ginkgo_mirror/src/rust/api/live.dart' as live;

Map<String, Object?> node({
  String title = '合成类别',
  Map<String, Object?>? progress,
}) => {
  'sourceIndex': 0,
  'title': title,
  'progress': progress,
  'rows': <Object?>[],
};
Map<String, Object?> payload({Map<String, Object?>? summary}) => {
  'summary': summary,
  'nodes': <Object?>[],
  'notice': null,
};
GraduateCreditMap data(String title) => GraduateCreditMap(
  summary: GraduateCreditNode(
    sourceIndex: 0,
    title: title,
    rows: [GraduateCreditRow(title: title, detail: '合成报告原文', isCourse: false)],
  ),
);

class FakeMap implements GraduateCreditMapGateway {
  FakeMap(this.read);
  final Future<GraduateCreditMapRead> Function(bool) read;
  int calls = 0;
  @override
  Future<GraduateCreditMapRead> graduateCreditMap({bool forceRefresh = false}) {
    calls++;
    return read(forceRefresh);
  }
}

live.GraduateCreditMapDto _mapDto() =>
    const live.GraduateCreditMapDto(nodes: []);

void main() {
  test(
    'a failed read stays unknown and authentication never stale-resolves',
    () {
      expect(
        decodeGraduateCreditMapRead(const live.GraduateCreditMapResponse())
            .issue!
            .kind,
        GraduateCreditIssueKind.unknown,
      );
      final auth = decodeGraduateCreditMapRead(
        live.GraduateCreditMapResponse(
          data: _mapDto(),
          failure: FailureCode.sessionExpired,
        ),
      );
      expect(auth.data, isNull);
      expect(auth.issue!.kind, GraduateCreditIssueKind.authentication);
      final changed = decodeGraduateCreditMapRead(
        live.GraduateCreditMapResponse(
          data: _mapDto(),
          failure: FailureCode.changedResponse,
        ),
      );
      expect(changed.data, isNotNull);
      expect(changed.stale, isTrue);
      expect(changed.issue!.kind, GraduateCreditIssueKind.protocolChanged);
    },
  );
  test('decoder preserves missing metrics and explicit zero without local arithmetic', () {
    final report = decodeGraduateCreditMapRead(
      live.GraduateCreditMapResponse(
        data: live.GraduateCreditMapDto(
          summary: live.GraduateCreditNodeDto(
            sourceIndex: 0,
            title: '培养方案执行报告',
            rows: const [],
            progress: const live.GraduateCreditMetricsDto(
              state: live.GraduateCreditStateDto.unknown,
              required_: 32,
              earned: null,
              pending: 0,
              remaining: null,
              ratio: null,
            ),
          ),
          nodes: const [],
        ),
      ),
    ).data!;
    final metrics = report.summary!.progress!;
    expect(metrics.requiredCredits, 32);
    // A missing value stays missing; an explicit zero stays zero.
    expect(metrics.earned, isNull);
    expect(metrics.pending, 0);
    expect(metrics.remaining, isNull);
    expect(metrics.ratio, isNull);
    expect(metrics.state, GraduateCreditState.unknown);
    expect(() => report.nodes.add(report.summary!), throwsUnsupportedError);
  });
}
