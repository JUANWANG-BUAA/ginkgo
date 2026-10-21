/// Presentation-only school time. Unzoned upstream values already describe
/// Beijing wall time; zoned instants are converted without the device timezone.
DateTime? parseSchoolTimestamp(String? value) {
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})(?::(\d{2})(?:\.\d{1,9})?)?(Z|[+-]\d{2}:?\d{2})?$',
  ).firstMatch(value?.trim() ?? '');
  if (match == null) return null;
  final year = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final day = int.parse(match[3]!);
  final hour = int.parse(match[4]!);
  final minute = int.parse(match[5]!);
  final second = int.parse(match[6] ?? '0');
  // DateTime.tryParse normalizes invalid dates such as February 30. Reject
  // those before parsing so unexpected upstream values remain visible as-is.
  final wall = DateTime.utc(year, month, day, hour, minute, second);
  if (wall.year != year ||
      wall.month != month ||
      wall.day != day ||
      hour > 23 ||
      minute > 59 ||
      second > 59) {
    return null;
  }
  if (match[7] == null) return wall;
  final instant = DateTime.tryParse(value!.trim());
  return instant?.toUtc().add(const Duration(hours: 8));
}

String _two(int value) => value.toString().padLeft(2, '0');
String _clock(DateTime value) => '${_two(value.hour)}:${_two(value.minute)}';
String _day(DateTime value) => '${_two(value.month)}月${_two(value.day)}日';
bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

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
