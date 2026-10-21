import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/graduate_page.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/src/rust/api/live.dart';
import 'package:ginkgo_mirror/src/rust/api/mirror.dart';

void main() {
  testWidgets(
    'academic sections publish independently and keep snapshots after report failure',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <bool, List<Completer<ReadOnlyResponse>>>{
        false: [],
        true: [],
      };
      await tester.pumpWidget(
        ginkgoApp(
          home: GraduatePage(
            loader: ({required report, required forceRefresh}) {
              final pending = Completer<ReadOnlyResponse>();
              requests[report]!.add(pending);
              return pending.future;
            },
          ),
        ),
      );
      requests[false]!.single.complete(
        ReadOnlyResponse(
          stale: false,
          payload: jsonEncode({
            'sections': [
              {
                'title': '学籍信息',
                'rows': [
                  {'title': '学院', 'detail': '合成学院'},
                ],
              },
            ],
          }),
        ),
      );
      await tester.pump();
      expect(find.text('合成学院'), findsOneWidget);
      expect(find.byType(GraduateCreditProgress), findsNothing);
      final fixture = jsonDecode(
        File('../fixtures/graduate/execution-normal-v1.json')
            .readAsStringSync(),
      ) as Map;
      requests[true]!.single.complete(
        ReadOnlyResponse(
          stale: false,
          payload: jsonEncode(fixture['expected']),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('尚需 30'), findsOneWidget);
      expect(find.text('尚需 4'), findsOneWidget);
      expect(find.text('总学分要求'), findsNothing);
      expect(find.text('类别要求与进度'), findsNothing);
      await tester.tap(find.text('报告原始数据'));
      await tester.pumpAndSettle();
      expect(find.text('总学分要求'), findsOneWidget);
      expect(find.text('全校累计已修学分'), findsOneWidget);
      await tester.tap(find.text('报告原始数据'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('合成类别'));
      await tester.pumpAndSettle();
      expect(find.text('类别要求与进度'), findsOneWidget);
      expect(find.text('要求 6 · 已获 2 · 待考核 1 学分'), findsOneWidget);
      expect(find.text('合成课程'), findsNothing);
      await tester.tap(find.text('查看本类课程'));
      await tester.pumpAndSettle();
      expect(find.text('合成课程'), findsOneWidget);
      expect(find.text('2 学分'), findsOneWidget);
      expect(find.text('已完成'), findsOneWidget);
      await tester.tap(find.text('学分地图'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('刷新研究生教务').first);
      await tester.pump();
      requests[true]!.last.complete(
        const ReadOnlyResponse(
          stale: false,
          failure: FailureCode.serviceUnavailable,
        ),
      );
      await tester.pump();
      expect(find.text('尚需 30'), findsOneWidget);
      expect(find.text('合成学院'), findsOneWidget);
      // Retrying the failed report leaves the status request in flight.
      await tester.tap(find.text('重试'));
      await tester.pump();
      expect(requests[true]!.length, 3);
      expect(requests[false]!.length, 2);
      requests[false]!.last.complete(
        const ReadOnlyResponse(stale: false, payload: '{"sections":[]}'),
      );
      requests[true]!.last.complete(
        ReadOnlyResponse(
          stale: false,
          payload: jsonEncode(fixture['expected']),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('合成学院'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('course filters preserve unknown results and isolate metadata', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final sections = [
      {
        'title': '数学类',
        'rows': [
          {'title': '类别要求与进度', 'detail': '要求 6 · 已获 2 · 待考核 1 学分'},
          {
            'title': '已修课程',
            'detail': '2 学分 · 已完成',
            'isCourse': true,
            'completed': true,
          },
          {
            'title': '未修课程',
            'detail': '2 学分 · 未完成',
            'isCourse': true,
            'completed': false,
          },
          {'title': '待核课程', 'detail': '2 学分 · 待确认', 'isCourse': true},
        ],
      },
      {
        'title': '语言类',
        'rows': [
          {
            'title': '英语',
            'detail': '2 学分 · 未完成',
            'isCourse': true,
            'completed': false,
          },
        ],
      },
    ];
    await tester.pumpWidget(
      ginkgoApp(
        home: GraduatePage(
          loader: ({required report, required forceRefresh}) async =>
              ReadOnlyResponse(
                stale: false,
                payload: jsonEncode({'sections': report ? sections : []}),
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('课程'));
    await tester.pumpAndSettle();
    expect(find.text('4 条课程记录'), findsOneWidget);
    expect(find.text('类别要求与进度'), findsNothing);
    await tester.tap(find.text('完成状态'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('待确认').last);
    await tester.pumpAndSettle();
    expect(find.text('待核课程'), findsOneWidget);
    expect(find.text('未修课程'), findsNothing);
    expect(find.text('1 条课程记录'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('graduate-search')), '不存在');
    await tester.pumpAndSettle();
    expect(find.text('没有匹配的课程'), findsOneWidget);
    await tester.tap(find.text('清除筛选'));
    await tester.pumpAndSettle();
    expect(find.text('4 条课程记录'), findsOneWidget);
    await tester.tap(find.text('课程类别'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('语言类').last);
    await tester.pumpAndSettle();
    expect(find.text('英语'), findsOneWidget);
    expect(find.text('已修课程'), findsNothing);
    await tester.tap(find.text('英语'));
    await tester.pumpAndSettle();
    expect(find.text('培养方案课程'), findsOneWidget);
    await tester.tap(find.byType(CupertinoNavigationBarBackButton));
    await tester.pumpAndSettle();
    expect(find.text('1 条课程记录'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'large dark course view preserves filters through the full detail route',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const courseTitle = '用于验证大字号下完整课程名称和详情返回的合成研究生课程';
      const categoryTitle = '合成培养方案中的长类别名称';
      const detail = '2 学分 · 待确认 · 学校未提供课程认定结果';
      await tester.pumpWidget(
        ginkgoApp(
          brightness: Brightness.dark,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.8),
                disableAnimations: true,
              ),
              child: GraduatePage(
                loader: ({required report, required forceRefresh}) async =>
                    ReadOnlyResponse(
                      stale: false,
                      payload: jsonEncode({
                        'sections': report
                            ? [
                                {
                                  'title': '培养方案执行报告',
                                  'progress': {
                                    'required': 32,
                                    'earned': 2,
                                    'pending': 1,
                                  },
                                  'rows': [
                                    {'title': '全校累计已修学分', 'detail': '4'},
                                  ],
                                },
                                {
                                  'title': categoryTitle,
                                  'progress': {
                                    'required': 6,
                                    'earned': 2,
                                    'pending': 1,
                                  },
                                  'rows': [
                                    {
                                      'title': '类别要求与进度',
                                      'detail': '要求 6 · 已获 2 · 待考核 1 学分',
                                    },
                                    {
                                      'title': courseTitle,
                                      'detail': detail,
                                      'isCourse': true,
                                      'credit': 2,
                                      'semester': '合成学期',
                                    },
                                  ],
                                },
                              ]
                            : [],
                      }),
                    ),
              ),
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
      await tester.scrollUntilVisible(
        find.text('报告原始数据'),
        180,
        scrollable: scrollable,
      );
      await tester.tap(find.text('报告原始数据'));
      await tester.pumpAndSettle();
      expect(find.text('全校累计已修学分'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(categoryTitle),
        180,
        scrollable: scrollable,
      );
      await tester.tap(find.text(categoryTitle));
      await tester.pumpAndSettle();
      expect(find.text('要求 6 · 已获 2 · 待考核 1 学分'), findsOneWidget);
      expect(tester.takeException(), isNull);
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(find.text('课程'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('完成状态'),
        180,
        scrollable: scrollable,
      );
      await tester.tap(find.text('完成状态'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('待确认').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(courseTitle),
        180,
        scrollable: scrollable,
      );
      await tester.tap(find.text(courseTitle));
      await tester.pumpAndSettle();
      expect(find.text('培养方案课程'), findsOneWidget);
      expect(find.text(courseTitle), findsOneWidget);
      expect(find.text('2 学分'), findsOneWidget);
      expect(find.text('合成学期'), findsOneWidget);
      expect(find.text(detail), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(CupertinoNavigationBarBackButton));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('完成状态'),
        -180,
        scrollable: scrollable,
      );
      expect(find.text('待确认'), findsNWidgets(2));
      expect(find.text('1 条课程记录'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'credit progress keeps missing and zero requirements distinct at large text',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ginkgoApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
            child: CupertinoTheme(
              data: const CupertinoThemeData(brightness: Brightness.dark),
              child: const CupertinoPageScaffold(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      GraduateCreditProgress(
                        progress: {
                          'required': null,
                          'earned': 2,
                          'pending': null,
                        },
                      ),
                      GraduateCreditProgress(
                        progress: {'required': 0, 'earned': 0, 'pending': 0},
                      ),
                      GraduateCreditProgress(
                        progress: {'required': 4, 'earned': 6, 'pending': 5},
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
      expect(find.text('学分信息不完整'), findsOneWidget);
      final bars = find.byWidgetPredicate(
        (widget) =>
            widget is SizedBox &&
            widget.height == 5 &&
            widget.width == double.infinity,
      );
      expect(bars, findsOneWidget);
      expect(tester.getSize(bars).width, greaterThan(100));
      expect(find.text('本项无最低学分要求'), findsOneWidget);
      expect(find.text('尚需 未确认'), findsOneWidget);
      expect(find.text('尚需 0'), findsNWidgets(2));
      expect(find.text('待考核 5'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
