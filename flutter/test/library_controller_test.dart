import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/features/library/library_controller.dart';
import 'package:ginkgo_mirror/src/rust/api/live.dart';
import 'package:ginkgo_mirror/src/rust/api/mirror.dart';

import 'library_progressive_widget_test.dart';
import 'mirror_widget_test.dart' show libraryBookingsFixture;

class MutationLibraryService extends ProgressiveLibraryService {
  int writes = 0;
  final mutation = Completer<MutationResponse>();
  final forcedReads = <bool>[];

  @override
  Future<LibraryBookingsResponse> libraryBookings({bool forceRefresh = false}) {
    forcedReads.add(forceRefresh);
    return super.libraryBookings(forceRefresh: forceRefresh);
  }

  @override
  Future<MutationResponse> performLibraryAction(
    String bookingId,
    String action,
  ) {
    writes++;
    return mutation.future;
  }
}

/// First read hangs forever; later reads answer immediately.
class HangingBookingsService extends ProgressiveLibraryService {
  int reads = 0;
  final left = <Completer<LibraryBookingsResponse>>[];

  @override
  Future<LibraryBookingsResponse> libraryBookings({bool forceRefresh = false}) {
    reads++;
    if (reads > 1) return Future.value(emptyBookings);
    final pending = Completer<LibraryBookingsResponse>();
    left.add(pending);
    return pending.future;
  }

  void releaseHanging() {
    for (final pending in left) {
      if (!pending.isCompleted) pending.complete(emptyBookings);
    }
  }
}

void main() {
  test(
    'post-write readback waits for older reads and survives page disposal',
    () async {
      final service = MutationLibraryService();
      final controller = LibraryController(service);
      var notifications = 0;
      controller.addListener(() => notifications++);
      final olderRead = controller.loadBookings();
      final write = controller.perform(
        libraryBookingsFixture.bookings.single,
        'cancel',
      );
      await controller.perform(
        libraryBookingsFixture.bookings.single,
        'cancel',
      );
      expect(service.writes, 1);
      service.mutation.complete(
        const MutationResponse(state: 'uncertain', message: '合成待核实'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(service.bookings, hasLength(1));
      controller.dispose();
      final before = notifications;
      service.bookings.first.complete(libraryBookingsFixture);
      await olderRead;
      await Future<void>.delayed(Duration.zero);
      expect(service.forcedReads, [false, true]);
      service.bookings.last.complete(emptyBookings);
      await write;
      expect(controller.bookings!.bookings, isEmpty);
      expect(notifications, before);
      expect(
        controller.uncertainActions,
        contains('${libraryBookingsFixture.bookings.single.id}/cancel'),
      );
      await controller.perform(
        libraryBookingsFixture.bookings.single,
        'cancel',
      );
      expect(service.writes, 1);
    },
  );

  testWidgets('a read that never settles stops the section loading', (
    tester,
  ) async {
    final service = HangingBookingsService();
    final controller = LibraryController(
      service,
      stallDeadline: const Duration(seconds: 30),
    );
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications++);

    unawaited(controller.loadBookings());
    await tester.pump();
    expect(controller.loadingBookings, isTrue);
    expect(controller.busy, isTrue);

    await tester.pump(const Duration(seconds: 29));
    expect(controller.loadingBookings, isTrue);

    await tester.pump(const Duration(seconds: 2));
    expect(
      controller.loadingBookings,
      isFalse,
      reason: 'the stalled read must not keep the section loading',
    );
    expect(controller.bookingError, isNotNull);
    expect(notifications, greaterThan(0));

    // The stalled slot does not absorb the next read.
    await controller.loadBookings(force: true);
    expect(controller.bookingError, isNull);

    // The abandoned read is never awaited: that is the point of the stall.
    service.releaseHanging();
  });

  test('an accepted write releases the action again', () async {
    final service = MutationLibraryService();
    final controller = LibraryController(service);
    addTearDown(controller.dispose);
    final booking = libraryBookingsFixture.bookings.single;
    final key = '${booking.id}/cancel';

    unawaited(controller.perform(booking, 'cancel'));
    await Future<void>.delayed(Duration.zero);
    expect(controller.uncertainActions, contains(key));

    service.mutation.complete(
      const MutationResponse(state: 'accepted', message: '已确认取消'),
    );
    // The readback must finish for `perform` to return.
    await Future<void>.delayed(Duration.zero);
    for (final pending in service.bookings) {
      if (!pending.isCompleted) pending.complete(emptyBookings);
    }
    await Future<void>.delayed(Duration.zero);

    expect(
      controller.uncertainActions,
      isNot(contains(key)),
      reason: 'a confirmed write must not disable the action forever',
    );
  });

  test('an uncertain write keeps the action blocked', () async {
    final service = MutationLibraryService();
    final controller = LibraryController(service);
    addTearDown(controller.dispose);
    final booking = libraryBookingsFixture.bookings.single;
    final key = '${booking.id}/cancel';

    unawaited(controller.perform(booking, 'cancel'));
    await Future<void>.delayed(Duration.zero);
    service.mutation.complete(
      const MutationResponse(state: 'uncertain', message: '结果待核实'),
    );
    await Future<void>.delayed(Duration.zero);
    for (final pending in service.bookings) {
      if (!pending.isCompleted) pending.complete(emptyBookings);
    }
    await Future<void>.delayed(Duration.zero);

    expect(
      controller.uncertainActions,
      contains(key),
      reason: 'an unconfirmed write must stay blocked until it is reconciled',
    );
  });

  testWidgets(
    'a change during a chained readback does not start a second one',
    (tester) async {
      // The booking slot briefly becomes null while a chained forced read
      // installs its replacement. Waiting only on the plain slot would let a
      // selection change start an overlapping second read.
      final service = HangingBookingsService();
      final controller = LibraryController(service);
      addTearDown(controller.dispose);

      // First read owns the slot.
      unawaited(controller.loadBookings());
      await tester.pump();

      // A forced read is chained behind it.
      unawaited(controller.loadBookings(force: true));
      await tester.pump();

      // Let the first read settle; the chained forced read takes over.
      service.releaseHanging();
      await tester.pump();

      // A selection change during the hand-off must not add a third read.
      unawaited(controller.reservationChanged());
      await tester.pump();
      service.releaseHanging();
      await tester.pump();

      expect(
        service.reads,
        lessThanOrEqualTo(3),
        reason: 'the hand-off must not multiply overlapping reads',
      );
    },
  );
}
