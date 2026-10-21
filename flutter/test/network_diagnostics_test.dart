import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/network_diagnostics_page.dart';
import 'package:ginkgo_mirror/src/rust/api/mirror.dart';
import 'package:ginkgo_mirror/src/rust/api/live.dart' show ReadOnlyResponse;

import 'mirror_widget_test.dart' show ControlledService;

void main() {
  test(
    'academic probe projects counts and failure without retaining raw rows',
    () async {
      final forces = <bool>[];
      final probes = schoolNetworkProbes(
        ControlledService(),
        academic: ({required report, required forceRefresh}) async {
          forces.add(forceRefresh);
          return const ReadOnlyResponse(
            stale: true,
            failure: FailureCode.serviceUnavailable,
            payload: '{"sections":[{"rows":[{"detail":"synthetic-private-value"},{"detail":"other"}]}]}',
          );
        },
      );
      final result = await probes[3].read(true);
      expect(result.count, 2);
      expect(result.stale, isTrue);
      expect(result.fromCache, isNull);
      expect(result.failure, FailureCode.serviceUnavailable);
      expect(forces, [true]);
    },
  );

  testWidgets(
    'publishes each result, prevents duplicate runs and distinguishes stale failure',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <Completer<NetworkProbeResult>>[];
      final forced = <bool>[];
      Future<NetworkProbeResult> read(bool force) {
        forced.add(force);
        final request = Completer<NetworkProbeResult>();
        requests.add(request);
        return request.future;
      }

      await tester.pumpWidget(
        ginkgoApp(
          home: SchoolNetworkChecks(
            probes: [NetworkProbe('图书馆', read), NetworkProbe('iclass', read)],
          ),
        ),
      );
      await tester.tap(find.text('开始读取'));
      await tester.pump();
      expect(requests, hasLength(1));
      await tester.tap(find.text('强制刷新并测量'));
      expect(requests, hasLength(1));
      requests.first.complete(
        const NetworkProbeResult(count: 3, fromCache: true),
      );
      await tester.pump();
      expect(requests, hasLength(2));
      expect(find.textContaining('3 条 · 命中缓存'), findsOneWidget);
      expect(find.text('正在读取…'), findsOneWidget);
      requests.last.complete(
        const NetworkProbeResult(
          count: 2,
          stale: true,
          failure: FailureCode.serviceUnavailable,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('错误码 serviceUnavailable · 保留旧结果 · 2 条'),
        findsOneWidget,
      );
      expect(find.textContaining('完成于'), findsOneWidget);
      await tester.tap(find.text('强制刷新并测量'));
      await tester.pump();
      expect(forced, [false, false, true]);
      requests.last.completeError(
        StateError('sensitive-response-must-not-appear'),
      );
      await tester.pump();
      expect(find.textContaining('读取失败'), findsOneWidget);
      expect(find.textContaining('sensitive-response'), findsNothing);
      expect(forced, [false, false, true, true]);
      await tester.pumpWidget(const SizedBox());
      requests.last.complete(const NetworkProbeResult(count: 0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('demo cannot start account network probes', (tester) async {
    await tester.pumpWidget(
      ginkgoApp(
        home: const NetworkDiagnosticsPage(service: DemoMirrorService()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('请先登录学校账号'), findsOneWidget);
    expect(find.text('开始读取'), findsNothing);
  });
}
