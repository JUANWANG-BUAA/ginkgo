// Opt in when the account owner is present to use the normal login form.
// No credentials, screenshots, response bodies or upstream mutations are taken.
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ginkgo_mirror/features/auth/login_page.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/features/settings/network_diagnostics_page.dart';
import 'package:ginkgo_mirror/src/rust/api/live.dart' as live;
import 'package:ginkgo_mirror/src/rust/frb_generated.dart';

const enabled = bool.fromEnvironment('GINKGO_MANUAL_LIVE_NETWORK');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'manual login and real read-only latency checks',
    (tester) async {
      await RustLib.init();
      const service = NativeMirrorService();
      final results = <Map<String, Object?>>[];
      try {
        live.SessionResponse? session;
        await tester.pumpWidget(
          ginkgoApp(
            home: LoginPage(
              service: service,
              onSignedIn: (value) => session = value,
              onDemo: () {},
            ),
          ),
        );
        // The owner types directly on the emulator. Never read controller values.
        final loginWait = Stopwatch()..start();
        while (session == null &&
            loginWait.elapsed < const Duration(minutes: 5)) {
          if (find.text('继续使用').evaluate().isNotEmpty) {
            await tester.tap(find.text('继续使用'));
          }
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(
          session?.state,
          live.SessionState.signedIn,
          reason: 'Account owner must complete the normal login form',
        );
        await tester.pumpWidget(ginkgoApp(home: const SizedBox.shrink()));
        await tester.pump();
        final probes = schoolNetworkProbes(service);
        var round = 0;
        await tester.pumpWidget(
          ginkgoApp(
            home: SchoolNetworkChecks(
              probes: [
                for (var index = 0; index < probes.length; index++)
                  NetworkProbe(probes[index].title, (force) async {
                    final watch = Stopwatch()..start();
                    final result = await probes[index].read(force);
                    final record = <String, Object?>{
                      'round': round,
                      'probe': index,
                      'forced': force,
                      'ms': watch.elapsedMilliseconds,
                      'count': result.count,
                      'fromCache': result.fromCache,
                      'stale': result.stale,
                      'failure': result.failure?.name,
                    };
                    results.add(record);
                    // Aggregate measurements only, never exception or response text.
                    // ignore: avoid_print
                    print('LIVE_NETWORK ${jsonEncode(record)}');
                    return result;
                  }),
              ],
            ),
          ),
        );
        await tester.pump();
        for (round = 0; round < 3; round++) {
          final action = round == 2
              ? '强制刷新并测量'
              : round == 0
              ? '开始读取'
              : '再次读取';
          await tester.tap(find.text(action));
          final waiting = Stopwatch()..start();
          while (results.length < (round + 1) * probes.length &&
              waiting.elapsed < const Duration(minutes: 4)) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(
            results.length,
            (round + 1) * probes.length,
            reason:
                'Results must publish without leaving and reopening the page',
          );
          await tester.pump(const Duration(milliseconds: 200));
          final uiFailed = tester.takeException() != null;
          expect(
            uiFailed,
            isFalse,
            reason: 'UI failed while publishing results',
          );
        }
        expect(
          results.where((r) => r['failure'] != null).length,
          0,
          reason: 'Read failures remain unaccepted; use aggregate measurements',
        );
      } finally {
        await tester.pumpWidget(ginkgoApp(home: const SizedBox.shrink()));
        await tester.pump();
        final signedOut = await tester.runAsync(service.signOut);
        expect(signedOut?.state, live.SessionState.signedOut);
        final restored = await tester.runAsync(service.restoreSession);
        expect(restored?.state, live.SessionState.signedOut);
        expect(restored?.remembered, isFalse);
      }
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 18)),
  );
}
