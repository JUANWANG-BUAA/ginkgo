use super::SessionService;
use crate::{
    adapters::cgyy_http, auth::CredentialVault, features::cgyy, foundation::http::HttpTransport,
    AppError, ErrorCode,
};
use serde_json::Value;
pub struct CgyyOutcome {
    pub data: Value,
    pub failure: Option<AppError>,
}
impl<T: HttpTransport + Send + Sync, V: CredentialVault> SessionService<T, V> {
    async fn cgyy_token(&self, renew: bool) -> Result<String, AppError> {
        let account = self.current_account()?;
        if !renew {
            if let Some(token) = self.identity.lock().cgyy_token.clone() {
                return Ok(token);
            }
        }
        let credentials = self.vault.load(&account)?;
        let token = cgyy_http::login(&self.session, credentials.as_ref()).await?;
        self.identity.lock().cgyy_token = Some(token.clone());
        Ok(token)
    }
    pub async fn load_cgyy(
        &self,
        kind: &str,
        site: i64,
        date: &str,
        force: bool,
    ) -> Result<CgyyOutcome, AppError> {
        if !["venues", "day", "orders"].contains(&kind) {
            return Err(AppError::invalid());
        }
        if kind == "day"
            && (site <= 0 || chrono::NaiveDate::parse_from_str(date, "%Y-%m-%d").is_err())
        {
            return Err(AppError::invalid());
        }
        if kind != "venues" {
            self.current_account()?;
        }
        let key = format!("{kind}:{site}:{date}");
        if !force {
            if let Some(entry) = self.cgyy.lock().fresh(&key) {
                return Ok(CgyyOutcome {
                    data: entry.value.clone(),
                    failure: None,
                });
            }
        }
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
                "venues" => serde_json::to_value(cgyy::sites(&value)?),
                "day" => serde_json::to_value(cgyy::day(&value, site, date)?),
                _ => serde_json::to_value(cgyy::orders(&value)?),
            }
            .map_err(|_| AppError::changed())
        }
        .await;
        match result {
            Ok(data) => {
                self.cgyy.lock().insert(key, data.clone());
                Ok(CgyyOutcome {
                    data,
                    failure: None,
                })
            }
            Err(error) => match self.cgyy.lock().any(&key) {
                Some(entry) => Ok(CgyyOutcome {
                    data: entry.value.clone(),
                    failure: Some(error),
                }),
                None => Err(error),
            },
        }
    }
}
