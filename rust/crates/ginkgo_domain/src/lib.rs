//! Shared values and pure business rules. No network, credential store or UI dependency.
pub mod features;
pub mod foundation;

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ErrorCode {
    InvalidRequest,
    ChangedResponse,
    UnsupportedContract,
    SessionExpired,
    ServiceUnavailable,
    CaptchaRequired,
    InvalidCredentials,
    PreLoginTip,
    AccessPolicyDenied,
    RedirectLimit,
    UnsupportedPortal,
    CredentialStore,
    /// The upstream business endpoint answered, but explicitly rejected this
    /// request (for example an expired app-level session). This is not a
    /// logout: the school session may still be valid.
    BusinessRejected,
    /// No response ever arrived: name resolution, TCP connect, TLS handshake
    /// or the request deadline failed. Distinct from `ServiceUnavailable`,
    /// which means the school answered or the transport itself was unusable.
    /// Blaming the school for a device that is offline sends the user to wait
    /// and retry instead of fixing their own connection.
    NetworkUnreachable,
    /// One module demanded its own re-authentication: its portal bounced to
    /// the school login while the shared school session may still be valid
    /// for every other module. Distinct from `SessionExpired`, which means
    /// the shared session itself is gone. Reporting a module-scoped bounce as
    /// a global expiry tells the user to log in again for a session that is
    /// still working.
    ModuleAuthRequired,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AppError {
    pub code: ErrorCode,
    /// Optional upstream-provided text (already stripped of markup). Callers
    /// localize their own copy from `code`; this is only a diagnostic aid.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub detail: Option<String>,
}

impl AppError {
    pub fn new(code: ErrorCode) -> Self {
        Self { code, detail: None }
    }
    pub fn with_detail(code: ErrorCode, detail: impl Into<String>) -> Self {
        Self {
            code,
            detail: Some(detail.into()),
        }
    }
    pub fn invalid() -> Self {
        Self::new(ErrorCode::InvalidRequest)
    }
    pub fn changed() -> Self {
        Self::new(ErrorCode::ChangedResponse)
    }
    pub fn session_expired() -> Self {
        Self::new(ErrorCode::SessionExpired)
    }
    pub fn module_auth_required() -> Self {
        Self::new(ErrorCode::ModuleAuthRequired)
    }
    pub fn unavailable() -> Self {
        Self::new(ErrorCode::ServiceUnavailable)
    }
    pub fn network_unreachable() -> Self {
        Self::new(ErrorCode::NetworkUnreachable)
    }
    pub fn allows_stale_snapshot(&self) -> bool {
        matches!(
            &self.code,
            ErrorCode::ServiceUnavailable | ErrorCode::NetworkUnreachable
        )
    }
    pub fn credential_store() -> Self {
        Self::new(ErrorCode::CredentialStore)
    }
}

impl std::fmt::Display for AppError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        // Never include request contents or upstream payloads in errors.
        write!(f, "{:?}", self.code)
    }
}
impl std::error::Error for AppError {}

pub mod ports;
pub mod session;
