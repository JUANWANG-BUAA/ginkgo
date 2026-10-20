//! SPOC read-only snapshots. Tokens stay inside Rust; no submission endpoints.
use super::{cache::SnapshotCache, session_service::SessionService};
use crate::{
    adapters::homework_http,
    auth::CredentialVault,
    features::homework::{HomeworkData, HomeworkDetail},
    foundation::http::HttpTransport,
    AppError, ErrorCode,
};

pub(crate) type HomeworkCache = SnapshotCache<String, HomeworkData>;
pub(crate) type HomeworkDetailCache = SnapshotCache<String, HomeworkDetail>;

pub struct HomeworkOutcome {
    pub data: HomeworkData,
    pub fetched_at: String,
    pub failure: Option<AppError>,
}
pub struct HomeworkDetailOutcome {
    pub data: HomeworkDetail,
    pub failure: Option<AppError>,
}

impl<T: HttpTransport + Send + Sync, V: CredentialVault> SessionService<T, V> {
    pub async fn load_homework(&self, force: bool) -> Result<HomeworkOutcome, AppError> {
        self.current_account()?;
        let key = "current".to_owned();
        if !force {
            let cache = self.homework.lock().expect("homework cache");
            if let Some(entry) = cache.fresh(&key) {
                return Ok(HomeworkOutcome {
                    data: entry.value.clone(),
                    fetched_at: entry.timestamp.clone(),
                    failure: None,
                });
            }
        }
        let mut result = homework_http::load(&self.session).await;
        if result
            .as_ref()
            .is_err_and(|e| e.detail.as_deref() == Some("webvpn_login_required"))
        {
            result = match self.ensure_webvpn_session().await {
                Ok(()) => homework_http::load(&self.session).await,
                Err(error) => Err(error),
            };
        } else if result
            .as_ref()
            .is_err_and(|e| e.code == ErrorCode::SessionExpired)
        {
            result = match self.silent_login().await {
                Ok(()) => homework_http::load(&self.session).await,
                Err(error) => Err(error),
            };
        }
        match result {
            Ok(data) => {
                let fetched_at = self
                    .homework
                    .lock()
                    .expect("homework cache")
                    .insert(key, data.clone());
                Ok(HomeworkOutcome {
                    data,
                    fetched_at,
                    failure: None,
                })
            }
            Err(error) => {
                let cache = self.homework.lock().expect("homework cache");
                match cache.any(&key) {
                    Some(entry) => Ok(HomeworkOutcome {
                        data: entry.value.clone(),
                        fetched_at: entry.timestamp.clone(),
                        failure: Some(error),
                    }),
                    None => Err(error),
                }
            }
        }
    }

    pub async fn load_homework_detail(
        &self,
        id: &str,
        force: bool,
    ) -> Result<HomeworkDetailOutcome, AppError> {
        self.current_account()?;
        let key = id.to_owned();
        if !force {
            let cache = self.homework_details.lock().expect("homework detail cache");
            if let Some(entry) = cache.fresh(&key) {
                return Ok(HomeworkDetailOutcome {
                    data: entry.value.clone(),
                    failure: None,
                });
            }
        }
        let mut result = homework_http::load_detail(&self.session, id).await;
        if result
            .as_ref()
            .is_err_and(|e| e.code == ErrorCode::SessionExpired)
        {
            result = match self.silent_login().await {
                Ok(()) => homework_http::load_detail(&self.session, id).await,
                Err(error) => Err(error),
            };
        }
        match result {
            Ok(data) => {
                self.homework_details
                    .lock()
                    .expect("homework detail cache")
                    .insert(key, data.clone());
                Ok(HomeworkDetailOutcome {
                    data,
                    failure: None,
                })
            }
            Err(error) => {
                let cache = self.homework_details.lock().expect("homework detail cache");
                match cache.any(&key) {
                    Some(entry) => Ok(HomeworkDetailOutcome {
                        data: entry.value.clone(),
                        failure: Some(error),
                    }),
                    None => Err(error),
                }
            }
        }
    }
}
