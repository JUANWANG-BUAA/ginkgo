import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/features/library/library_books_page.dart';
import 'package:ginkgo_mirror/src/rust/api/live.dart' as live;

/// Read-only stand-in: only the two catalogue calls are exercised here.
class FakeCatalog implements LibraryGateway {
  FakeCatalog({this.page, this.holdings, this.fail = false});
  final Map<String, dynamic>? page;
  final List<Map<String, dynamic>>? holdings;
  bool fail;
  final bookResponses = Queue<Future<live.ReadOnlyResponse>>();
  final List<(String, int)> searches = [];
  final List<(String, bool)> sorts = [];
  final List<String> holdingIds = [];

  @override
  bool get isDemo => false;

  @override
  Future<live.ReadOnlyResponse> libraryBooks({
    required String query,
    required int page,
    String sort = 'relevance',
    bool descending = true,
  }) async {
    searches.add((query, page));
    sorts.add((sort, descending));
    if (bookResponses.isNotEmpty) return bookResponses.removeFirst();
    if (fail) {
      return const live.ReadOnlyResponse(payload: null, stale: false);
    }
    return live.ReadOnlyResponse(
      payload: jsonEncode(this.page ?? const {}),
      stale: false,
    );
  }

  @override
  Future<live.ReadOnlyResponse> libraryHoldings(String bibId) async {
    holdingIds.add(bibId);
    if (fail) {
      return const live.ReadOnlyResponse(payload: null, stale: false);
    }
    return live.ReadOnlyResponse(
      payload: jsonEncode(holdings ?? const []),
      stale: false,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Map<String, dynamic> catalogPage(String title) => {
  'actualTotal': 30,
  'hasMore': true,
  'items': [
    {'bibId': 'B1', 'title': title},
  ],
};

live.ReadOnlyResponse bookResult(String title) => live.ReadOnlyResponse(
  payload: jsonEncode(catalogPage(title)),
  stale: false,
);

void main() {
  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('library-books-query')), '合成');
    await tap(tester, find.byKey(const Key('library-books-submit')));
  }

  Future<void> pump(WidgetTester tester, FakeCatalog service) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      CupertinoApp(home: LibraryBooksPage(service: service)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('empty query never reaches the school', (tester) async {
    final service = FakeCatalog();
    await pump(tester, service);
    await tester.tap(find.byKey(const Key('library-books-submit')));
    await tester.pumpAndSettle();
    expect(service.searches, isEmpty);
    expect(find.text('输入关键词开始检索'), findsOneWidget);
  });

  for (final keyboardAction in [false, true]) {
    testWidgets(
      'valid query hides keyboard and failed retry keeps rows (keyboard=$keyboardAction)',
      (tester) async {
        final service = FakeCatalog(page: catalogPage('合成保留书目'));
        await pump(tester, service);
        final field = find.byKey(const Key('library-books-query'));
        Future<void> submit(String text) async {
          await tester.showKeyboard(field);
          await tester.enterText(field, text);
          expect(
            tester
                .widget<EditableText>(find.byType(EditableText))
                .focusNode
                .hasFocus,
            isTrue,
          );
          expect(tester.testTextInput.isVisible, isTrue);
          if (keyboardAction) {
            await tester.testTextInput.receiveAction(TextInputAction.search);
          } else {
            await tester.tap(find.byKey(const Key('library-books-submit')));
          }
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<EditableText>(find.byType(EditableText))
                .focusNode
                .hasFocus,
            isFalse,
          );
          expect(tester.testTextInput.isVisible, isFalse);
        }

        await submit(' 合成 ');
        expect(service.searches, [('合成', 1)]);
        expect(find.text('合成保留书目'), findsOneWidget);
        service.fail = true;
        await submit(' 合成失败 ');
        expect(service.searches.last, ('合成失败', 1));
        expect(find.text('检索未完成，请稍后重试'), findsOneWidget);
        expect(find.text('合成保留书目'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('blank submission keeps focus without making a request', (
    tester,
  ) async {
    final service = FakeCatalog();
    await pump(tester, service);
    final field = find.byKey(const Key('library-books-query'));
    await tester.showKeyboard(field);
    await tester.enterText(field, '   ');
    await tester.tap(find.byKey(const Key('library-books-submit')));
    await tester.pumpAndSettle();
    expect(service.searches, isEmpty);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
    expect(tester.testTextInput.isVisible, isTrue);
  });

  for (final brightness in Brightness.values) {
    testWidgets('320dp 2x sort controls remain usable in ${brightness.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = FakeCatalog(page: catalogPage('合成窄屏书目'));
      await tester.pumpWidget(
        CupertinoApp(
          theme: CupertinoThemeData(brightness: brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: LibraryBooksPage(service: service),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('library-books-query')),
        '合成',
      );
      await tap(tester, find.byKey(const Key('library-books-submit')));
      await tap(tester, find.text('出版年'));
      await tap(tester, find.byKey(const Key('library-books-direction')));
      expect(service.sorts.last, ('pub_year', false));
      expect(find.text('合成窄屏书目'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('search renders hits and opens holdings', (tester) async {
    final service = FakeCatalog(
      page: {
        'page': 1,
        'pageSize': 20,
        'total': 30,
        'actualTotal': 30,
        'hasMore': true,
        'items': [
          {
            'bibId': 'B1',
            'title': '合成书名',
            'author': '甲 · 乙',
            'publisher': '合成出版社',
            'year': '2020',
            'callno': 'TP1/1',
            'isbn': '9787000000000',
          },
        ],
      },
      holdings: [
        {
          'callNo': 'TP1/1',
          'barCode': 'C1',
          'library': '学院路',
          'location': '三层',
          'status': '可借',
        },
      ],
    );
    await pump(tester, service);
    await tester.enterText(find.byKey(const Key('library-books-query')), '合成');
    await tester.tap(find.byKey(const Key('library-books-submit')));
    await tester.pumpAndSettle();
    expect(service.searches.single, ('合成', 1));
    expect(find.text('合成书名'), findsOneWidget);
    expect(find.textContaining('共 30 条'), findsOneWidget);
    expect(find.textContaining('甲 · 乙'), findsOneWidget);

    await tester.tap(find.byKey(const Key('library-book-0-B1')));
    await tester.pumpAndSettle();
    expect(service.holdingIds.single, 'B1');
    expect(find.text('馆藏地：学院路 · 三层'), findsOneWidget);
    expect(find.text('状态：可借'), findsOneWidget);
    expect(find.text('索书号：TP1/1'), findsOneWidget);
    expect(find.text('册条码：C1'), findsOneWidget);
  });

  testWidgets('search and sort tools stay compact above the results', (
    tester,
  ) async {
    final service = FakeCatalog(page: catalogPage('合成紧凑书目'));
    await pump(tester, service);
    expect(
      find.descendant(
        of: find.byKey(const Key('library-books-search-box')),
        matching: find.byKey(const Key('library-books-query')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('library-books-search-box')),
        matching: find.byKey(const Key('library-books-submit')),
      ),
      findsOneWidget,
    );
    await search(tester);
    expect(find.text('合成紧凑书目'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('library-book-0-B1'))).dy,
      lessThan(320),
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('library-books-sort-row')),
        matching: find.byKey(const Key('library-books-sort')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('library-books-sort-row')),
        matching: find.byKey(const Key('library-books-direction')),
      ),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const Key('library-books-sort-row'))).height,
      lessThan(80),
    );
  });

  testWidgets('read-only note starts collapsed and can be disclosed', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final service = FakeCatalog();
    await pump(tester, service);
    expect(find.text('检索说明'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('检索说明')), findsOneWidget);
    handle.dispose();
    expect(find.textContaining('不包含本人借阅记录'), findsNothing);
    await tap(tester, find.byKey(const Key('library-books-help')));
    expect(find.textContaining('不包含本人借阅记录'), findsOneWidget);
    expect(find.text('收起说明'), findsOneWidget);
    await tap(tester, find.byKey(const Key('library-books-help')));
    expect(find.textContaining('不包含本人借阅记录'), findsNothing);
  });

  testWidgets(
    'holdings put location first and discount repeated call numbers',
    (tester) async {
      final service = FakeCatalog(
        page: catalogPage('合成馆藏书目'),
        holdings: const [
          {
            'callNo': 'TP1/1',
            'barCode': 'C1',
            'library': '学院路',
            'location': '三层',
            'status': '可借',
          },
          {
            'callNo': 'TP1/1',
            'barCode': 'C2',
            'library': '学院路',
            'location': '三层',
            'status': '借出',
          },
          {
            'callNo': 'TP2/2',
            'barCode': 'C3',
            'library': '沙河',
            'location': '五层',
            'status': '在馆',
          },
          {'barCode': 'C4', 'library': '沙河', 'location': '五层'},
        ],
      );
      await pump(tester, service);
      await search(tester);
      await tap(tester, find.byKey(const Key('library-book-0-B1')));

      expect(find.text('馆藏地：学院路 · 三层'), findsNWidgets(2));
      expect(find.text('馆藏地：沙河 · 五层'), findsNWidgets(2));
      expect(find.text('状态：可借'), findsOneWidget);
      expect(find.text('状态：借出'), findsOneWidget);
      expect(find.text('状态：在馆'), findsOneWidget);
      expect(find.text('状态：未标注'), findsOneWidget);
      expect(find.text('索书号：TP1/1'), findsOneWidget);
      expect(find.text('同索书号：TP1/1'), findsOneWidget);
      expect(find.text('索书号：TP2/2'), findsOneWidget);
      expect(find.text('册条码：C1'), findsOneWidget);
      expect(find.text('册条码：C2'), findsOneWidget);
      expect(find.text('册条码：C3'), findsOneWidget);
      expect(find.text('册条码：C4'), findsOneWidget);

      double top(String text) => tester.getTopLeft(find.text(text).first).dy;
      expect(top('馆藏地：学院路 · 三层'), lessThan(top('状态：可借')));
      expect(top('状态：可借'), lessThan(top('索书号：TP1/1')));
      expect(top('索书号：TP1/1'), lessThan(top('册条码：C1')));
      expect(top('馆藏地：沙河 · 五层'), lessThan(top('索书号：TP2/2')));
      expect(top('索书号：TP2/2'), lessThan(top('册条码：C3')));
    },
  );

  testWidgets('empty result and failures stay explicit states', (tester) async {
    final empty = FakeCatalog(
      page: {
        'page': 1,
        'pageSize': 20,
        'total': 0,
        'actualTotal': 0,
        'hasMore': false,
        'items': <Object>[],
      },
    );
    await pump(tester, empty);
    await tester.enterText(find.byKey(const Key('library-books-query')), '不存在');
    await tester.tap(find.byKey(const Key('library-books-submit')));
    await tester.pumpAndSettle();
    expect(find.text('没有匹配的书目'), findsOneWidget);

    final failing = FakeCatalog(fail: true);
    await pump(tester, failing);
    await tester.enterText(find.byKey(const Key('library-books-query')), '合成');
    await tester.tap(find.byKey(const Key('library-books-submit')));
    await tester.pumpAndSettle();
    expect(find.text('检索未完成，请稍后重试'), findsOneWidget);
  });

  testWidgets('next page asks for page 2 only', (tester) async {
    final service = FakeCatalog(
      page: {
        'page': 1,
        'pageSize': 20,
        'total': 30,
        'actualTotal': 30,
        'hasMore': true,
        'items': [
          {'bibId': 'B1', 'title': '合成书名'},
        ],
      },
    );
    await pump(tester, service);
    await tester.enterText(find.byKey(const Key('library-books-query')), '合成');
    await tester.tap(find.byKey(const Key('library-books-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-books-more')));
    await tester.pumpAndSettle();
    expect(service.searches.map((call) => call.$2), [1, 2]);
  });

  testWidgets('sort and direction restart at page 1', (tester) async {
    final service = FakeCatalog(page: catalogPage('合成旧书'));
    await pump(tester, service);
    await search(tester);
    expect(service.sorts.single, ('relevance', true));
    for (final (label, sort) in [
      ('出版年', 'pub_year'),
      ('题名', 'title'),
      ('相关度', 'relevance'),
    ]) {
      await tap(tester, find.byKey(const Key('library-books-more')));
      expect(service.searches.last, ('合成', 2));
      await tap(tester, find.text(label));
      expect(service.searches.last, ('合成', 1));
      expect(service.sorts.last, (sort, true));
      expect(find.text('当前第 1 页'), findsOneWidget);
    }
    for (final descending in [false, true]) {
      await tap(tester, find.byKey(const Key('library-books-more')));
      expect(service.searches.last, ('合成', 2));
      await tap(tester, find.byKey(const Key('library-books-direction')));
      expect(service.searches.last, ('合成', 1));
      expect(service.sorts.last, ('relevance', descending));
    }
    expect(service.searches, hasLength(11));
  });

  testWidgets('failed sort keeps successful page and rows', (tester) async {
    final service = FakeCatalog(page: catalogPage('合成旧书'));
    await pump(tester, service);
    await search(tester);
    await tap(tester, find.byKey(const Key('library-books-more')));
    service.fail = true;
    await tap(tester, find.text('出版年'));
    expect(service.searches.last, ('合成', 1));
    expect(service.sorts.last, ('pub_year', true));
    expect(find.text('检索未完成，请稍后重试'), findsOneWidget);
    expect(find.text('合成旧书'), findsOneWidget);
    expect(find.text('当前第 2 页'), findsOneWidget);
    service.bookResponses.add(
      Future.value(
        const live.ReadOnlyResponse(payload: 'not-json', stale: false),
      ),
    );
    await tap(tester, find.byKey(const Key('library-books-direction')));
    expect(service.searches.last, ('合成', 1));
    expect(service.sorts.last, ('pub_year', false));
    expect(find.text('合成旧书'), findsOneWidget);
    expect(find.text('当前第 2 页'), findsOneWidget);
    expect(find.text('检索未完成，请稍后重试'), findsOneWidget);
  });

  for (final lateFailure in [false, true]) {
    testWidgets(
      'new provider ignores late ${lateFailure ? 'error' : 'success'}',
      (tester) async {
        final old = Completer<live.ReadOnlyResponse>();
        final fresh = Completer<live.ReadOnlyResponse>();
        final first = FakeCatalog(page: catalogPage('旧服务已有书目'));
        final second = FakeCatalog()..bookResponses.add(fresh.future);
        await pump(tester, first);
        await search(tester);
        first.bookResponses.add(old.future);
        await tester.tap(find.byKey(const Key('library-books-more')));
        await tester.pump();
        await tester.pumpWidget(
          CupertinoApp(home: LibraryBooksPage(service: second)),
        );
        await tester.pump();
        expect(find.text('旧服务已有书目'), findsNothing);
        expect(find.text('输入关键词开始检索'), findsOneWidget);
        await tester.enterText(
          find.byKey(const Key('library-books-query')),
          '合成',
        );
        await tester.tap(find.byKey(const Key('library-books-submit')));
        await tester.pump();
        expect(second.searches, [('合成', 1)]);
        // Neither a late result nor its finally may change the new request.
        if (lateFailure) {
          old.completeError(StateError('合成失败'));
        } else {
          old.complete(bookResult('迟到旧书'));
        }
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('迟到旧书'), findsNothing);
        expect(find.text('检索未完成，请稍后重试'), findsNothing);
        expect(
          tester
              .widget<CupertinoButton>(
                find.byKey(const Key('library-books-submit')),
              )
              .onPressed,
          isNull,
        );
        fresh.complete(bookResult('新服务书目'));
        await tester.pumpAndSettle();
        expect(find.text('新服务书目'), findsOneWidget);
        expect(find.text('旧服务已有书目'), findsNothing);
      },
    );
  }
}
