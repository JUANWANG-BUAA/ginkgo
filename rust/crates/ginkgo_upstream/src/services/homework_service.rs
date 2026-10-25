//! SPOC read-only snapshots. Tokens stay inside Rust; no submission endpoints.
use super::{cache::SnapshotCache, session_service::SchoolClient};
use crate::{
    adapters::homework_http,
    auth::CredentialVault,
    features::homework::{HomeworkData, HomeworkDetail},
    foundation::http::HttpTransport,
    AppError, ErrorCode,
};
use ginkgo_domain::ports::*;

pub(crate) type HomeworkCache = SnapshotCache<String, HomeworkData>;
pub(crate) type HomeworkDetailCache = SnapshotCache<String, HomeworkDetail>;

pub use ginkgo_domain::ports::HomeworkDetailOutcome;
pub use ginkgo_domain::ports::HomeworkOutcome;

impl<T: HttpTransport + Send + Sync, V: CredentialVault> HomeworkSource for SchoolClient<T, V> {
    async fn load_homework(&self, force: bool) -> Result<HomeworkOutcome, AppError> {
        let account = self.current_account()?;
        let key = "current".to_owned();
        if !force {
            let cache = self.snapshots.homework.lock();
            if let Some(entry) = cache.fresh(&key) {
                return Ok(HomeworkOutcome {
                    data: entry.value.clone(),
                    fetched_at: entry.timestamp.clone(),
                    failure: None,
                });
            }
        }
        let ticket = self.snapshots.homework.lock().begin(&key);
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
        if self.current_account()? != account {
            return Err(AppError::session_expired());
        }
        match result {
            Ok(data) => {
                let fetched_at =
                    self.snapshots
                        .homework
                        .lock()
                        .insert_if_current(key, ticket, data.clone());
                Ok(HomeworkOutcome {
                    data,
                    fetched_at,
                    failure: None,
                })
            }
            Err(error) => {
                let cache = self.snapshots.homework.lock();
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

    async fn load_homework_detail(
        &self,
        id: &str,
        force: bool,
    ) -> Result<HomeworkDetailOutcome, AppError> {
        let account = self.current_account()?;
        // Public item IDs include the source namespace; upstream expects zyid only.
        let id = id.strip_prefix("spoc:").unwrap_or(id);
        let key = id.to_owned();
        if !force {
            let cache = self.snapshots.homework_details.lock();
            if let Some(entry) = cache.fresh(&key) {
                return Ok(HomeworkDetailOutcome {
                    data: entry.value.clone(),
                    failure: None,
                });
            }
        }
        let ticket = self.snapshots.homework_details.lock().begin(&key);
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
        if self.current_account()? != account {
            return Err(AppError::session_expired());
        }
        match result {
            Ok(mut data) => {
                data.source_url = Some(crate::endpoints::HOMEWORK_PORTAL.to_owned());
                self.snapshots
                    .homework_details
                    .lock()
                    .insert_if_current(key, ticket, data.clone());
                Ok(HomeworkDetailOutcome {
                    data,
                    failure: None,
                })
            }
            Err(error) => {
                let cache = self.snapshots.homework_details.lock();
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
