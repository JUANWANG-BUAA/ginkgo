import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:ginkgo_mirror/application/background_reminders.dart';
import 'package:ginkgo_mirror/application/contracts.dart' show FailureCode;
import 'package:ginkgo_mirror/shared/app_preferences.dart';
import 'package:ginkgo_mirror/infrastructure/course_visibility_file_store.dart';
import 'package:ginkgo_mirror/infrastructure/display_preferences_file_store.dart';
import 'package:ginkgo_mirror/infrastructure/mirror_runtime.dart';
import 'package:ginkgo_mirror/infrastructure/native_mirror_service.dart';
import 'package:ginkgo_mirror/src/rust/api/live.dart' as native;

const _channel = MethodChannel('cn.edu.buaa.ginkgo/reminder-background');

/// A headless isolate owned by Android JobScheduler, not a second UI session.
@pragma('vm:entry-point')
Future<void> runBackgroundReminders() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? generation;
  var status = 'retryLater';
  var batch = const BackgroundReminderBatch({}, []);
  try {
    final config = await _channel.invokeMapMethod<String, Object?>('begin');
    if (config == null) return;
    generation = config['generation'] as String;
    final owner = config['owner'] as String;
    final preferences = AppPreferences(
      reader: DisplayPreferencesFileStore().read,
    );
    await preferences.restore();
    final blocked = preferences.readFailed || preferences.explicitSignOut;
    preferences.dispose();
    if (blocked) {
      status = 'localSettings';
      return;
    }
    await initializeMirrorRuntime();
    final response = await native.readBackgroundReminders(
      owner: owner,
      checkin: config['checkin'] == true,
      homework: config['homework'] == true,
    );
    final account = response.account;
    if (response.failure != null || account == null) {
      status = switch (response.failure) {
        FailureCode.sessionExpired => 'sessionRequired',
        FailureCode.credentialStore => 'storageUnavailable',
        _ => 'retryLater',
      };
      return;
    }
    final visibility = CourseVisibilityFileStore(account).createController();
    try {
      await visibility.restore();
      batch = backgroundReminderBatch(
        account: account,
        expectedOwner: owner,
        checkin: response.checkin,
        // An unreadable local course range must not widen notification scope.
        homework: visibility.ready ? response.homework : null,
        planner: const NativeMirrorService(),
        nowMillis: DateTime.now().millisecondsSinceEpoch,
        personalHomework: (item) =>
            item.courseRole != 'assistant' &&
            !visibility.hidden('spoc', item.courseId ?? item.id),
      );
      status = batch.groups.isEmpty ? 'retryLater' : 'updated';
    } finally {
      visibility.dispose();
    }
  } catch (_) {
    // Keep all existing plans. Never log school data, retry passwords or spin.
  } finally {
    if (generation != null) {
      await _channel.invokeMethod<void>('finish', {
        'generation': generation,
        'groups': batch.groups.toList(),
        'plans': batch.plans,
        'status': status,
      });
    }
  }
}
