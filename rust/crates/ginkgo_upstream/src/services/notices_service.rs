use super::SchoolClient;
use crate::{
    adapters::notices_http, auth::CredentialVault, foundation::http::HttpTransport, AppError,
};
pub use ginkgo_domain::ports::NoticesOutcome;
use ginkgo_domain::ports::*;

impl<T: HttpTransport + Send + Sync, V: CredentialVault> NoticeSource for SchoolClient<T, V> {
    async fn load_notices(&self, force: bool) -> Result<NoticesOutcome, AppError> {
        super::cache::read_with_snapshot(
            &self.snapshots.notices,
            "public".to_owned(),
            force,
            notices_http::load(&self.session),
        )
        .await
    }
}
