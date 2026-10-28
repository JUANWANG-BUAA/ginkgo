import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/widgets/ginkgo_mark.dart';
import 'package:ginkgo_mirror/startup_page.dart';
import 'package:ginkgo_mirror/workspace/workspace_shell.dart';

void main() {
  testWidgets('the ginkgo mark paints at any size without overflow', (
    tester,
  ) async {
    for (final size in [24.0, 52.0, 104.0, 240.0]) {
      await tester.pumpWidget(
        ginkgoApp(
          home: Center(
            child: GinkgoMark(
              size: size,
              color: const Color(0xff2f6b3a),
              veinColor: const Color(0xffe5e4d8),
            ),
          ),
        ),
      );
      expect(find.byType(GinkgoMark), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('the mark draws in and the wordmark follows', (tester) async {
    await tester.pumpWidget(ginkgoApp(home: const StartupPage()));
    expect(find.byKey(const Key('startup-entrance')), findsOneWidget);
    expect(find.byKey(const Key('startup-mark')), findsOneWidget);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    expect(tester.takeException(), isNull);
    expect(find.text('Ginkgo'), findsOneWidget);
    expect(find.text('让校园生活井然有序'), findsOneWidget);
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
  });

  testWidgets('reduced motion shows the finished cold start', (tester) async {
    await tester.pumpWidget(
      ginkgoApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const StartupPage(),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('startup-entrance')), findsNothing);
    expect(find.byKey(const Key('startup-mark')), findsOneWidget);
    expect(find.text('Ginkgo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
