import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/reminder_planning.dart';

/// A failed group is absent, while a successful empty group removes old plans.
class BackgroundReminderBatch {
  const BackgroundReminderBatch(this.groups, this.plans);
  final Set<String> groups;
  final List<Map<String, Object>> plans;
}

BackgroundReminderBatch backgroundReminderBatch({
  required String account,
  required String expectedOwner,
  required CheckInResponse? checkin,
  required HomeworkResponse? homework,
  required ReminderPlanningGateway planner,
  required int nowMillis,
  required bool Function(HomeworkItem) personalHomework,
}) {
  final owner = md5.convert(utf8.encode('$account:background')).toString();
  if (owner != expectedOwner) throw StateError('Background account changed');
  final groups = <String>{};
  final plans = <ReminderPlan>[];
  if (checkin != null && checkin.failure == null && !checkin.stale) {
    final result = planner.planCheckinHomeworkReminders(
      checkin: checkinReminderSeeds(checkin.date, checkin.courses),
      homework: const [],
      nowMillis: nowMillis,
    );
    if (!result.unsupported) {
      groups.add('checkin');
      plans.addAll(result.plans);
    }
  }
  if (homework != null && homework.failure == null) {
    final result = planner.planCheckinHomeworkReminders(
      checkin: const [],
      homework: homeworkReminderSeeds(homework.items.where(personalHomework)),
      nowMillis: nowMillis,
    );
    if (!result.unsupported) {
      groups.add('homework');
      plans.addAll(result.plans);
    }
  }
  plans.sort((a, b) => a.at.compareTo(b.at));
  return BackgroundReminderBatch(groups, [
    for (final plan
        in plans
            .where((p) => p.expires.millisecondsSinceEpoch > nowMillis)
            .take(60))
      {
        'key': sha256.convert(utf8.encode('$account:${plan.key}')).toString(),
        'group': plan.group,
        'at': plan.at.millisecondsSinceEpoch,
        'expires': plan.expires.millisecondsSinceEpoch,
      },
  ]);
}
