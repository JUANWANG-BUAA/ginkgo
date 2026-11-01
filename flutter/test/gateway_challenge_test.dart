import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/auth_challenge.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/features/settings/gateway_challenge_page.dart';
import 'package:ginkgo_mirror/main.dart';

Uint8List get _jpeg => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j8WQAAAAASUVORK5CYII=',
);

class ChallengeService extends Fake implements MirrorService {
  ChallengeService({this.pending = true});
  bool pending;
  final answers = <String>[];
  @override
  Future<LoginChallenge?> gatewayChallenge() async => pending
      ? LoginChallenge(
          id: 'gw-cap',
          kind: 'char',
          textSupported: true,
          image: _jpeg,
        )
      : null;
  @override
  Future<bool> submitGatewayChallenge(String answer) async {
    answers.add(answer);
    pending = false;
    return true;
  }
}

void main() {
  testWidgets('the gateway captcha is shown once and submitted once', (
    tester,
  ) async {
    final service = ChallengeService();
    await tester.pumpWidget(
      ginkgoApp(home: GatewayChallengePage(service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('gateway-captcha-image')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('gateway-captcha')), '8f2k');
    await tester.tap(find.text('提交验证'));
    await tester.pumpAndSettle();
    expect(service.answers, ['8f2k']);
    expect(find.textContaining('网关验证已通过'), findsOneWidget);
    expect(find.byKey(const Key('gateway-captcha-image')), findsNothing);
  });

  testWidgets('an idle gateway says so instead of showing an image', (
    tester,
  ) async {
    final service = ChallengeService(pending: false);
    await tester.pumpWidget(
      ginkgoApp(home: GatewayChallengePage(service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('gateway-captcha-image')), findsNothing);
    expect(find.textContaining('没有要求验证'), findsOneWidget);
  });

  testWidgets('a blank answer never reaches the school', (tester) async {
    final service = ChallengeService();
    await tester.pumpWidget(
      ginkgoApp(home: GatewayChallengePage(service: service)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('提交验证'));
    await tester.pumpAndSettle();
    expect(service.answers, isEmpty);
    expect(find.text('请输入图片中的验证码'), findsOneWidget);
  });
}
