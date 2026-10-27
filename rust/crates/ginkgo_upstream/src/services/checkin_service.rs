//! iclass check-in read-only use case (API.md §7.2).
//!
//! The app session is cached in memory only. A confirmed business rejection or
//! an auth redirect rebuilds that session exactly once; a still-expired school
//! session triggers one silent re-login. Refresh failures keep the previous
//! day's snapshot instead of clearing the page.
use super::{cache::now_shanghai, session_service::SchoolClient};
use crate::{
    adapters::checkin_http,
    auth::CredentialVault,
    codecs::checkin::CheckInCourse,
    foundation::{http::HttpTransport, school_time},
    AppError, ErrorCode,
};
use ginkgo_domain::ports::*;

pub use ginkgo_domain::ports::CheckInOutcome;

/// Local timing only: no account, URLs, cookies, course names or session IDs.
#[derive(Default)]
pub(crate) struct CheckInProgress {
    started: Option<std::time::Instant>,
    stage_started: Option<std::time::Instant>,
    phase: &'static str,
    stages: Vec<(&'static str, u128)>,
}

impl<T: HttpTransport + Send + Sync, V: CredentialVault> SchoolClient<T, V> {
    fn checkin_stage(&self, phase: &'static str) {
        let now = std::time::Instant::now();
        let mut progress = self.checkin_progress.lock();
        if phase == "authenticating" || (phase == "courses" && progress.started.is_none()) {
            *progress = CheckInProgress {
                started: Some(now),
                stage_started: Some(now),
                phase,
                stages: Vec::new(),
            };
            return;
        }
        if let Some(started) = progress.stage_started {
            let previous = progress.phase;
            progress
                .stages
                .push((previous, started.elapsed().as_millis()));
        }
        progress.phase = phase;
        progress.stage_started = Some(now);
    }

    async fn fetch_checkin(&self, compact: &str) -> Result<Vec<CheckInCourse>, AppError> {
        match self.try_fetch_checkin(compact).await {
            Err(error) if error.code == ErrorCode::SessionExpired => {
                // The school session may really be gone; re-confirm it once
                // through the platform credential vault, then rebuild iclass.
                self.silent_login().await?;
                self.identity.lock().iclass = None;
                self.try_fetch_checkin(compact).await
            }
            other => other,
        }
    }

    async fn try_fetch_checkin(&self, compact: &str) -> Result<Vec<CheckInCourse>, AppError> {
        let cached = { self.identity.lock().iclass.clone() };
        if let Some(iclass) = cached {
            self.checkin_stage("courses");
            match checkin_http::course_schedule(&self.session, &iclass, compact).await {
                Ok(courses) => return Ok(courses),
                // The app session is unusable; rebuild it, do not retry the
                // query against the same rejected session.
                Err(error) if error.code == ErrorCode::BusinessRejected => {
                    self.identity.lock().iclass = None;
                }
                Err(error) => return Err(error),
            }
        }
        let iclass = self.establish_iclass().await?;
        // Swift's currentSession caches immediately after app login succeeds.
        // A temporary course-read failure does not invalidate that login; do
        // not repeat the SSO redirects and app login on the next user retry.
        self.identity.lock().iclass = Some(iclass.clone());
        self.checkin_stage("courses");
        let result = checkin_http::course_schedule(&self.session, &iclass, compact).await;
        if result.as_ref().is_err_and(|error| {
            matches!(
                error.code,
                ErrorCode::BusinessRejected | ErrorCode::SessionExpired
            )
        }) {
            self.identity.lock().iclass = None;
        }
        result
    }

    async fn establish_iclass(&self) -> Result<crate::codecs::checkin::IClassSession, AppError> {
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
    ) -> Result<crate::codecs::checkin::IClassSession, AppError> {
        self.checkin_stage("authenticating");
        let login_name = checkin_http::resolve_login_name(&self.session).await?;
        self.checkin_stage("appLogin");
        checkin_http::app_login(&self.session, &login_name).await
    }
}

impl<T: HttpTransport + Send + Sync, V: CredentialVault> CheckInSource for SchoolClient<T, V> {
    fn checkin_load_progress(&self) -> CheckInLoadProgress {
        let progress = self.checkin_progress.lock();
        CheckInLoadProgress {
            phase: progress.phase.to_owned(),
            elapsed_ms: progress.started.map(|at| at.elapsed().as_millis()),
            stages: progress
                .stages
                .iter()
                .map(|(phase, milliseconds)| CheckInLoadStage {
                    phase: (*phase).to_owned(),
                    milliseconds: *milliseconds,
                })
                .collect(),
        }
    }

    async fn load_checkin(&self, force_refresh: bool) -> Result<CheckInOutcome, AppError> {
        self.load_checkin_on_date(None, force_refresh).await
    }

    /// Same read-only query as today, keyed by the requested school-local day.
    async fn load_checkin_on_date(
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
        let requested_at = std::time::Instant::now();
        if !force_refresh {
            let cached = self.snapshots.checkin.lock();
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

        // Concurrent callers can request the same uncached day at once.
        // Stage their network chains so they share one app login and
        // snapshot; fresh days above never wait for a different day's query.
        let _gate = self.checkin_request_gate.lock().await;
        if self.current_account()? != account {
            return Err(AppError::session_expired());
        }
        {
            let cached = self.snapshots.checkin.lock();
            if let Some(entry) = cached
                .fresh(&date)
                .filter(|entry| !force_refresh || entry.fetched_at >= requested_at)
            {
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

        *self.checkin_progress.lock() = CheckInProgress::default();
        let ticket = self.snapshots.checkin.lock().begin(&date);
        let fetched = self.fetch_checkin(&compact).await;
        self.checkin_stage(if fetched.is_ok() {
            "complete"
        } else {
            "failed"
        });
        if self.current_account()? != account {
            return Err(AppError::session_expired());
        }
        match fetched {
            Ok(courses) => {
                let timestamp = self.snapshots.checkin.lock().insert_if_current(
                    date.clone(),
                    ticket,
                    courses.clone(),
                );
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
                    self.identity.lock().iclass = None;
                }
                let cached = self.snapshots.checkin.lock();
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
}

impl<T: HttpTransport + Send + Sync, V: CredentialVault> CheckInMutationSource
    for SchoolClient<T, V>
{
    /// Caller holds the bridge's exclusive session access for this single user action.
    /// Re-read today first: never submit an old date, ambiguous merged ID, or cached status.
    async fn submit_checkin(&self, course_id: &str) -> crate::codecs::mutation::MutationOutcome {
        use crate::codecs::{checkin::CheckInStatus, mutation::MutationOutcome};
        let snapshot = match self.load_checkin(true).await {
            Ok(snapshot) if snapshot.failure.is_none() => snapshot,
            _ => {
                return MutationOutcome::not_submitted("无法核对当天课程，未提交签到，请刷新后重试")
            }
        };
        let Some(course) = snapshot
            .courses
            .iter()
            .find(|course| course.id == course_id)
        else {
            return MutationOutcome::not_submitted("当天课程已变化，未提交签到");
        };
        if !course.sign_in_allowed || course.status != CheckInStatus::NotSigned {
            return MutationOutcome::not_submitted("课程已签到或记录待确认，未重复提交");
        }
        if !ginkgo_domain::features::checkin::sign_in_window(
            &snapshot.date,
            &course.begins_at,
            &course.ends_at,
            &now_shanghai(),
        ) {
            return MutationOutcome::not_submitted("课前 10 分钟开放签到，课程结束后不可提交");
        }
        let iclass = self.identity.lock().iclass.clone();
        let Some(iclass) = iclass else {
            return MutationOutcome::not_submitted("签到会话失效，请刷新后重试");
        };
        let result = checkin_http::sign_in(&self.session, &iclass, course_id).await;
        // Invalidate only this module; subsequent reads must contact upstream.
        self.snapshots.checkin.lock().clear();
        result
    }
}
