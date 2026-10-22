//! Stable bykc business capability and values.
use super::DataOutcome;
use crate::AppError;
pub trait BykcSource: Send + Sync {
    fn load_bykc(
        &self,
        force: bool,
    ) -> impl std::future::Future<Output = Result<BykcOutcome, AppError>> + Send;
    fn load_bykc_chosen(
        &self,
        force: bool,
    ) -> impl std::future::Future<Output = Result<BykcChosenOutcome, AppError>> + Send;
    fn load_bykc_statistics(
        &self,
        force: bool,
    ) -> impl std::future::Future<Output = Result<BykcStatisticsOutcome, AppError>> + Send;
}

pub type BykcOutcome = DataOutcome<crate::features::bykc::Catalog>;

pub type BykcChosenOutcome = DataOutcome<crate::features::bykc::ChosenCourses>;

pub type BykcStatisticsOutcome = DataOutcome<crate::features::bykc::LearningStatistics>;
