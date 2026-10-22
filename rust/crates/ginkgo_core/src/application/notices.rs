//! notices application commands depend only on business ports.
use super::*;

impl<U: NoticeSource> Workspace<U> {
    pub async fn load_notices(&self, force: bool) -> Result<NoticesOutcome, AppError> {
        self.upstream.load_notices(force).await
    }
}
