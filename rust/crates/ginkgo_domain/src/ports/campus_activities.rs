//! Stable public campus activity capability.
use crate::{features::campus_activities::CampusActivities, AppError};

pub type CampusActivitiesOutcome = super::ReadSnapshot<CampusActivities>;

pub trait CampusActivitiesSource: Send + Sync {
    fn load_campus_activities(
        &self,
        page: i32,
        force: bool,
    ) -> impl std::future::Future<Output = Result<CampusActivitiesOutcome, AppError>> + Send;
}
