//! classroom application commands depend only on business ports.
use super::*;

impl<U: ClassroomSource> Workspace<U> {
    pub async fn load_classrooms(
        &self,
        input: &ClassroomQueryInput,
    ) -> Result<ClassroomOutcome, AppError> {
        self.upstream.load_classrooms(input).await
    }
}
