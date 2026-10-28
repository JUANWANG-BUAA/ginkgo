use super::{session_service::SchoolClient, AppError};
use crate::{adapters::campus_card_http, auth::CredentialVault, foundation::http::HttpTransport};
use ginkgo_domain::{features::campus_card::CampusCardBalance, ports::CampusCardBalanceSource};

impl<T: HttpTransport + Send + Sync, V: CredentialVault> SchoolClient<T, V> {
    async fn fetch_campus_card_balance(&self) -> Result<CampusCardBalance, AppError> {
        campus_card_http::establish(&self.session).await?;
        let card_number = campus_card_http::card_number(&self.session).await?;
        let balance_minor = campus_card_http::balance(&self.session, &card_number).await?;
        Ok(CampusCardBalance {
            balance_minor,
            fetched_at: super::cache::now_shanghai(),
        })
    }
}

impl<T: HttpTransport + Send + Sync, V: CredentialVault> CampusCardBalanceSource
    for SchoolClient<T, V>
{
    async fn campus_card_balance(&self) -> Result<CampusCardBalance, AppError> {
        let owner = self.account_owner()?;
        let result = match self.fetch_campus_card_balance().await {
            Err(error) if error.code == crate::ErrorCode::SessionExpired => {
                self.silent_login().await?;
                self.fetch_campus_card_balance().await
            }
            other => other,
        };
        self.check_account_owner(&owner)?;
        result
    }
}
