import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/refresh_section.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/shared/checkin_visibility.dart';
import 'package:ginkgo_mirror/shared/course_visibility.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/shared/today_time.dart';

import 'today_action_row.dart';
import 'today_presentation.dart';

/// The sign-in state of today's courses.
///
/// When today's timetable already renders student courses, matching check-in
/// entries are fused directly into [TodayCourseSection] to avoid duplicate
/// cards. This standalone section only appears when check-in is shown on its
/// own (stale snapshot, unmatched pending session, or standalone view).
class TodayCheckInSection extends StatelessWidget {
  const TodayCheckInSection({
    super.key,
    required this.section,
    required this.now,
    required this.onRetry,
    required this.onOpen,
    this.hasCoursesToday = true,
    this.todaySchedule,
    this.homework,
    this.handledByCourses = false,
    this.fusedCourseIds = const {},
  });

  final RefreshSection<CheckInResponse> section;
  final DateTime now;
  final VoidCallback onRetry;
  final VoidCallback onOpen;
  final bool hasCoursesToday;
  final TodayResponse? todaySchedule;
  final HomeworkResponse? homework;
  final bool handledByCourses;
  final Set<String> fusedCourseIds;

  static List<CheckInCourse> personalCourses(
    CheckInResponse? data, {
    CourseVisibility? visibility,
    HomeworkResponse? homework,
    TodayResponse? todaySchedule,
  }) => personalCheckInCourses(
    data?.courses ?? const <CheckInCourse>[],
    visibility: visibility,
    homework: homework,
    todaySchedule: todaySchedule,
    checkinDate: data?.date,
  );

  static List<CheckInCourse> pendingCourses(
    CheckInResponse? data, {
    CourseVisibility? visibility,
    HomeworkResponse? homework,
    TodayResponse? todaySchedule,
  }) {
    final courses = personalCourses(
      data,
      visibility: visibility,
      homework: homework,
      todaySchedule: todaySchedule,
    );
    final pending = courses
        .where(
          (course) =>
              course.status == CheckInStatus.notSigned ||
              course.status == CheckInStatus.unknown,
        )
        .toList();
    return pending.take(3).toList(growable: false);
  }

  static StatusChip chip(CheckInStatus status) => switch (status) {
    CheckInStatus.signed => const StatusChip.done('已签到'),
    CheckInStatus.notSigned => const StatusChip.pending('未签到'),
    CheckInStatus.unknown => const StatusChip.unknown('待确认'),
  };

  @override
  Widget build(BuildContext context) {
    final data = section.value;
    final visibility = CourseVisibilityScope.of(context);
    final error = switch (section.failure) {
      FailureCode.moduleAuthRequired => '签到服务认证未完成',
      _ when data == null && section.error != null => '签到状态暂时无法读取',
      _ => section.error,
    };
    final visibleCourses = personalCourses(
      data,
      visibility: visibility,
      homework: homework,
      todaySchedule: todaySchedule,
    );
    final unfusedPending = visibleCourses
        .where(
          (course) =>
              !fusedCourseIds.contains(course.id) &&
              (course.status == CheckInStatus.notSigned ||
                  course.status == CheckInStatus.unknown),
        )
        .toList(growable: false);
    final courses = unfusedPending.take(3).toList(growable: false);
    final pendingCount = unfusedPending.length;
    if (data == null) {
      if (handledByCourses) return const SizedBox.shrink();
      if (error == null && !hasCoursesToday) {
        return const SizedBox.shrink();
      }
      return TodayVisualSection(
        key: const Key('today-checkin'),
        header: const TodaySectionHeader(
          icon: CupertinoIcons.checkmark_seal,
          title: '课程签到',
        ),
        children: [
          if (!section.loading && error == null)
            TodayActionRow(title: '查看课程签到', onTap: onRetry)
          else
            SectionFeedback(
              loading: section.loading,
              label: '正在读取签到状态…',
              hasData: false,
              error: error,
              onRetry: onRetry,
            ),
        ],
      );
    }
    final signed = visibleCourses
        .where((course) => course.status == CheckInStatus.signed)
        .length;
    final date = todayDate(data.date);
    final today = DateTime.utc(now.year, now.month, now.day);
    final needsRefresh = data.stale || date == null || date != today;
    if (courses.isEmpty && (handledByCourses ? !needsRefresh : (error == null && !needsRefresh))) {
      return const SizedBox.shrink();
    }
    return TodayVisualSection(
      key: const Key('today-checkin'),
      header: TodaySectionHeader(
        icon: CupertinoIcons.checkmark_seal,
        title: '课程签到',
        actionLabel: '全部',
        onAction: onOpen,
      ),
      children: [
        if (needsRefresh)
          TodayActionRow(
            title: '签到日期待更新',
            subtitle:
                '当前数据日期：${data.date.isEmpty ? '未提供' : data.date}，请刷新后确认今天的签到。',
            onTap: section.loading || error != null ? null : onRetry,
          ),
        if ((section.loading || error != null) && !handledByCourses)
          SectionFeedback(
            loading: section.loading,
            label: '正在更新签到状态…',
            hasData: true,
            quietWhenRefreshing: true,
            error: error,
            onRetry: onRetry,
          ),
        if (courses.isEmpty)
          TodayActionRow(
            title: visibleCourses.isEmpty
                ? '上次读取没有签到记录'
                : '上次读取：$signed/${visibleCourses.length} 场已签到',
            subtitle: '当前签到状态仍待确认。',
            onTap: onOpen,
          )
        else
          for (final (index, course) in courses.indexed) ...[
            if (index > 0 || needsRefresh) const TodayVisualDivider(),
            GinkgoProgressiveRow(
              key: Key('today-checkin-${course.id}'),
              emphasized: index == 0,
              title: course.courseName,
              subtitle: [
                course.beginsAt.isEmpty ? null : course.beginsAt,
                course.classroomName,
              ].whereType<String>().join(' · '),
              badgeLabel: course.status == CheckInStatus.unknown
                  ? '待确认'
                  : '未签到',
              badgeIcon: course.status == CheckInStatus.unknown
                  ? CupertinoIcons.question_circle_fill
                  : CupertinoIcons.qrcode,
              accent: course.status == CheckInStatus.unknown
                  ? AppleDesign.statusUncertain
                  : AppleDesign.statusPending,
              onTap: onOpen,
            ),
          ],
        if (pendingCount > courses.length) ...[
          const TodayVisualDivider(),
          TodayActionRow(
            summary: true,
            title: '另有 ${pendingCount - courses.length} 场待确认',
            onTap: onOpen,
          ),
        ],
      ],
    );
  }
}
