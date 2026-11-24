//! Read-only teaching evaluation status service with 5-minute snapshot cache.
//! Never submits evaluation forms; preserves stale snapshot on transient failure.
use super::{session_service::SchoolClient, AppError};
use crate::{adapters::evaluation_http, auth::CredentialVault, foundation::http::HttpTransport};
use ginkgo_domain::{
    features::evaluation::TeachingEvaluationReport,
    ports::{TeachingEvaluationOutcome, TeachingEvaluationSource},
};

impl<T: HttpTransport + Send + Sync, V: CredentialVault> SchoolClient<T, V> {
    async fn fetch_teaching_evaluation_with_recovery(
        &self,
        owner: &super::session_service::AccountOwner,
    ) -> Result<TeachingEvaluationReport, AppError> {
        let canonical_id = self
            .identity
            .lock()
            .authenticated
            .as_ref()
            .filter(|u| u.account == owner.account)
            .map(|u| u.profile.school_id.trim().to_owned())
            .filter(|s| !s.is_empty())
            .unwrap_or_else(|| owner.account.clone());
        let first = evaluation_http::load(&self.session, &canonical_id, || {
            self.check_account_owner(owner)
        })
        .await;
        match first {
            Err(err) if err.detail.as_deref() == Some("webvpn_login_required") => {
                self.ensure_webvpn_session().await?;
                self.check_account_owner(owner)?;
                evaluation_http::load(&self.session, &canonical_id, || {
                    self.check_account_owner(owner)
                })
                .await
            }
            Err(err) if err.detail.is_none() && err.code == crate::ErrorCode::SessionExpired => {
                self.silent_login().await?;
                self.check_account_owner(owner)?;
                evaluation_http::load(&self.session, &canonical_id, || {
                    self.check_account_owner(owner)
                })
                .await
            }
            other => other,
        }
    }
}

impl<T: HttpTransport + Send + Sync, V: CredentialVault> TeachingEvaluationSource
    for SchoolClient<T, V>
{
    async fn load_teaching_evaluation(
        &self,
        force_refresh: bool,
    ) -> Result<TeachingEvaluationOutcome, AppError> {
        let owner = self.account_owner()?;
        let key = owner.account.to_ascii_lowercase();
        super::cache::read_with_snapshot_checked(
            &self.snapshots.evaluation,
            key,
            force_refresh,
            self.fetch_teaching_evaluation_with_recovery(&owner),
            || self.check_account_owner(&owner),
        )
        .await
    }
}
