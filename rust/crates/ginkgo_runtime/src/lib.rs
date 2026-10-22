//! Composition root. This is the only application crate that selects school/platform implementations.
use ginkgo_core::{application::Workspace, AppError};
use ginkgo_upstream::{
    adapters::reqwest_transport::ReqwestTransport,
    auth::{
        platform::{platform_vault, PlatformVault},
        session::Session,
        CredentialVault,
    },
    services::session_service::SchoolClient,
};
use std::sync::OnceLock;

pub type AppService = Workspace<SchoolClient<ReqwestTransport, PlatformVault>>;

/// Called lazily on the first command, never while Flutter initializes.
pub fn create_service() -> Result<AppService, AppError> {
    let transport = ReqwestTransport::new().map_err(|_| AppError::unavailable())?;
    Ok(Workspace::new(SchoolClient::new(
        Session::new(transport),
        platform_vault()?,
    )))
}

pub fn has_saved_accounts() -> Result<bool, AppError> {
    Ok(!platform_vault()?.accounts()?.is_empty())
}

pub fn verify_credential_storage(account: &str, secret: &str) -> bool {
    platform_vault().is_ok_and(|vault| {
        ginkgo_upstream::auth::vault::verify_vault_round_trip(&vault, account, secret)
    })
}

pub async fn check_update(
    current: &str,
) -> Result<ginkgo_core::features::updates::UpdateSummary, AppError> {
    static TRANSPORT: OnceLock<Result<ReqwestTransport, AppError>> = OnceLock::new();
    match TRANSPORT.get_or_init(|| ReqwestTransport::new().map_err(|_| AppError::unavailable())) {
        Ok(transport) => {
            ginkgo_upstream::services::updates_service::check(UpdateTransport(transport), current)
                .await
        }
        Err(error) => Err(error.clone()),
    }
}
struct UpdateTransport(&'static ReqwestTransport);
impl ginkgo_upstream::foundation::http::HttpTransport for UpdateTransport {
    async fn send(
        &self,
        request: ginkgo_upstream::foundation::http::HttpRequest,
    ) -> Result<
        ginkgo_upstream::foundation::http::HttpResponse,
        ginkgo_upstream::foundation::http::TransportError,
    > {
        self.0.send(request).await
    }
}

pub mod demo;

#[cfg(target_os = "android")]
pub use ginkgo_upstream::auth::platform::jni_on_load;
