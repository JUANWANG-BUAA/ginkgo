import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/features/library/library_seat_page.dart';

import 'library_read_page_generation_test.dart' show LibraryReads, area, slot;

class SeatWrites extends LibraryReads {
  final writes = <Completer<MutationResponse>>[];
  @override
  Future<MutationResponse> reserveLibrarySeat({
    required String areaId,
    required String seatId,
    required LibrarySlot slot,
  }) {
    final write = Completer<MutationResponse>();
    writes.add(write);
    return write.future;
  }
}

const availableSeats = LibrarySeatsResponse(
  seats: [
    LibrarySeat(id: 's1', name: '合成座位', available: true, statusName: '空闲'),
  ],
);
Widget host(
  SeatWrites service,
  Future<void> Function() readback, {
  LibrarySlot selectedSlot = slot,
}) => CupertinoApp(
  home: LibrarySeatPage(
    service: service,
    area: area,
    slot: selectedSlot,
    onReservationChanged: readback,
    onViewReservations: () {},
  ),
);
Future<void> openConfirmation(
  WidgetTester tester,
  SeatWrites service,
  Future<void> Function() readback,
) async {
  tester.view.physicalSize = const Size(430, 1300);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(host(service, readback));
  service.seatReads.single.complete(availableSeats);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('library-reserve-s1')));
  await tester.pumpAndSettle();
}

Future<void> confirm(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(CupertinoAlertDialog),
      matching: find.text('确认预约'),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('seat refresh during confirmation requires a new confirmation', (
    tester,
  ) async {
    final service = SeatWrites();
    await openConfirmation(tester, service, () async {});
    final refresh = tester.widget<CupertinoSliverRefreshControl>(
      find.byType(CupertinoSliverRefreshControl, skipOffstage: false),
    );
    final pending = refresh.onRefresh!();
    service.seatReads.last.complete(availableSeats);
    await pending;
    await tester.pump();
    await confirm(tester);
    expect(service.writes, isEmpty);
    await tester.pumpAndSettle();
  });
  testWidgets('service change revokes seat confirmation', (tester) async {
    final first = SeatWrites(), second = SeatWrites();
    await openConfirmation(tester, first, () async {});
    await tester.pumpWidget(host(second, () async {}));
    second.seatReads.single.complete(availableSeats);
    await tester.pump();
    await confirm(tester);
    expect(first.writes, isEmpty);
    expect(second.writes, isEmpty);
    await tester.pumpAndSettle();
  });
  testWidgets('same slot id with changed date revokes confirmation', (
    tester,
  ) async {
    final service = SeatWrites();
    await openConfirmation(tester, service, () async {});
    await tester.pumpWidget(
      host(
        service,
        () async {},
        selectedSlot: const LibrarySlot(
          id: 'slot',
          day: '2026-10-21',
          start: '08:00',
          end: '10:00',
        ),
      ),
    );
    await confirm(tester);
    expect(service.writes, isEmpty);
    service.seatReads.last.complete(availableSeats);
    await tester.pumpAndSettle();
  });
  testWidgets('late seat write only reads back its original context', (
    tester,
  ) async {
    final first = SeatWrites(), second = SeatWrites();
    var oldReads = 0, newReads = 0;
    await openConfirmation(tester, first, () async {
      oldReads++;
    });
    await confirm(tester);
    expect(first.writes, hasLength(1));
    await tester.pumpWidget(
      host(second, () async {
        newReads++;
      }),
    );
    second.seatReads.single.complete(availableSeats);
    await tester.pump();
    first.writes.single.complete(
      const MutationResponse(state: 'accepted', message: '旧预约已提交'),
    );
    await tester.pumpAndSettle();
    expect(oldReads, 1);
    expect(newReads, 0);
    expect(second.seatReads, hasLength(1));
    expect(find.text('旧预约已提交'), findsNothing);
    expect(
      tester
          .widget<CupertinoButton>(find.byKey(const Key('library-reserve-s1')))
          .onPressed,
      isNotNull,
    );
  });
  testWidgets(
    'readback exception releases busy and retains verification warning',
    (tester) async {
      final service = SeatWrites();
      await openConfirmation(tester, service, () async {
        throw StateError('synthetic');
      });
      await confirm(tester);
      service.writes.single.complete(
        const MutationResponse(state: 'accepted', message: '已提交'),
      );
      await tester.pump();
      service.seatReads.last.complete(availableSeats);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('核实'), findsWidgets);
      expect(
        tester
            .widget<CupertinoButton>(
              find.byKey(const Key('library-reserve-s1')),
            )
            .onPressed,
        isNull,
      );
    },
  );
}
