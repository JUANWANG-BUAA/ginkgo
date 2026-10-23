import 'package:flutter/cupertino.dart';

import 'apple_design.dart';
import 'application/contracts.dart';
import 'course_visibility.dart';
import 'school_timestamp.dart';
import 'today_time.dart';

/// The dashboard and full list use the same personal-course visibility policy.
List<HomeworkItem> personalHomeworkItems(
  Iterable<HomeworkItem> items,
  CourseVisibility? visibility,
) => items
    .where(
      (item) =>
          item.courseRole != 'assistant' &&
          !(visibility?.hidden('spoc', item.courseId ?? item.id) ?? false),
    )
    .toList(growable: false);

/// Orthogonal deadline status derived on the client; never mutates upstream
/// submission status (pending, submitted, unknown).
enum HomeworkDeadlineStatus {
  /// Clearly within deadline.
  active,

  /// Clearly past deadline (now >= deadline, or now >= next-day 00:00 for date-only).
  overdue,

  /// No deadline provided (null or empty string).
  undated,

  /// Malformed or unparseable deadline (e.g. invalid date 2026-02-30 or garbage string).
  invalid,
}

/// Classify a homework deadline against Beijing wall clock time.
///
/// Follows the specification in docs/NEXT-STAGE-PLAN-2026-10-23.md:
/// - Undated: null or empty
/// - Date-only YYYY-MM-DD: deadline is the end of that day (next-day 00:00:00 is exclusive upper bound)
/// - Exact timestamp: overdue when beijing_now >= deadline
/// - Invalid: malformed or impossible calendar date/time (kept distinct, never coerced to today or overdue)
HomeworkDeadlineStatus classifyHomeworkDeadline(
  String? dueAt, [
  DateTime? beijingNow,
]) {
  final text = dueAt?.trim() ?? '';
  if (text.isEmpty) return HomeworkDeadlineStatus.undated;

  final now = beijingNow ?? todaySchoolNow(DateTime.now());

  // 1. Strict YYYY-MM-DD date-only check
  final dateOnly = todayDate(text);
  if (dateOnly != null) {
    // Upper exclusive bound is next day 00:00:00 in Beijing time.
    final exclusiveUpperBound = dateOnly.add(const Duration(days: 1));
    return now.isBefore(exclusiveUpperBound)
        ? HomeworkDeadlineStatus.active
        : HomeworkDeadlineStatus.overdue;
  }

  // 2. Timestamp with time (HH:mm or HH:mm:ss with optional offset)
  final instant = parseSchoolTimestamp(text);
  if (instant != null) {
    // Exact deadline: overdue when now >= deadline.
    return now.isBefore(instant)
        ? HomeworkDeadlineStatus.active
        : HomeworkDeadlineStatus.overdue;
  }

  return HomeworkDeadlineStatus.invalid;
}

/// Helper to test if a deadline is strictly classified as overdue.
bool isHomeworkOverdue(String? dueAt, [DateTime? beijingNow]) =>
    classifyHomeworkDeadline(dueAt, beijingNow) == HomeworkDeadlineStatus.overdue;

/// Returns an intuitive relative deadline countdown with 00:00 midnight warning.
///
/// For example:
/// - "即周日晚前 · 还剩 2 天 12 小时" (when deadline is 00:00 on Monday)
/// - "还剩 2 天 5 小时"
/// - "还剩 45 分钟"
/// - "已超期 4 天"
String? homeworkRelativeDeadline(String? dueAt, [DateTime? beijingNow]) {
  final text = dueAt?.trim() ?? '';
  if (text.isEmpty) return null;

  final now = beijingNow ?? todaySchoolNow(DateTime.now());
  final status = classifyHomeworkDeadline(text, now);

  if (status == HomeworkDeadlineStatus.invalid ||
      status == HomeworkDeadlineStatus.undated) {
    return null;
  }

  const weekdays = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  final dateOnly = todayDate(text);
  if (dateOnly != null) {
    final exclusiveUpperBound = dateOnly.add(const Duration(days: 1));
    if (status == HomeworkDeadlineStatus.overdue) {
      final diff = now.difference(exclusiveUpperBound);
      final days = diff.inDays + 1;
      return '已超期 $days 天';
    } else {
      final diff = exclusiveUpperBound.difference(now);
      final days = diff.inDays;
      final hours = diff.inHours % 24;
      return days > 0
          ? (hours > 0 ? '还剩 $days 天 $hours 小时' : '还剩 $days 天')
          : '今天内截止（还剩 $hours 小时）';
    }
  }

  final instant = parseSchoolTimestamp(text);
  if (instant == null) return null;

  final isMidnight = instant.hour == 0 && instant.minute == 0;
  final midnightNote = isMidnight
      ? '即${weekdays[instant.subtract(const Duration(days: 1)).weekday]}晚前'
      : '';

  if (status == HomeworkDeadlineStatus.overdue) {
    final diff = now.difference(instant);
    final days = diff.inDays;
    final hours = diff.inHours;
    final overdueDesc = days > 0
        ? '已超期 $days 天'
        : (hours > 0 ? '已超期 $hours 小时' : '刚截止');
    return midnightNote.isNotEmpty ? '$midnightNote · $overdueDesc' : overdueDesc;
  } else {
    final diff = instant.difference(now);
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;
    final remaining = days > 0
        ? (hours > 0 ? '还剩 $days 天 $hours 小时' : '还剩 $days 天')
        : (hours > 0
            ? '还剩 $hours 小时${minutes > 0 ? ' $minutes 分' : ''}'
            : '还剩 ${diff.inMinutes.clamp(1, 60)} 分钟');
    return midnightNote.isNotEmpty ? '$midnightNote · $remaining' : remaining;
  }
}

/// Produces a strict single-line, unambiguous deadline string (under 22 chars).
///
/// For 00:00 midnight deadlines, converts to the practical deadline
/// (e.g. "周日晚 23:59 截止 · 剩 2天11时") to prevent confusion where students
/// assume the deadline is at the end of Monday rather than Sunday night.
String homeworkCompactDeadline(String? dueAt, [DateTime? beijingNow]) {
  final text = dueAt?.trim() ?? '';
  if (text.isEmpty) return '截止时间待确认';

  final now = beijingNow ?? todaySchoolNow(DateTime.now());
  final status = classifyHomeworkDeadline(text, now);

  if (status == HomeworkDeadlineStatus.invalid) {
    return '时间待确认 · $text';
  }

  const weekdays = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  final dateOnly = todayDate(text);
  if (dateOnly != null) {
    final exclusiveUpperBound = dateOnly.add(const Duration(days: 1));
    if (status == HomeworkDeadlineStatus.overdue) {
      final diff = now.difference(exclusiveUpperBound);
      final days = diff.inDays + 1;
      return '已截止 · 超期 $days 天';
    } else {
      final diff = exclusiveUpperBound.difference(now);
      final days = diff.inDays;
      final hours = diff.inHours % 24;
      final remaining = days > 0
          ? (hours > 0 ? '剩 ${days}天${hours}时' : '剩 $days 天')
          : '剩 $hours 小时';
      return '${dateOnly.month}/${dateOnly.day} 当天截止 · $remaining';
    }
  }

  final instant = parseSchoolTimestamp(text);
  if (instant == null) return text;

  if (status == HomeworkDeadlineStatus.overdue) {
    final diff = now.difference(instant);
    final days = diff.inDays;
    final hours = diff.inHours;
    final overdueDesc = days > 0
        ? '超期 $days 天'
        : (hours > 0 ? '超期 $hours 小时' : '刚截止');
    return '已截止 · $overdueDesc';
  }

  // Not overdue: active deadline
  final diff = instant.difference(now);
  final days = diff.inDays;
  final hours = diff.inHours % 24;
  final remaining = days > 0
      ? (hours > 0 ? '剩 ${days}天${hours}时' : '剩 $days 天')
      : (hours > 0
          ? '仅剩 $hours 小时'
          : '仅剩 ${diff.inMinutes.clamp(1, 60)} 分钟');

  // Check 00:00 midnight: "周X晚 23:59 截止"
  if (instant.hour == 0 && instant.minute == 0) {
    final prevDay = instant.subtract(const Duration(days: 1));
    final prevWeekday = weekdays[prevDay.weekday];
    return '$prevWeekday晚 23:59 截止 · $remaining';
  }

  // Exact daytime: e.g. "周一 18:00 截止 · 剩 2天"
  final weekday = weekdays[instant.weekday];
  final clock =
      '${instant.hour.toString().padLeft(2, '0')}:${instant.minute.toString().padLeft(2, '0')}';
  return '$weekday $clock 截止 · $remaining';
}

/// Color for the deadline status:
/// - Overdue -> statusDanger (red)
/// - Urgent (< 24 hours) -> statusDanger (red/alert)
/// - Pending / Active (>= 24 hours) -> statusPending (warm amber)
/// - Invalid / Undated -> statusUncertain (gray)
CupertinoDynamicColor homeworkDeadlineTint(
  String? dueAt, [
  DateTime? beijingNow,
]) {
  final text = dueAt?.trim() ?? '';
  if (text.isEmpty) return AppleDesign.statusUncertain;

  final now = beijingNow ?? todaySchoolNow(DateTime.now());
  final status = classifyHomeworkDeadline(text, now);

  if (status == HomeworkDeadlineStatus.overdue) {
    return AppleDesign.statusDanger;
  }
  if (status == HomeworkDeadlineStatus.invalid ||
      status == HomeworkDeadlineStatus.undated) {
    return AppleDesign.statusUncertain;
  }

  // Check if urgent (< 24 hours remaining)
  final instant = parseSchoolTimestamp(text);
  if (instant != null) {
    if (instant.difference(now).inHours < 24) {
      return AppleDesign.statusDanger;
    }
  }

  return AppleDesign.statusPending;
}
