use super::{cache::SnapshotCache, SchoolClient};
use crate::{
    adapters::library_stats_http, auth::CredentialVault, features::library_stats::CampusStats,
    foundation::http::HttpTransport, AppError,
};
use ginkgo_domain::ports::*;
pub(crate) type LibraryStatsCache = SnapshotCache<String, Vec<CampusStats>>;
pub use ginkgo_domain::ports::LibraryStatsOutcome;

impl<T: HttpTransport + Send + Sync, V: CredentialVault> LibraryStatsSource for SchoolClient<T, V> {
    async fn load_library_stats(&self, force: bool) -> Result<LibraryStatsOutcome, AppError> {
        let key = "public".to_owned();
        if !force {
            if let Some(entry) = self.snapshots.library_stats.lock().fresh(&key) {
                return Ok(LibraryStatsOutcome {
                    campuses: entry.value.clone(),
                    fetched_at: entry.timestamp.clone(),
                    from_cache: true,
                    failure: None,
                });
            }
        }
        let result = library_stats_http::load(&self.session, self.preference().into()).await;
        let mut cache = self.snapshots.library_stats.lock();
        match result {
            Ok(campuses) => {
                let fetched_at = cache.insert(key, campuses.clone());
                Ok(LibraryStatsOutcome {
                    campuses,
                    fetched_at,
                    from_cache: false,
                    failure: None,
                })
            }
            Err(error) => match cache.any(&key) {
                Some(entry) => Ok(LibraryStatsOutcome {
                    campuses: entry.value.clone(),
                    fetched_at: entry.timestamp.clone(),
                    from_cache: true,
                    failure: Some(error),
                }),
                None => Err(error),
            },
        }
    }
}
