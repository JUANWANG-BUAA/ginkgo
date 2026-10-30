import 'package:ginkgo_mirror/application/reminder_planning.dart';
import 'package:ginkgo_mirror/shared/reminder_rules.dart';

/// The Dart stand-in for the domain's check-in and assignment reminder rule.
///
/// The production rule lives in `ginkgo_domain::features::reminders` and runs
/// through the bridge. Unit tests cannot load the native library, so they use
/// this double — and the shared table `fixtures/rules/reminders-v1.json` pins
/// both against the same expectations, so the double cannot drift away from
/// the domain unnoticed.
class ReminderRuleDouble {
  const ReminderRuleDouble();

  ({List<ReminderPlan> plans, int skipped}) plan({
    required List<CheckInReminderSeed> checkin,
    required List<HomeworkReminderSeed> homework,
    required DateTime now,
  }) {
    final plans = <ReminderPlan>[];
    var skipped = 0;
    final seen = <String>{};
    for (final seed in checkin) {
      if (!seen.add(seed.id)) continue;
      final plan = _checkinPlan(seed, now);
      if (plan == null) {
        skipped++;
        continue;
      }
      plans.add(plan);
    }
    for (final seed in homework) {
      final candidates = _homeworkPlans(seed, now);
      if (candidates.isEmpty) {
        skipped++;
        continue;
      }
      plans.addAll(candidates);
    }
    plans.sort((a, b) {
      final byTime = a.at.compareTo(b.at);
      return byTime != 0 ? byTime : a.key.compareTo(b.key);
    });
    return (plans: plans, skipped: skipped);
  }

  ReminderPlan? _checkinPlan(CheckInReminderSeed seed, DateTime now) {
    if (!seed.notSigned || seed.conflicting) return null;
    // A merged session is only signable when the school says so.
    final allowed = seed.signInAllowed ?? seed.mergedRecordCount == 1;
    if (!allowed) return null;
    final start = schoolInstant(seed.beginsAt, day: seed.date);
    final end = schoolInstant(seed.endsAt, day: seed.date);
    if (start == null || end == null) return null;
    if (!end.isAfter(start) || !start.isAfter(now)) return null;
    // The session belongs to the queried day; a stale day never reminds.
    if (_beijingDate(start) != seed.date) return null;
    return ReminderPlan(
      key: 'checkin:${seed.date}:${seed.id.length}:${seed.id}:'
          '${start.millisecondsSinceEpoch}',
      group: 'checkin',
      at: start.subtract(const Duration(minutes: 10)),
      expires: end,
    );
  }

  List<ReminderPlan> _homeworkPlans(HomeworkReminderSeed seed, DateTime now) {
    if (!seed.pending) return const [];
    final due = schoolInstant(seed.dueAt);
    if (due == null || !due.isAfter(now)) return const [];
    final plans = <ReminderPlan>[];
    for (final hours in [48, 24]) {
      // Inside the last 24 hours only the close-in plan is new; the 48-hour
      // stage would fire for a moment that has already passed.
      if (hours == 48 && !now.isBefore(due.subtract(const Duration(hours: 24)))) {
        continue;
      }
      plans.add(
        ReminderPlan(
          key: 'homework:${seed.id.length}:${seed.id}:'
              '${due.millisecondsSinceEpoch}:$hours',
          group: 'homework',
          at: due.subtract(Duration(hours: hours)),
          expires: due,
        ),
      );
    }
    return plans;
  }
}

String _beijingDate(DateTime instant) => instant
    .toUtc()
    .add(const Duration(hours: 8))
    .toIso8601String()
    .substring(0, 10);
