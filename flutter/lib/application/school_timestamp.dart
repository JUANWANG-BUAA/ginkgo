/// School wall-clock value for local validation and presentation.
/// The returned UTC container represents Beijing wall time, not an instant.
/// Unzoned upstream values already describe
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
