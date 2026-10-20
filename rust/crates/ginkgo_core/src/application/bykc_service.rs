use super::session_service::SessionService;
use crate::{
    adapters::bykc_http, auth::CredentialVault, features::bykc::Catalog,
    foundation::http::HttpTransport, AppError, ErrorCode,
};

pub struct BykcOutcome {
    pub data: Catalog,
    pub failure: Option<AppError>,
}
impl<T: HttpTransport + Send + Sync, V: CredentialVault> SessionService<T, V> {
    pub async fn load_bykc(&self, force: bool) -> Result<BykcOutcome, AppError> {
        self.current_account()?;
        let key = "catalog".to_owned();
        if !force {
            let cache = self.bykc.lock().expect("bykc cache");
            if let Some(entry) = cache.fresh(&key) {
                return Ok(BykcOutcome {
                    data: entry.value.clone(),
                    failure: None,
                });
            }
        }
        let mut result = bykc_http::load(&self.session).await;
        if result
            .as_ref()
            .is_err_and(|e| e.code == ErrorCode::SessionExpired)
        {
            result = match self.silent_login().await {
                Ok(()) => bykc_http::load(&self.session).await,
                Err(e) => Err(e),
            };
        }
        match result {
            Ok(data) => {
                self.bykc
                    .lock()
                    .expect("bykc cache")
                    .insert(key, data.clone());
                Ok(BykcOutcome {
                    data,
                    failure: None,
                })
            }
            Err(error) => {
                let cache = self.bykc.lock().expect("bykc cache");
                match cache.any(&key) {
                    Some(entry) => Ok(BykcOutcome {
                        data: entry.value.clone(),
                        failure: Some(error),
                    }),
                    None => Err(error),
                }
            }
        }
    }
}
