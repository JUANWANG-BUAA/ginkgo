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
use std::sync::{Mutex, OnceLock};

pub fn get_or_retry<'a, T>(
    cell: &'a OnceLock<T>,
    gate: &Mutex<()>,
    create: impl FnOnce() -> Result<T, AppError>,
) -> Result<&'a T, AppError> {
    if let Some(value) = cell.get() {
        return Ok(value);
    }
    let _guard = gate
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner);
    if let Some(value) = cell.get() {
        return Ok(value);
    }
    let value = create()?;
    cell.set(value).map_err(|_| AppError::unavailable())?;
    cell.get().ok_or_else(AppError::unavailable)
}

pub type AppService = Workspace<SchoolClient<ReqwestTransport, PlatformVault>>;

pub fn library_loans_portal_url() -> String {
    ginkgo_upstream::adapters::library_loans_http::portal_url()
}

pub fn student_service_url(id: &str) -> Option<String> {
    ginkgo_upstream::adapters::student_services::official_url(id)
}

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
    static TRANSPORT: OnceLock<ReqwestTransport> = OnceLock::new();
    static TRANSPORT_INIT: Mutex<()> = Mutex::new(());
    let transport = get_or_retry(&TRANSPORT, &TRANSPORT_INIT, || {
        ReqwestTransport::new().map_err(|_| AppError::unavailable())
    })?;
    ginkgo_upstream::services::updates_service::check(UpdateTransport(transport), current).await
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

#[cfg(test)]
mod composition_tests {
    use super::*;

    /// The composition root must assemble without touching the network. A
    /// freshly assembled service is signed out; targets without a supported
    /// platform vault fail closed rather than using plaintext storage.
    #[test]
    fn composition_root_is_signed_out_or_fails_closed() {
        #[cfg(any(target_os = "android", target_os = "windows", target_os = "macos"))]
        {
            let service = create_service().expect("composition root must assemble off the network");
            let status = service.status();
            assert!(status.account.is_none(), "a new service holds no account");
            assert!(status.profile.is_none(), "a new service holds no profile");
        }
        #[cfg(not(any(target_os = "android", target_os = "windows", target_os = "macos")))]
        {
            let error = match create_service() {
                Err(error) => error,
                Ok(_) => panic!("unsupported target must not use a vault"),
            };
            assert_eq!(error.code, ginkgo_core::ErrorCode::CredentialStore);
        }
    }

    #[test]
    fn failed_initialization_is_retried_and_success_is_cached() {
        let cell = OnceLock::new();
        let gate = std::sync::Mutex::new(());
        let mut attempts = 0;

        let error = get_or_retry(&cell, &gate, || -> Result<usize, AppError> {
            attempts += 1;
            Err(AppError::unavailable())
        })
        .expect_err("the injected failure must reach the caller");
        assert_eq!(error.code, ginkgo_core::ErrorCode::ServiceUnavailable);
        let value = get_or_retry(&cell, &gate, || {
            attempts += 1;
            Ok(7)
        })
        .expect("a later attempt must be allowed to succeed");
        assert_eq!(*value, 7);
        let cached = get_or_retry(&cell, &gate, || {
            attempts += 1;
            Ok(9)
        })
        .expect("the successful value must be cached");
        assert_eq!(*cached, 7);
        assert_eq!(attempts, 2);
    }
}
