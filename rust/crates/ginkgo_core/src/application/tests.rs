use super::{
    ClassroomQueryInput, RoutePreference, ScheduleQueryInput, SessionOutcome, SessionService,
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
) -> (SessionService<MockTransport, MemoryVault>, MockTransport) {
    let transport = MockTransport::with_responses(responses);
    (
        SessionService::new(crate::auth::session::Session::new(transport.clone()), vault),
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

#[tokio::test]
async fn sign_in_returns_profile_and_stores_sanitized_credentials() {
    let (service, transport) =
        build_service(login_chain("sy2501001", "fixture"), MemoryVault::default());
    let outcome = service
        .sign_in("sy2501001", "pa+ss/word", Some("1234"), true)
        .await
        .expect("signed in");
    match outcome {
        SessionOutcome::SignedIn {
            profile,
            remembered,
        } => {
            assert_eq!(profile.school_id, "sy2501001");
            assert_eq!(profile.name, "fixture");
            assert!(remembered);
        }
        _ => panic!("expected signed in"),
    }
    let saved = service
        .vault
        .load("sy2501001")
        .expect("vault")
        .expect("saved");
    assert_eq!(saved.password, "pa+ss/word");
    assert_eq!(saved.captcha_text, None);
    assert_eq!(transport.request_count(), 5);
    assert_eq!(service.status().route, RoutePreference::Automatic);
}

#[tokio::test]
async fn sign_in_without_remember_removes_an_old_entry() {
    let (service, _) = build_service(login_chain("sy2501001", "fixture"), seeded("sy2501001"));
    service
        .sign_in("sy2501001", "pa+ss/word", None, false)
        .await
        .expect("signed in");
    assert!(service.vault.names().is_empty());
}

#[tokio::test]
async fn wrong_password_is_typed_and_not_persisted() {
    let transport = MockTransport::with_responses(vec![
        HttpResponse::new(200, LOGIN_URL, FORM_PAGE),
        HttpResponse::new(200, LOGIN_URL, FORM_PAGE),
    ]);
    let service = SessionService::new(
        crate::auth::session::Session::new(transport),
        MemoryVault::default(),
    );
    assert_eq!(
        service
            .sign_in("sy2501001", "wrong", None, true)
            .await
            .expect_err("wrong")
            .code,
        ErrorCode::InvalidCredentials
    );
    assert!(service.vault.names().is_empty());
}

#[tokio::test]
async fn restore_reuses_a_saved_account_or_reports_a_captcha() {
    let (service, transport) =
        build_service(login_chain("sy2501001", "fixture"), seeded("sy2501001"));
    match service.restore().await.expect("restore") {
        SessionOutcome::SignedIn { profile, .. } => assert_eq!(profile.school_id, "sy2501001"),
        _ => panic!("expected signed in"),
    }
    assert_eq!(transport.request_count(), 5);

    let captcha_page = FORM_PAGE.replace(
        "</form>",
        "<script>config.captcha = { type: 'slider', id: 'cap-1' };</script></form>",
    );
    let (service, _) = build_service(
        vec![HttpResponse::new(200, LOGIN_URL, captcha_page)],
        seeded("sy2501001"),
    );
    match service.restore().await.expect("captcha") {
        SessionOutcome::CaptchaRequired(challenge) => assert_eq!(challenge.id, "cap-1"),
        _ => panic!("expected captcha"),
    }
}

#[tokio::test]
async fn restore_without_a_saved_account_is_a_clean_signed_out_state() {
    let transport = MockTransport::default();
    let service = SessionService::new(
        crate::auth::session::Session::new(transport.clone()),
        MemoryVault::default(),
    );
    assert!(matches!(
        service.restore().await.expect("restore"),
        SessionOutcome::SignedOut
    ));
    assert_eq!(transport.request_count(), 0);
}

#[tokio::test]
async fn restore_deletes_an_entry_that_no_longer_authenticates() {
    let (service, _) = build_service(
        vec![
            HttpResponse::new(200, LOGIN_URL, FORM_PAGE),
            HttpResponse::new(200, LOGIN_URL, FORM_PAGE),
        ],
        seeded("sy2501001"),
    );
    assert!(matches!(
        service.restore().await.expect("restore"),
        SessionOutcome::SignedOut
    ));
    assert!(service.vault.names().is_empty());
}

#[tokio::test]
async fn classroom_reads_cache_for_five_minutes_and_keeps_a_stale_snapshot() {
    let mut responses = login_chain("sy2501001", "fixture");
    responses.push(HttpResponse::new(200, "activation", ""));
    responses.push(HttpResponse::new(
        200,
        "https://app.buaa.edu.cn/buaafreeclass/wap/default/search1?xqid=2&floorid=&date=2026-10-20",
        classroom_body(),
    ));
    responses.push(HttpResponse::new(200, "activation", ""));
    responses.push(HttpResponse::new(500, "search", "temporary"));
    let (service, transport) = build_service(responses, MemoryVault::default());
    service
        .sign_in("sy2501001", "pa+ss/word", None, true)
        .await
        .expect("signed in");

    let first = service.load_classrooms(&input()).await.expect("first");
    assert_eq!(first.result.summary.room_count, 2);
    assert!(!first.from_cache);
    assert!(first.failure.is_none());

    let second = service.load_classrooms(&input()).await.expect("cached");
    assert_eq!(second.result.summary.room_count, 2);
    assert!(second.from_cache);
    assert!(!second.stale);

    let mut forced = input();
    forced.force_refresh = true;
    let third = service.load_classrooms(&forced).await.expect("stale");
    assert_eq!(third.result.summary.room_count, 2);
    assert!(third.from_cache && third.stale);
    assert_eq!(
        third.failure.expect("failure").code,
        ErrorCode::ServiceUnavailable
    );
    assert_eq!(transport.request_count(), 9);
}

#[tokio::test]
async fn classroom_failure_without_a_snapshot_is_an_error() {
    let mut responses = login_chain("sy2501001", "fixture");
    responses.push(HttpResponse::new(200, "activation", ""));
    responses.push(HttpResponse::new(500, "search", "temporary"));
    let (service, _) = build_service(responses, MemoryVault::default());
    service
        .sign_in("sy2501001", "pa+ss/word", None, true)
        .await
        .expect("signed in");
    assert_eq!(
        service
            .load_classrooms(&input())
            .await
            .expect_err("failure")
            .code,
        ErrorCode::ServiceUnavailable
    );
}

#[tokio::test]
async fn classroom_session_expiry_recovers_once_with_the_saved_password() {
    let mut responses = login_chain("sy2501001", "fixture");
    responses.push(HttpResponse::new(200, "activation", ""));
    responses.push(HttpResponse::new(
        200,
        "search",
        r#"<html><input name="execution" value="expired" /></html>"#,
    ));
    responses.extend(login_chain("sy2501001", "fixture"));
    responses.push(HttpResponse::new(200, "activation", ""));
    responses.push(HttpResponse::new(200, "search", classroom_body()));
    let (service, transport) = build_service(responses, seeded("sy2501001"));
    service
        .sign_in("sy2501001", "pa+ss/word", None, true)
        .await
        .expect("signed in");

    let result = service.load_classrooms(&input()).await.expect("recovered");
    assert_eq!(result.result.summary.room_count, 2);
    assert_eq!(
        transport
            .requests()
            .iter()
            .filter(|request| request.method == HttpMethod::Post)
            .count(),
        2
    );
}

#[tokio::test]
async fn schedule_fetches_terms_weeks_courses_and_exams_then_reuses_the_snapshot() {
    let mut responses = login_chain("sy2501001", "fixture");
    responses.push(HttpResponse::new(
        200,
        "https://byxt.buaa.edu.cn/portal",
        r#"{"code":"0"}"#,
    ));
    responses.push(HttpResponse::new(
        200,
        "terms",
        schedule_body("terms-normal-v1.json"),
    ));
    responses.push(HttpResponse::new(
        200,
        "weeks",
        schedule_body("weeks-normal-v1.json"),
    ));
    responses.push(HttpResponse::new(
        200,
        "courses",
        schedule_body("courses-normal-v1.json"),
    ));
    responses.push(HttpResponse::new(
        200,
        "exams",
        schedule_body("exams-normal-v1.json"),
    ));
    let (service, transport) = build_service(responses, MemoryVault::default());
    service
        .sign_in("sy2501001", "pa+ss/word", None, true)
        .await
        .expect("signed in");

    let first = service
        .load_schedule(&ScheduleQueryInput {
            term_id: None,
            week: None,
            force_refresh: false,
        })
        .await
        .expect("schedule");
    assert_eq!(first.data.term_id, "2026-2027-1");
    assert_eq!(first.data.week_number, 2);
    assert_eq!(first.data.courses.len(), 2);
    assert_eq!(first.data.exams.len(), 2);
    assert!(!first.from_cache);

    let second = service
        .load_schedule(&ScheduleQueryInput {
            term_id: None,
            week: None,
            force_refresh: false,
        })
        .await
        .expect("cached schedule");
    assert!(second.from_cache);
    assert_eq!(transport.request_count(), 10);
}

#[tokio::test]
async fn schedule_requested_term_controls_courses_and_cache_key() {
    let mut responses = login_chain("sy2501001", "fixture");
    for name in ["selected term", "requested term"] {
        let mut courses: serde_json::Value =
            serde_json::from_str(&schedule_body("courses-normal-v1.json")).expect("fixture");
        // Use distinct valid course payloads to catch reuse across terms.
        if name == "requested term" {
            courses["datas"]["arrangedList"] = serde_json::json!([]);
        }
        responses.extend([
            HttpResponse::new(200, "portal", r#"{"code":"0"}"#),
            HttpResponse::new(200, "terms", schedule_body("terms-normal-v1.json")),
            HttpResponse::new(200, "weeks", schedule_body("weeks-normal-v1.json")),
            HttpResponse::new(200, "courses", courses.to_string()),
            HttpResponse::new(200, "exams", schedule_body("exams-normal-v1.json")),
        ]);
    }
    let (service, transport) = build_service(responses, MemoryVault::default());
    service
        .sign_in("sy2501001", "pa+ss/word", None, true)
        .await
        .expect("login");
    let current = ScheduleQueryInput {
        term_id: None,
        week: None,
        force_refresh: false,
    };
    let initial = service.load_schedule(&current).await.expect("current");
    assert_eq!(initial.data.courses.len(), 2);
    let requested = ScheduleQueryInput {
        term_id: Some("2025-2026-2".into()),
        week: None,
        force_refresh: false,
    };
    let result = service.load_schedule(&requested).await.expect("requested");
    assert_eq!(result.data.term_id, "2025-2026-2");
    assert!(result.data.courses.is_empty());
    let requests = transport.requests();
    let course_request = requests
        .iter()
        .rev()
        .find(|request| request.url.contains("getMyScheduleDetail"))
        .expect("course request");
    assert_eq!(
        course_request.body.as_deref(),
        Some("termCode=2025-2026-2&type=week&week=2")
    );
    assert_eq!(
        service
            .load_schedule(&current)
            .await
            .expect("cached current")
            .data
            .courses
            .len(),
        2
    );
    assert!(
        service
            .load_schedule(&requested)
            .await
            .expect("cached requested")
            .from_cache
    );
}

#[tokio::test]
async fn schedule_refresh_failure_keeps_the_previous_week() {
    let mut responses = login_chain("sy2501001", "fixture");
    responses.extend(vec![
        HttpResponse::new(200, "portal", r#"{"code":"0"}"#),
        HttpResponse::new(200, "terms", schedule_body("terms-normal-v1.json")),
        HttpResponse::new(200, "weeks", schedule_body("weeks-normal-v1.json")),
        HttpResponse::new(200, "courses", schedule_body("courses-normal-v1.json")),
        HttpResponse::new(200, "exams", schedule_body("exams-normal-v1.json")),
        HttpResponse::new(200, "portal", r#"{"code":"0"}"#),
        HttpResponse::new(200, "terms", "temporary"),
        HttpResponse::new(200, "weeks", ""),
        HttpResponse::new(200, "courses", ""),
        HttpResponse::new(200, "exams", ""),
    ]);
    let (service, _) = build_service(responses, MemoryVault::default());
    service
        .sign_in("sy2501001", "pa+ss/word", None, true)
        .await
        .expect("signed in");
    service
        .load_schedule(&ScheduleQueryInput {
            term_id: None,
            week: None,
            force_refresh: false,
        })
        .await
        .expect("first");
    let stale = service
        .load_schedule(&ScheduleQueryInput {
            term_id: None,
            week: None,
            force_refresh: true,
        })
        .await
        .expect("stale");
    assert!(stale.from_cache && stale.stale);
    assert_eq!(stale.data.courses.len(), 2);
}

#[tokio::test]
async fn sign_out_clears_identity_credentials_and_snapshots() {
    let mut responses = login_chain("sy2501001", "fixture");
    responses.push(HttpResponse::new(200, "activation", ""));
    responses.push(HttpResponse::new(200, "search", classroom_body()));
    responses.push(HttpResponse::new(200, "logout", "ok"));
    let (service, _) = build_service(responses, MemoryVault::default());
    service
        .sign_in("sy2501001", "pa+ss/word", None, true)
        .await
        .expect("signed in");
    service.load_classrooms(&input()).await.expect("classrooms");
    service.sign_out().await;
    assert_eq!(
        service.status(),
        SessionStatus {
            account: None,
            profile: None,
            route: RoutePreference::Automatic,
        }
    );
    assert!(service.vault.names().is_empty());
}

#[tokio::test]
async fn in_memory_session_is_revalidated_before_restore_succeeds() {
    let mut responses = login_chain("sy2501001", "fixture");
    responses.push(uc_ok("sy2501001", "fixture"));
    let (service, _) = build_service(responses, seeded("sy2501001"));
    service
        .sign_in("sy2501001", "pa+ss/word", None, true)
        .await
        .expect("signed in");
    match service.restore().await.expect("restore") {
        SessionOutcome::SignedIn { profile, .. } => assert_eq!(profile.name, "fixture"),
        _ => panic!("expected signed in"),
    }
}

#[test]
fn session_outcomes_are_constructible_for_the_bridge() {
    // Compile-time guard: the bridge maps this enum without exposing internals.
    let _ = LoginResult::SignedIn(UserProfile {
        school_id: "sy2501001".into(),
        name: "fixture".into(),
    });
    let _ = RoutePreference::WebVpn;
}

#[tokio::test]
async fn today_reads_caches_and_keeps_the_last_timeline() {
    let mut responses = login_chain("sy2501001", "fixture");
    responses.push(HttpResponse::new(200, "portal", r#"{"code":"0"}"#));
    responses.push(HttpResponse::new(
        200,
        "today",
        schedule_body("today-normal-v1.json"),
    ));
    responses.push(HttpResponse::new(200, "portal", r#"{"code":"0"}"#));
    responses.push(HttpResponse::new(500, "today", "temporary"));
    let (service, transport) = build_service(responses, MemoryVault::default());
    service
        .sign_in("sy2501001", "pa+ss/word", None, true)
        .await
        .expect("signed in");

    let first = service.load_today(false).await.expect("today");
    assert_eq!(first.courses.len(), 2);
    assert!(!first.from_cache);
    let second = service.load_today(false).await.expect("cached today");
    assert!(second.from_cache);
    assert_eq!(transport.request_count(), 7);

    let stale = service.load_today(true).await.expect("stale today");
    assert!(stale.stale && stale.from_cache);
    assert_eq!(stale.courses.len(), 2);
    assert_eq!(
        stale.failure.expect("failure").code,
        ErrorCode::ServiceUnavailable
    );
}

#[tokio::test]
async fn grades_discover_the_selected_term_and_summarize() {
    let mut responses = login_chain("sy2501001", "fixture");
    responses.push(HttpResponse::new(200, "portal", r#"{"code":"0"}"#));
    responses.push(HttpResponse::new(
        200,
        "terms",
        schedule_body("terms-normal-v1.json"),
    ));
    responses.push(HttpResponse::new(
        200,
        crate::adapters::grades_http::GRADE_URL,
        "<html>ok</html>",
    ));
    responses.push(HttpResponse::new(
        200,
        crate::adapters::grades_http::GRADE_URL,
        fixture("grades", "normal-v1.json")["input"]["body"].to_string(),
    ));
    let (service, transport) = build_service(responses, MemoryVault::default());
    service
        .sign_in("sy2501001", "pa+ss/word", None, true)
        .await
        .expect("signed in");

    let first = service.load_grades(None, false).await.expect("grades");
    assert_eq!(first.term_id, "2026-2027-1");
    assert_eq!(first.courses.len(), 2);
    assert!((first.summary.credit_total - 7.0).abs() < 0.001);
    assert!(first.summary.weighted_average.is_some());
    assert!(!first.from_cache);
    assert_eq!(transport.request_count(), 9);

    let cached = service
        .load_grades(None, false)
        .await
        .expect("cached grades");
    assert!(cached.from_cache);
    assert_eq!(transport.request_count(), 9);
}

#[tokio::test]
async fn explicit_grade_term_skips_schedule_discovery() {
    let mut responses = login_chain("sy2501001", "fixture");
    responses.push(HttpResponse::new(
        200,
        crate::adapters::grades_http::GRADE_URL,
        "<html>ok</html>",
    ));
    responses.push(HttpResponse::new(
        200,
        crate::adapters::grades_http::GRADE_URL,
        fixture("grades", "normal-v1.json")["input"]["body"].to_string(),
    ));
    let (service, transport) = build_service(responses, MemoryVault::default());
    service
        .sign_in("sy2501001", "pa+ss/word", None, true)
        .await
        .expect("signed in");
    let grades = service
        .load_grades(Some("2026-2027-1"), false)
        .await
        .expect("grades");
    assert_eq!(grades.term_id, "2026-2027-1");
    assert_eq!(transport.request_count(), 7);
}

#[tokio::test]
async fn captcha_answer_reuses_the_original_login_page() {
    let captcha_page = FORM_PAGE.replace(
        "</form>",
        "<script>config.captcha = { type: 'slider', id: 'cap-1' };</script></form>",
    );
    let transport = MockTransport::with_responses(vec![
        HttpResponse::new(200, LOGIN_URL, captcha_page),
        HttpResponse::new(302, LOGIN_URL, "")
            .with_header("Location", "https://sso.buaa.edu.cn/login?ticket=ST-1")
            .with_set_cookie("CASTGC=TGT-fixture; Path=/; Secure; HttpOnly"),
        HttpResponse::new(
            200,
            "https://sso.buaa.edu.cn/login?ticket=ST-1",
            "<html>ok</html>",
        ),
        HttpResponse::new(200, UC_ACTIVATION_URL, ""),
        uc_ok("sy2501001", "fixture"),
    ]);
    let service = SessionService::new(
        crate::auth::session::Session::new(transport.clone()),
        MemoryVault::default(),
    );
    match service
        .sign_in("sy2501001", "pa+ss/word", None, true)
        .await
        .expect("challenge")
    {
        SessionOutcome::CaptchaRequired(challenge) => assert_eq!(challenge.id, "cap-1"),
        _ => panic!("expected captcha"),
    }
    assert_eq!(transport.request_count(), 1);

    match service
        .sign_in("sy2501001", "pa+ss/word", Some("1234"), true)
        .await
        .expect("signed in")
    {
        SessionOutcome::SignedIn { profile, .. } => {
            assert_eq!(profile.school_id, "sy2501001")
        }
        _ => panic!("expected signed in"),
    }
    let requests = transport.requests();
    assert_eq!(requests[0].method, HttpMethod::Get);
    assert_eq!(requests[1].method, HttpMethod::Post);
    let body = requests[1].body.as_deref().expect("login body");
    assert!(body.contains("captcha=1234"));
    assert!(body.contains("execution=abc%2Bdef%2Fghi%3D"));
    let saved = service
        .vault
        .load("sy2501001")
        .expect("vault")
        .expect("saved");
    assert_eq!(saved.captcha_text, None);
}

#[tokio::test]
async fn graduate_schedule_uses_gsmis_and_today_is_derived_from_the_snapshot() {
    let mut responses = login_chain("grad2501001", "fixture");
    // BYXT current-user: SSO, back to the graduate portal marker.
    responses.push(
        HttpResponse::new(302, "https://byxt.buaa.edu.cn/currentUser.do", "").with_header(
            "Location",
            "https://sso.buaa.edu.cn/login?service=https%3A%2F%2Fbyxt.buaa.edu.cn",
        ),
    );
    responses.push(
        HttpResponse::new(302, "https://sso.buaa.edu.cn/login?service=x", "").with_header(
            "Location",
            "https://byxt.buaa.edu.cn/jwapp/sys/byrhmhsy/index.html",
        ),
    );
    responses.push(HttpResponse::new(
        200,
        "https://byxt.buaa.edu.cn/jwapp/sys/byrhmhsy/index.html",
        "<html>graduate</html>",
    ));
    // GSMIS activation, terms and full-term schedule.
    responses.push(HttpResponse::new(
        200,
        crate::adapters::graduate_schedule_http::ENTRY_URL,
        "<html>app</html>",
    ));
    responses.push(HttpResponse::new(
        200,
        crate::adapters::graduate_schedule_http::TERMS_URL,
        fixture("schedule", "graduate-terms-v1.json")["input"]["body"].to_string(),
    ));
    responses.push(HttpResponse::new(
        200,
        crate::adapters::graduate_schedule_http::SCHEDULE_URL,
        fixture("schedule", "graduate-schedule-v1.json")["input"]["body"].to_string(),
    ));
    let (service, transport) = build_service(responses, MemoryVault::default());
    service
        .sign_in("grad2501001", "pa+ss/word", None, true)
        .await
        .expect("signed in");

    let schedule = service
        .load_schedule(&ScheduleQueryInput {
            term_id: None,
            week: None,
            force_refresh: false,
        })
        .await
        .expect("graduate schedule");
    assert_eq!(schedule.data.term_id, "20261");
    assert_eq!(schedule.data.week_number, 7);
    assert_eq!(schedule.data.weeks.len(), 30);
    assert_eq!(schedule.data.courses.len(), 2);
    assert!(schedule.data.exams.is_empty());

    assert_eq!(transport.request_count(), 11);
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

#[tokio::test]
async fn checkin_concurrent_cold_reads_share_authentication_and_the_day_snapshot() {
    let mut responses = login_chain("sy2501001", "fixture");
    responses.push(checkin_entry_response("fixture-login"));
    responses.push(checkin_app_login_response());
    responses.push(checkin_schedule_response(checkin_day_body()));
    let transport = MockTransport::with_responses(responses);
    let service = SessionService::new(
        crate::auth::session::Session::new(YieldingTransport(transport.clone())),
        MemoryVault::default(),
    );
    service
        .sign_in("sy2501001", "pa+ss/word", None, true)
        .await
        .expect("signed in");

    let (first, page) = tokio::join!(service.load_checkin(false), service.load_checkin(false));
    let first = first.expect("first caller");
    let page = page.expect("check-in page");
    assert_eq!(first.courses.len(), 2);
    assert_eq!(page.courses.len(), 2);
    assert_ne!(first.from_cache, page.from_cache);
    assert_eq!(first.fetched_at, page.fetched_at);
    assert_eq!(transport.request_count(), 8);
}

#[tokio::test]
async fn checkin_concurrent_forced_reads_still_refresh_upstream() {
    let mut responses = login_chain("sy2501001", "fixture");
    responses.push(checkin_entry_response("fixture-login"));
    responses.push(checkin_app_login_response());
    responses.push(checkin_schedule_response(checkin_day_body()));
    responses.push(checkin_schedule_response(checkin_day_body()));
    let transport = MockTransport::with_responses(responses);
    let service = SessionService::new(
        crate::auth::session::Session::new(YieldingTransport(transport.clone())),
        MemoryVault::default(),
    );
    service
        .sign_in("sy2501001", "pa+ss/word", None, true)
        .await
        .expect("signed in");

    let (first, second) = tokio::join!(service.load_checkin(true), service.load_checkin(true));
    assert!(!first.expect("first refresh").from_cache);
    assert!(!second.expect("second refresh").from_cache);
    // One SSO entry, one app login, and two deliberately forced day queries.
    assert_eq!(transport.request_count(), 9);
}

#[tokio::test]
async fn checkin_retry_after_a_failed_day_read_keeps_the_successful_app_login() {
    for (status, body, expected) in [
        (503, "temporary", ErrorCode::ServiceUnavailable),
        (200, "{}", ErrorCode::ChangedResponse),
    ] {
        let mut responses = login_chain("sy2501001", "fixture");
        responses.push(checkin_entry_response("fixture-login"));
        responses.push(checkin_app_login_response());
        responses.push(HttpResponse::new(
            status,
            crate::adapters::checkin_http::COURSE_SCHEDULE_URL,
            body,
        ));
        responses.push(checkin_schedule_response(checkin_day_body()));
        let (service, transport) = build_service(responses, MemoryVault::default());
        service
            .sign_in("sy2501001", "pa+ss/word", None, true)
            .await
            .expect("signed in");

        assert_eq!(
            service
                .load_checkin(false)
                .await
                .expect_err("day failed")
                .code,
            expected
        );
        let retry = service.load_checkin(true).await.expect("retry day only");
        assert_eq!(retry.courses.len(), 2);
        assert!(!retry.from_cache);
        assert_eq!(transport.request_count(), 9);
        assert_eq!(
            transport
                .requests()
                .iter()
                .filter(|request| request
                    .url
                    .starts_with(crate::adapters::checkin_http::APP_LOGIN_URL))
                .count(),
            1
        );
    }
}

#[tokio::test]
async fn checkin_fresh_snapshot_does_not_wait_for_another_day_network_query() {
    use std::{future::Future, task::Poll};
    let transport = MockTransport::default();
    let service = SessionService::new(
        crate::auth::session::Session::new(transport.clone()),
        MemoryVault::default(),
    );
    *service.account.lock().expect("account") = Some("sy2501001".into());
    *service.profile.lock().expect("profile") = Some(UserProfile {
        school_id: "sy2501001".into(),
        name: "synthetic".into(),
    });
    let date = "2026-01-01".to_owned();
    let timestamp = service
        .checkin
        .lock()
        .expect("cache")
        .insert(date.clone(), vec![]);
    let gate = service.checkin_request_gate.lock().await;
    let mut cached = Box::pin(service.load_checkin_on_date(Some(date.clone()), false));
    match std::future::poll_fn(|cx| Poll::Ready(cached.as_mut().poll(cx))).await {
        Poll::Ready(Ok(outcome)) => {
            assert!(outcome.from_cache && !outcome.stale);
            assert_eq!(outcome.fetched_at, timestamp);
        }
        _ => panic!("a cached day must not wait for a different day's network query"),
    }
    let mut forced = Box::pin(service.load_checkin_on_date(Some(date), true));
    assert!(
        std::future::poll_fn(|cx| Poll::Ready(forced.as_mut().poll(cx)))
            .await
            .is_pending()
    );
    assert_eq!(transport.request_count(), 0);
    drop(forced);
    drop(gate);
}

#[tokio::test]
async fn checkin_reads_the_day_then_reuses_the_five_minute_snapshot() {
    let mut responses = login_chain("sy2501001", "fixture");
    responses.push(checkin_entry_response("fixture-login"));
    responses.push(checkin_app_login_response());
    responses.push(checkin_schedule_response(checkin_day_body()));
    let (service, transport) = build_service(responses, MemoryVault::default());
    service
        .sign_in("sy2501001", "pa+ss/word", None, true)
        .await
        .expect("signed in");

    let first = service.load_checkin(false).await.expect("checkin");
    assert_eq!(
        first.date,
        crate::foundation::school_time::beijing_day(&super::cache::now_shanghai())
            .expect("day")
            .local_date
    );
    assert_eq!(first.courses.len(), 2);
    assert_eq!(first.courses[0].status, CheckInStatus::NotSigned);
    assert_eq!(first.courses[0].merged_record_count, 2);
    assert_eq!(first.courses[1].status, CheckInStatus::Signed);
    assert!(!first.from_cache);

    let cached = service.load_checkin(false).await.expect("cached checkin");
    assert!(cached.from_cache && !cached.stale);
    assert_eq!(cached.courses.len(), 2);
    assert_eq!(transport.request_count(), 8);
}

#[tokio::test]
async fn checkin_status_two_is_an_empty_day_without_an_error() {
    let mut responses = login_chain("sy2501001", "fixture");
    responses.push(checkin_entry_response("fixture-login"));
    responses.push(checkin_app_login_response());
    responses.push(checkin_schedule_response(
        fixture("checkin", "course-schedule-empty-v1.json")["input"]["body"].to_string(),
    ));
    let (service, _) = build_service(responses, MemoryVault::default());
    service
        .sign_in("sy2501001", "pa+ss/word", None, true)
        .await
        .expect("signed in");
    let outcome = service.load_checkin(false).await.expect("empty day");
    assert!(outcome.courses.is_empty());
    assert!(outcome.failure.is_none());
}

#[tokio::test]
async fn checkin_business_rejection_rebuilds_the_app_session_once_then_keeps_the_snapshot() {
    let rejected = r#"{"STATUS":9,"ERRMSG":"fixture rejection"}"#;
    let mut responses = login_chain("sy2501001", "fixture");
    responses.push(checkin_entry_response("fixture-login"));
    responses.push(checkin_app_login_response());
    responses.push(checkin_schedule_response(checkin_day_body()));
    responses.push(checkin_schedule_response(rejected));
    responses.push(checkin_entry_response("fixture-login"));
    responses.push(checkin_app_login_response());
    responses.push(checkin_schedule_response(rejected));
    let (service, transport) = build_service(responses, MemoryVault::default());
    service
        .sign_in("sy2501001", "pa+ss/word", None, true)
        .await
        .expect("signed in");
    service.load_checkin(false).await.expect("first");

    let stale = service.load_checkin(true).await.expect("stale checkin");
    assert!(stale.from_cache && stale.stale);
    assert_eq!(stale.courses.len(), 2);
    assert_eq!(
        stale.failure.expect("failure").code,
        ErrorCode::BusinessRejected
    );
    // One rejected query, one rebuild (entry + app login), one rejected retry.
    assert_eq!(transport.request_count(), 12);
}

#[tokio::test]
async fn checkin_expired_school_session_recovers_once() {
    let mut responses = login_chain("sy2501001", "fixture");
    responses.push(checkin_entry_response("fixture-login"));
    responses.push(checkin_app_login_response());
    responses.push(checkin_schedule_response(checkin_day_body()));
    responses.push(HttpResponse::new(401, "iclass", ""));
    responses.extend(login_chain("sy2501001", "fixture"));
    responses.push(checkin_entry_response("fixture-login"));
    responses.push(checkin_app_login_response());
    responses.push(checkin_schedule_response(checkin_day_body()));
    let (service, transport) = build_service(responses, MemoryVault::default());
    service
        .sign_in("sy2501001", "pa+ss/word", None, true)
        .await
        .expect("signed in");
    service.load_checkin(false).await.expect("first");

    let recovered = service.load_checkin(true).await.expect("recovered");
    assert_eq!(recovered.courses.len(), 2);
    assert!(recovered.failure.is_none());
    assert_eq!(
        transport
            .requests()
            .iter()
            .filter(|request| request.method == HttpMethod::Post)
            .count(),
        2
    );
}

#[tokio::test]
async fn checkin_webvpn_fallback_establishes_the_gateway_session_once() {
    use crate::foundation::webvpn;
    let entry_wrapped = webvpn::wrap(crate::adapters::checkin_http::ENTRY_URL).expect("entry");
    let login_wrapped =
        webvpn::wrap(crate::adapters::checkin_http::APP_LOGIN_URL).expect("app login");
    let mut results: Vec<Result<HttpResponse, TransportError>> =
        login_chain("sy2501001", "fixture")
            .into_iter()
            .map(Ok)
            .collect();
    // Direct iclass is unreachable, then the gateway asks for its own login.
    results.push(Err(TransportError::Unavailable));
    results.push(Ok(HttpResponse::new(
        200,
        "https://d.buaa.edu.cn/login",
        "<html>gateway login</html>",
    )
    .with_set_cookie("gateway-preauth=fixture; Path=/; Secure")));
    // WebVPN CAS login chain (routed through the gateway).
    results.push(Ok(HttpResponse::new(
        200,
        crate::auth::LOGIN_URL,
        FORM_PAGE,
    )));
    results.push(Ok(HttpResponse::new(302, crate::auth::LOGIN_URL, "")
        .with_header("Location", "https://sso.buaa.edu.cn/login?ticket=ST-1")
        .with_set_cookie("CASTGC=TGT-fixture; Path=/; Secure; HttpOnly")));
    results.push(Ok(HttpResponse::new(
        200,
        "https://sso.buaa.edu.cn/login?ticket=ST-1",
        "<html>ok</html>",
    )));
    results.push(Ok(HttpResponse::new(
        200,
        crate::auth::UC_ACTIVATION_URL,
        "",
    )));
    results.push(Ok(uc_ok("sy2501001", "fixture")));
    results.push(Ok(HttpResponse::new(302, &entry_wrapped, "").with_header(
        "Location",
        "https://iclass.buaa.edu.cn:8346/?loginName=fixture-login",
    )));
    results.push(Ok(HttpResponse::new(
        200,
        &login_wrapped,
        r#"{"STATUS":0,"result":{"id":"1001","sessionId":"fixture-session"}}"#,
    )));
    results.push(Ok(HttpResponse::new(
        200,
        &login_wrapped,
        checkin_day_body(),
    )));

    let transport = MockTransport::with_results(results);
    let service = SessionService::new(
        crate::auth::session::Session::new(transport.clone()),
        MemoryVault::default(),
    );
    service
        .sign_in("sy2501001", "pa+ss/word", None, true)
        .await
        .expect("signed in");

    let outcome = service.load_checkin(false).await.expect("webvpn checkin");
    assert_eq!(outcome.courses.len(), 2);
    assert!(outcome.failure.is_none());
    assert_eq!(
        service.session.route(),
        crate::auth::session::RouteMode::WebVpn
    );
    // After the fallback, every iclass request goes through the gateway: the
    // failed attempt is retried once there, then the rebuilt session and the
    // app endpoints (port 8347) are all routed.
    let requests = transport.requests();
    let entry_routed = requests
        .iter()
        .filter(|request| request.url.starts_with("https://d.buaa.edu.cn/https-8346/"))
        .count();
    let app_routed = requests
        .iter()
        .filter(|request| request.url.starts_with("https://d.buaa.edu.cn/https-8347/"))
        .count();
    assert_eq!(entry_routed, 2);
    assert_eq!(app_routed, 2);
    // The gateway CAS session was established through the gateway itself.
    assert!(requests.iter().any(
        |request| request.url.starts_with("https://d.buaa.edu.cn/https/")
            && request.method == HttpMethod::Post
    ));
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

#[tokio::test]
async fn library_venues_and_bookings_use_the_five_minute_snapshot() {
    let mut responses = login_chain("sy2501001", "fixture");
    responses.push(library_login_redirect());
    responses.push(library_token_response());
    responses.push(library_body("space/pcTopFor"));
    responses.push(HttpResponse::new(
        200,
        "https://booking.lib.buaa.edu.cn/v4/index/subscribe",
        serde_json::json!({
            "code": 0,
            "data": fixture("library", "bookings-normal-v1.json")["input"]["data"].clone(),
        })
        .to_string(),
    ));
    responses.push(HttpResponse::new(500, "library", "temporary"));
    let (service, transport) = build_service(responses, MemoryVault::default());
    service
        .sign_in("sy2501001", "pa+ss/word", None, true)
        .await
        .expect("signed in");

    let venues = service.load_library_venues(false).await.expect("venues");
    assert_eq!(venues.venues.len(), 2);
    assert_eq!(venues.venues[0].name, "学院路馆");
    assert!(!venues.from_cache);
    assert_eq!(transport.request_count(), 8);

    let cached = service.load_library_venues(false).await.expect("cached");
    assert!(cached.from_cache);
    assert_eq!(transport.request_count(), 8);

    let bookings = service
        .load_library_bookings(false)
        .await
        .expect("bookings");
    assert_eq!(bookings.bookings.len(), 2);
    assert_eq!(bookings.bookings[0].title, "学院路馆 · A区 · 12号");

    let stale = service.load_library_venues(true).await.expect("stale");
    assert!(stale.from_cache && stale.stale);
    assert_eq!(stale.venues.len(), 2);
    assert_eq!(
        stale.failure.expect("failure").code,
        ErrorCode::ServiceUnavailable
    );
}

#[tokio::test]
async fn library_areas_slots_and_seats_follow_the_hierarchy() {
    let mut responses = login_chain("sy2501001", "fixture");
    responses.push(library_login_redirect());
    responses.push(library_token_response());
    responses.push(HttpResponse::new(
        200,
        "https://booking.lib.buaa.edu.cn/v4/space/pick",
        serde_json::json!({
            "code": 0,
            "data": fixture("library", "areas-normal-v1.json")["input"]["data"].clone(),
        })
        .to_string(),
    ));
    responses.push(HttpResponse::new(
        200,
        "https://booking.lib.buaa.edu.cn/v4/Space/map",
        serde_json::json!({
            "code": 0,
            "data": fixture("library", "slots-normal-v1.json")["input"]["data"].clone(),
        })
        .to_string(),
    ));
    responses.push(HttpResponse::new(
        200,
        "https://booking.lib.buaa.edu.cn/v4/Space/seat",
        serde_json::json!({
            "code": 0,
            "data": fixture("library", "seats-normal-v1.json")["input"]["data"].clone(),
        })
        .to_string(),
    ));
    let (service, transport) = build_service(responses, MemoryVault::default());
    service
        .sign_in("sy2501001", "pa+ss/word", None, true)
        .await
        .expect("signed in");

    let areas = service.load_library_areas("v1").await.expect("areas");
    assert_eq!(areas.len(), 2);
    let slots = service.load_library_slots("a1").await.expect("slots");
    assert_eq!(slots[0].id, "2026-10-20/t1");
    let seats = service
        .load_library_seats("a1", "2026-10-20/t1", "2026-10-20", "08:00", "10:00")
        .await
        .expect("seats");
    assert_eq!(seats.len(), 2);
    assert!(seats[0].available);
    assert!(!seats[1].available);
    assert_eq!(transport.request_count(), 10);
    assert_eq!(
        service
            .load_library_areas("")
            .await
            .expect_err("empty area")
            .code,
        ErrorCode::InvalidRequest
    );
}

#[tokio::test]
async fn library_token_expiry_relogs_exactly_once() {
    let mut responses = login_chain("sy2501001", "fixture");
    responses.push(library_login_redirect());
    responses.push(library_token_response());
    responses.push(HttpResponse::new(401, "library", ""));
    responses.push(library_login_redirect());
    responses.push(library_token_response());
    responses.push(library_body("space/pcTopFor"));
    let (service, transport) = build_service(responses, MemoryVault::default());
    service
        .sign_in("sy2501001", "pa+ss/word", None, true)
        .await
        .expect("signed in");

    let venues = service.load_library_venues(false).await.expect("relogin");
    assert_eq!(venues.venues.len(), 2);
    let exchanges = transport
        .requests()
        .iter()
        .filter(|request| request.url == crate::adapters::library_http::LOGIN_USER)
        .count();
    assert_eq!(exchanges, 2);
}

#[tokio::test]
async fn homework_full_read_chain_caches_list_and_reads_detail() {
    use crate::adapters::homework_http::SPOC_BASE;
    let envelope = |content: Value| serde_json::json!({"code":200,"content":content}).to_string();
    let mut responses = login_chain("sy2501001", "fixture");
    let spoc_auth = || {
        vec![
            HttpResponse::new(200, "https://spoc.buaa.edu.cn/spocnew/", "spa"),
            HttpResponse::new(
                404,
                "https://spoc.buaa.edu.cn/spocnew/cas?token=fixture",
                "callback",
            ),
            HttpResponse::new(
                200,
                format!("{SPOC_BASE}/sys/casLogin"),
                envelope(serde_json::json!({"rolecode":"01"})),
            ),
        ]
    };
    responses.extend(spoc_auth());
    responses.extend([
        HttpResponse::new(
            200,
            "term",
            envelope(serde_json::json!({"mrxq":"2026-20271","dqxq":"合成学期"})),
        ),
        HttpResponse::new(
            200,
            "courses",
            envelope(serde_json::json!([{"kcid":"c1","kcmc":"合成课程","skjs":"合成教师"}])),
        ),
        HttpResponse::new(
            200,
            "page",
            envelope(fixture("homework", "spoc-page-v1.json")["input"]["body"].clone()),
        ),
    ]);
    responses.extend(spoc_auth());
    responses.extend([
        HttpResponse::new(
            200,
            "assignment",
            envelope(serde_json::json!({"zynr":"<p>合成说明</p>"})),
        ),
        HttpResponse::new(200, "submission", envelope(serde_json::json!({"tjzt":"1"}))),
        HttpResponse::new(503, "spa", "unavailable"),
    ]);
    let (service, transport) = build_service(responses, MemoryVault::default());
    service
        .sign_in("sy2501001", "pa+ss/word", None, true)
        .await
        .expect("login");
    let list = service.load_homework(false).await.expect("list");
    assert_eq!(list.data.items.len(), 2);
    assert_eq!(list.data.items[0].teacher_name.as_deref(), Some("合成教师"));
    assert!(list.data.items[1].teacher_name.is_none());
    let count = transport.request_count();
    assert_eq!(
        service
            .load_homework(false)
            .await
            .expect("cache")
            .data
            .term_code,
        "2026-20271"
    );
    assert_eq!(count, transport.request_count());
    let detail = service
        .load_homework_detail("spoc:a", false)
        .await
        .expect("detail");
    assert_eq!(detail.data.content.as_deref(), Some("合成说明"));
    assert!(transport
        .requests()
        .iter()
        .any(|r| r.url.ends_with("/kczy/queryKczyInfoByid?id=a")));
    assert!(!transport
        .requests()
        .iter()
        .any(|r| r.url.contains("id=spoc")));
    assert_eq!(
        detail.data.status,
        crate::features::homework::HomeworkStatus::Submitted
    );
    // Teacher context belongs to the cached snapshot, including failed refresh.
    let stale = service.load_homework(true).await.expect("stale");
    assert!(stale.failure.is_some());
    assert_eq!(
        stale.data.items[0].teacher_name.as_deref(),
        Some("合成教师")
    );
    service.sign_out().await;
    assert!(service.load_homework(false).await.is_err());
}

#[tokio::test]
async fn homework_changed_body_preserves_cached_text_and_native_ids_share_cache() {
    use crate::{adapters::homework_http::SPOC_BASE, features::homework};
    let envelope = |content: Value| serde_json::json!({"code":200,"content":content}).to_string();
    let mut responses = login_chain("sy2501001", "fixture");
    responses.extend([
        HttpResponse::new(200, "https://spoc.buaa.edu.cn/spocnew/", "spa"),
        HttpResponse::new(
            404,
            "https://spoc.buaa.edu.cn/spocnew/cas?token=fixture",
            "callback",
        ),
        HttpResponse::new(
            200,
            format!("{SPOC_BASE}/sys/casLogin"),
            envelope(serde_json::json!({"rolecode":"01"})),
        ),
        HttpResponse::new(
            200,
            "detail",
            envelope(serde_json::json!({"zynr":{"text":"invalid structure"}})),
        ),
        HttpResponse::new(200, "submission", envelope(Value::Null)),
    ]);
    let (service, transport) = build_service(responses, MemoryVault::default());
    service
        .sign_in("sy2501001", "pa+ss/word", None, true)
        .await
        .expect("signed in");
    let cached =
        homework::parse_detail(&fixture("homework", "spoc-detail-normal-v1.json")["input"])
            .expect("synthetic detail");
    service
        .homework_details
        .lock()
        .expect("detail cache")
        .insert("synthetic+a/b".into(), cached);
    let initial = transport.request_count();
    assert_eq!(
        service
            .load_homework_detail("spoc:synthetic+a/b", false)
            .await
            .expect("cache")
            .data
            .content
            .as_deref(),
        Some("合成说明")
    );
    assert_eq!(transport.request_count(), initial);
    let result = service
        .load_homework_detail("synthetic+a/b", true)
        .await
        .expect("prior snapshot");
    assert_eq!(
        result.failure.expect("structure failure").code,
        ErrorCode::ChangedResponse
    );
    assert_eq!(result.data.content.as_deref(), Some("合成说明"));
    assert!(transport.requests().iter().any(|request| request
        .url
        .ends_with("queryKczyInfoByid?id=synthetic%2Ba%2Fb")));
}

#[tokio::test]
async fn bykc_failure_retains_cached_catalog_and_logout_isolates_account() {
    let mut responses = login_chain("sy2501001", "fixture");
    responses.push(HttpResponse::new(503, "bykc", "unavailable"));
    let (service, _) = build_service(responses, MemoryVault::default());
    service
        .sign_in("sy2501001", "pa+ss/word", None, true)
        .await
        .expect("login");
    let fixture = fixture("bykc", "catalog-normal-v1.json");
    let catalog = crate::features::bykc::parse_catalog(
        &fixture["input"]["config"],
        fixture["input"]["pages"].as_array().expect("pages"),
    )
    .expect("catalog");
    service
        .bykc
        .lock()
        .expect("cache")
        .insert("catalog".into(), catalog);
    assert_eq!(
        service
            .load_bykc(false)
            .await
            .expect("fresh")
            .data
            .courses
            .len(),
        1
    );
    let stale = service.load_bykc(true).await.expect("stale");
    assert!(stale.failure.is_some());
    let details = stale.data.courses[0]
        .details
        .as_ref()
        .expect("cached course details");
    assert_eq!(details.capacity, Some(40));
    assert_eq!(details.enrolled, Some(12));
    assert_eq!(details.campuses, ["学院路", "沙河"]);
    assert!(!serde_json::to_string(&stale.data)
        .expect("projection")
        .contains("synthetic-configuration-not-to-be-exported"));
    service.sign_out().await;
    assert!(service.load_bykc(false).await.is_err());
}

#[tokio::test]
async fn bykc_queued_cache_misses_reuse_snapshots_filled_while_waiting() {
    use crate::features::bykc;
    let (service, transport) =
        build_service(login_chain("sy2501001", "fixture"), MemoryVault::default());
    service
        .sign_in("sy2501001", "pa+ss/word", None, true)
        .await
        .expect("login");
    let initial = transport.requests().len();
    let catalog = bykc::Catalog {
        terms: vec![],
        courses: vec![],
    };
    let chosen = bykc::ChosenCourses {
        term: None,
        courses: None,
    };
    let statistics = bykc::parse_statistics(&fixture("bykc", "statistics-normal-v1.json")["input"])
        .expect("statistics");
    let access = service.bykc_access.lock().await;
    let mut catalog_read = std::pin::pin!(service.load_bykc(false));
    let mut chosen_read = std::pin::pin!(service.load_bykc_chosen(false));
    let mut statistics_read = std::pin::pin!(service.load_bykc_statistics(false));
    std::future::poll_fn(|cx| {
        assert!(std::future::Future::poll(catalog_read.as_mut(), cx).is_pending());
        assert!(std::future::Future::poll(chosen_read.as_mut(), cx).is_pending());
        assert!(std::future::Future::poll(statistics_read.as_mut(), cx).is_pending());
        std::task::Poll::Ready(())
    })
    .await;
    service
        .bykc
        .lock()
        .expect("catalog")
        .insert("catalog".into(), catalog);
    service
        .bykc_chosen
        .lock()
        .expect("chosen")
        .insert("chosen".into(), chosen);
    service
        .bykc_statistics
        .lock()
        .expect("statistics")
        .insert("statistics".into(), statistics);
    drop(access);
    assert!(catalog_read
        .await
        .expect("catalog snapshot")
        .failure
        .is_none());
    assert!(chosen_read
        .await
        .expect("chosen snapshot")
        .failure
        .is_none());
    assert_eq!(
        statistics_read
            .await
            .expect("statistics snapshot")
            .data
            .valid_course_count,
        Some(5)
    );
    assert_eq!(
        transport.requests().len(),
        initial,
        "queued reads must not repeat HTTP after cache fill"
    );
}

#[tokio::test]
async fn bykc_learning_caches_are_independent_preserve_failures_and_clear_for_identity() {
    use crate::features::bykc;
    let mut responses = login_chain("sy2501001", "fixture");
    responses.extend([
        HttpResponse::new(
            503,
            "https://bykc.buaa.edu.cn/sscv/cas/login",
            "unavailable",
        ),
        HttpResponse::new(
            503,
            "https://bykc.buaa.edu.cn/sscv/cas/login",
            "unavailable",
        ),
    ]);
    let (service, transport) = build_service(responses, MemoryVault::default());
    service
        .sign_in("sy2501001", "pa+ss/word", None, true)
        .await
        .expect("login");
    let chosen = bykc::ChosenCourses {
        term: None,
        courses: Some(
            bykc::parse_chosen(&fixture("bykc", "chosen-normal-v1.json")["input"]).expect("chosen"),
        ),
    };
    let statistics = bykc::parse_statistics(&fixture("bykc", "statistics-normal-v1.json")["input"])
        .expect("statistics");
    service
        .bykc_chosen
        .lock()
        .expect("chosen cache")
        .insert("chosen".into(), chosen);
    service
        .bykc_statistics
        .lock()
        .expect("statistics cache")
        .insert("statistics".into(), statistics);
    let initial = transport.requests().len();
    assert_eq!(
        service
            .load_bykc_chosen(false)
            .await
            .expect("fresh chosen")
            .data
            .courses
            .expect("known range")[0]
            .score,
        Some(92)
    );
    assert_eq!(
        service
            .load_bykc_statistics(false)
            .await
            .expect("fresh statistics")
            .data
            .valid_course_count,
        Some(5)
    );
    assert_eq!(
        transport.requests().len(),
        initial,
        "fresh reads send no requests"
    );
    // Cached data remains available while another BYKC read holds the SSO guard.
    let access = service.bykc_access.lock().await;
    std::future::poll_fn(|cx| {
        let mut read = std::pin::pin!(service.load_bykc_statistics(false));
        assert!(std::future::Future::poll(read.as_mut(), cx).is_ready());
        std::task::Poll::Ready(())
    })
    .await;
    drop(access);
    let stale = service.load_bykc_chosen(true).await.expect("stale chosen");
    assert!(stale.failure.is_some());
    assert_eq!(stale.data.courses.as_ref().expect("snapshot").len(), 1);
    let projected = serde_json::to_string(&stale.data).expect("projection");
    assert!(!projected.contains("synthetic-configuration-not-to-be-exported"));
    assert!(!projected.contains("synthetic-homework-not-to-be-exported"));
    assert!(!projected.contains("synthetic-private-field"));
    let statistics = service
        .load_bykc_statistics(false)
        .await
        .expect("independent fresh statistics");
    assert!(statistics.failure.is_none());
    assert_eq!(transport.requests().len(), initial + 1);
    let statistics = service
        .load_bykc_statistics(true)
        .await
        .expect("stale statistics");
    assert!(statistics.failure.is_some());
    assert_eq!(statistics.data.entries[2].completed, 3);
    service.clear_caches();
    assert!(service
        .bykc_chosen
        .lock()
        .expect("chosen cache")
        .any(&"chosen".into())
        .is_none());
    assert!(service
        .bykc_statistics
        .lock()
        .expect("statistics cache")
        .any(&"statistics".into())
        .is_none());
    service.sign_out().await;
    assert!(service.load_bykc_chosen(false).await.is_err());
    assert!(service.load_bykc_statistics(false).await.is_err());
}

#[tokio::test]
async fn graduate_reads_status_whitelist_and_execution_report_then_caches() {
    let mut responses = login_chain("sy2501001", "fixture");
    responses.extend([
        HttpResponse::new(200,"status app","app"),
        HttpResponse::new(200,"status",serde_json::json!({"code":0,"datas":{"xsjcxxcx":{"rows":[{"YXDM_DISPLAY":"合成学院","SFZH":"must-not-leave-rust"}]}}}).to_string()),
        HttpResponse::new(200,"execution app","app"),
        HttpResponse::new(200,"execution",fixture("graduate","execution-normal-v1.json")["input"].to_string()),
    ]);
    let (service, transport) = build_service(responses, MemoryVault::default());
    service
        .sign_in("sy2501001", "pa+ss/word", None, true)
        .await
        .expect("login");
    use crate::application::GraduatePart;
    let status = service
        .load_graduate_part(GraduatePart::Status, false)
        .await
        .expect("status first");
    let serialized = serde_json::to_string(&status.data).expect("json");
    assert!(serialized.contains("合成学院"));
    assert!(!serialized.contains("must-not-leave-rust"));
    // Only status activation + status query have occurred. No report needed to render it.
    let count = transport.request_count();
    assert_eq!(count, 7); // Login (5) + status activation (1) + status read (1).
    service
        .load_graduate_part(GraduatePart::Status, false)
        .await
        .expect("cached status");
    assert_eq!(count, transport.request_count());
    let report = service
        .load_graduate_part(GraduatePart::Report, false)
        .await
        .expect("report");
    assert!(serde_json::to_string(&report.data)
        .expect("json")
        .contains("要求 6"));
    assert_eq!(
        report.data.sections[0]
            .progress
            .as_ref()
            .expect("progress")
            .earned,
        Some(2.0)
    );
    let count = transport.request_count();
    // Successful report never fetches the fallback plan or re-authenticates.
    assert_eq!(count, 9);
    let requests = transport.requests();
    let report_requests = &requests[7..];
    assert!(report_requests[0]
        .url
        .ends_with("wdpyfazxbgappbuaa/*default/index.do"));
    assert!(report_requests[1]
        .url
        .ends_with("wdpyfazxbgappbuaa/zxbg/loadXspyfazxbgInfo.do"));
    assert_eq!(report_requests[1].body.as_deref(), Some("isShowSszxbg=0"));
    service.load_graduate(false).await.expect("both cached");
    assert_eq!(count, transport.request_count());
    // Force failures must retain the matching section, never another section's snapshot.
    let stale = service
        .load_graduate_part(GraduatePart::Report, true)
        .await
        .expect("stale report");
    assert!(stale.failure.is_some());
    assert_eq!(stale.data.sections[0].title, "培养方案执行报告");
    let count = transport.request_count();
    let status = service
        .load_graduate_part(GraduatePart::Status, false)
        .await
        .expect("status unaffected");
    assert!(status.failure.is_none());
    assert_eq!(count, transport.request_count());
    service.clear_snapshots();
    assert!(service
        .load_graduate_part(GraduatePart::Status, false)
        .await
        .is_err());
}

#[tokio::test]
async fn notices_public_list_caches_and_preserves_last_result_on_drift() {
    let body = fixture("notices", "normal-v1.json")["input"]["html"]
        .as_str()
        .unwrap()
        .to_owned();
    let url = "https://news.buaa.edu.cn/tzgg.htm";
    let (service, transport) = build_service(
        vec![
            HttpResponse::new(200, url, body),
            HttpResponse::new(200, url, "<html>changed</html>"),
        ],
        MemoryVault::default(),
    );
    assert_eq!(service.load_notices(false).await.unwrap().data.len(), 1);
    assert_eq!(service.load_notices(false).await.unwrap().data.len(), 1);
    assert_eq!(transport.request_count(), 1);
    let stale = service.load_notices(true).await.unwrap();
    assert_eq!(stale.data[0].title, "合成校园通知");
    assert_eq!(stale.failure.unwrap().code, ErrorCode::ChangedResponse);
}

#[tokio::test]
async fn cgyy_direct_public_login_day_orders_and_stale_snapshot() {
    let mut chain = login_chain("synthetic-student", "合成用户");
    let base = "https://cgyy.buaa.edu.cn/venue-zhjs-server";
    chain.extend([
        HttpResponse::new(
            200,
            format!("{base}/api/front/website/venues"),
            fixture("cgyy", "venues-normal-v1.json")["input"].to_string(),
        ),
        HttpResponse::new(200, format!("{base}/sso/manageLogin"), "ok")
            .with_set_cookie("sso_buaa_zhjs_token=synthetic-sso; Path=/; Secure"),
        HttpResponse::new(
            200,
            format!("{base}/api/login"),
            r#"{"code":200,"data":{"token":{"access_token":"synthetic-access"}}}"#,
        ),
        HttpResponse::new(
            200,
            format!("{base}/api/reservation/day/info"),
            fixture("cgyy", "day-normal-v1.json")["input"]["response"].to_string(),
        ),
        HttpResponse::new(
            200,
            format!("{base}/api/orders/mine"),
            fixture("cgyy", "orders-normal-v1.json")["input"].to_string(),
        ),
        HttpResponse::new(200, format!("{base}/api/reservation/day/info"), "{}"),
    ]);
    let (service, transport) = build_service(chain, MemoryVault::default());
    service
        .sign_in("synthetic-student", "synthetic-password", None, false)
        .await
        .unwrap();
    service
        .session
        .set_route(crate::auth::session::RouteMode::WebVpn);
    assert_eq!(
        service
            .load_cgyy("venues", 0, "", false)
            .await
            .unwrap()
            .data
            .as_array()
            .unwrap()
            .len(),
        1
    );
    let day = service
        .load_cgyy("day", 1, "2026-10-20", false)
        .await
        .unwrap();
    assert_eq!(day.data["spaces"][0]["slots"][0]["status"], "空闲");
    assert!(!day.data.to_string().contains("must-not-cross-bridge"));
    let orders = service.load_cgyy("orders", 0, "", false).await.unwrap();
    assert!(!orders.data.to_string().contains("phone"));
    let count = transport.request_count();
    service
        .load_cgyy("day", 1, "2026-10-20", false)
        .await
        .unwrap();
    assert_eq!(count, transport.request_count());
    let stale = service
        .load_cgyy("day", 1, "2026-10-20", true)
        .await
        .unwrap();
    assert_eq!(stale.data["date"], "2026-10-20");
    assert!(stale.failure.is_some());
    for req in transport.requests().iter().skip(5) {
        assert!(req.url.starts_with("https://cgyy.buaa.edu.cn/"));
        if req.url.contains("/api/") {
            assert!(req.header_value("sign").is_some());
        }
        assert!(req.method == HttpMethod::Get || req.url.ends_with("/api/login"));
    }
    service.clear_snapshots();
    assert!(service.cgyy_token.lock().unwrap().is_none());
}

#[tokio::test]
async fn library_auth_failure_preserves_the_previous_snapshot() {
    let mut responses = login_chain("sy2501001", "fixture");
    responses.extend([
        library_login_redirect(),
        library_token_response(),
        library_body("space/pcTopFor"),
        HttpResponse::new(200, crate::adapters::library_http::LOGIN_START, FORM_PAGE),
    ]);
    let (service, _) = build_service(responses, MemoryVault::default());
    service
        .sign_in("sy2501001", "pa+ss/word", None, false)
        .await
        .unwrap();
    let first = service.load_library_venues(false).await.unwrap();
    *service.library_token.lock().unwrap() = None;
    let stale = service.load_library_venues(true).await.unwrap();
    assert!(stale.stale && stale.from_cache);
    assert_eq!(stale.venues.len(), first.venues.len());
    assert!(!stale.venues.is_empty());
    assert_eq!(stale.failure.unwrap().code, ErrorCode::SessionExpired);
}

#[tokio::test]
async fn concurrent_library_reads_share_one_cas_exchange() {
    use crate::foundation::http::{HttpRequest, HttpTransport};
    #[derive(Clone)]
    struct YieldingTransport(MockTransport);
    impl HttpTransport for YieldingTransport {
        async fn send(&self, request: HttpRequest) -> Result<HttpResponse, TransportError> {
            tokio::task::yield_now().await;
            self.0.send(request).await
        }
    }
    let mut responses = login_chain("sy2501001", "fixture");
    responses.extend([
        library_login_redirect(),
        library_token_response(),
        library_body("space/pcTopFor"),
        library_body("space/pcTopFor"),
    ]);
    let transport = MockTransport::with_responses(responses);
    let service = SessionService::new(
        crate::auth::session::Session::new(YieldingTransport(transport.clone())),
        MemoryVault::default(),
    );
    service
        .sign_in("sy2501001", "pa+ss/word", None, false)
        .await
        .unwrap();
    let (first, second) = tokio::join!(
        service.load_library_venues(true),
        service.load_library_venues(true)
    );
    assert!(!first.unwrap().venues.is_empty());
    assert!(!second.unwrap().venues.is_empty());
    assert_eq!(
        transport
            .requests()
            .iter()
            .filter(|r| r.url == crate::adapters::library_http::LOGIN_USER)
            .count(),
        1
    );
}

#[tokio::test]
async fn checkin_history_is_cached_per_date_and_failure_preserves_only_that_day() {
    let mut responses = login_chain("sy2501001", "fixture");
    responses.push(checkin_entry_response("fixture-login"));
    responses.push(checkin_app_login_response());
    responses.push(checkin_schedule_response(checkin_day_body()));
    responses.push(checkin_schedule_response(r#"{"STATUS":2}"#));
    responses.push(checkin_schedule_response("drift"));
    let (service, transport) = build_service(responses, MemoryVault::default());
    service
        .sign_in("sy2501001", "fixture-password", None, true)
        .await
        .expect("login");
    let first = service
        .load_checkin_on_date(Some("2026-09-01".into()), false)
        .await
        .expect("history");
    assert_eq!(first.date, "2026-09-01");
    assert_eq!(first.courses.len(), 2);
    let empty = service
        .load_checkin_on_date(Some("2026-09-02".into()), false)
        .await
        .expect("empty");
    assert!(empty.courses.is_empty());
    let cached = service
        .load_checkin_on_date(Some("2026-09-01".into()), false)
        .await
        .expect("cache");
    assert!(cached.from_cache);
    let stale = service
        .load_checkin_on_date(Some("2026-09-01".into()), true)
        .await
        .expect("stale");
    assert!(stale.stale && stale.failure.is_some());
    assert_eq!(stale.courses, first.courses);
    let before = transport.request_count();
    for date in ["2026-02-30", "20260901", "2099-01-01"] {
        assert!(service
            .load_checkin_on_date(Some(date.into()), false)
            .await
            .is_err());
    }
    assert_eq!(before, transport.request_count());
    let requests = transport.requests();
    let queries: Vec<_> = requests
        .iter()
        .filter(|r| r.url.contains("dateStr="))
        .collect();
    assert!(queries[0].url.contains("dateStr=20260901"));
    assert!(queries[1].url.contains("dateStr=20260902"));
}

#[tokio::test]
async fn library_history_pages_are_isolated_and_expiry_recovers_once() {
    let body = |data: serde_json::Value| {
        HttpResponse::new(
            200,
            "https://booking.lib.buaa.edu.cn/v4/member/seat",
            serde_json::json!({"code":0,"data":data}).to_string(),
        )
    };
    let mut responses = login_chain("sy2501001", "fixture");
    responses.push(library_login_redirect());
    responses.push(library_token_response());
    responses.push(body(
        fixture("library", "history-normal-v1.json")["input"]["data"].clone(),
    ));
    responses.push(body(
        serde_json::json!({"data":[],"page":2,"limit":40,"total":42}),
    ));
    responses.push(HttpResponse::new(401, "library", "expired"));
    responses.push(library_login_redirect());
    responses.push(library_token_response());
    responses.push(body(
        fixture("library", "history-normal-v1.json")["input"]["data"].clone(),
    ));
    responses.push(HttpResponse::new(500, "library", "unavailable"));
    let (service, transport) = build_service(responses, MemoryVault::default());
    service
        .sign_in("sy2501001", "fixture-password", None, true)
        .await
        .expect("login");
    let first = service
        .load_library_history(1, false)
        .await
        .expect("page one");
    assert!(first.data.has_next);
    let second = service
        .load_library_history(2, false)
        .await
        .expect("page two");
    assert!(!second.data.has_next);
    assert!(
        service
            .load_library_history(1, false)
            .await
            .expect("cache")
            .from_cache
    );
    let recovered = service
        .load_library_history(1, true)
        .await
        .expect("recover");
    assert!(!recovered.stale);
    let stale = service.load_library_history(1, true).await.expect("stale");
    assert!(stale.stale && stale.failure.is_some());
    assert_eq!(stale.data, first.data);
    let before = transport.request_count();
    assert!(service.load_library_history(0, false).await.is_err());
    assert_eq!(before, transport.request_count());
    let requests = transport.requests();
    let history: Vec<_> = requests
        .iter()
        .filter(|r| r.url.ends_with("member/seat"))
        .collect();
    let params: serde_json::Value =
        serde_json::from_str(history[1].body.as_deref().expect("body")).expect("json");
    assert_eq!(params, serde_json::json!({"type":"1","page":2,"limit":40}));
    assert_eq!(
        history[0].header_value("Authorization"),
        Some("bearerfixture-library-token")
    );
}

#[tokio::test]
async fn library_public_stats_are_cookie_isolated_cached_and_preserved_on_failure() {
    let endpoint = crate::adapters::library_stats_http::URL;
    let mut responses = login_chain("sy2501001", "fixture");
    responses.push(
        HttpResponse::new(200, "https://lib.buaa.edu.cn/", "seed")
            .with_set_cookie("synthetic_private=must-not-leak; Path=/; Secure"),
    );
    responses.push(
        HttpResponse::new(
            200,
            endpoint,
            fixture("library", "stats-normal-v1.json")["input"]["html"]
                .as_str()
                .expect("html"),
        )
        .with_set_cookie("public_ephemeral=fixture; Path=/; Secure"),
    );
    responses.push(HttpResponse::new(503, endpoint, "unavailable"));
    let (service, transport) = build_service(responses, MemoryVault::default());
    service
        .sign_in("sy2501001", "fixture-password", None, true)
        .await
        .expect("login");
    service
        .session
        .send(HttpRequest::get("https://lib.buaa.edu.cn/"))
        .await
        .expect("seed cookie");
    // A private business request already activated WebVPN fallback. Public
    // statistics still start from the user's Automatic preference, cookie-free.
    assert!(service.session.activate_automatic_webvpn_fallback());
    let first = service.load_library_stats(false).await.expect("public");
    assert_eq!(first.campuses.len(), 2);
    assert_eq!(first.campuses[0].people, 120);
    assert!(
        service
            .load_library_stats(false)
            .await
            .expect("cache")
            .from_cache
    );
    let old = service.load_library_stats(true).await.expect("old");
    assert!(old.failure.is_some());
    assert_eq!(old.campuses, first.campuses);
    let requests = transport.requests();
    let stats: Vec<_> = requests.iter().filter(|r| r.url == endpoint).collect();
    assert_eq!(stats.len(), 2);
    assert!(stats.iter().all(|r| r.header_value("Cookie").is_none()));
}

#[tokio::test]
async fn schedule_expired_session_without_saved_password_keeps_snapshot() {
    let mut responses = login_chain("sy2501001", "fixture");
    responses.extend(vec![
        HttpResponse::new(200, "portal", r#"{"code":"0"}"#),
        HttpResponse::new(200, "terms", schedule_body("terms-normal-v1.json")),
        HttpResponse::new(200, "weeks", schedule_body("weeks-normal-v1.json")),
        HttpResponse::new(200, "courses", schedule_body("courses-normal-v1.json")),
        HttpResponse::new(200, "exams", schedule_body("exams-normal-v1.json")),
        HttpResponse::new(200, LOGIN_URL, FORM_PAGE),
    ]);
    let (service, transport) = build_service(responses, MemoryVault::default());
    service
        .sign_in("sy2501001", "fixture-password", None, false)
        .await
        .expect("login");
    let first = service
        .load_schedule(&ScheduleQueryInput {
            term_id: None,
            week: None,
            force_refresh: false,
        })
        .await
        .expect("snapshot");
    let stale = service
        .load_schedule(&ScheduleQueryInput {
            term_id: None,
            week: None,
            force_refresh: true,
        })
        .await
        .expect("retained snapshot");
    assert!(stale.stale);
    assert_eq!(
        stale.failure.expect("failure").code,
        ErrorCode::SessionExpired
    );
    assert_eq!(stale.fetched_at, first.fetched_at);
    assert_eq!(stale.data.courses, first.data.courses);
    assert_eq!(transport.request_count(), 11);
}

#[tokio::test]
async fn sign_out_after_route_change_removes_saved_account() {
    let mut responses = login_chain("sy2501001", "fixture");
    responses.push(HttpResponse::new(200, "logout", ""));
    let (service, _) = build_service(responses, MemoryVault::default());
    service
        .sign_in("sy2501001", "fixture-password", None, true)
        .await
        .expect("login");
    service.set_route(RoutePreference::Direct);
    assert!(!service.status().signed_in());
    assert_eq!(service.vault.names().len(), 1);
    service.sign_out().await;
    assert!(service.vault.names().is_empty());
}

#[tokio::test]
async fn checkin_write_revalidates_today_sends_once_and_invalidates_snapshot() {
    use crate::features::mutation::MutationState;
    let mut responses = login_chain("sy2501001", "fixture");
    responses.extend([
        checkin_entry_response("fixture-login"),
        checkin_app_login_response(),
        checkin_schedule_response(checkin_day_body()),
        HttpResponse::new(200, "timestamp", r#"{"timestamp":"1720000000+1"}"#),
        HttpResponse::new(503, "sign", ""),
    ]);
    let (service, transport) = build_service(responses, MemoryVault::default());
    service
        .sign_in("sy2501001", "pa+ss/word", None, false)
        .await
        .unwrap();
    let id = fixture("checkin", "course-schedule-normal-v1.json")["input"]["body"]["result"][0]
        ["id"]
        .as_str()
        .unwrap_or("501")
        .to_owned();
    let outcome = service.submit_checkin(&id).await;
    assert_eq!(outcome.state, MutationState::Uncertain);
    let writes: Vec<_> = transport
        .requests()
        .into_iter()
        .filter(|r| r.url.contains("stu_scan_sign.action"))
        .collect();
    assert_eq!(writes.len(), 1);
    assert_eq!(writes[0].method, HttpMethod::Post);
    assert!(writes[0].url.contains("timestamp=1720000000%2B1"));
    assert!(writes[0].header_value("sessionId").is_some());
    let day = crate::foundation::school_time::beijing_day(&super::cache::now_shanghai())
        .unwrap()
        .local_date;
    assert!(service.checkin.lock().unwrap().any(&day).is_none());
}

#[tokio::test]
async fn library_write_failure_is_not_replayed_or_route_switched() {
    use crate::{
        adapters::library_http,
        auth::session::{RouteMode, Session},
        features::mutation::MutationState,
    };
    let transport = MockTransport::with_results(vec![Err(TransportError::Unavailable)]);
    let session = Session::new(transport.clone());
    let outcome = library_http::mutate(
        &session,
        "synthetic",
        "space/cancel",
        &serde_json::json!({"id":"b1"}),
    )
    .await;
    assert_eq!(outcome.state, MutationState::Uncertain);
    assert_eq!(transport.request_count(), 1);
    assert_eq!(session.route(), RouteMode::Automatic);
}

#[tokio::test]
async fn library_reserve_rechecks_slot_and_seat_then_submits_once() {
    use crate::features::{library::LibrarySlot, mutation::MutationState};
    let mut responses = login_chain("sy2501001", "fixture");
    responses.extend([
        library_login_redirect(), library_token_response(),
        HttpResponse::new(200, "slots", serde_json::json!({"code":0,"data":fixture("library","slots-normal-v1.json")["input"]["data"]}).to_string()),
        HttpResponse::new(200, "seats", serde_json::json!({"code":0,"data":fixture("library","seats-normal-v1.json")["input"]["data"]}).to_string()),
        HttpResponse::new(200, "reserve", r#"{"code":1}"#),
    ]);
    let (service, transport) = build_service(responses, MemoryVault::default());
    service
        .sign_in("sy2501001", "pa+ss/word", None, false)
        .await
        .unwrap();
    let outcome = service
        .reserve_library_seat(
            "a1",
            "s1",
            LibrarySlot {
                id: "2026-10-20/t1".into(),
                day: "2026-10-20".into(),
                start: "08:00".into(),
                end: "10:00".into(),
            },
        )
        .await;
    assert_eq!(outcome.state, MutationState::Accepted);
    let writes: Vec<_> = transport
        .requests()
        .into_iter()
        .filter(|r| r.url.ends_with("space/confirm"))
        .collect();
    assert_eq!(writes.len(), 1);
    assert_eq!(
        writes[0].header_value("Authorization"),
        Some("bearerfixture-library-token")
    );
    let body: Value = serde_json::from_str(writes[0].body.as_deref().unwrap()).unwrap();
    assert!(body["aesjson"].is_string());
    assert!(!writes[0].body.as_ref().unwrap().contains("seat_id"));
}

#[tokio::test]
async fn library_cancel_revalidates_kind_and_never_cancels_an_ended_booking() {
    use crate::features::mutation::MutationState;
    for (day, expected, posts) in [
        ("2099-10-20", MutationState::Accepted, 1),
        ("2000-01-01", MutationState::NotSubmitted, 0),
    ] {
        let mut responses = login_chain("sy2501001", "fixture");
        responses.extend([
            library_login_redirect(), library_token_response(),
            HttpResponse::new(200, "bookings", serde_json::json!({"code":0,"data":[{"id":"b1","type":2,"status":1,"day":day,"end_time":"12:00","oksign":1}]}).to_string()),
            HttpResponse::new(200, "cancel", r#"{"code":0}"#),
        ]);
        let (service, transport) = build_service(responses, MemoryVault::default());
        service
            .sign_in("sy2501001", "pa+ss/word", None, false)
            .await
            .unwrap();
        let outcome = service.perform_library_action("b1", "cancel").await;
        assert_eq!(outcome.state, expected);
        assert_eq!(
            transport
                .requests()
                .iter()
                .filter(|r| r.url.ends_with("seminar/cancel"))
                .count(),
            posts
        );
    }
}

#[tokio::test]
async fn concurrent_school_recovery_joins_one_login_chain() {
    use crate::foundation::http::HttpTransport;
    #[derive(Clone)]
    struct Yielding(MockTransport);
    impl HttpTransport for Yielding {
        async fn send(&self, request: HttpRequest) -> Result<HttpResponse, TransportError> {
            tokio::task::yield_now().await;
            self.0.send(request).await
        }
    }
    let mut responses = login_chain("sy2501001", "fixture");
    responses.extend(login_chain("sy2501001", "fixture"));
    let transport = MockTransport::with_responses(responses);
    let service = SessionService::new(
        crate::auth::session::Session::new(Yielding(transport.clone())),
        MemoryVault::default(),
    );
    service
        .sign_in("sy2501001", "pa+ss/word", None, true)
        .await
        .unwrap();
    let before = transport.request_count();
    let (a, b) = tokio::join!(service.silent_login(), service.silent_login());
    assert!(a.is_ok() && b.is_ok());
    assert_eq!(transport.request_count() - before, 5);
}

#[tokio::test]
async fn graduate_plan_is_on_demand_independently_cached_and_preserved_on_failure() {
    use crate::application::GraduatePart;
    let input = fixture("graduate", "plan-normal-v1.json")["input"].clone();
    let base = "https://gsmis.buaa.edu.cn/gsapp/sys/wdpyfaappbuaa";
    let mut responses = login_chain("sy2501001", "fixture");
    responses.extend([
        HttpResponse::new(200, format!("{base}/*default/index.do"), "app"),
        HttpResponse::new(200, format!("{base}/modules/pyfaxq/gjxhcxdyfadm.do"),
            serde_json::json!({"code":0,"datas":{"gjxhcxdyfadm":{"rows":[{"FADM":"synthetic+/code"}]}}}).to_string()),
        HttpResponse::new(200, format!("{base}/modules/pyfaxq/facx.do"), input["header"].to_string()),
        HttpResponse::new(200, format!("{base}/modules/pyfaxq/gjfadmhqdydpyfanr.do"), input["chapters"].to_string()),
        HttpResponse::new(200, format!("{base}/modules/pyfaxq/pyfakcxxcx.do"), input["pool"].to_string()),
    ]);
    let (service, transport) = build_service(responses, MemoryVault::default());
    service
        .sign_in("sy2501001", "pa+ss/word", None, true)
        .await
        .expect("login");
    let before = transport.request_count();
    assert_eq!(before, 5, "login must not prefetch the plan");
    let plan = service
        .load_graduate_part(GraduatePart::Plan, false)
        .await
        .expect("plan");
    let projected = serde_json::to_value(&plan.data).expect("projection");
    assert_eq!(
        projected["sections"],
        fixture("graduate", "plan-normal-v1.json")["expected"]["sections"]
    );
    assert!(!projected.to_string().contains("synthetic-not-exported"));
    let requests = transport.requests();
    assert_eq!(requests.len(), before + 5);
    assert_eq!(requests[before + 2].method, HttpMethod::Get);
    assert!(requests[before + 2]
        .url
        .ends_with("facx.do?DM=synthetic%2B%2Fcode&EN=zh"));
    assert_eq!(
        requests[before + 3]
            .headers
            .get("Referer")
            .map(String::as_str),
        Some(format!("{base}/*default/index.do").as_str())
    );
    assert!(requests[before + 3]
        .url
        .ends_with("gjfadmhqdydpyfanr.do?DM=synthetic%2B%2Fcode"));
    let form: std::collections::HashMap<_, _> = url::form_urlencoded::parse(
        requests[before + 4]
            .body
            .as_ref()
            .expect("form body")
            .as_bytes(),
    )
    .into_owned()
    .collect();
    assert_eq!(
        form.get("setting").map(String::as_str),
        Some("[{\"name\":\"FADM\",\"value\":\"synthetic+/code\"}]")
    );
    service
        .load_graduate_part(GraduatePart::Plan, false)
        .await
        .expect("cached");
    assert_eq!(transport.request_count(), before + 5);
    // A failed unrelated report must not fall back to the plan snapshot.
    assert!(service
        .load_graduate_part(GraduatePart::Report, false)
        .await
        .is_err());
    let failed = service
        .load_graduate_part(GraduatePart::Plan, true)
        .await
        .expect("stale plan");
    assert!(failed.failure.is_some());
    assert_eq!(failed.data.sections.len(), plan.data.sections.len());
    service.clear_snapshots();
    assert!(service
        .load_graduate_part(GraduatePart::Plan, false)
        .await
        .is_err());
}
