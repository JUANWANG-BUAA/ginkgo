//! bykc application commands depend only on business ports.
use super::*;

impl<U: BykcSource> Workspace<U> {
    pub async fn load_bykc(&self, force: bool) -> Result<BykcOutcome, AppError> {
        self.upstream.load_bykc(force).await
    }
    pub async fn load_bykc_chosen(&self, force: bool) -> Result<BykcChosenOutcome, AppError> {
        self.upstream.load_bykc_chosen(force).await
    }
    pub async fn load_bykc_statistics(
        &self,
        force: bool,
    ) -> Result<BykcStatisticsOutcome, AppError> {
        self.upstream.load_bykc_statistics(force).await
    }
}
