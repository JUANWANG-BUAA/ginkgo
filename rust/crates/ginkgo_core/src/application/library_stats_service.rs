use super::{cache::SnapshotCache, SessionService};
use crate::{
    adapters::library_stats_http, auth::CredentialVault, features::library_stats::CampusStats,
    foundation::http::HttpTransport, AppError,
};
pub(crate) type LibraryStatsCache = SnapshotCache<String, Vec<CampusStats>>;
pub struct LibraryStatsOutcome {
    pub campuses: Vec<CampusStats>,
    pub fetched_at: String,
    pub from_cache: bool,
    pub failure: Option<AppError>,
}
impl<T: HttpTransport + Send + Sync, V: CredentialVault> SessionService<T, V> {
    pub async fn load_library_stats(&self, force: bool) -> Result<LibraryStatsOutcome, AppError> {
        let key = "public".to_owned();
        if !force {
            if let Some(entry) = self
                .library_stats
                .lock()
                .expect("library stats")
                .fresh(&key)
            {
                return Ok(LibraryStatsOutcome {
                    campuses: entry.value.clone(),
                    fetched_at: entry.timestamp.clone(),
                    from_cache: true,
                    failure: None,
                });
            }
        }
        let result = library_stats_http::load(&self.session).await;
        let mut cache = self.library_stats.lock().expect("library stats");
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
