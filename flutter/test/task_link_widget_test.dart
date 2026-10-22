import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/homework_detail_page.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/task_editor.dart';
import 'package:ginkgo_mirror/tasks_page.dart';

const assignment = HomeworkItem(
  id: 'spoc:123',
  title: '合成作业',
  courseName: '合成课程',
  dueAt: '2026-10-22T10:30:00Z',
  status: HomeworkStatus.pending,
);

Map<String, dynamic> record(
  String id, {
  String title = '个人修改标题',
  String due = '',
  bool completed = false,
  String? source,
}) => {
  'id': id,
  'title': title,
  'due': due,
  'completed': completed,
  if (source != null) 'source': {'kind': 'homework', 'assignment_id': source},
};

class TaskFake implements CampusGateway, AcademicGateway {
  final rows = <Map<String, dynamic>>[];
  final calls = <String>[];
  final roots = <String>[];
  final detailIds = <String>[];
  bool corrupt = false;
  bool failSave = false;
  List<HomeworkItem> assignments = [assignment];
  Completer<ReadOnlyResponse>? pendingLoad;
  Completer<ReadOnlyResponse>? pendingSave;
  Completer<HomeworkDetailResponse>? pendingDetail;
  @override
  bool get isDemo => true;
  @override
  Future<ReadOnlyResponse> editTasks({
    required String root,
    required String action,
    String? id,
    String? title,
    String? due,
    bool? completed,
  }) async {
    calls.add(action);
    roots.add(root);
    if (action == 'load' && pendingLoad != null) return pendingLoad!.future;
    if (action != 'load' && pendingSave != null) return pendingSave!.future;
    if (action != 'load' && failSave) {
      return const ReadOnlyResponse(stale: false);
    }
    if (action == 'add_homework') {
      if (!rows.any((t) => (t['source'] as Map?)?['assignment_id'] == id)) {
        rows.add(record('local:linked', title: title!, due: due!, source: id));
      }
    } else if (action == 'add') {
      rows.add(record('local:new', title: title!, due: due!));
    } else if (action == 'update') {
      final row = rows.singleWhere((t) => t['id'] == id);
      row['title'] = title;
      row['due'] = due;
    } else if (action == 'toggle') {
      rows.singleWhere((t) => t['id'] == id)['completed'] = completed;
    } else if (action == 'delete') {
      rows.removeWhere((t) => t['id'] == id);
    }
    return ReadOnlyResponse(
      payload: corrupt ? '{}' : jsonEncode(rows),
      stale: false,
    );
  }

  @override
  Future<HomeworkResponse> homework({bool forceRefresh = false}) async =>
      HomeworkResponse(
        termName: '合成学期',
        termCode: 'synthetic',
        items: assignments,
      );
  @override
  Future<HomeworkDetailResponse> homeworkDetail(
    String assignmentId, {
    bool forceRefresh = false,
  }) async {
    detailIds.add(assignmentId);
    return pendingDetail?.future ??
        const HomeworkDetailResponse(
          status: '待完成',
          content: '合成正文',
          stale: false,
        );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected non-local action: ${invocation.memberName}');
}

class AcademicOnly implements AcademicGateway {
  @override
  bool get isDemo => true;
  @override
  Future<HomeworkDetailResponse> homeworkDetail(
    String assignmentId, {
    bool forceRefresh = false,
  }) async => const HomeworkDetailResponse(status: '待完成', stale: false);
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Future<void> press(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets(
    'homework addition is explicit editable and duplicate locates without overwrite',
    (tester) async {
      phone(tester);
      final fake = TaskFake();
      await tester.pumpWidget(
        ginkgoApp(
          home: HomeworkDetailPage(
            item: assignment,
            service: fake,
            storageRoot: '/synthetic/tasks',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(fake.calls, isEmpty);
      await press(tester, 'homework-add-task');
      expect(fake.calls, ['load']);
      expect(
        tester
            .widget<CupertinoTextField>(find.byKey(const Key('task-title')))
            .controller!
            .text,
        assignment.title,
      );
      expect(
        tester
            .widget<CupertinoTextField>(find.byKey(const Key('task-due')))
            .controller!
            .text,
        assignment.dueAt,
      );
      await tester.enterText(find.byKey(const Key('task-title')), '个人改写');
      await tester.enterText(find.byKey(const Key('task-due')), '');
      await press(tester, 'task-save');
      expect(fake.calls, ['load', 'add_homework']);
      expect(fake.rows.single['title'], '个人改写');
      expect(fake.rows.single['due'], '');
      expect(fake.roots.every((r) => r == '/synthetic/tasks'), isTrue);
      fake.rows.single['completed'] = true;
      await press(tester, 'homework-add-task');
      expect(fake.calls, ['load', 'add_homework', 'load']);
      expect(find.textContaining('已添加过此作业'), findsOneWidget);
      expect(fake.rows.single['completed'], isTrue);
      await press(tester, 'homework-view-task');
      expect(
        find.byKey(const Key('task-highlight-local:linked')),
        findsOneWidget,
      );
      expect(find.text('个人改写'), findsOneWidget);
      await press(tester, 'task-source-local:linked');
      expect(fake.detailIds, ['123', '123']);
      expect(
        tester
            .widget<HomeworkDetailPage>(find.byType(HomeworkDetailPage))
            .openTaskOnLinked,
        isFalse,
      );
      await press(tester, 'homework-add-task');
      await press(tester, 'homework-view-task');
      expect(find.byType(TasksPage), findsOneWidget);
      expect(find.byType(HomeworkDetailPage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'legacy editing preserves source exact date and local completion only',
    (tester) async {
      phone(tester);
      final fake = TaskFake()
        ..rows.add(record('old', due: '2026-10-22', source: assignment.id));
      await tester.pumpWidget(
        ginkgoApp(
          home: TasksPage(service: fake, storageRoot: '/synthetic/tasks'),
        ),
      );
      await tester.pumpAndSettle();
      await press(tester, 'task-edit-old');
      expect(
        tester
            .widget<CupertinoTextField>(find.byKey(const Key('task-due')))
            .controller!
            .text,
        '2026-10-22',
      );
      await tester.enterText(find.byKey(const Key('task-title')), '仅改标题');
      await press(tester, 'task-save');
      expect(fake.rows.single['due'], '2026-10-22');
      expect(
        (fake.rows.single['source'] as Map)['assignment_id'],
        assignment.id,
      );
      await press(tester, 'task-toggle-old');
      expect(fake.rows.single['completed'], isTrue);
      expect(fake.calls, ['load', 'update', 'toggle']);
      expect(fake.detailIds, isEmpty);
      expect(find.textContaining('不代表已向学校提交'), findsOneWidget);
    },
  );

  testWidgets(
    'corrupt payload never reports success empty or allows mutation',
    (tester) async {
      phone(tester);
      final fake = TaskFake()..corrupt = true;
      await tester.pumpWidget(
        ginkgoApp(
          home: TasksPage(service: fake, storageRoot: '/synthetic'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('暂无待办'), findsNothing);
      expect(find.textContaining('读取或保存未确认'), findsOneWidget);
      expect(fake.calls, ['load']);
      await tester.pumpWidget(
        ginkgoApp(
          home: HomeworkDetailPage(
            item: assignment,
            service: fake,
            storageRoot: '/synthetic',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await press(tester, 'homework-add-task');
      expect(find.byType(TaskEditor), findsNothing);
      expect(find.textContaining('读取未确认'), findsOneWidget);
      expect(find.byKey(const Key('homework-view-task')), findsNothing);
    },
  );

  testWidgets('failed save retains draft and blocks automatic retry', (
    tester,
  ) async {
    phone(tester);
    final fake = TaskFake()..failSave = true;
    await tester.pumpWidget(
      ginkgoApp(
        home: HomeworkDetailPage(
          item: assignment,
          service: fake,
          storageRoot: '/synthetic',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await press(tester, 'homework-add-task');
    await tester.enterText(find.byKey(const Key('task-title')), '保留这份草稿');
    await press(tester, 'task-save');
    expect(find.byType(TaskEditor), findsOneWidget);
    expect(
      tester
          .widget<CupertinoTextField>(find.byKey(const Key('task-title')))
          .controller!
          .text,
      '保留这份草稿',
    );
    expect(find.textContaining('保存未确认'), findsOneWidget);
    expect(fake.calls, ['load', 'add_homework']);
  });

  testWidgets(
    'Academic-only detail remains compatible and missing source is honest',
    (tester) async {
      phone(tester);
      await tester.pumpWidget(
        ginkgoApp(
          home: HomeworkDetailPage(item: assignment, service: AcademicOnly()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('当前服务不支持本机待办'), findsOneWidget);
      final fake = TaskFake()
        ..assignments = []
        ..rows.add(record('gone', source: 'spoc:gone'));
      await tester.pumpWidget(
        ginkgoApp(
          home: TasksPage(service: fake, storageRoot: '/synthetic'),
        ),
      );
      await tester.pumpAndSettle();
      await press(tester, 'task-source-gone');
      expect(find.text('暂时无法定位来源作业'), findsOneWidget);
      expect(fake.detailIds, isEmpty);
    },
  );

  testWidgets(
    'narrow large text target is scrolled highlighted and actions meet 48dp',
    (tester) async {
      phone(tester);
      final fake = TaskFake()
        ..rows.addAll([
          for (var i = 0; i < 30; i++) record('item:$i', title: '合成长标题待办$i'),
        ]);
      await tester.pumpWidget(
        ginkgoApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: TasksPage(
              service: fake,
              storageRoot: '/synthetic',
              initialTaskId: 'item:29',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final finder = find.byKey(const Key('task-highlight-item:29'));
      expect(finder.hitTestable(), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('task-toggle-item:29'))).height,
        greaterThanOrEqualTo(48),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('late account load and detail do not replace new account data', (
    tester,
  ) async {
    final old = TaskFake()
      ..pendingLoad = Completer<ReadOnlyResponse>()
      ..pendingDetail = Completer<HomeworkDetailResponse>();
    final next = TaskFake()..rows.add(record('next', title: '新账号待办'));
    await tester.pumpWidget(
      ginkgoApp(
        home: TasksPage(service: old, storageRoot: '/old'),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(
      ginkgoApp(
        home: TasksPage(service: next, storageRoot: '/next'),
      ),
    );
    await tester.pumpAndSettle();
    old.pendingLoad!.complete(
      ReadOnlyResponse(
        payload: jsonEncode([record('old', title: '旧账号待办')]),
        stale: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('新账号待办'), findsOneWidget);
    expect(find.text('旧账号待办'), findsNothing);
    await tester.pumpWidget(
      ginkgoApp(
        home: HomeworkDetailPage(item: assignment, service: old),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(
      ginkgoApp(
        home: HomeworkDetailPage(item: assignment, service: next),
      ),
    );
    await tester.pumpAndSettle();
    old.pendingDetail!.complete(
      const HomeworkDetailResponse(
        status: '旧状态',
        content: '旧账号正文',
        stale: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('旧账号正文'), findsNothing);
    expect(find.text('合成正文'), findsOneWidget);
  });

  testWidgets(
    'pending save cannot double submit and late result cannot affect new account',
    (tester) async {
      phone(tester);
      final old = TaskFake()..pendingSave = Completer<ReadOnlyResponse>();
      final next = TaskFake()..rows.add(record('new', title: '新账号可见待办'));
      final current = ValueNotifier<TaskFake>(old);
      addTearDown(current.dispose);
      await tester.pumpWidget(
        ginkgoApp(
          home: ValueListenableBuilder<TaskFake>(
            valueListenable: current,
            builder: (_, gateway, _) => HomeworkDetailPage(
              item: assignment,
              service: gateway,
              storageRoot: gateway == old ? '/old' : '/new',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await press(tester, 'homework-add-task');
      final save = find.byKey(const Key('task-save'));
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pump();
      expect(old.calls, ['load', 'add_homework']);
      expect(tester.widget<CupertinoButton>(save).onPressed, isNull);
      current.value = next;
      await tester.pump();
      old.pendingSave!.complete(
        ReadOnlyResponse(
          payload: jsonEncode([record('old', source: assignment.id)]),
          stale: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditor), findsOneWidget);
      expect(find.textContaining('保存未确认'), findsOneWidget);
      expect(next.calls, isEmpty);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('homework-view-task')), findsNothing);
      expect(find.textContaining('已关联本机待办'), findsNothing);
    },
  );

  testWidgets(
    'precise deadline survives title-only edit and source-less tasks remain source-less',
    (tester) async {
      phone(tester);
      const raw = '2026-10-22T10:30:00.500123456Z';
      final fake = TaskFake()..rows.add(record('precise', due: raw));
      await tester.pumpWidget(
        ginkgoApp(
          home: TasksPage(service: fake, storageRoot: '/synthetic'),
        ),
      );
      await tester.pumpAndSettle();
      await press(tester, 'task-edit-precise');
      await tester.enterText(find.byKey(const Key('task-title')), '只改个人标题');
      await press(tester, 'task-save');
      expect(fake.rows.single['due'], raw);
      expect(fake.rows.single.containsKey('source'), isFalse);
      expect(find.byKey(const Key('task-source-precise')), findsNothing);
    },
  );

  testWidgets('large-text editor and homework return without implicit writes', (
    tester,
  ) async {
    phone(tester);
    final fake = TaskFake();
    await tester.pumpWidget(
      ginkgoApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: HomeworkDetailPage(
            item: assignment,
            service: fake,
            storageRoot: '/synthetic',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await press(tester, 'homework-add-task');
    await tester.ensureVisible(find.byKey(const Key('task-save')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(fake.calls, ['load']);
    expect(fake.rows, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'picker offers date exact Beijing time and clear without mandatory deadline',
    (tester) async {
      phone(tester);
      final fake = TaskFake();
      await tester.pumpWidget(
        ginkgoApp(
          home: TasksPage(service: fake, storageRoot: '/synthetic'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(CupertinoIcons.add));
      await tester.pumpAndSettle();
      final due = find.byKey(const Key('task-due'));
      expect(tester.widget<CupertinoTextField>(due).controller!.text, '');
      await press(tester, 'task-pick-date');
      final picker = tester.widget<CupertinoDatePicker>(
        find.byKey(const Key('task-deadline-picker')),
      );
      picker.onDateTimeChanged(DateTime(2027, 2, 3));
      await press(tester, 'task-picker-confirm');
      expect(
        tester.widget<CupertinoTextField>(due).controller!.text,
        '2027-02-03',
      );
      await press(tester, 'task-pick-time');
      tester
          .widget<CupertinoDatePicker>(
            find.byKey(const Key('task-deadline-picker')),
          )
          .onDateTimeChanged(DateTime(2027, 2, 3, 18, 45));
      await press(tester, 'task-picker-confirm');
      expect(
        tester.widget<CupertinoTextField>(due).controller!.text,
        '2027-02-03T18:45:00+08:00',
      );
      await press(tester, 'task-clear-due');
      expect(tester.widget<CupertinoTextField>(due).controller!.text, '');
      expect(fake.calls, ['load']);
    },
  );
}
