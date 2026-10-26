import '../reminder_rules.dart';
import 'contracts.dart';
import 'local_tasks.dart';

/// Typed, local-only business capability. No school payload or platform API.
abstract interface class ReminderPlanningGateway {
  Future<ExtendedReminderPlans> planReminders({
    required List<CourseReminderSeed> courses,
    required List<TaskReminderSeed> tasks,
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
