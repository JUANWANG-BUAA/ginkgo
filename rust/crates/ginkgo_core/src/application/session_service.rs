//! Long-lived account session used by the Android/Windows mirror.
//!
//! One `SessionService` owns the cookie jar, the platform credential vault and
//! every read snapshot. Flutter only sees coarse outcomes; cookies, passwords
//! and recovery stay here.
use super::{
    cache::SnapshotCache,
    schedule_service::{GradeData, ScheduleData},
};
use crate::{
    auth::{
        self,
        cas::CaptchaChallenge,
        session::{RouteMode, Session},
        CredentialVault, Credentials, LoginPage, LoginResult, UserProfile,
    },
    features::{classroom::Room, today::TodayCourse},
    foundation::http::HttpTransport,
    AppError, ErrorCode,
};
use std::{collections::BTreeMap, sync::Mutex};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RoutePreference {
    Automatic,
    Direct,
    WebVpn,
}

impl From<RoutePreference> for RouteMode {
    fn from(value: RoutePreference) -> Self {
        match value {
            RoutePreference::Automatic => RouteMode::Automatic,
            RoutePreference::Direct => RouteMode::Direct,
            RoutePreference::WebVpn => RouteMode::WebVpn,
        }
    }
}

pub(crate) type ClassroomCache = SnapshotCache<(i32, String), BTreeMap<String, Vec<Room>>>;
pub(crate) type ScheduleCache = SnapshotCache<Option<i32>, ScheduleData>;
pub(crate) type TodayCache = SnapshotCache<String, Vec<TodayCourse>>;
pub(crate) type GradeCache = SnapshotCache<String, GradeData>;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SessionStatus {
    pub account: Option<String>,
    pub profile: Option<UserProfile>,
    pub route: RoutePreference,
}

impl SessionStatus {
    pub fn signed_in(&self) -> bool {
        self.account.is_some() && self.profile.is_some()
    }
}

#[derive(Debug)]
pub enum SessionOutcome {
    SignedIn {
        profile: UserProfile,
        remembered: bool,
    },
    CaptchaRequired(CaptchaChallenge),
    SignedOut,
}

pub struct SessionService<T: HttpTransport, V: CredentialVault> {
    pub(crate) session: Session<T>,
    pub(crate) vault: V,
    pub(crate) account: Mutex<Option<String>>,
    pub(crate) profile: Mutex<Option<UserProfile>>,
    pub(crate) pending_login: Mutex<Option<LoginPage>>,
    pub(crate) route: Mutex<RoutePreference>,
    pub(crate) classrooms: Mutex<ClassroomCache>,
    pub(crate) schedules: Mutex<ScheduleCache>,
    pub(crate) today: Mutex<TodayCache>,
    pub(crate) grades: Mutex<GradeCache>,
}

impl<T: HttpTransport + Send + Sync, V: CredentialVault> SessionService<T, V> {
    pub fn new(session: Session<T>, vault: V) -> Self {
        Self {
            session,
            vault,
            account: Mutex::new(None),
            profile: Mutex::new(None),
            pending_login: Mutex::new(None),
            route: Mutex::new(RoutePreference::Automatic),
            classrooms: Mutex::new(ClassroomCache::default()),
            schedules: Mutex::new(ScheduleCache::default()),
            today: Mutex::new(TodayCache::default()),
            grades: Mutex::new(GradeCache::default()),
        }
    }

    pub fn status(&self) -> SessionStatus {
        SessionStatus {
            account: self.account.lock().expect("account lock").clone(),
            profile: self.profile.lock().expect("profile lock").clone(),
            route: *self.route.lock().expect("route lock"),
        }
    }

    /// Route changes invalidate the cookie jars and cached snapshots, matching
    /// the Apple rule that direct and WebVPN sessions never mix.
    pub fn set_route(&self, preference: RoutePreference) {
        let changed = {
            let mut route = self.route.lock().expect("route lock");
            let changed = *route != preference;
            *route = preference;
            changed
        };
        if changed {
            self.clear_identity();
        }
        self.session.set_route(preference.into());
    }

    pub async fn sign_in(
        &self,
        account: &str,
        password: &str,
        captcha: Option<&str>,
        remember: bool,
    ) -> Result<SessionOutcome, AppError> {
        let account = account.trim();
        if account.is_empty() || password.is_empty() {
            return Err(AppError::invalid());
        }
        if self
            .account
            .lock()
            .expect("account lock")
            .as_deref()
            .is_some_and(|current| current != account)
        {
            self.clear_identity();
        }
        self.session.set_route(self.preference().into());
        let credentials = Credentials {
            username: account.to_owned(),
            password: password.to_owned(),
            captcha_text: captcha
                .map(str::trim)
                .filter(|value| !value.is_empty())
                .map(str::to_owned),
        };
        let pending = { self.pending_login.lock().expect("pending login").take() };
        let page = match pending {
            Some(page) => page,
            None => auth::fetch_login_page(&self.session).await?,
        };
        let retry_page = page.clone();
        match auth::complete_login(&self.session, &credentials, page).await {
            Ok(LoginResult::CaptchaRequired(challenge)) => {
                *self.pending_login.lock().expect("pending login") = Some(retry_page);
                Ok(SessionOutcome::CaptchaRequired(challenge))
            }
            Ok(LoginResult::SignedIn(profile)) => {
                let remembered = if remember {
                    self.vault.save(account, &credentials).is_ok()
                } else {
                    let _ = self.vault.delete(account);
                    false
                };
                self.clear_caches();
                *self.pending_login.lock().expect("pending login") = None;
                *self.account.lock().expect("account lock") = Some(account.to_owned());
                *self.profile.lock().expect("profile lock") = Some(profile.clone());
                Ok(SessionOutcome::SignedIn {
                    profile,
                    remembered,
                })
            }
            Err(error) => {
                *self.pending_login.lock().expect("pending login") = None;
                Err(error)
            }
        }
    }

    /// Restore after process start. The in-memory cookies are validated first;
    /// a saved account is only re-logged-in when that confirmation fails.
    pub async fn restore(&self) -> Result<SessionOutcome, AppError> {
        self.session.set_route(self.preference().into());
        let has_identity = self.account.lock().expect("account lock").is_some()
            && self.profile.lock().expect("profile lock").is_some();
        let has_cookies =
            self.session.direct_cookie_present() || self.session.webvpn_cookie_present();
        if has_identity && has_cookies {
            match auth::validate_session(&self.session).await {
                Ok(profile) => {
                    *self.profile.lock().expect("profile lock") = Some(profile.clone());
                    return Ok(SessionOutcome::SignedIn {
                        profile,
                        remembered: true,
                    });
                }
                Err(error) if error.code == ErrorCode::SessionExpired => {}
                Err(error) => return Err(error),
            }
        }

        let accounts = match self.vault.accounts() {
            Ok(accounts) => accounts,
            Err(_) => return Ok(SessionOutcome::SignedOut),
        };
        for account in accounts.into_iter().take(5) {
            let credentials = match self.vault.load(&account) {
                Ok(Some(credentials)) => credentials,
                Ok(None) | Err(_) => continue,
            };
            let page = auth::fetch_login_page(&self.session).await?;
            match auth::complete_login(&self.session, &credentials, page.clone()).await {
                Ok(LoginResult::SignedIn(profile)) => {
                    self.clear_caches();
                    *self.account.lock().expect("account lock") = Some(credentials.username);
                    *self.profile.lock().expect("profile lock") = Some(profile.clone());
                    return Ok(SessionOutcome::SignedIn {
                        profile,
                        remembered: true,
                    });
                }
                Ok(LoginResult::CaptchaRequired(challenge)) => {
                    *self.pending_login.lock().expect("pending login") = Some(page);
                    return Ok(SessionOutcome::CaptchaRequired(challenge));
                }
                Err(error) if error.code == ErrorCode::InvalidCredentials => {
                    let _ = self.vault.delete(&account);
                }
                Err(error) => return Err(error),
            }
        }
        Ok(SessionOutcome::SignedOut)
    }

    /// Best-effort upstream logout; local identity and snapshots are always
    /// cleared and the saved password is removed.
    pub async fn sign_out(&self) {
        let account = self.account.lock().expect("account lock").take();
        let _ = auth::logout(&self.session).await;
        if let Some(account) = &account {
            let _ = self.vault.delete(account);
        }
        self.clear_identity();
    }

    /// Diagnostic used by device acceptance: write, read back and remove one
    /// synthetic credential. The reserved prefix prevents this call from ever
    /// replacing or deleting a real saved account.
    pub fn verify_vault_round_trip(&self, account: &str, secret: &str) -> bool {
        auth::vault::verify_vault_round_trip(&self.vault, account, secret)
    }

    pub(crate) fn preference(&self) -> RoutePreference {
        *self.route.lock().expect("route lock")
    }

    pub(crate) fn current_account(&self) -> Result<String, AppError> {
        if !self.status().signed_in() {
            return Err(AppError::session_expired());
        }
        self.account
            .lock()
            .expect("account lock")
            .clone()
            .ok_or_else(AppError::session_expired)
    }

    pub(crate) async fn silent_login(&self) -> Result<(), AppError> {
        let account = self.current_account()?;
        let credentials = self
            .vault
            .load(&account)?
            .ok_or_else(AppError::session_expired)?;
        match auth::login(&self.session, &credentials).await? {
            LoginResult::SignedIn(profile) => {
                *self.profile.lock().expect("profile lock") = Some(profile);
                Ok(())
            }
            LoginResult::CaptchaRequired(_) => Err(AppError::new(ErrorCode::CaptchaRequired)),
        }
    }

    /// Clear all read snapshots without touching credentials or the session.
    pub fn clear_snapshots(&self) {
        self.clear_caches();
    }

    pub(crate) fn clear_caches(&self) {
        self.classrooms.lock().expect("classroom cache").clear();
        self.schedules.lock().expect("schedule cache").clear();
        self.today.lock().expect("today cache").clear();
        self.grades.lock().expect("grade cache").clear();
    }

    fn clear_identity(&self) {
        self.session.clear_cookies();
        *self.pending_login.lock().expect("pending login") = None;
        *self.account.lock().expect("account lock") = None;
        *self.profile.lock().expect("profile lock") = None;
        self.clear_caches();
    }
}

/// The mirror only reads; retrying a read after a confirmed expired session is
/// safe and bounded to one login plus one retry.
pub(crate) fn is_recoverable(error: &AppError) -> bool {
    error.code == ErrorCode::ServiceUnavailable || error.code == ErrorCode::ChangedResponse
}
