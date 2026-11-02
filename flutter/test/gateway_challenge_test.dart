import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/auth_challenge.dart';
import 'package:ginkgo_mirror/application/service_capabilities.dart';
import 'package:ginkgo_mirror/features/settings/gateway_challenge_page.dart';
import 'package:ginkgo_mirror/features/settings/settings_page.dart';
import 'package:ginkgo_mirror/main.dart';

import 'session_widget_test.dart' show FakeService, signedOut;

LoginChallenge challenge(String id) => LoginChallenge(
  id: id,
  kind: 'char',
  textSupported: true,
  image: base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j8WQAAAAASUVORK5CYII=',
  ),
);

class GatewayFake extends FakeService implements GatewayVerificationGateway {
  GatewayFake() : super(restoreResponse: signedOut, loginResponse: signedOut);
  LoginChallenge? current;
  final reads = <({String? id, bool refresh})>[];
  final answers = <({String id, String answer})>[];
  bool wrong = false;
  bool failRefresh = false;
  Completer<void>? pending;
  @override
  Future<LoginChallenge?> gatewayChallenge({
    String? expectedId,
    bool refresh = false,
  }) async {
    reads.add((id: expectedId, refresh: refresh));
    if (refresh && failRefresh) throw StateError('synthetic refresh failure');
    if (refresh) current = challenge('cap-2');
    return current;
  }

  @override
  Future<void> answerGatewayChallenge({
    required String expectedId,
    required String answer,
  }) async {
    answers.add((id: expectedId, answer: answer));
    if (pending != null) await pending!.future;
    if (wrong) {
      current = challenge('cap-new');
      throw StateError('验证码不正确');
    }
    current = null;
  }
}

Future<void> tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('failed refresh keeps an explicit GET retry handle', (
    tester,
  ) async {
    final gateway = GatewayFake()
      ..current = challenge('cap-1')
      ..failRefresh = true;
    await tester.pumpWidget(
      ginkgoApp(home: GatewayChallengePage(gateway: gateway)),
    );
    await tester.pumpAndSettle();
    await tap(tester, 'gateway-refresh');
    expect(find.byKey(const Key('gateway-refresh')), findsOneWidget);
    expect(gateway.answers, isEmpty);
    gateway.failRefresh = false;
    await tap(tester, 'gateway-refresh');
    expect(gateway.reads.last, (id: 'cap-1', refresh: true));
    expect(gateway.answers, isEmpty);
  });

  testWidgets('no pending challenge never implies successful authentication', (
    tester,
  ) async {
    final gateway = GatewayFake();
    await tester.pumpWidget(
      ginkgoApp(home: GatewayChallengePage(gateway: gateway)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('这不代表网关会话已经有效'), findsOneWidget);
    expect(find.textContaining('网关验证通过'), findsNothing);
    expect(gateway.answers, isEmpty);
  });

  testWidgets(
    'refresh binds the next answer to the new challenge and failed answers reload',
    (tester) async {
      final gateway = GatewayFake()..current = challenge('cap-1');
      await tester.pumpWidget(
        ginkgoApp(home: GatewayChallengePage(gateway: gateway)),
      );
      await tester.pumpAndSettle();
      await tap(tester, 'gateway-refresh');
      expect(gateway.reads.last, (id: 'cap-1', refresh: true));
      gateway.wrong = true;
      await tester.enterText(find.byKey(const Key('gateway-answer')), 'wrong');
      await tap(tester, 'gateway-submit');
      expect(gateway.answers.single.id, 'cap-2');
      expect(find.text('验证码不正确'), findsOneWidget);
      gateway.wrong = false;
      await tester.enterText(
        find.byKey(const Key('gateway-answer')),
        'correct',
      );
      await tap(tester, 'gateway-submit');
      expect(gateway.answers.last.id, 'cap-new');
      expect(gateway.answers.length, 2);
      expect(find.text('网关验证通过，请返回原页面重新读取。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'busy answer cannot be submitted twice and late completion is safe',
    (tester) async {
      final gateway = GatewayFake()
        ..current = challenge('cap-1')
        ..pending = Completer<void>();
      await tester.pumpWidget(
        ginkgoApp(home: GatewayChallengePage(gateway: gateway)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('gateway-answer')), '1234');
      await tester.ensureVisible(find.byKey(const Key('gateway-submit')));
      await tester.tap(find.byKey(const Key('gateway-submit')));
      await tester.pump();
      expect(find.byKey(const Key('gateway-submit')), findsNothing);
      expect(gateway.answers.length, 1);
      await tester.pumpWidget(const CupertinoApp(home: SizedBox()));
      gateway.pending!.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('settings exposes verification through the capability matrix', (
    tester,
  ) async {
    final gateway = GatewayFake();
    expect(
      ServiceCapabilities.resolve(gateway).gatewayVerification,
      same(gateway),
    );
    await tester.pumpWidget(
      ginkgoApp(
        home: SettingsPage(
          service: gateway,
          maintenance: null,
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final entry = find.text('WebVPN 验证');
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.byType(GatewayChallengePage), findsOneWidget);
    expect(gateway.reads.length, 1);
  });
  testWidgets('320dp dark large text challenge and error remain operable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = GatewayFake()
      ..current = challenge('cap-1')
      ..wrong = true;
    await tester.pumpWidget(
      ginkgoApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 800),
            textScaler: TextScaler.linear(2),
            platformBrightness: Brightness.dark,
          ),
          child: GatewayChallengePage(gateway: gateway),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('gateway-answer')), 'wrong');
    await tap(tester, 'gateway-submit');
    expect(find.text('验证码不正确'), findsOneWidget);
    await tap(tester, 'gateway-refresh');
    expect(gateway.reads.last, (id: 'cap-new', refresh: true));
    expect(tester.takeException(), isNull);
  });
}
