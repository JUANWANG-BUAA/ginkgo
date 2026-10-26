import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/features/today/today_page.dart';
import 'package:ginkgo_mirror/features/tasks/tasks_page.dart';
import 'package:ginkgo_mirror/features/homework/homework_detail_page.dart';
import 'package:ginkgo_mirror/features/tasks/task_editor.dart';

import 'support.dart' show settle, show;

// Fixed synthetic snapshots: this visual suite must never read credentials,
// initialize native networking, or change task documents.
class VisualService extends Fake implements MirrorService {
  int writes = 0;
  @override
  bool get isDemo => true;

  @override
  Future<TodayResponse> today({bool forceRefresh = false}) async =>
      const TodayResponse(
        date: '2026-10-22',
        courses: [
          TodayCourse(name: '算法设计与分析', place: '新主楼 A101', time: '08:00-09:35'),
          TodayCourse(name: '操作系统', place: '主楼 B202', time: '10:00-11:35'),
        ],
      );

  static const assignment = HomeworkItem(
    id: 'spoc:visual-report',
    title: '完成实验报告与结果分析',
    courseName: '操作系统 · 合成课程',
    dueAt: '2026-10-23T18:30:00+08:00',
    status: HomeworkStatus.pending,
  );

  @override
  Future<HomeworkResponse> homework({bool forceRefresh = false}) async =>
      const HomeworkResponse(
        termName: '合成学期',
        termCode: 'synthetic',
        items: [assignment],
      );

  @override
  Future<HomeworkDetailResponse> homeworkDetail(
    String assignmentId, {
    bool forceRefresh = false,
  }) async => const HomeworkDetailResponse(
    status: '待完成',
    stale: false,
    dueAt: '2026-10-23T18:30:00+08:00',
    publishedAt: '2026-10-20 09:00:00',
    content: '''请整理实验过程、关键结果与分析结论。

1. 记录实验环境与操作步骤。
2. 对比结果并说明原因。
3. 完成后到学校平台提交。''',
  );

  @override
  Future<ReadOnlyResponse> editTasks({
    required String root,
    required String action,
    String? id,
    String? title,
    String? due,
    bool? completed,
  }) async {
    if (action != 'load') {
      writes++;
      throw StateError('Visual suite attempted a task mutation');
    }
    return ReadOnlyResponse(
      stale: false,
      payload: jsonEncode([
        {
          'id': 'visual-linked',
          'title': '整理操作系统实验报告',
          'due': '2026-10-23T18:30:00+08:00',
          'completed': false,
          'source': {'kind': 'homework', 'assignment_id': 'spoc:visual-report'},
        },
        {
          'id': 'visual-personal',
          'title': '预习下一章课程内容',
          'due': '',
          'completed': false,
        },
        {
          'id': 'visual-complete',
          'title': '阅读课程参考资料',
          'due': '2026-10-21',
          'completed': true,
        },
      ]),
    );
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  var converted = false;
  Future<void> capture(WidgetTester tester, String name) async {
    await settle(tester, frames: 5);
    expect(tester.takeException(), isNull);
    if (!converted) {
      await binding.convertFlutterSurfaceToImage();
      converted = true;
    }
    await binding.takeScreenshot(name);
  }

  testWidgets('iOS inspired visual matrix preserves read-only page behavior', (
    tester,
  ) async {
    final service = VisualService();
    final originalScale = tester.platformDispatcher.textScaleFactor;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final mode in [Brightness.light, Brightness.dark]) {
      final name = mode.name;
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        ginkgoApp(
          brightness: mode,
          home: TodayPage(
            service: service,
            storageRoot: '/synthetic-visual-only',
            accountId: 'synthetic-visual',
            now: () => DateTime.utc(2026, 10, 22, 1, 40),
          ),
        ),
      );
      await settle(tester, frames: 20);
      await capture(tester, 'ios-visual-today-$name');
      await show(
        tester,
        find.byKey(const Key('today-task-visual-linked')),
        scrollKey: 'today-scroll',
      );
      await capture(tester, 'ios-visual-today-actions-$name');

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        ginkgoApp(
          brightness: mode,
          home: TasksPage(
            service: service,
            academicService: service,
            storageRoot: '/synthetic-visual-only',
            initialTaskId: 'visual-linked',
          ),
        ),
      );
      await settle(tester, frames: 20);
      // initialTaskId may scroll a few points to locate the first row; capture
      // the settled page top, not a partially collapsed navigation-title frame.
      final tasksScroll = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(const Key('tasks-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      tasksScroll.position.jumpTo(tasksScroll.position.minScrollExtent);
      await capture(tester, 'ios-visual-tasks-$name');

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        ginkgoApp(
          brightness: mode,
          home: HomeworkDetailPage(
            item: VisualService.assignment,
            service: service,
            taskService: service,
            storageRoot: '/synthetic-visual-only',
          ),
        ),
      );
      await settle(tester, frames: 20);
      await capture(tester, 'ios-visual-homework-$name');
      await tester.ensureVisible(find.byKey(const Key('homework-add-task')));
      await capture(tester, 'ios-visual-homework-action-$name');

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        ginkgoApp(
          brightness: mode,
          home: TaskEditor(
            title: '整理操作系统实验报告',
            due: '2026-10-23T18:30:00+08:00',
            sourceAssignmentId: 'spoc:visual-report',
            onSave: (_) async {
              throw StateError('Visual suite attempted an editor save');
            },
          ),
        ),
      );
      await settle(tester, frames: 15);
      await capture(tester, 'ios-visual-editor-$name');
    }

    tester.platformDispatcher.textScaleFactorTestValue = 2;
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      ginkgoApp(
        brightness: Brightness.dark,
        home: TasksPage(
          service: service,
          storageRoot: '/synthetic-visual-only',
          initialTaskId: 'visual-linked',
        ),
      ),
    );
    await settle(tester, frames: 20);
    // Keep this crop on actual large-type task content below the pinned bar.
    final largeScroll = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(const Key('tasks-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    largeScroll.position.jumpTo(largeScroll.position.pixels + 24);
    await capture(tester, 'ios-visual-tasks-large-type');
    expect(service.writes, 0);
    tester.platformDispatcher.textScaleFactorTestValue = originalScale;
    await tester.pumpWidget(const SizedBox());
    await settle(tester, frames: 3);
  });
}
