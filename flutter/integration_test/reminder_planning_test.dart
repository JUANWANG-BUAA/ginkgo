import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ginkgo_mirror/application/reminder_planning.dart';
import 'package:ginkgo_mirror/infrastructure/native_reminder_planning.dart';
import 'package:ginkgo_mirror/src/rust/frb_generated.dart';

class _Planner with NativeReminderPlanning {}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => RustLib.init());

  testWidgets(
    'native reminder planner rejects contradictory assignment records',
    (tester) async {
      const pending = HomeworkReminderSeed(
        id: 'synthetic',
        dueAt: '2026-10-30T08:00:00+08:00',
        pending: true,
      );
      const submitted = HomeworkReminderSeed(
        id: 'synthetic',
        dueAt: '2026-10-30T08:00:00+08:00',
        pending: false,
      );
      final planner = _Planner();
      final now = DateTime.parse('2026-10-26T07:50:00+08:00')
          .millisecondsSinceEpoch;
      for (final records in [
        [pending, submitted],
        [submitted, pending],
      ]) {
        final result = planner.planCheckinHomeworkReminders(
          checkin: const [],
          homework: records,
          nowMillis: now,
        );
        expect(result.plans, isEmpty);
        expect(result.skipped, 1);
      }
      final identical = planner.planCheckinHomeworkReminders(
        checkin: const [],
        homework: const [pending, pending],
        nowMillis: now,
      );
      expect(identical.plans, hasLength(2));
      expect(identical.skipped, 0);
      const sameInstant = HomeworkReminderSeed(
        id: 'synthetic',
        dueAt: '2026-10-30T00:00:00Z',
        pending: true,
      );
      final equivalent = planner.planCheckinHomeworkReminders(
        checkin: const [],
        homework: const [pending, sameInstant],
        nowMillis: now,
      );
      expect(
        equivalent.plans.map((plan) => plan.key),
        orderedEquals(identical.plans.map((plan) => plan.key)),
      );
      expect(equivalent.skipped, 0);
    },
  );
}
