import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/features/checkin/checkin_page.dart';

class CheckinQrFake extends Fake implements CheckInGateway {
  final readFlags = <bool>[];
  int get reads => readFlags.length;
  bool stale = false;
  bool empty = false;
  bool throwOnRead = false;
  bool demo = false;
  FailureCode? failure;
  final qrRequests = <(String, bool, Completer<CheckInQrResponse>)>[];

  @override
  bool get isDemo => demo;

  @override
  Future<CheckInResponse> checkin({bool forceRefresh = false}) async {
    readFlags.add(forceRefresh);
    if (throwOnRead) throw StateError('synthetic read failure');
    return CheckInResponse(
      date: '2026-11-02',
      courses: empty
          ? const []
          : const [
              CheckInCourse(
                id: 'c1',
                courseName: '合成课程',
                beginsAt: '08:00',
                endsAt: '10:00',
                status: CheckInStatus.notSigned,
                mergedRecordCount: 1,
                conflicting: false,
              ),
            ],
      fromCache: false,
      stale: stale,
      failure: failure,
    );
  }

  @override
  Future<CheckInQrResponse> prepareCheckinQr(
    String courseId, {
    bool revalidateCourse = true,
  }) {
    final completer = Completer<CheckInQrResponse>();
    qrRequests.add((courseId, revalidateCourse, completer));
    return completer.future;
  }
}

CheckInQrResponse qrTicket(String id, {int refreshSeconds = 4}) =>
    CheckInQrResponse(
      courseId: id,
      fetchedAt: '2026-11-02T09:00:00+08:00',
      refreshSeconds: refreshSeconds,
      matrixSize: 21,
      modules: List<bool>.filled(21 * 21, true),
      demo: false,
    );

Widget host(CheckinQrFake service, DateTime Function() clock) =>
    CupertinoApp(home: CheckInPage(service: service, clock: clock));

void tallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  DateTime morning() => DateTime.utc(2026, 11, 2, 1);

  testWidgets('stale checkin snapshot shows a disabled QR action', (
    tester,
  ) async {
    tallViewport(tester);
    final service = CheckinQrFake()..stale = true;
    await tester.pumpWidget(host(service, morning));
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('checkin-submit-c1'));
    expect(tester.widget<CupertinoButton>(button).onPressed, isNull);
    expect(service.qrRequests, isEmpty);
  });

  testWidgets('a thrown refresh revokes even a retained QR callback', (
    tester,
  ) async {
    tallViewport(tester);
    final service = CheckinQrFake();
    await tester.pumpWidget(host(service, morning));
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('checkin-submit-c1'));
    final beforeFailure = tester.widget<CupertinoButton>(button).onPressed!;
    service.throwOnRead = true;
    await tester.tap(find.byIcon(CupertinoIcons.refresh));
    await tester.pumpAndSettle();
    expect(find.text('合成课程'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(tester.widget<CupertinoButton>(button).onPressed, isNull);
    beforeFailure();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('checkin-qr-sheet')), findsNothing);
    expect(service.qrRequests, isEmpty);
  });

  for (final (failure, message) in [
    (FailureCode.networkUnreachable, '无法连接网络'),
    (FailureCode.moduleAuthRequired, 'iClass 认证'),
  ]) {
    testWidgets('first $failure is not a confirmed empty day', (tester) async {
      tallViewport(tester);
      final service = CheckinQrFake()
        ..empty = true
        ..failure = failure;
      await tester.pumpWidget(host(service, morning));
      await tester.pumpAndSettle();
      expect(find.textContaining(message), findsOneWidget);
      expect(find.textContaining('重新登录'), findsNothing);
      expect(find.text('今天没有课程'), findsNothing);
      expect(service.readFlags, [false]);

      service.failure = null;
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(find.text('今天没有课程'), findsOneWidget);
      expect(find.text('重试'), findsNothing);
      expect(service.readFlags, [false, true]);
      expect(service.qrRequests, isEmpty);
    });

    testWidgets('retained rows are read-only after $failure', (tester) async {
      tallViewport(tester);
      final service = CheckinQrFake();
      await tester.pumpWidget(host(service, morning));
      await tester.pumpAndSettle();
      service
        ..failure = failure
        ..empty = true;
      await tester.tap(find.byIcon(CupertinoIcons.refresh));
      await tester.pumpAndSettle();
      expect(find.textContaining(message), findsOneWidget);
      expect(find.textContaining('上次结果'), findsOneWidget);
      expect(find.text('合成课程'), findsOneWidget);
      expect(find.text('今天没有课程'), findsNothing);
      final button = find.byKey(const Key('checkin-submit-c1'));
      expect(tester.widget<CupertinoButton>(button).onPressed, isNull);

      service
        ..failure = null
        ..empty = false;
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(tester.widget<CupertinoButton>(button).onPressed, isNotNull);
      expect(find.text('重试'), findsNothing);
      expect(service.readFlags, [false, true, true]);
      expect(service.qrRequests, isEmpty);
    });
  }

  testWidgets('stale empty is not displayed as confirmed empty', (
    tester,
  ) async {
    tallViewport(tester);
    final service = CheckinQrFake()
      ..stale = true
      ..empty = true;
    await tester.pumpWidget(host(service, morning));
    await tester.pumpAndSettle();
    expect(find.text('今天没有课程'), findsNothing);
    expect(find.text('重试'), findsOneWidget);
    service.stale = false;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('今天没有课程'), findsOneWidget);

    service.throwOnRead = true;
    await tester.tap(find.byIcon(CupertinoIcons.refresh));
    await tester.pumpAndSettle();
    expect(find.text('今天没有课程'), findsNothing);
    expect(find.textContaining('本地服务暂时不可用'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets(
    'QR sheet revalidates on open, ticks without revalidating, and stops when window closes',
    (tester) async {
      tallViewport(tester);
      final service = CheckinQrFake();
      var now = morning();
      await tester.pumpWidget(host(service, () => now));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('checkin-submit-c1')));
      await tester.pump();
      expect(service.qrRequests, hasLength(1));
      expect(service.qrRequests.first.$2, isTrue);

      service.qrRequests.first.$3.complete(qrTicket('c1', refreshSeconds: 4));
      await tester.pump();
      expect(find.byKey(const Key('checkin-qr-canvas')), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      expect(service.qrRequests, hasLength(2));
      expect(service.qrRequests.last.$2, isFalse);
      service.qrRequests.last.$3.complete(qrTicket('c1', refreshSeconds: 4));
      await tester.pump();

      // Advance clock past class end (10:00 Beijing = 02:00 UTC): timer must stop.
      now = DateTime.utc(2026, 11, 2, 3);
      await tester.pump(const Duration(seconds: 4));
      expect(service.qrRequests, hasLength(2));
    },
  );

  testWidgets('service replacement invalidates open QR sheet and late ticket', (
    tester,
  ) async {
    tallViewport(tester);
    final first = CheckinQrFake(), second = CheckinQrFake();
    await tester.pumpWidget(host(first, morning));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('checkin-submit-c1')));
    await tester.pump();
    expect(first.qrRequests, hasLength(1));

    await tester.pumpWidget(host(second, morning));
    await tester.pump();
    first.qrRequests.single.$3.complete(qrTicket('c1', refreshSeconds: 4));
    await tester.pump(const Duration(seconds: 5));
    // Old sheet must not schedule follow-up ticks or touch the replacement service.
    expect(first.qrRequests, hasLength(1));
    expect(second.qrRequests, isEmpty);
  });
}
