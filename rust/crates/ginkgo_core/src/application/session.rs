//! session application commands depend only on business ports.
use super::*;

impl<U: SessionSource> Workspace<U> {
    pub fn status(&self) -> SessionStatus {
        self.upstream.status()
    }
    pub fn set_route(&self, preference: RoutePreference) {
        self.upstream.set_route(preference)
    }
    pub async fn sign_in(
        &self,
        account: &str,
        password: &str,
        captcha: Option<&str>,
        remember: bool,
    ) -> Result<SessionOutcome, AppError> {
        self.upstream
            .sign_in(account, password, captcha, remember)
            .await
    }
    pub async fn restore(&self) -> Result<SessionOutcome, AppError> {
        self.upstream.restore().await
    }
    pub async fn sign_out(&self) {
        self.upstream.sign_out().await
    }
    pub fn clear_snapshots(&self) {
        self.upstream.clear_snapshots()
    }
}
