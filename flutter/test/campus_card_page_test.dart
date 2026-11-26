import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/application/session_memory_cache.dart';
import 'package:ginkgo_mirror/features/campus_card/campus_card_page.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/shared/app_preferences.dart';

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
  setUp(SessionMemoryCache.shared.clearAll);

  testWidgets(
    'balance auto-reads on entry, reveals by default, remembers hide toggle and has no money actions',
    (tester) async {
      final prefs = AppPreferences();
      addTearDown(prefs.dispose);
      final gateway = _FakeGateway();
      await tester.pumpWidget(
        ginkgoApp(preferences: prefs, home: CampusCardPage(gateway: gateway)),
      );
      await tester.pump();
      expect(gateway.calls, 1);
      gateway.responses.single.complete(success());
      await tester.pumpAndSettle();

      expect(find.text('¥ 123.45'), findsOneWidget);
      expect(find.text('¥ ••••'), findsNothing);
      expect(find.text('充值'), findsNothing);
      expect(find.text('挂失'), findsNothing);
      await tester.tap(find.byKey(const Key('campus-card-toggle')));
      await tester.pump();
      expect(find.text('¥ ••••'), findsOneWidget);
      expect(prefs.revealSensitiveAmounts, isFalse);
      await tester.tap(find.byKey(const Key('campus-card-toggle')));
      await tester.pump();
      expect(find.text('¥ 123.45'), findsOneWidget);
      expect(prefs.revealSensitiveAmounts, isTrue);
    },
  );

  testWidgets(
    'failed refresh preserves the previous value with a stale warning',
    (tester) async {
      final prefs = AppPreferences();
      addTearDown(prefs.dispose);
      final gateway = _FakeGateway();
      await tester.pumpWidget(
        ginkgoApp(preferences: prefs, home: CampusCardPage(gateway: gateway)),
      );
      await tester.pump();
      gateway.responses[0].complete(success());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('campus-card-read')));
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

  testWidgets('warm session memory cache avoids cold start on re-entry and clears on logout', (
    tester,
  ) async {
    final prefs = AppPreferences();
    addTearDown(prefs.dispose);
    final gateway = _FakeGateway();
    await tester.pumpWidget(
      ginkgoApp(preferences: prefs, home: CampusCardPage(gateway: gateway)),
    );
    await tester.pump();
    gateway.responses.single.complete(success());
    await tester.pumpAndSettle();
    expect(find.text('¥ 123.45'), findsOneWidget);

    // Leave page and re-enter with same gateway: renders immediately without new call.
    await tester.pumpWidget(ginkgoApp(preferences: prefs, home: const SizedBox()));
    await tester.pumpWidget(
      ginkgoApp(preferences: prefs, home: CampusCardPage(gateway: gateway)),
    );
    await tester.pump();
    expect(find.text('¥ 123.45'), findsOneWidget);
    expect(gateway.calls, 1);

    // Logout clears session memory cache.
    SessionMemoryCache.shared.clearAll();
    await tester.pumpWidget(ginkgoApp(preferences: prefs, home: const SizedBox()));
    await tester.pumpWidget(
      ginkgoApp(preferences: prefs, home: CampusCardPage(gateway: gateway)),
    );
    await tester.pump();
    expect(gateway.calls, 2);
  });

  testWidgets('late response from a replaced gateway is discarded', (
    tester,
  ) async {
    final prefs = AppPreferences();
    addTearDown(prefs.dispose);
    final first = _FakeGateway();
    final second = _FakeGateway();
    await tester.pumpWidget(
      ginkgoApp(preferences: prefs, home: CampusCardPage(gateway: first)),
    );
    await tester.pump();

    await tester.pumpWidget(
      ginkgoApp(preferences: prefs, home: CampusCardPage(gateway: second)),
    );
    await tester.pump();
    first.responses.single.complete(success());
    await tester.pump();

    expect(find.text('¥ 123.45'), findsNothing);
    expect(find.text('¥ ••••'), findsNothing);
    expect(second.calls, 1);
  });
}
