import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/library_page.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/src/rust/api/mirror.dart';

import 'mirror_widget_test.dart' show ControlledService;

class HierarchyService extends ControlledService {
  final seatRequests = <Completer<LibrarySeatsResponse>>[];
  @override
  Future<LibrarySeatsResponse> librarySeats({
    required String areaId,
    required LibrarySlot slot,
  }) {
    final request = Completer<LibrarySeatsResponse>();
    seatRequests.add(request);
    return request.future;
  }
}

void main() {
  testWidgets(
    'seat refresh keeps old rows, coalesces requests and disables stale reservation',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = HierarchyService();
      await tester.pumpWidget(ginkgoApp(home: LibraryPage(service: service)));
      await tester.pumpAndSettle();
      for (final key in [
        'library-venue-v1',
        'library-area-a1',
        'library-slot-2026-10-20/t1',
      ]) {
        await tester.tap(find.byKey(Key(key)));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
      }
      const snapshot = LibrarySeatsResponse(
        seats: [
          LibrarySeat(
            id: 's1',
            name: '合成座位',
            available: true,
            statusName: '空闲',
          ),
        ],
      );
      service.seatRequests.single.complete(snapshot);
      await tester.pumpAndSettle();
      final button = find.byKey(const Key('library-reserve-s1'));
      expect(tester.widget<CupertinoButton>(button).onPressed, isNotNull);
      await tester.tap(find.bySemanticsLabel('刷新列表').first);
      await tester.pump();
      final refresh = tester.widget<CupertinoSliverRefreshControl>(
        find.byType(CupertinoSliverRefreshControl, skipOffstage: false).last,
      );
      final joined = refresh.onRefresh!();
      expect(service.seatRequests, hasLength(2));
      expect(find.text('合成座位'), findsOneWidget);
      expect(tester.widget<CupertinoButton>(button).onPressed, isNull);
      service.seatRequests.last.complete(
        const LibrarySeatsResponse(
          seats: [],
          failure: FailureCode.serviceUnavailable,
        ),
      );
      await joined;
      await tester.pumpAndSettle();
      expect(find.text('合成座位'), findsOneWidget);
      expect(find.text('保留上次结果'), findsOneWidget);
      expect(tester.widget<CupertinoButton>(button).onPressed, isNull);
      await tester.tap(find.text('重试'));
      await tester.pump();
      service.seatRequests.last.complete(snapshot);
      await tester.pumpAndSettle();
      expect(tester.widget<CupertinoButton>(button).onPressed, isNotNull);
      expect(find.text('保留上次结果'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
