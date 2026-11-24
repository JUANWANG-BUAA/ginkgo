import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/evaluation.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/features/evaluation/evaluation_page.dart';
import 'package:ginkgo_mirror/main.dart';

class _FakeEvaluationGateway implements TeachingEvaluationGateway {
  final responses = <Completer<TeachingEvaluationRead>>[];
  final refreshArgs = <bool>[];

  @override
  Future<TeachingEvaluationRead> loadTeachingEvaluation({
    bool forceRefresh = false,
  }) {
    refreshArgs.add(forceRefresh);
    final completer = Completer<TeachingEvaluationRead>();
    responses.add(completer);
    return completer.future;
  }
}

class _FakeOfficialLinks implements StudentServiceLinksGateway {
  @override
  String? studentServiceUrl(String id) =>
      id == 'official-evaluation' ? 'https://example.invalid/pjxt' : null;
}

void main() {
  testWidgets(
    'loads evaluation summary and course statuses in read-only mode without submit controls',
    (tester) async {
      final gateway = _FakeEvaluationGateway();
      await tester.pumpWidget(
        ginkgoApp(
          home: EvaluationPage(
            gateway: gateway,
            officialLinks: _FakeOfficialLinks(),
          ),
        ),
      );

      expect(gateway.refreshArgs, [false]);
      gateway.responses.single.complete(
        const TeachingEvaluationRead(
          data: TeachingEvaluationReport(
            taskId: 'RW1',
            taskName: '2026秋季评教',
            term: '2026-20271',
            courses: [
              EvaluationCourseItem(
                id: 'C1',
                courseName: '编译原理',
                teacherName: '李文',
                questionnaireName: '理论课',
                status: EvaluationCourseStatus.pending,
              ),
              EvaluationCourseItem(
                id: 'C2',
                courseName: '计算机网络',
                teacherName: '张敏',
                questionnaireName: '理论课',
                status: EvaluationCourseStatus.completed,
              ),
            ],
            fetchedAt: '2026-11-23T11:30:00+08:00',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('编译原理'), findsOneWidget);
      expect(find.text('计算机网络'), findsOneWidget);
      expect(find.text('未评教'), findsWidgets);
      expect(find.text('已评教'), findsWidgets);
      expect(find.byKey(const Key('evaluation-official-link')), findsOneWidget);
      expect(find.text('提交评教'), findsNothing);
    },
  );

  testWidgets(
    'preserves stale snapshot on refresh failure and shows confirmed empty state when no task exists',
    (tester) async {
      final gateway = _FakeEvaluationGateway();
      await tester.pumpWidget(
        ginkgoApp(home: EvaluationPage(gateway: gateway)),
      );
      gateway.responses[0].complete(
        const TeachingEvaluationRead(
          data: TeachingEvaluationReport(
            courses: [],
            fetchedAt: '2026-11-23T11:35:00+08:00',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('当前暂无待评教任务'), findsOneWidget);

      await tester.tap(find.byKey(const Key('evaluation-refresh')));
      await tester.pump();
      expect(gateway.refreshArgs, [false, true]);
      gateway.responses[1].complete(
        const TeachingEvaluationRead(
          data: TeachingEvaluationReport(
            courses: [],
            fetchedAt: '2026-11-23T11:35:00+08:00',
            fromCache: true,
            stale: true,
          ),
          failure: FailureCode.serviceUnavailable,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('旧快照'), findsOneWidget);
    },
  );
}
