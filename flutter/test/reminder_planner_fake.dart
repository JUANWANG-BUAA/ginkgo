import 'dart:async';

import 'package:ginkgo_mirror/application/reminder_planning.dart';

import 'reminder_rule_double.dart';

/// A planner double for the unit tests.
///
/// The check-in and assignment rule lives in the domain and runs through the
/// bridge; unit tests cannot load the native library, so they use the double
/// that the shared table `fixtures/rules/reminders-v1.json` pins against the
/// domain implementation.
class Planner implements ReminderPlanningGateway {
  List<CourseReminderSeed> courses = [];
  List<TaskReminderSeed> tasks = [];
  List<CheckInReminderSeed> checkin = [];
  List<HomeworkReminderSeed> homework = [];
  ExtendedReminderPlans result = ExtendedReminderPlans(plans: []);
  Completer<ExtendedReminderPlans>? pending;
  @override
  Future<ExtendedReminderPlans> planReminders({
    required List<CourseReminderSeed> courses,
    required List<TaskReminderSeed> tasks,
    required int nowMillis,
  }) async {
    this.courses = courses;
    this.tasks = tasks;
    return pending?.future ?? result;
  }

  @override
  ExtendedReminderPlans planCheckinHomeworkReminders({
    required List<CheckInReminderSeed> checkin,
    required List<HomeworkReminderSeed> homework,
    required int nowMillis,
  }) {
    this.checkin = checkin;
    this.homework = homework;
    final planned = const ReminderRuleDouble().plan(
      checkin: checkin,
      homework: homework,
      now: DateTime.fromMillisecondsSinceEpoch(nowMillis, isUtc: true),
    );
    return ExtendedReminderPlans(
      plans: planned.plans,
      skipped: planned.skipped,
    );
  }
}
