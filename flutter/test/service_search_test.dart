import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/workspace/service_search.dart';
import 'package:ginkgo_mirror/workspace/workspace_catalog.dart';

import 'mirror_widget_test.dart' show ControlledService;

class SearchService extends ControlledService
    implements StudentServiceLinksGateway {
  @override
  String? studentServiceUrl(String id) => null;
  int scheduleReads = 0;
  @override
  Future<ScheduleResponse> schedule({
    String? termId,
    int? week,
    bool forceRefresh = false,
  }) {
    scheduleReads++;
    return super.schedule(
      termId: termId,
      week: week,
      forceRefresh: forceRefresh,
    );
  }
}

void main() {
  test('aliases refer to registered destinations with unique ids', () {
    final entries = searchableServices(workspaceDestinations);
    expect(entries.map((e) => e.id).toSet().length, entries.length);
    expect(
      entries.where((e) => e.matches('查书')).map((e) => e.id),
      contains('library'),
    );
    expect(
      entries.where((e) => e.matches('借书')).map((e) => e.id),
      contains('library-loans'),
    );
    expect(
      entries.where((e) => e.matches('账号')).map((e) => e.id),
      contains('settings'),
    );
    expect(
      entries.where((e) => e.matches('校车')).map((e) => e.id),
      contains('shuttle'),
    );
    expect(
      entries.where((e) => e.matches('课表')).map((e) => e.id),
      contains('schedule'),
    );
    expect(
      entries.where((e) => e.matches('打印')).map((e) => e.id),
      contains('official-print-guide'),
    );
    expect(
      entries.where((e) => e.matches('宿舍')).map((e) => e.id),
      contains('official-housing-guide'),
    );
    expect(
      entries.where((e) => e.matches('讲座')).map((e) => e.id),
      contains('campus-activities'),
    );
    for (final id in ['career-events', 'campus-activities']) {
      final entry = entries.singleWhere((entry) => entry.id == id);
      expect(entry.area, ServiceArea.information);
      expect(entry.sensitivity, '公开信息');
    }
  });
  testWidgets('More searches inline and routes through the shell', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = SearchService();
    await tester.pumpWidget(GinkgoApp(service: service));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(CupertinoTabBar),
        matching: find.text('更多'),
      ),
    );
    await tester.pumpAndSettle();
    final scheduleReadsBeforeSearch = service.scheduleReads;
    expect(find.byKey(const Key('more-account-settings')), findsOneWidget);
    expect(find.byKey(const Key('service-search')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('service-search')), '课表');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('service-result-schedule')), findsOneWidget);
    expect(find.byKey(const Key('more-account-settings')), findsNothing);
    expect(service.scheduleReads, scheduleReadsBeforeSearch);
    await tester.tap(find.byKey(const Key('service-result-schedule')));
    await tester.pumpAndSettle();
    expect(find.text('课表'), findsWidgets);
    expect(service.scheduleReads, greaterThan(scheduleReadsBeforeSearch));
    await tester.tap(
      find.descendant(
        of: find.byType(CupertinoTabBar),
        matching: find.text('更多'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CupertinoSearchTextField>(
            find.byKey(const Key('service-search')),
          )
          .controller!
          .text,
      '课表',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('More search distinguishes no results and official links', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(GinkgoApp(service: SearchService()));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(CupertinoTabBar),
        matching: find.text('更多'),
      ),
    );
    await tester.pumpAndSettle();
    final search = find.byKey(const Key('service-search'));
    await tester.enterText(search, '唯一不存在的标记ZXQ91');
    await tester.pumpAndSettle();
    expect(find.text('没有找到服务'), findsOneWidget);
    await tester.enterText(search, '打印');
    await tester.pumpAndSettle();
    expect(find.textContaining('前往官网'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('service-result-official-print-guide')),
    );
    await tester.pumpAndSettle();
    expect(find.text('无法打开官网'), findsOneWidget);
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('More keeps settings fixed and searchable', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(GinkgoApp(service: SearchService()));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(CupertinoTabBar),
        matching: find.text('更多'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('more-account-settings')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('service-search')), '账号');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('service-result-settings')), findsOneWidget);
    await tester.tap(find.byKey(const Key('service-result-settings')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-scroll')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
