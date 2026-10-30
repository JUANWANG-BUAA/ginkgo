import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/application/platform_actions.dart';
import 'package:ginkgo_mirror/infrastructure/demo_mirror_service.dart';
import 'package:ginkgo_mirror/features/reservations/reservation_widgets.dart';
import 'package:ginkgo_mirror/features/cgyy/cgyy_page.dart';
import 'package:ginkgo_mirror/features/classroom/classroom_page.dart';
import 'package:ginkgo_mirror/workspace/service_directory.dart';
import 'package:ginkgo_mirror/workspace/workspace_catalog.dart';
import 'package:ginkgo_mirror/widgets/resource_meter.dart';

void main() {
  testWidgets('resource snapshots preserve unknown, zero and excess values', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ginkgoApp(
        brightness: Brightness.dark,
        home: const CupertinoPageScaffold(
          child: SingleChildScrollView(
            child: Column(
              children: [
                ResourceMeter(
                  key: Key('unknown'),
                  label: '未知总量',
                  available: 8,
                  total: null,
                  unit: '座',
                ),
                ResourceMeter(
                  key: Key('zero'),
                  label: '零总量',
                  available: 0,
                  total: 0,
                  unit: '座',
                ),
                ResourceMeter(
                  key: Key('excess'),
                  label: '超额快照',
                  available: 14,
                  total: 10,
                  unit: '座',
                ),
                ResourceMeter(
                  key: Key('occupied'),
                  label: '全部占用',
                  available: 0,
                  total: 12,
                  unit: '座',
                ),
                ResourceMeter(
                  key: Key('unknown-free'),
                  label: '仅有总量',
                  available: null,
                  total: 20,
                  unit: '座',
                ),
                ResourceMeter(
                  key: Key('unknown-both'),
                  label: '没有数量',
                  available: null,
                  total: null,
                  unit: '座',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('8'), findsOneWidget);
    expect(find.text('座可用 · 总量未提供'), findsOneWidget);
    expect(find.text('可用数量未提供 · 共 20 座'), findsOneWidget);
    expect(find.text('官网未提供数量'), findsOneWidget);
    expect(find.text('座可用 · 共 0 座'), findsOneWidget);
    expect(find.text('暂未提供此类资源'), findsOneWidget);
    expect(find.text('14'), findsOneWidget);
    expect(find.text('座可用 · 共 10 座'), findsOneWidget);
    expect(find.bySemanticsLabel('未知总量 空闲比例'), findsNothing);
    expect(find.bySemanticsLabel('零总量 空闲比例'), findsNothing);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('超额快照 空闲比例'))
          .getSemanticsData()
          .value,
      '100%',
    );
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('全部占用 空闲比例'))
          .getSemanticsData()
          .value,
      '0%',
    );
    final fill = find.descendant(
      of: find.byKey(const Key('excess')),
      matching: find.byType(FractionallySizedBox),
    );
    expect(tester.widget<FractionallySizedBox>(fill).widthFactor, 1);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets(
    'reservation presses animate, cancel and release without submitting',
    (tester) async {
      var submissions = 0;
      await tester.pumpWidget(
        ginkgoApp(
          home: Center(
            child: ReservationActionButton(
              label: '预约',
              icon: CupertinoIcons.add_circled,
              onPressed: () => submissions++,
            ),
          ),
        ),
      );
      final scale = find.byType(AnimatedScale);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(CupertinoButton)),
      );
      await tester.pump(const Duration(milliseconds: 60));
      // Press target sits just under 1.0 so the row never visibly jumps.
      expect(tester.widget<AnimatedScale>(scale).scale, 0.96);
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(tester.widget<AnimatedScale>(scale).scale, 1);
      expect(submissions, 0);
      await tester.tap(find.byType(CupertinoButton));
      await tester.pumpAndSettle();
      expect(submissions, 1);
      expect(tester.widget<AnimatedScale>(scale).scale, 1);
      expect(tester.binding.hasScheduledFrame, isFalse);
    },
  );

  testWidgets(
    'busy disabled actions and reduced motion do not accumulate animation work',
    (tester) async {
      var submissions = 0;
      await tester.pumpWidget(
        ginkgoApp(
          home: Center(
            child: ReservationActionButton(
              buttonKey: const Key('busy-action'),
              label: '预约',
              icon: CupertinoIcons.add_circled,
              busy: true,
              primary: true,
              onPressed: () => submissions++,
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<CupertinoButton>(find.byKey(const Key('busy-action')))
            .onPressed,
        isNull,
      );
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
      expect(
        tester.widget<GinkgoActivity>(find.byType(GinkgoActivity)).size,
        16,
      );
      expect(
        find.ancestor(
          of: find.byType(GinkgoActivity),
          matching: find.byType(ColorFiltered),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('busy-action')));
      expect(submissions, 0);
      final disabled = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('busy-action'))),
      );
      await tester.pump(const Duration(milliseconds: 140));
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
      await disabled.cancel();
      // A busy indicator legitimately schedules frames; fixed pumps keep this
      // assertion bounded and avoid pumpAndSettle waiting on the spinner.
      await tester.pump(const Duration(milliseconds: 140));
      await tester.pumpWidget(
        ginkgoApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: Center(
                child: ReservationActionButton(
                  label: '预约',
                  icon: CupertinoIcons.add_circled,
                  onPressed: () => submissions++,
                ),
              ),
            ),
          ),
        ),
      );
      final pressed = await tester.startGesture(
        tester.getCenter(find.byType(CupertinoButton)),
      );
      await tester.pump();
      final animation = tester.widget<AnimatedScale>(
        find.byType(AnimatedScale),
      );
      expect(animation.scale, 1);
      expect(animation.duration, Duration.zero);
      await pressed.cancel();
      await tester.pumpAndSettle();
      expect(submissions, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the more surface wraps at 320px dark large type and opens every entry',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ginkgoApp(
          brightness: Brightness.dark,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.8),
                disableAnimations: true,
              ),
              child: CupertinoPageScaffold(
                child: ListView(
                  children: [
                    ServiceDirectory(
                      platformActions: const PlatformActions(),
                      service: const DemoMirrorService(),
                      destinations: workspaceDestinations,
                      onSignOut: () async {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final entry in <String, Type>{
        '研讨室': CgyyPage,
        '空教室': ClassroomPage,
      }.entries) {
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(entry.key));
        await tester.pumpAndSettle();
        await tester.tap(find.text(entry.key));
        await tester.pumpAndSettle();
        expect(find.byType(entry.value), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    },
  );
}
