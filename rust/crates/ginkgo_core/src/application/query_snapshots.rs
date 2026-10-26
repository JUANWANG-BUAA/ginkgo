//! No filesystem or crypto in the application core.
use super::*;
impl<U: LearningSnapshotSource> Workspace<U> {
    pub fn export_learning_snapshots(&self) -> Result<Vec<u8>, AppError> {
        self.upstream.export_learning_snapshots()
    }
    pub fn import_learning_snapshots(&self, bytes: &[u8]) -> Result<u32, AppError> {
        self.upstream.import_learning_snapshots(bytes)
    }
}
