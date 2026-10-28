import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/shared/checkin_sessions.dart';
import 'package:ginkgo_mirror/shared/school_timestamp.dart';

/// School wall-clock values are never interpreted in the device timezone.
DateTime? schoolInstant(String raw, {String? day}) {
  final text = RegExp(r'^\d{2}:\d{2}(:\d{2})?$').hasMatch(raw) && day != null
      ? '$day $raw'
      : raw;
  return parseSchoolTimestamp(text)?.subtract(const Duration(hours: 8));
}

String _beijingDate(DateTime instant) => instant
    .toUtc()
    .add(const Duration(hours: 8))
    .toIso8601String()
    .substring(0, 10);

bool checkinWindowOpen(CheckInCourse course, String day, DateTime now) {
  final start = schoolInstant(course.beginsAt, day: day);
  final end = schoolInstant(course.endsAt, day: day);
  final schoolDay = now
      .toUtc()
      .add(const Duration(hours: 8))
      .toIso8601String()
      .substring(0, 10);
  return schoolDay == day &&
      start != null &&
      end != null &&
      end.isAfter(start) &&
      _beijingDate(start) == day &&
      !now.isBefore(start.subtract(const Duration(minutes: 10))) &&
      now.isBefore(end);
}

class ReminderPlan {
  const ReminderPlan({
    required this.key,
    required this.group,
    required this.at,
    required this.expires,
  });
  final String key, group;
  final DateTime at, expires;
}

List<ReminderPlan> checkinReminders(CheckInResponse data) => [
  if (data.failure == null && !data.stale)
    for (final course in uniqueCheckinSessions(data.courses))
      if (course.status == CheckInStatus.notSigned &&
          !course.conflicting &&
          (course.signInAllowed ?? course.mergedRecordCount == 1))
        if (schoolInstant(course.beginsAt, day: data.date)
            case final DateTime start)
          if (schoolInstant(course.endsAt, day: data.date)
              case final DateTime end)
            if (end.isAfter(start) && _beijingDate(start) == data.date)
              ReminderPlan(
                key: 'checkin:${data.date}:${course.id}:$start',
                group: 'checkin',
                at: start.subtract(const Duration(minutes: 10)),
                expires: end,
              ),
];

List<ReminderPlan> homeworkReminders(
  Iterable<HomeworkItem> items,
  DateTime now,
) {
  final plans = <ReminderPlan>[];
  for (final item in items) {
    final due = item.dueAt == null ? null : schoolInstant(item.dueAt!);
    if (item.status != HomeworkStatus.pending ||
        due == null ||
        !due.isAfter(now)) {
      continue;
    }
    for (final hours in [48, 24]) {
      // On first discovery within 24h, do not fire both historical stages.
      final at = due.subtract(Duration(hours: hours));
      if (hours == 48 &&
          !now.isBefore(due.subtract(const Duration(hours: 24)))) {
        continue;
      }
      plans.add(
        ReminderPlan(
          key: 'homework:${item.id}:$due:$hours',
          group: 'homework',
          at: at,
          expires: due,
        ),
      );
    }
  }
  return plans;
}
