use super::session_service::SessionService;
use crate::{
    adapters::graduate_http, auth::CredentialVault, features::graduate::AcademicData,
    foundation::http::HttpTransport, AppError, ErrorCode,
};
pub struct GraduateOutcome {
    pub data: AcademicData,
    pub failure: Option<AppError>,
}
#[derive(Debug, Clone, Copy)]
pub enum GraduatePart {
    Status,
    Report,
}
impl GraduatePart {
    fn key(self) -> &'static str {
        match self {
            Self::Status => "status",
            Self::Report => "report",
        }
    }
    async fn load<T: HttpTransport>(
        self,
        session: &crate::auth::session::Session<T>,
        account: &str,
    ) -> Result<AcademicData, AppError> {
        match self {
            Self::Status => graduate_http::load_status(session, account).await,
            Self::Report => graduate_http::load_report(session, account).await,
        }
    }
}
impl<T: HttpTransport + Send + Sync, V: CredentialVault> SessionService<T, V> {
    pub async fn load_graduate(&self, force: bool) -> Result<GraduateOutcome, AppError> {
        let mut status = self.load_graduate_part(GraduatePart::Status, force).await?;
        let report = self.load_graduate_part(GraduatePart::Report, force).await?;
        status.data.sections.extend(report.data.sections);
        status.data.notice = report.data.notice;
        status.failure = status.failure.or(report.failure);
        Ok(status)
    }

    pub async fn load_graduate_part(
        &self,
        part: GraduatePart,
        force: bool,
    ) -> Result<GraduateOutcome, AppError> {
        // GSMIS applications share cookies and recovery. Stage their SSO chains
        // to avoid concurrent CAS activation; each completed part is published
        // immediately and cached independently by the caller.
        let _gate = self.graduate_request_gate.lock().await;
        let account = self.current_account()?;
        let key = part.key().to_owned();
        if !force {
            let cache = self.graduate.lock().expect("graduate cache");
            if let Some(entry) = cache.fresh(&key) {
                return Ok(GraduateOutcome {
                    data: entry.value.clone(),
                    failure: None,
                });
            }
        }
        let mut result = part.load(&self.session, &account).await;
        if result
            .as_ref()
            .is_err_and(|e| e.code == ErrorCode::SessionExpired)
        {
            result = match self.silent_login().await {
                Ok(()) => part.load(&self.session, &account).await,
                Err(e) => Err(e),
            };
        }
        match result {
            Ok(data) => {
                self.graduate
                    .lock()
                    .expect("graduate cache")
                    .insert(key, data.clone());
                Ok(GraduateOutcome {
                    data,
                    failure: None,
                })
            }
            Err(error) => {
                let cache = self.graduate.lock().expect("graduate cache");
                match cache.any(&key) {
                    Some(entry) => Ok(GraduateOutcome {
                        data: entry.value.clone(),
                        failure: Some(error),
                    }),
                    None => Err(error),
                }
            }
        }
    }
}
