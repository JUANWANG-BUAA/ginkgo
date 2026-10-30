import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/school_rules.dart';
import 'package:ginkgo_mirror/application/refresh_section.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/features/homework/homework_page.dart';
import 'package:ginkgo_mirror/features/homework/homework_projection.dart';
import 'package:ginkgo_mirror/main.dart';
import 'package:ginkgo_mirror/features/today/today_homework_section.dart';

import 'mirror_widget_test.dart' show ControlledService;
import 'platform_actions_fake.dart';

class FakeAcademicGateway extends ControlledService {
  FakeAcademicGateway(this.response);
  final HomeworkResponse response;

  @override
  Future<HomeworkResponse> homework({bool forceRefresh = false}) async =>
      response;
}

void main() {
  final beijingNow = DateTime.utc(2026, 10, 23, 12, 0, 0);

  group('HomeworkDeadlineClassification Unit Tests', () {
    test('undated and whitespace deadlines are classified as undated', () {
      expect(
        classifyHomeworkDeadline(null, beijingNow),
        HomeworkDeadlineStatus.undated,
      );
      expect(
        classifyHomeworkDeadline('', beijingNow),
        HomeworkDeadlineStatus.undated,
      );
      expect(
        classifyHomeworkDeadline('   ', beijingNow),
        HomeworkDeadlineStatus.undated,
      );
      expect(isHomeworkOverdue(null, beijingNow), isFalse);
      expect(isHomeworkOverdue('', beijingNow), isFalse);
    });

    test('date-only deadlines: valid until end of that Beijing day, overdue at next-day 00:00', () {
      const due = '2026-10-23';
      // At 23:59:59 on the same day -> active
      final sameDayLate = DateTime.utc(2026, 10, 23, 23, 59, 59);
      expect(
        classifyHomeworkDeadline(due, sameDayLate),
        HomeworkDeadlineStatus.active,
      );
      expect(isHomeworkOverdue(due, sameDayLate), isFalse);

      // At 00:00:00 next day -> overdue
      final nextDayMidnight = DateTime.utc(2026, 10, 24, 0, 0, 0);
      expect(
        classifyHomeworkDeadline(due, nextDayMidnight),
        HomeworkDeadlineStatus.overdue,
      );
      expect(isHomeworkOverdue(due, nextDayMidnight), isTrue);

      // Yesterday's date-only -> overdue
      expect(
        classifyHomeworkDeadline('2026-10-22', beijingNow),
        HomeworkDeadlineStatus.overdue,
      );
      expect(isHomeworkOverdue('2026-10-22', beijingNow), isTrue);

      // Tomorrow's date-only -> active
      expect(
        classifyHomeworkDeadline('2026-10-24', beijingNow),
        HomeworkDeadlineStatus.active,
      );
      expect(isHomeworkOverdue('2026-10-24', beijingNow), isFalse);
    });

    test('exact timestamps: overdue when now >= deadline', () {
      const due = '2026-10-23 18:00:00';
      // 1 second before -> active
      final before = DateTime.utc(2026, 10, 23, 17, 59, 59);
      expect(
        classifyHomeworkDeadline(due, before),
        HomeworkDeadlineStatus.active,
      );
      expect(isHomeworkOverdue(due, before), isFalse);

      // Exact moment -> overdue (now >= deadline)
      final at = DateTime.utc(2026, 10, 23, 18, 0, 0);
      expect(classifyHomeworkDeadline(due, at), HomeworkDeadlineStatus.overdue);
      expect(isHomeworkOverdue(due, at), isTrue);

      // 1 second after -> overdue
      final after = DateTime.utc(2026, 10, 23, 18, 0, 1);
      expect(
        classifyHomeworkDeadline(due, after),
        HomeworkDeadlineStatus.overdue,
      );
      expect(isHomeworkOverdue(due, after), isTrue);
    });

    test('zoned timestamps: UTC vs +08:00 represent identical instants in Beijing time', () {
      // 10:00 UTC == 18:00 Beijing time
      const utcDue = '2026-10-23T10:00:00Z';
      const bjtDue = '2026-10-23T18:00:00+08:00';

      final before = DateTime.utc(2026, 10, 23, 17, 59, 59);
      expect(
        classifyHomeworkDeadline(utcDue, before),
        HomeworkDeadlineStatus.active,
      );
      expect(
        classifyHomeworkDeadline(bjtDue, before),
        HomeworkDeadlineStatus.active,
      );

      final at = DateTime.utc(2026, 10, 23, 18, 0, 0);
      expect(
        classifyHomeworkDeadline(utcDue, at),
        HomeworkDeadlineStatus.overdue,
      );
      expect(
        classifyHomeworkDeadline(bjtDue, at),
        HomeworkDeadlineStatus.overdue,
      );
    });

    test(
      'invalid and impossible calendar dates remain invalid, never overdue',
      () {
        const invalids = [
          '2026-02-30', // impossible February day
          '2026-13-01', // month 13
          '2026-10-32', // day 32
          '2026-10-23 25:00:00', // hour 25
          'not-a-date',
          '2026/10/23',
        ];

        for (final raw in invalids) {
          expect(
            classifyHomeworkDeadline(raw, beijingNow),
            HomeworkDeadlineStatus.invalid,
            reason: 'Expected $raw to be classified as invalid',
          );
          expect(
            isHomeworkOverdue(raw, beijingNow),
            isFalse,
            reason: 'Invalid deadline $raw must never be treated as overdue',
          );
        }
      },
    );

    test('date-only today is urgent and exact tomorrow is upcoming', () {
      expect(
        homeworkDeadlineTint('2026-10-23', beijingNow),
        AppleDesign.statusDanger,
      );
      expect(
        homeworkDeadlineTint('2026-10-24 11:59:00', beijingNow),
        AppleDesign.statusDanger,
      );
      expect(
        homeworkDeadlineTint('2026-10-24 12:00:00', beijingNow),
        AppleDesign.statusPending,
      );
      expect(homeworkCompactDeadline('2026-10-23', beijingNow), contains('今天'));
      expect(
        homeworkCompactDeadline('2026-10-24', beijingNow),
        contains('10/24'),
      );
    });
  });

  group('TodayHomeworkSection & HomeworkPage Orthogonal Filtering', () {
    final syntheticItems = [
      // 1. Pending + Active
      const HomeworkItem(
        id: 'active-soon',
        courseName: '课程A',
        title: '活跃作业1',
        dueAt: '2026-10-23 18:00:00',
        status: HomeworkStatus.pending,
      ),
      // 2. Pending + Date-only Active (due today, currently noon)
      const HomeworkItem(
        id: 'active-date',
        courseName: '课程A',
        title: '活跃作业2',
        dueAt: '2026-10-23',
        status: HomeworkStatus.pending,
      ),
      // 3. Pending + Overdue
      const HomeworkItem(
        id: 'overdue-1',
        courseName: '课程B',
        title: '已截止作业1',
        dueAt: '2026-10-20 12:00:00',
        status: HomeworkStatus.pending,
      ),
      // 4. Pending + Overdue Date-only
      const HomeworkItem(
        id: 'overdue-date',
        courseName: '课程B',
        title: '已截止作业2',
        dueAt: '2026-10-22',
        status: HomeworkStatus.pending,
      ),
      // 5. Pending + Undated (retained, not overdue)
      const HomeworkItem(
        id: 'undated',
        courseName: '课程C',
        title: '无截止作业',
        status: HomeworkStatus.pending,
      ),
      // 6. Pending + Invalid Date (retained, not overdue)
      const HomeworkItem(
        id: 'invalid-due',
        courseName: '课程C',
        title: '非法日期作业',
        dueAt: '2026-02-30',
        status: HomeworkStatus.pending,
      ),
      // 7. Submitted
      const HomeworkItem(
        id: 'submitted-1',
        courseName: '课程D',
        title: '已提交作业',
        dueAt: '2026-10-20 12:00:00',
        status: HomeworkStatus.submitted,
      ),
      // 8. Unknown status
      const HomeworkItem(
        id: 'unknown-1',
        courseName: '课程E',
        title: '未知状态作业',
        dueAt: '2026-10-25 12:00:00',
        status: HomeworkStatus.unknown,
      ),
    ];

    testWidgets(
      'TodayHomeworkSection excludes overdue from pending list and shows overdue in summary',
      (tester) async {
        final section = RefreshSection<HomeworkResponse>()
          ..value = HomeworkResponse(
            termName: '2026秋',
            termCode: '2026-autumn',
            items: syntheticItems,
          );

        await tester.pumpWidget(
          CupertinoApp(
            home: SingleChildScrollView(
              child: TodayHomeworkSection(
                section: section,
                onRetry: () {},
                now: beijingNow,
              ),
            ),
          ),
        );

        // 4 pending non-overdue items: active-soon, active-date, undated, invalid-due
        expect(find.text('4 项作业待处理'), findsOneWidget);
        // Overdue count is 2 (overdue-1, overdue-date)
        // Unknown count is 1
        expect(find.text('1 项状态待确认 · 已截止 2 项'), findsOneWidget);

        // Active items must be displayed
        expect(find.text('活跃作业1'), findsOneWidget);
        expect(find.text('活跃作业2'), findsOneWidget);
        // Only take(3) are shown in items list:
        // active-soon (18:00), active-date (end of day), undated/invalid
        expect(
          find.byKey(const Key('today-homework-item-active-soon')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('today-homework-item-active-date')),
          findsOneWidget,
        );

        // Overdue items must NOT be displayed in today items list
        expect(
          find.byKey(const Key('today-homework-item-overdue-1')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('today-homework-item-overdue-date')),
          findsNothing,
        );

        // Submitted items must NOT be displayed
        expect(
          find.byKey(const Key('today-homework-item-submitted-1')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'HomeworkPage separates 待完成 and 已截止 with no overlap and matches summary counts',
      (tester) async {
        tester.view.physicalSize = const Size(430, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final gateway = FakeAcademicGateway(
          HomeworkResponse(
            termName: '2026秋',
            termCode: '2026-autumn',
            items: syntheticItems,
          ),
        );

        await tester.pumpWidget(
          ginkgoApp(
            home: HomeworkPage(fileActions: platformActions,service: gateway, now: beijingNow),
          ),
        );
        await tester.pumpAndSettle();

        // Check summary metric counts:
        // pending = 4 (active-soon, active-date, undated, invalid-due)
        // submitted = 1 (submitted-1)
        // overdue = 2 (overdue-1, overdue-date)
        // unknown = 1
        final pendingSummary = find.byKey(
          const ValueKey('homework-summary-待完成'),
        );
        expect(
          find.descendant(of: pendingSummary, matching: find.text('4')),
          findsOneWidget,
        );
        final submittedSummary = find.byKey(
          const ValueKey('homework-summary-已提交'),
        );
        expect(
          find.descendant(of: submittedSummary, matching: find.text('1')),
          findsOneWidget,
        );
        final overdueSummary = find.byKey(
          const ValueKey('homework-summary-已截止'),
        );
        expect(
          find.descendant(of: overdueSummary, matching: find.text('2')),
          findsOneWidget,
        );

        // Filter 0 (全部): all 8 items are visible
        expect(find.text('8 项作业'), findsOneWidget);

        // Switch to filter 1 (待完成)
        await tester.tap(find.byKey(const Key('homework-filter-pending')));
        await tester.pumpAndSettle();
        expect(find.text('4 项作业'), findsOneWidget);
        expect(find.text('活跃作业1'), findsOneWidget);
        expect(find.text('活跃作业2'), findsOneWidget);
        expect(find.text('无截止作业'), findsOneWidget);
        expect(find.text('非法日期作业'), findsOneWidget);
        // Overdue and submitted must be excluded from 待完成
        expect(find.text('已截止作业1'), findsNothing);
        expect(find.text('已截止作业2'), findsNothing);
        expect(find.text('已提交作业'), findsNothing);

        // Switch to filter 3 (已截止) via quickFilter pill
        await tester.tap(find.text('已截止 2'));
        await tester.pumpAndSettle();
        expect(find.text('2 项作业'), findsOneWidget);
        expect(find.text('已截止作业1'), findsOneWidget);
        expect(find.text('已截止作业2'), findsOneWidget);
        expect(find.text('活跃作业1'), findsNothing);

        // Switch to filter 2 (已提交)
        await tester.tap(find.byKey(const Key('homework-filter-submitted')));
        await tester.pumpAndSettle();
        expect(find.text('1 项作业'), findsOneWidget);
        expect(find.text('已提交作业'), findsOneWidget);
        expect(find.textContaining('已超期'), findsNothing);

        // Switch to filter 4 (待确认)
        await tester.tap(find.text('待确认 1'));
        await tester.pumpAndSettle();
        expect(find.text('1 项作业'), findsOneWidget);
        expect(find.text('未知状态作业'), findsOneWidget);
      },
    );

    testWidgets('HomeworkPage reports incomplete course roles', (tester) async {
      final gateway = FakeAcademicGateway(
        const HomeworkResponse(
          termName: '2026秋',
          termCode: '2026-autumn',
          items: [],
          rolesComplete: false,
        ),
      );
      await tester.pumpWidget(
        ginkgoApp(
          home: HomeworkPage(fileActions: platformActions,service: gateway, now: beijingNow),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('作业结果不完整'), findsOneWidget);
      expect(find.textContaining('课程身份未能全部核对'), findsOneWidget);
    });
  });
}
