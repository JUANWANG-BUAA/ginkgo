import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/bykc_detail_page.dart';
import 'package:ginkgo_mirror/bykc_page.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/src/rust/api/live.dart';
import 'package:ginkgo_mirror/src/rust/api/mirror.dart';

Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('../fixtures/bykc/$name-v1.json').readAsStringSync())
        as Map<String, dynamic>;
ReadOnlyResponse response(Map<String, dynamic> data) =>
    ReadOnlyResponse(payload: jsonEncode(data), stale: false);

class ControlledBykc {
  final requests = <BykcPart, List<Completer<ReadOnlyResponse>>>{};
  final forces = <BykcPart, List<bool>>{};

  Future<ReadOnlyResponse> load({
    required BykcPart part,
    required bool forceRefresh,
  }) {
    final request = Completer<ReadOnlyResponse>();
    (requests[part] ??= []).add(request);
    (forces[part] ??= []).add(forceRefresh);
    return request.future;
  }
}

void main() {
  testWidgets('BYKC completion categories group once without losing rows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ginkgoApp(
        home: BykcPage(
          loader: ({required part, required forceRefresh}) async => response(
            part == BykcPart.statistics
                ? {
                    'validCourseCount': 1,
                    'entries': [
                      {
                        'category': '博雅课程',
                        'subcategory': '艺术欣赏',
                        'required': 1,
                        'completed': 0,
                      },
                      {
                        'category': '博雅课程',
                        'subcategory': '安全教育',
                        'required': 1,
                        'completed': 1,
                      },
                      {
                        'category': '博雅课程',
                        'subcategory': '劳动实践',
                        'required': 0,
                        'completed': 0,
                      },
                    ],
                  }
                : {'courses': [], 'terms': []},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成统计'));
    await tester.pumpAndSettle();
    expect(find.text('博雅课程'), findsOneWidget);
    expect(find.text('艺术欣赏'), findsOneWidget);
    expect(find.text('安全教育'), findsOneWidget);
    expect(find.text('劳动实践'), findsOneWidget);
    expect(find.text('本项暂无要求'), findsOneWidget);
    expect(find.byType(BykcStatisticsCard), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'BYKC lazily loads independent tabs, keeps snapshots, and opens chosen detail',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = ControlledBykc();
      await tester.pumpWidget(ginkgoApp(home: BykcPage(loader: service.load)));
      await tester.pump();
      expect(service.requests.keys, [BykcPart.catalog]);
      service.requests[BykcPart.catalog]!.single.complete(
        response(fixture('catalog-normal')['expected'] as Map<String, dynamic>),
      );
      await tester.pumpAndSettle();
      expect(find.text('合成博雅课程'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('bykc-search')), '合成教师');
      await tester.pumpAndSettle();
      await tester.tap(find.text('已选课程'));
      await tester.pump();
      expect(service.requests.keys, [BykcPart.catalog, BykcPart.chosen]);
      expect(service.requests[BykcPart.statistics], isNull);
      service.requests[BykcPart.chosen]!.single.complete(
        response({
          'term': {'name': '合成学期'},
          'courses': fixture('chosen-normal')['expected'],
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('合成已选课程'), findsOneWidget);
      expect(find.text('已签到'), findsOneWidget);
      expect(find.text('已通过'), findsOneWidget);
      expect(find.text('成绩 92'), findsOneWidget);
      await tester.tap(find.text('合成已选课程'));
      await tester.pumpAndSettle();
      expect(find.byType(BykcDetailPage), findsOneWidget);
      expect(find.text('学习记录'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('10月20日 09:00'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('10月20日 09:00'), findsOneWidget);
      expect(service.requests[BykcPart.chosen], hasLength(1));
      await tester.tap(find.byType(CupertinoNavigationBarBackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('刷新博雅'));
      await tester.pump();
      await tester.tap(find.text('完成统计'));
      await tester.pump();
      expect(service.requests[BykcPart.statistics], hasLength(1));
      service.requests[BykcPart.statistics]!.single.complete(
        response(
          fixture('statistics-normal')['expected'] as Map<String, dynamic>,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('有效课程'), findsOneWidget);
      expect(find.text('5 门'), findsOneWidget);
      service.requests[BykcPart.chosen]!.last.complete(
        const ReadOnlyResponse(
          stale: false,
          failure: FailureCode.serviceUnavailable,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('5 门'), findsOneWidget);
      expect(find.text('保留上次结果'), findsNothing);
      await tester.tap(find.text('已选课程'));
      await tester.pumpAndSettle();
      expect(find.text('合成已选课程'), findsOneWidget);
      expect(find.text('保留上次结果'), findsOneWidget);
      expect(service.requests[BykcPart.chosen], hasLength(2));
      expect(service.forces[BykcPart.chosen], [false, true]);
      await tester.tap(find.text('课程库'));
      await tester.pumpAndSettle();
      final restoredSearch = tester.widget<CupertinoSearchTextField>(
        find.byKey(const Key('bykc-search')),
      );
      expect(restoredSearch.controller!.text, '合成教师');
      expect(
        find.descendant(
          of: find.byKey(
            ValueKey(
              'bykc-course-${fixture('catalog-normal')['expected']['courses'][0]['id']}',
            ),
          ),
          matching: find.text('合成教师'),
        ),
        findsOneWidget,
      );
      expect(find.text('合成博雅课程'), findsOneWidget);
      expect(service.requests[BykcPart.catalog], hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'large BYKC catalogs build visible rows and retain search on tab return',
    (tester) async {
      final catalog = {
        'terms': [],
        'courses': [
          for (var index = 0; index < 500; index++)
            {'id': index, 'name': 'Synthetic course $index'},
        ],
      };
      await tester.pumpWidget(
        ginkgoApp(
          home: BykcPage(
            loader: ({required part, required forceRefresh}) async => response(
              part == BykcPart.catalog
                  ? catalog
                  : {'term': null, 'courses': []},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('bykc-course-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('bykc-course-499')), findsNothing);
      await tester.enterText(find.byKey(const Key('bykc-search')), '499');
      await tester.pumpAndSettle();
      expect(find.text('Synthetic course 499'), findsOneWidget);
      expect(find.byKey(const ValueKey('bykc-course-0')), findsNothing);
      await tester.tap(find.text('已选课程'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('课程库'));
      await tester.pumpAndSettle();
      final search = tester.widget<CupertinoSearchTextField>(
        find.byKey(const Key('bykc-search')),
      );
      expect(search.controller!.text, '499');
      expect(find.text('Synthetic course 499'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('BYKC unknown term does not claim no selected courses', (
    tester,
  ) async {
    await tester.pumpWidget(
      ginkgoApp(
        home: BykcPage(
          loader: ({required part, required forceRefresh}) async => response(
            part == BykcPart.catalog
                ? fixture('catalog-normal')['expected'] as Map<String, dynamic>
                : {'term': null, 'courses': null},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('已选课程'));
    await tester.pumpAndSettle();
    expect(find.text('上游未提供有效学期范围，暂不能查询已选记录。'), findsOneWidget);
    expect(find.text('本学期暂无已选课程'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'BYKC progress preserves counts, caps the bar, and explains zero',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final entries =
          fixture('statistics-normal')['expected']['entries'] as List;
      await tester.pumpWidget(
        ginkgoApp(
          brightness: Brightness.dark,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
            child: CupertinoPageScaffold(
              child: ListView(
                children: [
                  for (final entry in entries)
                    BykcStatisticsCard(entry: entry as Map<String, dynamic>),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('0 / 0'), findsOneWidget);
      expect(find.text('本项暂无要求'), findsOneWidget);
      expect(find.text('还差 1 项'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('3 / 2'), 200);
      expect(find.text('3 / 2'), findsOneWidget);
      expect(find.text('已完成'), findsOneWidget);
      final factors = tester.widgetList<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(factors.every((widget) => (widget.widthFactor ?? 0) <= 1), isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
