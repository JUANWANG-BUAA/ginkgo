import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/apple_design.dart';
import 'package:ginkgo_mirror/apple_widgets.dart';
import 'package:ginkgo_mirror/homework_detail_page.dart';
import 'package:ginkgo_mirror/homework_task_link.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/task_editor.dart';
import 'package:ginkgo_mirror/tasks_page.dart';

import 'task_link_widget_test.dart' show TaskFake, assignment, record;

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
            TasksPage(
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
          'task-edit-visual',
          'task-delete-visual',
        ]) {
          await reveal(tester, find.byKey(Key(key)));
          expectTouchTarget(tester, key);
        }
        final toggle = tester.widget<CupertinoButton>(
          find.byKey(const Key('task-toggle-visual')),
        );
        final edit = tester.widget<CupertinoButton>(
          find.byKey(const Key('task-edit-visual')),
        );
        final delete = tester.widget<CupertinoButton>(
          find.byKey(const Key('task-delete-visual')),
        );
        expect(toggle.color, isNotNull);
        expect(edit.color, isNull);
        expect(
          (delete.child as Text).style!.color,
          AppleDesign.statusDanger.resolveFrom(
            tester.element(find.byType(TasksPage)),
          ),
        );
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
              HomeworkDetailPage(
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
          final action = find.byType(HomeworkTaskLink);
          final section = find.ancestor(
            of: action,
            matching: find.byType(AppleSection),
          );
          expect(section, findsOneWidget);
          expect(
            tester.widget<AppleSection>(section).children.single,
            isA<HomeworkTaskLink>(),
          );
          await reveal(tester, find.byKey(const Key('homework-add-task')));
          expectTouchTarget(tester, 'homework-add-task');
          expect(
            find.text('仅在本机记录，标记完成不等于学校提交。标题和截止时间可在确认前编辑。'),
            findsOneWidget,
          );
          await reveal(tester, find.text('合成正文'));
          expect(fake.calls, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
