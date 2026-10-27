import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/features/graduate/graduate_credit_map_widgets.dart';
import 'package:ginkgo_mirror/features/graduate/graduate_page.dart';
import 'package:ginkgo_mirror/infrastructure/demo_mirror_service.dart';
import 'package:ginkgo_mirror/main.dart';

void main() {
  testWidgets('graduate academics embeds the strict credit map', (
    tester,
  ) async {
    await tester.pumpWidget(
      ginkgoApp(home: GraduatePage(service: const DemoMirrorService())),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GraduateCreditMapNodeCard), findsWidgets);
  });
}
