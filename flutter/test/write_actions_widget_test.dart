import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/features/checkin/checkin_page.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/features/library/library_page.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/src/rust/api/live.dart';
import 'package:ginkgo_mirror/src/rust/api/mirror.dart';

import 'mirror_widget_test.dart'
    show ControlledService, checkInFixture, libraryBookingsFixture;

class WriteService extends ControlledService {
  int writes = 0, readbacks = 0;
  final pending = Completer<MutationResponse>();
  @override
  Future<CheckInResponse> checkin({bool forceRefresh = false}) async {
    if (forceRefresh) readbacks++;
    return checkInFixture;
  }

  @override
  Future<MutationResponse> submitCheckin(String courseId) {
    writes++;
    return pending.future;
  }

  @override
  Future<MutationResponse> reserveLibrarySeat({
    required String areaId,
    required String seatId,
    required LibrarySlot slot,
  }) {
    writes++;
    return pending.future;
  }

  @override
  Future<LibraryBookingsResponse> libraryBookings({bool forceRefresh = false}) {
    if (forceRefresh) readbacks++;
    return Future.value(
      writes == 0
          ? const LibraryBookingsResponse(
              bookings: [],
              fromCache: false,
              stale: false,
            )
          : libraryBookingsFixture,
    );
  }
}

void main() {
  testWidgets(
    'checkin requires confirmation, prevents double submit and reads back uncertain outcome',
    (tester) async {
      final service = WriteService();
      tester.view.physicalSize = const Size(430, 1300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ginkgoApp(
          home: CheckInPage(
            service: service,
            clock: () => DateTime.parse('2026-10-20T08:00:00+08:00'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.byKey(const Key('checkin-submit-501'));
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(service.writes, 0);
      expect(
        find.text('高等数学\n2026-10-20\n08:00–09:35\n主楼A101'),
        findsOneWidget,
      );
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(service.writes, 0);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认签到'));
      await tester.pump();
      expect(service.writes, 1);
      final submitting = find.descendant(
        of: button,
        matching: find.byType(GinkgoActivity),
      );
      expect(submitting, findsOneWidget);
      expect(tester.widget<GinkgoActivity>(submitting).size, 17);
      expect(tester.widget<CupertinoButton>(button).onPressed, isNull);
      service.pending.complete(
        const MutationResponse(state: 'uncertain', message: '测试：结果待核实'),
      );
      await tester.pumpAndSettle();
      expect(service.readbacks, 1);
      expect(find.text('测试：结果待核实'), findsOneWidget);
      expect(tester.widget<CupertinoButton>(button).onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unsigned status resolves its contrast in dark mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        theme: const CupertinoThemeData(brightness: Brightness.dark),
        home: CheckInPage(service: WriteService()),
      ),
    );
    await tester.pumpAndSettle();
    final label = find.text('未签到');
    final expected = AppleDesign.statusInactive.resolveFrom(
      tester.element(label),
    );
    expect(tester.widget<Text>(label).style!.color, expected);
    final footer = find.text('演示模式不会提交签到');
    await tester.scrollUntilVisible(
      footer,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester.widget<Text>(footer).style!.color,
      CupertinoColors.secondaryLabel.resolveFrom(tester.element(footer)),
    );
  });

  testWidgets(
    'seat reservation confirms exact date and seat and rechecks bookings',
    (tester) async {
      final service = WriteService();
      tester.view.physicalSize = const Size(430, 1300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ginkgoApp(home: LibraryPage(service: service)));
      await tester.pumpAndSettle();
      for (final key in [
        'library-venue-v1',
        'library-area-a1',
        'library-slot-2026-10-20/t1',
      ]) {
        await tester.tap(find.byKey(Key(key)));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const Key('library-reserve-s1')));
      await tester.pumpAndSettle();
      expect(find.textContaining('A-01\n2026-10-20'), findsOneWidget);
      expect(service.writes, 0);
      await tester.tap(find.text('确认预约'));
      await tester.pump();
      expect(service.writes, 1);
      service.pending.complete(
        const MutationResponse(state: 'accepted', message: '测试：学校已受理'),
      );
      await tester.pumpAndSettle();
      expect(service.readbacks, 1);
      expect(find.text('查看预约'), findsOneWidget);
      expect(
        tester
            .widget<CupertinoButton>(
              find.byKey(const Key('library-reserve-s1')),
            )
            .onPressed,
        isNull,
      );
      // The original route must receive the readback, not only a new page.
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      for (var i = 0; i < 3; i++) {
        navigator.pop();
        await tester.pumpAndSettle();
      }
      expect(find.text('当前没有进行中的预约'), findsNothing);
      expect(
        find.text(libraryBookingsFixture.bookings.single.title),
        findsOneWidget,
      );
      expect(service.readbacks, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
