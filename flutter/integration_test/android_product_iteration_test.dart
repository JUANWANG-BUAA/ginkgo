import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/src/rust/frb_generated.dart';
import 'package:ginkgo_mirror/features/tasks/tasks_page.dart';
import 'package:ginkgo_mirror/features/today/today_page.dart';
import 'package:ginkgo_mirror/features/homework/homework_detail_page.dart';
import 'package:ginkgo_mirror/application/contracts.dart';

import 'support.dart' show settle, show;
import 'package:ginkgo_mirror/infrastructure/demo_mirror_service.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  setUpAll(() async => RustLib.init());

  var surfaceConverted = false;
  Future<void> capture(String name) async {
    // Synthetic UI evidence only; test_driver/integration_test.dart exports PNGs.
    if (!Platform.isAndroid) return;
    if (!surfaceConverted) {
      await binding.convertFlutterSurfaceToImage();
      surfaceConverted = true;
    }
    await binding.takeScreenshot(name);
  }

  testWidgets('Today opens a native local task and reloads after completion', (
    tester,
  ) async {
    const service = DemoMirrorService();
    final directory = await Directory.systemTemp.createTemp(
      'ginkgo-android-today-ui-',
    );
    try {
      final added = await service.editTasks(
        root: directory.path,
        action: 'add_homework',
        id: 'spoc:synthetic-today-one',
        title: '设备首页待办',
        due: '',
      );
      expect(added.failure, isNull);
      final taskId =
          ((jsonDecode(added.payload!) as List).single as Map)['id'] as String;
      await tester.pumpWidget(
        ginkgoApp(
          home: TodayPage(
            service: service,
            storageRoot: directory.path,
            accountId: 'synthetic-demo-device',
          ),
        ),
      );
      await settle(tester, frames: 35);
      await capture('ginkgo-today-v2-top');
      final row = find.byKey(Key('today-task-$taskId'));
      await show(tester, row, scrollKey: 'today-scroll');
      await capture('ginkgo-today-v2-tasks');
      await tester.tap(row);
      await settle(tester, frames: 20);
      expect(find.byKey(Key('task-row-$taskId')), findsOneWidget);
      await capture('ginkgo-linked-task');
      final toggle = find.byKey(Key('task-toggle-$taskId'));
      await show(tester, toggle, scrollKey: 'tasks-scroll');
      await tester.tap(toggle);
      await settle(tester, frames: 20);
      await tester.tap(find.byType(CupertinoNavigationBarBackButton).first);
      await settle(tester, frames: 25);
      expect(find.byKey(Key('today-task-$taskId')), findsNothing);
      final result = await service.editTasks(
        root: directory.path,
        action: 'load',
      );
      expect(
        ((jsonDecode(result.payload!) as List).single as Map)['completed'],
        isTrue,
      );
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(ginkgoApp(home: const SizedBox()));
      await settle(tester, frames: 3);
      await directory.delete(recursive: true);
    }
  });

  testWidgets('homework detail adds and opens a linked task on Android', (
    tester,
  ) async {
    const service = DemoMirrorService();
    final directory = await Directory.systemTemp.createTemp(
      'ginkgo-android-homework-ui-',
    );
    try {
      await tester.pumpWidget(
        ginkgoApp(
          home: HomeworkDetailPage(
            service: service,
            storageRoot: directory.path,
            item: const HomeworkItem(
              id: 'spoc:synthetic-ui-one',
              courseName: '合成设备课程',
              title: '合成设备作业转待办',
              dueAt: '2026-10-25T18:30:00+08:00',
              status: HomeworkStatus.pending,
            ),
          ),
        ),
      );
      await settle(tester, frames: 30);
      await tester.ensureVisible(find.byKey(const Key('homework-add-task')));
      await tester.tap(find.byKey(const Key('homework-add-task')));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('task-title')), '设备编辑后待办');
      await tester.tap(find.byKey(const Key('task-save')));
      await settle(tester, frames: 30);
      final result = await service.editTasks(
        root: directory.path,
        action: 'load',
      );
      expect(result.failure, isNull);
      final rows = (jsonDecode(result.payload!) as List)
          .cast<Map<String, dynamic>>();
      expect(rows, hasLength(1));
      expect(rows.single['title'], '设备编辑后待办');
      expect(rows.single['source'], {
        'kind': 'homework',
        'assignment_id': 'spoc:synthetic-ui-one',
      });
      await tester.ensureVisible(find.byKey(const Key('homework-view-task')));
      await tester.tap(find.byKey(const Key('homework-view-task')));
      await settle(tester, frames: 30);
      expect(find.text('设备编辑后待办'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(ginkgoApp(home: const SizedBox()));
      await settle(tester, frames: 3);
      await directory.delete(recursive: true);
    }
  });

  testWidgets(
    'homework-linked tasks persist across native bridge without school writes',
    (tester) async {
      const service = DemoMirrorService();
      final directory = await Directory.systemTemp.createTemp(
        'ginkgo-android-product-',
      );
      try {
        Future<List<Map<String, dynamic>>> command(
          String action, {
          String? id,
          String? title,
          String? due,
          bool? completed,
        }) async {
          final result = await service.editTasks(
            root: directory.path,
            action: action,
            id: id,
            title: title,
            due: due,
            completed: completed,
          );
          expect(result.failure, isNull);
          expect(result.payload, isNotNull);
          return (jsonDecode(result.payload!) as List)
              .cast<Map<String, dynamic>>();
        }

        final added = await command(
          'add_homework',
          id: 'spoc:synthetic-device-one',
          title: '合成设备关联作业',
          due: '2026-10-25T18:30:00+08:00',
        );
        expect(added, hasLength(1));
        final taskId = added.single['id'] as String;
        expect(added.single['source'], {
          'kind': 'homework',
          'assignment_id': 'spoc:synthetic-device-one',
        });
        await command('update', id: taskId, title: '用户编辑后的合成待办', due: '');
        await command('toggle', id: taskId, completed: true);
        final duplicate = await command(
          'add_homework',
          id: 'spoc:synthetic-device-one',
          title: '不应覆盖用户标题',
          due: '2026-11-01',
        );
        expect(duplicate, hasLength(1));
        expect(duplicate.single['title'], '用户编辑后的合成待办');
        expect(duplicate.single['due'], '');
        expect(duplicate.single['completed'], isTrue);
        await tester.pumpWidget(
          ginkgoApp(
            home: TasksPage(
              demo: true,
              service: service,
              storageRoot: directory.path,
              initialTaskId: taskId,
            ),
          ),
        );
        await settle(tester, frames: 35);
        expect(find.text('用户编辑后的合成待办'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(ginkgoApp(home: const SizedBox()));
        await settle(tester, frames: 3);
        final reloaded = await command('load');
        expect(reloaded.single['id'], taskId);
        expect(reloaded.single['source'], duplicate.single['source']);
        // The isolated demo capability is deliberately unable to submit school writes.
        final blocked = await service.submitCheckin('synthetic-device-course');
        expect(blocked.state, 'notSubmitted');
      } finally {
        await tester.pumpWidget(ginkgoApp(home: const SizedBox()));
        await settle(tester, frames: 3);
        await directory.delete(recursive: true);
      }
    },
  );
}
