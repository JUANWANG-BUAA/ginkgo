import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/task_storage_scope.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/features/tasks/task_editor.dart';
import 'package:ginkgo_mirror/features/tasks/tasks_page.dart';
import 'package:ginkgo_mirror/application/local_tasks_read.dart';

import 'local_tasks_read_fixture.dart';

import 'task_link_widget_test.dart' show TaskFake, record, press, phone;
import 'task_visual_test.dart' show visualApp, narrowPhone, expectTouchTarget;
import 'platform_actions_fake.dart';

void main() {
  testWidgets('task storage location is supplied by the composition scope', (
    tester,
  ) async {
    phone(tester);
    final fake = TaskFake();
    await tester.pumpWidget(
      ginkgoApp(
        home: TaskStorageScope(
          resolve: () async => '/injected/tasks',
          child: TasksPage(fileActions: platformActions,service: fake),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(fake.roots, ['/injected/tasks']);
    expect(fake.calls, ['load']);
  });

  testWidgets(
    'storage resolution failure does not read or invent empty tasks',
    (tester) async {
      phone(tester);
      final fake = TaskFake();
      await tester.pumpWidget(
        ginkgoApp(
          home: TaskStorageScope(
            resolve: () async => throw StateError('storage unavailable'),
            child: TasksPage(fileActions: platformActions,service: fake),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(fake.calls, isEmpty);
      expect(find.text('待办读取或保存未确认，请刷新核对后再编辑。'), findsOneWidget);
    },
  );

  testWidgets('completed deadlines merge and stay collapsed until requested', (
    tester,
  ) async {
    phone(tester);
    final fake = TaskFake()
      ..rows.addAll([
        record('pending', title: '仍待完成'),
        record('dated', title: '已完成有截止', due: '2026-10-22', completed: true),
        record('undated', title: '已完成无截止', completed: true),
      ]);
    await tester.pumpWidget(
      ginkgoApp(
        home: TasksPage(fileActions: platformActions,service: fake, storageRoot: '/synthetic'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('已完成（2）'), findsOneWidget);
    expect(find.byKey(const Key('tasks-completed-section')), findsOneWidget);
    expect(find.text('已完成有截止'), findsNothing);
    expect(find.text('已完成无截止'), findsNothing);
    expect(find.text('仍待完成'), findsOneWidget);
    await press(tester, 'tasks-completed-toggle');
    expect(find.text('已完成有截止'), findsOneWidget);
    expect(find.text('已完成无截止'), findsOneWidget);
    await press(tester, 'task-toggle-undated');
    expect(fake.calls, ['load', 'toggle']);
    expect(fake.rows.last['completed'], isFalse);
    expect(find.text('已完成（1）'), findsOneWidget);
    await press(tester, 'tasks-completed-toggle');
    expect(find.text('已完成有截止'), findsNothing);
    expect(find.text('已完成无截止'), findsOneWidget);
  });

  testWidgets(
    'more menu preserves edit cancel and explicit delete confirmation',
    (tester) async {
      phone(tester);
      final fake = TaskFake()..rows.add(record('one', title: '合成待办'));
      await tester.pumpWidget(
        ginkgoApp(
          home: TasksPage(fileActions: platformActions,service: fake, storageRoot: '/synthetic'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('本机完成'), findsOneWidget);
      expect(find.text('更多'), findsOneWidget);
      expect(find.text('编辑'), findsNothing);
      expect(find.text('删除'), findsNothing);
      await press(tester, 'task-more-one');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsNothing);
      expect(find.byType(TasksPage), findsOneWidget);
      expect(fake.calls, ['load']);
      await press(tester, 'task-more-one');
      await press(tester, 'task-edit-one');
      expect(find.byType(TaskEditor), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(fake.calls, ['load']);
      await press(tester, 'task-more-one');
      await press(tester, 'task-delete-one');
      expect(find.text('删除待办？'), findsOneWidget);
      expect(fake.calls, ['load']);
      await tester.tap(find.widgetWithText(CupertinoDialogAction, '取消'));
      await tester.pumpAndSettle();
      expect(fake.rows, hasLength(1));
      await press(tester, 'task-more-one');
      await press(tester, 'task-delete-one');
      await tester.tap(find.widgetWithText(CupertinoDialogAction, '删除'));
      await tester.pumpAndSettle();
      expect(fake.calls, ['load', 'delete']);
      expect(find.text('暂无待办'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'secondary refresh preserves old rows and blocks duplicate load',
    (tester) async {
      phone(tester);
      final fake = TaskFake()..rows.add(record('one'));
      await tester.pumpWidget(
        ginkgoApp(
          home: TasksPage(fileActions: platformActions,service: fake, storageRoot: '/synthetic'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('刷新待办'), findsNothing);
      expectTouchTarget(tester, 'tasks-more');
      expectTouchTarget(tester, 'tasks-add');
      await press(tester, 'tasks-more');
      expectTouchTarget(tester, 'tasks-refresh');
      final pending = Completer<LocalTasksRead>();
      fake.pendingLoad = pending;
      await tester.tap(find.byKey(const Key('tasks-refresh')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(fake.calls, ['load', 'load']);
      expect(find.byKey(const Key('task-row-one')), findsOneWidget);
      expect(
        tester
            .widget<CupertinoButton>(find.byKey(const Key('tasks-more')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<CupertinoButton>(find.byKey(const Key('task-more-one')))
            .onPressed,
        isNull,
      );
      pending.complete(tasksRead(fake.rows));
      await tester.pumpAndSettle();
      expect(fake.calls, ['load', 'load']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an open menu cannot mutate a replacement account', (
    tester,
  ) async {
    phone(tester);
    final old = TaskFake()..rows.add(record('same'));
    final next = TaskFake()..rows.add(record('same', title: '新账号合成待办'));
    final current = ValueNotifier<TaskFake>(old);
    addTearDown(current.dispose);
    await tester.pumpWidget(
      ginkgoApp(
        home: ValueListenableBuilder<TaskFake>(
          valueListenable: current,
          builder: (_, gateway, _) => TasksPage(fileActions: platformActions,
            service: gateway,
            storageRoot: gateway == old ? '/old' : '/next',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await press(tester, 'task-more-same');
    current.value = next;
    await tester.pumpAndSettle();
    await press(tester, 'task-delete-same');
    expect(find.byType(CupertinoAlertDialog), findsNothing);
    expect(old.calls, ['load']);
    expect(next.calls, ['load']);
    expect(find.text('新账号合成待办'), findsOneWidget);
  });

  testWidgets('phone header returns from located task with 48dp target at 2x', (
    tester,
  ) async {
    narrowPhone(tester);
    final fake = TaskFake()..rows.add(record('target', completed: true));
    await tester.pumpWidget(
      visualApp(
        Builder(
          builder: (context) => CupertinoPageScaffold(
            child: CupertinoButton(
              child: const Text('打开待办'),
              onPressed: () => Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: const TextScaler.linear(2)),
                    child: TasksPage(fileActions: platformActions,
                      service: fake,
                      storageRoot: '/synthetic',
                      initialTaskId: 'target',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Brightness.dark,
        2,
      ),
    );
    await tester.tap(find.text('打开待办'));
    await tester.pumpAndSettle();
    expectTouchTarget(tester, 'tasks-back');
    expectTouchTarget(tester, 'tasks-more');
    expectTouchTarget(tester, 'tasks-add');
    expect(
      find.byKey(const Key('task-highlight-target')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('tasks-back')));
    await tester.pumpAndSettle();
    expect(find.text('打开待办'), findsOneWidget);
    expect(fake.calls, ['load']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
    'saving keeps fields editable-off and shows the brand leaf, not a spinner',
    (tester) async {
      phone(tester);
      final pending = Completer<bool>();
      await tester.pumpWidget(
        ginkgoApp(
          home: TaskEditor(title: '合成待办', onSave: (_) => pending.future),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('task-save')));
      await tester.pump();
      expect(
        tester.widget<GinkgoActivity>(find.byType(GinkgoActivity)).size,
        17,
      );
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
      expect(
        tester
            .widget<CupertinoTextField>(find.byKey(const Key('task-title')))
            .enabled,
        isFalse,
      );
      pending.complete(false);
      await tester.pumpAndSettle();
      expect(find.textContaining('保存未确认'), findsOneWidget);
      expect(find.text('合成待办'), findsOneWidget);
      expect(find.byType(GinkgoActivity), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'completed location expands at 320dp 2x in ${brightness.name}',
      (tester) async {
        narrowPhone(tester);
        final fake = TaskFake()
          ..rows.addAll([
            for (var i = 0; i < 12; i++) record('pending:$i', title: '合成待办$i'),
            record('target', title: '已完成的长标题定位目标', completed: true),
          ]);
        Widget page(String? id) => visualApp(
          TasksPage(fileActions: platformActions,
            service: fake,
            storageRoot: '/synthetic',
            initialTaskId: id,
          ),
          brightness,
          2,
        );
        await tester.pumpWidget(page('target'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('task-highlight-target')).hitTestable(),
          findsOneWidget,
        );
        expect(find.text('已完成（1）'), findsOneWidget);
        expectTouchTarget(tester, 'tasks-completed-toggle');
        expectTouchTarget(tester, 'task-more-target');
        await press(tester, 'tasks-completed-toggle');
        expect(find.byKey(const Key('task-row-target')), findsNothing);
        await tester.pumpWidget(page('pending:0'));
        await tester.pumpAndSettle();
        await tester.pumpWidget(page('target'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('task-highlight-target')).hitTestable(),
          findsOneWidget,
        );
        expect(fake.calls, ['load']);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
