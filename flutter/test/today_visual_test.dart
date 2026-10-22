import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/apple_design.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/today_action_row.dart';
import 'package:ginkgo_mirror/today_page.dart';

import 'today_v2_widget_test.dart'
    show TodayFake, oneHomework, task, tasksPayload;

class _VisualTodayService extends TodayFake {
  @override
  Future<TodayResponse> today({bool forceRefresh = false}) async =>
      const TodayResponse(
        date: '2026-10-22',
        courses: [
          TodayCourse(name: '合成焦点课程', time: '08:00-10:00', place: '合成教学楼 A101'),
          TodayCourse(name: '合成普通课程', time: '14:00-15:00', place: '合成教学楼 B202'),
        ],
      );
}

Widget _host(
  Widget child, {
  double scale = 1,
  Brightness brightness = Brightness.light,
}) => CupertinoApp(
  theme: CupertinoThemeData(
    brightness: brightness,
    primaryColor: AppleDesign.accent,
  ),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true),
      child: child,
    ),
  ),
);

void main() {
  testWidgets('Today uses a compact 17/20/13 hierarchy and 48dp targets', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        CupertinoPageScaffold(
          child: Column(
            children: [
              TodayActionRow(
                title: '焦点',
                status: '正在上课',
                emphasized: true,
                onTap: () {},
              ),
              TodayActionRow(title: '普通事项', subtitle: '辅助信息', onTap: () {}),
              TodayActionRow(title: '摘要', summary: true, onTap: () {}),
            ],
          ),
        ),
      ),
    );
    expect(tester.widget<Text>(find.text('焦点')).style!.fontSize, 20);
    expect(tester.widget<Text>(find.text('普通事项')).style!.fontSize, 17);
    expect(tester.widget<Text>(find.text('正在上课')).style!.fontSize, 13);
    expect(tester.widget<Text>(find.text('辅助信息')).style!.fontSize, 13);
    expect(tester.widget<Text>(find.text('摘要')).style!.fontSize, 15);
    for (final row in find.byType(TodayActionRow).evaluate()) {
      expect(
        tester.getSize(find.byWidget(row.widget)).height,
        greaterThanOrEqualTo(48),
      );
    }
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 1280.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final brightness in Brightness.values) {
        testWidgets('Today visual layout $width dp / ${scale}x / $brightness', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 2400);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final service = _VisualTodayService()
            ..assignments = oneHomework
            ..local = tasksPayload([task('visual', due: '2026-10-22')]);
          await tester.pumpWidget(
            _host(
              TodayPage(
                service: service,
                storageRoot: '/synthetic/tasks',
                now: () => DateTime.utc(2026, 10, 22, 1),
                onOpenFeature: (_) {},
              ),
              scale: scale,
              brightness: brightness,
            ),
          );
          await tester.pumpAndSettle();
          final focus = find.byKey(const Key('today-course-focus'));
          final focusTitle = find.descendant(
            of: focus,
            matching: find.text('合成焦点课程'),
          );
          expect(tester.widget<Text>(focusTitle).style!.fontSize, 20);
          final ordinary = find.byKey(const Key('today-course-1-合成普通课程'));
          expect(
            tester
                .widget<Text>(
                  find.descendant(of: ordinary, matching: find.text('合成普通课程')),
                )
                .style!
                .fontSize,
            17,
          );
          expect(
            tester.getRect(focus).left,
            width > 820 ? (width - 820) / 2 + 16 : 16,
          );
          expect(tester.getRect(focus).width, width > 820 ? 788 : width - 32);
          final row = find.byKey(const Key('today-task-visual'));
          await tester.ensureVisible(row);
          await tester.pumpAndSettle();
          expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
          expect(find.textContaining('本地完成不代表学校作业已提交'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
        });
      }
    }
  }
}
