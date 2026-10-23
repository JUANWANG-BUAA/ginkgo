use super::{
    ClassroomQueryInput, RoutePreference, ScheduleQueryInput, SchoolClient, SessionOutcome,
    SessionStatus,
};
use crate::{
    auth::{
        vault::MemoryVault, CredentialSource, Credentials, LoginResult, UserProfile, LOGIN_URL,
        UC_ACTIVATION_URL, UC_STATUS_URL,
    },
    features::checkin::CheckInStatus,
    features::classroom::Sort,
    foundation::http::{HttpMethod, HttpRequest, HttpResponse, TransportError},
    test_support::MockTransport,
    ErrorCode,
};
use ginkgo_domain::ports::*;
use serde_json::Value;
use std::{fs, path::Path};

const FORM_PAGE: &str = r#"<html><body>
  <form action="/login" method="post">
    <input type="hidden" name="execution" value="abc+def/ghi=" />
    <input type="text" name="username" />
    <input type="password" name="password" />
  </form>
</body></html>"#;

fn login_chain(account: &str, name: &str) -> Vec<HttpResponse> {
    vec![
        HttpResponse::new(200, LOGIN_URL, FORM_PAGE),
        HttpResponse::new(302, LOGIN_URL, "")
            .with_header("Location", "https://sso.buaa.edu.cn/login?ticket=ST-1")
            .with_set_cookie("CASTGC=TGT-fixture; Path=/; Secure; HttpOnly"),
        HttpResponse::new(
            200,
            "https://sso.buaa.edu.cn/login?ticket=ST-1",
            "<html>ok</html>",
        ),
        HttpResponse::new(200, UC_ACTIVATION_URL, ""),
        uc_ok(account, name),
    ]
}

fn uc_ok(account: &str, name: &str) -> HttpResponse {
    HttpResponse::new(
        200,
        UC_STATUS_URL,
        serde_json::json!({
            "code": 0,
            "data": {"schoolid": account, "name": name}
        })
        .to_string(),
    )
}

fn credentials(account: &str) -> Credentials {
    Credentials {
        username: account.into(),
        password: "pa+ss/word".into(),
        captcha_text: None,
    }
}

fn build_service(
    responses: Vec<HttpResponse>,
    vault: MemoryVault,
) -> (SchoolClient<MockTransport, MemoryVault>, MockTransport) {
    let transport = MockTransport::with_responses(responses);
    (
        SchoolClient::new(crate::auth::session::Session::new(transport.clone()), vault),
        transport,
    )
}

fn seeded(account: &str) -> MemoryVault {
    MemoryVault::with(account, credentials(account))
}

fn fixture(dir: &str, name: &str) -> Value {
    let path = Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../../../fixtures")
        .join(dir)
        .join(name);
    serde_json::from_str(&fs::read_to_string(path).expect("fixture")).expect("json")
}

fn classroom_body() -> String {
    fixture("classroom", "upstream-normal-v1.json")["input"].to_string()
}

fn input() -> ClassroomQueryInput {
    ClassroomQueryInput {
        campus: 2,
        date: "2026-10-20".into(),
        force_refresh: false,
        search: String::new(),
        section: 1,
        minimum_free_sections: 0,
        minimum_consecutive_sections: 0,
        building: Some("主楼".into()),
        sort: Sort::Name,
    }
}

fn schedule_body(name: &str) -> String {
    fixture("schedule", name)["input"]["body"].to_string()
}

fn checkin_entry_response(login_name: &str) -> HttpResponse {
    HttpResponse::new(
        302,
        "https://iclass.buaa.edu.cn:8346/?type=jumpMyCenter",
        "",
    )
    .with_header(
        "Location",
        &format!("https://iclass.buaa.edu.cn:8346/?loginName={login_name}"),
    )
}

fn checkin_app_login_response() -> HttpResponse {
    HttpResponse::new(
        200,
        "https://iclass.buaa.edu.cn:8347/app/user/login.action",
        r#"{"STATUS":0,"result":{"id":"1001","sessionId":"fixture-session"}}"#,
    )
}

fn checkin_schedule_response(body: impl Into<String>) -> HttpResponse {
    HttpResponse::new(
        200,
        "https://iclass.buaa.edu.cn:8347/app/course/get_stu_course_sched.action",
        body,
    )
}

fn checkin_day_body() -> String {
    fixture("checkin", "course-schedule-normal-v1.json")["input"]["body"].to_string()
}

/// Suspend each request once so concurrent callers reach the same cold read
/// before the first caller can populate the session or snapshot.
struct YieldingTransport(MockTransport);

impl crate::foundation::http::HttpTransport for YieldingTransport {
    async fn send(&self, request: HttpRequest) -> Result<HttpResponse, TransportError> {
        let mut yielded = false;
        std::future::poll_fn(|cx| {
            if yielded {
                std::task::Poll::Ready(())
            } else {
                yielded = true;
                cx.waker().wake_by_ref();
                std::task::Poll::Pending
            }
        })
        .await;
        self.0.send(request).await
    }
}

fn library_login_redirect() -> HttpResponse {
    HttpResponse::new(302, crate::adapters::library_http::LOGIN_START, "").with_header(
        "Location",
        "https://booking.lib.buaa.edu.cn/v4/login/cas?cas=fixture-cas",
    )
}

fn library_token_response() -> HttpResponse {
    HttpResponse::new(
        200,
        crate::adapters::library_http::LOGIN_USER,
        r#"{"code":0,"data":{"member":{"token":"fixture-library-token"}}}"#,
    )
}

fn library_body(path: &str) -> HttpResponse {
    HttpResponse::new(
        200,
        format!("https://booking.lib.buaa.edu.cn/v4/{path}"),
        serde_json::json!({
            "code": 0,
            "data": fixture("library", "venues-normal-v1.json")["input"]["data"].clone(),
        })
        .to_string(),
    )
}

/// Offline auth service: expired business reads, then a configurable CAS 500.
/// Yield before every response so both business readers can enter recovery.
#[derive(Clone, Default)]
struct RecoveryFailureTransport {
    requests: std::sync::Arc<std::sync::Mutex<Vec<HttpRequest>>>,
    password_posts: std::sync::Arc<std::sync::atomic::AtomicUsize>,
    allow_login: std::sync::Arc<std::sync::atomic::AtomicBool>,
}

impl crate::foundation::http::HttpTransport for RecoveryFailureTransport {
    async fn send(&self, request: HttpRequest) -> Result<HttpResponse, TransportError> {
        use std::sync::atomic::Ordering;
        tokio::task::yield_now().await;
        let upstream = crate::foundation::webvpn::unwrap(&request.url);
        self.requests
            .lock()
            .expect("requests")
            .push(request.clone());
        if upstream == LOGIN_URL {
            if request.method == HttpMethod::Post {
                let fields: std::collections::BTreeMap<_, _> = url::form_urlencoded::parse(
                    request.body.as_deref().unwrap_or_default().as_bytes(),
                )
                .into_owned()
                .collect();
                assert_eq!(
                    fields.get("username").map(String::as_str),
                    Some("sy2501001")
                );
                assert_eq!(
                    fields.get("password").map(String::as_str),
                    Some("pa+ss/word")
                );
                self.password_posts.fetch_add(1, Ordering::Relaxed);
                return Ok(if self.allow_login.load(Ordering::Relaxed) {
                    HttpResponse::new(302, &request.url, "")
                        .with_header(
                            "Location",
                            "https://sso.buaa.edu.cn/login?ticket=ST-synthetic",
                        )
                        .with_set_cookie("CASTGC=TGT-synthetic; Path=/; Secure; HttpOnly")
                } else {
                    HttpResponse::new(500, &request.url, "synthetic authentication failure")
                });
            }
            return Ok(HttpResponse::new(200, &request.url, FORM_PAGE));
        }
        if upstream == UC_STATUS_URL {
            return Ok(HttpResponse::new(
                200,
                &request.url,
                uc_ok("sy2501001", "synthetic").body,
            ));
        }
        if upstream.contains("/buaafreeclass/") {
            return Ok(HttpResponse::new(401, &request.url, ""));
        }
        Ok(HttpResponse::new(
            200,
            &request.url,
            "<html>synthetic</html>",
        ))
    }
}

fn recovery_failure_service() -> (
    SchoolClient<RecoveryFailureTransport, MemoryVault>,
    RecoveryFailureTransport,
) {
    let transport = RecoveryFailureTransport::default();
    let service = SchoolClient::new(
        crate::auth::session::Session::new(transport.clone()),
        seeded("sy2501001"),
    );
    service.set_authenticated(
        "sy2501001".into(),
        UserProfile {
            school_id: "sy2501001".into(),
            name: "synthetic".into(),
        },
    );
    (service, transport)
}

mod academic;
mod campus;
mod cgyy_booking;
mod checkin;
mod classroom;
mod homework;
mod library;
mod library_books;
mod session;
