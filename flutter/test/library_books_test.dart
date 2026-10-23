import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/library_books_page.dart';
import 'package:ginkgo_mirror/src/rust/api/live.dart' as live;

/// Read-only stand-in: only the two catalogue calls are exercised here.
class FakeCatalog implements LibraryGateway {
  FakeCatalog({this.page, this.holdings, this.fail = false});
  final Map<String, dynamic>? page;
  final List<Map<String, dynamic>>? holdings;
  final bool fail;
  final List<(String, int)> searches = [];
  final List<String> holdingIds = [];

  @override
  bool get isDemo => false;

  @override
  Future<live.ReadOnlyResponse> libraryBooks({
    required String query,
    required int page,
  }) async {
    searches.add((query, page));
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

void main() {
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
    await tester.enterText(
      find.byKey(const Key('library-books-query')),
      '合成',
    );
    await tester.tap(find.byKey(const Key('library-books-submit')));
    await tester.pumpAndSettle();
    expect(service.searches.single, ('合成', 1));
    expect(find.text('合成书名'), findsOneWidget);
    expect(find.textContaining('共 30 条'), findsOneWidget);
    expect(find.textContaining('甲 · 乙'), findsOneWidget);

    await tester.tap(find.byKey(const Key('library-book-B1')));
    await tester.pumpAndSettle();
    expect(service.holdingIds.single, 'B1');
    expect(find.text('TP1/1 · 可借'), findsOneWidget);
    expect(find.textContaining('学院路'), findsOneWidget);
  });

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
    await tester.enterText(
      find.byKey(const Key('library-books-query')),
      '不存在',
    );
    await tester.tap(find.byKey(const Key('library-books-submit')));
    await tester.pumpAndSettle();
    expect(find.text('没有匹配的书目'), findsOneWidget);

    final failing = FakeCatalog(fail: true);
    await pump(tester, failing);
    await tester.enterText(
      find.byKey(const Key('library-books-query')),
      '合成',
    );
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
    await tester.enterText(
      find.byKey(const Key('library-books-query')),
      '合成',
    );
    await tester.tap(find.byKey(const Key('library-books-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-books-more')));
    await tester.pumpAndSettle();
    expect(service.searches.map((call) => call.$2), [1, 2]);
  });
}
