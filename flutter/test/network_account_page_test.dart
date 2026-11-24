import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/network_account.dart';
import 'package:ginkgo_mirror/features/network_account/network_account_page.dart';
import 'package:ginkgo_mirror/main.dart';

class _FakeNetworkGateway implements NetworkAccountGateway {
  final responses = <Completer<NetworkAccountRead>>[];
  int calls = 0;

  @override
  Future<NetworkAccountRead> loadNetworkAccount() {
    calls++;
    final completer = Completer<NetworkAccountRead>();
    responses.add(completer);
    return completer.future;
  }
}

void main() {
  testWidgets(
    'reads portal metrics and traffic on demand, masks net fee and clears on background',
    (tester) async {
      final gateway = _FakeNetworkGateway();
      await tester.pumpWidget(
        ginkgoApp(home: NetworkAccountPage(gateway: gateway)),
      );

      expect(gateway.calls, 0);
      await tester.tap(find.byKey(const Key('network-account-read')));
      await tester.pump();
      expect(gateway.calls, 1);

      gateway.responses.single.complete(
        const NetworkAccountRead(
          data: NetworkAccountReport(
            netFeeMinor: 4280,
            unreturnedBooks: PortalMetric(value: '2'),
            unreadMail: PortalMetric(value: '5'),
            cloudDriveFree: PortalMetric(value: '88.5', unit: 'G'),
            trafficProducts: [
              NetworkTrafficProduct(
                productName: '学生校园网',
                usedText: '12.5G',
                freeRemainingText: '17.5G',
                paidRemainingText: '0G',
                packageCount: 1,
              ),
            ],
            fetchedAt: '2026-11-23T11:00:00+08:00',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('¥ ••••'), findsOneWidget);
      expect(find.text('¥ 42.80'), findsNothing);
      expect(find.text('学生校园网'), findsOneWidget);
      expect(find.textContaining('含 1 个套餐'), findsOneWidget);
      expect(find.text('88.5 G'), findsOneWidget);
      expect(find.text('充值'), findsNothing);

      await tester.tap(find.byKey(const Key('network-account-toggle')));
      await tester.pump();
      expect(find.text('¥ 42.80'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(find.text('¥ 42.80'), findsNothing);
      expect(find.text('学生校园网'), findsNothing);
    },
  );

  testWidgets(
    'renders partial success when traffic succeeds but portal requires auth',
    (tester) async {
      final gateway = _FakeNetworkGateway();
      await tester.pumpWidget(
        ginkgoApp(home: NetworkAccountPage(gateway: gateway)),
      );

      await tester.tap(find.byKey(const Key('network-account-read')));
      await tester.pump();
      gateway.responses.single.complete(
        const NetworkAccountRead(
          data: NetworkAccountReport(
            portalFailure: FailureCode.moduleAuthRequired,
            netFeeFailure: FailureCode.moduleAuthRequired,
            trafficProducts: [
              NetworkTrafficProduct(
                productName: '学生校园网',
                usedText: '3G',
                freeRemainingText: '27G',
                paidRemainingText: '0G',
                packageCount: 0,
              ),
            ],
            fetchedAt: '2026-11-23T11:05:00+08:00',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('部分可用'), findsOneWidget);
      expect(find.text('学生校园网'), findsOneWidget);
      expect(find.byKey(const Key('network-portal-feedback')), findsOneWidget);
    },
  );
}
