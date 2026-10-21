use super::session_service::SessionService;
use crate::{
    adapters::bykc_http,
    auth::CredentialVault,
    features::bykc::{Catalog, ChosenCourses, LearningStatistics},
    foundation::http::HttpTransport,
    AppError, ErrorCode,
};

pub struct BykcOutcome {
    pub data: Catalog,
    pub failure: Option<AppError>,
}
pub struct BykcChosenOutcome {
    pub data: ChosenCourses,
    pub failure: Option<AppError>,
}
pub struct BykcStatisticsOutcome {
    pub data: LearningStatistics,
    pub failure: Option<AppError>,
}
impl<T: HttpTransport + Send + Sync, V: CredentialVault> SessionService<T, V> {
    pub async fn load_bykc(&self, force: bool) -> Result<BykcOutcome, AppError> {
        self.current_account()?;
        let key = "catalog".to_owned();
        if !force {
            let cache = self.bykc.lock();
            if let Some(entry) = cache.fresh(&key) {
                return Ok(BykcOutcome {
                    data: entry.value.clone(),
                    failure: None,
                });
            }
        }
        let _access = self.bykc_access.lock().await;
        // Another queued read may have filled this snapshot while we waited.
        self.current_account()?;
        if !force {
            if let Some(entry) = self.bykc.lock().fresh(&key) {
                return Ok(BykcOutcome {
                    data: entry.value.clone(),
                    failure: None,
                });
            }
        }
        let mut result = bykc_http::load(&self.session).await;
        if result
            .as_ref()
            .is_err_and(|e| e.code == ErrorCode::SessionExpired)
        {
            result = match self.silent_login().await {
                Ok(()) => bykc_http::load(&self.session).await,
                Err(e) => Err(e),
            };
        }
        match result {
            Ok(data) => {
                self.bykc.lock().insert(key, data.clone());
                Ok(BykcOutcome {
                    data,
                    failure: None,
                })
            }
            Err(error) => {
                let cache = self.bykc.lock();
                match cache.any(&key) {
                    Some(entry) => Ok(BykcOutcome {
                        data: entry.value.clone(),
                        failure: Some(error),
                    }),
                    None => Err(error),
                }
            }
        }
    }

    pub async fn load_bykc_chosen(&self, force: bool) -> Result<BykcChosenOutcome, AppError> {
        self.current_account()?;
        let key = "chosen".to_owned();
        if !force {
            if let Some(entry) = self.bykc_chosen.lock().fresh(&key) {
                return Ok(BykcChosenOutcome {
                    data: entry.value.clone(),
                    failure: None,
                });
            }
        }
        let _access = self.bykc_access.lock().await;
        // Another queued read may have filled this snapshot while we waited.
        self.current_account()?;
        if !force {
            if let Some(entry) = self.bykc_chosen.lock().fresh(&key) {
                return Ok(BykcChosenOutcome {
                    data: entry.value.clone(),
                    failure: None,
                });
            }
        }
        let mut result = bykc_http::load_chosen(&self.session).await;
        if result
            .as_ref()
            .is_err_and(|error| error.code == ErrorCode::SessionExpired)
        {
            result = match self.silent_login().await {
                Ok(()) => bykc_http::load_chosen(&self.session).await,
                Err(error) => Err(error),
            };
        }
        match result {
            Ok(data) => {
                self.bykc_chosen.lock().insert(key, data.clone());
                Ok(BykcChosenOutcome {
                    data,
                    failure: None,
                })
            }
            Err(error) => match self.bykc_chosen.lock().any(&key) {
                Some(entry) => Ok(BykcChosenOutcome {
                    data: entry.value.clone(),
                    failure: Some(error),
                }),
                None => Err(error),
            },
        }
    }

    pub async fn load_bykc_statistics(
        &self,
        force: bool,
    ) -> Result<BykcStatisticsOutcome, AppError> {
        self.current_account()?;
        let key = "statistics".to_owned();
        if !force {
            if let Some(entry) = self.bykc_statistics.lock().fresh(&key) {
                return Ok(BykcStatisticsOutcome {
                    data: entry.value.clone(),
                    failure: None,
                });
            }
        }
        let _access = self.bykc_access.lock().await;
        // Another queued read may have filled this snapshot while we waited.
        self.current_account()?;
        if !force {
            if let Some(entry) = self.bykc_statistics.lock().fresh(&key) {
                return Ok(BykcStatisticsOutcome {
                    data: entry.value.clone(),
                    failure: None,
                });
            }
        }
        let mut result = bykc_http::load_statistics(&self.session).await;
        if result
            .as_ref()
            .is_err_and(|error| error.code == ErrorCode::SessionExpired)
        {
            result = match self.silent_login().await {
                Ok(()) => bykc_http::load_statistics(&self.session).await,
                Err(error) => Err(error),
            };
        }
        match result {
            Ok(data) => {
                self.bykc_statistics.lock().insert(key, data.clone());
                Ok(BykcStatisticsOutcome {
                    data,
                    failure: None,
                })
            }
            Err(error) => match self.bykc_statistics.lock().any(&key) {
                Some(entry) => Ok(BykcStatisticsOutcome {
                    data: entry.value.clone(),
                    failure: Some(error),
                }),
                None => Err(error),
            },
        }
    }
}
