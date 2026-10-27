import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/shared/today_time.dart';

import 'today_action_row.dart';
import 'today_presentation.dart';

/// Presentation-only interpretation of the existing Today clock range.
/// Invalid/absent clocks are unknown, never silently midnight.
class TodayCourseWindow {
  const TodayCourseWindow(this.starts, this.ends);
  final DateTime starts, ends;

  static TodayCourseWindow? parse(String date, String? time) {
    final day = todayDate(date);
    final match = RegExp(r'^(\d{1,2}):(\d{2})\s*[-–—~～]\s*(\d{1,2}):(\d{2})$')
        .firstMatch(time?.trim() ?? '');
    if (day == null || match == null) return null;
    final parts = [for (var i = 1; i <= 4; i++) int.parse(match[i]!)];
    if (parts[0] > 23 || parts[2] > 23 || parts[1] > 59 || parts[3] > 59) {
      return null;
    }
    final start = day.add(Duration(hours: parts[0], minutes: parts[1]));
    var end = day.add(Duration(hours: parts[2], minutes: parts[3]));
    if (end == start) return null;
    if (end.isBefore(start)) end = end.add(const Duration(days: 1));
    return TodayCourseWindow(start, end);
  }

  String status(DateTime now) => now.isBefore(starts)
      ? '尚未开始'
      : now.isBefore(ends)
      ? '正在上课'
      : '已结束';
}

class TodayCourseFocus extends StatelessWidget {
  const TodayCourseFocus({
    super.key,
    required this.data,
    required this.now,
    this.onOpen,
    this.stale = false,
  });
  final TodayResponse data;
  final DateTime now;
  final VoidCallback? onOpen;
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final dated = todayDate(data.date);
    if (dated == null || DateTime.utc(now.year, now.month, now.day) != dated) {
      return TodayActionRow(
        title: '请确认今天的课表',
        subtitle: '当前数据日期：${data.date}，刷新后再确认安排。',
        status: '课表日期待更新',
        onTap: onOpen,
      );
    }
    final known = <(TodayCourse, TodayCourseWindow)>[];
    for (final course in data.courses) {
      final window = TodayCourseWindow.parse(data.date, course.time);
      if (window != null) known.add((course, window));
    }
    known.sort((a, b) => a.$2.starts.compareTo(b.$2.starts));
    final ongoing = known.where(
      (e) => !now.isBefore(e.$2.starts) && now.isBefore(e.$2.ends),
    );
    final future = known.where((e) => now.isBefore(e.$2.starts));
    final focus = ongoing.isNotEmpty
        ? ongoing.first
        : future.isNotEmpty
        ? future.first
        : null;
    if (focus == null) {
      final unknown = known.length != data.courses.length;
      return TodayActionRow(
        title: unknown ? '部分课程时间待确认' : '今天的课程已结束',
        subtitle: unknown ? '请查看下方课程或完整课表，不据此判断空闲。' : '可以安排自己的学习与休息。',
        status: stale ? '上次课表 · 请刷新确认' : '接下来',
        onTap: onOpen,
      );
    }
    final (course, window) = focus;
    final running = !now.isBefore(window.starts);
    final minutes =
        ((running ? window.ends : window.starts).difference(now).inSeconds / 60)
            .ceil();
    return TodayActionRow(
      key: const Key('today-course-focus'),
      emphasized: true,
      status:
          '${stale ? '上次课表 · ' : ''}${running ? '正在上课 · 约 $minutes 分钟后结束' : '下一节课 · $minutes 分钟后开始'}',
      title: course.name,
      subtitle:
          '${course.time ?? '时间待确认'}\n${todayCoursePlaceLabel(course.place)}',
      onTap: onOpen,
    );
  }
}
