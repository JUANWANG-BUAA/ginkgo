//! SPOC read-only snapshots. Tokens stay inside Rust; no submission endpoints.
use super::{cache::SnapshotCache, session_service::SchoolClient};
use crate::{
    adapters::homework_http,
    auth::CredentialVault,
    codecs::homework::{HomeworkData, HomeworkDetail},
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
        let snapshot = super::cache::read_with_snapshot_checked(
            &self.snapshots.homework,
            key,
            force,
            async {
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
                result
            },
            || {
                if self.current_account()? == account {
                    Ok(())
                } else {
                    Err(AppError::session_expired())
                }
            },
        )
        .await?;
        Ok(snapshot)
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
        let snapshot = super::cache::read_with_snapshot_checked(
            &self.snapshots.homework_details,
            key,
            force,
            async {
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
                result.map(|mut data| {
                    data.source_url = Some(crate::endpoints::HOMEWORK_PORTAL.to_owned());
                    data
                })
            },
            || {
                if self.current_account()? == account {
                    Ok(())
                } else {
                    Err(AppError::session_expired())
                }
            },
        )
        .await?;
        Ok(snapshot)
    }
}
