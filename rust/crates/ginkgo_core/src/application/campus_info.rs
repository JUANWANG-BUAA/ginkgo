//! Public read commands: career events and campus activities.
use super::*;

impl<U: CareerEventsSource> Workspace<U> {
    pub async fn load_career_events(
        &self,
        month: &str,
        force: bool,
    ) -> Result<CareerEventsOutcome, AppError> {
        self.upstream.load_career_events(month, force).await
    }
}

impl<U: CampusActivitiesSource> Workspace<U> {
    pub async fn load_campus_activities(
        &self,
        page: i32,
        force: bool,
    ) -> Result<CampusActivitiesOutcome, AppError> {
        self.upstream.load_campus_activities(page, force).await
    }
}
