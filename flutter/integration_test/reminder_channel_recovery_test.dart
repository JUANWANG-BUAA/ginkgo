import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('GINKGO_TEST_REMINDER_CHANNEL');
  const reminders = MethodChannel('cn.edu.buaa.ginkgo/reminders');
  const system = MethodChannel('cn.edu.buaa.ginkgo/system');

  testWidgets(
    'blocked reminder channel retains an undelivered plan for recovery',
    (tester) async {
      Future<bool> waitFor(String status) async {
        for (var i = 0; i < 90; i++) {
          if (await system.invokeMethod<String>('notificationPermission') ==
              status) {
            return true;
          }
          await Future<void>.delayed(const Duration(seconds: 1));
        }
        return false;
      }

      Future<Map<String, dynamic>?> summary() =>
          reminders.invokeMapMethod<String, dynamic>('summary');
      Future<bool> waitVisible(int count) async {
        for (var i = 0; i < 45; i++) {
          if ((await summary())?['visible'] == count) return true;
          await Future<void>.delayed(const Duration(seconds: 1));
        }
        return false;
      }

      Map<String, Object> plan(String key) {
        final now = DateTime.now();
        return {
          'key': key,
          'group': 'homework',
          'at': now.add(const Duration(seconds: 2)).millisecondsSinceEpoch,
          'expires': now.add(const Duration(minutes: 5)).millisecondsSinceEpoch,
        };
      }

      // ignore: avoid_print
      print('GINKGO_CHANNEL_GRANT_PERMISSION');
      expect(await waitFor('granted'), isTrue);
      final seed = DateTime.now().microsecondsSinceEpoch
          .toRadixString(16)
          .padLeft(63, '0');
      try {
        await reminders.invokeMethod<void>('replace', [plan('a$seed')]);
        expect(await waitVisible(1), isTrue);
        await reminders.invokeMethod<void>('replace', []);
        final baseline = (await summary())?['delivered'] as int? ?? 0;
        // ignore: avoid_print
        print('GINKGO_CHANNEL_DISABLE');
        expect(await waitFor('channelBlocked'), isTrue);
        final pending = [plan('b$seed')];
        await reminders.invokeMethod<void>('replace', pending);
        await Future<void>.delayed(const Duration(seconds: 10));
        final blocked = await summary();
        expect(blocked?['visible'], 0);
        expect(blocked?['delivered'], baseline);
        // ignore: avoid_print
        print('GINKGO_CHANNEL_ENABLE');
        expect(await waitFor('granted'), isTrue);
        await reminders.invokeMethod<void>('replace', pending);
        expect(await waitVisible(1), isTrue);
        expect((await summary())?['delivered'], baseline + 1);
      } finally {
        await reminders.invokeMethod<void>('replace', []);
      }
    },
    skip: !Platform.isAndroid || !enabled,
  );
}
