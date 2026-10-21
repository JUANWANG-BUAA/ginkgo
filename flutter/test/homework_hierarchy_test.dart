import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/homework_page.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/src/rust/api/live.dart';
import 'package:ginkgo_mirror/src/rust/api/mirror.dart';

import 'mirror_widget_test.dart' show ControlledService;

class HomeworkHierarchyService extends ControlledService {
  int listCalls = 0;
  bool failRefresh = false;
  final detailCalls = <String>[];
  @override
  Future<HomeworkResponse> homework({bool forceRefresh = false}) async {
    listCalls++;
    if (failRefresh) throw StateError('synthetic network failure');
    return HomeworkResponse(
      termName: '合成学期',
      termCode: 'synthetic',
      items: [
        for (var index = 0; index < 500; index++)
          HomeworkItem(
            id: 'spoc:$index',
            title: '合成作业 $index',
            courseName: '合成课程 $index',
            teacherName: '合成教师 $index',
            dueAt: '2099-11-10T01:00:00Z',
            status: HomeworkStatus.pending,
          ),
      ],
    );
  }

  @override
  Future<HomeworkDetailResponse> homeworkDetail(
    String assignmentId, {
    bool forceRefresh = false,
  }) async {
    detailCalls.add(assignmentId);
    return const HomeworkDetailResponse(
      status: '待完成',
      stale: false,
      content: '合成作业说明，逐项完成后在 SPOC 提交。',
      dueAt: '2099-11-10T02:00:00Z',
      publishedAt: '2099-11-01 08:00:00',
    );
  }
}

void main() {
  testWidgets(
    'homework lazily builds rows and retains search through detail and failed refresh',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = HomeworkHierarchyService();
      await tester.pumpWidget(ginkgoApp(home: HomeworkPage(service: service)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('homework-spoc:0')), findsOneWidget);
      expect(find.byKey(const Key('homework-spoc:499')), findsNothing);
      await tester.enterText(
        find.byKey(const Key('homework-search')),
        '合成教师 499',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('homework-spoc:499')), findsOneWidget);
      expect(find.byKey(const Key('homework-spoc:0')), findsNothing);
      expect(find.text('截止 11月10日 09:00'), findsOneWidget);
      await tester.tap(find.byKey(const Key('homework-spoc:499')));
      await tester.pumpAndSettle();
      expect(service.detailCalls, ['499']);
      expect(
        find.byKey(const Key('homework-deadline-summary')),
        findsOneWidget,
      );
      expect(find.text('11月10日 10:00'), findsOneWidget);
      expect(find.text('合成作业说明，逐项完成后在 SPOC 提交。'), findsOneWidget);
      await tester.longPress(find.text('合成作业说明，逐项完成后在 SPOC 提交。'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('作业详情'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CupertinoNavigationBarBackButton));
      await tester.pumpAndSettle();
      final search = tester.widget<CupertinoSearchTextField>(
        find.byKey(const Key('homework-search')),
      );
      expect(search.controller!.text, '合成教师 499');
      expect(service.listCalls, 1);
      service.failRefresh = true;
      final refresh = tester.widget<CupertinoSliverRefreshControl>(
        find.byType(CupertinoSliverRefreshControl, skipOffstage: false),
      );
      await refresh.onRefresh!();
      await tester.pumpAndSettle();
      expect(find.textContaining('正在显示上次结果'), findsOneWidget);
      expect(find.text('合成作业 499'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'homework wraps deadline and long titles at accessibility sizes',
    (tester) async {
      tester.view.physicalSize = const Size(360, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ginkgoApp(
          brightness: Brightness.dark,
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(1.8),
              disableAnimations: true,
            ),
            child: HomeworkPage(service: HomeworkHierarchyService()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('homework-search')),
        220,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('homework-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.enterText(
        find.byKey(const Key('homework-search')),
        '合成作业 499',
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('homework-spoc:499')),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('homework-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('截止 11月10日 09:00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
