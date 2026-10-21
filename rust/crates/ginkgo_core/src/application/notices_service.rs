use super::SessionService;
use crate::{
    adapters::notices_http, auth::CredentialVault, features::notices::Notice,
    foundation::http::HttpTransport, AppError,
};
pub struct NoticesOutcome {
    pub data: Vec<Notice>,
    pub failure: Option<AppError>,
}
impl<T: HttpTransport + Send + Sync, V: CredentialVault> SessionService<T, V> {
    pub async fn load_notices(&self, force: bool) -> Result<NoticesOutcome, AppError> {
        let key = "public".to_owned();
        if !force {
            if let Some(entry) = self.notices.lock().fresh(&key) {
                return Ok(NoticesOutcome {
                    data: entry.value.clone(),
                    failure: None,
                });
            }
        }
        match notices_http::load(&self.session).await {
            Ok(data) => {
                self.notices.lock().insert(key, data.clone());
                Ok(NoticesOutcome {
                    data,
                    failure: None,
                })
            }
            Err(error) => match self.notices.lock().any(&key) {
                Some(entry) => Ok(NoticesOutcome {
                    data: entry.value.clone(),
                    failure: Some(error),
                }),
                None => Err(error),
            },
        }
    }
}
