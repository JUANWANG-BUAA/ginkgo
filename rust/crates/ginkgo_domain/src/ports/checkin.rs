//! Stable checkin business capability and values.
use crate::{features::checkin::CheckInCourse, AppError};
#[derive(Debug, Clone)]
pub struct CheckInOutcome {
    /// School-local date, yyyy-MM-dd.
    pub date: String,
    pub courses: Vec<CheckInCourse>,
    pub fetched_at: String,
    pub from_cache: bool,
    pub stale: bool,
    pub failure: Option<AppError>,
}

#[derive(Debug, Clone, serde::Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CheckInLoadProgress {
    pub phase: String,
    pub elapsed_ms: Option<u128>,
    pub stages: Vec<CheckInLoadStage>,
}

#[derive(Debug, Clone, serde::Serialize)]
pub struct CheckInLoadStage {
    pub phase: String,
    pub milliseconds: u128,
}

pub trait CheckInSource: Send + Sync {
    fn checkin_load_progress(&self) -> CheckInLoadProgress;
    fn load_checkin(
        &self,
        force_refresh: bool,
    ) -> impl std::future::Future<Output = Result<CheckInOutcome, AppError>> + Send;
    fn load_checkin_on_date(
        &self,
        date: Option<String>,
        force_refresh: bool,
    ) -> impl std::future::Future<Output = Result<CheckInOutcome, AppError>> + Send;
}

pub trait CheckInMutationSource: Send + Sync {
    fn submit_checkin(
        &self,
        course_id: &str,
    ) -> impl std::future::Future<Output = crate::features::mutation::MutationOutcome> + Send;
}
