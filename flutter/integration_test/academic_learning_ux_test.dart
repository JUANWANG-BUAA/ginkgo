import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ginkgo_mirror/features/graduate/graduate_credit_map_widgets.dart';
import 'package:ginkgo_mirror/features/graduate/graduate_page.dart';
import 'package:ginkgo_mirror/features/learning/learning_course_page.dart';
import 'package:ginkgo_mirror/features/learning/learning_page.dart';
import 'package:ginkgo_mirror/features/schedule/schedule_grid.dart';
import 'package:ginkgo_mirror/features/schedule/schedule_page.dart';
import 'package:ginkgo_mirror/infrastructure/demo_mirror_service.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/src/rust/frb_generated.dart';

import 'support.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  setUpAll(() async => RustLib.init());

  testWidgets('academic and learning demo UX uses the revised navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = const DemoMirrorService();
    await tester.pumpWidget(ginkgoApp(home: SchedulePage(service: service)));
    await settle(tester);
    expect(find.byType(ScheduleGrid), findsNothing);
    expect(find.byKey(const Key('schedule-day-strip')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(ginkgoApp(home: GraduatePage(service: service)));
    await settle(tester);
    expect(find.text('详细学分地图'), findsOneWidget);
    expect(find.byType(GraduateCreditMapNodeCard), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(ginkgoApp(home: LearningPage(service: service, fileActions: platformActions)));
    await settle(tester);
    await tester.tap(find.text('学习服务演示课程'));
    await settle(tester);
    expect(find.byType(LearningCoursePage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('公告'));
    await settle(tester);
    expect(find.text('课程学习说明（演示）'), findsOneWidget);
    await tester.tap(find.text('测验'));
    await settle(tester);
    expect(find.text('阶段测验（仅展示，演示）'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
