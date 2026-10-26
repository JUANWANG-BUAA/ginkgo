import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/features/cgyy/cgyy_day_page.dart';
import 'package:ginkgo_mirror/features/cgyy/cgyy_models.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/application/contracts.dart' as live;

/// CgyyDayPage renders the queried day slots through an injected loader, so
/// no native binding or school network is involved.
void main() {
  void viewport(Size size, WidgetTester tester) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  final site = CgyySite.fromJson({
    'id': 3,
    'name': '合成研讨室',
    'venue': '合成场馆',
    'campus': '学院路',
  });

  testWidgets('the day view renders every slot status for the site', (
    tester,
  ) async {
    viewport(const Size(430, 900), tester);
    await tester.pumpWidget(
      ginkgoApp(
        home: CgyyDayPage(
          demo: true,
          site: site,
          loader: ({required kind, required siteId, required date, required forceRefresh}) async {
            expect(kind, 'day');
            expect(siteId, 3);
            expect(date, '2026-10-20');
            return live.ReadOnlyResponse(
              payload: jsonEncode({
                'date': '2026-10-20',
                'spaces': [
                  {
                    'name': '合成研讨室',
                    'slots': [
                      {'time': '08:00–09:30', 'status': '空闲'},
                      {'time': '10:00–11:30', 'status': '不可预约'},
                      {'time': '13:00–14:30', 'status': '已满'},
                    ],
                  },
                ],
              }),
              stale: false,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GinkgoLoadingView), findsNothing);
    expect(find.text('空间时段'), findsOneWidget);
    expect(find.text('空闲'), findsOneWidget);
    expect(find.text('不可预约'), findsOneWidget);
    expect(find.text('已满'), findsOneWidget);
    expect(find.textContaining('实际显示'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed day read shows the error state with a retry action', (
    tester,
  ) async {
    viewport(const Size(430, 900), tester);
    await tester.pumpWidget(
      ginkgoApp(
        home: CgyyDayPage(
          demo: true,
          site: site,
          loader: ({required kind, required siteId, required date, required forceRefresh}) async {
            return const live.ReadOnlyResponse(
              stale: false,
              failure: live.FailureCode.serviceUnavailable,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GinkgoLoadingView), findsNothing);
    expect(find.text('重试'), findsOneWidget);
    expect(find.text('空间时段'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
