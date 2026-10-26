//! Optional private learning-query archives, never credentials or downloaded files.
/// Bytes are transient; the host may persist them ONLY via approved encrypted storage.
pub trait LearningSnapshotSource: Send + Sync {
    fn export_learning_snapshots(&self) -> Result<Vec<u8>, crate::AppError>;
    /// Caller must already have authenticated the current account. Never logs in.
    fn import_learning_snapshots(&self, bytes: &[u8]) -> Result<u32, crate::AppError>;
}
