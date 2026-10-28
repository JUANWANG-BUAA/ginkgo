//! Stable public campus activity capability.
use crate::{features::campus_activities::CampusActivities, AppError};

#[derive(Debug, Clone)]
pub struct CampusActivitiesOutcome {
    pub data: CampusActivities,
    pub failure: Option<AppError>,
}

pub trait CampusActivitiesSource: Send + Sync {
    fn load_campus_activities(
        &self,
        page: i32,
        force: bool,
    ) -> impl std::future::Future<Output = Result<CampusActivitiesOutcome, AppError>> + Send;
}
