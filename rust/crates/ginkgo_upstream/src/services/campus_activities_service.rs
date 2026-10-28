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
        super::cache::read_with_snapshot(
            &self.snapshots.activities,
            page.to_string(),
            force,
            async {
                let data = campus_activities_http::load(&self.session, page).await?;
                Ok(CampusActivities {
                    fetched_at: super::cache::now_shanghai(),
                    ..data
                })
            },
        )
        .await
    }
}
