//! Stable outcome business capability and values.
use crate::AppError;
#[derive(Debug, Clone)]
pub struct DataOutcome<T> {
    pub data: T,
    pub failure: Option<AppError>,
}
