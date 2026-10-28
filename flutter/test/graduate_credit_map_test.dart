import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/features/graduate/graduate_credit_map_page.dart';
import 'package:ginkgo_mirror/infrastructure/graduate_credit_map_payload.dart';

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

void main() {
  test('failed empty envelope stays unknown and authentication never stale-resolves', () {
    expect(
      decodeGraduateCreditMapRead(const ReadOnlyResponse(stale: false))
          .issue!
          .kind,
      GraduateCreditIssueKind.unknown,
    );
    final result = decodeGraduateCreditMapRead(
      ReadOnlyResponse(
        payload: jsonEncode(payload()),
        stale: true,
        failure: FailureCode.sessionExpired,
      ),
    );
    expect(result.data, isNull);
    expect(result.issue!.kind, GraduateCreditIssueKind.authentication);
    final changed = decodeGraduateCreditMapRead(
      ReadOnlyResponse(
        payload: jsonEncode(payload()),
        stale: true,
        failure: FailureCode.changedResponse,
      ),
    );
    expect(changed.data, isNotNull);
    expect(changed.stale, isTrue);
    expect(changed.issue!.kind, GraduateCreditIssueKind.protocolChanged);
  });
  testWidgets('authentication expiry clears previously successful report', (
    tester,
  ) async {
    var first = true;
    final service = FakeMap((_) async {
      if (first) {
        first = false;
        return GraduateCreditMapRead(data: data('私人旧报告'));
      }
      return const GraduateCreditMapRead(
        issue: GraduateCreditReadIssue(GraduateCreditIssueKind.authentication),
      );
    });
    await tester.pumpWidget(
      CupertinoApp(home: GraduateCreditMapPage(service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.text('私人旧报告'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('刷新学分地图'));
    await tester.pumpAndSettle();
    expect(find.text('私人旧报告'), findsNothing);
    expect(find.textContaining('需要重新登录'), findsOneWidget);
  });
  test('decoder preserves missing metrics and explicit zero without local arithmetic', () {
    final report = decodeGraduateCreditMap(
      payload(
        summary: node(
          progress: {
            'state': 'unknown',
            'required': 32,
            'earned': null,
            'pending': 0,
            'remaining': null,
            'ratio': null,
          },
        ),
      ),
    );
    final metrics = report.summary!.progress!;
    expect(metrics.requiredCredits, 32);
    expect(metrics.earned, isNull);
    expect(metrics.pending, 0);
    expect(metrics.remaining, isNull);
    expect(metrics.ratio, isNull);
    expect(metrics.state, GraduateCreditState.unknown);
    expect(() => report.nodes.add(report.summary!), throwsUnsupportedError);
  });
  test(
    'decoder rejects invalid projection instead of manufacturing a zero',
    () {
      expect(
        () => decodeGraduateCreditMap(
          payload(
            summary: node(progress: {'state': 'unknown', 'required': -1}),
          ),
        ),
        throwsFormatException,
      );
      expect(
        () => decodeGraduateCreditMap(
          payload(summary: node(progress: {'state': 'unknown', 'ratio': 2})),
        ),
        throwsFormatException,
      );
      expect(
        () => decodeGraduateCreditMap({'summary': null}),
        throwsA(anything),
      );
    },
  );
  test('only real changedResponse flags protocol change; other failures stay separate', () {
    expect(
      GraduateCreditReadIssue.fromFailure(FailureCode.changedResponse)!.kind,
      GraduateCreditIssueKind.protocolChanged,
    );
    expect(
      GraduateCreditReadIssue.fromFailure(FailureCode.sessionExpired)!.kind,
      GraduateCreditIssueKind.authentication,
    );
    expect(
      GraduateCreditReadIssue.fromFailure(FailureCode.serviceUnavailable)!.kind,
      GraduateCreditIssueKind.unavailable,
    );
    expect(
      GraduateCreditReadIssue.fromFailure(FailureCode.unsupportedContract)!
          .kind,
      GraduateCreditIssueKind.unsupported,
    );
    expect(
      GraduateCreditReadIssue.fromFailure(FailureCode.invalidRequest)!.kind,
      GraduateCreditIssueKind.unknown,
    );
    expect(GraduateCreditReadIssue.fromFailure(null), isNull);
  });
  testWidgets(
    'renders Rust projection unknowns and explicit lack of minimum distinctly',
    (tester) async {
      final service = FakeMap(
        (_) async => GraduateCreditMapRead(
          data: decodeGraduateCreditMap(
            payload(
              summary: node(
                progress: {
                  'state': 'noMinimum',
                  'required': 0,
                  'earned': null,
                  'pending': null,
                  'remaining': null,
                  'ratio': null,
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(
        CupertinoApp(
          home: GraduateCreditMapPage(service: service, accountId: 'synthetic'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('本项无最低学分要求'), findsOneWidget);
      expect(find.text('未确认'), findsNWidgets(3));
      expect(find.text('0%'), findsNothing);
    },
  );
  testWidgets(
    'failed refresh retains previous report, successful empty replaces it',
    (tester) async {
      var count = 0;
      final service = FakeMap(
        (_) async => switch (count++) {
          0 => GraduateCreditMapRead(data: data('旧报告')),
          1 => const GraduateCreditMapRead(
            issue: GraduateCreditReadIssue(
              GraduateCreditIssueKind.protocolChanged,
            ),
          ),
          _ => GraduateCreditMapRead(data: GraduateCreditMap()),
        },
      );
      await tester.pumpWidget(
        CupertinoApp(home: GraduateCreditMapPage(service: service)),
      );
      await tester.pumpAndSettle();
      expect(find.text('旧报告'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('刷新学分地图'));
      await tester.pumpAndSettle();
      expect(find.text('旧报告'), findsOneWidget);
      expect(find.textContaining('接口返回结构已变化'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('刷新学分地图'));
      await tester.pumpAndSettle();
      expect(find.text('旧报告'), findsNothing);
      expect(find.text('学校返回的执行报告暂无条目'), findsOneWidget);
    },
  );
  testWidgets(
    'account change drops late report and does not retain private old value',
    (tester) async {
      final old = Completer<GraduateCreditMapRead>();
      var count = 0;
      final service = FakeMap(
        (_) => count++ == 0
            ? old.future
            : Future.value(GraduateCreditMapRead(data: data('新报告'))),
      );
      await tester.pumpWidget(
        CupertinoApp(
          home: GraduateCreditMapPage(service: service, accountId: 'a'),
        ),
      );
      await tester.pump();
      await tester.pumpWidget(
        CupertinoApp(
          home: GraduateCreditMapPage(service: service, accountId: 'b'),
        ),
      );
      await tester.pumpAndSettle();
      old.complete(GraduateCreditMapRead(data: data('迟到报告')));
      await tester.pumpAndSettle();
      expect(find.text('新报告'), findsOneWidget);
      expect(find.text('迟到报告'), findsNothing);
    },
  );
  testWidgets(
    'timeout is not a protocol failure and unavailable gateway does not query',
    (tester) async {
      final service = FakeMap(
        (_) => Future.error(TimeoutException('synthetic')),
      );
      await tester.pumpWidget(
        CupertinoApp(home: GraduateCreditMapPage(service: service)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('读取超时'), findsOneWidget);
      expect(find.textContaining('接口返回结构已变化'), findsNothing);
      await tester.pumpWidget(
        CupertinoApp(home: const GraduateCreditMapPage(service: null)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('未发起学校读取'), findsOneWidget);
      expect(service.calls, 1);
    },
  );
}
