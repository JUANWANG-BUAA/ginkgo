import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/features/today/today_action_row.dart';

void main() {
  testWidgets('action row exposes button and cancellation restores feedback', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    var taps = 0;
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Center(
            child: TodayActionRow(title: '课程详情', onTap: () => taps++),
          ),
        ),
      ),
    );
    expect(
      tester.getSemantics(find.byType(TodayActionRow)),
      matchesSemantics(
        label: '课程详情',
        hint: '打开详情',
        isButton: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
        hasEnabledState: true,
        isEnabled: true,
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('课程详情')),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(taps, 0);
    await tester.tap(find.text('课程详情'));
    await tester.pumpAndSettle();
    expect(taps, 1);
    semantics.dispose();
  });

  testWidgets('reduced motion does not scale an action row while pressed', (
    tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: CupertinoPageScaffold(
            child: Center(
              child: TodayActionRow(title: '课程详情', onTap: () {}),
            ),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('课程详情')),
    );
    await tester.pump(const Duration(milliseconds: 200));
    for (final transition in tester.widgetList<ScaleTransition>(
      find.byType(ScaleTransition),
    )) {
      expect(transition.scale.value, 1);
    }
    await gesture.cancel();
    await tester.pumpAndSettle();
  });
}
