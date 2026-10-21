import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/login_page.dart';
import 'package:ginkgo_mirror/main.dart';

import 'session_widget_test.dart' show FakeService, signedOut, signedIn;

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
}
