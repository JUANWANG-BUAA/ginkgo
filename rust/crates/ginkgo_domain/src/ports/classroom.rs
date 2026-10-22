//! Stable classroom business capability and values.
use crate::{
    features::classroom::{FilterResult, Sort},
    AppError,
};
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ClassroomQueryInput {
    pub campus: i32,
    pub date: String,
    pub force_refresh: bool,
    pub search: String,
    pub section: i32,
    pub minimum_free_sections: i32,
    pub minimum_consecutive_sections: i32,
    pub building: Option<String>,
    pub sort: Sort,
}

#[derive(Debug)]
pub struct ClassroomOutcome {
    pub result: FilterResult,
    pub fetched_at: String,
    pub from_cache: bool,
    pub stale: bool,
    pub failure: Option<AppError>,
}

pub trait ClassroomSource: Send + Sync {
    fn load_classrooms(
        &self,
        input: &ClassroomQueryInput,
    ) -> impl std::future::Future<Output = Result<ClassroomOutcome, AppError>> + Send;
}
