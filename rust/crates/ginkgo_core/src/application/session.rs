//! session application commands depend only on business ports.
use super::*;

impl<U: SessionSource> Workspace<U> {
    pub async fn login_challenge(
        &self,
        expected_id: Option<&str>,
        refresh: bool,
    ) -> Result<ginkgo_domain::ports::LoginChallengeData, AppError> {
        self.upstream.login_challenge(expected_id, refresh).await
    }

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
    /// Second sign-out step: delete saved passwords. Deliberately separate so
    /// the caller does not hold its gate across platform storage.
    pub async fn purge_credentials(&self) {
        self.upstream.purge_credentials().await
    }
    pub fn clear_snapshots(&self) {
        self.upstream.clear_snapshots()
    }
}
