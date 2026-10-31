import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('GINKGO_TEST_PERMISSION_RECOVERY');
  const reminders = MethodChannel('cn.edu.buaa.ginkgo/reminders');
  const system = MethodChannel('cn.edu.buaa.ginkgo/system');

  testWidgets(
    'denied notification can be rescheduled after permission is granted',
    (tester) async {
      final before = await system.invokeMethod<String>(
        'notificationPermission',
      );
      expect(before, isNot('granted'));
      final now = DateTime.now();
      final plan = [
        {
          'key': now.microsecondsSinceEpoch.toRadixString(16).padLeft(64, '0'),
          'group': 'checkin',
          'at': now.add(const Duration(seconds: 2)).millisecondsSinceEpoch,
          'expires': now.add(const Duration(minutes: 3)).millisecondsSinceEpoch,
        },
      ];
      await reminders.invokeMethod<void>('replace', plan);
      try {
        await Future<void>.delayed(const Duration(seconds: 10));
        final denied = await reminders.invokeMapMethod<String, dynamic>(
          'summary',
        );
        expect(denied?['visible'], 0);
        expect(denied?['delivered'], 0);
        // The isolated-device runner grants permission after this marker.
        // ignore: avoid_print
        print('GINKGO_READY_TO_GRANT_NOTIFICATIONS');
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
        await reminders.invokeMethod<void>('replace', plan);
        Map<String, dynamic>? after;
        for (var i = 0; i < 45; i++) {
          await Future<void>.delayed(const Duration(seconds: 1));
          after = await reminders.invokeMapMethod<String, dynamic>('summary');
          if (after?['visible'] == 1) break;
        }
        expect(after?['visible'], 1);
        expect(after?['delivered'], 1);
      } finally {
        await reminders.invokeMethod<void>('replace', []);
      }
    },
    skip: !Platform.isAndroid || !enabled,
  );
}
