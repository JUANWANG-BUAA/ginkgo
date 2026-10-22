//! cgyy application commands depend only on business ports.
use super::*;

impl<U: CgyySource> Workspace<U> {
    pub async fn load_cgyy(&self, query: CgyyQuery, force: bool) -> Result<CgyyOutcome, AppError> {
        self.upstream.load_cgyy(query, force).await
    }
}
