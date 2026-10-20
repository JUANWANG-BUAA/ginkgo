import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/src/rust/api/live.dart';
import 'package:ginkgo_mirror/startup_page.dart';

import 'support.dart';

class StartupSession implements MirrorService {
  final response = Completer<SessionResponse>();
  @override
  Future<SessionResponse> restoreSession() => response.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'startup presents identity and continues to the normal login form',
    (tester) async {
      final service = StartupSession();
      await tester.pumpWidget(GinkgoRoot(liveService: service));
      await settle(tester, frames: 4);
      expect(find.byType(StartupPage), findsOneWidget);
      expect(find.text('Ginkgo 银杏'), findsOneWidget);
      service.response.complete(
        const SessionResponse(state: SessionState.signedOut, remembered: false),
      );
      await settle(tester, frames: 4);
      expect(find.byKey(const Key('login-account')), findsOneWidget);
      expect(find.byType(StartupPage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
