use super::session_service::SessionService;
use crate::{
    adapters::graduate_http, auth::CredentialVault, features::graduate::AcademicData,
    foundation::http::HttpTransport, AppError, ErrorCode,
};
pub struct GraduateOutcome {
    pub data: AcademicData,
    pub failure: Option<AppError>,
}
impl<T: HttpTransport + Send + Sync, V: CredentialVault> SessionService<T, V> {
    pub async fn load_graduate(&self, force: bool) -> Result<GraduateOutcome, AppError> {
        let account = self.current_account()?;
        let key = "academic".to_owned();
        if !force {
            let cache = self.graduate.lock().expect("graduate cache");
            if let Some(entry) = cache.fresh(&key) {
                return Ok(GraduateOutcome {
                    data: entry.value.clone(),
                    failure: None,
                });
            }
        }
        let mut result = graduate_http::load(&self.session, &account).await;
        if result
            .as_ref()
            .is_err_and(|e| e.code == ErrorCode::SessionExpired)
        {
            result = match self.silent_login().await {
                Ok(()) => graduate_http::load(&self.session, &account).await,
                Err(e) => Err(e),
            };
        }
        match result {
            Ok(data) => {
                self.graduate
                    .lock()
                    .expect("graduate cache")
                    .insert(key, data.clone());
                Ok(GraduateOutcome {
                    data,
                    failure: None,
                })
            }
            Err(error) => {
                let cache = self.graduate.lock().expect("graduate cache");
                match cache.any(&key) {
                    Some(entry) => Ok(GraduateOutcome {
                        data: entry.value.clone(),
                        failure: Some(error),
                    }),
                    None => Err(error),
                }
            }
        }
    }
}
