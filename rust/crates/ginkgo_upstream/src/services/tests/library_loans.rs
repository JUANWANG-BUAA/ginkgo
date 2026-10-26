//! Synthetic-only personal-loan transactions. No real reader data.
use crate::foundation::http::HttpTransport;
use std::sync::Arc;

struct PausingTransport {
    inner: MockTransport,
    entered: Arc<tokio::sync::Notify>,
    resume: Arc<tokio::sync::Notify>,
}
impl HttpTransport for PausingTransport {
    async fn send(&self, request: HttpRequest) -> Result<HttpResponse, TransportError> {
        if request.url.contains("/users/loans?") {
            self.entered.notify_one();
            self.resume.notified().await;
        }
        self.inner.send(request).await
    }
}
#[tokio::test]
async fn account_aba_during_read_discards_private_response() {
    let entered = Arc::new(tokio::sync::Notify::new());
    let resume = Arc::new(tokio::sync::Notify::new());
    let s = SchoolClient::new(
        crate::auth::session::Session::new(PausingTransport {
            inner: MockTransport::with_responses(vec![entry(), board(), loans(empty())]),
            entered: entered.clone(),
            resume: resume.clone(),
        }),
        MemoryVault::default(),
    );
    s.session.set_route(crate::auth::session::RouteMode::Direct);
    let profile = || UserProfile {
        school_id: "sy2501001".into(),
        name: "李文".into(),
    };
    s.set_authenticated("sy2501001".into(), profile());
    let (result, ()) = tokio::join!(s.library_loans(1), async {
        entered.notified().await;
        s.set_authenticated(
            "sy2501002".into(),
            UserProfile {
                school_id: "sy2501002".into(),
                name: "张三".into(),
            },
        );
        s.set_authenticated("sy2501001".into(), profile());
        resume.notify_one();
    });
    assert_eq!(result.err().unwrap().code, ErrorCode::SessionExpired);
}

use super::*;
#[test]
fn official_loan_portal_opens_the_mobile_current_loans_page() {
    assert_eq!(
        crate::adapters::library_loans_http::portal_url(),
        "https://space.lib.buaa.edu.cn/mspace/reader/lendList"
    );
}
fn entry() -> HttpResponse {
    HttpResponse::new(
        302,
        "https://space.lib.buaa.edu.cn/meta-local/opac/cas/rosetta",
        "",
    )
    .with_header("location", "/space/casBoard")
    .with_set_cookie("reader=synthetic; Path=/; Secure; HttpOnly")
}
fn board() -> HttpResponse {
    HttpResponse::new(
        200,
        "https://space.lib.buaa.edu.cn/space/casBoard",
        "<html></html>",
    )
}
fn loans(body: Value) -> HttpResponse {
    HttpResponse::new(
        200,
        "https://space.lib.buaa.edu.cn/meta-local/opac/users/loans",
        body.to_string(),
    )
}
fn empty() -> Value {
    serde_json::json!({"code":0,"data":{"currentPage":1,"pageSize":100,"total":0,"totalPage":0,"items":[]}})
}
fn signed(
    responses: Vec<HttpResponse>,
) -> (SchoolClient<MockTransport, MemoryVault>, MockTransport) {
    let (s, t) = build_service(responses, MemoryVault::default());
    s.set_authenticated(
        "sy2501001".into(),
        UserProfile {
            school_id: "sy2501001".into(),
            name: "李文".into(),
        },
    );
    s.session.set_route(crate::auth::session::RouteMode::Direct);
    (s, t)
}
#[tokio::test]
async fn private_read_establishes_cookie_and_never_posts_or_fetches_profile() {
    let (s, t) = signed(vec![entry(), board(), loans(empty())]);
    assert!(s.library_loans(1).await.unwrap().items.is_empty());
    let requests = t.requests();
    assert_eq!(requests.len(), 3);
    assert!(requests
        .iter()
        .all(|r| r.method == HttpMethod::Get && r.body.is_none()));
    assert_eq!(
        requests[2].url,
        "https://space.lib.buaa.edu.cn/meta-local/opac/users/loans?page=1&pageSize=100"
    );
    assert_eq!(requests[2].header_value("cookie"), Some("reader=synthetic"));
}
#[tokio::test]
async fn missing_identity_and_invalid_pages_do_not_contact_school() {
    let (s, t) = build_service(vec![], MemoryVault::default());
    assert_eq!(
        s.library_loans(1).await.err().unwrap().code,
        ErrorCode::SessionExpired
    );
    assert_eq!(
        s.library_loans(0).await.err().unwrap().code,
        ErrorCode::InvalidRequest
    );
    assert!(s.library_loans(101).await.is_err());
    assert_eq!(t.request_count(), 0);
}
#[tokio::test]
async fn foreign_redirect_is_blocked_before_request_and_login_form_is_not_empty() {
    for location in [
        "https://example.invalid/collect",
        "http://space.lib.buaa.edu.cn/space/casBoard",
    ] {
        let (s, t) = signed(vec![entry().with_header("location", location)]);
        assert!(s.library_loans(1).await.is_err());
        assert_eq!(t.request_count(), 1);
    }
    let (s, t) = signed(vec![
        entry().with_header("location", "https://sso.buaa.edu.cn/login"),
        HttpResponse::new(200, "https://sso.buaa.edu.cn/login", FORM_PAGE),
    ]);
    assert_eq!(
        s.library_loans(1).await.err().unwrap().code,
        ErrorCode::SessionExpired
    );
    assert_eq!(t.request_count(), 2);
}
#[tokio::test]
async fn endpoint_and_business_failures_are_not_successful_empty_or_cached() {
    for response in [
        HttpResponse::new(
            401,
            "https://space.lib.buaa.edu.cn/meta-local/opac/users/loans",
            "",
        ),
        HttpResponse::new(
            404,
            "https://space.lib.buaa.edu.cn/meta-local/opac/users/loans",
            "",
        ),
        HttpResponse::new(
            503,
            "https://space.lib.buaa.edu.cn/meta-local/opac/users/loans",
            "",
        ),
        loans(serde_json::json!({"code":7})),
        loans(serde_json::json!({"code":0,"data":{}})),
    ] {
        let (s, t) = signed(vec![
            entry(),
            board(),
            loans(empty()),
            entry(),
            board(),
            response,
        ]);
        assert!(s.library_loans(1).await.is_ok());
        assert!(s.library_loans(1).await.is_err());
        assert_eq!(t.request_count(), 6);
    }
}
