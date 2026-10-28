//! Public career events snapshot; failure preserves the old snapshot and time.
use super::SchoolClient;
use crate::{
    adapters::career_http, auth::CredentialVault, foundation::http::HttpTransport,
    services::cache::SnapshotCache, AppError,
};
use ginkgo_domain::{features::career::CareerEvents, ports::*};

pub(crate) type CareerEventsCache = SnapshotCache<String, CareerEvents>;

impl<T: HttpTransport + Send + Sync, V: CredentialVault> CareerEventsSource for SchoolClient<T, V> {
    async fn load_career_events(
        &self,
        month: &str,
        force: bool,
    ) -> Result<CareerEventsOutcome, AppError> {
        career_http::validate_month(month)?;
        super::cache::read_with_snapshot(&self.snapshots.career, month.to_owned(), force, async {
            let data = career_http::load(&self.session, month).await?;
            Ok(CareerEvents {
                fetched_at: super::cache::now_shanghai(),
                ..data
            })
        })
        .await
    }
}
