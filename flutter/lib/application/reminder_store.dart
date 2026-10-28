/// Account-scoped persistence for reminder preferences and read receipts.
/// Implementations serialize accepted writes and subsequent reads for the same
/// account, including across instances, and propagate storage failures.
abstract interface class ReminderStore {
  Future<String?> read();
  Future<void> write(String data);
}
