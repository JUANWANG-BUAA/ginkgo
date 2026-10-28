import 'package:ginkgo_mirror/shared/school_timestamp.dart';

/// UTC-shaped Beijing wall time; independent of the device timezone.
DateTime todaySchoolNow(DateTime instant) =>
    instant.toUtc().add(const Duration(hours: 8));

DateTime? todayDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
  final parsed = DateTime.tryParse(
    '$value'
    'T00:00:00Z',
  );
  if (parsed == null || parsed.toIso8601String().substring(0, 10) != value) {
    return null;
  }
  return parsed;
}

/// Presentation ordering and urgency only; never schedule an alarm from the
/// end-of-day value assigned to a date-only deadline.
DateTime? todayDue(String? value) {
  final text = value?.trim() ?? '';
  final day = todayDate(text);
  // A date-only task remains due throughout that school day; do not invent a
  // midnight deadline, which would incorrectly mark it overdue in the morning.
  return day
          ?.add(const Duration(days: 1))
          .subtract(const Duration(microseconds: 1)) ??
      parseSchoolTimestamp(text);
}

int todayCompareDue(String? a, String? b) {
  final left = todayDue(a), right = todayDue(b);
  if (left == null) return right == null ? 0 : 1;
  if (right == null) return -1;
  return left.compareTo(right);
}

String todayDueLabel(String? value, DateTime now, {bool localTask = false}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return localTask ? '无截止时间' : '截止时间待确认';
  final due = todayDue(text);
  if (due == null) return '截止时间待确认 · $text';
  final day = DateTime.utc(now.year, now.month, now.day);
  final dueDay = DateTime.utc(due.year, due.month, due.day);
  final days = dueDay.difference(day).inDays;
  final dateOnly = todayDate(text) != null;
  final when = days == 0
      ? '今天'
      : days == 1
      ? '明天'
      : '${due.month}月${due.day}日';
  final clock = dateOnly
      ? '（日期）'
      : ' ${due.hour.toString().padLeft(2, '0')}:${due.minute.toString().padLeft(2, '0')}';
  return '${(!due.isAfter(now)) ? '已截止' : '截止'} $when$clock';
}
