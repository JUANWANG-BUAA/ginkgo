import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/features/library/library_controller.dart';

import 'library_progressive_widget_test.dart'
    show ProgressiveLibraryService, emptyBookings, venueSnapshot;
import 'mirror_widget_test.dart' show libraryBookingsFixture;

class DeadlineLibraryService extends ProgressiveLibraryService {
  int writes = 0;
  final mutation = Completer<MutationResponse>();
  @override
  Future<MutationResponse> performLibraryAction(
    String bookingId,
    String action,
  ) {
    writes++;
    return mutation.future;
  }
}

(DeadlineLibraryService, LibraryController) setup() {
  final service = DeadlineLibraryService();
  final controller = LibraryController(
    service,
    stallDeadline: const Duration(seconds: 3),
  );
  addTearDown(() {
    controller.dispose();
    for (final read in service.bookings) {
      if (!read.isCompleted) read.complete(emptyBookings);
    }
    for (final read in service.venues) {
      if (!read.isCompleted) read.complete(venueSnapshot);
    }
    if (!service.mutation.isCompleted) {
      service.mutation.complete(
        const MutationResponse(state: 'notSubmitted', message: '合成未提交'),
      );
    }
  });
  return (service, controller);
}

void main() {
  testWidgets(
    'disposed ordinary reader releases its caller and starts no more reads',
    (tester) async {
      final service = DeadlineLibraryService();
      final controller = LibraryController(service);
      addTearDown(() {
        for (final read in service.bookings) {
          if (!read.isCompleted) read.complete(emptyBookings);
        }
        for (final read in service.venues) {
          if (!read.isCompleted) read.complete(venueSnapshot);
        }
      });
      var completed = false;
      unawaited(controller.loadBookings().then((_) => completed = true));
      controller.dispose();
      await tester.pump();
      expect(completed, true);
      unawaited(controller.loadVenues());
      await tester.pump();
      expect(service.venues, isEmpty);
      service.bookings.single.complete(emptyBookings);
      await tester.pump();
      expect(controller.bookings, isNull);
    },
  );
  testWidgets(
    'late write failure after invalidation does not publish into the new context',
    (tester) async {
      final (service, controller) = setup();
      var completed = false;
      unawaited(
        controller
            .perform(libraryBookingsFixture.bookings.single, 'cancel')
            .then((_) => completed = true),
      );
      controller.invalidate();
      unawaited(controller.loadBookings());
      service.mutation.completeError(
        StateError('synthetic late write failure'),
      );
      await tester.pump();
      expect(controller.mutationNotice, isNull);
      expect(completed, true);
      expect(service.bookings, hasLength(1));
      service.bookings.single.complete(emptyBookings);
      await tester.pump();
      expect(service.writes, 1);
    },
  );
  for (final bookings in [true, false]) {
    testWidgets(
      'deadline settles the ${bookings ? 'booking' : 'venue'} caller future',
      (tester) async {
        final (_, controller) = setup();
        var completed = false;
        unawaited(
          (bookings ? controller.loadBookings() : controller.loadVenues()).then(
            (_) => completed = true,
          ),
        );
        await tester.pump(const Duration(seconds: 4));
        expect(completed, true);
        expect(controller.busy, false);
      },
    );
  }
  testWidgets(
    'one section timeout does not discard the other section response',
    (tester) async {
      final (service, controller) = setup();
      unawaited(controller.loadBookings());
      await tester.pump(const Duration(seconds: 1));
      unawaited(controller.loadVenues());
      await tester.pump(const Duration(milliseconds: 2100));
      service.venues.single.complete(venueSnapshot);
      await tester.pump();
      expect(controller.venues, venueSnapshot);
      expect(controller.loadingVenues, false);
      expect(controller.bookingError, isNotNull);
    },
  );
  testWidgets('late abandoned response cannot cancel replacement deadline', (
    tester,
  ) async {
    final (service, controller) = setup();
    unawaited(controller.loadBookings());
    await tester.pump(const Duration(seconds: 4));
    var completed = false;
    unawaited(controller.loadBookings().then((_) => completed = true));
    service.bookings.first.complete(libraryBookingsFixture);
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(controller.loadingBookings, false);
    expect(completed, true);
    expect(controller.bookings, isNull);
  });
  testWidgets(
    'explicit queued forced read starts after the old read deadline',
    (tester) async {
      final (service, controller) = setup();
      unawaited(controller.loadBookings());
      unawaited(controller.loadBookings(force: true));
      await tester.pump(const Duration(seconds: 4));
      expect(service.bookings, hasLength(2));
      expect(controller.loadingBookings, true);
      service.bookings.last.complete(emptyBookings);
      await tester.pump();
    },
  );
  testWidgets(
    'write readback deadline releases busy but preserves uncertainty',
    (tester) async {
      final (service, controller) = setup();
      final booking = libraryBookingsFixture.bookings.single;
      var completed = false;
      unawaited(
        controller.perform(booking, 'cancel').then((_) => completed = true),
      );
      service.mutation.complete(
        const MutationResponse(state: 'uncertain', message: '合成待核实'),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      expect(completed, true);
      expect(controller.submitting, false);
      expect(controller.uncertainActions, contains('${booking.id}/cancel'));
      expect(service.writes, 1);
    },
  );
  testWidgets('invalidated queued work cannot clear the new forced-read slot', (
    tester,
  ) async {
    final (service, controller) = setup();
    unawaited(controller.loadBookings());
    unawaited(controller.loadBookings(force: true));
    controller.invalidate();
    unawaited(controller.loadBookings());
    final forced = controller.loadBookings(force: true);
    unawaited(forced);
    expect(service.bookings, hasLength(2));
    service.bookings.first.complete(emptyBookings);
    await tester.pump();
    final joined = controller.loadBookings(force: true);
    unawaited(joined);
    expect(identical(joined, forced), true);
    service.bookings[1].complete(emptyBookings);
    await tester.pump();
    expect(service.bookings, hasLength(3));
    service.bookings.last.complete(emptyBookings);
    await tester.pump();
    await forced;
  });
}
