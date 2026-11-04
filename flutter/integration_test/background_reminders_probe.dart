import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

export 'package:ginkgo_mirror/infrastructure/background_reminders.dart'
    show runBackgroundReminders;

/// Host-driven, synthetic-only fixture for process death, reboot and upgrade.
/// Never use this entrypoint as an application/release artifact.
Future<void> main() async {
  if (!const bool.fromEnvironment('GINKGO_TEST_BACKGROUND_REMINDERS')) return;
  WidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('cn.edu.buaa.ginkgo/reminders');
  final now = DateTime.now().millisecondsSinceEpoch;
  await channel.invokeMethod<void>('synchronize', {
    'owner': '1234567890abcdef1234567890abcdef',
    'checkin': true,
    'homework': true,
    'groups': ['checkin', 'homework', 'course', 'task'],
    'plans': [
      {
        'key': 'a'.padLeft(64, 'a'),
        'group': 'homework',
        'at': now + 3600000,
        'expires': now + 7200000,
      },
    ],
  });
  // ignore: avoid_print
  print('GINKGO_COLD_BACKGROUND_READY');
}
