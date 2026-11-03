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
        CredentialVault, LoginPage, LoginResult, PersistedSession, UserProfile,
    },
    codecs::checkin::IClassSession,
    foundation::http::HttpTransport,
    foundation::mutex::{lock_value, Mutex},
    AppError, ErrorCode,
};
use std::{
    sync::{
        atomic::{AtomicBool, AtomicU64, Ordering},
        Arc, Mutex as StdMutex,
    },
    time::{Duration, Instant},
};

/// School and gateway keep separate failures. Explicit credential rejection
/// or a login tip requiring user attention must not cause a background
/// password attempt every minute; transient
/// transport/service failures retain a shorter retry window.
fn automatic_login_failure_ttl(code: &ErrorCode) -> Duration {
    match code {
        ErrorCode::InvalidCredentials | ErrorCode::PreLoginTip => Duration::from_secs(30 * 60),
        _ => Duration::from_secs(60),
    }
}

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

#[derive(Clone)]
pub(crate) struct AccountOwner {
    pub(crate) account: String,
    pub(crate) generation: u64,
}

pub(crate) struct PendingLogin {
    page: LoginPage,
    route: RouteMode,
    account: String,
    generation: u64,
    created: Instant,
}

impl PendingLogin {
    /// Same sign-in attempt, regardless of age. A challenge that belongs to
    /// another account must never be answered or silently replaced.
    pub(crate) fn belongs_to(&self, account: &str, generation: u64) -> bool {
        self.account == account && self.generation == generation
    }

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
    /// Route of the verified identity; temporary gateway transactions cannot
    /// replace it until their own identity check succeeds.
    pub active_route: Option<RouteMode>,
    pub pending_login: Option<PendingLogin>,
    pub gateway_pending: Option<PendingLogin>,
    pub iclass: Option<IClassSession>,
    pub library_token: Option<String>,
    pub cgyy_token: Option<String>,
    pub cgyy_booking: Option<super::cgyy_booking_service::BookingContext>,
    /// UBAA remembers a successful GSMIS source for this authenticated lifetime.
    pub graduate_schedule: bool,
    /// The credential this session was opened with, kept in memory only so a
    /// gateway that needs its own CAS session can be authenticated without
    /// asking the user to store the password. Cleared with the identity.
    pub session_credentials: Option<crate::auth::Credentials>,
    pub generation: u64,
    /// Fixed start of this authenticated lifetime; cookie rotation cannot extend it.
    pub persisted_started_at_ms: i64,
}

pub struct SchoolClient<T: HttpTransport, V: CredentialVault> {
    pub(crate) session: Session<T>,
    pub(crate) learning_gate: tokio::sync::Mutex<()>,
    pub(crate) homework_files: Mutex<super::homework_submission_service::HomeworkFiles>,
    pub(crate) homework_file_gate: tokio::sync::Mutex<()>,
    pub(crate) vault: Arc<V>,
    pub(crate) identity: Arc<Mutex<Identity>>,
    pub(crate) route: Arc<StdMutex<RoutePreference>>,
    route_initialized: AtomicBool,
    pub(crate) snapshots: ReadSnapshots,
    pub(crate) bykc_access: tokio::sync::Mutex<()>,
    pub(crate) checkin_request_gates:
        Mutex<std::collections::BTreeMap<String, std::sync::Arc<tokio::sync::Mutex<()>>>>,
    pub(crate) checkin_progress: Mutex<super::checkin_service::CheckInProgress>,
    pub(crate) school_recovery_gate: tokio::sync::Mutex<()>,
    gateway_recovery_gate: tokio::sync::Mutex<()>,
    pub(crate) automatic_login_failure: Mutex<Option<(Instant, AppError)>>,
    gateway_login_failure: Mutex<Option<(Instant, AppError)>>,
    school_generation: AtomicU64,
    gateway_generation: AtomicU64,
    pub(crate) graduate_request_gate: tokio::sync::Mutex<()>,
    pub(crate) library_login_gate: tokio::sync::Mutex<()>,
    // In-memory safety journal, deliberately outside the resettable Identity.
    pub(crate) cgyy_safety:
        Mutex<std::collections::BTreeMap<String, super::cgyy_booking_service::BookingSafety>>,
    pub(crate) cgyy_mutation_gate: tokio::sync::Mutex<()>,
    /// Account revoked by the last sign-out, handed from the fast revocation
    /// step to the credential purge that runs outside the caller's gate.
    pub(crate) forgotten_account: Mutex<Option<String>>,
}

impl<T: HttpTransport + Send + Sync, V: CredentialVault> SchoolClient<T, V> {
    pub fn new(session: Session<T>, vault: V) -> Self {
        let vault = Arc::new(vault);
        let identity: Arc<Mutex<Identity>> = Arc::new(Mutex::default());
        let route = Arc::new(StdMutex::new(RoutePreference::Automatic));
        {
            let identity = Arc::clone(&identity);
            let route = Arc::clone(&route);
            session.set_verified_route_handler(move |account, generation, profile| {
                if *lock_value(&route) != RoutePreference::Automatic {
                    return false;
                }
                let mut identity = identity.lock();
                if identity.generation != generation
                    || !identity
                        .authenticated
                        .as_ref()
                        .is_some_and(|user| user.account.eq_ignore_ascii_case(account))
                {
                    return false;
                }
                if let Some(user) = identity.authenticated.as_mut() {
                    user.profile = profile.clone();
                }
                identity.active_route = Some(RouteMode::WebVpn);
                identity.iclass = None;
                identity.library_token = None;
                identity.gateway_pending = None;
                identity.graduate_schedule = false;
                true
            });
        }
        {
            let vault = Arc::clone(&vault);
            let identity = Arc::clone(&identity);
            session.set_cookie_persistor(move |cookies| {
                let (account, profile_name, started_at, active_route) = {
                    let identity = identity.lock();
                    let user = identity.authenticated.as_ref()?;
                    (
                        user.account.clone(),
                        user.profile.name.clone(),
                        identity.persisted_started_at_ms,
                        identity.active_route?,
                    )
                };
                let mut record =
                    PersistedSession::new(account, profile_name, active_route, cookies);
                record.saved_at_ms = started_at;
                let vault = Arc::clone(&vault);
                let persist: crate::auth::session::CookiePersistFuture = Box::pin(async move {
                    let _ = tokio::task::spawn_blocking(move || vault.save_session(&record)).await;
                });
                Some(persist)
            });
        }
        Self {
            session,
            learning_gate: tokio::sync::Mutex::new(()),
            homework_files: Mutex::default(),
            homework_file_gate: tokio::sync::Mutex::new(()),
            vault,
            identity,
            snapshots: ReadSnapshots::default(),
            route,
            route_initialized: AtomicBool::new(false),
            bykc_access: tokio::sync::Mutex::new(()),
            checkin_request_gates: Mutex::default(),
            checkin_progress: Mutex::default(),
            school_recovery_gate: tokio::sync::Mutex::new(()),
            gateway_recovery_gate: tokio::sync::Mutex::new(()),
            automatic_login_failure: Mutex::new(None),
            gateway_login_failure: Mutex::new(None),
            school_generation: AtomicU64::new(0),
            gateway_generation: AtomicU64::new(0),
            graduate_request_gate: tokio::sync::Mutex::new(()),
            library_login_gate: tokio::sync::Mutex::new(()),
            cgyy_safety: Mutex::default(),
            forgotten_account: Mutex::default(),
            cgyy_mutation_gate: tokio::sync::Mutex::new(()),
        }
    }

    pub(crate) fn checkin_day_gate(&self, date: &str) -> std::sync::Arc<tokio::sync::Mutex<()>> {
        self.checkin_request_gates
            .lock()
            .entry(date.to_owned())
            .or_default()
            .clone()
    }

    pub(crate) fn set_authenticated(&self, account: String, profile: UserProfile) {
        let active_route = self.session.pin_route();
        let mut identity = self.identity.lock();
        // Central invariant: the published account is the profile's school ID.
        // A mismatch means the cookie session belongs to another login; fail
        // closed to a signed-out state instead of rebinding it.
        let authenticated =
            account
                .eq_ignore_ascii_case(&profile.school_id)
                .then(|| AuthenticatedIdentity {
                    account: profile.school_id.clone(),
                    profile,
                });
        let rejected = authenticated.is_none();
        *identity = Identity {
            generation: identity.generation.wrapping_add(1),
            active_route: authenticated.as_ref().map(|_| active_route),
            authenticated,
            persisted_started_at_ms: crate::foundation::cookie::CookieJar::now_ms(),
            ..Identity::default()
        };
        let automatic_owner = identity
            .authenticated
            .as_ref()
            .map(|user| (user.account.clone(), identity.generation));
        drop(identity);
        if rejected {
            self.session.clear_cookies();
        } else if self.preference() == RoutePreference::Automatic {
            if let Some((account, generation)) = automatic_owner {
                self.session
                    .allow_automatic_business_route(account, generation);
            }
        }
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
        auth::vault::verify_vault_round_trip(self.vault.as_ref(), account, secret)
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
            + self.gateway_login_failure.poison_count()
            + self.cgyy_safety.poison_count()
            + self.snapshots.poison_events()
            + self.session.poison_events()
    }

    pub(crate) fn preference(&self) -> RoutePreference {
        *lock_value(&self.route)
    }

    /// Keep the credential this sign-in used so a gateway that needs its own
    /// CAS session can be authenticated later without a stored password.
    pub(crate) fn remember_session_credentials(&self, credentials: &crate::auth::Credentials) {
        let mut reusable = credentials.clone();
        reusable.captcha_text = None;
        self.identity.lock().session_credentials = Some(reusable);
    }

    /// The credential used to open this session, in memory only.
    pub(crate) fn session_credentials(&self) -> Option<crate::auth::Credentials> {
        self.identity.lock().session_credentials.clone()
    }

    pub(crate) async fn persist_active_session(&self) -> Result<(), AppError> {
        let (account, profile_name, started_at, active_route) = {
            let identity = self.identity.lock();
            let user = identity
                .authenticated
                .as_ref()
                .ok_or_else(AppError::session_expired)?;
            (
                user.account.clone(),
                user.profile.name.clone(),
                identity.persisted_started_at_ms,
                identity
                    .active_route
                    .ok_or_else(AppError::session_expired)?,
            )
        };
        let mut record = PersistedSession::new(
            account,
            profile_name,
            active_route,
            self.session.cookie_snapshot(),
        );
        record.saved_at_ms = started_at;
        let vault = Arc::clone(&self.vault);
        tokio::task::spawn_blocking(move || vault.save_session(&record))
            .await
            .map_err(|_| AppError::credential_store())?
    }

    pub(crate) async fn load_persisted_session(
        &self,
    ) -> Result<Option<PersistedSession>, AppError> {
        let vault = Arc::clone(&self.vault);
        tokio::task::spawn_blocking(move || vault.load_session())
            .await
            .map_err(|_| AppError::credential_store())?
    }

    pub(crate) async fn delete_persisted_session(&self) -> Result<(), AppError> {
        let vault = Arc::clone(&self.vault);
        tokio::task::spawn_blocking(move || vault.delete_session())
            .await
            .map_err(|_| AppError::credential_store())?
    }

    pub(crate) fn current_account(&self) -> Result<String, AppError> {
        self.identity
            .lock()
            .authenticated
            .as_ref()
            .map(|user| user.account.clone())
            .ok_or_else(AppError::session_expired)
    }

    pub(crate) fn account_owner(&self) -> Result<AccountOwner, AppError> {
        let identity = self.identity.lock();
        Ok(AccountOwner {
            account: identity
                .authenticated
                .as_ref()
                .ok_or_else(AppError::session_expired)?
                .account
                .clone(),
            generation: identity.generation,
        })
    }

    pub(crate) fn check_account_owner(&self, owner: &AccountOwner) -> Result<(), AppError> {
        let identity = self.identity.lock();
        if identity.generation != owner.generation
            || !identity
                .authenticated
                .as_ref()
                .is_some_and(|user| user.account == owner.account)
        {
            return Err(AppError::session_expired());
        }
        Ok(())
    }

    pub(crate) async fn silent_login(&self) -> Result<(), AppError> {
        let generation = self.school_generation.load(Ordering::Acquire);
        let _recovery = self.school_recovery_gate.lock().await;
        if self.school_generation.load(Ordering::Acquire) != generation {
            return Ok(());
        }
        self.check_automatic_login_failure()?;
        let owner = self.account_owner()?;
        let account = owner.account.clone();
        // UBAA rechecks UC before treating a business refusal as a global
        // logout. A valid UC session or a transient directory failure must
        // never trigger another password POST.
        let failure = match auth::validate_session(&self.session).await {
            Ok(profile) if profile.school_id.eq_ignore_ascii_case(&account) => {
                self.check_account_owner(&owner)?;
                self.update_profile(&account, profile)?;
                Some(AppError::module_auth_required())
            }
            Ok(_) => Some(AppError::session_expired()),
            Err(error) if error.code == ErrorCode::SessionExpired => None,
            Err(error) => Some(error),
        };
        self.check_account_owner(&owner)?;
        if let Some(error) = failure {
            let result = Err(error);
            self.record_automatic_login_result(&result);
            return result;
        }
        if self
            .identity
            .lock()
            .pending_login
            .as_ref()
            .is_some_and(|pending| pending.belongs_to(&account, owner.generation))
        {
            return Err(AppError::new(ErrorCode::CaptchaRequired));
        }
        let credentials = self.recovery_credentials(&account)?;
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
                    identity.iclass = None;
                    identity.library_token = None;
                    identity.gateway_pending = None;
                    identity.graduate_schedule = false;
                }
                self.school_generation.fetch_add(1, Ordering::Release);
                Ok(())
            }
            Ok(LoginResult::CaptchaRequired { challenge, page }) => {
                self.check_account_owner(&owner)?;
                self.identity.lock().pending_login = Some(PendingLogin {
                    page,
                    route: self.session.route(),
                    account,
                    generation: owner.generation,
                    created: Instant::now(),
                });
                Err(AppError::with_detail(
                    ErrorCode::CaptchaRequired,
                    challenge.id,
                ))
            }
            Err(error) => Err(error),
        };
        self.record_automatic_login_result(&result);
        if result.is_ok() {
            if self.preference() == RoutePreference::Automatic {
                let owner = self.account_owner()?;
                self.session
                    .allow_automatic_business_route(owner.account, owner.generation);
            }
            let _ = self.persist_active_session().await;
        }
        result
    }

    /// Establish a gateway session on an isolated, fixed-route transaction.
    /// Failed or cancelled authentication cannot reroute business reads.
    pub(crate) async fn ensure_webvpn_session(&self) -> Result<(), AppError> {
        let generation = self.gateway_generation.load(Ordering::Acquire);
        let _recovery = self.gateway_recovery_gate.lock().await;
        let _school = self.school_recovery_gate.lock().await;
        if self.gateway_generation.load(Ordering::Acquire) != generation {
            return Ok(());
        }
        if let Some((at, error)) = self.gateway_login_failure.lock().as_ref() {
            if at.elapsed() < automatic_login_failure_ttl(&error.code) {
                return Err(error.clone());
            }
        }
        let account = self.current_account()?;
        let owner = self.account_owner()?;
        if self.session.route() != RouteMode::WebVpn {
            // UBAA connection modes are explicit session boundaries. A module
            // cannot open a second mode and move an authenticated account to it.
            return Err(AppError::module_auth_required());
        }
        // Do not submit another password while the user is answering a challenge.
        if self
            .identity
            .lock()
            .gateway_pending
            .as_ref()
            .is_some_and(|pending| pending.belongs_to(&account, owner.generation))
        {
            return Err(AppError::new(ErrorCode::CaptchaRequired));
        }
        let session = self.session.routed(RouteMode::WebVpn);
        // A stale business token does not establish that the gateway's CAS
        // session expired either. Reuse a valid UC session without a password.
        let outcome = match auth::validate_session(&session).await {
            Ok(profile) => Ok(LoginResult::SignedIn(profile)),
            Err(error) if error.code == ErrorCode::SessionExpired => {
                match self.recovery_credentials(&account) {
                    Ok(credentials) => auth::login(&session, &credentials).await,
                    Err(error) => Err(error),
                }
            }
            Err(error) => Err(error),
        };
        self.check_account_owner(&owner)?;
        let result = self.finish_gateway_login(outcome, &owner);
        if result.is_ok() {
            self.gateway_generation.fetch_add(1, Ordering::Release);
            let _ = self.persist_active_session().await;
        }
        *self.gateway_login_failure.lock() = result
            .as_ref()
            .err()
            .map(|error| (Instant::now(), error.clone()));
        result
    }

    pub(crate) fn recovery_credentials(
        &self,
        account: &str,
    ) -> Result<crate::auth::Credentials, AppError> {
        if let Some(credentials) = self
            .session_credentials()
            .filter(|credentials| credentials.username.eq_ignore_ascii_case(account))
        {
            return Ok(credentials);
        }
        self.vault
            .load(account)?
            .ok_or_else(AppError::session_expired)
    }

    fn check_automatic_login_failure(&self) -> Result<(), AppError> {
        let failure = self.automatic_login_failure.lock();
        match failure.as_ref() {
            Some((at, error)) if at.elapsed() < automatic_login_failure_ttl(&error.code) => {
                Err(error.clone())
            }
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
        *self.gateway_login_failure.lock() = None;
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

mod gateway;
mod session_source;
