//! homework application commands depend only on business ports.
use super::*;

impl<U: HomeworkSource> Workspace<U> {
    pub async fn load_homework(&self, force: bool) -> Result<HomeworkOutcome, AppError> {
        self.upstream.load_homework(force).await
    }
    pub async fn load_homework_detail(
        &self,
        id: &str,
        force: bool,
    ) -> Result<HomeworkDetailOutcome, AppError> {
        self.upstream.load_homework_detail(id, force).await
    }
}
