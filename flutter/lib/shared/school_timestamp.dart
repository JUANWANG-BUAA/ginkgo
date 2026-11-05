import 'package:ginkgo_mirror/application/school_timestamp.dart';

export 'package:ginkgo_mirror/application/school_timestamp.dart'
    show parseSchoolTimestamp;

String _two(int value) => value.toString().padLeft(2, '0');
String _clock(DateTime value) => '${_two(value.hour)}:${_two(value.minute)}';
String _day(DateTime value) => '${_two(value.month)}月${_two(value.day)}日';
bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Weekday names indexed from Monday (`date.weekday - 1`).
const schoolWeekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

/// yyyy-MM-dd, the canonical query-date format the school systems accept.
String schoolDateString(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${_two(day.month)}-${_two(day.day)}';

/// yyyy年M月d日 · 周X, the dated heading shared by list pages.
String schoolDateWeekdayLabel(DateTime date) =>
    '${date.year}年${date.month}月${date.day}日 · ${schoolWeekdays[date.weekday - 1]}';

/// MM月dd日 HH:mm in Beijing, with unknown and invalid inputs kept distinct.
String schoolTimestampLabel(String? value) {
  if (value == null || value.trim().isEmpty) return '未确认';
  final date = parseSchoolTimestamp(value);
  return date == null ? value : '${_day(date)} ${_clock(date)}';
}

String schoolClockLabel(String? value) {
  if (value == null || value.trim().isEmpty) return '未确认';
  final date = parseSchoolTimestamp(value);
  return date == null ? value : _clock(date);
}

/// The page already labels the course day. Keep that day's times compact;
/// crossing midnight includes both dates, and crossing years includes years.
/// An unrecognized endpoint retains the full original range for inspection.
String schoolTimeRange(String beginsAt, String endsAt) {
  final start = parseSchoolTimestamp(beginsAt);
  final end = parseSchoolTimestamp(endsAt);
  if (start == null || end == null) return '$beginsAt–$endsAt';
  if (_sameDay(start, end)) return '${_clock(start)}–${_clock(end)}';
  final differentYears = start.year != end.year;
  String dated(DateTime date) =>
      '${differentYears ? '${date.year}年' : ''}${_day(date)} ${_clock(date)}';
  return '${dated(start)}–${dated(end)}';
}
