//! Public campus activities snapshot; failures preserve the prior snapshot.
use super::SchoolClient;
use crate::{
    adapters::campus_activities_http, auth::CredentialVault, foundation::http::HttpTransport,
    services::cache::SnapshotCache, AppError,
};
use ginkgo_domain::{features::campus_activities::CampusActivities, ports::*};

pub(crate) type CampusActivitiesCache = SnapshotCache<String, CampusActivities>;

impl<T: HttpTransport + Send + Sync, V: CredentialVault> CampusActivitiesSource
    for SchoolClient<T, V>
{
    async fn load_campus_activities(
        &self,
        page: i32,
        force: bool,
    ) -> Result<CampusActivitiesOutcome, AppError> {
        campus_activities_http::validate_page(page)?;
        let key = page.to_string();
        if !force {
            if let Some(entry) = self.snapshots.activities.lock().fresh(&key) {
                return Ok(CampusActivitiesOutcome {
                    data: entry.value.clone(),
                    failure: None,
                });
            }
        }
        let ticket = self.snapshots.activities.lock().begin(&key);
        match campus_activities_http::load(&self.session, page).await {
            Ok(data) => {
                let data = CampusActivities {
                    fetched_at: super::cache::now_shanghai(),
                    ..data
                };
                self.snapshots
                    .activities
                    .lock()
                    .insert_if_current(key, ticket, data.clone());
                Ok(CampusActivitiesOutcome {
                    data,
                    failure: None,
                })
            }
            Err(error) => match self.snapshots.activities.lock().any(&key) {
                Some(entry) => Ok(CampusActivitiesOutcome {
                    data: entry.value.clone(),
                    failure: Some(error),
                }),
                None => Err(error),
            },
        }
    }
}
