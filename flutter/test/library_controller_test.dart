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
}
