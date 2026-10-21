import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/network_diagnostics_page.dart';
import 'package:ginkgo_mirror/src/rust/api/mirror.dart';

import 'support.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('synthetic network timing results with large dark text', (
    tester,
  ) async {
    await tester.pumpWidget(
      ginkgoApp(
        brightness: Brightness.dark,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(1.8),
              disableAnimations: true,
            ),
            child: SchoolNetworkChecks(
              probes: [
                NetworkProbe(
                  '合成场馆',
                  (force) async =>
                      const NetworkProbeResult(count: 2, fromCache: true),
                ),
                NetworkProbe(
                  '合成课程',
                  (force) async => const NetworkProbeResult(
                    count: 0,
                    failure: FailureCode.serviceUnavailable,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('开始读取'));
    await settle(tester);
    await show(
      tester,
      find.textContaining('2 条 · 命中缓存'),
      scrollKey: 'maintenance-学校接口耗时',
    );
    expect(find.textContaining('2 条 · 命中缓存'), findsOneWidget);
    await show(
      tester,
      find.textContaining('错误码 serviceUnavailable'),
      scrollKey: 'maintenance-学校接口耗时',
    );
    expect(find.textContaining('错误码 serviceUnavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
