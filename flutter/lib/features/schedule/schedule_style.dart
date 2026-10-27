import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/shared/school_timestamp.dart';

const weekdayNames = schoolWeekdays;

/// Quiet secondary text used across the schedule surface.
TextStyle scheduleSecondary(BuildContext context) => TextStyle(
  fontSize: 14,
  color: CupertinoColors.secondaryLabel.resolveFrom(context),
);

Color courseColor(BuildContext context, String? value, [String name = '']) {
  if (value != null) {
    final hex = value.replaceFirst('#', '');
    if (hex.length == 6) {
      final parsed = int.tryParse(hex, radix: 16);
      if (parsed != null) return Color(0xFF000000 | parsed);
    }
  }
  const palette = [
    CupertinoColors.systemBlue,
    CupertinoColors.systemTeal,
    CupertinoColors.systemIndigo,
    CupertinoColors.systemOrange,
    CupertinoColors.systemPurple,
    CupertinoColors.systemPink,
    CupertinoColors.systemGreen,
    CupertinoColors.systemRed,
  ];
  var hash = 5381;
  for (final scalar in name.runes) {
    hash = ((hash * 33) + scalar) & 0x7fffffff;
  }
  return palette[hash % palette.length].resolveFrom(context);
}

String courseDetail(ScheduleCourse course) {
  final time = [
    if (course.startTime != null) course.startTime!,
    if (course.endTime != null) course.endTime!,
  ].join('–');
  final sections = '第 ${course.startSection}–${course.endSection} 节';
  final teacher = course.teacher == null ? '' : ' · ${course.teacher}';
  return time.isEmpty ? '$sections$teacher' : '$time · $sections$teacher';
}

String shortDate(String date) {
  final parsed = DateTime.tryParse(date);
  return parsed == null
      ? date
      : '${parsed.month.toString().padLeft(2, '0')}/${parsed.day.toString().padLeft(2, '0')}';
}

/// Column of today inside a week that starts on [weekStart], counting from 1.
///
/// Returns null when today is outside that week. The grid uses this to
/// highlight the current weekday.
int? scheduleTodayColumn(String? weekStart) {
  final start = DateTime.tryParse(weekStart ?? '');
  if (start == null) return null;
  final now = DateTime.now().toUtc().add(const Duration(hours: 8));
  final date = DateTime(start.year, start.month, start.day);
  final diff = DateTime(now.year, now.month, now.day).difference(date).inDays;
  return diff >= 0 && diff < 7 ? diff + 1 : null;
}

/// Title of one weekday inside a week, e.g. `周一 · 10/19 · 今天`.
///
/// [weekStart] is the first day of the week; without it only the weekday
/// name is shown.
String scheduleDayTitle(int day, String? weekStart) {
  final start = DateTime.tryParse(weekStart ?? '');
  final date = start?.add(Duration(days: day - 1));
  final now = DateTime.now().toUtc().add(const Duration(hours: 8));
  final today =
      date != null &&
      date.year == now.year &&
      date.month == now.month &&
      date.day == now.day;
  return '${weekdayNames[day - 1]}'
      '${date == null ? '' : ' · ${shortDate(date.toIso8601String())}'}'
      '${today ? ' · 今天' : ''}';
}
