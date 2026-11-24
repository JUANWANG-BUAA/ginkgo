import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/widgets/top_bounce_scroll_physics.dart';

void main() {
  Future<ScrollController> pump(WidgetTester tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      CupertinoApp(
        home: CustomScrollView(
          controller: controller,
          physics: const AlwaysScrollableScrollPhysics(
            parent: TopBounceScrollPhysics(),
          ),
          slivers: [
            SliverList.builder(
              itemCount: 40,
              itemBuilder: (_, i) => SizedBox(height: 80, child: Text('$i')),
            ),
          ],
        ),
      ),
    );
    return controller;
  }

  testWidgets('hard fling to the bottom never overshoots the extent', (
    tester,
  ) async {
    final controller = await pump(tester);
    final max = controller.position.maxScrollExtent;
    var worst = 0.0;
    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, -600),
      9000,
    );
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (controller.position.pixels > worst) {
        worst = controller.position.pixels;
      }
    }
    await tester.pumpAndSettle();
    expect(worst, lessThanOrEqualTo(max));
    expect(controller.position.pixels, max);
    expect(controller.position.maxScrollExtent, max);
  });

  testWidgets('dragging past the bottom is absorbed', (tester) async {
    final controller = await pump(tester);
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    final gesture = await tester.startGesture(const Offset(200, 400));
    await gesture.moveBy(const Offset(0, -200));
    await tester.pump();
    expect(controller.position.pixels, controller.position.maxScrollExtent);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.position.pixels, controller.position.maxScrollExtent);
  });

  testWidgets('top edge still bounces for pull-to-refresh', (tester) async {
    final controller = await pump(tester);
    final gesture = await tester.startGesture(const Offset(200, 300));
    await gesture.moveBy(const Offset(0, 120));
    await tester.pump();
    expect(controller.position.pixels, lessThan(0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.position.pixels, 0);
  });
}
