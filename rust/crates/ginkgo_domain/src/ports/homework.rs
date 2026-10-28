//! Stable homework business capability and values.
use super::ReadSnapshot;
use crate::{features::homework::HomeworkData, AppError};
pub type HomeworkOutcome = ReadSnapshot<HomeworkData>;

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

pub type HomeworkDetailOutcome = ReadSnapshot<crate::features::homework::HomeworkDetail>;
