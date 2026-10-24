import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/bykc_page.dart';
import 'package:ginkgo_mirror/cgyy_booking_page.dart';
import 'package:ginkgo_mirror/cgyy_page.dart';
import 'package:ginkgo_mirror/cgyy_review_page.dart';
import 'package:ginkgo_mirror/loading_widgets.dart';
import 'package:ginkgo_mirror/main.dart';

ReadOnlyResponse payload(Object value) =>
    ReadOnlyResponse(payload: jsonEncode(value), stale: false);

class PendingBooking implements CgyyBookingGateway {
  final options = Completer<ReadOnlyResponse>();
  @override
  Future<ReadOnlyResponse> executeCgyy(Map<String, Object?> command) {
    if (command['action'] != 'options') {
      throw StateError('The visual test only opens the options read');
    }
    return options.future;
  }
}

class PendingReview implements CgyyBookingGateway {
  final review = Completer<ReadOnlyResponse>();
  @override
  Future<ReadOnlyResponse> executeCgyy(Map<String, Object?> command) {
    if (command['action'] != 'review') {
      throw StateError('The visual test only opens the review read');
    }
    return review.future;
  }
}

class PendingSlots {
  final slots = Completer<ReadOnlyResponse>();
  Future<ReadOnlyResponse> load({
    required String kind,
    required int siteId,
    required String date,
    required bool forceRefresh,
  }) {
    if (kind == 'venues') {
      return Future.value(
        payload([
          {'id': 1, 'name': '合成场馆', 'campus': '合成校区'},
        ]),
      );
    }
    return slots.future;
  }
}

Future<void> desktop(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1000, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void expectIdentity(String section, String subtitle, IconData icon) {
  expect(find.text(section), findsOneWidget);
  expect(find.text(subtitle), findsOneWidget);
  expect(find.byIcon(icon), findsOneWidget);
}

void main() {
  testWidgets(
    '博雅 first load uses the branded loading view and its academic identity',
    (tester) async {
      await desktop(tester);
      final catalog = Completer<ReadOnlyResponse>();
      await tester.pumpWidget(
        ginkgoApp(
          home: BykcPage(
            loader: ({required part, required forceRefresh}) => catalog.future,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(GinkgoLoadingView), findsOneWidget);
      expect(find.text('正在读取博雅课程…'), findsOneWidget);
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
      expectIdentity('学业', '查看活动、课程与个人记录', CupertinoIcons.book_solid);

      final sizes = tester
          .widgetList<GinkgoActivity>(find.byType(GinkgoActivity))
          .map((activity) => activity.size);
      expect(sizes, containsAll(<double>[17, 36]));

      catalog.complete(payload({'courses': [], 'terms': []}));
      await tester.pumpAndSettle();
      expect(find.byType(GinkgoLoadingView), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '研讨室 first load uses the branded loading view and its space identity',
    (tester) async {
      await desktop(tester);
      final venues = Completer<ReadOnlyResponse>();
      await tester.pumpWidget(
        ginkgoApp(
          home: CgyyPage(
            loader: ({
              required kind,
              required siteId,
              required date,
              required forceRefresh,
            }) => venues.future,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(GinkgoLoadingView), findsOneWidget);
      expect(find.text('正在读取研讨室…'), findsOneWidget);
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
      expectIdentity('空间资源', '选择场馆并查看可预约空间', CupertinoIcons.person_3);

      venues.complete(payload(<Object>[]));
      await tester.pumpAndSettle();
      expect(find.byType(GinkgoLoadingView), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('时段查询 shows the branded loading view while the day read runs', (
    tester,
  ) async {
    await desktop(tester);
    final loader = PendingSlots();
    await tester.pumpWidget(ginkgoApp(home: CgyyPage(loader: loader.load)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cgyy-site-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(GinkgoLoadingView), findsOneWidget);
    expect(find.text('正在读取预约信息…'), findsOneWidget);
    expect(find.byType(CupertinoActivityIndicator), findsNothing);

    loader.slots.complete(
      payload({'date': '2026-10-25', 'spaces': <Object>[]}),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GinkgoLoadingView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    '预约研讨室 keeps its title under the space identity while options load',
    (tester) async {
      await desktop(tester);
      final gateway = PendingBooking();
      await tester.pumpWidget(
        ginkgoApp(
          home: CgyyBookingPage(
            gateway: gateway,
            siteId: 1,
            siteName: '合成场馆',
            date: '2026-10-25',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('预约研讨室'), findsOneWidget);
      expectIdentity('空间资源', '选择场馆并查看可预约空间', CupertinoIcons.person_3);
      expect(find.byType(GinkgoLoadingView), findsOneWidget);
      expect(find.text('正在读取预约信息…'), findsOneWidget);
      expect(find.byType(CupertinoActivityIndicator), findsNothing);

      gateway.options.complete(
        payload({
          'state': 'options',
          'options': {'choices': <Object>[], 'purposes': <Object>[]},
        }),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GinkgoLoadingView), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '核对上次操作 keeps its title under the space identity while orders load',
    (tester) async {
      await desktop(tester);
      final gateway = PendingReview();
      await tester.pumpWidget(
        ginkgoApp(home: CgyyReviewPage(gateway: gateway)),
      );
      await tester.pump();

      expect(find.text('核对上次操作'), findsOneWidget);
      expectIdentity('空间资源', '选择场馆并查看可预约空间', CupertinoIcons.person_3);
      expect(find.byType(GinkgoLoadingView), findsOneWidget);
      expect(find.text('正在核对订单…'), findsOneWidget);
      expect(find.byType(CupertinoActivityIndicator), findsNothing);

      gateway.review.complete(
        payload({
          'state': 'reviewRequired',
          'review': {'id': 'synthetic-review', 'orders': <Object>[]},
        }),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GinkgoLoadingView), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
