use super::*;

#[tokio::test]
async fn checkin_concurrent_cold_reads_share_authentication_and_the_day_snapshot() {
    let mut responses = login_chain("sy2501001", "fixture");
    responses.push(checkin_entry_response("fixture-login"));
    responses.push(checkin_app_login_response());
    responses.push(checkin_schedule_response(checkin_day_body()));
    let transport = MockTransport::with_responses(responses);
    let service = SchoolClient::new(
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
async fn checkin_overlapping_forced_reads_share_new_result_but_later_refresh_is_fresh() {
    let mut responses = login_chain("sy2501001", "fixture");
    responses.push(checkin_entry_response("fixture-login"));
    responses.push(checkin_app_login_response());
    responses.push(checkin_schedule_response(checkin_day_body()));
    responses.push(checkin_schedule_response(checkin_day_body()));
    let transport = MockTransport::with_responses(responses);
    let service = SchoolClient::new(
        crate::auth::session::Session::new(YieldingTransport(transport.clone())),
        MemoryVault::default(),
    );
    service
        .sign_in("sy2501001", "pa+ss/word", None, true)
        .await
        .expect("signed in");

    let (first, second) = tokio::join!(service.load_checkin(true), service.load_checkin(true));
    assert!(!first.expect("first refresh").from_cache);
    assert!(second.expect("overlapping refresh").from_cache);
    assert_eq!(transport.request_count(), 8);
    let progress =
        serde_json::to_value(service.checkin_load_progress()).expect("progress projection");
    assert_eq!(progress["phase"], "complete");
    let stages: Vec<_> = progress["stages"]
        .as_array()
        .unwrap()
        .iter()
        .map(|stage| stage["phase"].as_str().unwrap())
        .collect();
    assert_eq!(stages, ["authenticating", "appLogin", "courses"]);
    assert!(!progress.to_string().contains("sy2501001"));
    assert!(!progress.to_string().contains("fixture"));
    assert!(
        !service
            .load_checkin(true)
            .await
            .expect("later refresh")
            .from_cache
    );
    // Overlapping reads share only a result fetched since their request began.
    // A subsequent deliberate refresh still goes upstream.
    assert_eq!(transport.request_count(), 9);
    service.sign_out().await;
    assert_eq!(service.checkin_load_progress().phase, "");
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
async fn checkin_day_gates_only_serialize_reads_for_the_same_date() {
    use std::{future::Future, task::Poll};
    let transport = MockTransport::default();
    let service = SchoolClient::new(
        crate::auth::session::Session::new(transport.clone()),
        MemoryVault::default(),
    );
    service.set_authenticated(
        "sy2501001".into(),
        UserProfile {
            school_id: "sy2501001".into(),
            name: "synthetic".into(),
        },
    );
    let date = "2026-01-01".to_owned();
    let other_date = "2026-01-02".to_owned();
    let timestamp = service
        .snapshots
        .checkin
        .lock()
        .insert(date.clone(), vec![]);
    let other_day_gate = service.checkin_day_gate(&other_date);
    let gate = other_day_gate.lock().await;
    let mut cached = Box::pin(service.load_checkin_on_date(Some(date.clone()), false));
    match std::future::poll_fn(|cx| Poll::Ready(cached.as_mut().poll(cx))).await {
        Poll::Ready(Ok(outcome)) => {
            assert!(outcome.from_cache && !outcome.stale);
            assert_eq!(outcome.fetched_at, timestamp);
        }
        _ => panic!("a cached day must not wait for a different day's network query"),
    }
    let mut other_day = Box::pin(service.load_checkin_on_date(Some(date.clone()), true));
    assert!(
        std::future::poll_fn(|cx| Poll::Ready(other_day.as_mut().poll(cx)))
            .await
            .is_ready(),
        "a different day must reach its own network read instead of waiting"
    );
    drop(other_day);
    drop(gate);

    let requests_before_same_day = transport.request_count();
    let date_gate = service.checkin_day_gate(&date);
    let same_day_gate = date_gate.lock().await;
    let mut forced = Box::pin(service.load_checkin_on_date(Some(date), true));
    assert!(
        std::future::poll_fn(|cx| Poll::Ready(forced.as_mut().poll(cx)))
            .await
            .is_pending()
    );
    assert_eq!(transport.request_count(), requests_before_same_day);
    drop(forced);
    drop(same_day_gate);
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
        crate::foundation::school_time::beijing_day(&crate::services::cache::now_shanghai())
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
    responses.push(HttpResponse::new(200, LOGIN_URL, FORM_PAGE));
    responses.push(super::uc_expired());
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
async fn direct_checkin_network_failure_never_switches_route_or_posts_password() {
    let mut results: Vec<_> = login_chain("sy2501001", "fixture")
        .into_iter()
        .map(Ok)
        .collect();
    results.push(Err(TransportError::Unavailable));
    let transport = MockTransport::with_results(results);
    let service = SchoolClient::new(
        crate::auth::session::Session::new(transport.clone()),
        MemoryVault::default(),
    );
    service
        .sign_in("sy2501001", "pa+ss/word", None, true)
        .await
        .unwrap();
    let before = transport.request_count();
    assert_eq!(
        service.load_checkin(false).await.unwrap_err().code,
        ErrorCode::ServiceUnavailable
    );
    assert_eq!(
        service.session.route(),
        crate::auth::session::RouteMode::Direct
    );
    assert_eq!(service.current_account().unwrap(), "sy2501001");
    let requests = transport.requests();
    assert_eq!(requests.len() - before, 1);
    assert!(requests[before..]
        .iter()
        .all(|r| r.method == HttpMethod::Get && !r.url.contains("d.buaa.edu.cn")));
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
async fn checkin_qr_revalidates_today_then_refreshes_timestamp_without_reloading_schedule() {
    let now = chrono::DateTime::parse_from_rfc3339(&crate::services::cache::now_shanghai())
        .expect("clock");
    let mut day: serde_json::Value = serde_json::from_str(&checkin_day_body()).expect("fixture");
    for row in day["result"].as_array_mut().expect("rows") {
        row["classBeginTime"] = serde_json::json!(now.format("%Y-%m-%d %H:%M:%S").to_string());
        row["classEndTime"] = serde_json::json!((now + chrono::Duration::minutes(10))
            .format("%Y-%m-%d %H:%M:%S")
            .to_string());
    }
    let mut responses = login_chain("sy2501001", "fixture");
    responses.extend([
        checkin_entry_response("fixture-login"),
        checkin_app_login_response(),
        checkin_schedule_response(day.to_string()),
        HttpResponse::new(200, "timestamp", r#"{"timestamp":"1700000000000"}"#),
        HttpResponse::new(200, "timestamp", r#"{"timestamp":"1700000005000"}"#),
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

    let first = service
        .prepare_checkin_qr(&id, true)
        .await
        .expect("initial qr");
    assert_eq!(first.course_id, id);
    assert_eq!(first.refresh_seconds, 4);
    assert_eq!(
        first.modules.len(),
        usize::from(first.matrix_size) * usize::from(first.matrix_size)
    );

    // Periodic refresh inside the open QR sheet reuses the fresh day snapshot
    // and only fetches a new timestamp.
    let second = service
        .prepare_checkin_qr(&id, false)
        .await
        .expect("refreshed qr");
    assert_ne!(first.modules, second.modules);

    let requests = transport.requests();
    assert!(requests
        .iter()
        .all(|r| !r.url.contains("stu_scan_sign.action")));
    assert_eq!(
        requests
            .iter()
            .filter(|r| r.url.contains("get_stu_course_sched.action"))
            .count(),
        1
    );
    assert_eq!(
        requests
            .iter()
            .filter(|r| r.url.contains("get_timestamp.action"))
            .count(),
        2
    );
}

#[tokio::test]
async fn out_of_window_or_signed_checkin_never_requests_timestamp() {
    let mut day: serde_json::Value = serde_json::from_str(&checkin_day_body()).expect("fixture");
    for row in day["result"].as_array_mut().expect("rows") {
        row["classBeginTime"] = serde_json::json!("2099-10-20 08:00:00");
        row["classEndTime"] = serde_json::json!("2099-10-20 09:00:00");
    }
    let unsigned_id = day["result"][0]["id"].as_str().expect("id").to_owned();
    let signed_id = day["result"][1]["id"].as_str().expect("id").to_owned();
    let mut responses = login_chain("sy2501001", "fixture");
    responses.extend([
        checkin_entry_response("fixture-login"),
        checkin_app_login_response(),
        checkin_schedule_response(day.to_string()),
    ]);
    let (service, transport) = build_service(responses, MemoryVault::default());
    service
        .sign_in("sy2501001", "synthetic-password", None, false)
        .await
        .expect("login");

    let outside = service
        .prepare_checkin_qr(&unsigned_id, true)
        .await
        .expect_err("outside window");
    assert_eq!(outside.code, ErrorCode::BusinessRejected);
    assert_eq!(outside.detail.as_deref(), Some("outside_window"));

    let already = service
        .prepare_checkin_qr(&signed_id, false)
        .await
        .expect_err("already signed");
    assert_eq!(already.code, ErrorCode::BusinessRejected);
    assert_eq!(already.detail.as_deref(), Some("already_signed"));

    assert!(transport
        .requests()
        .iter()
        .all(|r| !r.url.contains("stu_scan_sign") && !r.url.contains("get_timestamp")));
}

#[tokio::test]
async fn checkin_business_401_rebuilds_module_without_password_login() {
    let mut responses = login_chain("sy2501001", "fixture");
    responses.extend([
        checkin_entry_response("fixture-login"),
        checkin_app_login_response(),
        checkin_schedule_response(checkin_day_body()),
        HttpResponse::new(401, crate::adapters::checkin_http::COURSE_SCHEDULE_URL, ""),
        checkin_entry_response("fixture-login"),
        checkin_app_login_response(),
        checkin_schedule_response(checkin_day_body()),
    ]);
    let (service, transport) = build_service(responses, MemoryVault::default());
    service
        .sign_in("sy2501001", "pa+ss/word", None, false)
        .await
        .unwrap();
    service.load_checkin(true).await.unwrap();
    let recovered = service.load_checkin(true).await.unwrap();
    assert!(recovered.failure.is_none());
    assert!(!recovered.courses.is_empty());
    assert_eq!(
        transport
            .requests()
            .iter()
            .filter(|r| r.method == HttpMethod::Post && r.url == LOGIN_URL)
            .count(),
        1
    );
}

#[tokio::test]
async fn current_webvpn_iclass_401_rebuilds_once_without_school_reauth() {
    use super::session_protocol::wire;
    use crate::{
        adapters::checkin_http::{APP_LOGIN_URL, COURSE_SCHEDULE_URL, ENTRY_URL},
        auth::session::{RouteMode, Session},
        test_support::TranscriptTransport,
    };

    let route = RouteMode::WebVpn;
    let get = |url: &str| HttpRequest::get(wire(url, route)).header("Accept", "application/json");
    // A newly issued session can already be unusable; an old cached one can
    // also remain rejected after a rebuild. Neither case justifies a UC probe.
    for (cached, repeated) in [(false, false), (false, true), (true, true)] {
        let mut steps = Vec::new();
        for (id, denied) in [("old", true), ("new", repeated)] {
            let response = if denied {
                HttpResponse::new(401, wire(COURSE_SCHEDULE_URL, route), "")
            } else {
                checkin_schedule_response(checkin_day_body())
            };
            if !cached || id == "new" {
                let app_login = format!("{APP_LOGIN_URL}?password=&phone=fixture-login&userLevel=1&verificationType=2&verificationUrl=");
                let app_session =
                    serde_json::json!({"STATUS":0,"result":{"id":"1001","sessionId":id}});
                steps.extend([
                    (get(ENTRY_URL), Ok(checkin_entry_response("fixture-login"))),
                    (
                        get(&app_login),
                        Ok(HttpResponse::new(
                            200,
                            wire(APP_LOGIN_URL, route),
                            app_session.to_string(),
                        )),
                    ),
                ]);
            }
            steps.push((
                get(&format!("{COURSE_SCHEDULE_URL}?id=1001&dateStr=20261020"))
                    .header("sessionId", id),
                Ok(response),
            ));
        }
        let transport = TranscriptTransport::new(steps);
        let service = SchoolClient::new(Session::new(transport.clone()), seeded("sy2501001"));
        service.set_route(RoutePreference::WebVpn);
        service.set_authenticated(
            "sy2501001".into(),
            UserProfile {
                school_id: "sy2501001".into(),
                name: "fixture".into(),
            },
        );
        if cached {
            service.identity.lock().iclass = Some(crate::codecs::checkin::IClassSession {
                user_id: "1001".into(),
                session_id: "old".into(),
            });
        }
        let result = service
            .load_checkin_on_date(Some("2026-10-20".into()), true)
            .await;
        if repeated {
            assert_eq!(result.unwrap_err().code, ErrorCode::ModuleAuthRequired);
            assert!(service.identity.lock().iclass.is_none());
        } else {
            let result = result.unwrap();
            assert!(result.failure.is_none() && !result.from_cache);
            assert_eq!(result.courses.len(), 2);
        }
        assert!(service.status().signed_in());
        assert_eq!(service.session.route(), route);
        transport.assert_finished();
    }
}
