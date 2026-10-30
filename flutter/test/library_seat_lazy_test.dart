import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/collection_toolbar.dart';
import 'package:ginkgo_mirror/features/library/library_page.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/src/rust/api/live.dart';
import 'package:ginkgo_mirror/src/rust/api/mirror.dart';

import 'mirror_widget_test.dart' show ControlledService;

class ManySeatsService extends ControlledService {
  int writes = 0;
  @override
  Future<LibrarySeatsResponse> librarySeats({
    required String areaId,
    required LibrarySlot slot,
  }) async => LibrarySeatsResponse(
    seats: List.generate(
      600,
      (index) => LibrarySeat(
        id: 'lazy-$index',
        name: 'S-${index.toString().padLeft(3, '0')}',
        statusName: index.isEven ? '空闲' : '已占用',
        available: index.isEven,
      ),
    ),
  );
  @override
  Future<MutationResponse> reserveLibrarySeat({
    required String areaId,
    required String seatId,
    required LibrarySlot slot,
  }) async {
    writes++;
    return const MutationResponse(state: 'notSubmitted', message: '合成测试');
  }
}

void main() {
  testWidgets(
    '600 seat rows build lazily and retain search, filtering and confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = ManySeatsService();
      await tester.pumpWidget(
        ginkgoApp(
          brightness: Brightness.dark,
          home: LibraryPage(service: service),
        ),
      );
      await tester.pumpAndSettle();
      for (final key in [
        'library-venue-v1',
        'library-area-a1',
        'library-slot-2026-10-20/t1',
      ]) {
        await tester.tap(find.byKey(Key(key)));
        await tester.pumpAndSettle();
      }
      final scrollable = find
          .descendant(
            of: find.byKey(const Key('library-seats-scroll')),
            matching: find.byType(Scrollable),
          )
          .first;
      Finder mountedRows() => find.byWidgetPredicate(
        (widget) =>
            widget is AppleListTile &&
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'library-seat-lazy-',
            ),
      );
      expect(mountedRows().evaluate().length, inInclusiveRange(1, 30));
      expect(find.byKey(const Key('library-seat-lazy-599')), findsNothing);
      final first = tester.widget<ClipRRect>(
        find.byKey(const Key('library-seat-group-lazy-0')),
      );
      expect(
        first.borderRadius,
        const BorderRadius.vertical(top: Radius.circular(26)),
      );
      await tester.tap(find.byKey(const Key('collection-next-page')));
      await tester.pumpAndSettle();
      expect(find.text('本页 51–100 · 共 600 个座位'), findsOneWidget);
      expect(
        tester.getRect(find.byKey(const Key('library-seat-lazy-50'))).top,
        greaterThanOrEqualTo(
          tester.getRect(find.byType(CollectionQuerySurface)).bottom - 1,
        ),
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('library-seat-lazy-90')),
        900,
        scrollable: scrollable,
      );
      expect(find.byKey(const Key('library-seat-lazy-90')), findsOneWidget);
      expect(find.byKey(const Key('library-seat-lazy-0')), findsNothing);
      expect(mountedRows().evaluate().length, lessThan(35));
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('library-seat-search')),
        'S-599',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('library-seat-lazy-599')), findsOneWidget);
      expect(find.byKey(const Key('library-reserve-lazy-599')), findsNothing);
      expect(mountedRows().evaluate().length, 1);
      final single = tester.widget<ClipRRect>(
        find.byKey(const Key('library-seat-group-lazy-599')),
      );
      expect(single.borderRadius, BorderRadius.circular(26));
      final occupied = find.text('已占用');
      expect(
        tester.widget<Text>(occupied).style!.color,
        CupertinoColors.secondaryLabel.resolveFrom(tester.element(occupied)),
      );
      await tester.tap(find.byType(CupertinoSwitch));
      await tester.pumpAndSettle();
      expect(find.text('没有符合条件的座位'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('library-seat-search')),
        'S-598',
      );
      await tester.pumpAndSettle();
      final button = find.byKey(const Key('library-reserve-lazy-598'));
      expect(button, findsOneWidget);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.textContaining('S-598\n2026-10-20'), findsOneWidget);
      expect(service.writes, 0);
      await tester.tap(find.text('返回'));
      await tester.pumpAndSettle();
      expect(service.writes, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
