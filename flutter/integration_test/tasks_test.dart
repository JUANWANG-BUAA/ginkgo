import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ginkgo_mirror/tasks_page.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/src/rust/frb_generated.dart';

import 'support.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  setUpAll(() async => RustLib.init());
  testWidgets('local tasks create edit complete persist and delete', (
    tester,
  ) async {
    Future<void> tapTask(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await settle(tester, frames: 3);
      await tester.tap(finder);
      await settle(tester);
    }

    final directory = await Directory.systemTemp.createTemp(
      'ginkgo-tasks-smoke',
    );
    try {
      await tester.pumpWidget(
        ginkgoApp(home: TasksPage(demo: true, storageRoot: directory.path)),
      );
      await settle(tester);
      await tapTask(tester, find.bySemanticsLabel('新增待办'));
      await tester.enterText(find.byKey(const Key('task-title')), '合成设备待办');
      await tapTask(tester, find.byKey(const Key('task-save')));
      expect(find.text('合成设备待办'), findsOneWidget);
      await tapTask(
        tester,
        find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith('task-edit-'),
        ),
      );
      await tester.enterText(find.byKey(const Key('task-title')), '修改设备待办');
      await tapTask(tester, find.byKey(const Key('task-save')));
      await tapTask(
        tester,
        find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'task-toggle-',
              ),
        ),
      );
      expect(find.text('已完成'), findsOneWidget);
      await tester.pumpWidget(ginkgoApp(home: const SizedBox()));
      await settle(tester);
      await tester.pumpWidget(
        ginkgoApp(home: TasksPage(demo: true, storageRoot: directory.path)),
      );
      await settle(tester);
      expect(find.text('修改设备待办'), findsOneWidget);
      expect(find.text('已完成'), findsOneWidget);
      await tapTask(
        tester,
        find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'task-delete-',
              ),
        ),
      );
      await tapTask(tester, find.widgetWithText(CupertinoDialogAction, '删除'));
      expect(find.text('暂无待办'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
