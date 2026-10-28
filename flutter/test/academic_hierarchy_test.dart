import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/widgets/academic_widgets.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/features/grades/grades_page.dart';
import 'package:ginkgo_mirror/features/graduate/graduate_page.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/src/rust/api/live.dart' show ReadOnlyResponse;
import 'package:ginkgo_mirror/src/rust/api/mirror.dart';

import 'dart:convert';

import 'mirror_widget_test.dart' show ControlledService;

class DenseGradeService extends ControlledService {
  @override
  Future<GradeResponse> grades({
    String? termCode,
    bool forceRefresh = false,
  }) async => const GradeResponse(
    termId: '2026-2027-1',
    courses: [
      GradeCourse(
        id: 'long',
        name: '用于验证课程标题与学分计分方式在窄屏下自然换行的合成课程',
        credit: 3.5,
        code: 'SYNTHETIC-101',
        courseType: '专业选修课程',
        score: '优秀',
        scoreType: '五级制',
      ),
      GradeCourse(id: 'missing', name: '缺失学分课程', score: '待发布'),
    ],
    summary: GradeSummary(courseCount: 2, creditTotal: 3.5),
  );
}

class LongScoreService extends ControlledService {
  @override
  Future<GradeResponse> grades({
    String? termCode,
    bool forceRefresh = false,
  }) async => const GradeResponse(
    termId: '2026-2027-1',
    courses: [
      GradeCourse(
        id: 'long-score',
        name: '合成课程',
        score: '本课程成绩正在复核，学校将在核验完成后发布',
        scoreType: '以学校最终认定的课程考核结果为准',
      ),
    ],
    summary: GradeSummary(courseCount: 1, creditTotal: 0),
  );
}

void main() {
  testWidgets('long original grades stay within the normal width course row', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ginkgoApp(home: GradesPage(service: LongScoreService())),
    );
    await tester.pumpAndSettle();
    expect(find.text('本课程成绩正在复核，学校将在核验完成后发布'), findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.text('本课程成绩正在复核，学校将在核验完成后发布'),
        matching: find.byType(RichText),
      ),
    );
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(paragraph.maxLines, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening a deep report category starts at its course filters', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ginkgoApp(
        home: GraduatePage(
          loader: ({required report, required forceRefresh}) async =>
              ReadOnlyResponse(
                stale: false,
                payload: jsonEncode({
                  'sections': !report
                      ? []
                      : [
                          {
                            'title': '培养方案执行报告',
                            'rows': [],
                            'progress': {
                              'required': 32,
                              'earned': 2,
                              'pending': 1,
                            },
                          },
                          for (var group = 0; group < 15; group++)
                            {
                              'title': '合成类别 $group',
                              'rows': [
                                {'title': '类别要求与进度', 'detail': '学校原始说明'},
                                for (var course = 0; course < 25; course++)
                                  {
                                    'title': '合成课程 $group-$course',
                                    'detail': '学校原始记录',
                                    'credit': 2,
                                    'isCourse': true,
                                  },
                              ],
                            },
                        ],
                }),
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final scrollable = find
        .descendant(
          of: find.byKey(const Key('graduate-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    tester
        .state<ScrollableState>(scrollable)
        .position
        .jumpTo(
          tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
        );
    await tester.pumpAndSettle();
    await tester.tap(find.text('合成类别 14'));
    await tester.pumpAndSettle();
    tester
        .state<ScrollableState>(scrollable)
        .position
        .jumpTo(
          tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
        );
    await tester.pumpAndSettle();
    final reportOffset = tester
        .state<ScrollableState>(scrollable)
        .position
        .pixels;
    await tester.tap(find.text('查看本类课程'));
    await tester.pumpAndSettle();
    final search = find.byKey(const Key('graduate-search'));
    expect(search, findsOneWidget);
    final bounds = tester.getRect(search);
    expect(bounds.top, greaterThanOrEqualTo(0));
    expect(bounds.bottom, lessThan(1000));
    expect(tester.state<ScrollableState>(scrollable).position.pixels, 0);
    expect(
      find.descendant(
        of: find.byType(ApplePickerTile<String>),
        matching: find.text('合成类别 14'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('学分地图'));
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      closeTo(reportOffset, 1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('academic labels resolve contrast in light and dark large type', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        ginkgoApp(
          brightness: brightness,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.8),
                disableAnimations: true,
              ),
              child: const CupertinoPageScaffold(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      AcademicBadge(
                        '待确认',
                        tint: CupertinoColors.systemOrange,
                        icon: CupertinoIcons.question_circle,
                      ),
                      AcademicBadge(
                        '已完成',
                        tint: CupertinoColors.systemGreen,
                        icon: CupertinoIcons.checkmark_circle_fill,
                      ),
                      AcademicFactRow(
                        label: '这是用于验证窄屏的较长学籍字段名称',
                        value: '这是用于验证窄屏完整换行的较长学籍字段内容',
                      ),
                      AcademicMetricGrid(
                        children: [
                          AcademicMetric(
                            label: '已认定',
                            value: '32',
                            prominent: true,
                          ),
                          AcademicMetric(label: '要求', value: '38'),
                          AcademicMetric(label: '待确认', value: '2'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final unknown = find.descendant(
        of: find.byType(AcademicBadge).first,
        matching: find.text('待确认'),
      );
      expect(
        tester.widget<Text>(unknown).style!.color,
        CupertinoColors.systemOrange.resolveFrom(tester.element(unknown)),
      );
      final completed = find.text('已完成');
      expect(
        tester.widget<Text>(completed).style!.color,
        CupertinoColors.systemGreen.resolveFrom(tester.element(completed)),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'grade hierarchy wraps at 320px and keeps original score details',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ginkgoApp(
          brightness: Brightness.dark,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.8),
                disableAnimations: true,
              ),
              child: GradesPage(service: DenseGradeService()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('加权平均'), findsOneWidget);
      expect(find.text('平均绩点'), findsOneWidget);
      expect(find.text('—'), findsNWidgets(2));
      final scrollable = find
          .descendant(
            of: find.byKey(const Key('grades-scroll')),
            matching: find.byType(Scrollable),
          )
          .first;
      final course = find.byKey(const Key('grade-course-long'));
      await tester.scrollUntilVisible(course, 180, scrollable: scrollable);
      await tester.tap(course);
      await tester.pumpAndSettle();
      expect(find.text('课程成绩'), findsOneWidget);
      expect(find.text('优秀'), findsOneWidget);
      expect(find.widgetWithText(AcademicFactRow, '3.5'), findsOneWidget);
      expect(find.widgetWithText(AcademicFactRow, '五级制'), findsOneWidget);
      expect(find.widgetWithText(AcademicFactRow, '专业选修课程'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(CupertinoNavigationBarBackButton));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('grade-course-missing')),
        180,
        scrollable: scrollable,
      );
      expect(find.text('学分未提供'), findsOneWidget);
      expect(find.text('待发布'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
