import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/library_page.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/src/rust/api/mirror.dart';

class ProgressiveLibraryService implements MirrorService {
  final venues = <Completer<LibraryVenuesResponse>>[];
  final bookings = <Completer<LibraryBookingsResponse>>[];
  @override
  bool get isDemo => true;
  @override
  Future<LibraryVenuesResponse> libraryVenues({bool forceRefresh = false}) {
    final request = Completer<LibraryVenuesResponse>();
    venues.add(request);
    return request.future;
  }

  @override
  Future<LibraryBookingsResponse> libraryBookings({bool forceRefresh = false}) {
    final request = Completer<LibraryBookingsResponse>();
    bookings.add(request);
    return request.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const venueSnapshot = LibraryVenuesResponse(
  venues: [LibraryVenue(id: 'v1', name: '测试馆', free: 12, total: 30)],
  fromCache: false,
  stale: false,
);
const emptyBookings = LibraryBookingsResponse(
  bookings: [],
  fromCache: false,
  stale: false,
);

void main() {
  testWidgets(
    'sections render independently, retain empty snapshots and retry only failed requests',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = ProgressiveLibraryService();
      await tester.pumpWidget(ginkgoApp(home: LibraryPage(service: service)));
      await tester.pump();
      expect(service.venues.length, 1);
      expect(service.bookings.length, 1);
      expect(find.text('当前没有进行中的预约'), findsNothing);
      expect(find.text('暂无可用场馆'), findsNothing);
      service.venues.single.complete(venueSnapshot);
      await tester.pump();
      expect(find.text('测试馆'), findsOneWidget);
      expect(find.byKey(const Key('library-bookings-status')), findsOneWidget);
      expect(find.byKey(const Key('library-venues-status')), findsNothing);
      service.bookings.single.complete(emptyBookings);
      await tester.pumpAndSettle();
      expect(find.text('当前没有进行中的预约'), findsOneWidget);

      // A forced refresh is never merged away: while a read is in flight it is
      // remembered and re-runs once that read settles.
      await tester.tap(find.bySemanticsLabel('刷新图书馆').first);
      await tester.pump();
      expect(find.text('测试馆'), findsOneWidget);
      expect(find.text('当前没有进行中的预约'), findsOneWidget);
      final refresh = tester.widget<CupertinoSliverRefreshControl>(
        find.byType(CupertinoSliverRefreshControl, skipOffstage: false),
      );
      final joined = refresh.onRefresh!();
      expect(service.venues.length, 2);
      expect(service.bookings.length, 2);

      // The first pass fails on bookings only: the old row stays and its
      // remembered forced run re-issues that section alone; venues is still
      // in flight, so its own catch-up has not been queued yet.
      service.bookings.last.completeError(
        StateError('synthetic transport error'),
      );
      await tester.pump();
      expect(find.text('当前没有进行中的预约'), findsOneWidget);
      expect(service.bookings.length, 3);
      expect(service.venues.length, 2);

      service.venues.last.complete(venueSnapshot);
      await tester.pump();
      expect(service.venues.length, 3);
      service.venues.last.complete(venueSnapshot);
      service.bookings.last.complete(emptyBookings);
      await tester.pumpAndSettle();
      await joined;
      expect(find.text('测试馆'), findsOneWidget);
      expect(find.text('当前没有进行中的预约'), findsOneWidget);

      // Only the failed section is retried: venues keeps its fresh snapshot.
      await tester.tap(find.bySemanticsLabel('刷新图书馆').first);
      await tester.pump();
      expect(service.venues.length, 4);
      expect(service.bookings.length, 4);
      service.venues.last.complete(venueSnapshot);
      service.bookings.last.completeError(
        StateError('synthetic transport error'),
      );
      await tester.pumpAndSettle();
      expect(find.text('测试馆'), findsOneWidget);
      expect(find.text('当前没有进行中的预约'), findsOneWidget);
      final retry = find.descendant(
        of: find.byKey(const Key('library-bookings-status')),
        matching: find.text('重试'),
      );
      expect(retry, findsOneWidget);
      await tester.tap(retry);
      await tester.pump();
      expect(service.bookings.length, 5);
      expect(service.venues.length, 4);
      service.bookings.last.complete(emptyBookings);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('library-bookings-status')), findsNothing);

      // An authoritative cached empty snapshot replaces an older nonempty one.
      await tester.tap(find.bySemanticsLabel('刷新图书馆').first);
      await tester.pump();
      expect(service.venues.length, 5);
      expect(service.bookings.length, 6);
      service.venues.last.complete(
        const LibraryVenuesResponse(
          venues: [],
          fromCache: true,
          stale: true,
          failure: FailureCode.serviceUnavailable,
        ),
      );
      service.bookings.last.complete(emptyBookings);
      await tester.pumpAndSettle();
      expect(find.text('暂无可用场馆'), findsOneWidget);
      expect(find.text('测试馆'), findsNothing);
      expect(find.text('保留上次结果'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'booking result is visible before venues, and disposal ignores late results',
    (tester) async {
      final service = ProgressiveLibraryService();
      await tester.pumpWidget(ginkgoApp(home: LibraryPage(service: service)));
      service.bookings.single.complete(emptyBookings);
      await tester.pump();
      expect(find.text('当前没有进行中的预约'), findsOneWidget);
      expect(find.text('暂无可用场馆'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      service.venues.single.complete(venueSnapshot);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
