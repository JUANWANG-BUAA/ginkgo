//! Stable graduate business capability and values.
use super::DataOutcome;
use crate::AppError;
#[derive(Debug, Clone, Copy)]
pub enum GraduatePart {
    Status,
    Report,
}

pub trait GraduateSource: Send + Sync {
    fn load_graduate(
        &self,
        force: bool,
    ) -> impl std::future::Future<Output = Result<GraduateOutcome, AppError>> + Send;
    fn load_graduate_part(
        &self,
        part: GraduatePart,
        force: bool,
    ) -> impl std::future::Future<Output = Result<GraduateOutcome, AppError>> + Send;
}

pub type GraduateOutcome = DataOutcome<crate::features::graduate::AcademicData>;
