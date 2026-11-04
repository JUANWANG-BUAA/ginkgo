import 'package:ginkgo_mirror/application/reminder_platform.dart';

/// Orders replacements across controller generations sharing one scheduler.
class SerialReminderPlatform
    implements ReminderPlatform, ScopedReminderPlatform {
  SerialReminderPlatform(this._delegate);

  final ReminderPlatform _delegate;
  Future<void> _tail = Future.value();

  Future<void> _enqueue(Future<void> Function() action) {
    final operation = _tail.then((_) => action());
    _tail = operation.catchError((Object _) {});
    return operation;
  }

  List<Map<String, Object>> _snapshot(List<Map<String, Object>> plans) => [
    for (final plan in plans) Map<String, Object>.of(plan),
  ];

  @override
  Future<void> replace(List<Map<String, Object>> plans) {
    final snapshot = _snapshot(plans);
    return _enqueue(() => _delegate.replace(snapshot));
  }

  @override
  Future<void> synchronize({
    required String owner,
    required bool checkin,
    required bool homework,
    required Set<String> groups,
    required List<Map<String, Object>> plans,
  }) {
    final delegate = _delegate;
    final snapshot = _snapshot(plans);
    final groupSnapshot = Set<String>.of(groups);
    return _enqueue(
      () => delegate is ScopedReminderPlatform
          ? (delegate as ScopedReminderPlatform).synchronize(
              owner: owner,
              checkin: checkin,
              homework: homework,
              groups: groupSnapshot,
              plans: snapshot,
            )
          : delegate.replace(snapshot),
    );
  }

  @override
  Future<void> clearOwner(String owner) {
    final delegate = _delegate;
    return _enqueue(
      () => delegate is ScopedReminderPlatform
          ? (delegate as ScopedReminderPlatform).clearOwner(owner)
          : delegate.replace([]),
    );
  }
}
