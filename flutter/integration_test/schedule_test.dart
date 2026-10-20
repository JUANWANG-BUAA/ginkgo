import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ginkgo_mirror/src/rust/frb_generated.dart';

import 'support.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  setUpAll(() async => RustLib.init());

  testWidgets(
    'schedule FFI lists courses, pushes detail, searches and preserves an uncached week',
    (tester) async {
      await launch(tester);
      await tapTab(tester, '课表');
      final course = find.byKey(const Key('schedule-course-u-0-1-1'));
      await show(tester, course, scrollKey: 'schedule-scroll');
      await tester.tap(course);
      await settle(tester);
      expect(find.text('课程详情'), findsOneWidget);
      await tester.tap(find.byType(CupertinoNavigationBarBackButton));
      await settle(tester);
      await tap(tester, '考试', scrollKey: 'schedule-scroll');
      await show(tester, find.text('考试安排'), scrollKey: 'schedule-scroll');
      expect(find.text('考试安排'), findsOneWidget);
      await tap(tester, '课程', scrollKey: 'schedule-scroll');
      final search = find.byKey(const Key('schedule-search'));
      await show(tester, search, scrollKey: 'schedule-scroll');
      await tester.enterText(search, '不存在');
      await settle(tester);
      expect(find.text('没有匹配的课程'), findsOneWidget);
      await tester.enterText(search, '');
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(tester);
      await tap(tester, '第 3 周', scrollKey: 'schedule-scroll');
      await show(
        tester,
        find.textContaining('第 3 周尚未缓存'),
        scrollKey: 'schedule-scroll',
      );
      expect(course, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
