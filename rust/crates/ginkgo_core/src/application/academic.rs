//! academic application commands depend only on business ports.
use super::*;

impl<U: ScheduleSource> Workspace<U> {
    pub async fn load_schedule(
        &self,
        input: &ScheduleQueryInput,
    ) -> Result<ScheduleOutcome, AppError> {
        self.upstream.load_schedule(input).await
    }
}

impl<U: TodaySource> Workspace<U> {
    pub async fn load_today(&self, force_refresh: bool) -> Result<TodayOutcome, AppError> {
        self.upstream.load_today(force_refresh).await
    }
}

impl<U: GradeSource> Workspace<U> {
    pub async fn load_grades(
        &self,
        term_code: Option<&str>,
        force_refresh: bool,
    ) -> Result<GradeOutcome, AppError> {
        self.upstream.load_grades(term_code, force_refresh).await
    }
    pub async fn load_grade_terms(&self) -> Result<Vec<Term>, AppError> {
        self.upstream.load_grade_terms().await
    }
}
