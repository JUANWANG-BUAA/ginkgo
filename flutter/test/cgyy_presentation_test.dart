import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/design/academic_widgets.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/features/cgyy/cgyy_gateway.dart';
import 'package:ginkgo_mirror/features/cgyy/cgyy_models.dart';
import 'package:ginkgo_mirror/features/cgyy/cgyy_page.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/features/reservations/reservation_widgets.dart';
import 'package:ginkgo_mirror/src/rust/api/live.dart';
import 'package:ginkgo_mirror/src/rust/api/mirror.dart';

Object fixture(String name) => (jsonDecode(
  File('../fixtures/cgyy/$name-normal-v1.json').readAsStringSync(),
) as Map)['expected'];

void main() {
  test('CGYY order and lock code projections preserve three states', () {
    final order = cgyyOrder(
      jsonEncode({
        'id': 42,
        'place': '合成楼',
        'date': '2026-10-27',
        'time': '08:00–09:00',
        'status': '订单状态 1',
      }),
    );
    expect(order.id, 42);
    final active = cgyyLockCodeData(
      jsonEncode({'qrCode': '246810', 'tradeNo': 'synthetic-trade'}),
    );
    final upcoming = cgyyLockCodeData(
      jsonEncode({'qrCode': 'null', 'reservationDate': '2026-10-28'}),
    );
    final empty = cgyyLockCodeData('{}');
    expect(active.hasPassword, isTrue);
    expect(upcoming.hasPassword, isFalse);
    expect(upcoming.hasUpcomingReservation, isTrue);
    expect(empty.hasUpcomingReservation, isFalse);
  });

  test('CGYY detail helpers use the existing bounded gateway shapes', () async {
    final calls = <String>[];
    Future<ReadOnlyResponse> loader({
      required String kind,
      required int siteId,
      required String date,
      required bool forceRefresh,
    }) async {
      calls.add('$kind/$siteId/$date');
      return const ReadOnlyResponse(payload: '{}', stale: false);
    }

    await cgyyOrderDetail(demo: false, loader: loader, orderId: 42);
    await cgyyLockCode(demo: false, loader: loader);
    expect(calls, ['order/42/', 'lockCode/0/']);
  });

  testWidgets(
    'narrow dark CGYY shows capacity, semantic slots, date action and raw order status',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <String>[];
      await tester.pumpWidget(
        ginkgoApp(
          brightness: Brightness.dark,
          home: CgyyPage(
            demo: true,
            loader:
                ({
                  required kind,
                  required siteId,
                  required date,
                  required forceRefresh,
                }) async {
                  requests.add(kind);
                  final data = fixture(kind);
                  if (kind == 'day') {
                    final day = data as Map;
                    (day['spaces'] as List).first['slots'] = [
                      {'time': '08:00–09:00', 'status': '空闲'},
                      {'time': '09:00–10:00', 'status': '不可预约'},
                      {'time': '10:00–11:00', 'status': '状态待确认'},
                    ];
                  }
                  return ReadOnlyResponse(
                    payload: jsonEncode(data),
                    stale: false,
                  );
                },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('8 座'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.building_2_fill), findsOneWidget);
      expect(find.text('合成场馆 · 合成校区'), findsOneWidget);
      await tester.tap(find.text('合成研讨室'));
      await tester.pumpAndSettle();
      expect(find.byType(ReservationActionButton), findsOneWidget);
      expect(find.text('2026年10月20日 · 周二'), findsOneWidget);
      expect(find.text('空闲'), findsOneWidget);
      expect(find.text('不可预约'), findsOneWidget);
      expect(find.text('状态待确认'), findsOneWidget);
      expect(find.text('立即预约'), findsNothing);
      final statuses = tester
          .widgetList<AcademicBadge>(find.byType(AcademicBadge))
          .toList();
      expect(
        statuses.singleWhere((badge) => badge.label == '空闲').tint,
        AppleDesign.statusSuccess,
      );
      expect(
        statuses.singleWhere((badge) => badge.label == '不可预约').tint,
        AppleDesign.statusInactive,
      );
      expect(
        statuses.singleWhere((badge) => badge.label == '状态待确认').tint,
        AppleDesign.statusUncertain,
      );
      await tester.tap(find.byType(CupertinoNavigationBarBackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('我的预约记录'));
      await tester.pumpAndSettle();
      expect(find.text('合成场馆 · 合成研讨室 · 合成空间'), findsOneWidget);
      expect(find.text('订单状态 1'), findsOneWidget);
      expect(find.text('取消预约'), findsNothing);
      expect(requests, ['venues', 'day', 'orders']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'CGYY large text wraps and keeps prior venue snapshot after refresh failure',
    (tester) async {
      tester.view.physicalSize = const Size(360, 1300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      var venues = 0;
      await tester.pumpWidget(
        ginkgoApp(
          home: CgyyPage(
            demo: true,
            loader:
                ({
                  required kind,
                  required siteId,
                  required date,
                  required forceRefresh,
                }) async {
                  if (kind == 'venues' && venues++ > 0) {
                    return const ReadOnlyResponse(
                      stale: false,
                      failure: FailureCode.serviceUnavailable,
                    );
                  }
                  return ReadOnlyResponse(
                    payload: jsonEncode(fixture(kind)),
                    stale: false,
                  );
                },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('合成研讨室'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('刷新场馆'));
      await tester.pumpAndSettle();
      expect(find.text('正在显示上次场馆。'), findsOneWidget);
      await tester.ensureVisible(find.text('合成研讨室'));
      await tester.tap(find.text('合成研讨室'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('空闲'));
      expect(find.text('08:00–09:00'), findsOneWidget);
      expect(find.text('空闲'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
