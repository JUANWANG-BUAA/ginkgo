//! graduate application commands depend only on business ports.
use super::*;

impl<U: GraduateSource> Workspace<U> {
    pub async fn load_graduate(&self, force: bool) -> Result<GraduateOutcome, AppError> {
        self.upstream.load_graduate(force).await
    }
    pub async fn load_graduate_part(
        &self,
        part: GraduatePart,
        force: bool,
    ) -> Result<GraduateOutcome, AppError> {
        self.upstream.load_graduate_part(part, force).await
    }
}
