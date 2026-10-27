import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/shared/app_preferences.dart';
import 'package:ginkgo_mirror/features/grades/grades_page.dart';
import 'package:ginkgo_mirror/features/library/library_page.dart';
import 'package:ginkgo_mirror/features/tasks/tasks_page.dart';
import 'package:ginkgo_mirror/features/today/today_page.dart';
import 'package:ginkgo_mirror/workspace/workspace_shell.dart';
import 'package:ginkgo_mirror/workspace/workspace_tab_transition.dart';

import 'mirror_widget_test.dart'
    show ControlledService, mockLocalTaskSupportDirectory;

const double pageWidth = 430;

Finder transition(int index, {bool skipOffstage = true}) =>
    find.byWidgetPredicate(
      (widget) => widget is WorkspaceTabTransition && widget.index == index,
      skipOffstage: skipOffstage,
    );

double displacement(WidgetTester tester, int index) => tester
    .widget<Transform>(
      find
          .descendant(of: transition(index), matching: find.byType(Transform))
          .first,
    )
    .transform
    .storage[12];

/// The sheet itself never fades; only its edge decoration changes.
void expectNoFade(WidgetTester tester, int index) => expect(
  find.descendant(of: transition(index), matching: find.byType(Opacity)),
  findsNothing,
);

Finder pageEdge(int index) => find.descendant(
  of: transition(index),
  matching: find.byKey(const ValueKey('workspace-tab-page-edge')),
);

Finder pageSpine(int index) => find.descendant(
  of: transition(index),
  matching: find.byKey(const ValueKey('workspace-tab-page-spine')),
);

LinearGradient gradientOf(WidgetTester tester, Finder finder) =>
    (tester.widget<DecoratedBox>(finder).decoration as BoxDecoration).gradient!
        as LinearGradient;

Widget motionHarness(
  CupertinoTabController tabs, {
  bool tickerEnabled = true,
  AppPreferences? preferences,
  Widget Function(int)? page,
}) => ginkgoApp(
  preferences: preferences,
  home: TickerMode(
    enabled: tickerEnabled,
    child: WorkspaceTabMotion(
      controller: tabs,
      child: WorkspaceTabScaffold(
        controller: tabs,
        tabBar: CupertinoTabBar(
          items: [
            for (var i = 0; i < 5; i++)
              BottomNavigationBarItem(
                icon: const Icon(CupertinoIcons.circle),
                label: 'tab$i',
              ),
          ],
        ),
        tabBuilder: (_, index) => WorkspaceTabTransition(
          index: index,
          child: CupertinoTabView(
            builder: (_) => page?.call(index) ?? Text('page$index'),
          ),
        ),
      ),
    ),
  ),
);

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

Future<void> tapTab(WidgetTester tester, String label) => tester.tap(
  find.descendant(of: find.byType(CupertinoTabBar), matching: find.text(label)),
);

void main() {
  setUp(mockLocalTaskSupportDirectory);

  testWidgets('two original pages meet without a blank gap during a turn', (
    tester,
  ) async {
    phone(tester);
    final tabs = CupertinoTabController();
    addTearDown(tabs.dispose);
    await tester.pumpWidget(motionHarness(tabs));
    tabs.index = 1;
    await tester.pump();
    expect(find.byType(CupertinoTabView), findsNWidgets(2));
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 40));
      final outgoing = displacement(tester, 0);
      final incoming = displacement(tester, 1);
      expect(outgoing, lessThan(0));
      expect(incoming, greaterThan(0));
      expect(incoming - outgoing, closeTo(pageWidth, 0.001));
    }
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoTabView), findsOneWidget);
    expect(find.text('page0'), findsNothing);
    expect(find.text('page1'), findsOneWidget);
  });

  testWidgets(
    'outgoing page is painted but excluded from touch and semantics',
    (tester) async {
      phone(tester);
      final semantics = tester.ensureSemantics();
      try {
        final tabs = CupertinoTabController();
        addTearDown(tabs.dispose);
        await tester.pumpWidget(motionHarness(tabs));
        tabs.index = 1;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 30));
        expect(find.text('page0'), findsOneWidget);
        expect(find.text('page0').hitTestable(), findsNothing);
        expect(find.semantics.byLabel('page0'), findsNothing);
        expect(find.semantics.byLabel('page1'), findsOneWidget);
        expect(
          TickerMode.valuesOf(tester.element(find.text('page0'))).enabled,
          isFalse,
        );
        await tester.pumpAndSettle();
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('bottom bar swipes switch adjacent tabs and stop at the ends', (
    tester,
  ) async {
    phone(tester);
    final tabs = CupertinoTabController();
    addTearDown(tabs.dispose);
    await tester.pumpWidget(motionHarness(tabs));
    final bar = find.byType(CupertinoTabBar);
    await tester.drag(bar, const Offset(-110, 0));
    await tester.pumpAndSettle();
    expect(tabs.index, 1);
    await tester.drag(bar, const Offset(110, 0));
    await tester.pumpAndSettle();
    expect(tabs.index, 0);
    await tester.drag(bar, const Offset(110, 0));
    await tester.pumpAndSettle();
    expect(tabs.index, 0);
    tabs.index = 4;
    await tester.pumpAndSettle();
    await tester.drag(bar, const Offset(-110, 0));
    await tester.pumpAndSettle();
    expect(tabs.index, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'first page is still; index direction, full-width slide and 230ms completion',
    (tester) async {
      phone(tester);
      final tabs = CupertinoTabController();
      addTearDown(tabs.dispose);
      await tester.pumpWidget(motionHarness(tabs));
      expect(displacement(tester, 0), 0);
      expectNoFade(tester, 0);
      expect(
        find.byType(CupertinoTabView, skipOffstage: false),
        findsOneWidget,
      );
      for (final index in [1, 2, 3, 4, 2, 0]) {
        final previous = tabs.index;
        final direction = index > previous ? 1 : -1;
        await tapTab(tester, 'tab$index');
        await tester.pump();
        // The whole sheet starts one page width away, on the side it came from.
        expect(displacement(tester, index), direction * pageWidth);
        expect(pageEdge(index), findsOneWidget);
        expect(pageSpine(index), findsOneWidget);
        expectNoFade(tester, index);
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          displacement(tester, index).abs(),
          inExclusiveRange(0, pageWidth),
        );
        await tester.pump(const Duration(milliseconds: 130));
        expect(displacement(tester, index), 0);
        expect(gradientOf(tester, pageEdge(index)).colors.first.a, 0);
      }
      expect(
        find.byType(CupertinoTabView, skipOffstage: false),
        findsNWidgets(5),
      );
      await tester.pumpAndSettle();
      tabs.index = 0;
      await tester.pump();
      expect(displacement(tester, 0), 0);
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  testWidgets('page edge shadow and spine follow direction and clear at rest', (
    tester,
  ) async {
    phone(tester);
    final tabs = CupertinoTabController();
    addTearDown(tabs.dispose);
    await tester.pumpWidget(motionHarness(tabs));
    // Both layers exist from the first frame but shade nothing at rest.
    expect(pageEdge(0), findsOneWidget);
    expect(pageSpine(0), findsOneWidget);
    expect(
      gradientOf(tester, pageEdge(0)).colors.map((color) => color.a),
      everyElement(0),
    );
    expect(
      gradientOf(tester, pageSpine(0)).colors.map((color) => color.a),
      everyElement(0),
    );

    tabs.index = 1;
    await tester.pump();
    // Arriving from the right: free edge shadow on the left, hinge on the
    // right.
    final shadow = gradientOf(tester, pageEdge(1));
    final spine = gradientOf(tester, pageSpine(1));
    expect(shadow.begin, Alignment.centerLeft);
    expect(shadow.end, Alignment.centerRight);
    expect(spine.begin, Alignment.centerRight);
    expect(spine.end, Alignment.centerLeft);
    expect(shadow.colors.first.a, greaterThan(0));
    expect(shadow.colors.last.a, 0);
    expect(spine.colors.first.a, greaterThan(0));
    expect(spine.colors.last.a, 0);
    final startAlpha = shadow.colors.first.a;

    await tester.pump(const Duration(milliseconds: 100));
    expect(
      gradientOf(tester, pageEdge(1)).colors.first.a,
      inExclusiveRange(0, startAlpha),
    );

    await tester.pump(const Duration(milliseconds: 130));
    expect(gradientOf(tester, pageEdge(1)).colors.first.a, 0);

    tabs.index = 0;
    await tester.pump();
    final reversedShadow = gradientOf(tester, pageEdge(0));
    final reversedSpine = gradientOf(tester, pageSpine(0));
    expect(reversedShadow.begin, Alignment.centerRight);
    expect(reversedShadow.end, Alignment.centerLeft);
    expect(reversedSpine.begin, Alignment.centerLeft);
    expect(reversedSpine.end, Alignment.centerRight);
    expect(reversedShadow.colors.first.a, greaterThan(0));
  });

  testWidgets(
    'system and app reduce motion are zero-frame and cancel active motion',
    (tester) async {
      phone(tester);
      final tabs = CupertinoTabController();
      final preferences = AppPreferences(writer: (_) async {});
      addTearDown(tabs.dispose);
      addTearDown(preferences.dispose);
      await tester.pumpWidget(motionHarness(tabs, preferences: preferences));
      tabs.index = 2;
      await tester.pump();
      expect(displacement(tester, 2), pageWidth);
      await preferences.update(reduceMotion: true);
      await tester.pump();
      expect(displacement(tester, 2), 0);
      expect(gradientOf(tester, pageEdge(2)).colors.first.a, 0);
      tabs.index = 0;
      await tester.pump();
      expectNoFade(tester, 0);
      expect(tester.binding.transientCallbackCount, 0);
      await preferences.update(reduceMotion: false);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pump();
      tabs.index = 4;
      await tester.pump();
      expect(displacement(tester, 4), 0);
      expectNoFade(tester, 4);
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  testWidgets(
    'rapid selection, inactive ticker and lifecycle never replay stale motion',
    (tester) async {
      phone(tester);
      final tabs = CupertinoTabController();
      addTearDown(tabs.dispose);
      await tester.pumpWidget(motionHarness(tabs));
      tabs.index = 4;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      tabs.index = 1;
      await tester.pump();
      expect(displacement(tester, 1), -pageWidth);
      tabs.index = 3;
      tabs.index = 0;
      await tester.pump();
      expect(displacement(tester, 0), -pageWidth);
      await tester.pumpWidget(motionHarness(tabs, tickerEnabled: false));
      expect(displacement(tester, 0), 0);
      tabs.index = 2;
      await tester.pump();
      expect(displacement(tester, 2), 0);
      await tester.pumpWidget(motionHarness(tabs));
      expect(displacement(tester, 2), 0);
      tabs.index = 3;
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(displacement(tester, 3), 0);
      tabs.index = 4;
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(displacement(tester, 4), 0);
      expect(tester.binding.transientCallbackCount, 0);
      // Dispose while a ticker is active as well.
      tabs.index = 0;
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'animation frames do not rebuild pages or replace their navigator',
    (tester) async {
      phone(tester);
      final tabs = CupertinoTabController();
      addTearDown(tabs.dispose);
      final builds = <int, int>{};
      await tester.pumpWidget(
        motionHarness(
          tabs,
          page: (index) => Builder(
            builder: (_) {
              builds[index] = (builds[index] ?? 0) + 1;
              return Text('page$index');
            },
          ),
        ),
      );
      final original = tester.state<NavigatorState>(
        find.descendant(of: transition(0), matching: find.byType(Navigator)),
      );
      tabs.index = 4;
      await tester.pump();
      final count = builds[4];
      for (var frame = 0; frame < 15; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(builds[4], count);
      expect(builds.keys, unorderedEquals([0, 4]));
      expect(
        tester.state<NavigatorState>(
          find.descendant(
            of: transition(0, skipOffstage: false),
            matching: find.byType(Navigator, skipOffstage: false),
          ),
        ),
        same(original),
      );
      expect(
        TickerMode.valuesOf(
          tester.element(find.text('page0', skipOffstage: false)),
        ).enabled,
        isFalse,
      );
    },
  );

  testWidgets(
    'mobile preserves detail stack and filter through rapid switching and back during motion',
    (tester) async {
      phone(tester);
      await tester.pumpWidget(GinkgoApp(service: ControlledService()));
      await tester.pumpAndSettle();
      await tapTab(tester, '课表');
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('schedule-search')), '合成筛选');
      await tester.pumpAndSettle();
      await tapTab(tester, '作业');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('homework-spoc:a')));
      await tester.pumpAndSettle();
      final detailNavigator = Navigator.of(tester.element(find.text('作业详情')));
      await tapTab(tester, '预约');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      await tapTab(tester, '作业');
      await tester.pump();
      expect(find.text('作业详情'), findsOneWidget);
      expect(
        Navigator.of(tester.element(find.text('作业详情'))),
        same(detailNavigator),
      );
      expect(displacement(tester, 3), -pageWidth);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('作业详情'), findsNothing);
      expect(find.text('再返回一次退出 Ginkgo'), findsNothing);
      await tapTab(tester, '课表');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: find.byKey(const Key('schedule-search')),
                matching: find.byType(EditableText),
              ),
            )
            .controller
            .text,
        '合成筛选',
      );
      // Root back during entry goes to workspace, rather than exiting.
      await tapTab(tester, '预约');
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(TodayPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'schedule horizontal drag and both scroll positions survive switching',
    (tester) async {
      phone(tester);
      await tester.pumpWidget(GinkgoApp(service: ControlledService()));
      await tester.pumpAndSettle();
      await tapTab(tester, '课表');
      await tester.pumpAndSettle();
      await tester.tap(find.text('周课表'));
      await tester.pumpAndSettle();
      final horizontal = find.byKey(const Key('schedule-grid-horizontal'));
      final horizontalState = tester.state<ScrollableState>(
        find
            .descendant(of: horizontal, matching: find.byType(Scrollable))
            .first,
      );
      // The grid extends below the viewport; drag its visible upper rows,
      // not its geometric center (which is behind the bottom tab bar).
      await tester.dragFrom(
        tester.getTopLeft(horizontal) + const Offset(280, 100),
        const Offset(-210, 0),
      );
      await tester.pumpAndSettle();
      expect(horizontalState.position.pixels, greaterThan(0));
      final x = horizontalState.position.pixels;
      final verticalState = tester.state<ScrollableState>(
        find
            .descendant(of: transition(2), matching: find.byType(Scrollable))
            .first,
      );
      verticalState.position.jumpTo(120);
      await tester.pump();
      expect(verticalState.position.pixels, 120);
      expect(
        tester
            .widget<WorkspaceTabScaffold>(find.byType(WorkspaceTabScaffold))
            .controller
            .index,
        2,
      );
      await tapTab(tester, '预约');
      await tester.pump();
      await tapTab(tester, '课表');
      await tester.pumpAndSettle();
      expect(horizontalState.mounted, isTrue);
      expect(verticalState.mounted, isTrue);
      expect(horizontalState.position.pixels, x);
      expect(verticalState.position.pixels, 120);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'secondary shortcut routes push current stack and disarm root exit',
    (tester) async {
      phone(tester);
      var exits = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemNavigator.pop') exits++;
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(GinkgoApp(service: ControlledService()));
      await tester.pumpAndSettle();
      final open = tester
          .widget<TodayPage>(find.byType(TodayPage))
          .onOpenFeature!;
      final rootNavigator = Navigator.of(
        tester.element(find.byType(TodayPage)),
      );
      for (final entry in <String, Type>{
        'tasks': TasksPage,
        'grades': GradesPage,
        'library': LibraryPage,
      }.entries) {
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('再返回一次退出 Ginkgo'), findsOneWidget, reason: entry.key);
        open(entry.key);
        await tester.pumpAndSettle();
        expect(find.byType(entry.value), findsOneWidget);
        expect(
          Navigator.of(tester.element(find.byType(entry.value))),
          same(rootNavigator),
        );
        expect(find.text('再返回一次退出 Ginkgo'), findsNothing);
        await tapTab(tester, '预约');
        await tester.pump();
        await tapTab(tester, '工作台');
        await tester.pump();
        expect(find.byType(entry.value), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(TodayPage), findsOneWidget);
        expect(find.text('再返回一次退出 Ginkgo'), findsNothing);
        expect(exits, 0);
      }
      open('not-a-destination');
      await tester.pump();
      expect(rootNavigator.canPop(), isFalse);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
