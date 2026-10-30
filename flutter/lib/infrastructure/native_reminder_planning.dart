import '../application/reminder_planning.dart';


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

  @override
  ExtendedReminderPlans planCheckinHomeworkReminders({
    required List<CheckInReminderSeed> checkin,
    required List<HomeworkReminderSeed> homework,
    required int nowMillis,
  }) {
    final response = native.planCheckinHomeworkReminders(
      checkin: [
        for (final value in checkin)
          native.CheckInReminderSeed(
            id: value.id,
            date: value.date,
            beginsAt: value.beginsAt,
            endsAt: value.endsAt,
            notSigned: value.notSigned,
            conflicting: value.conflicting,
            signInAllowed: value.signInAllowed,
            mergedRecordCount: value.mergedRecordCount,
          ),
      ],
      homework: [
        for (final value in homework)
          native.HomeworkReminderSeed(
            id: value.id,
            dueAt: value.dueAt,
            pending: value.pending,
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
