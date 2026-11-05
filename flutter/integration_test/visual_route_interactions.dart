import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart' show BykcPart;
import 'package:ginkgo_mirror/features/learning/learning_course_page.dart';
import 'package:ginkgo_mirror/features/schedule/schedule_widgets.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';

import 'support.dart' show settle;

/// Exercises local UI only. Never opens official links or submits school writes.
Future<void> inspectRouteInteractions(
  WidgetTester tester,
  String id,
  Future<void> Function(String) capture,
) async {
  Future<void> tapVisible(Finder finder) async {
    for (
      var attempt = 0;
      finder.evaluate().isEmpty && attempt < 30;
      attempt++
    ) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -160));
      await settle(tester, frames: 3);
    }
    expect(finder.evaluate(), isNotEmpty);
    await tester.ensureVisible(finder.first);
    await settle(tester, frames: 3);
    await tester.tap(finder.first);
    await settle(tester, frames: 8);
  }

  Future<void> back() async {
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await settle(tester, frames: 8);
  }

  if (id == 'grades' || id == 'notices') {
    final target = id == 'grades'
        ? find.byWidgetPredicate(
            (widget) =>
                widget.key is ValueKey<String> &&
                (widget.key! as ValueKey<String>).value.startsWith(
                  'grade-course-',
                ),
          )
        : find.widgetWithText(AppleListTile, '合成校园通知');
    final scroll = find.byType(Scrollable).first;
    // Lazy lists can have zero matches before scrolling and several after it.
    // Select the first course only once a row has actually been built.
    for (
      var attempt = 0;
      target.evaluate().isEmpty && attempt < 30;
      attempt++
    ) {
      await tester.drag(scroll, const Offset(0, -160));
      await settle(tester, frames: 3);
    }
    expect(target.evaluate(), isNotEmpty, reason: '$id detail entry');
    await tapVisible(target);
    await capture('$id-detail');
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    if (position.maxScrollExtent > 0) {
      position.jumpTo(position.maxScrollExtent);
      await capture('$id-detail-end');
    }
    await back();
  }
  if (id == 'learning-course') {
    for (final label in ['公告', '测验', '资料']) {
      final selector = find.descendant(
        of: find.byType(CupertinoSlidingSegmentedControl<LearningCourseTab>),
        matching: find.text(label),
      );
      await tapVisible(selector);
      await capture(
        'learning-course-${{'公告': 'announcements', '测验': 'assessments', '资料': 'resources'}[label]}',
      );
    }
  }
  if (id == 'bykc') {
    for (final label in ['已选课程', '完成统计', '课程库']) {
      final picker = find.byType(ApplePickerTile<BykcPart>);
      if (picker.evaluate().isNotEmpty) {
        await tapVisible(picker);
        await capture('bykc-view-picker');
        await tapVisible(find.text(label).last);
      } else {
        await tapVisible(
          find.descendant(
            of: find.byType(CupertinoSlidingSegmentedControl<BykcPart>),
            matching: find.text(label),
          ),
        );
      }
      await capture(
        'bykc-${{'已选课程': 'chosen', '完成统计': 'statistics', '课程库': 'catalog'}[label]}',
      );
    }
  }
  if (id == 'library-loans' || id.startsWith('library-loans-')) {
    await tapVisible(find.byKey(const Key('library-loans-first-read')));
    await capture('$id-read');
  }
  if (id == 'campus-card') {
    await tapVisible(find.byKey(const Key('campus-card-read')));
    await capture('campus-card-private');
    final toggle = find.byKey(const Key('campus-card-toggle'));
    if (toggle.evaluate().isNotEmpty) {
      await tapVisible(toggle);
      await capture('campus-card-revealed');
      await tapVisible(toggle);
    }
  }
  if (id == 'schedule') {
    for (final key in ['schedule-term-picker', 'schedule-week-picker']) {
      await tapVisible(find.byKey(Key(key)));
      await capture(key);
      await back();
    }
    for (final mode in [
      ScheduleViewMode.weekGrid,
      ScheduleViewMode.semester,
      ScheduleViewMode.exam,
      ScheduleViewMode.dayList,
    ]) {
      if (MediaQuery.textScalerOf(tester.element(find.byType(Scrollable).first))
              .scale(1) >
          1.4) {
        await tapVisible(find.byType(ApplePickerTile<ScheduleViewMode>));
        await capture('schedule-view-picker');
        await tapVisible(find.text(scheduleViewModeDescription(mode)).last);
      } else {
        await tapVisible(
          find.descendant(
            of: find.byType(CupertinoSlidingSegmentedControl<ScheduleViewMode>),
            matching: find.text(scheduleViewModeLabel(mode)),
          ),
        );
      }
      await capture('schedule-${mode.name.toLowerCase()}');
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      position.jumpTo(position.maxScrollExtent);
      await capture('schedule-${mode.name.toLowerCase()}-end');
      position.jumpTo(position.minScrollExtent);
      await settle(tester, frames: 5);
    }
  }
  if (id == 'classroom') {
    await tapVisible(find.text('筛选与排序'));
    await capture('classroom-filters');
  }
  if (id == 'more') {
    await tapVisible(find.byKey(const ValueKey('shortcuts-edit')));
    await capture('more-shortcut-editor');
  }
  if (id == 'task-editor') {
    await tapVisible(find.byKey(const Key('task-pick-time')));
    await capture('task-deadline-picker');
    await back();
    await tapVisible(find.byKey(const Key('task-title')));
    await tester.enterText(
      find.byKey(const Key('task-title')),
      '合成修改：保留尚未保存的输入',
    );
    await SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    await settle(tester, frames: 15);
    expect(
      tester.view.viewInsets.bottom,
      greaterThan(0),
      reason: 'the Android keyboard must be visible in this capture',
    );
    await capture('task-editor-keyboard');
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester, frames: 5);
    await tester.pageBack();
    await settle(tester, frames: 5);
    expect(find.text('放弃未保存的修改？'), findsOneWidget);
    await capture('task-discard-confirmation');
    await tapVisible(find.text('继续编辑'));
    await tester.enterText(
      find.byKey(const Key('task-title')),
      '合成待办：整理本周课程笔记',
    );
    FocusManager.instance.primaryFocus?.unfocus();
  }
  expect(tester.takeException(), isNull, reason: 'interactions for $id');
}
