use ginkgo_domain::ports::SessionSource;
use ginkgo_upstream::{
    auth::{session::Session, CredentialSource, CredentialVault, Credentials, PersistedSession},
    foundation::http::{HttpRequest, HttpResponse, HttpTransport, TransportError},
    services::session_service::SchoolClient,
    AppError, ErrorCode,
};

struct NoNetwork;
impl HttpTransport for NoNetwork {
    async fn send(&self, _: HttpRequest) -> Result<HttpResponse, TransportError> {
        panic!("storage failure must not start school requests or password recovery")
    }
}

struct UnavailableSessionVault;
impl CredentialSource for UnavailableSessionVault {
    fn load(&self, _: &str) -> Result<Option<Credentials>, AppError> {
        panic!("session storage failure must not read passwords")
    }
}
impl CredentialVault for UnavailableSessionVault {
    fn save(&self, _: &str, _: &Credentials) -> Result<(), AppError> {
        panic!("unexpected password save")
    }
    fn delete(&self, _: &str) -> Result<(), AppError> {
        panic!("unexpected password deletion")
    }
    fn accounts(&self) -> Result<Vec<String>, AppError> {
        Ok(vec![])
    }
    fn load_session(&self) -> Result<Option<PersistedSession>, AppError> {
        Err(AppError::credential_store())
    }
}

#[tokio::test]
async fn unreadable_session_is_an_error_not_a_signed_out_result() {
    let service = SchoolClient::new(Session::new(NoNetwork), UnavailableSessionVault);
    let error = service.restore().await.expect_err("keep failure retryable");
    assert_eq!(error.code, ErrorCode::CredentialStore);
    assert!(!service.status().signed_in());
}
