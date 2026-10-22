//! library_stats application commands depend only on business ports.
use super::*;

impl<U: LibraryStatsSource> Workspace<U> {
    pub async fn load_library_stats(&self, force: bool) -> Result<LibraryStatsOutcome, AppError> {
        self.upstream.load_library_stats(force).await
    }
}
