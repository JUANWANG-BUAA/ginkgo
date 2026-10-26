//! Stable homework business capability and values.
use super::DataOutcome;
use crate::{features::homework::HomeworkData, AppError};
#[derive(Debug, PartialEq, Eq)]
pub struct HomeworkOutcome {
    pub data: HomeworkData,
    pub fetched_at: String,
    pub failure: Option<AppError>,
}

pub trait HomeworkSource: Send + Sync {
    fn load_homework(
        &self,
        force: bool,
    ) -> impl std::future::Future<Output = Result<HomeworkOutcome, AppError>> + Send;
    fn load_homework_detail(
        &self,
        id: &str,
        force: bool,
    ) -> impl std::future::Future<Output = Result<HomeworkDetailOutcome, AppError>> + Send;
}

pub type HomeworkDetailOutcome = DataOutcome<crate::features::homework::HomeworkDetail>;
