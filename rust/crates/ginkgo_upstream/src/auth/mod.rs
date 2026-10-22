//! CAS + UC authentication (API.md §1).
//!
//! Layout:
//! - `cas`     pure login-page/form parsing
//! - `session` cookie jar, direct/WebVPN isolation, safe fallback
//! - `login`   login-page fetch, POST, redirect and error classification
//! - `uc`      UC activation and the only session-validity check
//!
//! Credentials enter through [`CredentialVault`]; Flutter never receives or
//! forwards cookies.
pub mod cas;
pub mod login;
pub mod platform;
pub(crate) mod redirect;
pub mod session;
pub mod uc;
pub mod vault;

use crate::{
    foundation::http::{HttpRequest, HttpTransport},
    AppError,
};
pub use login::fetch_login_page;
use serde::{Deserialize, Serialize};
use session::{RouteMode, Session};
pub use uc::{activate_uc, validate_session};

pub const LOGIN_URL: &str = "https://sso.buaa.edu.cn/login";
pub const UC_ACTIVATION_URL: &str =
    "https://uc.buaa.edu.cn/api/login?target=https%3A%2F%2Fuc.buaa.edu.cn%2F%23%2Fuser%2Flogin";
pub const UC_STATUS_URL: &str = "https://uc.buaa.edu.cn/api/uc/status";
pub const LOGOUT_URL: &str = "https://sso.buaa.edu.cn/logout";

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Credentials {
    pub username: String,
    pub password: String,
    pub captcha_text: Option<String>,
}

/// Read-only credential port used by recovery paths.
pub trait CredentialSource: Send + Sync {
    fn load(&self, account: &str) -> Result<Option<Credentials>, AppError>;
}

/// Platform secure-storage port. Implementations wrap the Android Keystore or
/// the system keychain; the Rust core only sees typed credentials.
pub trait CredentialVault: CredentialSource {
    fn save(&self, account: &str, credentials: &Credentials) -> Result<(), AppError>;
    fn delete(&self, account: &str) -> Result<(), AppError>;
    fn accounts(&self) -> Result<Vec<String>, AppError>;
}

pub use ginkgo_domain::session::UserProfile;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum LoginPage {
    Form {
        execution: String,
        captcha: Option<cas::CaptchaChallenge>,
        action_url: String,
        html: String,
    },
    ExistingSession {
        location: String,
    },
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum LoginResult {
    SignedIn(UserProfile),
    CaptchaRequired(cas::CaptchaChallenge),
}

/// Complete the documented CAS → UC chain. A captcha challenge is returned
/// without submitting the form so the caller can prompt for it.
pub async fn login<T: HttpTransport>(
    session: &Session<T>,
    credentials: &Credentials,
) -> Result<LoginResult, AppError> {
    let page = fetch_login_page(session).await?;
    complete_login(session, credentials, page).await
}

/// Finish a login from an already fetched page. Keeping the page lets a
/// captcha answer reuse the same execution token instead of invalidating it by
/// fetching a new challenge.
pub async fn complete_login<T: HttpTransport>(
    session: &Session<T>,
    credentials: &Credentials,
    page: LoginPage,
) -> Result<LoginResult, AppError> {
    if credentials.username.trim().is_empty() || credentials.password.is_empty() {
        return Err(AppError::invalid());
    }
    match page {
        LoginPage::ExistingSession { location } => {
            let response = session
                .send_with_fallback(HttpRequest::get(&location))
                .await?;
            login::follow_redirects_and_check_error(session, response, location).await?;
        }
        LoginPage::Form {
            execution,
            captcha,
            action_url,
            html,
        } => {
            if let Some(challenge) = captcha {
                if credentials
                    .captcha_text
                    .as_deref()
                    .is_none_or(str::is_empty)
                {
                    return Ok(LoginResult::CaptchaRequired(challenge));
                }
            }
            let mut fields = cas::login_fields(
                &html,
                &credentials.username,
                &credentials.password,
                credentials.captcha_text.as_deref(),
            );
            fields.retain(|(name, _)| name != "execution");
            fields.push(("execution".into(), execution));
            let body = cas::form_urlencode(&fields);
            let response = session
                .send(HttpRequest::post_form(action_url.clone(), body))
                .await?;
            login::follow_redirects_and_check_error(session, response, action_url).await?;
        }
    }
    activate_uc(session).await?;
    let user = validate_session(session).await?;
    Ok(LoginResult::SignedIn(user))
}

/// Load credentials from the platform vault, then log in. This is the only
/// entry point the bridge should expose for real accounts.
pub async fn login_with_store<T: HttpTransport, C: CredentialSource + ?Sized>(
    session: &Session<T>,
    store: &C,
    account: &str,
) -> Result<LoginResult, AppError> {
    let credentials = store.load(account)?.ok_or_else(AppError::session_expired)?;
    login(session, &credentials).await
}

/// Explicitly establish a WebVPN session before routed campus traffic. The
/// direct cookie jar remains untouched.
pub async fn establish_webvpn_session<T: HttpTransport>(
    session: &Session<T>,
    credentials: &Credentials,
) -> Result<(), AppError> {
    session.set_route(RouteMode::WebVpn);
    match login(session, credentials).await? {
        LoginResult::SignedIn(_) if session.webvpn_cookie_present() => Ok(()),
        LoginResult::SignedIn(_) => Err(AppError::session_expired()),
        LoginResult::CaptchaRequired(challenge) => Err(AppError::with_detail(
            crate::ErrorCode::CaptchaRequired,
            challenge.id,
        )),
    }
}

/// Logout is best-effort: callers must clear local state even when upstream
/// returns an error.
pub async fn logout<T: HttpTransport>(session: &Session<T>) -> Result<(), AppError> {
    let result = session.send(HttpRequest::get(LOGOUT_URL)).await;
    session.clear_cookies();
    result.map(|_| ())
}

pub use session::RouteMode as SessionRoute;

#[cfg(test)]
mod tests;

pub(crate) mod iclass;
