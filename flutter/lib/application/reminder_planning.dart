import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/local_tasks.dart';

/// One scheduled reminder. The domain decides when a reminder is due; this
/// value only carries that decision to the platform.
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

/// Typed, local-only business capability. No school payload or platform API.
abstract interface class ReminderPlanningGateway {
  Future<ExtendedReminderPlans> planReminders({
    required List<CourseReminderSeed> courses,
    required List<TaskReminderSeed> tasks,
    required int nowMillis,
  });

  /// Plans the check-in and assignment reminders. The rule lives in the
  /// domain: the page hands over the sessions and deadlines and receives the
  /// plans back, so no second implementation decides when to remind.
  ExtendedReminderPlans planCheckinHomeworkReminders({
    required List<CheckInReminderSeed> checkin,
    required List<HomeworkReminderSeed> homework,
    required int nowMillis,
  });
}

class CourseReminderSeed {
  const CourseReminderSeed({
    required this.id,
    required this.weekStart,
    required this.day,
    required this.startsAt,
    required this.endsAt,
  });
  final String id, weekStart, startsAt, endsAt;
  final int day;
}

class TaskReminderSeed {
  const TaskReminderSeed({
    required this.id,
    required this.due,
    required this.completed,
  });
  final String id, due;
  final bool completed;
}

class ExtendedReminderPlans {
  ExtendedReminderPlans({
    required Iterable<ReminderPlan> plans,
    this.skipped = 0,
    this.unsupported = false,
  }) : plans = List.unmodifiable(plans);
  final List<ReminderPlan> plans;
  final int skipped;
  final bool unsupported;
}

List<CourseReminderSeed> courseReminderSeeds(ScheduleResponse data) {
  final weeks = data.weeks.where((week) => week.number == data.weekNumber);
  if (weeks.length != 1) throw const FormatException('课程周次无法确认');
  final start = weeks.single.startDate;
  return [
    for (final course in data.courses)
      CourseReminderSeed(
        id: course.id,
        weekStart: start,
        day: course.day,
        startsAt: course.startTime ?? '',
        endsAt: course.endTime ?? '',
      ),
  ];
}

List<TaskReminderSeed> taskReminderSeeds(Iterable<LocalTaskRecord> data) => [
  for (final task in data)
    TaskReminderSeed(id: task.id, due: task.due, completed: task.completed),
];

/// The check-in sessions of one queried day. The domain decides which of them
/// still need a reminder; duplicate sessions collapse there.
List<CheckInReminderSeed> checkinReminderSeeds(
  String date,
  Iterable<CheckInCourse> courses,
) => [
  for (final course in courses)
    CheckInReminderSeed(
      id: course.id,
      date: date,
      beginsAt: course.beginsAt,
      endsAt: course.endsAt,
      notSigned: course.status == CheckInStatus.notSigned,
      conflicting: course.conflicting,
      signInAllowed: course.signInAllowed,
      mergedRecordCount: course.mergedRecordCount,
    ),
];

/// The assignments whose deadline may still be pending.
List<HomeworkReminderSeed> homeworkReminderSeeds(
  Iterable<HomeworkItem> items,
) => [
  for (final item in items)
    HomeworkReminderSeed(
      id: item.id,
      dueAt: item.dueAt ?? '',
      pending: item.status == HomeworkStatus.pending,
    ),
];

/// A check-in session that may still need a reminder.
class CheckInReminderSeed {
  const CheckInReminderSeed({
    required this.id,
    required this.date,
    required this.beginsAt,
    required this.endsAt,
    required this.notSigned,
    required this.conflicting,
    required this.mergedRecordCount,
    this.signInAllowed,
  });
  final String id, date, beginsAt, endsAt;

  /// True only when the session is exactly "not signed".
  final bool notSigned;

  /// A conflicting session never reminds.
  final bool conflicting;

  /// Explicit false covers merged sessions with conflicting records.
  final bool? signInAllowed;
  final int mergedRecordCount;
}

/// A school assignment that may still need a deadline reminder.
class HomeworkReminderSeed {
  const HomeworkReminderSeed({
    required this.id,
    required this.dueAt,
    required this.pending,
  });
  final String id, dueAt;
  final bool pending;
}
