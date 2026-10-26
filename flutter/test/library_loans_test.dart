import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/library_loans.dart';
import 'package:ginkgo_mirror/library_loans_page.dart';
import 'package:ginkgo_mirror/infrastructure/native_library_loans.dart';

const page = LibraryLoanPage(
  items: [LibraryLoan(id: 'fixture', title: '合成书名', dueAt: '2026-11-01')],
  page: 1,
  total: 101,
  hasMore: true,
);

class Loans implements LibraryLoansGateway {
  final calls = <int>[];
  LibraryLoansRead result = const LibraryLoansRead(data: page);
  Completer<LibraryLoansRead>? delayed;
  @override
  Future<LibraryLoansRead> libraryLoans({int page = 1}) async {
    calls.add(page);
    return delayed == null ? result : delayed!.future;
  }
}

Widget app(LibraryLoansGateway gateway, {bool enabled = true}) => CupertinoApp(
  home: TickerMode(
    enabled: enabled,
    child: LibraryLoansPage(gateway: gateway),
  ),
);
Future<void> read(WidgetTester tester, {bool refresh = false}) async {
  final button = find.text(refresh ? '刷新本人借阅' : '读取本人借阅');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  test('invalid business payload is a failure, not empty', () {
    expect(
      decodeLibraryLoans(const ReadOnlyResponse(payload: '{}', stale: false))
          .failure,
      FailureCode.changedResponse,
    );
    expect(
      decodeLibraryLoans(
        const ReadOnlyResponse(
          payload: '{"items":[],"page":1,"total":0,"hasMore":false}',
          stale: false,
        ),
      ).data!.items,
      isEmpty,
    );
    expect(
      decodeLibraryLoans(
        const ReadOnlyResponse(
          payload: '{}',
          stale: false,
          failure: FailureCode.sessionExpired,
        ),
      ).failure,
      FailureCode.sessionExpired,
    );
  });
  testWidgets('no automatic personal read; explicit success and pagination', (
    tester,
  ) async {
    final gateway = Loans();
    await tester.pumpWidget(app(gateway));
    await tester.pumpAndSettle();
    expect(gateway.calls, isEmpty);
    expect(find.textContaining('暂无当前借阅'), findsNothing);
    await read(tester);
    expect(find.text('合成书名'), findsOneWidget);
    expect(gateway.calls, [1]);
    gateway.result = const LibraryLoansRead(
      data: LibraryLoanPage(
        items: [LibraryLoan(id: 'second', title: '第二页合成书')],
        page: 2,
        total: 101,
        hasMore: false,
      ),
    );
    await tester.ensureVisible(find.text('下一页'));
    await tester.tap(find.text('下一页'));
    await tester.pumpAndSettle();
    expect(gateway.calls, [1, 2]);
    expect(find.text('第二页合成书'), findsOneWidget);
    expect(find.text('合成书名'), findsNothing);
  });
  testWidgets(
    'failure preserves old page; auth failure clears private records',
    (tester) async {
      final gateway = Loans();
      await tester.pumpWidget(app(gateway));
      await read(tester);
      gateway.result = const LibraryLoansRead(
        failure: FailureCode.changedResponse,
      );
      await read(tester, refresh: true);
      expect(find.text('合成书名'), findsOneWidget);
      expect(find.textContaining('数据结构发生变化'), findsOneWidget);
      expect(find.textContaining('暂无当前借阅'), findsNothing);
      gateway.result = const LibraryLoansRead(
        failure: FailureCode.sessionExpired,
      );
      await read(tester, refresh: true);
      expect(find.text('合成书名'), findsNothing);
      expect(find.textContaining('读者认证未完成'), findsOneWidget);
    },
  );
  testWidgets('confirmed empty replaces previous records', (tester) async {
    final gateway = Loans();
    await tester.pumpWidget(app(gateway));
    await read(tester);
    gateway.result = const LibraryLoansRead(
      data: LibraryLoanPage(items: [], page: 1, total: 0, hasMore: false),
    );
    await read(tester, refresh: true);
    expect(find.text('合成书名'), findsNothing);
    expect(find.textContaining('暂无当前借阅（本次查询已确认）'), findsOneWidget);
  });
  testWidgets(
    'hidden page drops data and late read without automatically reloading',
    (tester) async {
      final gateway = Loans()..delayed = Completer<LibraryLoansRead>();
      await tester.pumpWidget(app(gateway));
      await tester.tap(find.text('读取本人借阅'));
      await tester.pump();
      await tester.pumpWidget(app(gateway, enabled: false));
      gateway.delayed!.complete(const LibraryLoansRead(data: page));
      await tester.pumpAndSettle();
      await tester.pumpWidget(app(gateway));
      await tester.pumpAndSettle();
      expect(find.text('合成书名'), findsNothing);
      expect(gateway.calls, [1]);
    },
  );
  testWidgets('gateway change rejects late account response', (tester) async {
    final first = Loans()..delayed = Completer<LibraryLoansRead>();
    await tester.pumpWidget(app(first));
    await tester.tap(find.text('读取本人借阅'));
    await tester.pump();
    await tester.pumpWidget(app(Loans()));
    first.delayed!.complete(const LibraryLoansRead(data: page));
    await tester.pumpAndSettle();
    expect(find.text('合成书名'), findsNothing);
  });
  testWidgets('backgrounding clears page memory', (tester) async {
    final gateway = Loans();
    await tester.pumpWidget(app(gateway));
    await read(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.text('合成书名'), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(gateway.calls, [1]);
  });
}
