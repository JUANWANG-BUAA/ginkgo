/// System notification scheduling, independent of the platform channel.
abstract interface class ReminderPlatform {
  Future<void> replace(List<Map<String, Object>> plans);
}

/// Atomically binds background discovery and partial plan updates to an owner.
abstract interface class ScopedReminderPlatform {
  Future<void> synchronize({
    required String owner,
    required bool checkin,
    required bool homework,
    required Set<String> groups,
    required List<Map<String, Object>> plans,
  });
  Future<void> clearOwner(String owner);
}
