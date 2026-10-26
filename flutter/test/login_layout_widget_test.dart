import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart' show SessionResponse;
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/features/auth/login_page.dart';
import 'package:ginkgo_mirror/main.dart';

import 'session_widget_test.dart' show FakeService, signedOut, signedIn;

class PendingLoginService extends FakeService {
  PendingLoginService()
    : super(restoreResponse: signedOut, loginResponse: signedIn);
  final pending = Completer<SessionResponse>();
  @override
  Future<SessionResponse> login({
    required String account,
    required String password,
    String? captcha,
    required bool remember,
  }) => pending.future;
}

void main() {
  testWidgets(
    'login fields and submit align on phone and desktop with accessible text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final width in [390.0, 1200.0]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpWidget(
          ginkgoApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
              child: LoginPage(
                key: ValueKey(width),
                service: FakeService(
                  restoreResponse: signedOut,
                  loginResponse: signedIn,
                ),
                onSignedIn: (_) {},
                onDemo: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final fields = tester.getRect(find.byKey(const Key('login-fields')));
        final submit = tester.getRect(find.byKey(const Key('login-submit')));
        expect(fields.left, submit.left);
        expect(fields.width, submit.width);
        expect(fields.width, lessThanOrEqualTo(420));
        expect(tester.takeException(), isNull);
        final password = find.byKey(const Key('login-password'));
        await tester.ensureVisible(password);
        await tester.enterText(password, 'synthetic-only');
        expect(tester.widget<CupertinoTextField>(password).obscureText, isTrue);
        await tester.tap(find.bySemanticsLabel('显示密码'));
        await tester.pump();
        expect(
          tester.widget<CupertinoTextField>(password).obscureText,
          isFalse,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'busy login shows the brand leaf with contrasting paint, not a spinner',
    (tester) async {
      final service = PendingLoginService();
      await tester.pumpWidget(
        ginkgoApp(
          home: LoginPage(service: service, onSignedIn: (_) {}, onDemo: () {}),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('login-account')),
        'sy2501001',
      );
      await tester.enterText(
        find.byKey(const Key('login-password')),
        'synthetic-only',
      );
      await tester.tap(find.byKey(const Key('login-submit')));
      await tester.pump();
      expect(
        tester.widget<GinkgoActivity>(find.byType(GinkgoActivity)).size,
        17,
      );
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
      expect(
        find.ancestor(
          of: find.byType(GinkgoActivity),
          matching: find.byType(ColorFiltered),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      service.pending.complete(signedIn);
      await tester.pump();
    },
  );
}
