import 'package:ginkgo_mirror/application/reminder_platform.dart';

/// Orders replacements across controller generations sharing one scheduler.
class SerialReminderPlatform implements ReminderPlatform {
  SerialReminderPlatform(this._delegate);

  final ReminderPlatform _delegate;
  Future<void> _tail = Future.value();

  @override
  Future<void> replace(List<Map<String, Object>> plans) {
    final operation = _tail.then((_) => _delegate.replace(plans));
    _tail = operation.catchError((Object _) {});
    return operation;
  }
}
