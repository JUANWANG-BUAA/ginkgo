import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/refresh_section.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/shared/today_time.dart';

import 'today_action_row.dart';
import 'today_presentation.dart';

/// The sign-in state of today's courses.
///
/// Only the sessions that still need attention are listed; a confirmed
/// sign-in is not an action item. The status is written as a word, an icon
/// and a color, so it survives a grayscale screenshot.
class TodayCheckInSection extends StatelessWidget {
  const TodayCheckInSection({
    super.key,
    required this.section,
    required this.now,
    required this.onRetry,
    required this.onOpen,
  });

  final RefreshSection<CheckInResponse> section;
  final DateTime now;
  final VoidCallback onRetry;
  final VoidCallback onOpen;

  static List<CheckInCourse> pendingCourses(CheckInResponse? data) {
    final courses = data?.courses ?? const <CheckInCourse>[];
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
    final courses = pendingCourses(data);
    final pendingCount =
        data?.courses
            .where(
              (course) =>
                  course.status == CheckInStatus.notSigned ||
                  course.status == CheckInStatus.unknown,
            )
            .length ??
        0;
    if (data == null) {
      return TodayVisualSection(
        key: const Key('today-checkin'),
        header: const TodaySectionHeader(
          icon: CupertinoIcons.checkmark_seal,
          title: '课程签到',
        ),
        children: [
          SectionFeedback(
            loading: section.loading,
            label: '正在读取签到状态…',
            hasData: false,
            error: section.error,
            onRetry: onRetry,
          ),
        ],
      );
    }
    final signed = data.courses
        .where((course) => course.status == CheckInStatus.signed)
        .length;
    final date = todayDate(data.date);
    final today = DateTime.utc(now.year, now.month, now.day);
    final needsRefresh = data.stale || date == null || date != today;
    if (courses.isEmpty &&
        section.error == null &&
        !section.loading &&
        !needsRefresh) {
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
      footer: Text('签到状态来自学校系统 · ${data.date}'),
      children: [
        if (needsRefresh)
          TodayActionRow(
            title: '签到日期待更新',
            subtitle:
                '当前数据日期：${data.date.isEmpty ? '未提供' : data.date}，请刷新后确认今天的签到。',
            onTap: onRetry,
          ),
        if (section.error != null)
          SectionFeedback(
            loading: section.loading,
            label: '正在更新签到状态…',
            hasData: true,
            error: section.error,
            onRetry: onRetry,
          ),
        if (courses.isEmpty)
          TodayActionRow(
            title: data.courses.isEmpty
                ? (needsRefresh ? '该日期没有签到记录' : '今天没有可签到的课程')
                : '已确认 $signed/${data.courses.length} 场签到',
            subtitle: data.courses.isEmpty
                ? (needsRefresh ? '查看签到列表以核对日期。' : '课程开始后才会出现签到入口。')
                : '没有待签到的场次。',
            onTap: onOpen,
          )
        else
          for (final course in courses)
            TodayActionRow(
              key: Key('today-checkin-${course.id}'),
              title: course.courseName,
              subtitle: [
                course.beginsAt.isEmpty ? null : course.beginsAt,
                course.classroomName,
              ].whereType<String>().join(' · '),
              trailing: chip(course.status),
              onTap: onOpen,
            ),
        if (pendingCount > courses.length)
          TodayActionRow(
            summary: true,
            title: '另有 ${pendingCount - courses.length} 场待确认',
            onTap: onOpen,
          ),
      ],
    );
  }
}
