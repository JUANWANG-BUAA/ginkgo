//! iclass check-in read-only use case (API.md §7.2).
//!
//! A read may rebuild the in-memory iClass session once. An iClass 401 is not
//! evidence of school expiry; only an explicit school-session failure takes
//! the silent-login path. Failed refreshes retain the day's previous snapshot.
use super::{cache::now_shanghai, session_service::SchoolClient};
use crate::{
    adapters::checkin_http,
    auth::CredentialVault,
    codecs::checkin::{CheckInCourse, IClassSession},
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
        let cached = self.identity.lock().iclass.clone();
        let had_cached_session = cached.is_some();
        let error = match self.read_checkin_once(compact, cached).await {
            Ok(courses) => return Ok(courses),
            Err(error) => error,
        };
        match error.detail.as_deref() {
            // Neither a rejected module session nor a verified route change
            // calls for a UC probe or password submission.
            Some("iclass_session" | "route_changed") => {}
            Some("webvpn_login_required") => self.ensure_webvpn_session().await?,
            None if error.code == ErrorCode::SessionExpired => self.silent_login().await?,
            _ if had_cached_session && error.code == ErrorCode::BusinessRejected => {}
            _ => return Err(error),
        }
        self.read_checkin_once(compact, None)
            .await
            .map_err(|error| {
                if error.detail.as_deref() == Some("iclass_session") {
                    AppError::module_auth_required()
                } else {
                    error
                }
            })
    }

    async fn read_checkin_once(
        &self,
        compact: &str,
        cached: Option<IClassSession>,
    ) -> Result<Vec<CheckInCourse>, AppError> {
        let iclass = match cached {
            Some(session) => session,
            None => {
                let session = self.establish_iclass().await?;
                // A temporary course-read failure does not invalidate app login.
                self.identity.lock().iclass = Some(session.clone());
                session
            }
        };
        self.checkin_stage("courses");
        let result = checkin_http::course_schedule(&self.session, &iclass, compact).await;
        if result.as_ref().is_err_and(|error| {
            matches!(
                error.detail.as_deref(),
                Some("route_changed" | "webvpn_login_required")
            ) || matches!(
                error.code,
                ErrorCode::BusinessRejected | ErrorCode::SessionExpired
            )
        }) {
            let mut identity = self.identity.lock();
            if identity.iclass.as_ref() == Some(&iclass) {
                identity.iclass = None;
            }
        }
        result
    }

    async fn establish_iclass(&self) -> Result<IClassSession, AppError> {
        self.checkin_stage("authenticating");
        let login_name = checkin_http::resolve_login_name(&self.session).await?;
        self.checkin_stage("appLogin");
        checkin_http::app_login(&self.session, &login_name).await
    }

    /// Read-only upstream server timestamp for building QR check-in payloads.
    pub async fn fetch_checkin_timestamp(&self) -> Result<String, AppError> {
        match checkin_http::fetch_timestamp(&self.session).await {
            Ok(ts) => Ok(ts),
            Err(error) if error.detail.as_deref() == Some("webvpn_login_required") => {
                self.ensure_webvpn_session().await?;
                checkin_http::fetch_timestamp(&self.session).await
            }
            Err(error) if error.detail.is_none() && error.code == ErrorCode::SessionExpired => {
                self.silent_login().await?;
                checkin_http::fetch_timestamp(&self.session).await
            }
            Err(error) => Err(error),
        }
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

        // Only the same uncached day shares authentication and a snapshot;
        // independent dates never wait for each other's network chain.
        let day_gate = self.checkin_day_gate(&date);
        let _gate = day_gate.lock().await;
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
        let result = super::cache::read_with_snapshot_checked(
            &self.snapshots.checkin,
            date.clone(),
            true,
            async {
                let fetched = self.fetch_checkin(&compact).await;
                self.checkin_stage(if fetched.is_ok() {
                    "complete"
                } else {
                    "failed"
                });
                fetched
            },
            || {
                if self.current_account()? == account {
                    Ok(())
                } else {
                    Err(AppError::session_expired())
                }
            },
        )
        .await;
        if self.current_account()? == account
            && result
                .as_ref()
                .is_err_and(|error| error.code == ErrorCode::SessionExpired)
        {
            self.identity.lock().iclass = None;
        }
        if self.current_account()? == account
            && result.as_ref().ok().is_some_and(|snapshot| {
                snapshot
                    .failure
                    .as_ref()
                    .is_some_and(|error| error.code == ErrorCode::SessionExpired)
            })
        {
            self.identity.lock().iclass = None;
        }
        let snapshot = result?;
        Ok(CheckInOutcome {
            date,
            courses: snapshot.data,
            fetched_at: snapshot.fetched_at,
            from_cache: snapshot.from_cache,
            stale: snapshot.stale,
            failure: snapshot.failure,
        })
    }
}

impl<T: HttpTransport + Send + Sync, V: CredentialVault> CheckInQrSource for SchoolClient<T, V> {
    /// Prepare a live classroom QR matrix for WeCom / 智慧北航 scan check-in.
    ///
    /// Initial open (`revalidate_course = true`) forces a fresh day read so a
    /// stale or conflicting schedule never mints a QR code; periodic ticks
    /// inside an open QR sheet (`revalidate_course = false`) reuse the verified
    /// 5-minute day snapshot and only refresh the upstream server timestamp.
    async fn prepare_checkin_qr(
        &self,
        course_id: &str,
        revalidate_course: bool,
    ) -> Result<ginkgo_domain::features::checkin::CheckInQrTicket, AppError> {
        use crate::codecs::checkin::CheckInStatus;
        use ginkgo_domain::features::checkin::{encode_qr_matrix, sign_in_window, CheckInQrTicket};

        let course_id = course_id.trim();
        if course_id.is_empty() {
            return Err(AppError::invalid());
        }
        let account = self.current_account()?;
        let snapshot = self.load_checkin(revalidate_course).await?;
        if self.current_account()? != account {
            return Err(AppError::session_expired());
        }
        if let Some(failure) = snapshot.failure {
            return Err(failure);
        }
        if snapshot.stale {
            return Err(AppError::unavailable());
        }
        let Some(course) = snapshot
            .courses
            .iter()
            .find(|course| course.id == course_id)
        else {
            return Err(AppError::with_detail(
                ErrorCode::BusinessRejected,
                "course_changed",
            ));
        };
        if course.status == CheckInStatus::Signed {
            return Err(AppError::with_detail(
                ErrorCode::BusinessRejected,
                "already_signed",
            ));
        }
        if !course.sign_in_allowed
            || course.conflicting
            || course.status != CheckInStatus::NotSigned
        {
            return Err(AppError::with_detail(
                ErrorCode::BusinessRejected,
                "status_unconfirmed",
            ));
        }
        let now = now_shanghai();
        if !sign_in_window(&snapshot.date, &course.begins_at, &course.ends_at, &now) {
            return Err(AppError::with_detail(
                ErrorCode::BusinessRejected,
                "outside_window",
            ));
        }
        let timestamp = self.fetch_checkin_timestamp().await?;
        if self.current_account()? != account {
            return Err(AppError::session_expired());
        }
        let url = checkin_http::classroom_qr_url(course_id, &timestamp)?;
        let (matrix_size, modules) = encode_qr_matrix(&url).map_err(|()| AppError::invalid())?;
        Ok(CheckInQrTicket {
            course_id: course_id.to_owned(),
            fetched_at: now_shanghai(),
            refresh_seconds: 4,
            matrix_size,
            modules,
        })
    }
}
