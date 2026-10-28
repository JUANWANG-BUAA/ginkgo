/// System notification scheduling, independent of the platform channel.
abstract interface class ReminderPlatform {
  Future<void> replace(List<Map<String, Object>> plans);
}
