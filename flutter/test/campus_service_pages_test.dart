import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/features/checkin/checkin_page.dart';
import 'package:ginkgo_mirror/features/classroom/classroom_page.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/features/notices/notices_page.dart';
import 'package:ginkgo_mirror/features/shuttle/shuttle_page.dart';
import 'package:ginkgo_mirror/features/tasks/tasks_page.dart';

import 'mirror_widget_test.dart' show ControlledService, checkInFixture;

/// One pending read per page. Nothing here reaches native bindings, demo
/// initialization or a school network.
class PendingPageService extends ControlledService {
  final noticesRequests = <Completer<ReadOnlyResponse>>[];
  final noticesForces = <bool>[];
  final shuttleRequests = <Completer<ReadOnlyResponse>>[];
  final tasksRequests = <Completer<ReadOnlyResponse>>[];

  @override
  Future<ReadOnlyResponse> notices({bool forceRefresh = false}) {
    final request = Completer<ReadOnlyResponse>();
    noticesRequests.add(request);
    noticesForces.add(forceRefresh);
    return request.future;
  }

  @override
  Future<ReadOnlyResponse> shuttleTimetable() {
    final request = Completer<ReadOnlyResponse>();
    shuttleRequests.add(request);
    return request.future;
  }

  @override
  Future<ReadOnlyResponse> editTasks({
    required String root,
    required String action,
    String? id,
    String? title,
    String? due,
    bool? completed,
  }) {
    if (action != 'load') {
      throw UnimplementedError('Unexpected task write: $action');
    }
    final request = Completer<ReadOnlyResponse>();
    tasksRequests.add(request);
    return request.future;
  }
}

final _rooms = ClassroomResponse(
  buildings: [
    ClassroomBuilding(
      name: '教学楼 A',
      rooms: [
        ClassroomRow(
          id: 'room-1',
          name: '教室 1',
          floor: '1',
          sections: Int32List.fromList([1, 2]),
          longestRun: 2,
          sectionStates: const [],
        ),
      ],
    ),
  ],
  roomCount: 1,
  buildingCount: 1,
  freeSlotCount: 2,
  fromCache: false,
);

ReadOnlyResponse _notices() => ReadOnlyResponse(
  stale: false,
  payload: jsonEncode([
    {
      'title': '合成校园通知',
      'published_at': '2026-10-20 10:00',
      'url': 'https://news.example.test/1',
      'summary': '合成摘要',
    },
  ]),
);

ReadOnlyResponse _timetable() => ReadOnlyResponse(
  stale: false,
  payload: jsonEncode({
    'source': 'https://shuttle.example.test/published-timetable',
    'tables': [
      {
        'left': '合成甲校区 → 合成乙校区',
        'right': '合成乙校区 → 合成甲校区',
        'sections': [
          {
            'label': '星期一至星期五',
            'left': [
              {'index': '1', 'time': '09:00', 'capacity': '45'},
            ],
            'right': [
              {'index': '1', 'time': '10:15', 'capacity': '48'},
            ],
          },
        ],
      },
    ],
  }),
);

final _tasks = ReadOnlyResponse(
  stale: false,
  payload: jsonEncode([
    {'id': 'one', 'title': '合成待办', 'due': '2026-10-22', 'completed': false},
  ]),
);

/// Wide windows render the desktop identity; phones keep the native title.
void desktopViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void expectHeaderIdentity(
  WidgetTester tester,
  String section,
  String subtitle,
  IconData icon,
) {
  final header = find.byType(ApplePageHeader);
  expect(header, findsOneWidget);
  expect(
    find.descendant(of: header, matching: find.text(section)),
    findsOneWidget,
  );
  expect(
    find.descendant(of: header, matching: find.text(subtitle)),
    findsOneWidget,
  );
  expect(
    find.descendant(of: header, matching: find.byIcon(icon)),
    findsOneWidget,
  );
}

void expectBrandedLoading(
  WidgetTester tester,
  String label, {
  int leafSize = 36,
}) {
  expect(find.byType(CupertinoActivityIndicator), findsNothing);
  expect(find.byType(GinkgoLoadingView), findsOneWidget);
  expect(find.text(label), findsOneWidget);
  final leaves = tester
      .widgetList<GinkgoActivity>(
        find.descendant(
          of: find.byType(GinkgoLoadingView),
          matching: find.byType(GinkgoActivity),
        ),
      )
      .toList();
  expect(leaves, hasLength(1));
  expect(leaves.single.size, leafSize);
}

void expectSmallLeaf(WidgetTester tester, Finder scope) {
  expect(find.byType(CupertinoActivityIndicator), findsNothing);
  final leaves = tester
      .widgetList<GinkgoActivity>(
        find.descendant(of: scope, matching: find.byType(GinkgoActivity)),
      )
      .toList();
  expect(leaves, hasLength(1));
  expect(leaves.single.size, 17);
}

final _refreshIcon = find.byIcon(CupertinoIcons.refresh);

void main() {
  testWidgets('checkin loads with the branded view, then refreshes quietly', (
    tester,
  ) async {
    desktopViewport(tester);
    final service = PendingPageService();
    await tester.pumpWidget(ginkgoApp(home: CheckInPage(service: service)));
    expectBrandedLoading(tester, '正在读取 iClass 课程…', leafSize: 24);
    expectHeaderIdentity(
      tester,
      '工作台',
      '查看课程签到状态与记录',
      CupertinoIcons.checkmark_seal,
    );

    service.checkinRequests.single.complete(checkInFixture);
    await tester.pumpAndSettle();
    expect(find.byType(GinkgoLoadingView), findsNothing);
    expect(find.text('高等数学'), findsOneWidget);

    await tester.tap(_refreshIcon);
    await tester.pump();
    expectSmallLeaf(tester, find.byType(AppleGlassButton));
    expectSmallLeaf(tester, find.byKey(const Key('checkin-refreshing')));
    service.checkinRequests.last.complete(checkInFixture);
    await tester.pumpAndSettle();
    expect(find.byType(GinkgoActivity), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'classroom first query shows the branded view; refresh is small',
    (tester) async {
      desktopViewport(tester);
      final service = PendingPageService();
      await tester.pumpWidget(ginkgoApp(home: ClassroomPage(service: service)));
      expectBrandedLoading(tester, '正在读取空教室…');
      expect(find.text('正在读取学校日期'), findsOneWidget);
      expectHeaderIdentity(
        tester,
        '空间资源',
        '按校区、日期与节次查询空闲教室',
        CupertinoIcons.building_2_fill,
      );
      await tester.pump();
      expect(find.byType(GinkgoLoadingView), findsNothing);
      expect(find.text('选择范围后查询'), findsOneWidget);

      await tester.ensureVisible(find.text('查询空教室'));
      await tester.tap(find.text('查询空教室'));
      await tester.pump();
      expectBrandedLoading(tester, '正在读取空教室…');
      service.requests.single.complete(_rooms);
      await tester.pumpAndSettle();
      expect(find.byType(GinkgoLoadingView), findsNothing);
      expect(find.text('1 间 · 1 栋'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('刷新空教室').first);
      await tester.pump();
      expectSmallLeaf(tester, find.byType(AppleGlassButton));
      expectSmallLeaf(tester, find.byKey(const Key('classroom-refreshing')));
      service.requests.last.complete(_rooms);
      await tester.pumpAndSettle();
      expect(find.byType(GinkgoActivity), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('notices loads with the branded view and keeps its identity', (
    tester,
  ) async {
    desktopViewport(tester);
    final service = PendingPageService();
    await tester.pumpWidget(ginkgoApp(home: NoticesPage(service: service)));
    expectBrandedLoading(tester, '正在读取校园通知…');
    expectHeaderIdentity(tester, '校园', '查看通知与校内资讯', CupertinoIcons.news_solid);

    service.noticesRequests.single.complete(_notices());
    await tester.pumpAndSettle();
    expect(find.byType(GinkgoLoadingView), findsNothing);
    expect(find.text('合成校园通知'), findsOneWidget);
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a notices pull-to-refresh during an in-flight read is rerun, not dropped',
    (tester) async {
      desktopViewport(tester);
      final service = PendingPageService();
      await tester.pumpWidget(ginkgoApp(home: NoticesPage(service: service)));
      expect(service.noticesRequests, hasLength(1));

      // Pull to refresh while the initial read is still in flight.
      await tester.fling(
        find.byKey(const Key('notices-scroll')),
        const Offset(0, 400),
        1000,
      );
      await tester.pump();
      // The refresh is remembered: no blind second request starts mid-flight.
      expect(service.noticesRequests, hasLength(1));

      service.noticesRequests.single.complete(_notices());
      await tester.pump();
      // Once the initial read settles, the remembered refresh runs as forced.
      expect(service.noticesRequests, hasLength(2));
      expect(service.noticesForces.last, isTrue);
      service.noticesRequests.last.complete(_notices());
      await tester.pumpAndSettle();
      expect(find.text('合成校园通知'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shuttle keeps its plan and identity under the branded load', (
    tester,
  ) async {
    desktopViewport(tester);
    final service = PendingPageService();
    await tester.pumpWidget(
      ginkgoApp(
        home: ShuttlePage(
          service: service,
          now: DateTime.utc(2026, 10, 26, 8, 30),
        ),
      ),
    );
    expectBrandedLoading(tester, '正在读取校车时刻表…');
    expectHeaderIdentity(tester, '校园生活', '计划班次与实时余票，分开核对', CupertinoIcons.bus);

    service.shuttleRequests.single.complete(_timetable());
    await tester.pumpAndSettle();
    expect(find.byType(GinkgoLoadingView), findsNothing);
    final plan = find.byKey(const Key('shuttle-plan'));
    expect(plan, findsOneWidget);
    expect(
      find.descendant(of: plan, matching: find.text('下一班计划')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: plan, matching: find.text('09:00')),
      findsOneWidget,
    );

    await tester.tap(find.bySemanticsLabel('刷新校车时刻表').first);
    await tester.pump();
    expectSmallLeaf(tester, find.byType(AppleGlassButton));
    expect(plan, findsOneWidget);
    service.shuttleRequests.last.complete(_timetable());
    await tester.pumpAndSettle();
    expect(find.byType(GinkgoActivity), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'tasks load with the branded view and refresh with a small leaf',
    (tester) async {
      desktopViewport(tester);
      final service = PendingPageService();
      await tester.pumpWidget(
        ginkgoApp(
          home: TasksPage(service: service, storageRoot: '/synthetic'),
        ),
      );
      expectBrandedLoading(tester, '正在读取待办…');
      expectHeaderIdentity(
        tester,
        '工作台',
        '安排个人任务与截止时间',
        CupertinoIcons.list_bullet,
      );

      service.tasksRequests.single.complete(_tasks);
      await tester.pumpAndSettle();
      expect(find.byType(GinkgoLoadingView), findsNothing);
      expect(find.text('合成待办'), findsOneWidget);

      await tester.tap(find.byKey(const Key('tasks-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tasks-refresh')));
      await tester.pump();
      expectSmallLeaf(tester, find.byKey(const Key('tasks-refreshing')));
      expect(find.text('合成待办'), findsOneWidget);
      service.tasksRequests.last.complete(_tasks);
      await tester.pumpAndSettle();
      expect(find.byType(GinkgoActivity), findsNothing);
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
