use super::{
    session::{RouteMode, Session},
    Credentials, LoginResult, LOGIN_URL, UC_ACTIVATION_URL, UC_STATUS_URL,
};
use crate::{
    foundation::{
        http::{HttpMethod, HttpResponse, TransportError},
        webvpn,
    },
    test_support::MockTransport,
    ErrorCode,
};

const CONTEXT: &str = "https://sso.buaa.edu.cn/login?service=https%3A%2F%2Fd.buaa.edu.cn%2Fcb%3Fx%3Da%252Bb&dup=1&dup=2";

fn form(action: &str) -> String {
    format!(
        r#"<form action="{action}"><input type="hidden" name="execution" value="initial" /></form>"#
    )
}
fn expiry(action: Option<&str>) -> String {
    let action = action
        .map(|value| format!(r#" action="{value}""#))
        .unwrap_or_default();
    format!(
        r#"<form id="continueForm"{action}><input type="hidden" name="execution" value="renewed+execution/value" /><button name="_eventId" value="ignoreAndContinue">继续使用</button></form>"#
    )
}
fn credentials() -> Credentials {
    Credentials {
        username: "sy2501001".into(),
        password: "synthetic-password".into(),
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
fn routed(url: &str, route: RouteMode) -> String {
    if route == RouteMode::WebVpn {
        webvpn::wrap(url).unwrap()
    } else {
        url.to_owned()
    }
}

#[tokio::test]
async fn expiry_acknowledges_the_form_action_including_service_and_duplicate_query() {
    for route in [RouteMode::Direct, RouteMode::WebVpn] {
        let action = CONTEXT
            .replacen("https://sso.buaa.edu.cn", "", 1)
            .replace('&', "&amp;");
        let transport = MockTransport::with_responses(vec![
            HttpResponse::new(200, LOGIN_URL, form("/login")),
            HttpResponse::new(200, LOGIN_URL, expiry(Some(&action))),
            HttpResponse::new(302, CONTEXT, "")
                .with_header("Location", "https://uc.buaa.edu.cn/cb?ticket=ST-synthetic"),
            HttpResponse::new(200, UC_ACTIVATION_URL, ""),
            uc_ok(),
        ]);
        let session = Session::new(transport.clone());
        session.set_route(route);
        assert!(matches!(
            super::login(&session, &credentials()).await.unwrap(),
            LoginResult::SignedIn(_)
        ));
        let requests = transport.requests();
        assert_eq!(requests[2].url, routed(CONTEXT, route));
        assert_eq!(
            requests[2].body.as_deref(),
            Some("execution=renewed%2Bexecution%2Fvalue&_eventId=ignoreAndContinue")
        );
        assert_eq!(
            requests
                .iter()
                .filter(|r| r
                    .body
                    .as_deref()
                    .is_some_and(|body| body.contains("password=")))
                .count(),
            1
        );
    }
}

#[tokio::test]
async fn expiry_without_action_keeps_the_current_login_context() {
    for route in [RouteMode::Direct, RouteMode::WebVpn] {
        for action in [None, Some(""), Some("   ")] {
            let transport = MockTransport::with_responses(vec![
                HttpResponse::new(200, LOGIN_URL, form(CONTEXT)),
                HttpResponse::new(200, CONTEXT, expiry(action)),
                HttpResponse::new(302, CONTEXT, "")
                    .with_header("Location", "https://uc.buaa.edu.cn/cb?ticket=ST-synthetic"),
                HttpResponse::new(200, UC_ACTIVATION_URL, ""),
                uc_ok(),
            ]);
            let session = Session::new(transport.clone());
            session.set_route(route);
            assert!(matches!(
                super::login(&session, &credentials()).await.unwrap(),
                LoginResult::SignedIn(_)
            ));
            assert_eq!(transport.requests()[2].url, routed(CONTEXT, route));
        }
    }
}

#[tokio::test]
async fn expiry_action_outside_the_validated_cas_origin_never_receives_execution() {
    for action in [
        "http://sso.buaa.edu.cn/login",
        "https://evil.example/login",
        "https://d.buaa.edu.cn/login",
        "https://sso.buaa.edu.cn:8443/login",
        "https://user:secret@sso.buaa.edu.cn/login",
        "javascript:alert(1)",
    ] {
        let transport = MockTransport::with_responses(vec![
            HttpResponse::new(200, LOGIN_URL, form("/login")),
            HttpResponse::new(200, LOGIN_URL, expiry(Some(action))),
        ]);
        let error = super::login(&Session::new(transport.clone()), &credentials())
            .await
            .unwrap_err();
        assert_eq!(error.code, ErrorCode::ChangedResponse, "{action}");
        assert_eq!(transport.request_count(), 2, "no expiry POST to {action}");
    }
}

#[tokio::test]
async fn a_second_expiry_page_does_not_repeat_the_acknowledgement() {
    let transport = MockTransport::with_responses(vec![
        HttpResponse::new(200, LOGIN_URL, form("/login")),
        HttpResponse::new(200, LOGIN_URL, expiry(Some(CONTEXT))),
        HttpResponse::new(200, CONTEXT, expiry(Some(CONTEXT))),
    ]);
    let error = super::login(&Session::new(transport.clone()), &credentials())
        .await
        .unwrap_err();
    assert_eq!(error.code, ErrorCode::SessionExpired);
    assert_eq!(transport.request_count(), 3);
    assert_eq!(
        transport
            .requests()
            .iter()
            .filter(|r| r.method == HttpMethod::Post)
            .count(),
        2
    );
}

#[tokio::test]
async fn expiry_acknowledgement_transport_failure_is_not_replayed() {
    for route in [RouteMode::Automatic, RouteMode::WebVpn] {
        let transport = MockTransport::with_results(vec![
            Ok(HttpResponse::new(200, LOGIN_URL, form("/login"))),
            Ok(HttpResponse::new(200, LOGIN_URL, expiry(Some(CONTEXT)))),
            Err(TransportError::Unreachable),
        ]);
        let session = Session::new(transport.clone());
        session.set_route(route);
        let error = super::login(&session, &credentials()).await.unwrap_err();
        assert_eq!(error.code, ErrorCode::NetworkUnreachable);
        assert_eq!(transport.request_count(), 3);
    }
}

#[tokio::test]
async fn captcha_after_expiry_keeps_its_new_form_and_does_not_resubmit_password() {
    for route in [RouteMode::Direct, RouteMode::WebVpn] {
        let captcha = format!(
            "{}<script>config.captcha = {{ type: 'char', id: 'new-challenge' }};</script>",
            form(CONTEXT).replace("value=\"initial\"", "value=\"captcha-execution\"")
        );
        let transport = MockTransport::with_responses(vec![
            HttpResponse::new(200, LOGIN_URL, form("/login")),
            HttpResponse::new(200, LOGIN_URL, expiry(Some(CONTEXT))),
            HttpResponse::new(200, CONTEXT, captcha),
        ]);
        let session = Session::new(transport.clone());
        session.set_route(route);
        let result = super::login(&session, &credentials()).await.unwrap();
        let LoginResult::CaptchaRequired { challenge, page } = result else {
            panic!("expected a fresh challenge, not a published identity");
        };
        assert_eq!(challenge.id, "new-challenge");
        let super::LoginPage::Form {
            execution,
            action_url,
            ..
        } = page
        else {
            panic!("expected the challenge form");
        };
        assert_eq!(execution, "captcha-execution");
        assert_eq!(action_url, CONTEXT);
        let requests = transport.requests();
        assert_eq!(requests.len(), 3);
        assert_eq!(requests[2].url, routed(CONTEXT, route));
        assert_eq!(
            requests
                .iter()
                .filter(|r| r
                    .body
                    .as_deref()
                    .is_some_and(|body| body.contains("password=")))
                .count(),
            1
        );
    }
}
