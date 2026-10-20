//! iclass check-in read-only use case (API.md §7.2).
//!
//! The app session is cached in memory only. A confirmed business rejection or
//! an auth redirect rebuilds that session exactly once; a still-expired school
//! session triggers one silent re-login. Refresh failures keep the previous
//! day's snapshot instead of clearing the page.
use super::{cache::now_shanghai, session_service::SessionService};
use crate::{
    adapters::checkin_http,
    auth::CredentialVault,
    features::checkin::CheckInCourse,
    foundation::{http::HttpTransport, school_time},
    AppError, ErrorCode,
};

#[derive(Debug, Clone)]
pub struct CheckInOutcome {
    /// School-local date, yyyy-MM-dd.
    pub date: String,
    pub courses: Vec<CheckInCourse>,
    pub fetched_at: String,
    pub from_cache: bool,
    pub stale: bool,
    pub failure: Option<AppError>,
}

impl<T: HttpTransport + Send + Sync, V: CredentialVault> SessionService<T, V> {
    pub async fn load_checkin(&self, force_refresh: bool) -> Result<CheckInOutcome, AppError> {
        self.load_checkin_on_date(None, force_refresh).await
    }

    /// Same read-only query as today, keyed by the requested school-local day.
    pub async fn load_checkin_on_date(
        &self,
        date: Option<String>,
        force_refresh: bool,
    ) -> Result<CheckInOutcome, AppError> {
        let account = self.current_account()?;
        let today = school_time::beijing_day(&now_shanghai())?.local_date;
        let date = match date {
            Some(date) => {
                let parsed = chrono::NaiveDate::parse_from_str(&date, "%Y-%m-%d")
                    .map_err(|_| AppError::invalid())?;
                if parsed.format("%Y-%m-%d").to_string() != date || date > today {
                    return Err(AppError::invalid());
                }
                date
            }
            None => today,
        };
        let compact = date.replace('-', "");
        if !force_refresh {
            let cached = self.checkin.lock().expect("checkin cache");
            if let Some(entry) = cached.fresh(&date) {
                return Ok(CheckInOutcome {
                    date,
                    courses: entry.value.clone(),
                    fetched_at: entry.timestamp.clone(),
                    from_cache: true,
                    stale: false,
                    failure: None,
                });
            }
        }

        let fetched = self.fetch_checkin(&compact).await;
        if self.current_account()? != account {
            return Err(AppError::session_expired());
        }
        match fetched {
            Ok(courses) => {
                let timestamp = self
                    .checkin
                    .lock()
                    .expect("checkin cache")
                    .insert(date.clone(), courses.clone());
                Ok(CheckInOutcome {
                    date,
                    courses,
                    fetched_at: timestamp,
                    from_cache: false,
                    stale: false,
                    failure: None,
                })
            }
            Err(error) => {
                if error.code == ErrorCode::SessionExpired {
                    *self.iclass.lock().expect("iclass session") = None;
                }
                let cached = self.checkin.lock().expect("checkin cache");
                match cached.any(&date) {
                    Some(entry) => Ok(CheckInOutcome {
                        date,
                        courses: entry.value.clone(),
                        fetched_at: entry.timestamp.clone(),
                        from_cache: true,
                        stale: true,
                        failure: Some(error),
                    }),
                    None => Err(error),
                }
            }
        }
    }

    async fn fetch_checkin(&self, compact: &str) -> Result<Vec<CheckInCourse>, AppError> {
        match self.try_fetch_checkin(compact).await {
            Err(error) if error.code == ErrorCode::SessionExpired => {
                // The school session may really be gone; re-confirm it once
                // through the platform credential vault, then rebuild iclass.
                self.silent_login().await?;
                *self.iclass.lock().expect("iclass session") = None;
                self.try_fetch_checkin(compact).await
            }
            other => other,
        }
    }

    async fn try_fetch_checkin(&self, compact: &str) -> Result<Vec<CheckInCourse>, AppError> {
        let cached = { self.iclass.lock().expect("iclass session").clone() };
        if let Some(iclass) = cached {
            match checkin_http::course_schedule(&self.session, &iclass, compact).await {
                Ok(courses) => return Ok(courses),
                // The app session is unusable; rebuild it, do not retry the
                // query against the same rejected session.
                Err(error) if error.code == ErrorCode::BusinessRejected => {
                    *self.iclass.lock().expect("iclass session") = None;
                }
                Err(error) => return Err(error),
            }
        }
        let iclass = self.establish_iclass().await?;
        let courses = checkin_http::course_schedule(&self.session, &iclass, compact).await?;
        *self.iclass.lock().expect("iclass session") = Some(iclass);
        Ok(courses)
    }

    async fn establish_iclass(&self) -> Result<crate::features::checkin::IClassSession, AppError> {
        let first = match self.try_establish_iclass().await {
            Ok(session) => return Ok(session),
            Err(error) => error,
        };
        // The gateway needs its own CAS session. Only retry when iclass itself
        // reported that the gateway login is missing, and only with a saved
        // credential: otherwise the caller must sign in again.
        if first.detail.as_deref() != Some("webvpn_login_required") {
            return Err(first);
        }
        self.ensure_webvpn_session().await?;
        self.try_establish_iclass().await
    }

    async fn try_establish_iclass(
        &self,
    ) -> Result<crate::features::checkin::IClassSession, AppError> {
        let login_name = checkin_http::resolve_login_name(&self.session).await?;
        checkin_http::app_login(&self.session, &login_name).await
    }
}
