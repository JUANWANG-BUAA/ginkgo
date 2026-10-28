//! Stable outcome business capability and values.
use crate::AppError;
#[derive(Debug, Clone)]
pub struct DataOutcome<T> {
    pub data: T,
    pub failure: Option<AppError>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ReadSnapshot<T> {
    pub data: T,
    pub fetched_at: String,
    pub from_cache: bool,
    pub stale: bool,
    pub failure: Option<AppError>,
}
