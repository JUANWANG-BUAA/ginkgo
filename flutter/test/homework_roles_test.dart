import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/homework_page.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/src/rust/api/mirror.dart';

import 'mirror_widget_test.dart' show ControlledService;

class CourseRoleService extends ControlledService {
  @override
  Future<HomeworkResponse> homework({bool forceRefresh = false}) async =>
      const HomeworkResponse(
        termCode: 'synthetic-term',
        termName: '合成学期',
        items: [
          HomeworkItem(
            id: 'student',
            courseId: 'student-course',
            courseRole: 'student',
            courseName: '合成学生课程',
            title: '学生作业',
            status: HomeworkStatus.pending,
          ),
          HomeworkItem(
            id: 'assistant',
            courseId: 'assistant-course',
            courseRole: 'assistant',
            courseName: '合成助教课程',
            title: '助教作业',
            status: HomeworkStatus.pending,
          ),
          HomeworkItem(
            id: 'unknown',
            courseId: 'unknown-course',
            courseName: '合成未知课程',
            title: '未知归属作业',
            status: HomeworkStatus.pending,
          ),
        ],
      );
}

void main() {
  testWidgets(
    'assistant courses start collapsed and never inflate personal totals',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ginkgoApp(home: HomeworkPage(service: CourseRoleService())),
      );
      await tester.pumpAndSettle();
      final summary = find.byKey(const ValueKey('homework-summary-待完成'));
      expect(
        find.descendant(of: summary, matching: find.text('2')),
        findsOneWidget,
      );
      expect(find.text('2 项作业'), findsOneWidget);
      await tester.tap(find.byType(CupertinoSwitch));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: summary, matching: find.text('2')),
        findsOneWidget,
      );
      expect(find.text('3 项作业'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('homework-assistant')),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('homework-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('助教课程 · 不代表个人待交作业'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
