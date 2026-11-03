// Included only in temporary copies of historical upstream test modules.
use super::*;
use crate::{
    auth::session::Session,
    foundation::{http::HttpTransport, webvpn},
};
use std::sync::{Arc, Mutex};

const CALLBACK: &str = "https://uc.buaa.edu.cn/api/callback?ticket=ST-synthetic";
const MODULE: &str = "https://iclass.buaa.edu.cn:8346/synthetic";

#[derive(Clone, Copy)]
enum Scenario {
    Ticket,
    Fallback,
    UcUnavailable,
    ColdBoot,
    GatewayMismatch,
    CaptchaType,
}

#[derive(Clone)]
struct Probe {
    scenario: Scenario,
    requests: Arc<Mutex<Vec<String>>>,
    callback_seen: Arc<Mutex<bool>>,
    raw_requests: Arc<Mutex<Vec<Value>>>,
}

impl Probe {
    fn new(scenario: Scenario) -> Self {
        Self {
            scenario,
            requests: Arc::default(),
            callback_seen: Arc::default(),
            raw_requests: Arc::default(),
        }
    }
    fn requests(&self) -> Vec<String> {
        self.requests.lock().unwrap().clone()
    }
}

impl HttpTransport for Probe {
    async fn send(&self, request: HttpRequest) -> Result<HttpResponse, TransportError> {
        self.raw_requests.lock().unwrap().push(serde_json::json!({
            "method": match request.method { HttpMethod::Get => "GET", HttpMethod::Post => "POST" },
            "url": request.url, "headers": request.headers,
            "body": request.body.as_deref().unwrap_or("")
        }));
        let original = webvpn::unwrap(&request.url);
        let vpn = request.url != original;
        let cookie = request.header_value("Cookie").unwrap_or("");
        let stage = if original == LOGIN_URL && request.method == HttpMethod::Get {
            "CAS_GET"
        } else if original == LOGIN_URL && request.method == HttpMethod::Post {
            "CAS_POST"
        } else if original == CALLBACK {
            "CALLBACK"
        } else if original == UC_ACTIVATION_URL {
            "UC_ACTIVATE"
        } else if original == UC_STATUS_URL {
            "UC_STATUS"
        } else if original == "https://iclass.buaa.edu.cn:8346/?type=jumpMyCenter" {
            "CHECKIN_ENTRY"
        } else if original == MODULE {
            "MODULE"
        } else {
            "UNEXPECTED"
        };
        self.requests.lock().unwrap().push(format!(
            "{stage}:{}:cookie={}",
            if vpn { "vpn" } else { "direct" },
            !cookie.is_empty()
        ));
        let response = match stage {
            "CAS_GET" if matches!(self.scenario, Scenario::ColdBoot) && !vpn => {
                return Err(TransportError::Unreachable)
            }
            "CAS_GET" if matches!(self.scenario, Scenario::CaptchaType) => {
                HttpResponse::new(200, &request.url,
                    FORM_PAGE.to_owned() + "<script>config.captcha = { type: 'char', id: 'synthetic-cap' };</script>")
            }
            "CAS_GET" => HttpResponse::new(200, &request.url, FORM_PAGE).with_set_cookie(if vpn {
                "wengine_vpn_ticket=synthetic; Path=/; Secure"
            } else {
                "CASTGC=synthetic; Path=/; Secure"
            }),
            "CAS_POST" if matches!(self.scenario, Scenario::Ticket) => {
                HttpResponse::new(302, &request.url, "").with_header("Location", CALLBACK)
            }
            "CAS_POST" => HttpResponse::new(200, &request.url, "ok"),
            "CALLBACK" => {
                *self.callback_seen.lock().unwrap() = true;
                HttpResponse::new(200, &request.url, "ok")
            }
            "UC_ACTIVATE" => HttpResponse::new(200, &request.url, "ok"),
            "UC_STATUS" if matches!(self.scenario, Scenario::UcUnavailable) => {
                HttpResponse::new(503, &request.url, "unavailable")
            }
            "UC_STATUS" if matches!(self.scenario, Scenario::GatewayMismatch) && vpn => {
                HttpResponse::new(
                    200,
                    &request.url,
                    r#"{"code":0,"data":{"schoolid":"sy2501002","name":"other fixture"}}"#,
                )
            }
            "UC_STATUS"
                if matches!(self.scenario, Scenario::Ticket)
                    && !*self.callback_seen.lock().unwrap() =>
            {
                HttpResponse::new(200, &request.url, r#"{"code":10600,"data":null}"#)
            }
            "UC_STATUS"
                if matches!(self.scenario, Scenario::ColdBoot)
                    && (!vpn || !cookie.contains("wengine_vpn_ticket=synthetic")) =>
            {
                HttpResponse::new(200, &request.url, r#"{"code":10600,"data":null}"#)
            }
            "UC_STATUS" => HttpResponse::new(
                200,
                &request.url,
                r#"{"code":0,"data":{"schoolid":"sy2501001","name":"fixture"}}"#,
            ),
            "MODULE" if !vpn => return Err(TransportError::Unreachable),
            "MODULE" => HttpResponse::new(200, &request.url, "ok"),
            "CHECKIN_ENTRY" if !vpn => return Err(TransportError::Unreachable),
            "CHECKIN_ENTRY" => HttpResponse::new(200, &request.url, "synthetic entry"),
            _ => return Err(TransportError::Unavailable),
        };
        Ok(response)
    }
}

fn describe(result: &Result<SessionOutcome, crate::AppError>) -> String {
    match result {
        Ok(SessionOutcome::SignedIn { .. }) => "SignedIn".into(),
        Ok(SessionOutcome::SignedOut) => "SignedOut".into(),
        Ok(_) => "Other".into(),
        Err(error) => format!("Error::{:?}", error.code),
    }
}

#[tokio::test]
async fn history_session_observe_ticket() {
    let transport = Probe::new(Scenario::Ticket);
    let client = SchoolClient::new(Session::new(transport.clone()), MemoryVault::default());
    let result = client.sign_in("sy2501001", "synthetic", None, false).await;
    println!(
        "OBS ticket result={} requests={:?}",
        describe(&result),
        transport.requests()
    );
    assert!(transport
        .requests()
        .iter()
        .any(|s| s.starts_with("CAS_POST:")));
    assert!(
        *transport.callback_seen.lock().unwrap(),
        "service ticket was not followed"
    );
    assert!(matches!(result, Ok(SessionOutcome::SignedIn { .. })));
}

#[tokio::test]
async fn history_session_observe_fallback() {
    let transport = Probe::new(Scenario::Fallback);
    let client = SchoolClient::new(Session::new(transport.clone()), MemoryVault::default());
    let login = client.sign_in("sy2501001", "synthetic", None, false).await;
    assert!(
        matches!(login, Ok(SessionOutcome::SignedIn { .. })),
        "synthetic login failed: {}",
        describe(&login)
    );
    let result = client
        .session
        .send_with_fallback(HttpRequest::get(MODULE))
        .await;
    println!(
        "OBS fallback login={} module={} route={:?} requests={:?}",
        describe(&login),
        if result.is_ok() { "Ok" } else { "Error" },
        client.session.route(),
        transport.requests()
    );
    assert!(
        result.is_ok(),
        "automatic route did not retry the synthetic GET through WebVPN"
    );
}

#[tokio::test]
async fn history_session_observe_uc_unavailable() {
    let transport = Probe::new(Scenario::UcUnavailable);
    let client = SchoolClient::new(Session::new(transport.clone()), MemoryVault::default());
    let result = client.sign_in("sy2501001", "synthetic", None, false).await;
    println!(
        "OBS uc_unavailable result={} requests={:?}",
        describe(&result),
        transport.requests()
    );
    assert!(transport
        .requests()
        .iter()
        .any(|s| s.starts_with("UC_STATUS:")));
    assert!(
        result.is_err(),
        "UC 503 must not fabricate a verified identity"
    );
}

#[tokio::test]
async fn history_session_observe_gateway_mismatch() {
    let transport = Probe::new(Scenario::GatewayMismatch);
    let client = SchoolClient::new(Session::new(transport.clone()), MemoryVault::default());
    let login = client.sign_in("sy2501001", "synthetic", None, false).await;
    assert!(matches!(login, Ok(SessionOutcome::SignedIn { .. })));
    let route = client.session.route();
    let result = client
        .session
        .send_with_fallback(HttpRequest::get(MODULE))
        .await;
    let requests = transport.requests();
    println!(
        "OBS gateway_mismatch module={} route={:?} requests={requests:?}",
        if result.is_ok() { "Ok" } else { "Error" },
        client.session.route(),
    );
    assert!(result.is_err(), "a different gateway identity must not satisfy this account's read");
    assert!(!requests.iter().any(|request| request.starts_with("MODULE:vpn:")));
    assert_eq!(client.session.route(), route);
    assert_eq!(requests.iter().filter(|request| request.starts_with("CAS_POST:")).count(), 1);
}

#[tokio::test]
async fn history_session_observe_captcha_type() {
    let transport = Probe::new(Scenario::CaptchaType);
    let client = SchoolClient::new(Session::new(transport.clone()), MemoryVault::default());
    let first = client.sign_in("sy2501001", "synthetic", None, false).await;
    assert!(matches!(first, Ok(SessionOutcome::CaptchaRequired(_))));
    assert_eq!(transport.requests().len(), 1);
    let answered = client.sign_in("sy2501001", "synthetic", Some("1234"), false).await;
    println!("OBS captcha_type result={} requests={:?}", describe(&answered), transport.requests());
    assert!(matches!(answered, Ok(SessionOutcome::SignedIn { .. })));
    let captured = transport.raw_requests.lock().unwrap();
    let posted: Vec<_> = captured.iter().filter(|request| request["method"] == "POST").collect();
    assert_eq!(posted.len(), 1);
    let body = posted[0]["body"].as_str().unwrap();
    let fields: Vec<_> = url::form_urlencoded::parse(body.as_bytes()).collect();
    for key in ["captcha", "captchaResponse"] {
        assert!(fields.iter().any(|(name, value)| name == key && value == "1234"));
    }
}
