import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/cgyy_commands.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/application/platform_actions.dart';
import 'package:ginkgo_mirror/features/cgyy/cgyy_page.dart';
import 'package:ginkgo_mirror/features/cgyy/cgyy_review_page.dart';
import 'package:ginkgo_mirror/features/cgyy/cgyy_models.dart';
import 'package:ginkgo_mirror/features/reservations/reservations_page.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/workspace/workspace_catalog.dart';

import 'cgyy_fixture.dart';
import 'mirror_widget_test.dart' show ControlledService;

CgyyOrder get currentOrder => cgyyOrderFrom(const <String, dynamic>{
  'id': 42,
  'place': '合成楼 · A101',
  'date': '2030-12-31',
  'time': '2030-12-31 14:00:00–2030-12-31 15:00:00',
  'status': '订单状态 1',
  'order_status': 1,
  'check_status': 2,
  'can_cancel': true,
});

class ManagementService extends ControlledService
    implements CgyyBookingGateway {
  final commands = <Map<String, Object?>>[];
  bool pending = false;
  bool reviewFails = false;
  bool statusFails = false;
  bool emptyReview = false;
  bool ackFails = false;
  bool lockFails = false;
  int lockReads = 0;
  CgyyLockCode lockCode = const CgyyLockCode(
    qrCode: '246810',
    dueDate: '2026-10-27 10:00:00',
    tradeNo: 'synthetic-trade',
    venueName: '合成楼',
    spaceName: 'A101',
    reservationDate: '2026-10-27',
  );
  Completer<void>? cancelWait;
  Completer<void>? reviewWait;
  final reads = <bool>[];
  @override
  bool get isDemo => false;
  @override
  Future<CgyyLoadRead> cgyy({
    required String kind,
    required int siteId,
    required String date,
    required bool forceRefresh,
  }) async {
    reads.add(forceRefresh);
    if (kind == 'lockCode') {
      lockReads++;
      if (lockFails) throw StateError('synthetic lock read failure');
    }
    return switch (kind) {
      'venues' => CgyyLoadRead(
        sites: [
          CgyySite(id: 1, name: '合成研讨室', venue: '合成楼', campus: '沙河', seats: 8),
        ],
      ),
      'day' => CgyyLoadRead(
        day: CgyyDay(date: date, spaces: const []),
      ),
      'order' => CgyyLoadRead(order: currentOrder),
      'lockCode' => CgyyLoadRead(lockCode: lockCode),
      _ => CgyyLoadRead(orders: [currentOrder]),
    };
  }

  @override
  Future<CgyyActionResult> executeCgyy(CgyyCommand command) async {
    commands.add(command.toPayload());
    switch (command.toPayload()['action']) {
      case 'status':
        if (statusFails) throw StateError('synthetic status failure');
        return CgyyActionResult.fromState(
          pending ? 'uncertain' : 'ready',
          '本机写入状态',
        );
      case 'review':
        await reviewWait?.future;
        if (reviewFails) throw StateError('synthetic read failure');
        return CgyyActionResult.of(
          state: 'reviewRequired',
          review: CgyyReviewSnapshot(
            id: 'fresh-review',
            orders: emptyReview ? const [] : [currentOrder],
          ),
        );
      case 'acknowledge':
        if (ackFails) throw StateError('synthetic expired review');
        pending = false;
        return CgyyActionResult.fromState('ready', '已解除保护');
      case 'cancel':
        pending = true;
        await cancelWait?.future;
        return CgyyActionResult.fromState('uncertain', '取消结果待核实，请勿重发');
      default:
        throw StateError('Unexpected action');
    }
  }
}

Future<void> visible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    250,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pumpAndSettle();
}

Future<void> openRecords(WidgetTester tester, ManagementService service) async {
  await tester.pumpWidget(
    ginkgoApp(
      home: CgyyPage(service: service, bookingGateway: service),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('我的预约记录'));
  await tester.pumpAndSettle();
}

void main() {
  test('booking options preserve the fallback source marker', () {
    final fallback = CgyyBookingOptions(
      choices: const [],
      purposes: const [],
      usesFallbackPurposes: true,
    );
    final school = CgyyBookingOptions(
      choices: const [],
      purposes: const [],
      usesFallbackPurposes: false,
    );
    expect(fallback.usesFallbackPurposes, isTrue);
    expect(school.usesFallbackPurposes, isFalse);
  });

  test(
    'approval states distinguish pending, approved, rejected and absent',
    () {
      CgyyOrder withStatus({int? orderStatus, int? checkStatus}) => CgyyOrder(
        id: currentOrder.id,
        place: currentOrder.place,
        date: currentOrder.date,
        time: currentOrder.time,
        status: currentOrder.status,
        orderStatus: orderStatus ?? currentOrder.orderStatus,
        checkStatus: checkStatus,
        canCancel: currentOrder.canCancel,
      );
      expect(currentOrder.statusLabel, '待辅导员审批');
      expect(withStatus(checkStatus: 1).statusLabel, '审批通过');
      expect(withStatus(checkStatus: -2).statusLabel, '辅导员审批驳回');
      expect(withStatus(orderStatus: 2).statusLabel, '已取消');
      expect(withStatus().statusLabel, contains('未提供'));
      expect(withStatus(checkStatus: 123).statusLabel, contains('待确认'));
    },
  );

  testWidgets(
    'shared unknown state disables cancel and requires visible fresh review',
    (tester) async {
      final service = ManagementService()..pending = true;
      await openRecords(tester, service);
      final cancel = find.byKey(const Key('cgyy-cancel-42'));
      await visible(tester, cancel);
      // A disabled row cannot submit even if it is visible.
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(service.commands.where((c) => c['action'] == 'cancel'), isEmpty);
      await visible(tester, find.byKey(const Key('cgyy-open-review')));
      await tester.tap(find.byKey(const Key('cgyy-open-review')));
      await tester.pumpAndSettle();
      expect(find.byType(CgyyReviewPage), findsOneWidget);
      expect(find.textContaining('订单 42'), findsOneWidget);
      expect(find.textContaining('待辅导员审批'), findsOneWidget);
      final ack = find.byKey(const Key('cgyy-review-acknowledge'));
      await visible(tester, ack);
      expect(tester.widget<CupertinoButton>(ack).onPressed, isNull);
      await tester.tap(find.byKey(const Key('cgyy-review-checked')));
      await tester.pumpAndSettle();
      await tester.tap(ack);
      await tester.pumpAndSettle();
      expect(
        service.commands.where((c) => c['action'] == 'acknowledge'),
        isEmpty,
      );
      await tester.tap(find.byKey(const Key('cgyy-review-confirm')));
      await tester.pumpAndSettle();
      final sent = service.commands
          .where((c) => c['action'] == 'acknowledge')
          .single;
      expect(sent['review_id'], 'fresh-review');
      expect(service.pending, false);
      expect(find.byType(CgyyReviewPage), findsNothing);
      expect(
        service.commands.where(
          (c) => ['prepare', 'submit', 'cancel'].contains(c['action']),
        ),
        isEmpty,
      );
    },
  );

  testWidgets(
    'failed fresh review never enables acknowledgement; retry replaces snapshot',
    (tester) async {
      final service = ManagementService()
        ..pending = true
        ..reviewFails = true;
      await tester.pumpWidget(
        ginkgoApp(home: CgyyReviewPage(gateway: service)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('未能取得最新'), findsOneWidget);
      expect(find.byKey(const Key('cgyy-review-checked')), findsNothing);
      expect(
        tester
            .widget<CupertinoButton>(
              find.byKey(const Key('cgyy-review-acknowledge')),
            )
            .onPressed,
        isNull,
      );
      service.reviewFails = false;
      await visible(tester, find.byKey(const Key('cgyy-review-refresh')));
      await tester.tap(find.byKey(const Key('cgyy-review-refresh')));
      await tester.pumpAndSettle();
      expect(find.textContaining('订单 42'), findsOneWidget);
      expect(service.pending, true);
      expect(service.commands.map((c) => c['action']), ['review', 'review']);
    },
  );

  testWidgets(
    'empty latest records are not treated as proof of no submission',
    (tester) async {
      final service = ManagementService()..emptyReview = true;
      await tester.pumpWidget(
        ginkgoApp(home: CgyyReviewPage(gateway: service)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('这不证明上次操作未生效'), findsOneWidget);
      expect(
        tester
            .widget<CupertinoButton>(
              find.byKey(const Key('cgyy-review-acknowledge')),
            )
            .onPressed,
        isNull,
      );
      expect(service.commands.map((c) => c['action']), ['review']);
    },
  );

  testWidgets(
    'cancellation confirms exact order once and blocks back while submitting',
    (tester) async {
      final service = ManagementService()..cancelWait = Completer<void>();
      await openRecords(tester, service);
      final cancel = find.byKey(const Key('cgyy-cancel-42'));
      await visible(tester, cancel);
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(CupertinoAlertDialog),
          matching: find.textContaining('订单 42'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('cgyy-cancel-confirm')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('预约记录'), findsOneWidget);
      expect(service.commands.where((c) => c['action'] == 'cancel').length, 1);
      expect(
        tester
            .widget<CupertinoButton>(find.byKey(const Key('cgyy-records-back')))
            .onPressed,
        isNull,
      );
      service.cancelWait!.complete();
      await tester.pumpAndSettle();
      expect(find.text('取消结果待核实，请勿重发'), findsOneWidget);
      expect(service.reads, contains(true));
      expect(find.byKey(const Key('cgyy-open-review')), findsOneWidget);
      expect(
        service.commands
            .where((c) => c['action'] == 'cancel')
            .single['order_id'],
        42,
      );
    },
  );

  testWidgets('reservation hub preserves the injected booking capability', (
    tester,
  ) async {
    final service = ManagementService();
    await tester.pumpWidget(
      ginkgoApp(
        home: ReservationsPage(service: service, bookingGateway: service),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('研讨室与场馆'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cgyy-site-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cgyy-open-booking')), findsOneWidget);
    expect(service.commands.single['action'], 'status');
    expect(tester.takeException(), isNull);
  });

  test('workspace reservation destination resolves the booking capability', () {
    final service = ManagementService();
    final context = WorkspaceContext(
      service: service,
      platformActions: const PlatformActions(),
      mobile: true,
      openFeature: (_) {},
      openSettings: () {},
    );

    final page = destinationById('reservations')!.build(context);
    expect(page, isA<ReservationsPage>());
    expect((page as ReservationsPage).bookingGateway, same(service));
  });

  for (final brightness in Brightness.values) {
    testWidgets('320dp 2x review reflows in $brightness', (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        ginkgoApp(
          brightness: brightness,
          home: CgyyReviewPage(gateway: ManagementService()),
        ),
      );
      await tester.pumpAndSettle();
      await visible(tester, find.byKey(const Key('cgyy-review-acknowledge')));
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(const Key('cgyy-review-acknowledge'))).height,
        greaterThanOrEqualTo(48),
      );
    });
  }
}
