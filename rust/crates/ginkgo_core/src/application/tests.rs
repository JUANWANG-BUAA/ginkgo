use super::{
    ClassroomQueryInput, RoutePreference, ScheduleQueryInput, SessionOutcome, SessionService,
    SessionStatus,
};
use crate::{
    auth::{
        vault::MemoryVault, CredentialSource, Credentials, LoginResult, UserProfile, LOGIN_URL,
        UC_ACTIVATION_URL, UC_STATUS_URL,
    },
    features::classroom::Sort,
    foundation::http::{HttpMethod, HttpResponse},
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
            week: None,
            force_refresh: false,
        })
        .await
        .expect("cached schedule");
    assert!(second.from_cache);
    assert_eq!(transport.request_count(), 10);
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
            week: None,
            force_refresh: false,
        })
        .await
        .expect("first");
    let stale = service
        .load_schedule(&ScheduleQueryInput {
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
    responses.push(HttpResponse::new(
        200,
        "today",
        schedule_body("today-normal-v1.json"),
    ));
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
    assert_eq!(transport.request_count(), 6);

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
