import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/features/checkin/checkin_page.dart';

class CheckinWrites extends Fake implements CheckInGateway {
  int reads = 0;
  bool stale = false;
  final writes = <Completer<MutationResponse>>[];
  @override
  bool get isDemo => true;
  @override
  Future<CheckInResponse> checkin({bool forceRefresh = false}) async {
    reads++;
    return CheckInResponse(
      date: '2026-11-02',
      courses: const [
        CheckInCourse(
          id: 'c1',
          courseName: '合成课程',
          beginsAt: '08:00',
          endsAt: '10:00',
          status: CheckInStatus.notSigned,
          mergedRecordCount: 1,
          conflicting: false,
        ),
      ],
      fromCache: false,
      stale: stale,
    );
  }

  @override
  Future<MutationResponse> submitCheckin(String courseId) {
    final write = Completer<MutationResponse>();
    writes.add(write);
    return write.future;
  }
}

Widget host(CheckinWrites service, DateTime Function() clock) => CupertinoApp(
  home: CheckInPage(service: service, clock: clock),
);
Future<void> openConfirmation(
  WidgetTester tester,
  CheckinWrites service,
  DateTime Function() clock,
) async {
  tester.view.physicalSize = const Size(430, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(host(service, clock));
  await tester.pumpAndSettle();
  await tester.tap(find.text('签到').last);
  await tester.pumpAndSettle();
  expect(find.text('确认签到？'), findsOneWidget);
}

Future<void> confirm(WidgetTester tester) async {
  await tester.tap(find.text('确认签到'));
  await tester.pump();
}

void main() {
  DateTime morning() => DateTime.utc(2026, 11, 2, 1);
  testWidgets('stale checkin snapshot shows a disabled submit action', (
    tester,
  ) async {
    final service = CheckinWrites()..stale = true;
    await tester.pumpWidget(host(service, morning));
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('checkin-submit-c1'));
    expect(tester.widget<CupertinoButton>(button).onPressed, isNull);
    expect(service.writes, isEmpty);
  });
  testWidgets('checkin refresh revokes a pending confirmation', (tester) async {
    final service = CheckinWrites();
    await openConfirmation(tester, service, morning);
    final refresh = tester.widget<CupertinoSliverRefreshControl>(
      find.byType(CupertinoSliverRefreshControl, skipOffstage: false),
    );
    await refresh.onRefresh!();
    await tester.pump();
    await confirm(tester);
    expect(service.writes, isEmpty);
    await tester.pumpAndSettle();
  });
  testWidgets('checkin service replacement revokes confirmation', (
    tester,
  ) async {
    final first = CheckinWrites(), second = CheckinWrites();
    await openConfirmation(tester, first, morning);
    await tester.pumpWidget(host(second, morning));
    await tester.pump();
    await confirm(tester);
    expect(first.writes, isEmpty);
    expect(second.writes, isEmpty);
    await tester.pumpAndSettle();
  });
  testWidgets('checkin confirmation rechecks the live time window', (
    tester,
  ) async {
    final service = CheckinWrites();
    var now = morning();
    await openConfirmation(tester, service, () => now);
    now = DateTime.utc(2026, 11, 2, 3);
    await confirm(tester);
    expect(service.writes, isEmpty);
    await tester.pumpAndSettle();
  });
  testWidgets('late checkin result cannot update replacement context', (
    tester,
  ) async {
    final first = CheckinWrites(), second = CheckinWrites();
    await openConfirmation(tester, first, morning);
    await confirm(tester);
    expect(first.writes, hasLength(1));
    await tester.pumpWidget(host(second, morning));
    await tester.pump();
    first.writes.single.complete(
      const MutationResponse(state: 'accepted', message: '旧签到结果'),
    );
    await tester.pumpAndSettle();
    expect(first.reads, 2);
    expect(second.reads, 1);
    expect(find.text('旧签到结果'), findsNothing);
  });
}
