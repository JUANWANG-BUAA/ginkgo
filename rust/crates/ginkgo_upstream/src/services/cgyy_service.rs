use super::SchoolClient;
use crate::{
    adapters::cgyy_http, auth::CredentialVault, codecs::cgyy, foundation::http::HttpTransport,
    AppError, ErrorCode,
};
pub use ginkgo_domain::ports::CgyyOutcome;
use ginkgo_domain::ports::*;
use ginkgo_domain::ports::{CgyyData, CgyyQuery};
impl<T: HttpTransport + Send + Sync, V: CredentialVault> SchoolClient<T, V> {
    pub(super) async fn cgyy_token(&self, renew: bool) -> Result<String, AppError> {
        let owner = self.account_owner()?;
        {
            let identity = self.identity.lock();
            if identity.generation != owner.generation {
                return Err(AppError::session_expired());
            }
            if !renew {
                if let Some(token) = identity.cgyy_token.clone() {
                    return Ok(token);
                }
            }
        }
        let credentials = self.vault.load(&owner.account)?;
        let token = cgyy_http::login(&self.session, credentials.as_ref()).await?;
        self.check_account_owner(&owner)?;
        let mut identity = self.identity.lock();
        // Recheck while holding the publication lock.
        if identity.generation != owner.generation {
            return Err(AppError::session_expired());
        }
        identity.cgyy_token = Some(token.clone());
        Ok(token)
    }
}
impl<T: HttpTransport + Send + Sync, V: CredentialVault> CgyySource for SchoolClient<T, V> {
    async fn load_cgyy(&self, query: CgyyQuery, force: bool) -> Result<CgyyOutcome, AppError> {
        let (kind, site, date) = match &query {
            CgyyQuery::Venues => ("venues", 0, ""),
            CgyyQuery::Day { site_id, date } => ("day", *site_id, date.as_str()),
            CgyyQuery::Orders => ("orders", 0, ""),
            CgyyQuery::Order { order_id } => ("order", *order_id, ""),
            CgyyQuery::LockCode => ("lockCode", 0, ""),
        };
        if kind == "day"
            && (site <= 0 || chrono::NaiveDate::parse_from_str(date, "%Y-%m-%d").is_err())
        {
            return Err(AppError::invalid());
        }
        if kind == "order" && site <= 0 {
            return Err(AppError::invalid());
        }
        if kind != "venues" {
            self.current_account()?;
        }
        if matches!(query, CgyyQuery::Order { .. } | CgyyQuery::LockCode) {
            let owner = self.account_owner()?;
            let (value, _) = self.load_booking_read(&owner, kind, site, date).await?;
            self.check_account_owner(&owner)?;
            let data = if kind == "order" {
                CgyyData::Order(cgyy::order(&value)?)
            } else {
                CgyyData::LockCode(cgyy::lock_code(&value)?)
            };
            return Ok(CgyyOutcome {
                data,
                failure: None,
            });
        }
        let key = format!("{kind}:{site}:{date}");
        if !force {
            if let Some(entry) = self.snapshots.cgyy.lock().fresh(&key) {
                return Ok(CgyyOutcome {
                    data: entry.value.clone(),
                    failure: None,
                });
            }
        }
        let ticket = self.snapshots.cgyy.lock().begin(&key);
        let result = async {
            let token = if kind == "venues" {
                None
            } else {
                Some(self.cgyy_token(false).await?)
            };
            let mut result =
                cgyy_http::load(&self.session, kind, site, date, token.as_deref()).await;
            if kind != "venues"
                && result
                    .as_ref()
                    .is_err_and(|e| e.code == ErrorCode::SessionExpired)
            {
                self.identity.lock().cgyy_token = None;
                result = match self.cgyy_token(true).await {
                    Ok(token) => {
                        cgyy_http::load(&self.session, kind, site, date, Some(&token)).await
                    }
                    Err(e) => Err(e),
                };
            }
            let value = result?;
            match kind {
                "venues" => Ok(CgyyData::Venues(cgyy::sites(&value)?)),
                "day" => Ok(CgyyData::Day(cgyy::day(&value, site, date)?)),
                _ => Ok(CgyyData::Orders(cgyy::orders(&value)?)),
            }
        }
        .await;
        self.snapshots
            .cgyy
            .lock()
            .resolve_current(key, ticket, result)
    }
}
