import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/features/library/library_area_page.dart';
import 'package:ginkgo_mirror/features/library/library_history_page.dart';
import 'package:ginkgo_mirror/features/library/library_holdings_page.dart';
import 'package:ginkgo_mirror/features/library/library_seat_page.dart';
import 'package:ginkgo_mirror/features/library/library_slot_page.dart';

class LibraryReads extends Fake implements LibraryGateway {
  final areaReads = <Completer<LibraryAreasResponse>>[];
  final slotReads = <Completer<LibrarySlotsResponse>>[];
  final seatReads = <Completer<LibrarySeatsResponse>>[];
  final holdingReads = <Completer<ReadOnlyResponse>>[];
  final historyReads = <Completer<LibraryHistoryResponse>>[];

  @override
  bool get isDemo => true;

  @override
  Future<LibraryAreasResponse> libraryAreas(String libraryId) {
    final read = Completer<LibraryAreasResponse>();
    areaReads.add(read);
    return read.future;
  }

  @override
  Future<LibrarySlotsResponse> librarySlots(String areaId) {
    final read = Completer<LibrarySlotsResponse>();
    slotReads.add(read);
    return read.future;
  }

  @override
  Future<LibrarySeatsResponse> librarySeats({
    required String areaId,
    required LibrarySlot slot,
  }) {
    final read = Completer<LibrarySeatsResponse>();
    seatReads.add(read);
    return read.future;
  }

  @override
  Future<ReadOnlyResponse> libraryHoldings(String bibId) {
    final read = Completer<ReadOnlyResponse>();
    holdingReads.add(read);
    return read.future;
  }

  @override
  Future<LibraryHistoryResponse> libraryHistory(
    int page, {
    bool forceRefresh = false,
  }) {
    final read = Completer<LibraryHistoryResponse>();
    historyReads.add(read);
    return read.future;
  }
}

const venue = LibraryVenue(id: 'v', name: '合成馆', free: 1, total: 2);
const area = LibraryArea(id: 'a', name: '合成区域', free: 1, total: 2);
const slot = LibrarySlot(
  id: 'slot',
  day: '2026-10-20',
  start: '08:00',
  end: '10:00',
);

Widget areaPage(LibraryGateway service) => CupertinoApp(
  home: LibraryAreaPage(
    service: service,
    venue: venue,
    onReservationChanged: () async {},
    onViewReservations: () {},
  ),
);

Widget slotPage(LibraryGateway service) => CupertinoApp(
  home: LibrarySlotPage(
    service: service,
    area: area,
    onReservationChanged: () async {},
    onViewReservations: () {},
  ),
);

Widget seatPage(LibraryGateway service) => CupertinoApp(
  home: LibrarySeatPage(
    service: service,
    area: area,
    slot: slot,
    onReservationChanged: () async {},
    onViewReservations: () {},
  ),
);

LibraryHistoryResponse history(String title) => LibraryHistoryResponse(
  bookings: [
    LibraryBooking(
      id: title,
      title: title,
      areaName: '合成区域',
      seatNumber: '1',
      day: '2026-10-20',
      startTime: '08:00',
      endTime: '10:00',
      statusName: '已结束',
    ),
  ],
  page: 1,
  pageSize: 20,
  hasNext: false,
  fromCache: false,
  stale: false,
);

void main() {
  testWidgets('library area replacement discards the old response', (
    tester,
  ) async {
    final first = LibraryReads();
    final second = LibraryReads();
    await tester.pumpWidget(areaPage(first));
    await tester.pumpWidget(areaPage(second));
    expect(second.areaReads, hasLength(1));
    first.areaReads.single.complete(
      const LibraryAreasResponse(
        areas: [LibraryArea(id: 'old', name: '旧服务区域', free: 1, total: 2)],
      ),
    );
    await tester.pump();
    expect(find.text('旧服务区域'), findsNothing);
    second.areaReads.single.complete(
      const LibraryAreasResponse(
        areas: [LibraryArea(id: 'new', name: '新服务区域', free: 1, total: 2)],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('新服务区域'), findsOneWidget);
  });

  testWidgets('library slot replacement discards the old response', (
    tester,
  ) async {
    final first = LibraryReads();
    final second = LibraryReads();
    await tester.pumpWidget(slotPage(first));
    await tester.pumpWidget(slotPage(second));
    expect(second.slotReads, hasLength(1));
    first.slotReads.single.complete(
      const LibrarySlotsResponse(
        slots: [
          LibrarySlot(
            id: 'old',
            day: '2026-10-20',
            start: '06:00',
            end: '07:00',
          ),
        ],
      ),
    );
    await tester.pump();
    expect(find.text('06:00–07:00'), findsNothing);
    second.slotReads.single.complete(
      const LibrarySlotsResponse(
        slots: [
          LibrarySlot(
            id: 'new',
            day: '2026-10-20',
            start: '11:00',
            end: '12:00',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('11:00–12:00'), findsOneWidget);
  });

  testWidgets('library seat replacement discards the old response', (
    tester,
  ) async {
    final first = LibraryReads();
    final second = LibraryReads();
    await tester.pumpWidget(seatPage(first));
    await tester.pumpWidget(seatPage(second));
    expect(second.seatReads, hasLength(1));
    first.seatReads.single.complete(
      const LibrarySeatsResponse(
        seats: [
          LibrarySeat(
            id: 'old',
            name: '旧服务座位',
            statusName: '空闲',
            available: true,
          ),
        ],
      ),
    );
    await tester.pump();
    expect(find.text('旧服务座位'), findsNothing);
    second.seatReads.single.complete(
      const LibrarySeatsResponse(
        seats: [
          LibrarySeat(
            id: 'new',
            name: '新服务座位',
            statusName: '空闲',
            available: true,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('新服务座位'), findsOneWidget);
  });

  testWidgets('library holdings replacement discards the old response', (
    tester,
  ) async {
    final first = LibraryReads();
    final second = LibraryReads();
    Widget page(LibraryGateway service) => CupertinoApp(
      home: LibraryHoldingsPage(service: service, bibId: 'b', title: '合成书目'),
    );
    await tester.pumpWidget(page(first));
    await tester.pumpWidget(page(second));
    expect(second.holdingReads, hasLength(1));
    first.holdingReads.single.complete(
      ReadOnlyResponse(
        payload: jsonEncode([
          {'callNo': '旧服务索书号', 'location': '旧馆藏地'},
        ]),
        stale: false,
      ),
    );
    await tester.pump();
    expect(find.textContaining('旧服务索书号'), findsNothing);
    second.holdingReads.single.complete(
      ReadOnlyResponse(
        payload: jsonEncode([
          {'callNo': '新服务索书号', 'location': '新馆藏地'},
        ]),
        stale: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('新服务索书号'), findsOneWidget);
  });

  testWidgets('library history replacement discards the old response', (
    tester,
  ) async {
    final first = LibraryReads();
    final second = LibraryReads();
    await tester.pumpWidget(
      CupertinoApp(home: LibraryHistoryPage(service: first)),
    );
    await tester.pumpWidget(
      CupertinoApp(home: LibraryHistoryPage(service: second)),
    );
    expect(second.historyReads, hasLength(1));
    first.historyReads.single.complete(history('旧服务预约'));
    await tester.pump();
    expect(find.text('旧服务预约'), findsNothing);
    second.historyReads.single.complete(history('新服务预约'));
    await tester.pumpAndSettle();
    expect(find.text('新服务预约'), findsOneWidget);
  });
}
