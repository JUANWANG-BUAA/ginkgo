import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/app/ginkgo_app.dart';
import 'package:ginkgo_mirror/features/cgyy/cgyy_gateway.dart';
import 'package:ginkgo_mirror/features/cgyy/cgyy_models.dart';
import 'package:ginkgo_mirror/features/cgyy/cgyy_order_detail_page.dart';
import 'package:ginkgo_mirror/features/cgyy/cgyy_lock_code_page.dart';

void main() {
  for (final lock in [false, true]) {
    testWidgets(
      '${lock ? 'lock' : 'order'} replaces account and rejects old response',
      (tester) async {
        final old = Completer<CgyyLoadRead>();
        var newReads = 0;
        Future<CgyyLoadRead> oldLoader({
          required String kind,
          required int siteId,
          required String date,
          required bool forceRefresh,
        }) => old.future;
        Future<CgyyLoadRead> newLoader({
          required String kind,
          required int siteId,
          required String date,
          required bool forceRefresh,
        }) async {
          newReads++;
          return const CgyyLoadRead(
            order: CgyyOrder(
              id: 2,
              place: '新账号预约',
              date: '2026-11-05',
              time: '08:00',
              status: '已受理',
            ),
            lockCode: CgyyLockCode(qrCode: '222222'),
          );
        }

        Widget app(CgyyLoader loader) => ginkgoApp(
          home: lock
              ? CgyyLockCodePage(key: const ValueKey('same'), loader: loader)
              : CgyyOrderDetailPage(
                  key: const ValueKey('same'),
                  orderId: 2,
                  loader: loader,
                ),
        );
        await tester.pumpWidget(app(oldLoader));
        await tester.pumpWidget(app(newLoader));
        await tester.pump(const Duration(milliseconds: 100));
        expect(newReads, 1);
        old.complete(
          const CgyyLoadRead(
            order: CgyyOrder(
              id: 1,
              place: '旧账号预约',
              date: '2026-11-04',
              time: '08:00',
              status: '已受理',
            ),
            lockCode: CgyyLockCode(qrCode: '111111'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining(lock ? '111111' : '旧账号预约'), findsNothing);
        expect(find.textContaining(lock ? '222222' : '新账号预约'), findsWidgets);
      },
    );
  }
}
