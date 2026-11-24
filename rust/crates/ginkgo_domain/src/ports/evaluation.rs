use crate::{features::evaluation::TeachingEvaluationReport, ports::ReadSnapshot, AppError};

pub type TeachingEvaluationOutcome = ReadSnapshot<TeachingEvaluationReport>;

pub trait TeachingEvaluationSource: Send + Sync {
    fn load_teaching_evaluation(
        &self,
        force_refresh: bool,
    ) -> impl std::future::Future<Output = Result<TeachingEvaluationOutcome, AppError>> + Send;
}
