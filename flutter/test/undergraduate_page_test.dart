import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';
import 'package:ginkgo_mirror/features/undergraduate/undergraduate_page.dart';

class _FakeAcademicGateway implements AcademicGateway {
  _FakeAcademicGateway({
    required this.scheduleResponse,
    required this.gradeResponse,
  });

  final ScheduleResponse scheduleResponse;
  final GradeResponse gradeResponse;

  @override
  bool get isDemo => false;

  @override
  Future<TodayResponse> today({bool forceRefresh = false}) =>
      throw UnimplementedError();

  @override
  Future<ScheduleResponse> schedule({
    String? termId,
    int? week,
    bool forceRefresh = false,
  }) async => scheduleResponse;

  @override
  Future<GradeTermsResponse> gradeTerms() async =>
      GradeTermsResponse(terms: scheduleResponse.terms);

  @override
  Future<GradeResponse> grades({
    String? termCode,
    bool forceRefresh = false,
  }) async => gradeResponse;

  @override
  Future<ClassroomResponse> classrooms(DemoScope scope, ClassroomQuery query) =>
      throw UnimplementedError();

  @override
  Future<QueryDates> dates(String instant) => throw UnimplementedError();

  @override
  Future<HomeworkResponse> homework({bool forceRefresh = false}) =>
      throw UnimplementedError();

  @override
  Future<HomeworkDetailResponse> homeworkDetail(
    String id, {
    bool forceRefresh = false,
  }) => throw UnimplementedError();

  @override
  Future<RuleExamples> rules() => throw UnimplementedError();
}

void main() {
  testWidgets('renders undergraduate GPA vial, exams and quick actions', (
    tester,
  ) async {
    final opened = <String>[];
    final gateway = _FakeAcademicGateway(
      scheduleResponse: const ScheduleResponse(
        terms: [
          ScheduleTerm(
            id: '2026-2027-1',
            name: '2026-2027学年第1学期',
            selected: true,
          ),
        ],
        weeks: [
          ScheduleWeek(
            number: 10,
            current: true,
            startDate: '2026-11-23',
            endDate: '2026-11-29',
          ),
        ],
        termId: '2026-2027-1',
        weekNumber: 10,
        courses: [
          ScheduleCourse(
            id: 'c1',
            name: '算法设计与分析',
            day: 1,
            startSection: 1,
            endSection: 2,
          ),
        ],
        exams: [
          ScheduleExam(
            id: 'e1',
            courseName: '算法设计与分析',
            examDate: '2026-12-20',
            startTime: '09:00',
            endTime: '11:00',
            examPlace: '新主楼A101',
            examSeatNo: '18',
            week: 16,
            examType: '期末考试',
          ),
        ],
        fetchedAt: '2026-11-24T10:00:00+08:00',
      ),
      gradeResponse: const GradeResponse(
        termId: '2026-2027-1',
        courses: [],
        summary: GradeSummary(
          courseCount: 4,
          creditTotal: 14.5,
          weightedAverage: 91.4,
          gradePointAverage: 3.82,
        ),
        fetchedAt: '2026-11-24T10:00:00+08:00',
      ),
    );

    await tester.pumpWidget(
      CupertinoApp(
        home: UndergraduatePage(
          service: gateway,
          onOpenFeature: opened.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('undergraduate-dashboard')), findsOneWidget);
    expect(find.textContaining('GPA 3.82'), findsOneWidget);
    expect(find.text('算法设计与分析'), findsOneWidget);
    expect(find.textContaining('新主楼A101'), findsOneWidget);
    expect(find.textContaining('座号 18'), findsOneWidget);
    expect(find.byKey(const Key('undergraduate-graduate-hint')), findsNothing);

    await tester.drag(
      find.byKey(const Key('undergraduate-scroll')),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('undergrad-open-schedule')));
    expect(opened, ['schedule']);
  });

  testWidgets('detects graduate term source and guides user to graduate page', (
    tester,
  ) async {
    final opened = <String>[];
    final gateway = _FakeAcademicGateway(
      scheduleResponse: const ScheduleResponse(
        terms: [ScheduleTerm(id: '20261', name: '2026秋季', selected: true)],
        weeks: [],
        termId: '20261',
        weekNumber: 1,
        courses: [],
        exams: [],
        fetchedAt: '2026-11-24T10:00:00+08:00',
      ),
      gradeResponse: const GradeResponse(
        termId: '20261',
        courses: [],
        summary: GradeSummary(courseCount: 0, creditTotal: 0),
        fetchedAt: '2026-11-24T10:00:00+08:00',
      ),
    );

    await tester.pumpWidget(
      CupertinoApp(
        theme: const CupertinoThemeData(brightness: Brightness.dark),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(1.6),
            disableAnimations: true,
          ),
          child: UndergraduatePage(
            service: gateway,
            onOpenFeature: opened.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('undergraduate-graduate-hint')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('undergraduate-graduate-hint')),
      findsOneWidget,
    );
    expect(find.text('本科考试接口未对研究生开放'), findsOneWidget);
    await tester.tap(find.byKey(const Key('undergraduate-graduate-hint')));
    expect(opened, ['graduate']);
  });
}
