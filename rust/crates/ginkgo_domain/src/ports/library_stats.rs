//! Stable library_stats business capability and values.
use crate::{features::library_stats::CampusStats, AppError};
pub struct LibraryStatsOutcome {
    pub campuses: Vec<CampusStats>,
    pub fetched_at: String,
    pub from_cache: bool,
    pub failure: Option<AppError>,
}

pub trait LibraryStatsSource: Send + Sync {
    fn load_library_stats(
        &self,
        force: bool,
    ) -> impl std::future::Future<Output = Result<LibraryStatsOutcome, AppError>> + Send;
}
