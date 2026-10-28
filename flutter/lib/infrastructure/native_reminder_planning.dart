import '../application/reminder_planning.dart';

import 'package:ginkgo_mirror/shared/reminder_rules.dart';

import '../src/rust/api/reminder_planning.dart' as native;

/// Pure Rust command; does not initialize the network runtime.
mixin NativeReminderPlanning implements ReminderPlanningGateway {
  @override
  Future<ExtendedReminderPlans> planReminders({
    required List<CourseReminderSeed> courses,
    required List<TaskReminderSeed> tasks,
    required int nowMillis,
  }) async {
    final response = native.planCourseTaskReminders(
      courses: [
        for (final value in courses)
          native.CourseReminderSeed(
            id: value.id,
            weekStart: value.weekStart,
            day: value.day,
            startsAt: value.startsAt,
            endsAt: value.endsAt,
          ),
      ],
      tasks: [
        for (final value in tasks)
          native.TaskReminderSeed(
            id: value.id,
            due: value.due,
            completed: value.completed,
          ),
      ],
      nowMillis: nowMillis,
    );
    return ExtendedReminderPlans(
      plans: [
        for (final value in response.plans)
          ReminderPlan(
            key: value.key,
            group: value.group,
            at: DateTime.fromMillisecondsSinceEpoch(
              value.atMillis.toInt(),
              isUtc: true,
            ),
            expires: DateTime.fromMillisecondsSinceEpoch(
              value.expiresMillis.toInt(),
              isUtc: true,
            ),
          ),
      ],
      skipped: response.skipped,
      unsupported: response.unsupported,
    );
  }
}
