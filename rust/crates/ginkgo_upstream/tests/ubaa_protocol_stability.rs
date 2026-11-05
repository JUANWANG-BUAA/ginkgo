//! Offline snapshot-isolation regressions against the actual public client.
//! Exact CAS/password/captcha transcripts remain in the frozen auth/service tests;
//! this suite does not claim full UBAA parity or real-account acceptance.
use ginkgo_domain::ports::{SessionOutcome, SessionSource};
use ginkgo_upstream::{
    auth::{
        session::{RouteMode, SessionCookies},
        vault::MemoryVault,
        CredentialSource, CredentialVault, Credentials, PersistedSession, UC_STATUS_URL,
    },
    foundation::{
        cookie::CookieJar,
        http::{HttpMethod, HttpRequest, HttpResponse, HttpTransport, TransportError},
    },
    services::background_session::{from_snapshot, owner_key},
};
use std::sync::{Arc, Mutex};

#[derive(Clone)]
struct RecordingTransport {
    requests: Arc<Mutex<Vec<HttpRequest>>>,
    body: &'static str,
}
impl HttpTransport for RecordingTransport {
    async fn send(&self, request: HttpRequest) -> Result<HttpResponse, TransportError> {
        self.requests.lock().unwrap().push(request.clone());
        Ok(HttpResponse::new(200, request.url, self.body))
    }
}

fn snapshot() -> PersistedSession {
    let mut direct = CookieJar::new();
    direct.store(
        UC_STATUS_URL,
        "uc=synthetic; Path=/; Secure",
        CookieJar::now_ms(),
    );
    PersistedSession::new(
        "sy2501001".into(),
        "合成账号".into(),
        RouteMode::Direct,
        SessionCookies {
            direct,
            webvpn: CookieJar::new(),
        },
    )
}

#[tokio::test]
async fn background_identity_rejection_never_replays_password_or_changes_foreground_vault() {
    for (body, signed_in) in [
        (
            r#"{"code":0,"data":{"schoolid":"sy2501001","name":"合成账号"}}"#,
            true,
        ),
        (r#"{"code":10600,"data":null}"#, false),
        (
            r#"{"code":0,"data":{"schoolid":"sy2501002","name":"其他账号"}}"#,
            false,
        ),
    ] {
        let foreground = MemoryVault::with(
            "sy2501001",
            Credentials {
                username: "sy2501001".into(),
                password: "synthetic-only".into(),
                captcha_text: None,
            },
        );
        let saved = snapshot();
        foreground.save_session(&saved).unwrap();
        let original = serde_json::to_value(foreground.load_session().unwrap()).unwrap();
        let transport = RecordingTransport {
            requests: Arc::default(),
            body,
        };
        let client = from_snapshot(transport.clone(), saved, &owner_key("sy2501001")).unwrap();
        let outcome = client.restore().await.unwrap();
        assert_eq!(
            matches!(outcome, SessionOutcome::SignedIn { .. }),
            signed_in
        );
        let requests = transport.requests.lock().unwrap();
        assert_eq!(
            requests.len(),
            1,
            "restoration is one UC read, never password replay"
        );
        let request = &requests[0];
        assert_eq!(request.method, HttpMethod::Get);
        assert_eq!(request.url, UC_STATUS_URL);
        assert_eq!(request.header_value("Cookie"), Some("uc=synthetic"));
        assert_eq!(
            request.header_value("X-Requested-With"),
            Some("XMLHttpRequest")
        );
        assert_eq!(
            request.header_value("Accept"),
            Some("application/json, text/javascript, */*; q=0.01, application/json")
        );
        assert!(request.body.is_none());
        assert!(request.binary_body.is_none());
        assert_eq!(
            serde_json::to_value(foreground.load_session().unwrap()).unwrap(),
            original
        );
        assert_eq!(
            foreground.load("sy2501001").unwrap().unwrap().password,
            "synthetic-only"
        );
    }
}

#[test]
fn wrong_owner_cannot_create_a_background_client_or_make_requests() {
    let transport = RecordingTransport {
        requests: Arc::default(),
        body: "",
    };
    assert!(from_snapshot(transport.clone(), snapshot(), &owner_key("sy2501002")).is_err());
    assert!(transport.requests.lock().unwrap().is_empty());
}
