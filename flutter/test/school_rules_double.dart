import 'package:ginkgo_mirror/application/school_rules.dart';
import 'package:ginkgo_mirror/shared/reminder_rules.dart';
import 'package:ginkgo_mirror/shared/school_timestamp.dart';
import 'package:ginkgo_mirror/shared/today_time.dart';

/// The Dart stand-in for the domain rules.
///
/// The production implementations live in `ginkgo_domain` and run through the
/// bridge. Unit tests cannot load the native library, so they use this double,
/// which the shared rule tables pin against the domain implementation.
class DartSchoolRules implements SchoolRules {
  const DartSchoolRules();

  @override
  HomeworkDeadlineStatus homeworkDeadline(String? dueAt, DateTime now) {
    final text = dueAt?.trim() ?? '';
    if (text.isEmpty) return HomeworkDeadlineStatus.undated;

    // A date-only deadline lasts the whole school day: the exclusive upper
    // bound is the next midnight in Beijing, never the start of that day.
    final dateOnly = todayDate(text);
    if (dateOnly != null) {
      final exclusiveUpperBound = dateOnly.add(const Duration(days: 1));
      return now.isBefore(exclusiveUpperBound)
          ? HomeworkDeadlineStatus.active
          : HomeworkDeadlineStatus.overdue;
    }

    // An exact timestamp is overdue once Beijing passes it.
    final instant = parseSchoolTimestamp(text);
    if (instant != null) {
      return now.isBefore(instant)
          ? HomeworkDeadlineStatus.active
          : HomeworkDeadlineStatus.overdue;
    }

    // A malformed or impossible calendar date is not an expired deadline.
    return HomeworkDeadlineStatus.invalid;
  }

  @override
  bool checkinWindowOpen(
    String date,
    String beginsAt,
    String endsAt,
    DateTime now,
  ) {
    final start = schoolInstant(beginsAt, day: date);
    final end = schoolInstant(endsAt, day: date);
    if (start == null || end == null) return false;
    final schoolDay = _beijingDate(now);
    return schoolDay == date &&
        end.isAfter(start) &&
        _beijingDate(start) == date &&
        !now.isBefore(start.subtract(const Duration(minutes: 10))) &&
        now.isBefore(end);
  }
}

String _beijingDate(DateTime instant) => instant
    .toUtc()
    .add(const Duration(hours: 8))
    .toIso8601String()
    .substring(0, 10);
