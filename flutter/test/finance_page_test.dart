import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/finance.dart';
import 'package:ginkgo_mirror/application/session_memory_cache.dart';
import 'package:ginkgo_mirror/features/finance/finance_page.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/shared/app_preferences.dart';

class _FakeFinanceGateway implements FinanceIncomeGateway {
  final responses = <Completer<FinanceIncomeRead>>[];
  int calls = 0;

  @override
  Future<FinanceIncomeRead> loadFinanceIncomes() {
    calls++;
    final completer = Completer<FinanceIncomeRead>();
    responses.add(completer);
    return completer.future;
  }
}

FinanceIncomeRead _sampleRead() => const FinanceIncomeRead(
  data: FinanceIncomeReport(
    entries: [
      FinanceIncomeEntry(
        id: 'LSH-01',
        project: '助研津贴',
        description: '11月助研补助',
        grossMinor: 80050,
        taxMinor: 0,
        netMinor: 80050,
        taxRate: '0%',
        recordedDate: '2026-11-15',
      ),
    ],
    total: 1,
    fetchedAt: '2026-11-23T10:00:00+08:00',
  ),
);

void main() {
  setUp(SessionMemoryCache.shared.clearAll);

  testWidgets(
    'finance incomes auto-load on open, show amounts by default and cache in session memory',
    (tester) async {
      final prefs = AppPreferences();
      addTearDown(prefs.dispose);
      final gateway = _FakeFinanceGateway();
      await tester.pumpWidget(
        ginkgoApp(preferences: prefs, home: FinancePage(gateway: gateway)),
      );
      await tester.pump();
      expect(gateway.calls, 1);

      gateway.responses.single.complete(_sampleRead());
      await tester.pumpAndSettle();

      expect(find.text('助研津贴'), findsOneWidget);
      expect(find.text('¥ 800.50'), findsOneWidget);
      expect(find.text('¥ ••••'), findsNothing);

      await tester.tap(find.byKey(const Key('finance-toggle')));
      await tester.pump();
      expect(find.text('¥ ••••'), findsOneWidget);
      expect(prefs.revealSensitiveAmounts, isFalse);

      // Re-entering uses warm session memory cache without a second fetch.
      await tester.pumpWidget(ginkgoApp(preferences: prefs, home: const SizedBox()));
      await tester.pumpWidget(
        ginkgoApp(preferences: prefs, home: FinancePage(gateway: gateway)),
      );
      await tester.pump();
      expect(find.text('助研津贴'), findsOneWidget);
      expect(gateway.calls, 1);
    },
  );

  testWidgets(
    'distinguishes confirmed empty finance records and discards late responses after gateway swap',
    (tester) async {
      final prefs = AppPreferences();
      addTearDown(prefs.dispose);
      final first = _FakeFinanceGateway();
      final second = _FakeFinanceGateway();
      await tester.pumpWidget(
        ginkgoApp(preferences: prefs, home: FinancePage(gateway: first)),
      );
      await tester.pump();

      await tester.pumpWidget(
        ginkgoApp(preferences: prefs, home: FinancePage(gateway: second)),
      );
      await tester.pump();
      first.responses.single.complete(_sampleRead());
      await tester.pump();
      expect(find.text('助研津贴'), findsNothing);
      expect(second.calls, 1);

      second.responses.single.complete(
        const FinanceIncomeRead(failure: FailureCode.moduleAuthRequired),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('finance-feedback')), findsOneWidget);

      await tester.tap(find.byKey(const Key('finance-read')));
      await tester.pump();
      second.responses.last.complete(
        const FinanceIncomeRead(
          data: FinanceIncomeReport(
            entries: [],
            total: 0,
            fetchedAt: '2026-11-23T10:05:00+08:00',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('暂无财务收入记录'), findsOneWidget);
    },
  );
}
