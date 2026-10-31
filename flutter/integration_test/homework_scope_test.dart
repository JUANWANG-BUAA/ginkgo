import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/school_rules.dart';
import 'package:ginkgo_mirror/features/homework/homework_page.dart';
import 'package:ginkgo_mirror/infrastructure/native_school_rules.dart';
import 'package:ginkgo_mirror/shared/course_visibility.dart';
import 'package:ginkgo_mirror/src/rust/frb_generated.dart';
import 'package:ginkgo_mirror/workspace/workspace_shell.dart';

import '../test/homework_deadline_classification_test.dart'
    show FakeAcademicGateway;
import 'support.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  setUpAll(() async {
    await RustLib.init();
    schoolRules = const NativeSchoolRules();
  });

  testWidgets('homework scope and combined deadline filter remain usable', (
    tester,
  ) async {
    final service = FakeAcademicGateway(
      const HomeworkResponse(
        termName: '合成学期',
        termCode: 'synthetic',
        items: [
          HomeworkItem(
            id: 'pending',
            courseName: '学生课程',
            title: '待交报告',
            dueAt: '2026-10-20',
            status: HomeworkStatus.pending,
          ),
          HomeworkItem(
            id: 'submitted',
            courseName: '学生课程',
            title: '已交报告',
            dueAt: '2026-10-20',
            status: HomeworkStatus.submitted,
          ),
          HomeworkItem(
            id: 'assistant',
            courseName: '助教课程',
            courseRole: 'assistant',
            title: '助教报告',
            dueAt: '2026-10-20',
            status: HomeworkStatus.pending,
          ),
        ],
      ),
    );
    await tester.pumpWidget(
      ginkgoApp(
        home: CourseVisibilityScope(
          account: 'synthetic-homework-scope-test',
          child: HomeworkPage(
            service: service,
            fileActions: platformActions,
            now: DateTime.utc(2026, 10, 23),
          ),
        ),
      ),
    );
    await settle(tester);
    if (const bool.fromEnvironment('GINKGO_HOMEWORK_CAPTURE')) {
      await binding.convertFlutterSurfaceToImage();
      await binding.takeScreenshot('homework-assistant-scope');
    }
    expect(find.text('待完成 1'), findsOneWidget);
    expect(find.text('管理课程范围'), findsOneWidget);
    expect(find.textContaining('筛选计数仅包含个人课程'), findsOneWidget);
    await tester.tap(find.byKey(const Key('homework-filter-pending')));
    await settle(tester);
    await tester.tap(find.text('已截止 2'));
    await settle(tester);
    expect(find.text('待交报告'), findsOneWidget);
    expect(find.text('已交报告'), findsNothing);
    await show(
      tester,
      find.byType(CupertinoSwitch),
      scrollKey: 'homework-scroll',
    );
    await tester.tap(find.byType(CupertinoSwitch));
    await settle(tester);
    await show(tester, find.text('助教报告'), scrollKey: 'homework-scroll');
    expect(find.text('待完成 1'), findsOneWidget);
    await show(
      tester,
      find.byKey(const Key('homework-search')),
      scrollKey: 'homework-scroll',
    );
    await tester.enterText(find.byKey(const Key('homework-search')), '不存在的作业');
    await settle(tester);
    expect(find.text('没有匹配的作业'), findsOneWidget);
    await show(tester, find.text('清除筛选'), scrollKey: 'homework-scroll');
    await tester.tap(find.text('清除筛选'));
    await settle(tester);
    expect(find.text('3 项作业'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
