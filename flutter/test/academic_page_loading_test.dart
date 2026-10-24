import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/apple_widgets.dart';
import 'package:ginkgo_mirror/grades_page.dart';
import 'package:ginkgo_mirror/homework_detail_page.dart';
import 'package:ginkgo_mirror/homework_page.dart';
import 'package:ginkgo_mirror/loading_widgets.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/schedule_page.dart';
import 'package:ginkgo_mirror/src/rust/api/live.dart'
    show GradeTermsResponse, HomeworkDetailResponse;
import 'package:ginkgo_mirror/src/rust/api/mirror.dart';

import 'mirror_widget_test.dart'
    show ControlledService, gradesFixture, homeworkFixture, scheduleFixture;

class PendingAcademicService extends ControlledService {
  final terms = Completer<GradeTermsResponse>();
  final gradesRequest = Completer<GradeResponse>();
  final scheduleRequest = Completer<ScheduleResponse>();
  final homeworkRequest = Completer<HomeworkResponse>();
  final detailRequests = <Completer<HomeworkDetailResponse>>[];

  @override
  Future<GradeTermsResponse> gradeTerms() => terms.future;

  @override
  Future<GradeResponse> grades({String? termCode, bool forceRefresh = false}) =>
      gradesRequest.future;

  @override
  Future<ScheduleResponse> schedule({
    String? termId,
    int? week,
    bool forceRefresh = false,
  }) => scheduleRequest.future;

  @override
  Future<HomeworkResponse> homework({bool forceRefresh = false}) =>
      homeworkRequest.future;

  @override
  Future<HomeworkDetailResponse> homeworkDetail(
    String assignmentId, {
    bool forceRefresh = false,
  }) {
    final request = Completer<HomeworkDetailResponse>();
    detailRequests.add(request);
    return request.future;
  }
}

class RefreshingAcademicService extends ControlledService {
  int gradeCalls = 0;
  final pendingGrades = Completer<GradeResponse>();
  int scheduleCalls = 0;
  final pendingSchedule = Completer<ScheduleResponse>();
  int homeworkCalls = 0;
  final pendingHomework = Completer<HomeworkResponse>();
  int detailCalls = 0;
  final pendingDetails = <Completer<HomeworkDetailResponse>>[];

  @override
  Future<GradeResponse> grades({String? termCode, bool forceRefresh = false}) {
    gradeCalls++;
    return gradeCalls == 1 ? Future.value(gradesFixture) : pendingGrades.future;
  }

  @override
  Future<ScheduleResponse> schedule({
    String? termId,
    int? week,
    bool forceRefresh = false,
  }) {
    scheduleCalls++;
    return scheduleCalls == 1
        ? Future.value(scheduleFixture)
        : pendingSchedule.future;
  }

  @override
  Future<HomeworkResponse> homework({bool forceRefresh = false}) {
    homeworkCalls++;
    return homeworkCalls == 1
        ? Future.value(homeworkFixture)
        : pendingHomework.future;
  }

  @override
  Future<HomeworkDetailResponse> homeworkDetail(
    String assignmentId, {
    bool forceRefresh = false,
  }) {
    detailCalls++;
    if (detailCalls == 1) {
      return Future.value(
        const HomeworkDetailResponse(
          content: '合成正文',
          status: '待完成',
          stale: false,
        ),
      );
    }
    final request = Completer<HomeworkDetailResponse>();
    pendingDetails.add(request);
    return request.future;
  }
}

Future<void> pumpPage(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(430, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ginkgoApp(home: page));
  await tester.pump();
}

void expectSmallBusyLeaf(WidgetTester tester) {
  expect(find.byType(CupertinoActivityIndicator), findsNothing);
  final leaves = tester
      .widgetList<GinkgoActivity>(find.byType(GinkgoActivity))
      .where((leaf) => leaf.size == 17);
  expect(leaves, hasLength(1));
}

void main() {
  testWidgets('grades first load uses the branded loading view', (
    tester,
  ) async {
    final service = PendingAcademicService();
    await pumpPage(tester, GradesPage(service: service));
    expect(find.byType(GinkgoLoadingView), findsOneWidget);
    expect(find.text('正在读取成绩…'), findsOneWidget);
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
    service.terms.complete(
      const GradeTermsResponse(
        terms: [ScheduleTerm(id: '2026-2027-1', name: '合成学期', selected: true)],
      ),
    );
    await tester.pump();
    service.gradesRequest.complete(gradesFixture);
    await tester.pumpAndSettle();
    expect(find.byType(GinkgoLoadingView), findsNothing);
  });

  testWidgets('schedule first load uses the branded loading view', (
    tester,
  ) async {
    final service = PendingAcademicService();
    await pumpPage(tester, SchedulePage(service: service));
    expect(find.byType(GinkgoLoadingView), findsOneWidget);
    expect(find.text('正在读取课表…'), findsOneWidget);
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
    service.scheduleRequest.complete(scheduleFixture);
    await tester.pumpAndSettle();
    expect(find.byType(GinkgoLoadingView), findsNothing);
  });

  testWidgets('homework first load uses the branded loading view', (
    tester,
  ) async {
    final service = PendingAcademicService();
    await pumpPage(tester, HomeworkPage(service: service));
    expect(find.byType(GinkgoLoadingView), findsOneWidget);
    expect(find.text('正在读取作业…'), findsOneWidget);
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
    service.homeworkRequest.complete(homeworkFixture);
    await tester.pumpAndSettle();
    expect(find.byType(GinkgoLoadingView), findsNothing);
  });

  testWidgets('homework detail first load uses the branded loading view', (
    tester,
  ) async {
    final service = PendingAcademicService();
    await pumpPage(
      tester,
      HomeworkDetailPage(item: homeworkFixture.items.first, service: service),
    );
    expect(find.byType(GinkgoLoadingView), findsOneWidget);
    expect(find.text('正在读取作业详情…'), findsOneWidget);
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
    service.detailRequests.single.complete(
      const HomeworkDetailResponse(
        content: '合成正文',
        status: '待完成',
        stale: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GinkgoLoadingView), findsNothing);
  });

  testWidgets('grades refresh shows the small branded leaf', (tester) async {
    final service = RefreshingAcademicService();
    await pumpPage(tester, GradesPage(service: service));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(CupertinoIcons.refresh));
    await tester.pump();
    expectSmallBusyLeaf(tester);
    service.pendingGrades.complete(gradesFixture);
    await tester.pumpAndSettle();
  });

  testWidgets('schedule refresh shows the small branded leaf', (tester) async {
    final service = RefreshingAcademicService();
    await pumpPage(tester, SchedulePage(service: service));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(CupertinoIcons.refresh));
    await tester.pump();
    expectSmallBusyLeaf(tester);
    service.pendingSchedule.complete(scheduleFixture);
    await tester.pumpAndSettle();
  });

  testWidgets('homework refresh shows the small branded leaf', (tester) async {
    final service = RefreshingAcademicService();
    await pumpPage(tester, HomeworkPage(service: service));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(CupertinoIcons.refresh));
    await tester.pump();
    expectSmallBusyLeaf(tester);
    service.pendingHomework.complete(homeworkFixture);
    await tester.pumpAndSettle();
  });

  testWidgets('homework detail refresh shows the small branded leaf', (
    tester,
  ) async {
    final service = RefreshingAcademicService();
    await pumpPage(
      tester,
      HomeworkDetailPage(item: homeworkFixture.items.first, service: service),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(CupertinoIcons.refresh));
    await tester.pump();
    expectSmallBusyLeaf(tester);
    service.pendingDetails.single.complete(
      const HomeworkDetailResponse(
        content: '合成正文',
        status: '待完成',
        stale: false,
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('academic headers keep section, subtitle and icon', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final expectations = <(Widget, String, String, IconData)>[
      (
        GradesPage(service: PendingAcademicService()),
        '查看课程成绩、学分与加权统计',
        '正在读取成绩…',
        CupertinoIcons.chart_bar_alt_fill,
      ),
      (
        SchedulePage(service: PendingAcademicService()),
        '按学期与教学周查看课程和考试',
        '正在读取课表…',
        CupertinoIcons.calendar,
      ),
      (
        HomeworkPage(service: PendingAcademicService()),
        '区分个人作业状态与助教课程',
        '正在读取作业…',
        CupertinoIcons.doc_text,
      ),
    ];
    for (final (page, subtitle, loadingLabel, icon) in expectations) {
      await tester.pumpWidget(ginkgoApp(home: page));
      await tester.pump();
      final header = tester.widget<ApplePageHeader>(
        find.byType(ApplePageHeader),
      );
      expect(header.section, '学业');
      expect(header.subtitle, subtitle);
      expect(header.icon, icon);
      expect(find.text('学业'), findsOneWidget);
      expect(find.text(subtitle), findsOneWidget);
      expect(find.byIcon(icon), findsOneWidget);
      expect(find.text(loadingLabel), findsOneWidget);
    }
  });
}
