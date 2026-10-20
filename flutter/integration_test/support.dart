import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/mirror_service.dart';

/// Advance a fixed number of frames. Live mode can wait indefinitely for an
/// engine frame that never arrives, even though the page is stable.
Future<void> settle(WidgetTester tester, {int frames = 20}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> show(
  WidgetTester tester,
  Finder finder, {
  String scrollKey = 'classroom-scroll',
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await settle(tester);
  final rootScrollable = find
      .descendant(
        of: find.byKey(Key(scrollKey)),
        matching: find.byType(Scrollable),
      )
      .first;
  for (var i = 0; finder.evaluate().isEmpty && i < 30; i++) {
    final position = tester.state<ScrollableState>(rootScrollable).position;
    if (position.pixels <= position.minScrollExtent) break;
    await tester.drag(
      rootScrollable,
      Offset(0, (position.pixels - position.minScrollExtent).clamp(0.0, 300.0)),
    );
    await settle(tester);
  }
  await tester.scrollUntilVisible(
    finder,
    180,
    scrollable: find
        .descendant(
          of: find.byKey(Key(scrollKey)),
          matching: find.byType(Scrollable),
        )
        .first,
    maxScrolls: 30,
  );
  await settle(tester);
  final rect = tester.getRect(finder);
  final visibleTop = MediaQuery.paddingOf(tester.element(finder)).top + 64;
  if (rect.top < visibleTop) {
    final scrollable = find
        .descendant(
          of: find.byKey(Key(scrollKey)),
          matching: find.byType(Scrollable),
        )
        .first;
    final position = tester.state<ScrollableState>(scrollable).position;
    final available = position.pixels - position.minScrollExtent;
    await tester.drag(
      scrollable,
      Offset(
        0,
        (visibleTop - rect.top + 20).clamp(
          0.0,
          available.clamp(0.0, double.infinity),
        ),
      ),
    );
    await settle(tester);
  }
}

Future<void> tap(
  WidgetTester tester,
  String label, {
  String scrollKey = 'classroom-scroll',
}) async {
  final finder = find.text(label);
  await show(tester, finder, scrollKey: scrollKey);
  await tester.tap(finder.first);
  await settle(tester);
}

/// Tap a bottom-tab label without invoking the page-scroll helper.
Future<void> tapTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).first);
  await settle(tester);
}

Future<void> launch(
  WidgetTester tester, {
  MirrorService service = const NativeMirrorService(),
}) async {
  await tester.pumpWidget(GinkgoApp(key: UniqueKey(), service: service));
  await settle(tester, frames: 30);
}
