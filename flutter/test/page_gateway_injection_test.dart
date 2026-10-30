import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/features/bykc/bykc_page.dart';
import 'package:ginkgo_mirror/features/graduate/graduate_page.dart';
import 'package:ginkgo_mirror/main.dart';

/// A page must never compose its own adapter: a fallback locator would give
/// the page its own adapter instance and therefore its own account binding.
/// Without a gateway the page says so instead of quietly reading as somebody
/// else.
void main() {
  testWidgets('the bykc page without a gateway reports the missing gateway', (
    tester,
  ) async {
    await tester.pumpWidget(ginkgoApp(home: const BykcPage()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('本地服务暂时不可用，请重试'), findsOneWidget);
    // No catalogue rows: the page did not read anything at all.
    expect(find.text('课程库'), findsOneWidget);
    expect(find.text('合成博雅课程'), findsNothing);
  });

  testWidgets('the graduate page without a gateway reports the missing gateway', (
    tester,
  ) async {
    await tester.pumpWidget(ginkgoApp(home: const GraduatePage()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Both graduate sections report it; neither reads anything.
    expect(find.text('本地服务暂时不可用，请重试'), findsWidgets);
  });
}
