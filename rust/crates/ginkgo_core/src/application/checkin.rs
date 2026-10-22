//! checkin application commands depend only on business ports.
use super::*;

impl<U: CheckInSource> Workspace<U> {
    pub fn checkin_load_progress(&self) -> CheckInLoadProgress {
        self.upstream.checkin_load_progress()
    }
    pub async fn load_checkin(&self, force_refresh: bool) -> Result<CheckInOutcome, AppError> {
        self.upstream.load_checkin(force_refresh).await
    }
    pub async fn load_checkin_on_date(
        &self,
        date: Option<String>,
        force_refresh: bool,
    ) -> Result<CheckInOutcome, AppError> {
        self.upstream
            .load_checkin_on_date(date, force_refresh)
            .await
    }
}

impl<U: CheckInMutationSource> Workspace<U> {
    pub async fn submit_checkin(
        &self,
        course_id: &str,
    ) -> crate::features::mutation::MutationOutcome {
        self.upstream.submit_checkin(course_id).await
    }
}
