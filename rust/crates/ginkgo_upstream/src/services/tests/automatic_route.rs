//! Route migration uses existing cookies, never an additional password login.
use super::session_protocol::{status_request, wire};
use super::*;

#[tokio::test]
async fn session_protocol_redirect_keeps_negotiation_but_never_forwards_secrets() {
    let first = HttpRequest::get("https://sso.buaa.edu.cn/synthetic")
        .header("User-Agent", "synthetic-browser")
        .header("Accept", "application/json")
        .header("Accept-Language", "zh-CN")
        .header("Authorization", "Bearer synthetic-private")
        .header("Origin", "https://sso.buaa.edu.cn")
        .header("Referer", "https://sso.buaa.edu.cn/private")
        .header("X-Secret", "synthetic-private");
    let second = HttpRequest::get("https://app.buaa.edu.cn/synthetic")
        .header("User-Agent", "synthetic-browser")
        .header("Accept", "application/json")
        .header("Accept-Language", "zh-CN");
    let transport = TranscriptTransport::new(vec![
        (
            first.clone(),
            Ok(HttpResponse::new(302, &first.url, "").with_header("Location", &second.url)),
        ),
        (
            second.clone(),
            Ok(HttpResponse::new(200, &second.url, "ready")),
        ),
    ]);
    let session = Session::new(transport.clone());
    session.send_following_redirects(first).await.unwrap();
    transport.assert_finished();
}
use crate::{
    auth::session::{RouteMode, Session, SessionCookies},
    foundation::{cookie::CookieJar, http::HttpTransport},
    test_support::TranscriptTransport,
};

const BUSINESS: &str = "https://iclass.buaa.edu.cn:8346/app/entry";

fn client<T: HttpTransport + Send + Sync>(
    transport: T,
    preference: RoutePreference,
) -> SchoolClient<T, MemoryVault> {
    let client = SchoolClient::new(Session::new(transport), MemoryVault::default());
    client.set_route(preference);
    client.set_authenticated(
        "sy2501001".into(),
        UserProfile {
            school_id: "sy2501001".into(),
            name: "fixture".into(),
        },
    );
    let mut direct = CookieJar::new();
    direct.store(
        UC_STATUS_URL,
        "UC=direct; Path=/; Secure",
        CookieJar::now_ms(),
    );
    let mut webvpn = CookieJar::new();
    webvpn.store(
        &wire(UC_STATUS_URL, RouteMode::WebVpn),
        "VPN=synthetic; Path=/; Secure",
        CookieJar::now_ms(),
    );
    client
        .session
        .restore_cookies(SessionCookies { direct, webvpn });
    client
}

#[tokio::test]
async fn session_protocol_automatic_route_verifies_target_before_moving_and_persisting() {
    let vpn = wire(BUSINESS, RouteMode::WebVpn);
    let transport = TranscriptTransport::new(vec![
        (HttpRequest::get(BUSINESS), Err(TransportError::Unreachable)),
        (
            status_request(RouteMode::WebVpn, Some("VPN=synthetic")),
            Ok(uc_ok("sy2501001", "fixture").with_set_cookie("VPN=rotated; Path=/; Secure")),
        ),
        (
            HttpRequest::get(&vpn).header("Cookie", "VPN=rotated"),
            Ok(HttpResponse::new(200, vpn, "business")),
        ),
    ]);
    let client = client(transport.clone(), RoutePreference::Automatic);
    client.persist_active_session().await.unwrap();
    let started = client.vault.load_session().unwrap().unwrap().saved_at_ms;
    let result = client
        .session
        .send_with_fallback(HttpRequest::get(BUSINESS))
        .await;
    assert_eq!(result.unwrap().body, "business");
    assert_eq!(client.status().account.as_deref(), Some("sy2501001"));
    assert_eq!(client.status().route, RoutePreference::Automatic);
    assert_eq!(client.session.route(), RouteMode::WebVpn);
    let record = client.vault.load_session().unwrap().unwrap();
    assert_eq!(record.route, RouteMode::WebVpn);
    assert_eq!(record.saved_at_ms, started);
    assert!(record.cookies.direct.contains("UC"));
    assert!(transport
        .requests()
        .iter()
        .all(|request| request.method == HttpMethod::Get));
    transport.assert_finished();
}

#[tokio::test]
async fn session_protocol_automatic_route_failure_preserves_direct_identity_without_password() {
    for (response, expected) in [
        (Ok(uc_expired()), ErrorCode::ModuleAuthRequired),
        (
            Ok(uc_ok("sy2501002", "other fixture")),
            ErrorCode::ModuleAuthRequired,
        ),
        (
            Ok(HttpResponse::new(503, UC_STATUS_URL, "temporary")),
            ErrorCode::ServiceUnavailable,
        ),
        (
            Err(TransportError::Unreachable),
            ErrorCode::NetworkUnreachable,
        ),
    ] {
        let transport = TranscriptTransport::new(vec![
            (HttpRequest::get(BUSINESS), Err(TransportError::Unreachable)),
            (
                status_request(RouteMode::WebVpn, Some("VPN=synthetic")),
                response
                    .map(|response| response.with_set_cookie("OTHER=unverified; Path=/; Secure")),
            ),
            (HttpRequest::get(BUSINESS), Err(TransportError::Unreachable)),
        ]);
        let client = client(transport.clone(), RoutePreference::Automatic);
        client.persist_active_session().await.unwrap();
        for _ in 0..2 {
            assert_eq!(
                client
                    .session
                    .send_with_fallback(HttpRequest::get(BUSINESS))
                    .await
                    .unwrap_err()
                    .code,
                expected
            );
        }
        assert!(client.status().signed_in());
        assert_eq!(client.session.route(), RouteMode::Direct);
        assert!(!client.session.cookie_snapshot().webvpn.contains("OTHER"));
        assert_eq!(
            client.vault.load_session().unwrap().unwrap().route,
            RouteMode::Direct
        );
        assert!(transport
            .requests()
            .iter()
            .all(|request| request.method == HttpMethod::Get));
        transport.assert_finished();
    }
}

#[tokio::test]
async fn session_protocol_explicit_direct_does_not_migrate() {
    let transport = TranscriptTransport::new(vec![(
        HttpRequest::get(BUSINESS),
        Err(TransportError::Unreachable),
    )]);
    let client = client(transport.clone(), RoutePreference::Direct);
    assert_eq!(
        client
            .session
            .send_with_fallback(HttpRequest::get(BUSINESS))
            .await
            .unwrap_err()
            .code,
        ErrorCode::NetworkUnreachable
    );
    assert_eq!(client.session.route(), RouteMode::Direct);
    transport.assert_finished();
}

#[tokio::test]
async fn session_protocol_automatic_route_never_replays_posts_or_authentication_tickets() {
    for request in [
        HttpRequest::post_form(BUSINESS, "synthetic=single-write"),
        HttpRequest::get(LOGIN_URL),
        HttpRequest::get(UC_STATUS_URL).header("Cookie", "UC=direct"),
        HttpRequest::get(format!("{BUSINESS}?ticket=ST-synthetic")),
    ] {
        let transport =
            TranscriptTransport::new(vec![(request.clone(), Err(TransportError::Unreachable))]);
        let client = client(transport.clone(), RoutePreference::Automatic);
        assert_eq!(
            client
                .session
                .send_with_fallback(request)
                .await
                .unwrap_err()
                .code,
            ErrorCode::NetworkUnreachable
        );
        assert!(client.status().signed_in());
        transport.assert_finished();
    }
}

#[derive(Clone)]
struct ConcurrentRoutes {
    direct: std::sync::Arc<tokio::sync::Barrier>,
    uc: std::sync::Arc<std::sync::atomic::AtomicUsize>,
}
impl HttpTransport for ConcurrentRoutes {
    async fn send(&self, request: HttpRequest) -> Result<HttpResponse, TransportError> {
        assert_eq!(request.method, HttpMethod::Get);
        if request.url == BUSINESS {
            self.direct.wait().await;
            return Err(TransportError::Unreachable);
        }
        if request.url == wire(UC_STATUS_URL, RouteMode::WebVpn) {
            assert_eq!(
                request,
                status_request(RouteMode::WebVpn, Some("VPN=synthetic"))
            );
            self.uc.fetch_add(1, std::sync::atomic::Ordering::SeqCst);
            tokio::task::yield_now().await;
            return Ok(uc_ok("sy2501001", "fixture"));
        }
        assert_eq!(request.url, wire(BUSINESS, RouteMode::WebVpn));
        assert_eq!(request.header_value("Cookie"), Some("VPN=synthetic"));
        Ok(HttpResponse::new(200, request.url, "business"))
    }
}

#[tokio::test]
async fn session_protocol_automatic_route_concurrent_reads_share_one_target_validation() {
    let transport = ConcurrentRoutes {
        direct: std::sync::Arc::new(tokio::sync::Barrier::new(2)),
        uc: std::sync::Arc::default(),
    };
    let client = client(transport.clone(), RoutePreference::Automatic);
    let (first, second) = tokio::time::timeout(std::time::Duration::from_secs(3), async {
        tokio::join!(
            client
                .session
                .send_with_fallback(HttpRequest::get(BUSINESS)),
            client
                .session
                .send_with_fallback(HttpRequest::get(BUSINESS))
        )
    })
    .await
    .unwrap();
    assert_eq!(first.unwrap().body, "business");
    assert_eq!(second.unwrap().body, "business");
    assert_eq!(transport.uc.load(std::sync::atomic::Ordering::SeqCst), 1);
    assert_eq!(client.session.route(), RouteMode::WebVpn);
}

#[derive(Clone, Default)]
struct HeldResponse {
    started: std::sync::Arc<tokio::sync::Notify>,
    resume: std::sync::Arc<tokio::sync::Notify>,
    hold_uc: bool,
}
impl HttpTransport for HeldResponse {
    async fn send(&self, request: HttpRequest) -> Result<HttpResponse, TransportError> {
        assert_eq!(request.method, HttpMethod::Get);
        if request.url == BUSINESS {
            return Err(TransportError::Unreachable);
        }
        let is_uc = request.url == wire(UC_STATUS_URL, RouteMode::WebVpn);
        if (is_uc && self.hold_uc) || request.url.ends_with("/late") {
            self.started.notify_one();
            self.resume.notified().await;
        }
        Ok(if is_uc {
            uc_ok("sy2501001", "fixture")
        } else {
            HttpResponse::new(200, request.url, "late")
        }
        .with_set_cookie("LATE=must-not-import; Path=/; Secure"))
    }
}

#[tokio::test]
async fn session_protocol_automatic_route_account_change_revokes_pending_probe_and_cookie_import() {
    let transport = HeldResponse {
        hold_uc: true,
        ..HeldResponse::default()
    };
    let client = client(transport.clone(), RoutePreference::Automatic);
    let (result, ()) = tokio::time::timeout(std::time::Duration::from_secs(3), async {
        tokio::join!(
            client
                .session
                .send_with_fallback(HttpRequest::get(BUSINESS)),
            async {
                transport.started.notified().await;
                // A new owner is published while the old owner's UC response waits.
                client.set_route(RoutePreference::Direct);
                client.set_authenticated(
                    "sy2501002".into(),
                    UserProfile {
                        school_id: "sy2501002".into(),
                        name: "other fixture".into(),
                    },
                );
                transport.resume.notify_one();
            }
        )
    })
    .await
    .expect("route transaction must finish or reject within its local test deadline");
    assert_eq!(result.unwrap_err().code, ErrorCode::ModuleAuthRequired);
    assert_eq!(client.status().account.as_deref(), Some("sy2501002"));
    assert_eq!(client.session.route(), RouteMode::Direct);
    assert!(client.session.cookie_snapshot().webvpn.is_empty());
}

#[tokio::test]
async fn session_protocol_automatic_route_late_direct_response_cannot_restore_old_module_cookies() {
    let transport = HeldResponse::default();
    let client = client(transport.clone(), RoutePreference::Automatic);
    let (late, ()) = tokio::time::timeout(std::time::Duration::from_secs(3), async {
        tokio::join!(
            client
                .session
                .send(HttpRequest::get("https://iclass.buaa.edu.cn:8346/late")),
            async {
                transport.started.notified().await;
                let response = client
                    .session
                    .send_with_fallback(HttpRequest::get(BUSINESS))
                    .await
                    .unwrap();
                assert_eq!(response.body, "late");
                transport.resume.notify_one();
            }
        )
    })
    .await
    .expect("route transaction must finish or reject within its local test deadline");
    assert_eq!(late.unwrap_err().code, ErrorCode::ModuleAuthRequired);
    assert!(!client.session.cookie_snapshot().direct.contains("LATE"));
    assert!(client.status().signed_in());
}

#[tokio::test]
async fn session_protocol_cookie_headers_are_owned_case_insensitively() {
    let transport = TranscriptTransport::new(vec![(
        HttpRequest::get(BUSINESS),
        Ok(HttpResponse::new(200, BUSINESS, "ok")),
    )]);
    let client = client(transport.clone(), RoutePreference::Direct);
    client
        .session
        .send(HttpRequest::get(BUSINESS).header("cOoKiE", "caller=must-not-send"))
        .await
        .unwrap();
    transport.assert_finished();
}

// Reuse the independently executed UBAA request/response vectors. Fail at
// each real check-in stage, then require a new gateway module login rather
// than replaying a direct loginName/sessionId on the other route.
#[tokio::test]
async fn session_protocol_automatic_route_rebuilds_checkin_at_every_read_stage() {
    use crate::foundation::webvpn;
    let source: Value = serde_json::from_str(include_str!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/tests/data/ubaa-business-responses.json"
    )))
    .unwrap();
    let golden: Value = serde_json::from_str(
        &include_str!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/tests/data/ubaa-business-wire.json"
        ))
        .replace("$COMPACT_DAY", "20260101")
        .replace("$DAY", "2026-01-01"),
    )
    .unwrap();
    let case = golden["cases"]
        .as_array()
        .unwrap()
        .iter()
        .find(|case| case["id"] == "webvpn-checkin-nonempty")
        .unwrap();
    let vpn_steps: Vec<_> = case["requests"]
        .as_array()
        .unwrap()
        .iter()
        .map(|input| {
            let url = input["url"].as_str().unwrap();
            let mut request = HttpRequest::get(url).header("Cookie", "VPN=synthetic");
            for (key, value) in input["headers"].as_object().unwrap() {
                request = request.header(
                    if key == "sessionid" {
                        "sessionId"
                    } else {
                        "Accept"
                    },
                    value.as_str().unwrap(),
                );
            }
            let path = url::Url::parse(&webvpn::unwrap(url))
                .unwrap()
                .path()
                .to_string();
            let input = source["responses"]
                .as_array()
                .unwrap()
                .iter()
                .find(|input| input["path"] == path)
                .unwrap();
            let body = if path.ends_with("get_stu_course_sched.action") {
                source["nonempty_checkin_body"].as_str().unwrap()
            } else {
                input["body"].as_str().unwrap()
            };
            let mut response =
                HttpResponse::new(input["status"].as_u64().unwrap() as u16, url, body);
            if let Some(location) = input["location"].as_str() {
                response = response.with_header("Location", location);
            }
            (request, Ok(response))
        })
        .collect();
    for failed_stage in 0..4 {
        let mut steps = Vec::new();
        for (stage, (request, response)) in vpn_steps
            .iter()
            .enumerate()
            .take(failed_stage + 1)
            .filter(|(stage, _)| failed_stage != 3 || *stage == 2)
        {
            let mut direct = request.clone();
            direct.url = webvpn::unwrap(&direct.url);
            direct.headers.remove("Cookie");
            // Prove that the direct handoff value is not reused on WebVPN.
            if stage == 1 {
                direct.url = direct.url.replace("fixture-login", "direct-login");
            }
            let response = if stage == failed_stage || failed_stage == 3 {
                Err(TransportError::Unreachable)
            } else {
                let mut response = response.clone().unwrap();
                response.final_url = webvpn::unwrap(&response.final_url);
                if let Some(location) = response.headers.get_mut("location") {
                    *location = location.replace("fixture-login", "direct-login");
                }
                Ok(response)
            };
            steps.push((direct, response));
        }
        steps.push((
            status_request(RouteMode::WebVpn, Some("VPN=synthetic")),
            Ok(uc_ok("sy2501001", "fixture")),
        ));
        steps.extend(vpn_steps.clone());
        let transport = TranscriptTransport::new(steps);
        let service = client(transport.clone(), RoutePreference::Automatic);
        if failed_stage == 3 {
            service.identity.lock().iclass = Some(crate::codecs::checkin::IClassSession {
                user_id: "user-1".into(),
                session_id: "session-1".into(),
            });
        }
        let result = service
            .load_checkin_on_date(Some("2026-01-01".into()), true)
            .await
            .unwrap();
        assert_eq!(result.courses.len(), 2);
        assert_eq!(result.courses[0].course_name, "软件工程");
        assert_eq!(result.courses[1].status, CheckInStatus::Signed);
        assert_eq!(service.session.route(), RouteMode::WebVpn);
        assert!(service.status().signed_in());
        assert!(transport
            .requests()
            .iter()
            .all(|request| request.method == HttpMethod::Get));
        transport.assert_finished();
    }
}

#[tokio::test]
async fn session_protocol_automatic_route_checkin_never_submits_saved_password_for_target_probe() {
    let entry = crate::adapters::checkin_http::ENTRY_URL;
    let transport = TranscriptTransport::new(vec![
        (
            HttpRequest::get(entry).header("Accept", "application/json"),
            Err(TransportError::Unreachable),
        ),
        (
            status_request(RouteMode::WebVpn, Some("VPN=synthetic")),
            Ok(uc_expired()),
        ),
    ]);
    let service = client(transport.clone(), RoutePreference::Automatic);
    service
        .vault
        .save(
            "sy2501001",
            &crate::auth::Credentials {
                username: "sy2501001".into(),
                password: "synthetic-only".into(),
                captcha_text: None,
            },
        )
        .unwrap();
    let error = service
        .load_checkin_on_date(Some("2026-01-01".into()), true)
        .await
        .unwrap_err();
    assert_eq!(error.code, ErrorCode::ModuleAuthRequired);
    assert_eq!(service.session.route(), RouteMode::Direct);
    assert!(service.status().signed_in());
    transport.assert_finished();
}
