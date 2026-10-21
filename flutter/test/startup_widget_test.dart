import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/src/rust/api/live.dart';
import 'package:ginkgo_mirror/startup_page.dart';

class PendingSession implements MirrorService {
  final response = Completer<SessionResponse>();
  @override
  Future<SessionResponse> restoreSession() => response.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('restoration does not wait for the entrance animation', (
    tester,
  ) async {
    final service = PendingSession();
    await tester.pumpWidget(GinkgoRoot(liveService: service));
    expect(find.byKey(const Key('startup-entrance')), findsOneWidget);
    service.response.complete(
      const SessionResponse(state: SessionState.signedOut, remembered: false),
    );
    await tester.pump();
    expect(find.byKey(const Key('login-account')), findsOneWidget);
    expect(find.byType(StartupPage), findsNothing);
  });

  testWidgets('reduced motion uses static status and large text fits', (
    tester,
  ) async {
    await tester.pumpWidget(
      ginkgoApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              textScaler: const TextScaler.linear(1.8),
            ),
            child: const StartupPage(),
          ),
        ),
      ),
    );
    expect(find.text('Ginkgo 银杏'), findsOneWidget);
    expect(find.byKey(const Key('startup-entrance')), findsNothing);
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
