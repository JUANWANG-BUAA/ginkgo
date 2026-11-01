use super::{cas, login::fetch_login_page, session::Session, vault::MemoryVault, *};
use crate::{
    foundation::http::{HttpMethod, HttpResponse},
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
        HttpResponse::new(200, home, "<html>home</html>"),
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
    assert_eq!(requests.len(), 7);
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
async fn login_form_actions_outside_the_documented_cas_target_never_receive_credentials() {
    for action in [
        "http://sso.buaa.edu.cn/login",
        "https://sso.buaa.edu.cn.evil.example/login",
        "https://auth.evil.example/login",
        "https://sso.buaa.edu.cn:8443/login",
        "https://user:secret@sso.buaa.edu.cn/login",
        "ftp://sso.buaa.edu.cn/login",
    ] {
        let body = FORM_PAGE.replace(r#"action="/login""#, &format!(r#"action="{action}""#));
        let transport =
            MockTransport::with_responses(vec![HttpResponse::new(200, LOGIN_URL, body)]);
        let session = Session::new(transport.clone());
        let error = login(&session, &credentials())
            .await
            .expect_err("drifted form action must fail before any credential POST");
        assert_eq!(error.code, ErrorCode::ChangedResponse, "action {action}");
        assert_eq!(
            transport.request_count(),
            1,
            "action {action} must not receive a password request"
        );
        assert_eq!(transport.requests()[0].method, HttpMethod::Get);
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
        for flow in 0..3 {
            let transport = MockTransport::with_responses(vec![
                HttpResponse::new(302, LOGIN_URL, "").with_header("Location", location),
                HttpResponse::new(200, location, FORM_PAGE),
            ]);
            let session = Session::new(transport.clone());
            let error = match flow {
                0 => activate_uc(&session)
                    .await
                    .expect_err("unknown insecure UC hop"),
                1 => fetch_login_page(&session)
                    .await
                    .expect_err("unknown insecure CAS hop"),
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
async fn generic_get_and_cas_entry_upgrade_only_the_known_http_location() {
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
                LoginPage::Form { .. }
            ));
        } else {
            session
                .send_following_redirects(crate::foundation::http::HttpRequest::get(LOGIN_URL))
                .await
                .unwrap();
        }
        assert_eq!(transport.requests()[1].url, secure);
        assert!(transport
            .requests()
            .iter()
            .all(|request| request.method == HttpMethod::Get));
    }
}

#[tokio::test]
async fn secure_cookie_rule_is_unchanged_and_form_post_actions_are_not_rewritten() {
    let form_action = "https://sso.buaa.edu.cn/login?service=unchanged%2B";
    let body = FORM_PAGE.replace(r#"action="/login""#, &format!(r#"action="{form_action}""#));
    let transport = MockTransport::with_responses(vec![
        HttpResponse::new(200, LOGIN_URL, body)
            .with_set_cookie("CASTGC=TGT-synthetic; Path=/; Secure; HttpOnly"),
        HttpResponse::new(500, form_action, "synthetic"),
    ]);
    let session = Session::new(transport.clone());
    assert_eq!(
        login(&session, &credentials())
            .await
            .expect_err("upstream rejected")
            .code,
        ErrorCode::ServiceUnavailable
    );
    let requests = transport.requests();
    assert_eq!(requests.len(), 2);
    assert_eq!(requests[1].method, HttpMethod::Post);
    assert_eq!(
        requests[1].url, form_action,
        "form POST targets and encoded query values are unchanged"
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
        LoginResult::CaptchaRequired(challenge) => {
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
async fn wrong_credentials_return_a_typed_error() {
    let transport = MockTransport::with_responses(vec![
        login_page(),
        HttpResponse::new(200, LOGIN_URL, FORM_PAGE),
    ]);
    let session = Session::new(transport);
    assert_eq!(
        login(&session, &credentials())
            .await
            .expect_err("wrong")
            .code,
        ErrorCode::InvalidCredentials
    );
}

#[tokio::test]
async fn uc_server_error_is_transient_and_keeps_cookies() {
    let transport = MockTransport::with_responses(vec![
        login_page(),
        HttpResponse::new(302, LOGIN_URL, "")
            .with_header("Location", "https://sso.buaa.edu.cn/login?ticket=ST-2")
            .with_set_cookie("CASTGC=TGT-fixture; Path=/; Secure"),
        HttpResponse::new(
            200,
            "https://sso.buaa.edu.cn/login?ticket=ST-2",
            "<html>ok</html>",
        ),
        HttpResponse::new(200, UC_ACTIVATION_URL, ""),
        HttpResponse::new(500, UC_STATUS_URL, "temporary"),
    ]);
    let session = Session::new(transport);
    assert_eq!(
        login(&session, &credentials())
            .await
            .expect_err("temporary")
            .code,
        ErrorCode::ServiceUnavailable
    );
    assert!(session.direct_cookie_present());
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
