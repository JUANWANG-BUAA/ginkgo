//! Stable session business capability and values.
use crate::{
    session::{CaptchaChallenge, UserProfile},
    AppError,
};
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RoutePreference {
    Automatic,
    Direct,
    WebVpn,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SessionStatus {
    pub account: Option<String>,
    pub profile: Option<UserProfile>,
    pub route: RoutePreference,
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

impl SessionStatus {
    pub fn signed_in(&self) -> bool {
        self.account.is_some() && self.profile.is_some()
    }
}

pub trait SessionSource: Send + Sync {
    fn status(&self) -> SessionStatus;
    fn set_route(&self, preference: RoutePreference);
    fn sign_in(
        &self,
        account: &str,
        password: &str,
        captcha: Option<&str>,
        remember: bool,
    ) -> impl std::future::Future<Output = Result<SessionOutcome, AppError>> + Send;
    fn restore(&self)
        -> impl std::future::Future<Output = Result<SessionOutcome, AppError>> + Send;
    fn sign_out(&self) -> impl std::future::Future<Output = ()> + Send;
    fn clear_snapshots(&self);
    fn account(&self) -> Result<String, AppError>;
}
