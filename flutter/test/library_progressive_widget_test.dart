import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/features/library/library_page.dart';
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
      // The library root reads personal bookings only; venue availability is
      // loaded lazily after the user chooses the seat-booking task.
      expect(service.venues, isEmpty);
      expect(service.bookings.length, 1);
      expect(find.text('当前没有进行中的预约'), findsNothing);
      expect(find.text('暂无可用场馆'), findsNothing);
      service.bookings.single.complete(emptyBookings);
      await tester.pumpAndSettle();
      expect(find.text('当前没有进行中的预约'), findsOneWidget);
      await tester.tap(find.byKey(const Key('library-find-seats')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(service.venues.length, 1);
      service.venues.single.complete(venueSnapshot);
      await tester.pumpAndSettle();
      expect(find.text('测试馆'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const Key('library-scroll')),
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
      expect(find.text('当前没有进行中的预约'), findsOneWidget);

      // A forced refresh is never merged away: while a read is in flight it is
      // remembered and re-runs once that read settles.
      await tester.tap(find.bySemanticsLabel('刷新预约').first);
      await tester.pump();
      expect(find.text('当前没有进行中的预约'), findsOneWidget);
      final refresh = tester.widget<CupertinoSliverRefreshControl>(
        find.byType(CupertinoSliverRefreshControl, skipOffstage: false),
      );
      final joined = refresh.onRefresh!();
      expect(service.venues.length, 1);
      expect(service.bookings.length, 2);

      // The first pass fails: the old row stays and its remembered forced run
      // re-issues the booking section alone.
      service.bookings.last.completeError(
        StateError('synthetic transport error'),
      );
      await tester.pump();
      expect(find.text('当前没有进行中的预约'), findsOneWidget);
      expect(service.bookings.length, 3);

      service.bookings.last.complete(emptyBookings);
      await tester.pumpAndSettle();
      await joined;
      expect(find.text('当前没有进行中的预约'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('刷新预约').first);
      await tester.pump();
      expect(service.bookings.length, 4);
      service.bookings.last.completeError(
        StateError('synthetic transport error'),
      );
      await tester.pumpAndSettle();
      expect(find.text('当前没有进行中的预约'), findsOneWidget);
      final retry = find.descendant(
        of: find.byKey(const Key('library-bookings-status')),
        matching: find.text('重试'),
      );
      expect(retry, findsOneWidget);
      await tester.tap(retry);
      await tester.pump();
      expect(service.bookings.length, 5);
      service.bookings.last.complete(emptyBookings);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('library-bookings-status')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('disposed venue selection ignores late results', (tester) async {
    final service = ProgressiveLibraryService();
    await tester.pumpWidget(ginkgoApp(home: LibraryPage(service: service)));
    await tester.pumpAndSettle();
    service.bookings.single.complete(emptyBookings);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-find-seats')));
    await tester.pumpAndSettle();
    expect(service.venues, hasLength(1));
    expect(find.text('暂无可用场馆'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    service.venues.single.complete(venueSnapshot);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
