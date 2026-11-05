import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/shared/app_preferences.dart';
import 'package:ginkgo_mirror/application/contracts.dart';

import 'session_widget_test.dart' show FakeService, signedOut;

class RecoveringService extends FakeService {
  RecoveringService({this.throws = false})
    : super(restoreResponse: signedOut, loginResponse: signedOut);

  final bool throws;
  int restores = 0;

  @override
  Future<SessionResponse> restoreSession() async {
    restores++;
    if (restores > 1) return signedOut;
    if (throws) throw StateError('synthetic vault failure');
    return const SessionResponse(
      state: SessionState.signedOut,
      remembered: false,
      failure: FailureCode.credentialStore,
    );
  }
}

class PendingRetryService extends RecoveringService {
  final pending = Completer<SessionResponse>();
  int routes = 0;
  @override
  Future<SessionResponse> setRoute(RouteChoice route) {
    routes++;
    return routes == 1 ? Future.value(signedOut) : pending.future;
  }
}

void main() {
  testWidgets(
    'retry coalesces rapid taps before route initialization completes',
    (tester) async {
      final preferences = AppPreferences();
      addTearDown(preferences.dispose);
      final service = PendingRetryService();
      await tester.pumpWidget(
        GinkgoRoot(liveService: service, preferences: preferences),
      );
      await tester.pumpAndSettle();
      final retry = tester
          .widget<CupertinoButton>(find.widgetWithText(CupertinoButton, '重试恢复'))
          .onPressed!;
      retry();
      retry();
      expect(service.routes, 2);
      expect(service.restores, 1);
      await tester.pump();
      expect(find.text('重试恢复'), findsNothing);
      service.pending.complete(signedOut);
      await tester.pumpAndSettle();
      expect(service.restores, 2);
      expect(service.signOutCalls, 0);
      expect(find.byKey(const Key('login-account')), findsOneWidget);
    },
  );
  for (final throws in [false, true]) {
    testWidgets('restore failure is retryable, not sign-out (throws=$throws)', (
      tester,
    ) async {
      final preferences = AppPreferences();
      addTearDown(preferences.dispose);
      final service = RecoveringService(throws: throws);
      await tester.pumpWidget(
        GinkgoRoot(liveService: service, preferences: preferences),
      );
      await tester.pumpAndSettle();
      expect(find.text('暂未恢复登录状态'), findsOneWidget);
      expect(find.byKey(const Key('login-account')), findsNothing);
      expect(preferences.explicitSignOut, isFalse);
      expect(service.signOutCalls, 0);
      await tester.tap(find.text('重试恢复'));
      await tester.pumpAndSettle();
      expect(service.restores, 2);
      expect(find.byKey(const Key('login-account')), findsOneWidget);
      expect(service.signOutCalls, 0);
    });
  }
}
