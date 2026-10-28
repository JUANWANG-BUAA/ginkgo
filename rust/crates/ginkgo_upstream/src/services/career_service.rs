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
        let key = month.to_owned();
        if !force {
            if let Some(entry) = self.snapshots.career.lock().fresh(&key) {
                return Ok(CareerEventsOutcome {
                    data: entry.value.clone(),
                    failure: None,
                });
            }
        }
        let ticket = self.snapshots.career.lock().begin(&key);
        match career_http::load(&self.session, month).await {
            Ok(data) => {
                let data = CareerEvents {
                    fetched_at: super::cache::now_shanghai(),
                    ..data
                };
                self.snapshots
                    .career
                    .lock()
                    .insert_if_current(key, ticket, data.clone());
                Ok(CareerEventsOutcome {
                    data,
                    failure: None,
                })
            }
            Err(error) => match self.snapshots.career.lock().any(&key) {
                Some(entry) => Ok(CareerEventsOutcome {
                    data: entry.value.clone(),
                    failure: Some(error),
                }),
                None => Err(error),
            },
        }
    }
}
