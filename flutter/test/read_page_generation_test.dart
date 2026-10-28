import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/application/query_snapshots.dart';
import 'package:ginkgo_mirror/features/checkin/checkin_page.dart';
import 'package:ginkgo_mirror/features/cgyy/cgyy_day_page.dart';
import 'package:ginkgo_mirror/features/cgyy/cgyy_models.dart';
import 'package:ginkgo_mirror/features/grades/grades_page.dart';
import 'package:ginkgo_mirror/features/learning/learning_snapshots_page.dart';
import 'package:ginkgo_mirror/features/schedule/schedule_page.dart';

class AcademicReads extends Fake implements AcademicGateway {
  final termReads = <Completer<GradeTermsResponse>>[];
  final gradeReads = <Completer<GradeResponse>>[];
  final scheduleReads = <Completer<ScheduleResponse>>[];

  @override
  bool get isDemo => true;

  @override
  Future<GradeTermsResponse> gradeTerms() {
    final read = Completer<GradeTermsResponse>();
    termReads.add(read);
    return read.future;
  }

  @override
  Future<GradeResponse> grades({String? termCode, bool forceRefresh = false}) {
    final read = Completer<GradeResponse>();
    gradeReads.add(read);
    return read.future;
  }

  @override
  Future<ScheduleResponse> schedule({
    String? termId,
    int? week,
    bool forceRefresh = false,
  }) {
    final read = Completer<ScheduleResponse>();
    scheduleReads.add(read);
    return read.future;
  }
}

class CheckInReads extends Fake implements CheckInGateway {
  final reads = <Completer<CheckInResponse>>[];

  @override
  bool get isDemo => true;

  @override
  Future<CheckInResponse> checkin({bool forceRefresh = false}) {
    final read = Completer<CheckInResponse>();
    reads.add(read);
    return read.future;
  }
}

class SnapshotReads extends Fake implements LearningSnapshotGateway {
  final reads = <Completer<LearningSnapshotStatus>>[];

  @override
  Future<LearningSnapshotStatus> learningSnapshotStatus() {
    final read = Completer<LearningSnapshotStatus>();
    reads.add(read);
    return read.future;
  }
}

GradeResponse grades(String name) => GradeResponse(
  termId: 'term',
  courses: [
    GradeCourse(id: name, name: name, credit: 1, score: '60', scoreValue: 60),
  ],
  summary: GradeSummary(
    courseCount: 1,
    creditTotal: 1,
    weightedAverage: 60,
    gradePointAverage: 1,
  ),
);

ScheduleResponse schedule(String name) => ScheduleResponse(
  terms: const [],
  weeks: const [],
  termId: 'term',
  weekNumber: 1,
  courses: [
    ScheduleCourse(
      id: name,
      name: name,
      day: 1,
      startSection: 1,
      endSection: 2,
      startTime: '08:00',
      endTime: '09:00',
    ),
  ],
  exams: const [],
);

CheckInResponse checkin(String name) => CheckInResponse(
  date: '2026-10-20',
  courses: [
    CheckInCourse(
      id: name,
      courseName: name,
      beginsAt: '08:00',
      endsAt: '09:00',
      status: CheckInStatus.signed,
      mergedRecordCount: 1,
      conflicting: false,
    ),
  ],
  fromCache: false,
  stale: false,
);

void main() {
  testWidgets('grades replacement discards the old service response', (
    tester,
  ) async {
    final first = AcademicReads();
    final second = AcademicReads();
    await tester.pumpWidget(CupertinoApp(home: GradesPage(service: first)));
    first.termReads.single.complete(const GradeTermsResponse(terms: []));
    await tester.pump();
    await tester.pumpWidget(CupertinoApp(home: GradesPage(service: second)));
    second.termReads.single.complete(const GradeTermsResponse(terms: []));
    await tester.pump();
    expect(second.gradeReads, hasLength(1));

    first.gradeReads.single.complete(grades('旧服务成绩'));
    await tester.pump();
    expect(find.text('旧服务成绩'), findsNothing);
    second.gradeReads.single.complete(grades('新服务成绩'));
    await tester.pumpAndSettle();
    expect(find.text('新服务成绩'), findsOneWidget);
  });

  testWidgets('schedule replacement discards the old service response', (
    tester,
  ) async {
    final first = AcademicReads();
    final second = AcademicReads();
    await tester.pumpWidget(CupertinoApp(home: SchedulePage(service: first)));
    await tester.pumpWidget(CupertinoApp(home: SchedulePage(service: second)));
    expect(second.scheduleReads, hasLength(1));

    first.scheduleReads.single.complete(schedule('旧服务课表'));
    await tester.pump();
    expect(find.text('旧服务课表'), findsNothing);
    second.scheduleReads.single.complete(schedule('新服务课表'));
    await tester.pumpAndSettle();
    expect(find.text('新服务课表'), findsOneWidget);
  });

  testWidgets('checkin replacement discards the old service response', (
    tester,
  ) async {
    final first = CheckInReads();
    final second = CheckInReads();
    await tester.pumpWidget(CupertinoApp(home: CheckInPage(service: first)));
    await tester.pumpWidget(CupertinoApp(home: CheckInPage(service: second)));
    expect(second.reads, hasLength(1));

    first.reads.single.complete(checkin('旧服务签到'));
    await tester.pump();
    expect(find.text('旧服务签到'), findsNothing);
    second.reads.single.complete(checkin('新服务签到'));
    await tester.pumpAndSettle();
    expect(find.text('新服务签到'), findsOneWidget);
  });

  testWidgets('CGYY loader replacement discards the old day', (tester) async {
    final site = CgyySite.fromJson(const {
      'id': 3,
      'name': '合成研讨室',
      'venue': '合成场馆',
      'campus': '学院路',
    });
    final first = Completer<ReadOnlyResponse>();
    final second = Completer<ReadOnlyResponse>();
    CgyyLoader loader(Completer<ReadOnlyResponse> read) =>
        ({
          required kind,
          required siteId,
          required date,
          required forceRefresh,
        }) => read.future;
    await tester.pumpWidget(
      CupertinoApp(
        home: CgyyDayPage(demo: true, site: site, loader: loader(first)),
      ),
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: CgyyDayPage(demo: true, site: site, loader: loader(second)),
      ),
    );
    first.complete(
      ReadOnlyResponse(
        payload: jsonEncode({
          'date': '2026-10-20',
          'spaces': [
            {
              'name': '旧服务空间',
              'slots': [
                {'time': '08:00–09:00', 'status': '空闲'},
              ],
            },
          ],
        }),
        stale: false,
      ),
    );
    await tester.pump();
    expect(find.text('旧服务空间'), findsNothing);
    second.complete(
      ReadOnlyResponse(
        payload: jsonEncode({
          'date': '2026-10-20',
          'spaces': [
            {
              'name': '新服务空间',
              'slots': [
                {'time': '08:00–09:00', 'status': '空闲'},
              ],
            },
          ],
        }),
        stale: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('新服务空间'), findsOneWidget);
  });

  testWidgets('snapshot gateway replacement discards the old status', (
    tester,
  ) async {
    final first = SnapshotReads();
    final second = SnapshotReads();
    await tester.pumpWidget(
      CupertinoApp(home: LearningSnapshotsPage(gateway: first)),
    );
    await tester.pumpWidget(
      CupertinoApp(home: LearningSnapshotsPage(gateway: second)),
    );
    expect(second.reads, hasLength(1));

    first.reads.single.complete(
      const LearningSnapshotStatus(supported: true, message: '旧服务状态'),
    );
    await tester.pump();
    expect(find.text('旧服务状态'), findsNothing);
    second.reads.single.complete(
      const LearningSnapshotStatus(supported: true, message: '新服务状态'),
    );
    await tester.pumpAndSettle();
    expect(find.text('新服务状态'), findsOneWidget);
  });
}
