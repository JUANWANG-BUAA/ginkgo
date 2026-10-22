//! Long-lived account session used by the Android/Windows mirror.
//!
//! One `SchoolClient` owns the cookie jar, the platform credential vault and
//! every read snapshot. Flutter only sees coarse outcomes; cookies, passwords
//! and recovery stay here.
use super::snapshots::ReadSnapshots;
use crate::{
    auth::{
        self,
        session::{RouteMode, Session},
        CredentialVault, Credentials, LoginPage, LoginResult, UserProfile,
    },
    features::checkin::IClassSession,
    foundation::http::HttpTransport,
    foundation::mutex::{lock_value, Mutex},
    AppError, ErrorCode,
};
use ginkgo_domain::ports::*;
use std::{
    sync::{
        atomic::{AtomicU64, Ordering},
        Mutex as StdMutex,
    },
    time::{Duration, Instant},
};

/// Failed automatic password authentication is shared by both school and
/// gateway recovery. User-triggered login does not consult this cooldown.
const AUTOMATIC_LOGIN_FAILURE_TTL: Duration = Duration::from_secs(60);

pub use ginkgo_domain::ports::RoutePreference;

impl From<RoutePreference> for RouteMode {
    fn from(value: RoutePreference) -> Self {
        match value {
            RoutePreference::Automatic => RouteMode::Automatic,
            RoutePreference::Direct => RouteMode::Direct,
            RoutePreference::WebVpn => RouteMode::WebVpn,
        }
    }
}

pub use ginkgo_domain::ports::SessionStatus;

pub use ginkgo_domain::ports::SessionOutcome;

/// Published together so readers never observe an account without its profile.
pub(crate) struct AuthenticatedIdentity {
    pub account: String,
    pub profile: UserProfile,
}

/// All account-scoped authentication state has one lifetime and one reset.
/// Keep secrets out of Debug/serialization; this state never crosses the bridge.
#[derive(Default)]
pub(crate) struct Identity {
    pub authenticated: Option<AuthenticatedIdentity>,
    pub pending_login: Option<LoginPage>,
    pub iclass: Option<IClassSession>,
    pub library_token: Option<String>,
    pub cgyy_token: Option<String>,
    pub cgyy_booking: Option<super::cgyy_booking_service::BookingContext>,
    pub generation: u64,
}

pub struct SchoolClient<T: HttpTransport, V: CredentialVault> {
    pub(crate) session: Session<T>,
    pub(crate) vault: V,
    pub(crate) identity: Mutex<Identity>,
    pub(crate) route: StdMutex<RoutePreference>,
    pub(crate) snapshots: ReadSnapshots,
    pub(crate) bykc_access: tokio::sync::Mutex<()>,
    pub(crate) checkin_request_gate: tokio::sync::Mutex<()>,
    pub(crate) checkin_progress: Mutex<super::checkin_service::CheckInProgress>,
    recovery_gate: tokio::sync::Mutex<()>,
    pub(crate) automatic_login_failure: Mutex<Option<(Instant, AppError)>>,
    school_generation: AtomicU64,
    gateway_generation: AtomicU64,
    pub(crate) graduate_request_gate: tokio::sync::Mutex<()>,
    pub(crate) library_login_gate: tokio::sync::Mutex<()>,
    // In-memory safety journal, deliberately outside the resettable Identity.
    pub(crate) cgyy_safety:
        Mutex<std::collections::BTreeMap<String, super::cgyy_booking_service::BookingSafety>>,
    pub(crate) cgyy_mutation_gate: tokio::sync::Mutex<()>,
}

impl<T: HttpTransport + Send + Sync, V: CredentialVault> SchoolClient<T, V> {
    pub fn new(session: Session<T>, vault: V) -> Self {
        Self {
            session,
            vault,
            identity: Mutex::default(),
            snapshots: ReadSnapshots::default(),
            route: StdMutex::new(RoutePreference::Automatic),
            bykc_access: tokio::sync::Mutex::new(()),
            checkin_request_gate: tokio::sync::Mutex::new(()),
            checkin_progress: Mutex::default(),
            recovery_gate: tokio::sync::Mutex::new(()),
            automatic_login_failure: Mutex::new(None),
            school_generation: AtomicU64::new(0),
            gateway_generation: AtomicU64::new(0),
            graduate_request_gate: tokio::sync::Mutex::new(()),
            library_login_gate: tokio::sync::Mutex::new(()),
            cgyy_safety: Mutex::default(),
            cgyy_mutation_gate: tokio::sync::Mutex::new(()),
        }
    }

    pub(crate) fn set_authenticated(&self, account: String, profile: UserProfile) {
        let mut identity = self.identity.lock();
        *identity = Identity {
            generation: identity.generation.wrapping_add(1),
            authenticated: Some(AuthenticatedIdentity { account, profile }),
            ..Identity::default()
        };
    }

    fn update_profile(&self, account: &str, profile: UserProfile) -> Result<(), AppError> {
        let mut identity = self.identity.lock();
        let user = identity
            .authenticated
            .as_mut()
            .filter(|user| user.account == account)
            .ok_or_else(AppError::session_expired)?;
        user.profile = profile;
        Ok(())
    }

    /// Diagnostic used by device acceptance: write, read back and remove one
    /// synthetic credential. The reserved prefix prevents this call from ever
    /// replacing or deleting a real saved account.
    pub fn verify_vault_round_trip(&self, account: &str, secret: &str) -> bool {
        auth::vault::verify_vault_round_trip(&self.vault, account, secret)
    }

    pub(crate) fn preference(&self) -> RoutePreference {
        *lock_value(&self.route)
    }

    pub(crate) fn current_account(&self) -> Result<String, AppError> {
        self.identity
            .lock()
            .authenticated
            .as_ref()
            .map(|user| user.account.clone())
            .ok_or_else(AppError::session_expired)
    }

    pub(crate) async fn silent_login(&self) -> Result<(), AppError> {
        let generation = self.school_generation.load(Ordering::Acquire);
        let _recovery = self.recovery_gate.lock().await;
        if self.school_generation.load(Ordering::Acquire) != generation {
            return Ok(());
        }
        self.check_automatic_login_failure()?;
        let owner = self.booking_owner()?;
        let account = owner.account.clone();
        let credentials = self
            .vault
            .load(&account)?
            .ok_or_else(AppError::session_expired)?;
        let result = match auth::login(&self.session, &credentials).await {
            Ok(LoginResult::SignedIn(profile)) => {
                {
                    let mut identity = self.identity.lock();
                    if identity.generation != owner.generation {
                        return Err(AppError::session_expired());
                    }
                    let user = identity
                        .authenticated
                        .as_mut()
                        .filter(|u| u.account == account)
                        .ok_or_else(AppError::session_expired)?;
                    user.profile = profile;
                    identity.generation = identity.generation.wrapping_add(1);
                    identity.cgyy_booking = None;
                    identity.cgyy_token = None;
                }
                self.school_generation.fetch_add(1, Ordering::Release);
                Ok(())
            }
            Ok(LoginResult::CaptchaRequired(_)) => Err(AppError::new(ErrorCode::CaptchaRequired)),
            Err(error) => Err(error),
        };
        self.record_automatic_login_result(&result);
        result
    }

    /// Establish the WebVPN gateway's own CAS session after an automatic route
    /// fallback. Requires a saved credential: without one the caller must sign
    /// in again. On failure the route returns to Automatic so the gateway can
    /// never leave every later request stranded.
    pub(crate) async fn ensure_webvpn_session(&self) -> Result<(), AppError> {
        let generation = self.gateway_generation.load(Ordering::Acquire);
        let _recovery = self.recovery_gate.lock().await;
        if self.gateway_generation.load(Ordering::Acquire) != generation {
            return Ok(());
        }
        if let Err(error) = self.check_automatic_login_failure() {
            self.session.set_route(RouteMode::Automatic);
            return Err(error);
        }
        // Called after an explicit gateway challenge. A cookie may be only
        // the pre-login gateway session, not proof of authenticated access.
        let account = self.current_account()?;
        let credentials = self
            .vault
            .load(&account)?
            .ok_or_else(AppError::session_expired)?;
        let result = auth::establish_webvpn_session(&self.session, &credentials).await;
        if result.is_err() {
            self.session.set_route(RouteMode::Automatic);
        } else {
            self.gateway_generation.fetch_add(1, Ordering::Release);
        }
        self.record_automatic_login_result(&result);
        result
    }

    fn check_automatic_login_failure(&self) -> Result<(), AppError> {
        let failure = self.automatic_login_failure.lock();
        match failure.as_ref() {
            Some((at, error)) if at.elapsed() < AUTOMATIC_LOGIN_FAILURE_TTL => Err(error.clone()),
            _ => Ok(()),
        }
    }

    fn record_automatic_login_result(&self, result: &Result<(), AppError>) {
        *self.automatic_login_failure.lock() = result
            .as_ref()
            .err()
            .map(|error| (Instant::now(), error.clone()));
    }

    fn clear_automatic_login_failure(&self) {
        *self.automatic_login_failure.lock() = None;
    }

    pub(crate) fn clear_caches(&self) {
        self.snapshots.clear();
        {
            let mut identity = self.identity.lock();
            identity.cgyy_token = None;
            identity.cgyy_booking = None;
        }
        *self.checkin_progress.lock() = Default::default();
    }

    fn clear_identity(&self) {
        {
            let mut identity = self.identity.lock();
            *identity = Identity {
                generation: identity.generation.wrapping_add(1),
                ..Identity::default()
            };
        }
        self.clear_automatic_login_failure();
        self.session.clear_cookies();
        self.clear_caches();
    }
}

/// booking.lib answers 200 with its own login-expired message; that only means
/// the business token is stale, not that the school session is gone.
pub(crate) fn is_library_login_error(error: &AppError) -> bool {
    error.code == ErrorCode::SessionExpired && error.detail.as_deref() == Some("library_login")
}
impl<T: HttpTransport + Send + Sync, V: CredentialVault> SessionSource for SchoolClient<T, V> {
    fn status(&self) -> SessionStatus {
        let identity = self.identity.lock();
        SessionStatus {
            account: identity
                .authenticated
                .as_ref()
                .map(|user| user.account.clone()),
            profile: identity
                .authenticated
                .as_ref()
                .map(|user| user.profile.clone()),
            route: self.preference(),
        }
    }

    /// Route changes invalidate the cookie jars and cached snapshots, matching
    /// the Apple rule that direct and WebVPN sessions never mix.
    fn set_route(&self, preference: RoutePreference) {
        let changed = {
            let mut route = lock_value(&self.route);
            let changed = *route != preference;
            *route = preference;
            changed
        };
        if changed {
            self.clear_identity();
        }
        self.session.set_route(preference.into());
    }

    async fn sign_in(
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
        let switching_account = self
            .identity
            .lock()
            .authenticated
            .as_ref()
            .is_some_and(|current| current.account != account);
        if switching_account {
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
        let pending = { self.identity.lock().pending_login.take() };
        let page = match pending {
            Some(page) => page,
            None => auth::fetch_login_page(&self.session).await?,
        };
        let retry_page = page.clone();
        match auth::complete_login(&self.session, &credentials, page).await {
            Ok(LoginResult::CaptchaRequired(challenge)) => {
                self.identity.lock().pending_login = Some(retry_page);
                Ok(SessionOutcome::CaptchaRequired(challenge))
            }
            Ok(LoginResult::SignedIn(profile)) => {
                self.clear_automatic_login_failure();
                let remembered = if remember {
                    self.vault.save(account, &credentials).is_ok()
                } else {
                    let _ = self.vault.delete(account);
                    false
                };
                self.clear_caches();
                self.set_authenticated(account.to_owned(), profile.clone());
                Ok(SessionOutcome::SignedIn {
                    profile,
                    remembered,
                })
            }
            Err(error) => {
                self.identity.lock().pending_login = None;
                Err(error)
            }
        }
    }

    /// Restore after process start. The in-memory cookies are validated first;
    /// a saved account is only re-logged-in when that confirmation fails.
    async fn restore(&self) -> Result<SessionOutcome, AppError> {
        self.session.set_route(self.preference().into());
        let account = self
            .identity
            .lock()
            .authenticated
            .as_ref()
            .map(|user| user.account.clone());
        let has_cookies =
            self.session.direct_cookie_present() || self.session.webvpn_cookie_present();
        if let Some(account) = account.filter(|_| has_cookies) {
            match auth::validate_session(&self.session).await {
                Ok(profile) => {
                    self.update_profile(&account, profile.clone())?;
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
                    self.clear_automatic_login_failure();
                    self.clear_caches();
                    self.set_authenticated(credentials.username, profile.clone());
                    return Ok(SessionOutcome::SignedIn {
                        profile,
                        remembered: true,
                    });
                }
                Ok(LoginResult::CaptchaRequired(challenge)) => {
                    self.identity.lock().pending_login = Some(page);
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
    async fn sign_out(&self) {
        let account = {
            let mut identity = self.identity.lock();
            let account = identity.authenticated.take().map(|user| user.account);
            *identity = Identity {
                generation: identity.generation.wrapping_add(1),
                ..Identity::default()
            };
            account
        };
        let _ = auth::logout(&self.session).await;
        // A route change or failed restore can already have cleared identity.
        // Explicit logout must still remove saved accounts to prevent restoration.
        let mut accounts = self.vault.accounts().unwrap_or_default();
        if let Some(account) = account {
            if !accounts.contains(&account) {
                accounts.push(account);
            }
        }
        for account in accounts {
            let _ = self.vault.delete(&account);
        }
        self.clear_identity();
    }

    /// Clear all read snapshots without touching credentials or the session.
    fn clear_snapshots(&self) {
        self.clear_caches();
    }

    fn account(&self) -> Result<String, AppError> {
        self.current_account()
    }
}
