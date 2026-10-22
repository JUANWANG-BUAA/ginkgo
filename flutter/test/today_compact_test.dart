import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/today_page.dart';

import 'today_v2_widget_test.dart'
    show TodayFake, oneHomework, task, tasksPayload;

class CompactService extends TodayFake {
  @override
  Future<TodayResponse> today({bool forceRefresh = false}) async {
    courseReads++;
    return const TodayResponse(
      date: '2026-10-22',
      courses: [
        TodayCourse(name: '合成下一节课', time: '10:00-11:35', place: '合成教学楼'),
        TodayCourse(name: '合成下午课', time: '14:00-15:35', place: '合成教学楼'),
      ],
    );
  }
}

void main() {
  testWidgets('compact first screen keeps next course and deadline visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = CompactService()
      ..assignments = oneHomework
      ..local = tasksPayload([task('one')]);
    var settings = 0;
    Widget host(String account) => CupertinoApp(
      home: TodayPage(
        service: service,
        accountId: account,
        storageRoot: '/synthetic/tasks',
        now: () => DateTime.utc(2026, 10, 22, 1, 40),
        onOpenSettings: () => settings++,
        onOpenFeature: (_) {},
      ),
    );
    await tester.pumpWidget(host('a'));
    await tester.pumpAndSettle();
    expect(find.text('账户与设置'), findsNothing);
    expect(find.text('合成下午课'), findsNothing);
    expect(find.text('合成下一节课'), findsOneWidget);
    expect(tester.getRect(find.text('合成报告')).bottom, lessThan(844));
    await tester.tap(find.byKey(const Key('workspace-settings')));
    expect(settings, 1);
    final toggle = find.byKey(const Key('today-toggle-courses'));
    expect(tester.getSize(toggle).height, greaterThanOrEqualTo(48));
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text('合成下午课'), findsOneWidget);
    expect(service.courseReads, 1);
    expect(service.homeworkReads, 1);
    await tester.tap(find.bySemanticsLabel('刷新今天').first);
    await tester.pumpAndSettle();
    expect(find.text('合成下午课'), findsOneWidget);
    await tester.pumpWidget(host('b'));
    await tester.pumpAndSettle();
    expect(find.text('合成下午课'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
