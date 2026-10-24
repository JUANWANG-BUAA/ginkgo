import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/app_preferences.dart';
import 'package:ginkgo_mirror/ginkgo_visuals.dart';
import 'package:ginkgo_mirror/loading_widgets.dart';
import 'package:ginkgo_mirror/workspace_shell.dart';

import 'workspace_tab_transition_test.dart'
    show displacement, motionHarness, pageWidth, phone, transition;

const double _matrixScale = 2;

Widget _matrixHost(AppPreferences preferences, Brightness brightness) =>
    ginkgoApp(
      preferences: preferences,
      brightness: brightness,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(_matrixScale)),
          child: CupertinoPageScaffold(
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        GinkgoIconTile(
                          icon: CupertinoIcons.calendar,
                          semanticLabel: '课表',
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            '合成课程名称与教室信息，用于验证大字号换行',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          children: const [
                            Icon(CupertinoIcons.clock, size: 16),
                            Text('合成课程安排'),
                            GinkgoBadge(
                              label: '今日已读取全部课程与考试安排',
                              icon: CupertinoIcons.checkmark,
                              compact: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const GinkgoBadge(
                      label: '合成状态标签：图书馆座位已预约，请按时签到',
                      icon: CupertinoIcons.book,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  test('the visual matrix covers all seven accents', () {
    expect(AppAccent.values.length, 7);
  });

  for (final width in [320.0, 430.0]) {
    testWidgets(
      '${width.toInt()}dp large type: every accent and brightness fits the visual primitives',
      (tester) async {
        tester.view.physicalSize = Size(width, 932);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final preferences = AppPreferences(writer: (_) async {});
        addTearDown(preferences.dispose);

        for (final brightness in Brightness.values) {
          for (final accent in AppAccent.values) {
            await preferences.update(accent: accent);
            await tester.pumpWidget(_matrixHost(preferences, brightness));
            await tester.pump();
            final reason =
                '${accent.name} / ${brightness.name} / ${width.toInt()}dp / '
                '${_matrixScale}x';
            expect(tester.takeException(), isNull, reason: reason);
            expect(find.byType(GinkgoIconTile), findsOneWidget, reason: reason);
            expect(find.byType(GinkgoBadge), findsNWidgets(2), reason: reason);
            expect(
              tester.getSize(find.byType(GinkgoIconTile)),
              const Size(44, 44),
              reason: reason,
            );
            final context = tester.element(find.byType(GinkgoIconTile));
            expect(
              CupertinoTheme.of(context).primaryColor,
              CupertinoDynamicColor.resolve(accent.color, context),
              reason: reason,
            );
            for (var i = 0; i < 2; i++) {
              expect(
                tester.getSize(find.byType(GinkgoBadge).at(i)).width,
                lessThanOrEqualTo(width - 32 + 0.01),
                reason: reason,
              );
            }
            expect(tester.takeException(), isNull, reason: reason);
          }
        }
      },
    );
  }

  testWidgets('loading view schedules no frames when animations are disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: GinkgoLoadingView(label: '正在读取课表…', detail: '保留上次结果'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.binding.transientCallbackCount, 0);
    expect(find.byType(GinkgoActivity), findsOneWidget);
    expect(find.text('正在读取课表…'), findsOneWidget);
  });

  testWidgets('loading view schedules no frames in an inactive ticker', (
    tester,
  ) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: TickerMode(
          enabled: false,
          child: GinkgoLoadingView(label: '正在读取课表…', detail: '保留上次结果'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.binding.transientCallbackCount, 0);
    expect(find.byType(GinkgoActivity), findsOneWidget);
    expect(find.text('正在读取课表…'), findsOneWidget);
  });

  testWidgets(
    'rapid reverse switching settles in 230ms and never copies the page navigator',
    (tester) async {
      phone(tester);
      final tabs = CupertinoTabController();
      addTearDown(tabs.dispose);
      await tester.pumpWidget(motionHarness(tabs));

      expect(
        find.byType(CupertinoTabView, skipOffstage: false),
        findsOneWidget,
      );
      final original = tester.state<NavigatorState>(
        find.descendant(of: transition(0), matching: find.byType(Navigator)),
      );

      tabs.index = 4;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      tabs.index = 1;
      await tester.pump();
      expect(displacement(tester, 1), -pageWidth);
      await tester.pump(const Duration(milliseconds: 40));
      tabs.index = 0;
      await tester.pump();
      expect(displacement(tester, 0), -pageWidth);

      // Every visited page keeps its single original view and navigator; the
      // transition never mounts a second copy for the motion.
      for (final index in [0, 1, 4]) {
        final page = transition(index, skipOffstage: false);
        expect(
          find.descendant(
            of: page,
            matching: find.byType(CupertinoTabView, skipOffstage: false),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: page,
            matching: find.byType(Navigator, skipOffstage: false),
          ),
          findsOneWidget,
        );
      }
      // Three visited tabs, each with exactly the one view above: no copy is
      // created for the transition.
      expect(
        find.byType(CupertinoTabView, skipOffstage: false),
        findsNWidgets(3),
      );
      // Only the selected page is on screen.
      expect(find.byType(CupertinoTabView), findsOneWidget);
      expect(
        tester.state<NavigatorState>(
          find.descendant(of: transition(0), matching: find.byType(Navigator)),
        ),
        same(original),
      );

      await tester.pump(const Duration(milliseconds: 230));
      expect(displacement(tester, 0), 0);
      // The fake clock can stop on the frame just before the ticker's
      // completion tick; one microsecond lets that tick run.
      await tester.pump(const Duration(microseconds: 1));
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
    },
  );

  testWidgets('reduced motion pins every switch at zero displacement', (
    tester,
  ) async {
    phone(tester);
    final tabs = CupertinoTabController();
    final preferences = AppPreferences(writer: (_) async {});
    addTearDown(tabs.dispose);
    addTearDown(preferences.dispose);
    await preferences.update(reduceMotion: true);
    await tester.pumpWidget(motionHarness(tabs, preferences: preferences));

    for (final index in [3, 1, 4, 0]) {
      tabs.index = index;
      await tester.pump();
      expect(displacement(tester, index), 0, reason: 'device reduce motion');
      expect(tester.binding.transientCallbackCount, 0);
    }

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pump();
    for (final index in [2, 4]) {
      tabs.index = index;
      await tester.pump();
      expect(
        displacement(tester, index),
        0,
        reason: 'system disable animations',
      );
      expect(tester.binding.transientCallbackCount, 0);
    }
  });
}
