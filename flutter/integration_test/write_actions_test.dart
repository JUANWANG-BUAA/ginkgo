import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ginkgo_mirror/src/rust/frb_generated.dart';
import 'package:ginkgo_mirror/src/rust/api/live.dart' as live;

import 'support.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  setUpAll(() async => RustLib.init());
  testWidgets(
    'synthetic checkin and reservation confirmation with no upstream writes',
    (tester) async {
      // No account exists; native preflight must reject without a mutation request.
      final native = await live.submitCheckin(courseId: 'synthetic-no-account');
      expect(native.state, 'notSubmitted');
      await launch(tester);
      await tapMore(tester, '课程签到');
      await settle(tester);
      await tester.tap(find.byKey(const Key('checkin-submit-501')));
      await settle(tester);
      expect(find.text('确认签到？'), findsOneWidget);
      await tester.tap(find.text('确认签到'));
      await settle(tester);
      expect(find.textContaining('演示模式不会提交签到'), findsWidgets);
      await tapTab(tester, '图书馆');
      await tap(tester, '学院路馆', scrollKey: 'library-scroll');
      await tap(tester, 'A区', scrollKey: 'library-areas-scroll');
      await tap(tester, '08:00–10:00', scrollKey: 'library-slots-scroll');
      await show(
        tester,
        find.byKey(const Key('library-reserve-s1')),
        scrollKey: 'library-seats-scroll',
      );
      await tester.tap(find.byKey(const Key('library-reserve-s1')));
      await settle(tester);
      expect(find.text('确认预约？'), findsOneWidget);
      await tester.tap(find.text('确认预约'));
      await settle(tester);
      expect(find.text('演示模式不会提交预约'), findsOneWidget);
      expect(find.text('查看预约'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
