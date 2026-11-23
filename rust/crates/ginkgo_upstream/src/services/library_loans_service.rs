//! Explicit private reads: no snapshots, background fetch, profile fetch or disk.
use super::SchoolClient;
use crate::{
    adapters::library_loans_http, auth::CredentialVault, foundation::http::HttpTransport, AppError,
};
use ginkgo_domain::{features::library_loans::LibraryLoanPage, ports::LibraryLoansSource};
impl<T: HttpTransport + Send + Sync, V: CredentialVault> SchoolClient<T, V> {
    async fn read_library_loans_once(
        &self,
        owner: &super::session_service::AccountOwner,
        page: u32,
    ) -> Result<LibraryLoanPage, AppError> {
        library_loans_http::establish(&self.session).await?;
        self.check_account_owner(owner)?;
        let result = library_loans_http::load(&self.session, page).await;
        self.check_account_owner(owner)?;
        result
    }
}

impl<T: HttpTransport + Send + Sync, V: CredentialVault> LibraryLoansSource for SchoolClient<T, V> {
    async fn library_loans(&self, page: u32) -> Result<LibraryLoanPage, AppError> {
        if !(1..=100).contains(&page) {
            return Err(AppError::invalid());
        }
        let owner = self.account_owner()?;
        match self.read_library_loans_once(&owner, page).await {
            Err(error) if error.detail.as_deref() == Some("webvpn_login_required") => {
                self.ensure_webvpn_session().await?;
                self.check_account_owner(&owner)?;
                self.read_library_loans_once(&owner, page).await
            }
            other => other,
        }
    }
}
