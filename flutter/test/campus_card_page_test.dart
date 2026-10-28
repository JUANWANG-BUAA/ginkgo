import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/features/campus_card/campus_card_page.dart';
import 'package:ginkgo_mirror/main.dart';

class _FakeGateway implements CampusCardGateway {
  final responses = <Completer<CampusCardBalanceResponse>>[];
  int calls = 0;

  @override
  bool get isDemo => false;

  @override
  Future<CampusCardBalanceResponse> campusCardBalance() {
    calls++;
    final completer = Completer<CampusCardBalanceResponse>();
    responses.add(completer);
    return completer.future;
  }
}

CampusCardBalanceResponse success() => const CampusCardBalanceResponse(
  balanceMinor: 12345,
  fetchedAt: '2026-10-20T08:00:00+08:00',
);

void main() {
  testWidgets(
    'balance is read on demand, masked by default and has no money actions',
    (tester) async {
      final gateway = _FakeGateway();
      await tester.pumpWidget(
        ginkgoApp(home: CampusCardPage(gateway: gateway)),
      );
      expect(gateway.calls, 0);

      await tester.tap(find.text('查询余额'));
      await tester.pump();
      expect(gateway.calls, 1);
      gateway.responses.single.complete(success());
      await tester.pumpAndSettle();

      expect(find.text('¥ ••••'), findsOneWidget);
      expect(find.text('¥ 123.45'), findsNothing);
      expect(find.text('充值'), findsNothing);
      expect(find.text('挂失'), findsNothing);
      await tester.tap(find.text('显示'));
      await tester.pump();
      expect(find.text('¥ 123.45'), findsOneWidget);
      await tester.tap(find.text('隐藏'));
      await tester.pump();
      expect(find.text('¥ ••••'), findsOneWidget);
    },
  );

  testWidgets(
    'failed refresh preserves the previous value with a stale warning',
    (tester) async {
      final gateway = _FakeGateway();
      await tester.pumpWidget(
        ginkgoApp(home: CampusCardPage(gateway: gateway)),
      );
      await tester.tap(find.text('查询余额'));
      await tester.pump();
      gateway.responses[0].complete(success());
      await tester.pumpAndSettle();
      await tester.tap(find.text('显示'));
      await tester.pump();

      await tester.tap(find.text('刷新余额'));
      await tester.pump();
      gateway.responses[1].complete(
        const CampusCardBalanceResponse(
          failure: FailureCode.serviceUnavailable,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('¥ 123.45'), findsOneWidget);
      expect(find.textContaining('可能过期'), findsOneWidget);
      expect(gateway.calls, 2);
    },
  );

  testWidgets('background clears private data without an automatic reload', (
    tester,
  ) async {
    final gateway = _FakeGateway();
    await tester.pumpWidget(ginkgoApp(home: CampusCardPage(gateway: gateway)));
    await tester.tap(find.text('查询余额'));
    await tester.pump();
    gateway.responses.single.complete(success());
    await tester.pumpAndSettle();
    await tester.tap(find.text('显示'));
    await tester.pump();
    expect(find.text('¥ 123.45'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(find.text('¥ 123.45'), findsNothing);
    expect(find.text('¥ ••••'), findsNothing);
    expect(find.text('查询余额'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(gateway.calls, 1);
  });

  testWidgets('late response from a replaced gateway is discarded', (
    tester,
  ) async {
    final first = _FakeGateway();
    final second = _FakeGateway();
    await tester.pumpWidget(ginkgoApp(home: CampusCardPage(gateway: first)));
    await tester.tap(find.text('查询余额'));
    await tester.pump();

    await tester.pumpWidget(ginkgoApp(home: CampusCardPage(gateway: second)));
    first.responses.single.complete(success());
    await tester.pumpAndSettle();

    expect(find.text('¥ 123.45'), findsNothing);
    expect(find.text('¥ ••••'), findsNothing);
    expect(second.calls, 0);
  });
}
