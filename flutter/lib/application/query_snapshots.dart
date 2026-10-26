class LearningSnapshotStatus {
  const LearningSnapshotStatus({
    required this.supported,
    this.enabled = false,
    this.message,
  });
  final bool supported, enabled;
  final String? message;
}

abstract interface class LearningSnapshotGateway {
  Future<LearningSnapshotStatus> learningSnapshotStatus();

  /// User must explicitly confirm saving private learning metadata first.
  Future<LearningSnapshotStatus> setLearningSnapshotsEnabled(bool enabled);
}
