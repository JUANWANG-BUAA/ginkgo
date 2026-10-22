use super::*;

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
    use crate::services::GraduatePart;
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
