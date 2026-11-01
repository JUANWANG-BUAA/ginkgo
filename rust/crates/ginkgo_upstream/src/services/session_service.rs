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
        CredentialVault, LoginPage, LoginResult, UserProfile,
    },
    codecs::checkin::IClassSession,
    foundation::http::HttpTransport,
    foundation::mutex::{lock_value, Mutex},
    AppError, ErrorCode,
};
use std::{
    sync::{
        atomic::{AtomicU64, Ordering},
        Mutex as StdMutex,
    },
    time::{Duration, Instant},
};

/// Failed automatic password authentication is tracked per recovery kind.
/// User-triggered login does not consult this cooldown.
const AUTOMATIC_LOGIN_FAILURE_TTL: Duration = Duration::from_secs(60);

/// A rejected gateway authentication blocks further automatic password
/// submissions for this long. The block expires so a later attempt can
/// succeed once the school's risk control has cooled down; an explicit user
/// login or route change clears it immediately. Transport failures are not
/// rejections: they keep only [AUTOMATIC_LOGIN_FAILURE_TTL], so a flaky
/// network never leaves the gateway unusable for half an hour.
const GATEWAY_AUTH_BLOCK_TTL: Duration = Duration::from_secs(1800);

/// Errors that mean the school itself refused this password or demanded a
/// challenge. Repeating them is what raises the account's risk score, so only
/// these earn the long block.
fn is_gateway_authentication_rejection(error: &AppError) -> bool {
    matches!(
        error.code,
        ErrorCode::InvalidCredentials
            | ErrorCode::CaptchaRequired
            | ErrorCode::PreLoginTip
            | ErrorCode::AccessPolicyDenied
    )
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
    /// The gateway's own login page while the school demands a captcha for it.
    /// Kept so an answer reuses the same `execution` token instead of asking
    /// the school for a new challenge on every keystroke.
    pub gateway_pending: Option<PendingLogin>,
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
    pub(crate) checkin_request_gates:
        Mutex<std::collections::BTreeMap<String, std::sync::Arc<tokio::sync::Mutex<()>>>>,
    pub(crate) checkin_progress: Mutex<super::checkin_service::CheckInProgress>,
    pub(crate) school_recovery_gate: tokio::sync::Mutex<()>,
    gateway_recovery_gate: tokio::sync::Mutex<()>,
    pub(crate) automatic_login_failure: Mutex<Option<(Instant, AppError)>>,
    pub(crate) gateway_login_failure: Mutex<Option<(Instant, AppError)>>,
    /// A failed gateway authentication blocks further automatic password
    /// submissions for [GATEWAY_AUTH_BLOCK_TTL]; an explicit user action clears
    /// it immediately.
    pub(crate) gateway_auth_blocked: Mutex<Option<(Instant, AppError)>>,
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
            checkin_request_gates: Mutex::default(),
            checkin_progress: Mutex::default(),
            school_recovery_gate: tokio::sync::Mutex::new(()),
            gateway_recovery_gate: tokio::sync::Mutex::new(()),
            automatic_login_failure: Mutex::new(None),
            gateway_login_failure: Mutex::new(None),
            gateway_auth_blocked: Mutex::new(None),
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
            + self.gateway_login_failure.poison_count()
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
            Ok(LoginResult::CaptchaRequired { .. }) => {
                Err(AppError::new(ErrorCode::CaptchaRequired))
            }
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
        let _recovery = self.gateway_recovery_gate.lock().await;
        if self.gateway_generation.load(Ordering::Acquire) != generation {
            return Ok(());
        }
        // A failed gateway authentication is not retried on its own: the
        // school counts repeated password submissions as risk. The block
        // expires so a later attempt can succeed, and an explicit user action
        // clears it immediately.
        let mut block_expired = false;
        {
            let mut blocked = self.gateway_auth_blocked.lock();
            match blocked.as_ref() {
                Some((at, error)) if at.elapsed() < GATEWAY_AUTH_BLOCK_TTL => {
                    let error = error.clone();
                    drop(blocked);
                    self.session.set_route(RouteMode::Automatic);
                    return Err(error);
                }
                Some(_) => {
                    *blocked = None;
                    block_expired = true;
                }
                None => {}
            }
        }
        if block_expired {
            // The long block expired: the short failure cooldown must not keep
            // the gateway unusable.
            *self.gateway_login_failure.lock() = None;
        }
        if let Err(error) = self.check_gateway_login_failure() {
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
        self.session.set_route(RouteMode::WebVpn);
        let result = match auth::fetch_login_page(&self.session).await {
            Ok(page) => {
                match auth::complete_login(&self.session, &credentials, page.clone()).await {
                    Ok(LoginResult::SignedIn(_)) if self.session.webvpn_cookie_present() => Ok(()),
                    Ok(LoginResult::SignedIn(_)) => Err(AppError::session_expired()),
                    Ok(LoginResult::CaptchaRequired { challenge, page }) => {
                        // Keep the page the school just re-rendered: its
                        // `execution` token is the one the answer must use.
                        self.remember_gateway_pending(page, &account);
                        Err(AppError::with_detail(
                            ErrorCode::CaptchaRequired,
                            challenge.id,
                        ))
                    }
                    Err(error) => Err(error),
                }
            }
            Err(error) => Err(error),
        };
        if let Err(error) = &result {
            self.session.set_route(RouteMode::Automatic);
            if is_gateway_authentication_rejection(error) {
                *self.gateway_auth_blocked.lock() = Some((Instant::now(), error.clone()));
            }
        } else {
            self.gateway_generation.fetch_add(1, Ordering::Release);
            *self.gateway_auth_blocked.lock() = None;
        }
        self.record_gateway_login_result(&result);
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

    fn check_gateway_login_failure(&self) -> Result<(), AppError> {
        let failure = self.gateway_login_failure.lock();
        match failure.as_ref() {
            Some((at, error)) if at.elapsed() < AUTOMATIC_LOGIN_FAILURE_TTL => Err(error.clone()),
            _ => Ok(()),
        }
    }

    fn record_gateway_login_result(&self, result: &Result<(), AppError>) {
        *self.gateway_login_failure.lock() = result
            .as_ref()
            .err()
            .map(|error| (Instant::now(), error.clone()));
    }

    pub(crate) fn remember_gateway_pending(&self, page: LoginPage, account: &str) {
        let mut identity = self.identity.lock();
        let generation = identity.generation;
        identity.gateway_pending = Some(PendingLogin {
            page,
            account: account.to_owned(),
            generation,
            created: Instant::now(),
        });
    }

    fn clear_automatic_login_failure(&self) {
        *self.automatic_login_failure.lock() = None;
        *self.gateway_login_failure.lock() = None;
        *self.gateway_auth_blocked.lock() = None;
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

mod session_source;
