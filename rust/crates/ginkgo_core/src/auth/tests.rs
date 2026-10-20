use super::{cas, login::fetch_login_page, session::Session, *};
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
