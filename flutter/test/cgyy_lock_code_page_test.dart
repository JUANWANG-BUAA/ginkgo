import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/features/cgyy/cgyy_lock_code_page.dart';
import 'package:ginkgo_mirror/features/cgyy/cgyy_models.dart';
import 'package:ginkgo_mirror/features/cgyy/cgyy_order_detail_page.dart';
import 'package:ginkgo_mirror/features/cgyy/cgyy_page.dart';
import 'package:ginkgo_mirror/main.dart';

import 'cgyy_management_test.dart';

void main() {
  testWidgets('CGYY home exposes booking, orders and lock code entries', (
    tester,
  ) async {
    final service = ManagementService();
    await tester.pumpWidget(
      ginkgoApp(
        home: CgyyPage(service: service, bookingGateway: service),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('预约研讨室'), findsOneWidget);
    expect(find.text('我的预约记录'), findsOneWidget);
    expect(find.text('门锁密码'), findsOneWidget);
    await tester.tap(find.text('门锁密码'));
    await tester.pumpAndSettle();
    expect(find.byType(CgyyLockCodePage), findsOneWidget);
  });

  testWidgets('CGYY order row opens its own detail', (tester) async {
    await openRecords(tester, ManagementService());
    await tester.tap(find.text('合成楼 · A101'));
    await tester.pumpAndSettle();
    expect(find.byType(CgyyOrderDetailPage), findsOneWidget);
    expect(find.textContaining('订单 42'), findsWidgets);
    expect(find.textContaining('待辅导员审批'), findsWidgets);
  });

  testWidgets('lock code shows password and only refreshes manually', (
    tester,
  ) async {
    final service = ManagementService();
    await tester.pumpWidget(
      ginkgoApp(home: CgyyLockCodePage(service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.text('246810'), findsOneWidget);
    expect(find.textContaining('2026-10-27 10:00:00'), findsOneWidget);
    expect(service.lockReads, 1);
    await tester.pump(const Duration(seconds: 31));
    expect(service.lockReads, 1);
    await tester.tap(find.bySemanticsLabel('刷新门锁密码'));
    await tester.pumpAndSettle();
    expect(service.lockReads, 2);
  });

  testWidgets('lock code distinguishes upcoming, empty and failure', (
    tester,
  ) async {
    final service = ManagementService()
      ..lockCode = const CgyyLockCode(
        qrCode: 'null',
        tradeNo: 'synthetic-upcoming',
      );
    await tester.pumpWidget(
      ginkgoApp(home: CgyyLockCodePage(service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.text('未到开门时段'), findsOneWidget);

    service.lockCode = const CgyyLockCode();
    await tester.tap(find.bySemanticsLabel('刷新门锁密码'));
    await tester.pumpAndSettle();
    expect(find.text('当前无可用预约'), findsOneWidget);

    service.lockFails = true;
    await tester.tap(find.bySemanticsLabel('刷新门锁密码'));
    await tester.pumpAndSettle();
    expect(find.text('门锁密码读取失败'), findsOneWidget);
    expect(find.text('当前无可用预约'), findsNothing);
  });

  testWidgets('lock code remains complete at 320dp and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      ginkgoApp(home: CgyyLockCodePage(service: ManagementService())),
    );
    await tester.pumpAndSettle();
    expect(find.text('246810'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
