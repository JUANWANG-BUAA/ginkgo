import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/library_loans.dart';
import 'package:ginkgo_mirror/application/session_memory_cache.dart';
import 'package:ginkgo_mirror/features/library/library_loans_page.dart';
import 'package:ginkgo_mirror/infrastructure/native_library_loans.dart';
import 'package:ginkgo_mirror/src/rust/api/live.dart' as live;
import 'package:ginkgo_mirror/widgets/school_links.dart';

const page = LibraryLoanPage(
  items: [LibraryLoan(id: 'fixture', title: '合成书名', dueAt: '2026-11-01')],
  page: 1,
  total: 101,
  hasMore: true,
);
const secondPage = LibraryLoanPage(
  items: [LibraryLoan(id: 'second', title: '第二页合成书')],
  page: 2,
  total: 101,
  hasMore: false,
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

class Portal implements LibraryLoansOfficialGateway {
  Portal({this.unavailable = false});
  final bool unavailable;

  @override
  String libraryLoansPortalUrl() {
    if (unavailable) throw StateError('synthetic unavailable portal');
    return 'https://example.org/library';
  }
}

Widget app(
  LibraryLoansGateway gateway, {
  LibraryLoansOfficialGateway? portal,
  bool enabled = true,
}) => CupertinoApp(
  home: TickerMode(
    enabled: enabled,
    child: LibraryLoansPage(gateway: gateway, officialGateway: portal),
  ),
);

Future<void> tapText(WidgetTester tester, String text) async {
  final target = find.text(text);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> read(WidgetTester tester, {bool refresh = false}) async {
  if (!refresh) {
    await tester.pumpAndSettle();
    return;
  }
  final button = find.byKey(const Key('library-loans-read'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  setUp(SessionMemoryCache.shared.clearAll);

  test('a typed read keeps an empty page and a failure distinct', () {
    // No page at all is a failure, not an empty success.
    expect(
      decodeLibraryLoans(const live.LibraryLoansResponse()).failure,
      FailureCode.changedResponse,
    );
    expect(
      decodeLibraryLoans(
        const live.LibraryLoansResponse(
          data: live.LibraryLoanPageDto(
            items: [],
            page: 1,
            total: 0,
            hasMore: false,
          ),
        ),
      ).data!.items,
      isEmpty,
    );
    expect(
      decodeLibraryLoans(
        const live.LibraryLoansResponse(failure: FailureCode.sessionExpired),
      ).failure,
      FailureCode.sessionExpired,
    );
  });
  testWidgets('auto-reads on open, supports pagination and warm session cache', (
    tester,
  ) async {
    final gateway = Loans();
    await tester.pumpWidget(app(gateway));
    await tester.pumpAndSettle();
    expect(find.text('合成书名'), findsOneWidget);
    expect(gateway.calls, [1]);
    gateway.result = const LibraryLoansRead(data: secondPage);
    await tester.ensureVisible(find.text('下一页'));
    await tester.tap(find.text('下一页'));
    await tester.pumpAndSettle();
    expect(gateway.calls, [1, 2]);
    expect(find.text('第二页合成书'), findsOneWidget);
    expect(find.text('合成书名'), findsNothing);

    // Re-entering renders cached page 1 immediately without cold start.
    await tester.pumpWidget(const CupertinoApp(home: SizedBox()));
    await tester.pumpWidget(app(gateway));
    await tester.pump();
    expect(find.text('合成书名'), findsOneWidget);
    expect(gateway.calls, [1, 2]);
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
      expect(find.text('尚未读取借阅记录'), findsNothing);
      expect(find.textContaining('暂无当前借阅'), findsNothing);
      gateway.result = const LibraryLoansRead(
        failure: FailureCode.sessionExpired,
      );
      await tapText(tester, '重试第 1 页');
      expect(find.text('合成书名'), findsNothing);
      expect(find.textContaining('未能确认图书馆读者身份'), findsOneWidget);
    },
  );
  testWidgets(
    'reader authentication failure does not prescribe repeated app login',
    (tester) async {
      final gateway = Loans()
        ..result = const LibraryLoansRead(failure: FailureCode.sessionExpired);
      await tester.pumpWidget(app(gateway));
      await read(tester);
      expect(find.textContaining('请重新登录'), findsNothing);
      expect(find.textContaining('sessionExpired'), findsOneWidget);
      expect(find.textContaining('未能确认图书馆读者身份'), findsOneWidget);
      expect(find.textContaining('过期'), findsNothing);
      expect(gateway.calls, [1]);
      await tester.pump(const Duration(seconds: 30));
      expect(gateway.calls, [1]);
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

  testWidgets('a failed first read offers an inline retry', (tester) async {
    final gateway = Loans()
      ..result = const LibraryLoansRead(
        failure: FailureCode.serviceUnavailable,
      );
    await tester.pumpWidget(app(gateway));
    await tester.pumpAndSettle();
    expect(find.text('第 1 页借阅读取失败'), findsOneWidget);
    gateway.result = const LibraryLoansRead(data: page);
    await tapText(tester, '重试第 1 页');
    expect(gateway.calls, [1, 1]);
    expect(find.text('合成书名'), findsOneWidget);
  });
  for (final failure in [
    FailureCode.changedResponse,
    FailureCode.redirectLimit,
    FailureCode.moduleAuthRequired,
  ]) {
    testWidgets('retry only the failed second page: ${failure.name}', (
      tester,
    ) async {
      final gateway = Loans();
      await tester.pumpWidget(app(gateway));
      await read(tester);
      gateway.result = LibraryLoansRead(failure: failure);
      await tapText(tester, '下一页');

      expect(find.text('第 2 页借阅读取失败'), findsOneWidget);
      expect(find.textContaining('诊断代码：${failure.name}'), findsOneWidget);
      expect(find.textContaining('本次查询已确认'), findsNothing);
      if (failure == FailureCode.moduleAuthRequired) {
        expect(find.text('合成书名'), findsNothing);
        expect(find.text('学校总数'), findsNothing);
        expect(find.textContaining('过期'), findsNothing);
      } else {
        expect(find.text('合成书名'), findsOneWidget);
        expect(find.textContaining('第 1 页上次读取的结果'), findsOneWidget);
      }
      expect(gateway.calls, [1, 2]);

      gateway.result = const LibraryLoansRead(data: secondPage);
      await tapText(tester, '重试第 2 页');
      expect(gateway.calls, [1, 2, 2]);
      expect(find.text('第二页合成书'), findsOneWidget);
      expect(find.text('合成书名'), findsNothing);
      expect(find.text('重试第 2 页'), findsNothing);
      expect(find.textContaining('上次读取的结果'), findsNothing);
    });
  }

  testWidgets('retained empty page is not a newly confirmed empty read', (
    tester,
  ) async {
    final gateway = Loans()
      ..result = const LibraryLoansRead(
        data: LibraryLoanPage(items: [], page: 1, total: 0, hasMore: false),
      );
    await tester.pumpWidget(app(gateway));
    await read(tester);
    expect(find.textContaining('本次查询已确认'), findsOneWidget);

    final pending = gateway.delayed = Completer<LibraryLoansRead>();
    await tester.tap(find.byKey(const Key('library-loans-read')));
    await tester.pump();
    expect(find.textContaining('本次查询已确认'), findsNothing);
    expect(find.text('上次读取时本页没有借阅记录。'), findsOneWidget);
    pending.complete(
      const LibraryLoansRead(failure: FailureCode.networkUnreachable),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('本次查询已确认'), findsNothing);
    expect(find.text('上次读取时本页没有借阅记录。'), findsOneWidget);
    expect(find.textContaining('诊断代码：networkUnreachable'), findsOneWidget);
    expect(gateway.calls, [1, 1]);
  });

  testWidgets('portal failures do not create or replace a private read failure', (
    tester,
  ) async {
    final gateway = Loans();
    await tester.pumpWidget(app(gateway, portal: Portal(unavailable: true)));
    await tester.pumpAndSettle();
    await tapText(tester, '打开图书馆官网');
    expect(find.text('无法打开官网'), findsOneWidget);
    await tapText(tester, '知道了');
    expect(gateway.calls, [1]);
    expect(find.textContaining('借阅读取失败'), findsNothing);

    // A valid portal address with no launcher returns false instead of throwing.
    await tester.pumpWidget(app(gateway, portal: Portal()));
    await tester.pumpAndSettle();
    gateway.result = const LibraryLoansRead(
      failure: FailureCode.businessRejected,
    );
    await tapText(tester, '下一页');
    await tapText(tester, '打开图书馆官网');
    expect(find.text('无法打开官网'), findsOneWidget);
    await tapText(tester, '知道了');
    expect(find.textContaining('诊断代码：businessRejected'), findsOneWidget);
    expect(find.text('重试第 2 页'), findsOneWidget);
    expect(find.text('合成书名'), findsOneWidget);
    expect(gateway.calls, [1, 2]);
  });

  testWidgets('a late portal failure does not surface on a new account', (
    tester,
  ) async {
    final launch = Completer<bool>();
    final portal = Portal();
    Widget withLauncher(Loans gateway) => ExternalLinkScope(
      launcher: (_) => launch.future,
      child: app(gateway, portal: portal),
    );

    final first = Loans();
    await tester.pumpWidget(withLauncher(first));
    await tester.pumpAndSettle();
    await tapText(tester, '打开图书馆官网');
    final second = Loans()..delayed = Completer<LibraryLoansRead>();
    await tester.pumpWidget(withLauncher(second));
    await tester.pump();
    launch.complete(false);
    await tester.pump();
    expect(find.text('无法打开官网'), findsNothing);
    expect(find.text('合成书名'), findsNothing);
    expect(second.calls, [1]);
  });

  testWidgets('gateway change rejects late account response', (tester) async {
    final first = Loans()..delayed = Completer<LibraryLoansRead>();
    final second = Loans()..delayed = Completer<LibraryLoansRead>();
    await tester.pumpWidget(app(first));
    await tester.pump();
    await tester.pumpWidget(app(second));
    await tester.pump();
    first.delayed!.complete(const LibraryLoansRead(data: page));
    await tester.pump();
    expect(find.text('合成书名'), findsNothing);
  });
}
