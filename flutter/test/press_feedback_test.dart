import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/widgets/press_feedback.dart';

void main() {
  testWidgets('touch compression cancels on scroll and honors reduced motion', (tester) async {
    Future<void> host(bool reduced) => tester.pumpWidget(CupertinoApp(
      home: Builder(builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: Center(child: PressFeedback(child: CupertinoButton(
          onPressed: () {}, child: const Text('打开课程'),
        ))),
      )),
    ));
    double target() => tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;
    await host(false);
    final gesture = await tester.startGesture(tester.getCenter(find.text('打开课程')));
    await tester.pump(const Duration(milliseconds: 150));
    expect(target(), lessThan(1));
    await gesture.moveBy(const Offset(0, 30));
    await tester.pumpAndSettle();
    expect(target(), 1);
    await gesture.cancel();
    await host(true);
    final reduced = await tester.startGesture(tester.getCenter(find.text('打开课程')));
    await tester.pump();
    expect(target(), 1);
    await reduced.cancel();
    await tester.pumpAndSettle();
  });
}
