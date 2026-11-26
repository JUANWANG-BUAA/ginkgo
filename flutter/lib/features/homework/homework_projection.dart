import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/school_rules.dart';

import 'package:ginkgo_mirror/design/apple_design.dart';
export 'package:ginkgo_mirror/shared/homework_visibility.dart';
import 'package:ginkgo_mirror/shared/school_timestamp.dart';
import 'package:ginkgo_mirror/shared/today_time.dart';

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
]) => schoolRules.homeworkDeadline(
  dueAt,
  beijingNow ?? todaySchoolNow(DateTime.now()),
);

/// Helper to test if a deadline is strictly classified as overdue.
bool isHomeworkOverdue(String? dueAt, [DateTime? beijingNow]) =>
    classifyHomeworkDeadline(dueAt, beijingNow) ==
    HomeworkDeadlineStatus.overdue;

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
      ? '即${schoolWeekdays[instant.subtract(const Duration(days: 1)).weekday - 1]}晚前'
      : '';

  if (status == HomeworkDeadlineStatus.overdue) {
    final diff = now.difference(instant);
    final days = diff.inDays;
    final hours = diff.inHours;
    final overdueDesc = days > 0
        ? '已超期 $days 天'
        : (hours > 0 ? '已超期 $hours 小时' : '刚截止');
    return midnightNote.isNotEmpty
        ? '$midnightNote · $overdueDesc'
        : overdueDesc;
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
          ? (hours > 0 ? '剩 $days天$hours时' : '剩 $days 天')
          : '剩 $hours 小时';
      final isToday =
          dateOnly.year == now.year &&
          dateOnly.month == now.month &&
          dateOnly.day == now.day;
      return isToday
          ? '今天截止 · $remaining'
          : '${dateOnly.month}/${dateOnly.day} 当天截止 · $remaining';
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
      ? (hours > 0 ? '剩 $days天$hours时' : '剩 $days 天')
      : (hours > 0 ? '仅剩 $hours 小时' : '仅剩 ${diff.inMinutes.clamp(1, 60)} 分钟');

  // Check 00:00 midnight: "周X晚 23:59 截止"
  if (instant.hour == 0 && instant.minute == 0) {
    final prevDay = instant.subtract(const Duration(days: 1));
    final prevWeekday = schoolWeekdays[prevDay.weekday - 1];
    return '$prevWeekday晚 23:59 截止 · $remaining';
  }

  // Exact daytime: e.g. "周一 18:00 截止 · 剩 2天"
  final weekday = schoolWeekdays[instant.weekday - 1];
  final clock =
      '${instant.hour.toString().padLeft(2, '0')}:${instant.minute.toString().padLeft(2, '0')}';
  return '$weekday $clock 截止 · $remaining';
}

/// Crisp short countdown label for a status pill (e.g. "剩 35 天", "仅剩 6 小时",
/// "今天截止", "已超期 2 天").
String homeworkCountdownBadge(String? dueAt, [DateTime? beijingNow]) {
  final text = dueAt?.trim() ?? '';
  if (text.isEmpty) return '截止待确认';
  final now = beijingNow ?? todaySchoolNow(DateTime.now());
  final status = classifyHomeworkDeadline(text, now);
  if (status == HomeworkDeadlineStatus.invalid ||
      status == HomeworkDeadlineStatus.undated) {
    return '时间待确认';
  }
  final dateOnly = todayDate(text);
  if (dateOnly != null) {
    final bound = dateOnly.add(const Duration(days: 1));
    if (status == HomeworkDeadlineStatus.overdue) {
      return '已超期 ${now.difference(bound).inDays + 1} 天';
    }
    final diff = bound.difference(now);
    if (diff.inDays > 0) return '剩 ${diff.inDays} 天';
    return '今天截止';
  }
  final instant = parseSchoolTimestamp(text);
  if (instant == null) return '时间待确认';
  if (status == HomeworkDeadlineStatus.overdue) {
    final diff = now.difference(instant);
    if (diff.inDays > 0) return '已超期 ${diff.inDays} 天';
    if (diff.inHours > 0) return '已超期 ${diff.inHours} 小时';
    return '刚截止';
  }
  final diff = instant.difference(now);
  final days = diff.inDays;
  final hours = diff.inHours % 24;
  if (days >= 7) return '剩 $days 天';
  if (days > 0) return hours > 0 ? '剩 $days天$hours时' : '剩 $days 天';
  if (hours > 0) return '仅剩 $hours 小时';
  return '仅剩 ${diff.inMinutes.clamp(1, 60)} 分钟';
}

/// Concise clock/date deadline string paired next to [homeworkCountdownBadge].
String? homeworkDueSummary(String? dueAt, [DateTime? beijingNow]) {
  final text = dueAt?.trim() ?? '';
  if (text.isEmpty) return null;
  final now = beijingNow ?? todaySchoolNow(DateTime.now());
  final status = classifyHomeworkDeadline(text, now);
  if (status == HomeworkDeadlineStatus.invalid ||
      status == HomeworkDeadlineStatus.undated) {
    return null;
  }
  final dateOnly = todayDate(text);
  if (dateOnly != null) {
    return '${dateOnly.month}月${dateOnly.day}日截止';
  }
  final instant = parseSchoolTimestamp(text);
  if (instant == null) return null;
  if (instant.hour == 0 && instant.minute == 0) {
    final prev = instant.subtract(const Duration(days: 1));
    final weekday = schoolWeekdays[prev.weekday - 1];
    return '${prev.month}月${prev.day}日 $weekday晚 23:59';
  }
  final weekday = schoolWeekdays[instant.weekday - 1];
  final clock =
      '${instant.hour.toString().padLeft(2, '0')}:${instant.minute.toString().padLeft(2, '0')}';
  return '${instant.month}月${instant.day}日 $weekday $clock';
}

/// Color for the deadline status:
/// - Overdue -> statusDanger (red)
/// - Urgent (< 24 hours) -> statusDanger (red/alert)
/// - Soon (1–7 days) -> statusPending (warm amber)
/// - Calm (> 7 days) -> accent (calm brand green)
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

  final effectiveDue = todayDue(text);
  if (effectiveDue != null) {
    final remainingHours = effectiveDue.difference(now).inHours;
    if (remainingHours < 24) return AppleDesign.statusDanger;
    if (remainingHours >= 24 * 7) return AppleDesign.accent;
  }

  return AppleDesign.statusPending;
}
