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
