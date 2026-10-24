import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/apple_design.dart';
import 'package:ginkgo_mirror/apple_widgets.dart';
import 'package:ginkgo_mirror/library_area_page.dart';
import 'package:ginkgo_mirror/library_books_page.dart';
import 'package:ginkgo_mirror/library_history_page.dart';
import 'package:ginkgo_mirror/library_page.dart';
import 'package:ginkgo_mirror/library_seat_page.dart';
import 'package:ginkgo_mirror/library_slot_page.dart';
import 'package:ginkgo_mirror/library_stats_page.dart';
import 'package:ginkgo_mirror/loading_widgets.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/src/rust/api/live.dart';
import 'package:ginkgo_mirror/src/rust/api/mirror.dart';

/// Holds every library request until the test releases it, so first-load
/// states can be inspected instead of a resolved snapshot.
class VisualLibrary implements MirrorService {
  VisualLibrary();
  bool holdVenues = false,
      holdBookings = false,
      holdStats = false,
      holdAreas = false,
      holdSlots = false,
      holdSeats = false,
      holdHistory = false,
      holdBooks = false,
      holdHoldings = false;

  final venuesPending = Completer<LibraryVenuesResponse>();
  final bookingsPending = Completer<LibraryBookingsResponse>();
  final statsPending = Completer<ReadOnlyResponse>();
  final areasPending = Completer<LibraryAreasResponse>();
  final slotsPending = Completer<LibrarySlotsResponse>();
  final seatsPending = Completer<LibrarySeatsResponse>();
  final historyPending = Completer<LibraryHistoryResponse>();
  final booksPending = Completer<ReadOnlyResponse>();
  final holdingsPending = Completer<ReadOnlyResponse>();

  LibraryVenuesResponse venuesResult = const LibraryVenuesResponse(
    venues: [LibraryVenue(id: 'v1', name: '合成馆', free: 20, total: 40)],
    fromCache: false,
    stale: false,
  );

  @override
  bool get isDemo => true;

  @override
  Future<LibraryVenuesResponse> libraryVenues({bool forceRefresh = false}) =>
      holdVenues ? venuesPending.future : Future.value(venuesResult);

  @override
  Future<LibraryBookingsResponse> libraryBookings({
    bool forceRefresh = false,
  }) => holdBookings
      ? bookingsPending.future
      : Future.value(
          const LibraryBookingsResponse(
            bookings: [],
            fromCache: false,
            stale: false,
          ),
        );

  @override
  Future<ReadOnlyResponse> libraryStats({bool forceRefresh = false}) =>
      holdStats
      ? statsPending.future
      : Future.value(const ReadOnlyResponse(stale: false));

  @override
  Future<LibraryAreasResponse> libraryAreas(String libraryId) => holdAreas
      ? areasPending.future
      : Future.value(
          const LibraryAreasResponse(
            areas: [LibraryArea(id: 'a1', name: '合成区域', free: 5, total: 10)],
          ),
        );

  @override
  Future<LibrarySlotsResponse> librarySlots(String areaId) => holdSlots
      ? slotsPending.future
      : Future.value(
          const LibrarySlotsResponse(
            slots: [
              LibrarySlot(
                id: '2026-10-20/t1',
                day: '10月20日',
                start: '08:00',
                end: '10:00',
              ),
            ],
          ),
        );

  @override
  Future<LibrarySeatsResponse> librarySeats({
    required String areaId,
    required LibrarySlot slot,
  }) => holdSeats
      ? seatsPending.future
      : Future.value(
          const LibrarySeatsResponse(
            seats: [
              LibrarySeat(
                id: 's1',
                name: '合成座位',
                statusName: '空闲',
                available: true,
              ),
            ],
          ),
        );

  @override
  Future<LibraryHistoryResponse> libraryHistory(
    int page, {
    bool forceRefresh = false,
  }) => holdHistory
      ? historyPending.future
      : Future.value(
          LibraryHistoryResponse(
            bookings: const [],
            page: page,
            pageSize: 20,
            hasNext: false,
            fromCache: false,
            stale: false,
          ),
        );

  @override
  Future<ReadOnlyResponse> libraryBooks({
    required String query,
    required int page,
    String sort = 'relevance',
    bool descending = true,
  }) => holdBooks
      ? booksPending.future
      : Future.value(
          ReadOnlyResponse(
            payload: jsonEncode({
              'actualTotal': 1,
              'hasMore': false,
              'items': [
                {'bibId': 'B1', 'title': '合成书目'},
              ],
            }),
            stale: false,
          ),
        );

  @override
  Future<ReadOnlyResponse> libraryHoldings(String bibId) => holdHoldings
      ? holdingsPending.future
      : Future.value(const ReadOnlyResponse(payload: '[]', stale: false));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const venue = LibraryVenue(id: 'v1', name: '合成馆', free: 20, total: 40);
const area = LibraryArea(id: 'a1', name: '合成区域', free: 5, total: 10);
const slot = LibrarySlot(
  id: '2026-10-20/t1',
  day: '10月20日',
  start: '08:00',
  end: '10:00',
);

Future<void> pump(
  WidgetTester tester,
  Widget page, {
  Size size = const Size(1200, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ginkgoApp(home: page));
  await tester.pump();
}

Finder headerText(String text) => find.descendant(
  of: find.byKey(const Key('desktop-page-heading')),
  matching: find.text(text),
);

Color resolvedColor(WidgetTester tester, Finder finder, Color color) =>
    (color is CupertinoDynamicColor
            ? color.resolveFrom(tester.element(finder))
            : color)
        .withValues(alpha: 1);

void main() {
  testWidgets('library first load uses one branded loading view', (
    tester,
  ) async {
    final service = VisualLibrary()
      ..holdVenues = true
      ..holdBookings = true;
    await pump(tester, LibraryPage(service: service));
    expect(find.text('正在读取图书馆…'), findsOneWidget);
    expect(find.byType(GinkgoLoadingView), findsOneWidget);
    service.venuesPending.complete(service.venuesResult);
    await tester.pump();
    // The remaining section reports inline with a small leaf, not a spinner.
    final activity = find.descendant(
      of: find.byKey(const Key('library-bookings-status')),
      matching: find.byType(GinkgoActivity),
    );
    expect(tester.widget<GinkgoActivity>(activity).size, 17);
    service.bookingsPending.complete(
      const LibraryBookingsResponse(
        bookings: [],
        fromCache: false,
        stale: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('正在读取图书馆…'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('venue rows distinguish ample, tight and unknown capacity', (
    tester,
  ) async {
    final service = VisualLibrary()
      ..venuesResult = const LibraryVenuesResponse(
        venues: [
          LibraryVenue(id: 'ample', name: '充足馆', free: 24, total: 40),
          LibraryVenue(id: 'tight', name: '紧张馆', free: 0, total: 30),
          LibraryVenue(id: 'low', name: '偏低馆', free: 2, total: 40),
          LibraryVenue(id: 'unknown', name: '未知馆', free: 0, total: 0),
        ],
        fromCache: false,
        stale: false,
      );
    await pump(
      tester,
      LibraryPage(service: service),
      size: const Size(430, 1400),
    );
    await tester.pumpAndSettle();

    // Ample: a thin, faint bar in the resource color.
    final ampleBar = find.byKey(const Key('library-venue-bar-ample'));
    expect(tester.getSize(ampleBar).height, 3);
    final ampleFill = tester.widget<ColoredBox>(
      find.byKey(const Key('library-venue-fill-ample')),
    );
    expect(ampleFill.color.a, lessThan(1));
    expect(
      (ampleFill.color.r, ampleFill.color.g, ampleFill.color.b),
      (
        resolvedColor(tester, ampleBar, AppleDesign.resourceTeal).r,
        resolvedColor(tester, ampleBar, AppleDesign.resourceTeal).g,
        resolvedColor(tester, ampleBar, AppleDesign.resourceTeal).b,
      ),
    );

    // Tight: the pending status color, both on the bar and the count.
    final tightFill = tester.widget<ColoredBox>(
      find.byKey(const Key('library-venue-fill-tight')),
    );
    final expectedPending = resolvedColor(
      tester,
      find.byKey(const Key('library-venue-fill-tight')),
      AppleDesign.statusPending,
    );
    expect(
      (tightFill.color.r, tightFill.color.g, tightFill.color.b),
      (expectedPending.r, expectedPending.g, expectedPending.b),
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('library-venue-tight')),
        matching: find.text('0'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('library-venue-bar-low')), findsOneWidget);

    // Unknown capacity: no bar, no fabricated zero, explicit text.
    final unknown = find.byKey(const Key('library-venue-unknown'));
    expect(find.byKey(const Key('library-venue-bar-unknown')), findsNothing);
    expect(
      find.descendant(of: unknown, matching: find.text('0')),
      findsNothing,
    );
    expect(
      find.descendant(of: unknown, matching: find.text('余量待确认')),
      findsOneWidget,
    );
    expect(find.text('余量待确认'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every library page passes its section, subtitle and icon', (
    tester,
  ) async {
    final service = VisualLibrary();
    await pump(tester, LibraryPage(service: service));
    await tester.pumpAndSettle();
    expect(headerText('空间资源'), findsOneWidget);
    expect(headerText('选择场馆、区域与可预约时段'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('desktop-page-heading')),
        matching: find.byIcon(CupertinoIcons.book),
      ),
      findsOneWidget,
    );

    await pump(tester, LibraryStatsPage(service: service));
    expect(headerText('空间资源'), findsOneWidget);
    expect(headerText('学院路 · 沙河在馆人数与空间余量'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('desktop-page-heading')),
        matching: find.byIcon(CupertinoIcons.person_2_fill),
      ),
      findsOneWidget,
    );

    await pump(
      tester,
      LibraryAreaPage(
        service: service,
        venue: venue,
        onReservationChanged: () async {},
        onViewReservations: () {},
      ),
    );
    expect(headerText('空间资源'), findsOneWidget);
    expect(headerText('查看开放区域与座位余量'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('desktop-page-heading')),
        matching: find.byIcon(CupertinoIcons.rectangle_grid_2x2),
      ),
      findsOneWidget,
    );

    await pump(
      tester,
      LibrarySlotPage(
        service: service,
        area: area,
        onReservationChanged: () async {},
        onViewReservations: () {},
      ),
    );
    expect(headerText('空间资源'), findsOneWidget);
    expect(headerText('选择时段后查看空闲座位'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('desktop-page-heading')),
        matching: find.byIcon(CupertinoIcons.clock),
      ),
      findsOneWidget,
    );

    await pump(
      tester,
      LibrarySeatPage(
        service: service,
        area: area,
        slot: slot,
        onReservationChanged: () async {},
        onViewReservations: () {},
      ),
    );
    expect(headerText('空间资源'), findsOneWidget);
    expect(headerText('合成区域 · 选择空闲座位'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('desktop-page-heading')),
        matching: find.byIcon(CupertinoIcons.square_grid_2x2),
      ),
      findsOneWidget,
    );

    await pump(tester, LibraryHistoryPage(service: service));
    expect(headerText('空间资源'), findsOneWidget);
    expect(headerText('进行中及已结束记录 · 只读'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('desktop-page-heading')),
        matching: find.byIcon(CupertinoIcons.clock_fill),
      ),
      findsOneWidget,
    );

    await pump(tester, LibraryBooksPage(service: service));
    expect(headerText('图书与借阅'), findsOneWidget);
    expect(headerText('公开目录检索 · 复本状态'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('desktop-page-heading')),
        matching: find.byIcon(CupertinoIcons.book_solid),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('library pages use branded first-load views and inline leaves', (
    tester,
  ) async {
    final service = VisualLibrary();

    service.holdStats = true;
    await pump(
      tester,
      LibraryStatsPage(service: service),
      size: const Size(430, 932),
    );
    expect(find.text('正在读取在馆数据…'), findsOneWidget);
    expect(find.byType(GinkgoLoadingView), findsOneWidget);
    expect(
      tester
          .widget<GinkgoActivity>(
            find.descendant(
              of: find.byType(AppleGlassButton),
              matching: find.byType(GinkgoActivity),
            ),
          )
          .size,
      17,
    );
    service.statsPending.complete(const ReadOnlyResponse(stale: false));
    await tester.pumpAndSettle();

    service.holdAreas = true;
    await pump(
      tester,
      LibraryAreaPage(
        service: service,
        venue: venue,
        onReservationChanged: () async {},
        onViewReservations: () {},
      ),
      size: const Size(430, 932),
    );
    expect(find.text('正在读取区域…'), findsOneWidget);
    service.areasPending.complete(const LibraryAreasResponse(areas: []));
    await tester.pumpAndSettle();

    service.holdSlots = true;
    await pump(
      tester,
      LibrarySlotPage(
        service: service,
        area: area,
        onReservationChanged: () async {},
        onViewReservations: () {},
      ),
      size: const Size(430, 932),
    );
    expect(find.text('正在读取时段…'), findsOneWidget);
    service.slotsPending.complete(const LibrarySlotsResponse(slots: []));
    await tester.pumpAndSettle();

    service.holdSeats = true;
    await pump(
      tester,
      LibrarySeatPage(
        service: service,
        area: area,
        slot: slot,
        onReservationChanged: () async {},
        onViewReservations: () {},
      ),
      size: const Size(430, 932),
    );
    expect(find.text('正在读取座位…'), findsOneWidget);
    service.seatsPending.complete(const LibrarySeatsResponse(seats: []));
    await tester.pumpAndSettle();

    service.holdHistory = true;
    await pump(
      tester,
      LibraryHistoryPage(service: service),
      size: const Size(430, 932),
    );
    expect(find.text('正在读取预约记录…'), findsOneWidget);
    service.historyPending.complete(
      const LibraryHistoryResponse(
        bookings: [],
        page: 1,
        pageSize: 20,
        hasNext: false,
        fromCache: false,
        stale: false,
      ),
    );
    await tester.pumpAndSettle();

    service.holdBooks = true;
    await pump(
      tester,
      LibraryBooksPage(service: service),
      size: const Size(430, 932),
    );
    await tester.enterText(find.byKey(const Key('library-books-query')), '合成');
    await tester.tap(find.byKey(const Key('library-books-submit')));
    await tester.pump();
    expect(find.text('正在读取书目…'), findsOneWidget);
    expect(
      tester
          .widget<GinkgoActivity>(
            find.descendant(
              of: find.byKey(const Key('library-books-submit')),
              matching: find.byType(GinkgoActivity),
            ),
          )
          .size,
      17,
    );
    service.booksPending.complete(
      ReadOnlyResponse(
        payload: jsonEncode({'items': <Object>[]}),
        stale: false,
      ),
    );
    await tester.pumpAndSettle();

    service.holdHoldings = true;
    await pump(
      tester,
      LibraryHoldingsPage(service: service, bibId: 'B1', title: '合成书目'),
      size: const Size(430, 932),
    );
    expect(find.text('正在读取馆藏…'), findsOneWidget);
    expect(find.byType(GinkgoLoadingView), findsOneWidget);
    service.holdingsPending.complete(
      const ReadOnlyResponse(payload: '[]', stale: false),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
