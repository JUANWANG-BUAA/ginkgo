import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/checkin_loading.dart';
import 'package:ginkgo_mirror/loading_widgets.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/src/rust/api/live.dart';

class _ProgressService implements CheckInGateway {
  _ProgressService(this.payload);

  final String? payload;
  int reads = 0;

  @override
  bool get isDemo => false;

  @override
  Future<ReadOnlyResponse> checkinProgress() async {
    reads++;
    return ReadOnlyResponse(payload: payload, stale: false);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  testWidgets(
    'iClass progress keeps its label in the compact branded view, not a spinner',
    (tester) async {
      await tester.pumpWidget(
        ginkgoApp(
          home: const CheckInLoading(
            isDemo: true,
            service: DemoMirrorService(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(GinkgoLoadingView), findsOneWidget);
      final loading = tester.widget<GinkgoLoadingView>(
        find.byType(GinkgoLoadingView),
      );
      expect(loading.label, '正在读取 iClass 课程…');
      expect(loading.detail, isNull);
      expect(loading.compact, isTrue);
      expect(find.text('正在读取 iClass 课程…'), findsOneWidget);
      expect(
        tester.widget<GinkgoActivity>(find.byType(GinkgoActivity)).size,
        24,
      );
      expect(find.text('首次连接需要建立学校和 iClass 会话，后续读取会复用有效会话。'), findsOneWidget);
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('local progress polling updates the phase and elapsed seconds', (
    tester,
  ) async {
    final service = _ProgressService(
      jsonEncode({'phase': 'courses', 'elapsedMs': 2600}),
    );
    await tester.pumpWidget(
      ginkgoApp(home: CheckInLoading(isDemo: false, service: service)),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    final loading = tester.widget<GinkgoLoadingView>(
      find.byType(GinkgoLoadingView),
    );
    expect(loading.label, '正在读取当天课程…');
    expect(loading.detail, '已等待 2 秒');
    expect(service.reads, greaterThanOrEqualTo(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('reduced motion leaves the loading leaf static', (tester) async {
    await tester.pumpWidget(
      ginkgoApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const CheckInLoading(
              isDemo: true,
              service: DemoMirrorService(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(find.byType(GinkgoLoadingView), findsOneWidget);
    expect(find.text('正在读取 iClass 课程…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
