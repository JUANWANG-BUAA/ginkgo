import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/workspace/workspace_shortcut_preferences.dart';
import 'package:ginkgo_mirror/workspace/workspace_shortcuts.dart';

const choices = [
  WorkspaceShortcut(
    id: 'checkin',
    title: '课程签到',
    icon: CupertinoIcons.checkmark,
  ),
  WorkspaceShortcut(
    id: 'schedule',
    title: '查看课表',
    icon: CupertinoIcons.calendar,
  ),
  WorkspaceShortcut(id: 'homework', title: '学校作业', icon: CupertinoIcons.book),
  WorkspaceShortcut(
    id: 'reservations',
    title: '空间预约',
    icon: CupertinoIcons.building_2_fill,
  ),
  WorkspaceShortcut(
    id: 'extra',
    title: '另一个很长很长的服务名称',
    icon: CupertinoIcons.star,
  ),
];

File preferenceFile(Directory root, String account) => File(
  '${root.path}/workspace-shortcuts-${sha256.convert(utf8.encode(account))}.json',
);

String encoded(List<String> ids) => jsonEncode({'version': 1, 'ids': ids});

Widget host({
  String? account = 'fixture-a',
  bool demo = true,
  String? root,
  List<WorkspaceShortcut> entries = choices,
  double scale = 1,
  ValueChanged<String>? onOpen,
}) => CupertinoApp(
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: CupertinoPageScaffold(
      child: SingleChildScrollView(
        child: WorkspaceShortcuts(
          accountId: account,
          demo: demo,
          choices: entries,
          storageRoot: root,
          onOpen: onOpen ?? (_) {},
        ),
      ),
    ),
  ),
);

Future<void> tap(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> waitForIo(
  WidgetTester tester, {
  required bool Function() complete,
  required String reason,
}) async {
  // File reads/writes have multiple asynchronous stages. Alternate real event
  // loop turns with widget pumps instead of assuming one delay drains them all.
  const maxAttempts = 100;
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
    if (complete()) return;
  }
  fail('Timed out after $maxAttempts I/O turns waiting for $reason');
}

bool buttonEnabled(WidgetTester tester, String key) =>
    tester.widget<CupertinoButton>(find.byKey(ValueKey(key))).onPressed != null;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final previousHitTestWarningPolicy =
      WidgetController.hitTestWarningShouldBeFatal;
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDownAll(() {
    WidgetController.hitTestWarningShouldBeFatal = previousHitTestWarningPolicy;
  });

  test(
    'versioned schema rejects malformed values without dropping unknown IDs',
    () {
      for (final source in [
        '[]',
        '{}',
        '{"version":2,"ids":[]}',
        '{"version":1.0,"ids":[]}',
        '{"version":1,"ids":[2]}',
        '{"version":1,"ids":["a","a"]}',
        '{"version":1,"ids":[""]}',
        '{"version":1,"ids":[],"extra":true}',
        encoded(['a', 'b', 'c', 'd', 'e']),
      ]) {
        expect(
          () => WorkspaceShortcutPreferences.decode(source),
          throwsFormatException,
        );
      }
      expect(WorkspaceShortcutPreferences.decode(encoded(['future-service'])), [
        'future-service',
      ]);
      expect(WorkspaceShortcutPreferences.decode(encoded([])), isEmpty);
    },
  );

  test(
    'account hashes persist independently and leave unrelated tasks untouched',
    () async {
      final root = await Directory.systemTemp.createTemp('shortcut-test-');
      addTearDown(() => root.delete(recursive: true));
      final task = File('${root.path}/local-tasks.json');
      await task.writeAsString('fixture task data');
      final a = WorkspaceShortcutPreferences(
        accountId: 'fixture-a',
        demo: false,
        storageRoot: root.path,
      );
      final b = WorkspaceShortcutPreferences(
        accountId: 'fixture-b',
        demo: false,
        storageRoot: root.path,
      );
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await a.restore();
      await b.restore();
      expect(a.ids, isNull);
      expect(await a.save(['extra', 'future-service']), isTrue);
      expect(await b.save([]), isTrue);
      final reopened = WorkspaceShortcutPreferences(
        accountId: 'fixture-a',
        demo: false,
        storageRoot: root.path,
      );
      addTearDown(reopened.dispose);
      await reopened.restore();
      expect(reopened.ids, ['extra', 'future-service']);
      expect(b.ids, isEmpty);
      final paths = await root.list().map((entry) => entry.path).toList();
      expect(
        paths.where(
          (path) => path.contains('fixture-a') || path.contains('fixture-b'),
        ),
        isEmpty,
      );
      expect(await task.readAsString(), 'fixture task data');
    },
  );

  test('unknown account and demo never call storage', () async {
    for (final account in <String?>[null, '', '  ', 'fixture-demo']) {
      final p = WorkspaceShortcutPreferences(
        accountId: account,
        demo: account == 'fixture-demo',
        read: () async => throw StateError('must not read'),
        write: (_) async => throw StateError('must not write'),
      );
      await p.restore();
      expect(p.ready, isTrue);
      expect(await p.save([]), isTrue);
      expect(p.ids, isEmpty);
      p.dispose();
    }
  });

  test(
    'failed or invalid reads block writes until explicit successful retry',
    () async {
      var source = 'invalid';
      var writes = 0;
      final p = WorkspaceShortcutPreferences(
        accountId: 'fixture',
        demo: false,
        read: () async => source,
        write: (_) async {
          writes++;
        },
      );
      addTearDown(p.dispose);
      await p.restore();
      expect(p.ready, isFalse);
      expect(p.error, isNotNull);
      expect(await p.save([]), isFalse);
      expect(writes, 0);
      source = encoded(['extra']);
      await p.restore();
      expect(p.error, isNull);
      expect(p.ids, ['extra']);
      expect(await p.save([]), isTrue);
      expect(writes, 1);
    },
  );

  test(
    'read exception and failed save preserve old preferences; retry succeeds',
    () async {
      var failRead = true;
      var failWrite = true;
      var disk = encoded(['schedule']);
      final p = WorkspaceShortcutPreferences(
        accountId: 'fixture',
        demo: false,
        read: () async {
          if (failRead) throw const FileSystemException('fixture');
          return disk;
        },
        write: (value) async {
          if (failWrite) throw const FileSystemException('fixture');
          disk = value;
        },
      );
      addTearDown(p.dispose);
      await p.restore();
      expect(p.ready, isFalse);
      failRead = false;
      await p.restore();
      expect(await p.save([]), isFalse);
      expect(p.ids, ['schedule']);
      expect(WorkspaceShortcutPreferences.decode(disk), ['schedule']);
      expect(p.error, contains('保存失败'));
      failWrite = false;
      expect(await p.save([]), isTrue);
      expect(p.ids, isEmpty);
      expect(p.error, isNull);
      await expectLater(p.save(['a', 'b', 'c', 'd', 'e']), throwsArgumentError);
    },
  );

  test(
    'late reads and writes after dispose cannot notify or update a new account',
    () async {
      final read = Completer<String?>();
      final a = WorkspaceShortcutPreferences(
        accountId: 'a',
        demo: false,
        read: () => read.future,
      );
      final restoring = a.restore();
      a.dispose();
      final b = WorkspaceShortcutPreferences(accountId: 'b', demo: true);
      addTearDown(b.dispose);
      await b.restore();
      await b.save(['homework']);
      read.complete(encoded(['schedule']));
      await restoring;
      expect(a.ids, isNull);
      expect(b.ids, ['homework']);

      final write = Completer<void>();
      final c = WorkspaceShortcutPreferences(
        accountId: 'a',
        demo: false,
        read: () async => encoded(['schedule']),
        write: (_) => write.future,
      );
      await c.restore();
      final saving = c.save([]);
      c.dispose();
      write.complete();
      expect(await saving, isFalse);
      expect(c.ids, ['schedule']);
      expect(b.ids, ['homework']);
    },
  );

  testWidgets(
    'default entries open only on tap; cancel and reset require save',
    (tester) async {
      final opened = <String>[];
      await tester.pumpWidget(host(onOpen: opened.add));
      await tester.pumpAndSettle();
      await tap(tester, 'shortcut-open-schedule');
      expect(opened, ['schedule']);
      await tap(tester, 'shortcuts-edit');
      expect(
        tester
            .widget<CupertinoButton>(
              find.byKey(const ValueKey('shortcut-choice-extra')),
            )
            .onPressed,
        isNull,
      );
      await tap(tester, 'shortcut-choice-checkin');
      await tap(tester, 'shortcut-choice-extra');
      await tap(tester, 'shortcuts-cancel');
      expect(
        find.byKey(const ValueKey('shortcut-open-checkin')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('shortcut-open-extra')), findsNothing);
      await tap(tester, 'shortcuts-edit');
      for (final id in WorkspaceShortcutPreferences.defaultIds) {
        await tap(tester, 'shortcut-choice-$id');
      }
      await tap(tester, 'shortcuts-save');
      expect(find.text('暂无常用服务，可点编辑选择。'), findsOneWidget);
      await tap(tester, 'shortcuts-edit');
      await tap(tester, 'shortcuts-defaults');
      await tap(tester, 'shortcuts-cancel');
      expect(find.text('暂无常用服务，可点编辑选择。'), findsOneWidget);
      await tap(tester, 'shortcuts-edit');
      await tap(tester, 'shortcuts-defaults');
      await tap(tester, 'shortcuts-save');
      expect(
        find.byKey(const ValueKey('shortcut-open-checkin')),
        findsOneWidget,
      );
      expect(opened, ['schedule']);
    },
  );

  testWidgets('sliver recycling keeps the current draft and demo selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: CustomScrollView(
            controller: scroll,
            slivers: [
              SliverList.list(
                children: [
                  WorkspaceShortcuts(
                    accountId: 'demo',
                    demo: true,
                    choices: choices,
                    onOpen: (_) {},
                  ),
                  const SizedBox(height: 3000),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tap(tester, 'shortcuts-edit');
    await tap(tester, 'shortcut-choice-checkin');
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pumpAndSettle();
    scroll.jumpTo(0);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('shortcuts-save')), findsOneWidget);
    final selection = tester.widget<Semantics>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('shortcut-choice-checkin')),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(selection.properties.selected, isFalse);
    await tap(tester, 'shortcuts-save');
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pumpAndSettle();
    scroll.jumpTo(0);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('shortcut-open-checkin')), findsNothing);
    expect(
      find.byKey(const ValueKey('shortcut-open-schedule')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('account switch discards unsaved draft and memory preferences', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tap(tester, 'shortcuts-edit');
    await tap(tester, 'shortcut-choice-checkin');
    await tester.pumpWidget(host(account: 'fixture-b'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('shortcuts-save')), findsNothing);
    expect(find.byKey(const ValueKey('shortcut-open-checkin')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown IDs stay preserved, disappear safely and can return', (
    tester,
  ) async {
    final root = Directory.systemTemp.createTempSync('shortcut-widget-');
    addTearDown(() => root.deleteSync(recursive: true));
    final file = preferenceFile(root, 'fixture-a');
    file.writeAsStringSync(encoded(['extra', 'future-service']));
    await tester.pumpWidget(host(demo: false, root: root.path));
    await waitForIo(
      tester,
      complete: () => buttonEnabled(tester, 'shortcuts-edit'),
      reason: 'restored preferences to unlock editing',
    );
    expect(find.byKey(const ValueKey('shortcut-open-extra')), findsOneWidget);
    expect(find.text('部分已选服务暂不可用，原偏好已保留。'), findsOneWidget);
    await tap(tester, 'shortcuts-edit');
    expect(
      find.byKey(const ValueKey('shortcut-choice-future-service')),
      findsOneWidget,
    );
    await tap(tester, 'shortcuts-save');
    await waitForIo(
      tester,
      complete: () =>
          find.byKey(const ValueKey('shortcuts-save')).evaluate().isEmpty,
      reason: 'successful save to close the draft',
    );
    expect(WorkspaceShortcutPreferences.decode(file.readAsStringSync()), [
      'extra',
      'future-service',
    ]);
    await tester.pumpWidget(
      host(
        demo: false,
        root: root.path,
        entries: [
          ...choices,
          const WorkspaceShortcut(
            id: 'future-service',
            title: '新服务',
            icon: CupertinoIcons.star,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('shortcut-open-future-service')),
      findsOneWidget,
    );
  });

  testWidgets(
    'read error locks editor and explicit retry recovers without overwrite',
    (tester) async {
      final root = Directory.systemTemp.createTempSync('shortcut-widget-');
      addTearDown(() => root.deleteSync(recursive: true));
      final file = preferenceFile(root, 'fixture-a');
      file.writeAsStringSync('corrupt');
      await tester.pumpWidget(host(demo: false, root: root.path));
      await waitForIo(
        tester,
        complete: () =>
            find.byKey(const ValueKey('shortcuts-retry')).evaluate().isNotEmpty,
        reason: 'failed read to offer an explicit retry',
      );
      expect(
        tester
            .widget<CupertinoButton>(
              find.byKey(const ValueKey('shortcuts-edit')),
            )
            .onPressed,
        isNull,
      );
      expect(file.readAsStringSync(), 'corrupt');
      file.writeAsStringSync(encoded([]));
      await tap(tester, 'shortcuts-retry');
      await waitForIo(
        tester,
        complete: () => buttonEnabled(tester, 'shortcuts-edit'),
        reason: 'retried read to unlock editing',
      );
      expect(find.text('暂无常用服务，可点编辑选择。'), findsOneWidget);
      expect(
        tester
            .widget<CupertinoButton>(
              find.byKey(const ValueKey('shortcuts-edit')),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'write failure keeps draft and old preference with visible retry',
    (tester) async {
      final root = Directory.systemTemp.createTempSync('shortcut-widget-');
      addTearDown(() => root.deleteSync(recursive: true));
      final file = preferenceFile(root, 'fixture-a');
      file.writeAsStringSync(encoded(['schedule']));
      await tester.pumpWidget(host(demo: false, root: root.path));
      await waitForIo(
        tester,
        complete: () => buttonEnabled(tester, 'shortcuts-edit'),
        reason: 'restored preferences to unlock editing',
      );
      await tap(tester, 'shortcuts-edit');
      await tap(tester, 'shortcut-choice-schedule');
      // Make replacement fail without permissions/platform-dependent chmod behavior.
      file.deleteSync();
      Directory(file.path).createSync();
      await tap(tester, 'shortcuts-save');
      await waitForIo(
        tester,
        complete: () => find.text('保存失败，原设置未更改。请重试保存。').evaluate().isNotEmpty,
        reason: 'failed write to leave a retryable draft',
      );
      expect(find.text('保存失败，原设置未更改。请重试保存。'), findsOneWidget);
      await tap(tester, 'shortcuts-cancel');
      expect(
        find.byKey(const ValueKey('shortcut-open-schedule')),
        findsOneWidget,
      );
      Directory(file.path).deleteSync();
      file.writeAsStringSync(encoded(['schedule']));
      await tap(tester, 'shortcuts-edit');
      await tap(tester, 'shortcut-choice-schedule');
      await tap(tester, 'shortcuts-save');
      await waitForIo(
        tester,
        complete: () =>
            find.byKey(const ValueKey('shortcuts-save')).evaluate().isEmpty,
        reason: 'retried save to close the draft',
      );
      expect(
        WorkspaceShortcutPreferences.decode(file.readAsStringSync()),
        isEmpty,
      );
    },
  );

  testWidgets(
    '320dp large text reflows all controls and preserves 48dp targets',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(host(scale: 2.5));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final id in WorkspaceShortcutPreferences.defaultIds) {
        expect(
          tester.getSize(find.byKey(ValueKey('shortcut-open-$id'))).height,
          greaterThanOrEqualTo(48),
        );
      }
      await tap(tester, 'shortcuts-edit');
      for (final key in [
        'shortcuts-cancel',
        'shortcuts-defaults',
        'shortcuts-save',
      ]) {
        await tester.ensureVisible(find.byKey(ValueKey(key)));
        expect(
          tester.getSize(find.byKey(ValueKey(key))).height,
          greaterThanOrEqualTo(48),
        );
      }
      expect(tester.takeException(), isNull);
      await tap(tester, 'shortcuts-cancel');
      await tester.pumpWidget(host(entries: [], scale: 2.5));
      await tap(tester, 'shortcuts-edit');
      await tap(tester, 'shortcuts-save');
      expect(find.text('暂无常用服务，可点编辑选择。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
