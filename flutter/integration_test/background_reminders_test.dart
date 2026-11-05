import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ginkgo_mirror/infrastructure/mirror_runtime.dart';
import 'package:ginkgo_mirror/application/contracts.dart' show FailureCode;
import 'package:ginkgo_mirror/src/rust/api/live.dart' as native;
export 'package:ginkgo_mirror/infrastructure/background_reminders.dart'
    show runBackgroundReminders;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('GINKGO_TEST_BACKGROUND_REMINDERS');
  const channel = MethodChannel('cn.edu.buaa.ginkgo/reminders');
  const owner = '1234567890abcdef1234567890abcdef';
  testWidgets('headless engine and JNI finish without any saved account', (
    tester,
  ) async {
    await initializeMirrorRuntime();
    // The runtime rejects a missing local snapshot before any HTTP request.
    // Dart (73b2dcf) maps this failure to retryLater for the background engine;
    // the bridge failure and the displayed background status are distinct.
    final missing = await native.readBackgroundReminders(
      owner: owner,
      checkin: true,
      homework: true,
    );
    expect(missing.failure, FailureCode.sessionExpired);
    expect(missing.account, isNull);
    final now = DateTime.now().millisecondsSinceEpoch;
    Map<String, Object> plan(String key, String group) => {
      'key': key.padLeft(64, key),
      'group': group,
      'at': now + 3600000,
      'expires': now + 7200000,
    };
    Future<void> synchronize(
      String account,
      List<String> groups,
      List<Map<String, Object>> plans,
    ) => channel.invokeMethod<void>('synchronize', {
      'owner': account,
      'checkin': true,
      'homework': true,
      'groups': groups,
      'plans': plans,
    });
    Future<int?> planCount() async =>
        (await channel.invokeMapMethod<String, Object?>('summary'))?['plans']
            as int?;
    await synchronize(
      owner,
      ['checkin', 'homework'],
      [plan('a', 'checkin'), plan('b', 'homework')],
    );
    expect(await planCount(), 2);
    await synchronize(owner, ['checkin'], []);
    expect(await planCount(), 1);
    await synchronize(owner, [], []);
    expect(await planCount(), 1);
    const other = 'abcdef1234567890abcdef1234567890';
    await channel.invokeMethod<void>('clearOwner', other);
    expect(await planCount(), 1);
    await synchronize(other, [], []);
    expect(await planCount(), 0);
    await channel.invokeMethod<void>('clearOwner', owner);
    expect(
      (await channel.invokeMapMethod<String, Object?>(
        'backgroundSummary',
      ))?['enabled'],
      true,
    );
    await channel.invokeMethod<void>('clearOwner', other);
    expect(
      (await channel.invokeMapMethod<String, Object?>(
        'backgroundSummary',
      ))?['scheduled'],
      false,
    );
    await channel.invokeMethod<void>('synchronize', {
      'owner': owner,
      'checkin': true,
      'homework': true,
      'groups': ['checkin', 'homework', 'course', 'task'],
      'plans': <Object>[],
    });
    final initial = await channel.invokeMapMethod<String, Object?>(
      'backgroundSummary',
    );
    expect(initial?['scheduled'], true);
    // The host runner backgrounds the Activity and forces only this local job.
    // ignore: avoid_print
    print('GINKGO_BACKGROUND_TEST_READY');
    Map<String, Object?>? summary;
    for (var i = 0; i < 90; i++) {
      summary = await channel.invokeMapMethod<String, Object?>(
        'backgroundSummary',
      );
      if (summary?['status'] == 'retryLater') break;
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    expect(summary?['status'], 'retryLater');
    expect(summary?['lastRun'], greaterThan(0));
    expect(summary?['scheduled'], true);
    // Preserve only this synthetic configuration for the host's cold-process
    // probe. The runner must use a fresh, isolated emulator, never a real app.
  }, skip: !Platform.isAndroid || !enabled);
}
