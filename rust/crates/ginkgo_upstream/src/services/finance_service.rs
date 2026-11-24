//! On-demand student income service: no snapshot persistence, no logs, strict owner checks.
use super::{session_service::SchoolClient, AppError};
use crate::{adapters::finance_http, auth::CredentialVault, foundation::http::HttpTransport};
use ginkgo_domain::{features::finance::FinanceIncomeReport, ports::FinanceIncomeSource};

impl<T: HttpTransport + Send + Sync, V: CredentialVault> SchoolClient<T, V> {
    async fn read_finance_incomes_once(
        &self,
        owner: &super::session_service::AccountOwner,
    ) -> Result<FinanceIncomeReport, AppError> {
        let credential = finance_http::authenticate(&self.session, &owner.account).await?;
        self.check_account_owner(owner)?;
        let (entries, total) = finance_http::fetch_all_pages(&self.session, &credential, || {
            self.check_account_owner(owner)
        })
        .await?;
        self.check_account_owner(owner)?;
        Ok(FinanceIncomeReport {
            entries,
            total,
            fetched_at: super::cache::now_shanghai(),
        })
    }
}

impl<T: HttpTransport + Send + Sync, V: CredentialVault> FinanceIncomeSource
    for SchoolClient<T, V>
{
    async fn finance_incomes(&self) -> Result<FinanceIncomeReport, AppError> {
        let owner = self.account_owner()?;
        let first = self.read_finance_incomes_once(&owner).await;
        match first {
            Err(error) if error.detail.as_deref() == Some("webvpn_login_required") => {
                self.ensure_webvpn_session().await?;
                self.check_account_owner(&owner)?;
                self.read_finance_incomes_once(&owner).await
            }
            Err(error)
                if error.detail.is_none() && error.code == crate::ErrorCode::SessionExpired =>
            {
                self.silent_login().await?;
                self.check_account_owner(&owner)?;
                self.read_finance_incomes_once(&owner).await
            }
            other => other,
        }
    }
}
