import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/features/homework/homework_detail_page.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/features/tasks/task_editor.dart';
import 'package:ginkgo_mirror/features/tasks/tasks_page.dart';

import 'task_link_widget_test.dart' show TaskFake, assignment, record, press;
import 'platform_actions_fake.dart';

Widget visualApp(Widget page, Brightness brightness, double scale) => ginkgoApp(
  brightness: brightness,
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: page,
    ),
  ),
);

void narrowPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> reveal(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void expectTouchTarget(WidgetTester tester, String key) {
  final size = tester.getSize(find.byKey(Key(key)));
  expect(size.width, greaterThanOrEqualTo(48));
  expect(size.height, greaterThanOrEqualTo(48));
}

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0]) {
      final variant = '${brightness.name} / ${scale}x';
      testWidgets('task hierarchy and quiet location tint: $variant', (
        tester,
      ) async {
        narrowPhone(tester);
        final fake = TaskFake()
          ..rows.add(
            record(
              'visual',
              title: '合成个人待办：保留完整标题并允许在窄屏自然换行',
              source: assignment.id,
            ),
          );
        await tester.pumpWidget(
          visualApp(
            TasksPage(fileActions: platformActions,
              service: fake,
              storageRoot: '/synthetic/visual',
              initialTaskId: 'visual',
            ),
            brightness,
            scale,
          ),
        );
        await tester.pumpAndSettle();
        final title = tester.widget<Text>(find.text('合成个人待办：保留完整标题并允许在窄屏自然换行'));
        expect(title.style!.fontSize, 17);
        expect(title.style!.fontWeight, FontWeight.w600);
        final highlight = tester.widget<Text>(
          find.byKey(const Key('task-highlight-visual')),
        );
        expect(highlight.style!.fontSize, 13);
        final container = tester.widget<Container>(
          find
              .ancestor(
                of: find.byKey(const Key('task-row-visual')),
                matching: find.byType(Container),
              )
              .first,
        );
        final decoration = container.decoration! as BoxDecoration;
        expect(decoration.border, isNull);
        expect(decoration.color!.a, lessThan(0.1));
        expect(container.padding, const EdgeInsets.all(16));
        final source = tester.widget<Text>(find.text('来源：学校作业 · 查看来源'));
        expect(source.style!.fontSize, 13);
        for (final key in [
          'task-source-visual',
          'task-toggle-visual',
          'task-more-visual',
        ]) {
          await reveal(tester, find.byKey(Key(key)));
          expectTouchTarget(tester, key);
        }
        final toggle = tester.widget<CupertinoButton>(
          find.byKey(const Key('task-toggle-visual')),
        );
        final more = tester.widget<CupertinoButton>(
          find.byKey(const Key('task-more-visual')),
        );
        expect(toggle.color, isNotNull);
        expect(more.color, isNull);
        expect(find.byKey(const Key('task-edit-visual')), findsNothing);
        expect(find.byKey(const Key('task-delete-visual')), findsNothing);
        await press(tester, 'task-more-visual');
        for (final key in ['task-edit-visual', 'task-delete-visual']) {
          await reveal(tester, find.byKey(Key(key)));
          expectTouchTarget(tester, key);
        }
        expect(
          tester
              .widget<CupertinoActionSheetAction>(
                find.byKey(const Key('task-delete-visual')),
              )
              .isDestructiveAction,
          isTrue,
        );
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(fake.calls, ['load']);
        expect(tester.takeException(), isNull);
      });

      testWidgets('editor labels, pills and complete safety copy: $variant', (
        tester,
      ) async {
        narrowPhone(tester);
        await tester.pumpWidget(
          visualApp(
            TaskEditor(
              title: '合成待办',
              sourceAssignmentId: assignment.id,
              onSave: (_) async => false,
            ),
            brightness,
            scale,
          ),
        );
        await tester.pumpAndSettle();
        for (final key in [
          'task-title',
          'task-pick-date',
          'task-pick-time',
          'task-due',
          'task-clear-due',
          'task-save',
        ]) {
          await reveal(tester, find.byKey(Key(key)));
          if (key != 'task-title' && key != 'task-due') {
            expectTouchTarget(tester, key);
          }
        }
        final date = tester.widget<CupertinoButton>(
          find.byKey(const Key('task-pick-date')),
        );
        expect(date.color, isNotNull);
        expect(date.borderRadius, BorderRadius.circular(12));
        final titleRect = tester.getRect(find.byKey(const Key('task-title')));
        final dueRect = tester.getRect(find.byKey(const Key('task-due')));
        expect(titleRect.left, dueRect.left);
        await reveal(tester, find.text('这是本机个人待办，标记完成不代表已向学校提交作业。'));
        final safety = tester.widget<Text>(
          find.text('这是本机个人待办，标记完成不代表已向学校提交作业。'),
        );
        expect(safety.style!.fontSize, 13);
        expect(tester.takeException(), isNull);
        await reveal(tester, find.byKey(const Key('task-pick-date')));
        await tester.tap(find.byKey(const Key('task-pick-date')));
        await tester.pumpAndSettle();
        expect(find.text('截止时间 · 北京时间'), findsOneWidget);
        expect(find.byKey(const Key('task-deadline-picker')), findsOneWidget);
        expect(find.text('取消'), findsOneWidget);
        expectTouchTarget(tester, 'task-picker-confirm');
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
      });

      testWidgets(
        'assignment detail hierarchy and independent local action: $variant',
        (tester) async {
          narrowPhone(tester);
          final fake = TaskFake();
          await tester.pumpWidget(
            visualApp(
              HomeworkDetailPage(fileActions: platformActions,
                item: assignment,
                service: fake,
                storageRoot: '/synthetic/visual',
              ),
              brightness,
              scale,
            ),
          );
          await tester.pumpAndSettle();
          final title = tester.widget<Text>(find.text(assignment.title));
          expect(title.style!.fontSize, 20);
          expect(title.style!.fontWeight, FontWeight.w600);
          expect(
            tester.widget<Text>(find.text('截止时间 · 北京时间')).style!.fontSize,
            13,
          );
          // Assignments are no longer pushed into personal to-dos: the detail
          // page must not offer an "add to my tasks" action at all.
          expect(find.byKey(const Key('homework-add-task')), findsNothing);
          expect(find.textContaining('仅在本机记录'), findsNothing);
          await reveal(tester, find.text('合成正文'));
          expect(fake.calls, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
