use super::*;
use crate::foundation::http::HttpTransport;
use std::sync::Arc;

fn entry() -> HttpResponse {
    HttpResponse::new(
        302,
        "https://pass.cc-pay.cn/login?backUrl=https%3A%2F%2Fpass.cc-pay.cn%2Fdashboard%3Flinkfrom%3Dpass&channel=BUAASSO",
        "",
    )
    .with_header(
        "location",
        "https://sso.buaa.edu.cn/login?service=https%3A%2F%2Fpass.cc-pay.cn%2Flogin",
    )
}

fn callback() -> HttpResponse {
    HttpResponse::new(200, "https://pass.cc-pay.cn/login?ticket=ST-1", "")
}

fn user() -> HttpResponse {
    HttpResponse::new(
        200,
        "https://pass.cc-pay.cn/api/user",
        r#"{"success":true,"type":200,"data":{}}"#,
    )
}

fn cards() -> HttpResponse {
    HttpResponse::new(
        200,
        "https://pass.cc-pay.cn/api/campus_cards",
        r#"{"success":true,"type":200,"data":{"data":[{"stuNo":"sy2501001"}]}}"#,
    )
}

fn balance() -> HttpResponse {
    HttpResponse::new(
        200,
        "https://pass.cc-pay.cn/api/campus_card/balance?stuNo=sy2501001",
        r#"{"success":true,"type":200,"data":{"balance":"123.45","unclaimedAmount":"0.00","status":"0"}}"#,
    )
}

fn signed(
    responses: Vec<HttpResponse>,
) -> (SchoolClient<MockTransport, MemoryVault>, MockTransport) {
    let (service, transport) = build_service(responses, MemoryVault::default());
    service.set_authenticated(
        "sy2501001".into(),
        UserProfile {
            school_id: "sy2501001".into(),
            name: "李文".into(),
        },
    );
    service
        .session
        .set_route(crate::auth::session::RouteMode::Direct);
    (service, transport)
}

#[tokio::test]
async fn balance_uses_unified_auth_and_never_reads_bank_cards() {
    let (service, transport) = signed(vec![entry(), callback(), user(), cards(), balance()]);
    let result = service.campus_card_balance().await.expect("balance");
    assert_eq!(result.balance_minor, 12345);

    let requests = transport.requests();
    assert_eq!(requests.len(), 5);
    assert!(requests.iter().all(|request| {
        request.method == HttpMethod::Get
            && request.body.is_none()
            && !request.url.contains("bank_cards")
    }));
    assert!(requests[0].url.contains("channel=BUAASSO"));
    assert_eq!(requests[2].url, "https://pass.cc-pay.cn/api/user");
    assert_eq!(requests[3].url, "https://pass.cc-pay.cn/api/campus_cards");
    assert!(requests[4]
        .url
        .ends_with("campus_card/balance?stuNo=sy2501001"));
}

#[tokio::test]
async fn missing_identity_does_not_contact_campus_card_service() {
    let (service, transport) = build_service(vec![], MemoryVault::default());
    assert_eq!(
        service
            .campus_card_balance()
            .await
            .expect_err("missing identity")
            .code,
        ErrorCode::SessionExpired
    );
    assert!(transport.requests().is_empty());
}

struct PausingTransport {
    inner: MockTransport,
    entered: Arc<tokio::sync::Notify>,
    resume: Arc<tokio::sync::Notify>,
}
impl HttpTransport for PausingTransport {
    async fn send(&self, request: HttpRequest) -> Result<HttpResponse, TransportError> {
        if request.url.contains("/api/campus_card/balance") {
            self.entered.notify_one();
            self.resume.notified().await;
        }
        self.inner.send(request).await
    }
}

#[tokio::test]
async fn account_aba_during_balance_read_discards_private_response() {
    let entered = Arc::new(tokio::sync::Notify::new());
    let resume = Arc::new(tokio::sync::Notify::new());
    let service = SchoolClient::new(
        crate::auth::session::Session::new(PausingTransport {
            inner: MockTransport::with_responses(vec![
                entry(),
                callback(),
                user(),
                cards(),
                balance(),
            ]),
            entered: entered.clone(),
            resume: resume.clone(),
        }),
        MemoryVault::default(),
    );
    service
        .session
        .set_route(crate::auth::session::RouteMode::Direct);
    let profile = || UserProfile {
        school_id: "sy2501001".into(),
        name: "李文".into(),
    };
    service.set_authenticated("sy2501001".into(), profile());

    let (result, ()) = tokio::join!(service.campus_card_balance(), async {
        entered.notified().await;
        service.set_authenticated(
            "sy2501002".into(),
            UserProfile {
                school_id: "sy2501002".into(),
                name: "张三".into(),
            },
        );
        service.set_authenticated("sy2501001".into(), profile());
        resume.notify_one();
    });
    assert_eq!(
        result.expect_err("stale account").code,
        ErrorCode::SessionExpired
    );
}
