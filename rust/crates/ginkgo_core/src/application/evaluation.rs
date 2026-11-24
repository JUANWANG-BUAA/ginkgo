//! Read-only teaching evaluation status query through an isolated narrow port.
//! Never exposes form questions or evaluation submission endpoints.
use super::*;
pub use ginkgo_domain::features::evaluation::{
    EvaluationCourseItem, EvaluationCourseStatus, TeachingEvaluationReport,
};

impl<U: TeachingEvaluationSource> Workspace<U> {
    pub async fn load_teaching_evaluation(
        &self,
        force_refresh: bool,
    ) -> Result<TeachingEvaluationOutcome, AppError> {
        self.upstream.load_teaching_evaluation(force_refresh).await
    }
}
