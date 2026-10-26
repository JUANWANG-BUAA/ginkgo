import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/features/classroom/classroom_page.dart';
import 'package:ginkgo_mirror/features/classroom/classroom_results.dart';
import 'package:ginkgo_mirror/main.dart';

import 'mirror_widget_test.dart' show ControlledService;

class ManyRoomsService extends ControlledService {
  int reads = 0;
  Completer<ClassroomResponse>? delayed;
  final result = ClassroomResponse(
    buildings: List.generate(
      2,
      (building) => ClassroomBuilding(
        name: building == 0 ? '教学楼 A' : '教学楼 B',
        rooms: List.generate(300, (offset) {
          final index = building * 300 + offset;
          return ClassroomRow(
            id: 'room-$index',
            name: '教室 $index',
            floor: '1',
            sections: Int32List.fromList([1, 2]),
            longestRun: 2,
            sectionStates: [],
          );
        }),
      ),
    ),
    roomCount: 600,
    buildingCount: 2,
    freeSlotCount: 1200,
    fromCache: false,
  );

  @override
  Future<ClassroomResponse> classrooms(
    DemoScope scope,
    ClassroomQuery query,
  ) async {
    reads++;
    return delayed == null ? result : delayed!.future;
  }
}

void main() {
  testWidgets(
    'large room results are bounded, lazy, pinned and preserve the current page',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = ManyRoomsService();
      await tester.pumpWidget(ginkgoApp(home: ClassroomPage(service: service)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('查询空教室'));
      await tester.pumpAndSettle();
      expect(find.text('1–50 / 600 间教室'), findsOneWidget);
      expect(
        tester
            .getRect(find.byKey(const ValueKey('classroom-room-教学楼 A-room-0')))
            .top,
        greaterThanOrEqualTo(
          tester.getRect(find.byType(ClassroomResultsHeader)).bottom - 1,
        ),
      );
      expect(find.byType(ClassroomResultTile).evaluate().length, lessThan(30));
      await tester.tap(find.byKey(const Key('collection-next-page')));
      await tester.pumpAndSettle();
      expect(find.text('51–100 / 600 间教室'), findsOneWidget);
      final scrollable = find
          .descendant(
            of: find.byKey(const Key('classroom-scroll')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('classroom-room-教学楼 A-room-90')),
        700,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      final header = tester.getRect(find.byKey(const Key('classroom-search')));
      expect(header.top, greaterThanOrEqualTo(0));
      expect(header.bottom, lessThan(400));
      final anchorRow = find.byKey(
        const ValueKey('classroom-room-教学楼 A-room-90'),
      );
      service.delayed = Completer<ClassroomResponse>();
      await tester.tap(find.bySemanticsLabel('刷新空教室').first);
      await tester.pump();
      expect(find.text('51–100 / 600 间教室'), findsOneWidget);
      service.delayed!.complete(service.result);
      await tester.pumpAndSettle();
      // The current page and viewed item survive refresh. Exact pixel anchoring
      // under sliver relayout remains a documented follow-up.
      expect(tester.getRect(anchorRow).top, greaterThanOrEqualTo(0));
      expect(tester.getRect(anchorRow).bottom, lessThan(1100));
      expect(find.text('51–100 / 600 间教室'), findsOneWidget);
      await tester.tap(find.byKey(const Key('classroom-building-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('教学楼 B').last);
      await tester.pumpAndSettle();
      expect(find.text('1–50 / 300 间教室'), findsOneWidget);
      expect(service.reads, 2);
      expect(find.text('教室 300'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('search coalesces rapid typing before issuing the query', (
    tester,
  ) async {
    final service = ManyRoomsService();
    await tester.pumpWidget(ginkgoApp(home: ClassroomPage(service: service)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('查询空教室'));
    await tester.tap(find.text('查询空教室'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('classroom-search')), '1');
    await tester.enterText(find.byKey(const Key('classroom-search')), '101');
    expect(service.reads, 1);
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pumpAndSettle();
    expect(service.reads, 2);
    expect(tester.takeException(), isNull);
  });
}
