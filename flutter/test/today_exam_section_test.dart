import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/features/today/today_exam_section.dart';

import 'today_v2_widget_test.dart' show TodayFake, host, size;

class ExamFake extends TodayFake {
  final requests = <Completer<ScheduleResponse>>[];

  @override
  Future<ScheduleResponse> schedule({
    String? termId,
    int? week,
    bool forceRefresh = false,
  }) {
    final completer = Completer<ScheduleResponse>();
    requests.add(completer);
    return completer.future;
  }
}

const exams = ScheduleResponse(
  terms: [],
  weeks: [],
  termId: 's',
  weekNumber: 1,
  courses: [],
  exams: [
    ScheduleExam(
      id: 'exam-a',
      courseName: '考试A',
      examDate: '2026-10-23',
      startTime: '09:00',
      examPlace: '主楼101',
    ),
  ],
  fetchedAt: '2026-10-22T01:00:00Z',
);
const noExams = ScheduleResponse(
  terms: [],
  weeks: [],
  termId: 's',
  weekNumber: 1,
  courses: [],
  exams: [],
);

void main() {
  testWidgets('exam card appears only when there is an upcoming exam', (
    tester,
  ) async {
    size(tester);
    final fake = ExamFake();
    String? opened;
    await tester.pumpWidget(
      host(
        TodayExamSection(
          service: fake,
          now: DateTime.utc(2026, 10, 22, 9),
          onOpen: (id) => opened = id,
        ),
      ),
    );
    expect(find.text('近期考试'), findsNothing);

    fake.requests.single.complete(exams);
    await tester.pumpAndSettle();
    expect(find.text('近期考试'), findsOneWidget);
    expect(find.text('考试A'), findsOneWidget);
    expect(find.text('课程A'), findsNothing);
    expect(find.text('作业A'), findsNothing);
    expect(find.text('签到A'), findsNothing);
    await tester.tap(find.text('考试A'));
    expect(opened, 'schedule');
  });

  testWidgets('empty and failed exam reads leave no card', (tester) async {
    size(tester);
    final fake = ExamFake();
    await tester.pumpWidget(
      host(TodayExamSection(service: fake, now: DateTime.utc(2026, 10, 22, 9))),
    );
    fake.requests.single.complete(noExams);
    await tester.pumpAndSettle();
    expect(find.text('近期考试'), findsNothing);
    expect(find.byKey(const Key('today-exams')), findsNothing);
  });

  testWidgets('gateway replacement discards late exams', (tester) async {
    size(tester);
    final first = ExamFake();
    final second = ExamFake();
    Widget page(ExamFake service) => host(
      TodayExamSection(service: service, now: DateTime.utc(2026, 10, 22, 9)),
    );
    await tester.pumpWidget(page(first));
    await tester.pumpWidget(page(second));

    expect(second.requests, hasLength(1));
    first.requests.single.complete(exams);
    await tester.pump();
    expect(find.text('近期考试'), findsNothing);
    second.requests.single.complete(noExams);
    await tester.pumpAndSettle();
    expect(find.text('近期考试'), findsNothing);
  });
}
