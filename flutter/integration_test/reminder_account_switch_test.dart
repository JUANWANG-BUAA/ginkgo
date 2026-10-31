import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/reminder_planning.dart';
import 'package:ginkgo_mirror/infrastructure/native_reminder_platform.dart';
import 'package:ginkgo_mirror/infrastructure/serial_reminder_platform.dart';
import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/shared/reminder_controller.dart';

class _Service extends Fake implements MirrorService {
  @override
  bool get isDemo => false;
}

class _Planner implements ReminderPlanningGateway {
  _Planner(this.plan);
  final ReminderPlan plan;
  @override
  ExtendedReminderPlans planCheckinHomeworkReminders({
    required List<CheckInReminderSeed> checkin,
    required List<HomeworkReminderSeed> homework,
    required int nowMillis,
  }) => ExtendedReminderPlans(plans: [plan]);

  @override
  Future<ExtendedReminderPlans> planReminders({
    required List<CourseReminderSeed> courses,
    required List<TaskReminderSeed> tasks,
    required int nowMillis,
  }) async => ExtendedReminderPlans(plans: []);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('GINKGO_TEST_REMINDER_ACCOUNT_SWITCH');
  const system = MethodChannel('cn.edu.buaa.ginkgo/system');
  const channel = MethodChannel('cn.edu.buaa.ginkgo/reminders');
  testWidgets(
    'synthetic account replacement clears the previous notification',
    (tester) async {
      // The isolated-device runner grants permission after the test starts.
      // ignore: avoid_print
      print('GINKGO_ACCOUNT_TEST_READY');
      var granted = false;
      for (var i = 0; i < 45; i++) {
        if (await system.invokeMethod<String>('notificationPermission') ==
            'granted') {
          granted = true;
          break;
        }
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      expect(granted, isTrue);
      final platform = SerialReminderPlatform(const NativeReminderPlatform());
      final now = DateTime.now();
      final plan = ReminderPlan(
        key: 'synthetic-shared-${now.microsecondsSinceEpoch}',
        group: 'homework',
        at: now.subtract(const Duration(seconds: 1)),
        expires: now.add(const Duration(minutes: 3)),
      );
      final service = _Service();
      ReminderController controller(String account) => ReminderController(
        service: service,
        account: account,
        visibility: null,
        platform: platform,
        persist: false,
        planner: _Planner(plan),
      );
      final old = controller('synthetic-account-a');
      final next = controller('synthetic-account-b');
      const data = HomeworkResponse(
        termName: '合成',
        termCode: 'synthetic',
        items: [],
      );
      Future<Map<String, dynamic>?> waitForVisible(int count) async {
        Map<String, dynamic>? result;
        for (var i = 0; i < 45; i++) {
          result = await channel.invokeMapMethod<String, dynamic>('summary');
          if (result?['visible'] == count) return result;
          await Future<void>.delayed(const Duration(seconds: 1));
        }
        return result;
      }

      try {
        await platform.replace([]);
        final baseline = await channel.invokeMapMethod<String, dynamic>(
          'summary',
        );
        final delivered = baseline?['delivered'] as int? ?? 0;
        expect(old.digest(plan.key), isNot(next.digest(plan.key)));
        old.updateHomework(data);
        await old.reconcile();
        expect((await waitForVisible(1))?['visible'], 1);
        final oldDelivered = await channel.invokeMapMethod<String, dynamic>(
          'summary',
        );
        expect(oldDelivered?['delivered'], greaterThanOrEqualTo(delivered + 1));
        await old.stop();
        expect(
          (await channel.invokeMapMethod<String, dynamic>(
            'summary',
          ))?['visible'],
          0,
        );
        next.updateHomework(data);
        await next.reconcile();
        Map<String, dynamic>? after;
        for (var i = 0; i < 45; i++) {
          after = await channel.invokeMapMethod<String, dynamic>('summary');
          if (after?['visible'] == 1 &&
              (after?['delivered'] as int? ?? 0) >= delivered + 2) {
            break;
          }
          await Future<void>.delayed(const Duration(seconds: 1));
        }
        expect(after?['visible'], 1);
        expect(after?['delivered'], greaterThanOrEqualTo(delivered + 2));
        await next.stop();
        final beforePending = await channel.invokeMapMethod<String, dynamic>(
          'summary',
        );
        final deliveredBeforePending = beforePending?['delivered'] as int? ?? 0;
        final future = DateTime.now();
        final occurrence = 'synthetic-pending-${future.microsecondsSinceEpoch}';
        Map<String, Object> pendingPlan(
          ReminderController owner,
          int seconds,
        ) => {
          'key': owner.digest(occurrence),
          'group': 'homework',
          'at': future.add(Duration(seconds: seconds)).millisecondsSinceEpoch,
          'expires': future
              .add(const Duration(minutes: 3))
              .millisecondsSinceEpoch,
        };
        await platform.replace([pendingPlan(old, 8)]);
        final clearOld = platform.replace([]);
        final addNew = platform.replace([pendingPlan(next, 18)]);
        await clearOld;
        await addNew;
        await Future<void>.delayed(const Duration(seconds: 11));
        final between = await channel.invokeMapMethod<String, dynamic>(
          'summary',
        );
        expect(between?['visible'], 0);
        expect(between?['delivered'], deliveredBeforePending);
        expect((await waitForVisible(1))?['visible'], 1);
      } finally {
        await next.stop();
        old.dispose();
        next.dispose();
      }
      expect(
        (await channel.invokeMapMethod<String, dynamic>('summary'))?['visible'],
        0,
      );
    },
    skip: !Platform.isAndroid || !enabled,
  );
}
