use super::{cache::SnapshotCache, SchoolClient};
use crate::{
    adapters::library_stats_http, auth::CredentialVault, codecs::library_stats::CampusStats,
    foundation::http::HttpTransport, AppError,
};
use ginkgo_domain::ports::*;
pub(crate) type LibraryStatsCache = SnapshotCache<String, Vec<CampusStats>>;
pub use ginkgo_domain::ports::LibraryStatsOutcome;

impl<T: HttpTransport + Send + Sync, V: CredentialVault> LibraryStatsSource for SchoolClient<T, V> {
    async fn load_library_stats(&self, force: bool) -> Result<LibraryStatsOutcome, AppError> {
        let snapshot = super::cache::read_with_snapshot(
            &self.snapshots.library_stats,
            "public".to_owned(),
            force,
            library_stats_http::load(&self.session, self.preference().into()),
        )
        .await?;
        Ok(LibraryStatsOutcome {
            campuses: snapshot.data,
            fetched_at: snapshot.fetched_at,
            from_cache: snapshot.from_cache,
            failure: snapshot.failure,
        })
    }
}
