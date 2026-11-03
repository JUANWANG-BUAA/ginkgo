use super::{cas, login::fetch_login_page, session::Session, vault::MemoryVault, *};
use crate::{
    foundation::http::{HttpMethod, HttpResponse, TransportError},
    test_support::MockTransport,
    ErrorCode,
};

const FORM_PAGE: &str = r#"<html><body>
  <form action="/login" method="post">
    <input type="hidden" name="execution" value="abc+def/ghi=" />
    <input type="text" name="username" />
    <input type="password" name="password" />
  </form>
</body></html>"#;

fn login_page() -> HttpResponse {
    HttpResponse::new(200, LOGIN_URL, FORM_PAGE)
}

fn credentials() -> Credentials {
    Credentials {
        username: "sy2501001".into(),
        password: "pa+ss/word".into(),
        captcha_text: None,
    }
}

fn uc_ok() -> HttpResponse {
    HttpResponse::new(
        200,
        UC_STATUS_URL,
        r#"{"code":0,"data":{"schoolid":"sy2501001","name":"fixture"}}"#,
    )
}

#[tokio::test]
async fn uc_activation_known_http_cas_redirect_uses_https_secure_cookie_and_one_password_post() {
    let legacy_cas = "http://sso.buaa.edu.cn/login?service=https%3A%2F%2Fuc.buaa.edu.cn%2Fapi%2Fcallback%3Ftarget%3Da%252Bb%252Fc%2525&dup=1&dup=2&literal=a+b";
    let secure_cas = legacy_cas.replacen("http:", "https:", 1);
    let home = "https://uc.buaa.edu.cn/";
    let callback = "https://uc.buaa.edu.cn/api/callback?ticket=ST-synthetic";
    let transport = MockTransport::with_responses(vec![
        login_page(),
        HttpResponse::new(302, LOGIN_URL, "")
            .with_header("Location", home)
            .with_set_cookie("CASTGC=TGT-synthetic; Path=/; Secure; HttpOnly"),
        HttpResponse::new(200, home, "service ticket consumed"),
        HttpResponse::new(302, UC_ACTIVATION_URL, "").with_header("Location", legacy_cas),
        HttpResponse::new(302, &secure_cas, "").with_header("Location", callback),
        HttpResponse::new(200, callback, "activated"),
        uc_ok(),
    ]);
    let session = Session::new(transport.clone());
    assert!(matches!(
        login(&session, &credentials()).await.expect("activated"),
        LoginResult::SignedIn(_)
    ));
    let requests = transport.requests();
    // Consume the target ticket, then activate UC on the same fixed route.
    assert_eq!(requests.len(), 7);
    assert_eq!(requests[2].url, home);
    assert_eq!(
        requests
            .iter()
            .filter(|r| r.method == HttpMethod::Post)
            .count(),
        1
    );
    assert_eq!(
        requests[4].url, secure_cas,
        "only the scheme changes, including duplicate and encoded query values"
    );
    assert_eq!(requests[4].method, HttpMethod::Get);
    assert_eq!(
        requests[4].header_value("Cookie"),
        Some("CASTGC=TGT-synthetic")
    );
    assert!(requests.iter().all(|r| r.url.starts_with("https://")));
}

#[tokio::test]
async fn login_form_actions_cannot_change_the_fixed_ubaa_password_target() {
    for action in [
        "http://sso.buaa.edu.cn/login",
        "https://sso.buaa.edu.cn.evil.example/login",
        "https://auth.evil.example/login",
        "https://sso.buaa.edu.cn:8443/login",
        "https://user:secret@sso.buaa.edu.cn/login",
        "ftp://sso.buaa.edu.cn/login",
    ] {
        let body = FORM_PAGE.replace(r#"action="/login""#, &format!(r#"action="{action}""#));
        let transport = MockTransport::with_responses(vec![
            HttpResponse::new(200, LOGIN_URL, body),
            HttpResponse::new(401, LOGIN_URL, "<div id=\"errorDiv\">fixture refusal</div>"),
        ]);
        let session = Session::new(transport.clone());
        let error = login(&session, &credentials())
            .await
            .expect_err("the fixed CAS endpoint rejected the request");
        assert_eq!(error.code, ErrorCode::PreLoginTip, "action {action}");
        assert_eq!(
            transport.request_count(),
            2,
            "exactly one password POST to the fixed CAS endpoint"
        );
        let requests = transport.requests();
        assert_eq!(requests[0].method, HttpMethod::Get);
        assert_eq!(requests[1].method, HttpMethod::Post);
        assert_eq!(requests[1].url, LOGIN_URL);
    }
}

#[tokio::test]
async fn unknown_http_redirects_fail_before_following_in_auth_and_generic_get_chains() {
    for location in [
        "http://uc.buaa.edu.cn/api/login",
        "http://sso.buaa.edu.cn/cas/login",
        "http://sso.buaa.edu.cn/login/extra",
        "http://sso.buaa.edu.cn:8080/login",
        "http://sso.buaa.edu.cn:80/login",
        "http://user@sso.buaa.edu.cn/login",
        "http://sso.buaa.edu.cn.evil.example/login",
    ] {
        for flow in 0..2 {
            let transport = MockTransport::with_responses(vec![
                HttpResponse::new(302, LOGIN_URL, "").with_header("Location", location),
                HttpResponse::new(200, location, FORM_PAGE),
            ]);
            let session = Session::new(transport.clone());
            let error = match flow {
                0 => activate_uc(&session)
                    .await
                    .expect_err("unknown insecure UC hop"),
                _ => session
                    .send_following_redirects(crate::foundation::http::HttpRequest::get(LOGIN_URL))
                    .await
                    .expect_err("unknown insecure business GET hop"),
            };
            assert_eq!(error.detail.as_deref(), Some("insecure_redirect"));
            assert_eq!(
                transport.request_count(),
                1,
                "no request is sent to an unconfirmed HTTP target"
            );
        }
    }
}

#[tokio::test]
async fn generic_get_upgrades_known_http_location_but_cas_preload_does_not_follow_it() {
    let legacy =
        "http://sso.buaa.edu.cn/login?service=https%3A%2F%2Fexample.test%2Fcb%3Fx%3D%252B%252F";
    let secure = legacy.replacen("http:", "https:", 1);
    for flow in 0..2 {
        let transport = MockTransport::with_responses(vec![
            HttpResponse::new(302, LOGIN_URL, "").with_header("Location", legacy),
            HttpResponse::new(200, &secure, FORM_PAGE),
        ]);
        let session = Session::new(transport.clone());
        if flow == 0 {
            assert!(matches!(
                fetch_login_page(&session).await.unwrap(),
                LoginPage::ExistingSession
            ));
            assert_eq!(transport.request_count(), 1);
        } else {
            session
                .send_following_redirects(crate::foundation::http::HttpRequest::get(LOGIN_URL))
                .await
                .unwrap();
            assert_eq!(transport.requests()[1].url, secure);
        }
        assert!(transport
            .requests()
            .iter()
            .all(|request| request.method == HttpMethod::Get));
    }
}

#[tokio::test]
async fn secure_cookie_rule_is_unchanged_and_password_post_uses_fixed_login_url() {
    let form_action = "https://sso.buaa.edu.cn/login?service=unchanged%2B";
    let body = FORM_PAGE.replace(r#"action="/login""#, &format!(r#"action="{form_action}""#));
    let transport = MockTransport::with_responses(vec![
        HttpResponse::new(200, LOGIN_URL, body)
            .with_set_cookie("CASTGC=TGT-synthetic; Path=/; Secure; HttpOnly"),
        HttpResponse::new(401, LOGIN_URL, "<div id=\"errorDiv\">fixture refusal</div>"),
    ]);
    let session = Session::new(transport.clone());
    assert_eq!(
        login(&session, &credentials())
            .await
            .expect_err("upstream rejected")
            .code,
        ErrorCode::PreLoginTip
    );
    let requests = transport.requests();
    assert_eq!(requests.len(), 2);
    assert_eq!(requests[1].method, HttpMethod::Post);
    assert_eq!(
        requests[1].url, LOGIN_URL,
        "UBAA ignores the page action and its query for the password POST"
    );
    assert_eq!(
        requests[1].header_value("Cookie"),
        Some("CASTGC=TGT-synthetic")
    );
    let mut cookies = crate::foundation::cookie::CookieJar::new();
    cookies.store(
        LOGIN_URL,
        "CASTGC=TGT-synthetic; Path=/; Secure; HttpOnly",
        0,
    );
    assert!(cookies
        .header_for("http://sso.buaa.edu.cn/login", 1)
        .is_none());
    assert_eq!(
        cookies.header_for(LOGIN_URL, 1).as_deref(),
        Some("CASTGC=TGT-synthetic")
    );
}

#[tokio::test]
async fn captcha_page_returns_a_challenge_without_submitting() {
    let captcha_page = FORM_PAGE.replace(
        "</form>",
        "<script>config.captcha = { type: 'slider', id: 'cap-1' };</script></form>",
    );
    let transport =
        MockTransport::with_responses(vec![HttpResponse::new(200, LOGIN_URL, captcha_page)]);
    let session = Session::new(transport);

    match login(&session, &credentials()).await.expect("challenge") {
        LoginResult::CaptchaRequired { challenge, .. } => {
            assert_eq!(challenge.id, "cap-1");
            assert!(challenge.image_url.contains("captchaId=cap-1"));
        }
        LoginResult::SignedIn(_) => panic!("captcha must not sign in"),
    }
    assert_eq!(session.transport().request_count(), 1);
}

#[tokio::test]
async fn successful_login_keeps_castgc_inside_rust_and_returns_profile() {
    let transport = MockTransport::with_responses(vec![
        login_page(),
        HttpResponse::new(302, LOGIN_URL, "")
            .with_header("Location", "https://sso.buaa.edu.cn/login?ticket=ST-1")
            .with_set_cookie("CASTGC=TGT-fixture; Path=/; Secure; HttpOnly"),
        HttpResponse::new(
            200,
            "https://sso.buaa.edu.cn/login?ticket=ST-1",
            "<html>ok</html>",
        ),
        HttpResponse::new(200, UC_ACTIVATION_URL, ""),
        uc_ok(),
    ]);
    let session = Session::new(transport);

    let result = login(&session, &credentials()).await.expect("signed in");
    assert_eq!(
        result,
        LoginResult::SignedIn(UserProfile {
            school_id: "sy2501001".into(),
            name: "fixture".into(),
        })
    );

    let requests = session.transport().requests();
    let post = requests
        .iter()
        .find(|request| request.method == HttpMethod::Post)
        .expect("form post");
    assert_eq!(post.url, LOGIN_URL);
    let body = post.body.as_deref().expect("body");
    assert!(body.contains("execution=abc%2Bdef%2Fghi%3D"));
    assert!(body.contains("password=pa%2Bss%2Fword"));

    let ticket = requests
        .iter()
        .find(|request| request.url.contains("ticket=ST-1"))
        .expect("ticket hop");
    assert_eq!(ticket.header_value("Cookie"), Some("CASTGC=TGT-fixture"));
}

#[tokio::test]
async fn unexplained_login_form_is_not_proof_of_wrong_credentials() {
    let transport = MockTransport::with_responses(vec![
        login_page(),
        HttpResponse::new(200, LOGIN_URL, "<input name=\"execution\" value=\"again\">"),
    ]);
    let error = login(&Session::new(transport.clone()), &credentials())
        .await
        .expect_err("identity is not established");
    assert_eq!(error.code, ErrorCode::PreLoginTip);
    assert!(error
        .detail
        .as_deref()
        .is_some_and(|text| text.contains("未提供明确原因")));
    assert_eq!(transport.request_count(), 2);
    assert_eq!(
        transport
            .requests()
            .iter()
            .filter(|r| r.method == HttpMethod::Post)
            .count(),
        1
    );
}

#[tokio::test]
async fn login_form_preserves_explicit_school_message_without_guessing_credentials() {
    let body = format!("{FORM_PAGE}<div id=\"errorDiv\">认证流程暂不可用，请稍后重试</div>");
    let transport =
        MockTransport::with_responses(vec![login_page(), HttpResponse::new(200, LOGIN_URL, body)]);
    let error = login(&Session::new(transport.clone()), &credentials())
        .await
        .unwrap_err();
    assert_eq!(error.code, ErrorCode::PreLoginTip);
    assert_eq!(
        error.detail.as_deref(),
        Some("认证流程暂不可用，请稍后重试")
    );
    assert_eq!(transport.request_count(), 2);
}

#[tokio::test]
async fn explicit_credential_rejection_keeps_its_typed_error() {
    for message in ["账号或密码错误", "用户名或密码错误"] {
        let body = format!("{FORM_PAGE}<div id=\"errorDiv\">{message}</div>");
        let transport = MockTransport::with_responses(vec![
            login_page(),
            HttpResponse::new(200, LOGIN_URL, body),
        ]);
        let error = login(&Session::new(transport.clone()), &credentials())
            .await
            .unwrap_err();
        assert_eq!(error.code, ErrorCode::InvalidCredentials);
        assert_eq!(transport.request_count(), 2);
    }
}

#[tokio::test]
async fn unauthorized_navigation_is_not_a_password_rejection() {
    for (responses, expected) in [
        (
            vec![HttpResponse::new(401, LOGIN_URL, "")],
            ErrorCode::ServiceUnavailable,
        ),
        (
            vec![
                login_page(),
                HttpResponse::new(302, LOGIN_URL, "")
                    .with_header("Location", "/login?next=fixture"),
                HttpResponse::new(401, LOGIN_URL, ""),
            ],
            ErrorCode::PreLoginTip,
        ),
        (
            vec![
                HttpResponse::new(302, LOGIN_URL, "")
                    .with_header("Location", "https://uc.buaa.edu.cn/fixture"),
                HttpResponse::new(200, UC_ACTIVATION_URL, ""),
                HttpResponse::new(401, UC_STATUS_URL, ""),
            ],
            ErrorCode::ServiceUnavailable,
        ),
    ] {
        let transport = MockTransport::with_responses(responses);
        let error = login(&Session::new(transport.clone()), &credentials())
            .await
            .unwrap_err();
        assert_eq!(error.code, expected);
        assert!(
            transport
                .requests()
                .iter()
                .filter(|r| r.method == HttpMethod::Post)
                .count()
                <= 1
        );
    }
}

#[tokio::test]
async fn unauthorized_credential_post_reports_unknown_authentication_refusal() {
    let transport =
        MockTransport::with_responses(vec![login_page(), HttpResponse::new(401, LOGIN_URL, "")]);
    let error = login(&Session::new(transport.clone()), &credentials())
        .await
        .unwrap_err();
    assert_eq!(error.code, ErrorCode::PreLoginTip);
    assert!(error
        .detail
        .as_deref()
        .is_some_and(|text| text.contains("未提供明确原因")));
    assert_eq!(transport.request_count(), 2);
}

#[tokio::test]
async fn uc_server_error_does_not_publish_an_unverified_identity() {
    let transport = MockTransport::with_responses(vec![
        login_page(),
        HttpResponse::new(302, LOGIN_URL, "")
            .with_header("Location", "https://uc.buaa.edu.cn/?ticket=ST-synthetic")
            .with_set_cookie("CASTGC=TGT-fixture; Path=/; Secure"),
        HttpResponse::new(
            200,
            "https://uc.buaa.edu.cn/?ticket=ST-synthetic",
            "service",
        ),
        HttpResponse::new(200, UC_ACTIVATION_URL, ""),
        HttpResponse::new(500, UC_STATUS_URL, "temporary"),
    ]);
    let session = Session::new(transport);
    assert_eq!(
        login(&session, &credentials()).await.unwrap_err().code,
        ErrorCode::ServiceUnavailable
    );
    assert!(session.direct_cookie_present());
}

#[tokio::test]
async fn unexpected_login_page_and_broken_directory_never_sign_in() {
    let session = Session::new(MockTransport::with_responses(vec![
        login_page(),
        HttpResponse::new(200, LOGIN_URL, "<html>unknown school page</html>"),
        HttpResponse::new(200, UC_ACTIVATION_URL, ""),
        HttpResponse::new(200, UC_STATUS_URL, "<html>maintenance</html>"),
    ]));
    assert_eq!(
        login(&session, &credentials()).await.unwrap_err().code,
        ErrorCode::ChangedResponse
    );
}

#[tokio::test]
async fn policy_block_switches_automatic_mode_to_webvpn_once() {
    let transport = MockTransport::with_responses(vec![
        HttpResponse::new(200, LOGIN_URL, "访问策略禁止 没有权限访问相应的资源"),
        login_page(),
    ]);
    let session = Session::new(transport);
    let page = fetch_login_page(&session).await.expect("wrapped page");
    assert!(matches!(page, LoginPage::Form { .. }));
    assert_eq!(session.route(), SessionRoute::WebVpn);

    let requests = session.transport().requests();
    assert_eq!(requests[0].url, LOGIN_URL);
    assert!(requests[1].url.starts_with("https://d.buaa.edu.cn/https/"));
}

#[tokio::test]
async fn webvpn_cookies_never_leak_into_direct_requests() {
    let transport = MockTransport::with_responses(vec![
        HttpResponse::new(200, "https://uc.buaa.edu.cn/", "")
            .with_set_cookie("WEBVPN-SESSION=fixture; Path=/; Secure"),
        HttpResponse::new(200, "https://uc.buaa.edu.cn/", ""),
        HttpResponse::new(200, UC_STATUS_URL, ""),
    ]);
    let session = Session::new(transport);
    session.set_route(SessionRoute::WebVpn);
    let _ = session
        .send(crate::foundation::http::HttpRequest::get(UC_STATUS_URL))
        .await;
    let _ = session
        .send(crate::foundation::http::HttpRequest::get(UC_STATUS_URL))
        .await;
    session.set_route(SessionRoute::Direct);
    let _ = session
        .send(crate::foundation::http::HttpRequest::get(UC_STATUS_URL))
        .await;

    let requests = session.transport().requests();
    assert_eq!(
        requests[1].header_value("Cookie"),
        Some("WEBVPN-SESSION=fixture")
    );
    assert!(requests[2].header_value("Cookie").is_none());
}

#[test]
fn captcha_parser_ignores_default_pages() {
    assert!(cas::detect_captcha(FORM_PAGE).is_none());
}

#[test]
fn vault_diagnostic_only_touches_the_reserved_prefix() {
    let vault = MemoryVault::default();
    assert!(!vault::verify_vault_round_trip(
        &vault,
        "sy2501001",
        "fixture-secret"
    ));
    assert!(vault.accounts().expect("accounts").is_empty());
    assert!(vault::verify_vault_round_trip(
        &vault,
        "__ginkgo_vault_test__account",
        "fixture-secret"
    ));
    assert!(vault.accounts().expect("accounts").is_empty());
}

#[tokio::test]
async fn following_redirects_carries_cookies_and_resolves_relative_locations() {
    let transport = MockTransport::with_responses(vec![
        HttpResponse::new(302, "https://byxt.buaa.edu.cn/start", "")
            .with_header("Location", "/next")
            .with_set_cookie("JSESSIONID=abc; Path=/; Secure"),
        HttpResponse::new(302, "https://byxt.buaa.edu.cn/next", "")
            .with_header("Location", "https://byxt.buaa.edu.cn/final"),
        HttpResponse::new(200, "https://byxt.buaa.edu.cn/final", r#"{"code":"0"}"#),
    ]);
    let session = Session::new(transport.clone());
    let response = session
        .send_following_redirects(crate::foundation::http::HttpRequest::get(
            "https://byxt.buaa.edu.cn/start",
        ))
        .await
        .expect("redirect chain");
    assert_eq!(response.final_url, "https://byxt.buaa.edu.cn/final");
    let requests = transport.requests();
    assert_eq!(requests.len(), 3);
    assert_eq!(requests[1].header_value("Cookie"), Some("JSESSIONID=abc"));
}

#[tokio::test]
async fn webvpn_responses_are_normalized_before_redirects_are_followed() {
    use crate::foundation::webvpn;
    let start = "https://iclass.buaa.edu.cn:8346/?type=jumpMyCenter";
    let landed = "https://iclass.buaa.edu.cn:8346/?loginName=fixture";
    let wrapped_start = webvpn::wrap(start).expect("wrap start");
    let wrapped_landed = webvpn::wrap(landed).expect("wrap landed");
    // Gateway-relative hop: the gateway emits its own path, not the upstream URL.
    let gateway_relative = wrapped_landed
        .strip_prefix("https://d.buaa.edu.cn")
        .expect("gateway prefix")
        .to_string();
    let transport = MockTransport::with_responses(vec![
        HttpResponse::new(302, &wrapped_start, "").with_header("Location", &gateway_relative),
        HttpResponse::new(200, &wrapped_landed, "{}"),
    ]);
    let session = Session::new(transport.clone());
    session.set_route(SessionRoute::WebVpn);
    let response = session
        .send_following_redirects(crate::foundation::http::HttpRequest::get(start))
        .await
        .expect("gateway redirect chain");
    assert_eq!(response.final_url, landed);
    let requests = transport.requests();
    assert_eq!(requests.len(), 2);
    assert_eq!(requests[0].url, wrapped_start);
    assert_eq!(requests[1].url, wrapped_landed);
}

#[tokio::test]
async fn webvpn_absolute_locations_stay_on_the_gateway_when_gateway_owned() {
    use crate::foundation::webvpn;
    let start = "https://iclass.buaa.edu.cn:8346/?type=jumpMyCenter";
    let wrapped_start = webvpn::wrap(start).expect("wrap start");
    let transport = MockTransport::with_responses(vec![
        HttpResponse::new(302, &wrapped_start, "").with_header(
            "Location",
            "https://d.buaa.edu.cn/https-8346/0000/?loginName=fixture",
        ),
        HttpResponse::new(
            200,
            "https://d.buaa.edu.cn/https-8346/0000/?loginName=fixture",
            "",
        ),
    ]);
    let session = Session::new(transport.clone());
    session.set_route(SessionRoute::WebVpn);
    let response = session
        .send_following_redirects(crate::foundation::http::HttpRequest::get(start))
        .await
        .expect("absolute gateway location");
    // An undecodable gateway host keeps the gateway URL, but it is still a
    // resolvable absolute location: no upstream mis-join.
    assert_eq!(
        response.final_url,
        "https://d.buaa.edu.cn/https-8346/0000/?loginName=fixture"
    );
    assert_eq!(
        transport.requests()[1].url,
        "https://d.buaa.edu.cn/https-8346/0000/?loginName=fixture"
    );
}

#[tokio::test]
async fn redirect_loops_are_bounded() {
    let transport = MockTransport::with_responses(
        (0..11)
            .map(|_| {
                HttpResponse::new(302, "https://byxt.buaa.edu.cn/loop", "")
                    .with_header("Location", "/loop")
            })
            .collect(),
    );
    let session = Session::new(transport.clone());
    assert_eq!(
        session
            .send_following_redirects(crate::foundation::http::HttpRequest::get(
                "https://byxt.buaa.edu.cn/loop",
            ))
            .await
            .expect_err("loop")
            .code,
        ErrorCode::RedirectLimit
    );
    assert_eq!(transport.request_count(), 10);
}

#[tokio::test]
async fn webvpn_maps_origin_and_referer_with_the_request() {
    use crate::foundation::{http::HttpRequest, webvpn};
    let transport = MockTransport::with_responses(vec![HttpResponse::new(200, UC_STATUS_URL, "")]);
    let session = Session::new(transport);
    session.set_route(SessionRoute::WebVpn);
    session
        .send(
            HttpRequest::get(UC_STATUS_URL)
                .header("Origin", "https://booking.lib.buaa.edu.cn")
                .header("Referer", "https://booking.lib.buaa.edu.cn/v4/"),
        )
        .await
        .unwrap();
    let requests = session.transport().requests();
    assert_eq!(
        requests[0].header_value("Origin"),
        Some(
            webvpn::wrap("https://booking.lib.buaa.edu.cn")
                .unwrap()
                .as_str()
        )
    );
    assert_eq!(
        requests[0].header_value("Referer"),
        Some(
            webvpn::wrap("https://booking.lib.buaa.edu.cn/v4/")
                .unwrap()
                .as_str()
        )
    );
}

/// A safe direct read that cannot reach the campus is what opens the
/// gateway. Retrying it there also establishes the gateway session that later
/// module reads need — without it, automatic mode met an unauthenticated
/// gateway and answered with its login page. The password itself is still
/// submitted exactly once: only GETs are replayed.
#[tokio::test]
async fn a_silent_network_failure_opens_the_gateway_without_a_second_password() {
    let transport = MockTransport::with_results(vec![
        Err(TransportError::Unreachable),
        Ok(HttpResponse::new(200, "https://d.buaa.edu.cn/login", "")),
    ]);
    let session = Session::new(transport.clone());
    let _ = fetch_login_page(&session).await;
    assert_eq!(
        session.transport().request_count(),
        2,
        "the safe read is retried once through the gateway"
    );
    assert_eq!(session.route(), super::session::RouteMode::WebVpn);
    assert!(
        session.transport().requests()[1]
            .url
            .starts_with("https://d.buaa.edu.cn/https/"),
        "the retry goes through the gateway"
    );
    assert_eq!(
        session
            .transport()
            .requests()
            .iter()
            .filter(|request| request.method == HttpMethod::Post)
            .count(),
        0,
        "no password is submitted by a read"
    );
}

#[tokio::test]
async fn password_expiry_acknowledgement_401_is_not_a_password_rejection() {
    let expiry = FORM_PAGE.replace(
        "</form>",
        "<button name=\"_eventId\" value=\"ignoreAndContinue\">继续使用</button></form>",
    );
    let transport = MockTransport::with_responses(vec![
        login_page(),
        HttpResponse::new(200, LOGIN_URL, expiry),
        HttpResponse::new(401, LOGIN_URL, ""),
    ]);
    let error = login(&Session::new(transport.clone()), &credentials())
        .await
        .unwrap_err();
    assert_eq!(error.code, ErrorCode::PreLoginTip);
    let posts: Vec<_> = transport
        .requests()
        .into_iter()
        .filter(|r| r.method == HttpMethod::Post)
        .collect();
    assert_eq!(posts.len(), 2);
    assert!(!posts[1].body.as_deref().unwrap().contains("password="));
}

#[tokio::test]
async fn credential_post_401_preserves_policy_or_captcha_refusal_instead_of_blaming_password() {
    for (body, expected) in [
        (
            "<div id=\"errorDiv\">验证码错误</div>",
            ErrorCode::PreLoginTip,
        ),
        (
            "<div id=\"errorDiv\">访问策略禁止</div>",
            ErrorCode::AccessPolicyDenied,
        ),
    ] {
        let transport = MockTransport::with_responses(vec![
            login_page(),
            HttpResponse::new(401, LOGIN_URL, body),
        ]);
        let error = login(&Session::new(transport.clone()), &credentials())
            .await
            .unwrap_err();
        assert_eq!(error.code, expected);
        if expected == ErrorCode::PreLoginTip {
            assert_eq!(error.detail.as_deref(), Some("验证码错误"));
        }
        assert_eq!(transport.request_count(), 2);
    }
}

#[tokio::test]
async fn final_cas_redirect_error_is_reported_after_consuming_its_target_before_uc() {
    let target = "https://uc.buaa.edu.cn/error?exception.message=fixture%2Bfailure%252Bdetail";
    let transport = MockTransport::with_responses(vec![
        login_page(),
        HttpResponse::new(302, LOGIN_URL, "").with_header("Location", target),
        HttpResponse::new(200, target, ""),
    ]);
    let error = login(&Session::new(transport.clone()), &credentials())
        .await
        .expect_err("reported error must not publish identity");
    assert_eq!(error.code, ErrorCode::PreLoginTip);
    assert_eq!(error.detail.as_deref(), Some("fixture+failure%2Bdetail"));
    assert_eq!(transport.request_count(), 3);
    assert_eq!(transport.requests()[2].url, target);
}

#[tokio::test]
async fn initial_redirect_activates_uc_without_inspecting_the_unused_location() {
    let transport = MockTransport::with_responses(vec![
        HttpResponse::new(302, LOGIN_URL, "").with_header(
            "Location",
            "https://uc.buaa.edu.cn/error?exception.message=fixture-refusal",
        ),
        HttpResponse::new(200, UC_ACTIVATION_URL, ""),
        uc_ok(),
    ]);
    let result = login(&Session::new(transport.clone()), &credentials())
        .await
        .unwrap();
    assert!(matches!(result, LoginResult::SignedIn(_)));
    assert_eq!(transport.request_count(), 3);
    assert_eq!(transport.requests()[1].url, UC_ACTIVATION_URL);
    assert_eq!(transport.requests()[2].url, UC_STATUS_URL);
    assert!(transport
        .requests()
        .iter()
        .all(|r| r.method == HttpMethod::Get));
}

#[tokio::test]
async fn uc_activation_redirect_queries_do_not_replace_the_uc_status_check() {
    let transport = MockTransport::with_responses(vec![
        login_page(),
        HttpResponse::new(302, LOGIN_URL, "")
            .with_header("Location", "https://uc.buaa.edu.cn/cb?ticket=ST-synthetic"),
        HttpResponse::new(
            200,
            "https://uc.buaa.edu.cn/cb?ticket=ST-synthetic",
            "service",
        ),
        HttpResponse::new(302, UC_ACTIVATION_URL, "").with_header(
            "Location",
            "https://uc.buaa.edu.cn/error?exception.message=fixture-activation-refusal",
        ),
        HttpResponse::new(200, "https://uc.buaa.edu.cn/error", ""),
        uc_ok(),
    ]);
    let result = login(&Session::new(transport.clone()), &credentials())
        .await
        .expect("UC status is valid");
    assert!(matches!(result, LoginResult::SignedIn(_)));
    let requests = transport.requests();
    assert_eq!(requests.len(), 6);
    assert_eq!(requests[3].url, UC_ACTIVATION_URL);
    assert!(requests[4]
        .url
        .contains("exception.message=fixture-activation-refusal"));
    assert_eq!(requests[5].url, UC_STATUS_URL);
}

#[tokio::test]
async fn uc_activation_html_does_not_replace_status_identity_validation() {
    for body in [
        "<div id=\"errorDiv\">fixture activation message</div>",
        "<div id=\"errorDiv\" style=\"display:none\">fixture activation message</div>",
        "<div class=\"tip-text\" hidden>fixture activation message</div>",
    ] {
        for valid in [true, false] {
            let status = if valid {
                uc_ok()
            } else {
                HttpResponse::new(200, UC_STATUS_URL, r#"{"code":10600,"data":null}"#)
            };
            let transport = MockTransport::with_responses(vec![
                HttpResponse::new(200, UC_ACTIVATION_URL, body),
                status,
            ]);
            let session = Session::new(transport.clone());
            activate_uc(&session)
                .await
                .expect("UC navigation HTML is not a CAS refusal");
            let result = validate_session(&session).await;
            if valid {
                assert_eq!(result.unwrap().school_id, "sy2501001");
            } else {
                assert_eq!(result.unwrap_err().code, ErrorCode::SessionExpired);
            }
            let requests = transport.requests();
            assert_eq!(requests.len(), 2);
            assert_eq!(requests[0].url, UC_ACTIVATION_URL);
            assert_eq!(requests[1].url, UC_STATUS_URL);
            assert!(requests.iter().all(|r| r.method == HttpMethod::Get));
        }
    }
}

#[tokio::test]
async fn uc_activation_landing_status_does_not_replace_the_ubaa_status_check() {
    for status in [204, 401, 403, 404, 483, 500, 503] {
        for valid in [true, false] {
            let identity = if valid {
                uc_ok()
            } else {
                HttpResponse::new(200, UC_STATUS_URL, r#"{"code":10600,"data":null}"#)
            };
            let transport = MockTransport::with_responses(vec![
                HttpResponse::new(status, UC_ACTIVATION_URL, "synthetic landing page"),
                identity,
            ]);
            let session = Session::new(transport.clone());
            activate_uc(&session).await.unwrap();
            let result = validate_session(&session).await;
            if valid {
                assert_eq!(result.unwrap().school_id, "sy2501001");
            } else {
                assert_eq!(result.unwrap_err().code, ErrorCode::SessionExpired);
            }
            let requests = transport.requests();
            assert_eq!(requests.len(), 2);
            assert_eq!(requests[0].url, UC_ACTIVATION_URL);
            assert_eq!(requests[1].url, UC_STATUS_URL);
            assert!(requests.iter().all(|r| r.method == HttpMethod::Get));
        }
    }
}

#[tokio::test]
async fn credential_401_with_captcha_is_a_refusal_like_ubaa_without_reposting() {
    for route in [RouteMode::Direct, RouteMode::WebVpn] {
        for tip in ["", "<div id=\"errorDiv\">验证码错误，请重新输入</div>"] {
            let body = format!(
                r#"<form action="/login?service=synthetic"><input type="hidden" name="execution" value="fresh-execution"></form><script>config.captcha = {{type: 'image', id: 'fresh-captcha'}};</script>{tip}"#
            );
            let wire = if route == RouteMode::WebVpn {
                crate::foundation::webvpn::wrap(LOGIN_URL).unwrap()
            } else {
                LOGIN_URL.to_string()
            };
            let transport = MockTransport::with_responses(vec![
                login_page(),
                HttpResponse::new(401, wire, body),
            ]);
            let session = Session::new(transport.clone());
            session.set_route(route);
            let error = login(&session, &credentials())
                .await
                .expect_err("UBAA reports a failed submission, not a preload challenge");
            assert_eq!(error.code, ErrorCode::PreLoginTip);
            if !tip.is_empty() {
                assert_eq!(error.detail.as_deref(), Some("验证码错误，请重新输入"));
            }
            assert_eq!(transport.request_count(), 2);
            assert_eq!(
                transport
                    .requests()
                    .iter()
                    .filter(|r| r.method == HttpMethod::Post)
                    .count(),
                1
            );
        }
    }
}

#[tokio::test]
async fn credential_401_captcha_does_not_hide_policy_or_other_explicit_refusals() {
    for (tip, expected) in [
        ("访问策略禁止", ErrorCode::AccessPolicyDenied),
        ("账号或密码错误", ErrorCode::InvalidCredentials),
        ("请在学校网页处理账号状态", ErrorCode::PreLoginTip),
    ] {
        let body = format!(
            r#"<input name="execution" value="fresh"><script>config.captcha = {{type: 'image', id: 'fresh'}};</script><div id="errorDiv">{tip}</div>"#
        );
        let transport = MockTransport::with_responses(vec![
            login_page(),
            HttpResponse::new(401, LOGIN_URL, body),
        ]);
        let error = login(&Session::new(transport.clone()), &credentials())
            .await
            .unwrap_err();
        assert_eq!(error.code, expected);
        assert_eq!(transport.request_count(), 2);
    }
}

#[tokio::test]
async fn credential_401_captcha_refuses_without_following_its_unsafe_action() {
    let body = r#"<form action="https://untrusted.example/login"><input name="execution" value="fresh"></form><script>config.captcha = {type: 'image', id: 'fresh'};</script>"#;
    let transport =
        MockTransport::with_responses(vec![login_page(), HttpResponse::new(401, LOGIN_URL, body)]);
    let error = login(&Session::new(transport.clone()), &credentials())
        .await
        .unwrap_err();
    assert_eq!(error.code, ErrorCode::PreLoginTip);
    assert_eq!(transport.request_count(), 2);
}

#[tokio::test]
async fn unauthenticated_navigation_or_incomplete_401_form_never_becomes_a_captcha_retry() {
    let form = r#"<input name="execution" value="fresh"><script>config.captcha = {type: 'image', id: 'fresh'};</script>"#;
    let transport = MockTransport::with_responses(vec![HttpResponse::new(401, LOGIN_URL, form)]);
    let error = fetch_login_page(&Session::new(transport.clone()))
        .await
        .unwrap_err();
    assert_eq!(error.code, ErrorCode::ServiceUnavailable);
    assert_eq!(transport.request_count(), 1);
    let incomplete = r#"<script>config.captcha = {type: 'image', id: 'fresh'};</script>"#;
    let transport = MockTransport::with_responses(vec![
        login_page(),
        HttpResponse::new(401, LOGIN_URL, incomplete),
    ]);
    let error = login(&Session::new(transport.clone()), &credentials())
        .await
        .unwrap_err();
    assert_eq!(error.code, ErrorCode::PreLoginTip);
    assert_eq!(transport.request_count(), 2);
}

#[tokio::test]
async fn cas_paragraph_error_cannot_be_overridden_by_valid_uc_identity() {
    let transport = MockTransport::with_responses(vec![
        login_page(),
        HttpResponse::new(
            200,
            LOGIN_URL,
            r#"<p class="errors">合成账号状态需要人工处理</p>"#,
        ),
        HttpResponse::new(200, UC_ACTIVATION_URL, "activated"),
        uc_ok(),
    ]);
    let error = login(&Session::new(transport.clone()), &credentials())
        .await
        .expect_err("explicit paragraph refusal");
    assert_eq!(error.code, ErrorCode::PreLoginTip);
    assert_eq!(error.detail.as_deref(), Some("合成账号状态需要人工处理"));
    assert_eq!(
        transport.request_count(),
        2,
        "must not activate UC after explicit refusal"
    );
}
