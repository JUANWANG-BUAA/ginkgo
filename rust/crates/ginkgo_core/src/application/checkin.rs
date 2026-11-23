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

impl<U: CheckInQrSource> Workspace<U> {
    pub async fn prepare_checkin_qr(
        &self,
        course_id: &str,
        revalidate_course: bool,
    ) -> Result<crate::features::checkin::CheckInQrTicket, AppError> {
        self.upstream
            .prepare_checkin_qr(course_id, revalidate_course)
            .await
    }
}
