import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/auth_challenge.dart';
import 'package:ginkgo_mirror/features/settings/gateway_challenge_page.dart';
import 'package:ginkgo_mirror/main.dart';

import 'gateway_challenge_test.dart' show GatewayFake, challenge, tap;

class DelayedChallenge extends GatewayFake {
  final read = Completer<LoginChallenge?>();
  @override
  Future<LoginChallenge?> gatewayChallenge({
    String? expectedId,
    bool refresh = false,
  }) {
    reads.add((id: expectedId, refresh: refresh));
    return read.future;
  }
}

Widget host(GatewayVerificationGateway gateway) =>
    ginkgoApp(home: GatewayChallengePage(gateway: gateway));
Future<void> beginAnswer(WidgetTester tester, GatewayFake gateway) async {
  await tester.pumpWidget(host(gateway));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('gateway-answer')),
    'synthetic-answer',
  );
  await tester.ensureVisible(find.byKey(const Key('gateway-submit')));
  await tester.tap(find.byKey(const Key('gateway-submit')));
  await tester.pump();
}

void main() {
  testWidgets(
    'old read completion cannot clear the replacement read busy state',
    (tester) async {
      final old = DelayedChallenge();
      final next = DelayedChallenge();
      await tester.pumpWidget(host(old));
      await tester.pumpWidget(host(next));
      old.read.complete(challenge('old'));
      await tester.pump();
      expect(find.text('正在处理网关验证'), findsOneWidget);
      expect(find.byKey(const Key('gateway-submit')), findsNothing);
      next.read.complete(challenge('next'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('gateway-answer')),
        'fresh-answer',
      );
      await tap(tester, 'gateway-submit');
      expect(next.answers.single.id, 'next');
    },
  );
  testWidgets(
    'old read failure cannot replace the current challenge with an error',
    (tester) async {
      final old = DelayedChallenge();
      final next = GatewayFake()..current = challenge('next');
      await tester.pumpWidget(host(old));
      await tester.pumpWidget(host(next));
      old.read.completeError(StateError('synthetic old read failure'));
      await tester.pumpAndSettle();
      expect(find.text('synthetic old read failure'), findsNothing);
      expect(find.byKey(const Key('gateway-submit')), findsOneWidget);
      expect(next.reads, hasLength(1));
    },
  );
  testWidgets(
    'gateway replacement reloads and discards an old pending challenge',
    (tester) async {
      final old = DelayedChallenge();
      final next = GatewayFake()..current = challenge('next');
      await tester.pumpWidget(host(old));
      await tester.pumpWidget(host(next));
      await tester.pump();
      expect(next.reads, hasLength(1));
      old.read.complete(challenge('old'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('gateway-answer')),
        'fresh-answer',
      );
      await tap(tester, 'gateway-submit');
      expect(next.answers.single.id, 'next');
      expect(old.answers, isEmpty);
    },
  );
  testWidgets('gateway replacement clears the old answer and challenge', (
    tester,
  ) async {
    final old = GatewayFake()..current = challenge('old');
    final next = GatewayFake()..current = challenge('next');
    await tester.pumpWidget(host(old));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('gateway-answer')),
      'old-answer',
    );
    await tester.pumpWidget(host(next));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CupertinoTextField>(find.byKey(const Key('gateway-answer')))
          .controller!
          .text,
      isEmpty,
    );
    await tap(tester, 'gateway-submit');
    expect(next.answers, isEmpty);
    expect(find.text('请输入验证码'), findsOneWidget);
  });
  for (final rejected in [false, true]) {
    testWidgets(
      'late gateway answer rejected=$rejected cannot affect a replacement',
      (tester) async {
        final old = GatewayFake()
          ..current = challenge('old')
          ..pending = Completer<void>()
          ..wrong = rejected;
        final next = GatewayFake()..current = challenge('next');
        await beginAnswer(tester, old);
        await tester.pumpWidget(host(next));
        await tester.pump();
        old.pending!.complete();
        await tester.pumpAndSettle();
        expect(next.reads, hasLength(1));
        expect(next.answers, isEmpty);
        expect(find.textContaining('网关验证通过'), findsNothing);
        expect(find.text('验证码不正确'), findsNothing);
        expect(find.byKey(const Key('gateway-submit')), findsOneWidget);
        expect(old.answers, hasLength(1));
      },
    );
  }
}
