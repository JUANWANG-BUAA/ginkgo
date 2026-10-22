//! Stable notices business capability and values.
use super::DataOutcome;
use crate::AppError;
pub trait NoticeSource: Send + Sync {
    fn load_notices(
        &self,
        force: bool,
    ) -> impl std::future::Future<Output = Result<NoticesOutcome, AppError>> + Send;
}

pub type NoticesOutcome = DataOutcome<Vec<crate::features::notices::Notice>>;
