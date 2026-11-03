import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/features/library/library_page.dart';
import 'package:ginkgo_mirror/src/rust/api/live.dart';
import 'package:ginkgo_mirror/src/rust/api/mirror.dart';

import 'library_progressive_widget_test.dart';

class ActionLibraryService extends ProgressiveLibraryService {
  int writes = 0;

  @override
  Future<MutationResponse> performLibraryAction(
    String bookingId,
    String action,
  ) async {
    writes++;
    return const MutationResponse(state: 'notSubmitted', message: '合成未提交');
  }
}

LibraryBookingsResponse bookingSnapshot(
  String title, {
  List<String>? actions,
}) => LibraryBookingsResponse(
  bookings: [
    LibraryBooking(
      id: title,
      title: title,
      areaName: '合成区域',
      seatNumber: '1',
      day: '2026-11-02',
      startTime: '08:00',
      endTime: '10:00',
      statusName: '使用中',
      actions: actions,
    ),
  ],
  fromCache: false,
  stale: false,
);

Widget libraryHost(ProgressiveLibraryService service) =>
    CupertinoApp(home: LibraryPage(service: service));

void main() {
  testWidgets(
    'booking actions disable during refresh and after failed refresh',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = ActionLibraryService();
      final snapshot = bookingSnapshot('待取消预约', actions: const ['cancel']);
      await tester.pumpWidget(libraryHost(service));
      service.bookings.single.complete(snapshot);
      await tester.pumpAndSettle();
      final button = find.byKey(const Key('library-action-待取消预约-cancel'));
      expect(tester.widget<CupertinoButton>(button).onPressed, isNotNull);
      final refresh = tester.widget<CupertinoSliverRefreshControl>(
        find.byType(CupertinoSliverRefreshControl, skipOffstage: false),
      );
      final pending = refresh.onRefresh!();
      await tester.pump();
      expect(tester.widget<CupertinoButton>(button).onPressed, isNull);
      service.bookings.last.complete(
        const LibraryBookingsResponse(
          bookings: [],
          fromCache: false,
          stale: false,
          failure: FailureCode.serviceUnavailable,
        ),
      );
      await pending;
      await tester.pumpAndSettle();
      expect(find.text('待取消预约'), findsOneWidget);
      expect(tester.widget<CupertinoButton>(button).onPressed, isNull);
      final retry = refresh.onRefresh!();
      service.bookings.last.complete(snapshot);
      await retry;
      await tester.pumpAndSettle();
      expect(tester.widget<CupertinoButton>(button).onPressed, isNotNull);
    },
  );
  testWidgets(
    'booking refresh revokes a confirmation even for identical data',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = ActionLibraryService();
      final snapshot = bookingSnapshot('待取消预约', actions: const ['cancel']);
      await tester.pumpWidget(libraryHost(service));
      service.bookings.single.complete(snapshot);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('library-action-待取消预约-cancel')));
      await tester.pumpAndSettle();
      final refresh = tester.widget<CupertinoSliverRefreshControl>(
        find.byType(CupertinoSliverRefreshControl, skipOffstage: false),
      );
      final pending = refresh.onRefresh!();
      service.bookings.last.complete(snapshot);
      await pending;
      await tester.pump();
      await tester.tap(find.widgetWithText(CupertinoDialogAction, '取消预约'));
      await tester.pump();
      expect(service.writes, 0);
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'library replacement clears snapshots and reads the new service',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final first = ProgressiveLibraryService();
      final second = ProgressiveLibraryService();

      await tester.pumpWidget(libraryHost(first));
      first.bookings.single.complete(bookingSnapshot('旧服务已有预约'));
      await tester.pumpAndSettle();
      expect(find.text('旧服务已有预约'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('刷新预约').first);
      await tester.pump();
      expect(first.bookings, hasLength(2));

      await tester.pumpWidget(libraryHost(second));
      await tester.pump();
      expect(second.bookings, hasLength(1));
      expect(find.text('旧服务已有预约'), findsNothing);

      first.bookings.last.complete(bookingSnapshot('旧服务迟到预约'));
      await tester.pump();
      expect(find.text('旧服务迟到预约'), findsNothing);

      second.bookings.single.complete(bookingSnapshot('新服务预约'));
      await tester.pumpAndSettle();
      expect(find.text('新服务预约'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('service replacement revokes a pending action confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final first = ActionLibraryService();
    final second = ActionLibraryService();

    await tester.pumpWidget(libraryHost(first));
    first.bookings.single.complete(
      bookingSnapshot('待取消预约', actions: const ['cancel']),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library-action-待取消预约-cancel')));
    await tester.pumpAndSettle();
    expect(find.text('确认取消预约？'), findsOneWidget);

    await tester.pumpWidget(libraryHost(second));
    await tester.pump();
    expect(find.text('确认取消预约？'), findsOneWidget);

    final dialog = find.byType(CupertinoAlertDialog);
    await tester.tap(find.descendant(of: dialog, matching: find.text('取消预约')));
    await tester.pump();
    expect(first.writes, 0);
    expect(second.writes, 0);

    second.bookings.single.complete(emptyBookings);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
