use super::SchoolClient;
use crate::{
    adapters::notices_http, auth::CredentialVault, foundation::http::HttpTransport, AppError,
};
pub use ginkgo_domain::ports::NoticesOutcome;
use ginkgo_domain::ports::*;

impl<T: HttpTransport + Send + Sync, V: CredentialVault> NoticeSource for SchoolClient<T, V> {
    async fn load_notices(&self, force: bool) -> Result<NoticesOutcome, AppError> {
        let key = "public".to_owned();
        if !force {
            if let Some(entry) = self.snapshots.notices.lock().fresh(&key) {
                return Ok(NoticesOutcome {
                    data: entry.value.clone(),
                    failure: None,
                });
            }
        }
        let ticket = self.snapshots.notices.lock().begin(&key);
        match notices_http::load(&self.session).await {
            Ok(data) => {
                self.snapshots
                    .notices
                    .lock()
                    .insert_if_current(key, ticket, data.clone());
                Ok(NoticesOutcome {
                    data,
                    failure: None,
                })
            }
            Err(error) => match self.snapshots.notices.lock().any(&key) {
                Some(entry) => Ok(NoticesOutcome {
                    data: entry.value.clone(),
                    failure: Some(error),
                }),
                None => Err(error),
            },
        }
    }
}
