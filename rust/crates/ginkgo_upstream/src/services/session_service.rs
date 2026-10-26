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

pub(crate) struct PendingLogin {
    page: LoginPage,
    account: String,
    generation: u64,
    created: Instant,
}

impl PendingLogin {
    fn valid(&self, account: &str, generation: u64) -> bool {
        self.account == account
            && self.generation == generation
            && self.created.elapsed() < Duration::from_secs(300)
    }
}

/// All account-scoped authentication state has one lifetime and one reset.
/// Keep secrets out of Debug/serialization; this state never crosses the bridge.
#[derive(Default)]
pub(crate) struct Identity {
    pub authenticated: Option<AuthenticatedIdentity>,
    pub pending_login: Option<PendingLogin>,
    pub iclass: Option<IClassSession>,
    pub library_token: Option<String>,
    pub cgyy_token: Option<String>,
    pub cgyy_booking: Option<super::cgyy_booking_service::BookingContext>,
    pub generation: u64,
}

pub struct SchoolClient<T: HttpTransport, V: CredentialVault> {
    pub(crate) session: Session<T>,
    pub(crate) learning_gate: tokio::sync::Mutex<()>,
    pub(crate) homework_files: Mutex<super::homework_submission_service::HomeworkFiles>,
    pub(crate) homework_file_gate: tokio::sync::Mutex<()>,
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
            learning_gate: tokio::sync::Mutex::new(()),
            homework_files: Mutex::default(),
            homework_file_gate: tokio::sync::Mutex::new(()),
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
        // Central invariant: the published account is the profile's school ID.
        // A mismatch means the cookie session belongs to another login; fail
        // closed to a signed-out state instead of rebinding it.
        let authenticated =
            (account == profile.school_id).then_some(AuthenticatedIdentity { account, profile });
        if authenticated.is_none() {
            self.session.clear_cookies();
        }
        *identity = Identity {
            generation: identity.generation.wrapping_add(1),
            authenticated,
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

    /// How often one of this client's in-memory locks was recovered from a
    /// poisoned state.
    ///
    /// A non-zero value means a panic interrupted a state update. The guarded
    /// values were kept — in particular the session `Identity`, so the user is
    /// not silently signed out — but the event stays visible to the caller
    /// instead of disappearing into a silent reset.
    pub fn lock_poison_events(&self) -> u64 {
        self.identity.poison_count()
            + self.checkin_progress.poison_count()
            + self.automatic_login_failure.poison_count()
            + self.cgyy_safety.poison_count()
            + self.snapshots.poison_events()
            + self.session.poison_events()
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
    async fn login_challenge(
        &self,
        expected_id: Option<&str>,
        refresh: bool,
    ) -> Result<LoginChallengeData, AppError> {
        let (page, account, generation, created) = {
            let mut identity = self.identity.lock();
            let pending = identity
                .pending_login
                .as_ref()
                .ok_or_else(AppError::session_expired)?;
            if !pending.valid(&pending.account, identity.generation) {
                identity.pending_login = None;
                return Err(AppError::session_expired());
            }
            let LoginPage::Form {
                captcha: Some(challenge),
                ..
            } = &pending.page
            else {
                return Err(AppError::invalid());
            };
            if expected_id.is_some_and(|id| id != challenge.id)
                || (refresh && expected_id.is_none())
            {
                return Err(AppError::session_expired());
            }
            (
                pending.page.clone(),
                pending.account.clone(),
                pending.generation,
                pending.created,
            )
        };
        // Refresh is a new login-page GET, not an invented refresh endpoint and
        // never an ExistingSession hop or form submission.
        let clear_original_pending = || {
            let mut identity = self.identity.lock();
            if identity.generation == generation
                && identity.pending_login.as_ref().is_some_and(|pending| {
                    pending.account == account
                        && pending.generation == generation
                        && pending.created == created
                })
            {
                identity.pending_login = None;
            }
        };
        let page = if refresh {
            match auth::fetch_login_page(&self.session).await {
                Ok(page) => page,
                Err(error) => {
                    clear_original_pending();
                    return Err(error);
                }
            }
        } else {
            page
        };
        let LoginPage::Form {
            captcha: Some(challenge),
            ..
        } = &page
        else {
            clear_original_pending();
            return Err(AppError::session_expired());
        };
        let challenge = challenge.clone();
        let text_supported = auth::cas::text_captcha_supported(&challenge);
        {
            let mut identity = self.identity.lock();
            if identity.generation != generation
                || identity
                    .pending_login
                    .as_ref()
                    .is_none_or(|pending| !pending.valid(&account, generation))
            {
                return Err(AppError::session_expired());
            }
            identity.pending_login = Some(PendingLogin {
                page,
                account: account.clone(),
                generation,
                created: if refresh { Instant::now() } else { created },
            });
        }
        let image = if text_supported {
            auth::challenge::image(&self.session, &challenge.id).await?
        } else {
            vec![]
        };
        let identity = self.identity.lock();
        if identity.generation != generation
            || identity.pending_login.as_ref().is_none_or(|pending| {
                !pending.valid(&account, generation)
                    || !matches!(&pending.page,
                LoginPage::Form { captcha: Some(current), .. } if current.id == challenge.id)
            })
        {
            return Err(AppError::session_expired());
        }
        Ok(LoginChallengeData {
            challenge_id: challenge.id,
            challenge_type: challenge.captcha_type,
            text_supported,
            image,
        })
    }

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
        let (pending, generation) = {
            let mut identity = self.identity.lock();
            (identity.pending_login.take(), identity.generation)
        };
        let page = match pending.filter(|page| page.valid(account, generation)) {
            Some(pending) => pending.page,
            None => {
                // A stale answer must never be submitted against a newly fetched page.
                if credentials.captcha_text.is_some() {
                    return Err(AppError::session_expired());
                }
                auth::fetch_login_page(&self.session).await?
            }
        };
        let retry_page = page.clone();
        match auth::complete_login(&self.session, &credentials, page).await {
            Ok(LoginResult::CaptchaRequired(challenge)) => {
                let mut identity = self.identity.lock();
                if identity.generation != generation {
                    return Err(AppError::session_expired());
                }
                identity.pending_login = Some(PendingLogin {
                    page: retry_page,
                    account: account.to_owned(),
                    generation,
                    created: Instant::now(),
                });
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
                Ok(profile) if profile.school_id == account => {
                    self.update_profile(&account, profile.clone())?;
                    return Ok(SessionOutcome::SignedIn {
                        profile,
                        remembered: true,
                    });
                }
                // The cookie jar no longer belongs to the published account.
                // Drop it and fall through to the saved-credential flow rather
                // than rebinding the profile of a different login.
                Ok(_) => self.clear_identity(),
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
                    let mut identity = self.identity.lock();
                    let generation = identity.generation;
                    identity.pending_login = Some(PendingLogin {
                        page,
                        account: credentials.username,
                        generation,
                        created: Instant::now(),
                    });
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
        // An enumeration failure defaults to knowing only the signed-in account
        // below; Android vault no longer reports that failure as an empty list.
        let mut accounts = self.vault.accounts().unwrap_or_default();
        if let Some(account) = account {
            if !accounts.contains(&account) {
                accounts.push(account);
            }
        }
        for account in accounts {
            // Deletes are idempotent local keychain operations; one retry
            // covers a transient Keystore/keychain failure.
            if self.vault.delete(&account).is_err() {
                let _ = self.vault.delete(&account);
            }
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
