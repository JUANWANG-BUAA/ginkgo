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
pub(crate) mod challenge;
pub mod login;
pub mod platform;
pub(crate) mod redirect;
pub mod session;
pub mod uc;
pub mod vault;

use crate::{
    foundation::http::{HttpRequest, HttpTransport},
    AppError, ErrorCode,
};
pub use login::fetch_login_page;
use serde::{Deserialize, Serialize};
pub use session::PersistedSession;
use session::{RouteMode, Session};
pub use uc::{activate_uc, validate_session};

pub const LOGIN_URL: &str = "https://sso.buaa.edu.cn/login";
pub const UC_ACTIVATION_URL: &str =
    "https://uc.buaa.edu.cn/api/login?target=https%3A%2F%2Fuc.buaa.edu.cn%2F%23%2Fuser%2Flogin";
pub const UC_STATUS_URL: &str = "https://uc.buaa.edu.cn/api/uc/status";

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
pub trait CredentialVault: CredentialSource + 'static {
    fn save(&self, account: &str, credentials: &Credentials) -> Result<(), AppError>;
    fn delete(&self, account: &str) -> Result<(), AppError>;
    fn accounts(&self) -> Result<Vec<String>, AppError>;

    /// Session cookies use a separate encrypted record from optional saved
    /// passwords. Other platforms keep their existing password-restore path.
    fn save_session(&self, _session: &PersistedSession) -> Result<(), AppError> {
        Err(AppError::credential_store())
    }
    fn load_session(&self) -> Result<Option<PersistedSession>, AppError> {
        Ok(None)
    }
    fn delete_session(&self) -> Result<(), AppError> {
        Ok(())
    }
    fn has_session(&self) -> Result<bool, AppError> {
        Ok(false)
    }
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
    ExistingSession,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum LoginResult {
    SignedIn(UserProfile),
    /// The school demands a captcha. `page` is the form it just re-rendered,
    /// carrying the `execution` token the answer must be sent with.
    CaptchaRequired {
        challenge: cas::CaptchaChallenge,
        page: LoginPage,
    },
}

/// Complete the documented CAS → UC chain. A captcha challenge is returned
/// without submitting the form so the caller can prompt for it.
pub async fn login<T: HttpTransport>(
    session: &Session<T>,
    credentials: &Credentials,
) -> Result<LoginResult, AppError> {
    let page = fetch_login_page(session).await?;
    finish_login(session, credentials, page).await
}

/// Resume a prepared login. UBAA fetches the login endpoint again before a
/// captcha POST, while preferring the execution supplied with the answer.
pub async fn complete_login<T: HttpTransport>(
    session: &Session<T>,
    credentials: &Credentials,
    page: LoginPage,
) -> Result<LoginResult, AppError> {
    if credentials.username.trim().is_empty() || credentials.password.is_empty() {
        return Err(AppError::invalid());
    }
    let answer = credentials
        .captcha_text
        .as_deref()
        .filter(|text| !text.trim().is_empty());
    let page = if let (LoginPage::Form { execution, .. }, Some(_)) = (&page, answer) {
        // The extra GET shares the challenge's route and cookie jar. It must
        // not replace an explicitly supplied execution with the new page's.
        session.pin_route();
        login::fetch_login_page_with_execution(session, Some(execution)).await?
    } else {
        page
    };
    finish_login(session, credentials, page).await
}

async fn finish_login<T: HttpTransport>(
    session: &Session<T>,
    credentials: &Credentials,
    page: LoginPage,
) -> Result<LoginResult, AppError> {
    if credentials.username.trim().is_empty() || credentials.password.is_empty() {
        return Err(AppError::invalid());
    }
    // The form/execution and service tickets belong to the route that fetched
    // the page. Do not select a different cookie jar halfway through login.
    session.pin_route();
    match page {
        // UBAA ignores the initial Location and activates UC directly. This
        // branch is not the redirect chain produced by a password submission.
        LoginPage::ExistingSession => {}
        LoginPage::Form {
            execution,
            captcha,
            action_url: _,
            html,
        } => {
            // UBAA posts to its fixed loginUrl(), never the page's form action.
            let action_url = LOGIN_URL.to_owned();
            if let Some(challenge) = captcha {
                let fresh = LoginPage::Form {
                    execution: execution.clone(),
                    captcha: Some(challenge.clone()),
                    action_url: action_url.clone(),
                    html: html.clone(),
                };
                if !cas::text_captcha_supported(&challenge) {
                    return Ok(LoginResult::CaptchaRequired {
                        challenge,
                        page: fresh,
                    });
                }
                if credentials
                    .captcha_text
                    .as_deref()
                    .is_none_or(|text| text.trim().is_empty())
                {
                    return Ok(LoginResult::CaptchaRequired {
                        challenge,
                        page: fresh,
                    });
                }
            }
            let fields = match credentials
                .captcha_text
                .as_deref()
                .filter(|text| !text.trim().is_empty())
            {
                Some(answer) => cas::captcha_login_fields(
                    &credentials.username,
                    &credentials.password,
                    &execution,
                    answer,
                ),
                None => {
                    cas::login_fields(&html, &credentials.username, &credentials.password, None)
                }
            };
            let body = cas::form_urlencode(&fields);
            let response = session
                .send(
                    HttpRequest::post_form(action_url.clone(), body)
                        .header("Accept", "application/json")
                        .header(
                            "Content-Type",
                            "application/x-www-form-urlencoded; charset=UTF-8",
                        ),
                )
                .await?;
            login::follow_redirects_and_check_error(session, response, action_url).await?;
        }
    }
    // A completed redirect is not sufficient identity proof. Keep transient
    // failures distinct, and never bind cookies to an unverified input account.
    activate_uc(session).await?;
    let user = validate_session(session).await?;
    if !user
        .school_id
        .eq_ignore_ascii_case(credentials.username.trim())
    {
        session.clear_cookies();
        return Err(AppError::with_detail(
            ErrorCode::SessionExpired,
            "identity_mismatch",
        ));
    }
    Ok(LoginResult::SignedIn(user))
}

/// Transient reachability failures may preserve an already verified identity.
/// A changed response needs diagnosis, not a fabricated successful login.
pub(crate) fn directory_unavailable(error: &AppError) -> bool {
    matches!(
        error.code,
        ErrorCode::ServiceUnavailable | ErrorCode::NetworkUnreachable
    )
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
        LoginResult::CaptchaRequired { challenge, .. } => Err(AppError::with_detail(
            crate::ErrorCode::CaptchaRequired,
            challenge.id,
        )),
    }
}

pub use session::RouteMode as SessionRoute;

#[cfg(test)]
mod tests;

pub(crate) mod iclass;

#[cfg(test)]
mod expiry_tests;
