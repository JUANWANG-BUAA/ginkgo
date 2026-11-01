import 'dart:async';
import 'dart:convert';

import 'package:ginkgo_mirror/application/contracts.dart' show SessionResponse;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/auth_challenge.dart';
import 'package:ginkgo_mirror/features/auth/login_page.dart';
import 'package:ginkgo_mirror/main.dart';

import 'session_widget_test.dart'
    show FakeService, signedIn, signedOut, captcha;

class ChallengeGateway implements AuthChallengeGateway {
  final calls = <({String? id, bool refresh})>[];
  final pending = Completer<LoginChallenge>();
  @override
  Future<LoginChallenge> loginChallenge({
    String? expectedId,
    bool refresh = false,
  }) {
    calls.add((id: expectedId, refresh: refresh));
    if (refresh) return pending.future;
    return Future.value(
      LoginChallenge(
        id: 'cap-1',
        kind: 'slider',
        textSupported: false,
        image: [],
      ),
    );
  }
}

class LocalGateway implements AuthChallengeGateway {
  @override
  Future<LoginChallenge> loginChallenge({
    String? expectedId,
    bool refresh = false,
  }) async => LoginChallenge(
    id: 'cap-1',
    kind: 'local',
    textSupported: true,
    // In-memory renderer fixture, not an upstream JPEG protocol assertion.
    image: base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j8WQAAAAASUVORK5CYII=',
    ),
  );
}

class LocalService extends FakeService {
  LocalService() : super(restoreResponse: signedOut, loginResponse: captcha);
  final answers = <String?>[];
  @override
  Future<SessionResponse> login({
    required String account,
    required String password,
    String? captcha,
    required bool remember,
  }) async {
    answers.add(captcha);
    return answers.length == 1 ? loginResponse : signedIn;
  }
}

void main() {
  testWidgets(
    'local challenge displays bytes, blocks blank input and submits answer once',
    (tester) async {
      final service = LocalService();
      var completed = 0;
      await tester.pumpWidget(
        ginkgoApp(
          home: LoginPage(
            service: service,
            onSignedIn: (_) => completed++,
            onDemo: () {},
            challengeGateway: LocalGateway(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('login-account')),
        'synthetic',
      );
      await tester.enterText(
        find.byKey(const Key('login-password')),
        'synthetic-password',
      );
      await tester.ensureVisible(find.byKey(const Key('login-submit')));
      await tester.tap(find.byKey(const Key('login-submit')));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsWidgets);
      expect(find.byKey(const Key('login-captcha')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('login-submit')));
      await tester.tap(find.byKey(const Key('login-submit')));
      await tester.pumpAndSettle();
      expect(service.answers, [null]);
      await tester.enterText(find.byKey(const Key('login-captcha')), '1234');
      await tester.ensureVisible(find.byKey(const Key('login-submit')));
      await tester.tap(find.byKey(const Key('login-submit')));
      await tester.pump();
      expect(service.answers, [null, '1234']);
      expect(completed, 1);
    },
  );
  testWidgets(
    'unsupported challenge disables submit, refreshes explicitly and drops late response',
    (tester) async {
      final gateway = ChallengeGateway();
      await tester.pumpWidget(
        ginkgoApp(
          home: LoginPage(
            service: FakeService(
              restoreResponse: signedOut,
              loginResponse: signedIn,
            ),
            onSignedIn: (_) => fail('challenge cannot log in'),
            onDemo: () {},
            initialCaptcha: true,
            challengeGateway: gateway,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('验证方式暂不支持'), findsOneWidget);
      expect(find.byKey(const Key('login-captcha')), findsNothing);
      expect(
        tester
            .widget<CupertinoButton>(find.byKey(const Key('login-submit')))
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(
        find.byKey(const Key('login-captcha-refresh')),
      );
      await tester.tap(find.byKey(const Key('login-captcha-refresh')));
      await tester.pump();
      expect(gateway.calls.last, (id: 'cap-1', refresh: true));
      expect(find.text('正在读取验证码…'), findsOneWidget);
      await tester.pumpWidget(const CupertinoApp(home: SizedBox()));
      gateway.pending.complete(
        LoginChallenge(
          id: 'cap-2',
          kind: 'slider',
          textSupported: false,
          image: [],
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'WebVPN storage explanation does not require opting into password save',
    (tester) async {
      await tester.pumpWidget(
        ginkgoApp(
          home: LoginPage(
            service: FakeService(
              restoreResponse: signedOut,
              loginResponse: signedIn,
            ),
            onSignedIn: (_) {},
            onDemo: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('WebVPN 网关可能需要再次认证'), findsOneWidget);
      expect(find.textContaining('不保存也可登录'), findsOneWidget);
    },
  );
}
