use super::*;
use crate::auth::CredentialVault;
use ginkgo_domain::features::cgyy_booking::{BookingRequest, CgyyCommand};
use ginkgo_domain::ports::{CgyyData, CgyyQuery};
use serde_json::json;

fn expired_token() -> HttpResponse {
    HttpResponse::new(401, "fixture", "")
}
fn token_renewal() -> Vec<HttpResponse> {
    vec![
        HttpResponse::new(
            200,
            "https://cgyy.buaa.edu.cn/venue-zhjs-server/sso/manageLogin",
            "ok",
        )
        .with_set_cookie("sso_buaa_zhjs_token=synthetic-sso; Path=/; Secure"),
        response(json!({"token":{"access_token":"renewed-access-token"}})),
    ]
}
fn options_command() -> CgyyCommand {
    CgyyCommand::Options {
        site_id: 1,
        date: "2026-10-25".into(),
    }
}
fn assert_read_renewal_requests(transport: &MockTransport, reads: usize) {
    let requests = transport.requests();
    assert_eq!(
        requests
            .iter()
            .filter(|r| r.url.ends_with("/api/login"))
            .count(),
        1
    );
    assert_eq!(
        requests
            .iter()
            .filter(|r| r.header_value("cgAuthorization").is_some())
            .count(),
        reads
    );
    // The authentication POST is allowed; no business POST is ever retried.
    assert!(requests
        .iter()
        .all(|r| r.method == HttpMethod::Get || r.url.ends_with("/api/login")));
}
#[tokio::test]
async fn review_expired_token_renews_once_and_mints_id_from_fresh_orders() {
    let mut responses = vec![response(json!({"content":[]})), expired_token()];
    responses.extend(token_renewal());
    responses.push(response(
        fixture("cgyy", "orders-normal-v1.json")["input"]["data"].clone(),
    ));
    let (service, transport) = service(responses);
    mark_pending(&service);
    let old = service
        .execute_cgyy(CgyyCommand::Review)
        .await
        .expect("initial review")
        .review
        .expect("review")
        .id;
    seed_caches(&service);
    let review = service
        .execute_cgyy(CgyyCommand::Review)
        .await
        .expect("renewed review")
        .review
        .expect("review");
    assert_ne!(review.id, old);
    assert!(!review.orders.is_empty());
    assert!(is_pending(&service));
    assert!(service
        .execute_cgyy(CgyyCommand::Acknowledge { review_id: old })
        .await
        .is_err());
    assert_eq!(transport.request_count(), 5);
    assert_read_renewal_requests(&transport, 3);
    let requests = transport.requests();
    assert_eq!(
        requests[1].header_value("cgAuthorization"),
        Some("synthetic-access-token")
    );
    assert_eq!(
        requests[4].header_value("cgAuthorization"),
        Some("renewed-access-token")
    );
    assert_eq!(requests[3].header_value("Sso-Token"), Some("synthetic-sso"));
    service
        .execute_cgyy(CgyyCommand::Acknowledge {
            review_id: review.id,
        })
        .await
        .expect("fresh acknowledgement");
    assert!(!is_pending(&service));
}
#[tokio::test]
async fn review_failed_renewal_or_second_get_keeps_pending_without_review_or_cache_fallback() {
    let mut failures = vec![vec![HttpResponse::new(503, "renewal", "")]];
    for last in [
        expired_token(),
        HttpResponse::new(503, "second get", ""),
        HttpResponse::new(200, "fixture", "malformed"),
    ] {
        let mut chain = token_renewal();
        chain.push(last);
        failures.push(chain);
    }
    for failure in failures {
        let mut responses = vec![response(json!({"content":[]})), expired_token()];
        responses.extend(failure);
        let expected_requests = responses.len();
        let (service, transport) = service(responses);
        mark_pending(&service);
        let old = service
            .execute_cgyy(CgyyCommand::Review)
            .await
            .expect("first")
            .review
            .expect("review")
            .id;
        seed_caches(&service);
        assert!(service.execute_cgyy(CgyyCommand::Review).await.is_err());
        assert!(is_pending(&service));
        assert!(service
            .cgyy_safety
            .lock()
            .get("synthetic")
            .expect("safety")
            .review
            .is_none());
        assert!(service
            .execute_cgyy(CgyyCommand::Acknowledge { review_id: old })
            .await
            .is_err());
        assert_eq!(transport.request_count(), expected_requests);
        assert!(
            transport
                .requests()
                .iter()
                .filter(|r| r.url.ends_with("/api/login"))
                .count()
                <= 1
        );
    }
}
#[tokio::test]
async fn options_expired_day_token_renews_once_and_uses_new_token_for_codes() {
    let mut responses = vec![expired_token()];
    responses.extend(token_renewal());
    responses.extend([
        day(true),
        response(json!({"purpose":[{"key":1,"name":"合成类"}]})),
    ]);
    let (service, transport) = service(responses);
    mark_pending(&service);
    seed_caches(&service);
    let result = service
        .execute_cgyy(options_command())
        .await
        .expect("options");
    assert_eq!(result.state, "options");
    let options = result.options.expect("options");
    assert_eq!(options.choices.len(), 1);
    assert_eq!(options.purposes[0].id, 1);
    assert!(is_pending(&service));
    assert!(result.review.is_none());
    assert_eq!(transport.request_count(), 5);
    assert_read_renewal_requests(&transport, 3);
    for request in transport.requests().iter().skip(3) {
        assert_eq!(
            request.header_value("cgAuthorization"),
            Some("renewed-access-token")
        );
    }
}
#[tokio::test]
async fn options_use_ubaa_fallback_when_purpose_source_is_empty_or_rejected() {
    for codes in [
        response(json!({"purpose": []})),
        HttpResponse::new(
            200,
            "https://cgyy.buaa.edu.cn/venue-zhjs-server/api/codes",
            json!({"code": 500, "data": null}).to_string(),
        ),
    ] {
        let (service, _) = service(vec![day(true), codes]);
        let result = service
            .execute_cgyy(options_command())
            .await
            .expect("fallback options");
        let options = result.options.expect("options");
        assert_eq!(options.choices.len(), 1);
        assert_eq!(options.purposes.len(), 10);
        assert!(options.uses_fallback_purposes);
    }
}

#[tokio::test]
async fn options_never_hide_authentication_failure_behind_fallback() {
    let (service, _) = service(vec![day(true), expired_token()]);
    let error = match service.execute_cgyy(options_command()).await {
        Err(error) => error,
        Ok(_) => panic!("authentication must not fall back"),
    };
    assert_eq!(error.code, ErrorCode::SessionExpired);
}

#[tokio::test]
async fn options_failed_renewal_or_second_get_never_returns_cached_options() {
    let mut failures = vec![vec![HttpResponse::new(503, "renewal", "")]];
    for last in [
        expired_token(),
        HttpResponse::new(503, "second get", ""),
        HttpResponse::new(200, "fixture", "malformed"),
    ] {
        let mut chain = token_renewal();
        chain.push(last);
        failures.push(chain);
    }
    for failure in failures {
        let mut responses = vec![expired_token()];
        responses.extend(failure);
        let expected_requests = responses.len();
        let (service, transport) = service(responses);
        seed_caches(&service);
        assert!(service.execute_cgyy(options_command()).await.is_err());
        assert!(!is_pending(&service));
        assert_eq!(transport.request_count(), expected_requests);
        assert!(
            transport
                .requests()
                .iter()
                .filter(|r| r.url.ends_with("/api/login"))
                .count()
                <= 1
        );
        assert!(transport
            .requests()
            .iter()
            .all(|r| !r.url.contains("/api/codes")));
    }
}
#[tokio::test]
async fn options_renewal_failure_preserves_existing_pending_without_review() {
    let mut second_get_failure = token_renewal();
    second_get_failure.push(expired_token());
    for failure in [
        vec![HttpResponse::new(503, "renewal", "")],
        second_get_failure,
    ] {
        let mut responses = vec![expired_token()];
        responses.extend(failure);
        let expected_requests = responses.len();
        let (service, transport) = service(responses);
        mark_pending(&service);
        seed_caches(&service);
        let result = service
            .execute_cgyy(options_command())
            .await
            .expect("protected failure");
        assert_eq!(result.state, "uncertain");
        assert!(result.options.is_none() && result.review.is_none());
        assert!(is_pending(&service));
        assert!(service
            .cgyy_safety
            .lock()
            .get("synthetic")
            .expect("safety")
            .review
            .is_none());
        assert!(service.identity.lock().cgyy_token.is_none());
        assert_eq!(transport.request_count(), expected_requests);
    }
}
#[tokio::test]
async fn review_and_options_do_not_retry_5xx_or_parse_errors() {
    for review in [true, false] {
        for failure in [
            HttpResponse::new(503, "fixture", ""),
            HttpResponse::new(200, "fixture", "malformed"),
        ] {
            let command = if review {
                CgyyCommand::Review
            } else {
                options_command()
            };
            let (service, transport) = service(vec![failure]);
            seed_caches(&service);
            assert!(service.execute_cgyy(command).await.is_err());
            assert_eq!(transport.request_count(), 1);
            assert_eq!(
                service.identity.lock().cgyy_token.as_deref(),
                Some("synthetic-access-token")
            );
        }
    }
}
#[tokio::test]
async fn late_read_401_after_account_change_cannot_clear_new_token_or_renew() {
    for (review, suffix) in [(true, "/orders/mine"), (false, "/reservation/day/info")] {
        for account in ["synthetic-b", "synthetic"] {
            let command = if review {
                CgyyCommand::Review
            } else {
                options_command()
            };
            let (service, transport) = paused_service(vec![expired_token()], suffix);
            let (result, ()) = tokio::join!(service.execute_cgyy(command), async {
                transport.entered.notified().await;
                authenticate(&service, account);
                service.identity.lock().cgyy_token = Some("new-generation-token".into());
                transport.resume.notify_one();
            });
            assert!(result.is_err());
            assert_eq!(
                service.identity.lock().cgyy_token.as_deref(),
                Some("new-generation-token")
            );
            assert_eq!(transport.inner.request_count(), 1);
        }
    }
}
#[tokio::test]
async fn renewed_login_after_account_change_cannot_publish_token_or_send_second_get() {
    for command in [CgyyCommand::Review, options_command()] {
        let mut responses = vec![expired_token()];
        responses.extend(token_renewal());
        let (service, transport) = paused_service(responses, "/api/login");
        let (result, ()) = tokio::join!(service.execute_cgyy(command), async {
            transport.entered.notified().await;
            authenticate(&service, "synthetic-b");
            service.identity.lock().cgyy_token = Some("new-account-token".into());
            transport.resume.notify_one();
        });
        assert!(result.is_err());
        assert_eq!(
            service.identity.lock().cgyy_token.as_deref(),
            Some("new-account-token")
        );
        assert_eq!(transport.inner.request_count(), 3);
    }
}
#[tokio::test]
async fn mutation_precheck_401_never_enters_read_renewal_path() {
    for command in [
        CgyyCommand::Prepare { booking: booking() },
        CgyyCommand::Cancel { order_id: 9 },
    ] {
        let (service, transport) = service(vec![expired_token()]);
        assert!(service.execute_cgyy(command).await.is_err());
        assert_eq!(transport.request_count(), 1);
        assert!(transport
            .requests()
            .iter()
            .all(|r| r.method == HttpMethod::Get));
    }
}

#[tokio::test]
async fn order_detail_uses_ubaa_endpoint_and_projection() {
    let (service, transport) = service(vec![response(
        fixture("cgyy", "order-detail-normal-v1.json")["input"]["data"].clone(),
    )]);
    let outcome = service
        .load_cgyy(CgyyQuery::Order { order_id: 42 }, false)
        .await
        .expect("order detail");
    let CgyyData::Order(order) = outcome.data else {
        panic!("order projection")
    };
    assert_eq!(order.id, 42);
    assert_eq!(order.check_status, Some(1));
    let requests = transport.requests();
    assert_eq!(requests.len(), 1);
    assert!(requests[0].url.contains("/api/orders/42?"));
    assert!(requests[0].url.contains("nocache="));
    assert!(requests[0].header_value("sign").is_some());
}

#[tokio::test]
async fn lock_code_projects_ubaa_states_and_bypasses_snapshots() {
    for (name, password, trade) in [
        (
            "lock-code-normal-v1.json",
            Some("246810"),
            Some("synthetic-trade"),
        ),
        (
            "lock-code-upcoming-v1.json",
            None,
            Some("synthetic-upcoming"),
        ),
        ("lock-code-empty-v1.json", None, None),
    ] {
        let body = fixture("cgyy", name)["input"]["data"].clone();
        let (service, transport) = service(vec![response(body.clone()), response(body)]);
        for _ in 0..2 {
            let outcome = service
                .load_cgyy(CgyyQuery::LockCode, false)
                .await
                .expect("lock code");
            let CgyyData::LockCode(code) = outcome.data else {
                panic!("lock code projection")
            };
            assert_eq!(code.qr_code.as_deref(), password);
            assert_eq!(code.trade_no.as_deref(), trade);
        }
        let requests = transport.requests();
        assert_eq!(requests.len(), 2);
        assert!(requests
            .iter()
            .all(|request| request.url.contains("/api/orders/lock/code")));
    }
}

#[tokio::test]
async fn lock_code_expired_token_renews_only_once() {
    let mut responses = vec![expired_token()];
    responses.extend(token_renewal());
    responses.push(response(
        fixture("cgyy", "lock-code-normal-v1.json")["input"]["data"].clone(),
    ));
    let (service, transport) = service(responses);
    service
        .load_cgyy(CgyyQuery::LockCode, false)
        .await
        .expect("renewed lock code");
    assert_read_renewal_requests(&transport, 2);
}

fn response(data: Value) -> HttpResponse {
    HttpResponse::new(
        200,
        "https://cgyy.buaa.edu.cn/venue-zhjs-server/api/fixture",
        json!({"code":200,"data":data}).to_string(),
    )
}
fn booking() -> BookingRequest {
    BookingRequest {
        site_id: 1,
        date: "2026-10-25".into(),
        space_id: 1,
        time_ids: vec![1],
        phone: "13800000000".into(),
        theme: "合成活动".into(),
        purpose_type: 1,
        joiner_num: 2,
        activity_content: "合成测试".into(),
        joiners: "合成人员".into(),
        philosophy: false,
        off_school: false,
    }
}
fn day(free: bool) -> HttpResponse {
    response(
        json!({"spaceTimeInfo":[{"id":1,"beginTime":"08:00","endTime":"09:00"}],
        "reservationDateSpaceInfo":{"2026-10-25":[{"id":1,"spaceName":"合成空间","venueSpaceGroupId":2,"1":{"reservationStatus":if free {1} else {2}}}]},
        "token":"synthetic-reservation-token"}),
    )
}
fn service(
    responses: Vec<HttpResponse>,
) -> (SchoolClient<MockTransport, MemoryVault>, MockTransport) {
    let (service, transport) = build_service(responses, MemoryVault::default());
    service.set_authenticated(
        "synthetic".into(),
        UserProfile {
            school_id: "synthetic".into(),
            name: "合成".into(),
        },
    );
    service.identity.lock().cgyy_token = Some("synthetic-access-token".into());
    (service, transport)
}
fn challenge() -> HttpResponse {
    response(
        json!({"success":true,"repData":{"token":"synthetic-captcha-token","secretKey":"1234567890123456", "originalImageBase64":"AA==", "jigsawImageBase64":"AA=="}}),
    )
}
#[tokio::test]
async fn prepare_rechecks_availability_before_any_write() {
    let (service, transport) = service(vec![day(false)]);
    assert!(service
        .execute_cgyy(CgyyCommand::Prepare { booking: booking() })
        .await
        .is_err());
    assert_eq!(transport.request_count(), 1);
    assert!(transport
        .requests()
        .iter()
        .all(|r| r.method == HttpMethod::Get));
}
#[tokio::test]
async fn draft_uncertainty_never_replays_and_blocks_followup_submission() {
    let (service, transport) = service(vec![day(true), HttpResponse::new(503, "draft", "")]);
    let result = service
        .execute_cgyy(CgyyCommand::Prepare { booking: booking() })
        .await
        .expect("outcome");
    assert_eq!(result.state, "uncertain");
    let before = transport.request_count();
    assert_eq!(
        service
            .execute_cgyy(CgyyCommand::Prepare { booking: booking() })
            .await
            .expect("blocked")
            .state,
        "uncertain"
    );
    assert_eq!(before, transport.request_count());
    assert_eq!(
        transport
            .requests()
            .iter()
            .filter(|r| r.url.ends_with("/api/reservation/order/info"))
            .count(),
        1
    );
}
#[tokio::test]
async fn captcha_context_is_consumed_and_secrets_never_cross_bridge() {
    let (service, transport) = service(vec![
        day(true),
        response(json!({})),
        challenge(),
        response(json!({"success":true})),
        day(true),
        HttpResponse::new(503, "submit", ""),
    ]);
    let prepared = service
        .execute_cgyy(CgyyCommand::Prepare { booking: booking() })
        .await
        .expect("prepared");
    let public = serde_json::to_string(&prepared).expect("dto");
    for forbidden in [
        "synthetic-access-token",
        "synthetic-reservation-token",
        "synthetic-captcha-token",
        "1234567890123456",
        "13800000000",
    ] {
        assert!(!public.contains(forbidden));
    }
    let id = prepared.challenge.expect("challenge").id;
    let result = service
        .execute_cgyy(CgyyCommand::Submit {
            challenge_id: id.clone(),
            x: 100.0,
            width: None,
        })
        .await
        .expect("outcome");
    assert_eq!(result.state, "uncertain");
    let before = transport.request_count();
    assert_eq!(
        service
            .execute_cgyy(CgyyCommand::Submit {
                challenge_id: id,
                x: 100.0,
                width: None
            })
            .await
            .expect("blocked")
            .state,
        "uncertain"
    );
    assert_eq!(before, transport.request_count());
    let requests = transport.requests();
    let submit = requests
        .iter()
        .find(|r| r.url.ends_with("/api/reservation/order/submit"))
        .expect("submit");
    assert_eq!(submit.method, HttpMethod::Post);
    assert!(!submit.body.as_deref().expect("form").contains("nocache"));
    assert!(!submit.url.contains("13800000000"));
    assert!(submit.header_value("sign").is_some());
    assert!(requests.iter().all(|r| !r.url.contains("d.buaa.edu.cn")));
}
#[tokio::test]
async fn acknowledgement_requires_successful_order_readback() {
    let (service, _) = service(vec![HttpResponse::new(503, "orders", "")]);
    service
        .cgyy_safety
        .lock()
        .entry("synthetic".into())
        .or_default()
        .pending = true;
    assert!(service.execute_cgyy(CgyyCommand::Review).await.is_err());
    assert!(service
        .cgyy_safety
        .lock()
        .get("synthetic")
        .is_some_and(|s| s.pending));
}
#[tokio::test]
async fn rejected_captcha_never_submits_an_order() {
    let (service, transport) = service(vec![
        day(true),
        response(json!({})),
        challenge(),
        response(json!({"success":false})),
    ]);
    let id = service
        .execute_cgyy(CgyyCommand::Prepare { booking: booking() })
        .await
        .expect("prepared")
        .challenge
        .expect("challenge")
        .id;
    assert_eq!(
        service
            .execute_cgyy(CgyyCommand::Submit {
                challenge_id: id.clone(),
                x: 100.0,
                width: None
            })
            .await
            .expect("outcome")
            .state,
        "rejected"
    );
    assert!(service
        .execute_cgyy(CgyyCommand::Submit {
            challenge_id: id,
            x: 0.0,
            width: None
        })
        .await
        .is_err());
    assert!(transport
        .requests()
        .iter()
        .all(|r| !r.url.ends_with("/order/submit")));
}
#[tokio::test]
async fn acknowledged_submission_requires_matching_order_readback() {
    // Only a visible row with the same id *and* the requested reservation date
    // confirms the write; a bare id or a different date stays uncertain.
    for (row, expected) in [
        (
            json!({"id":9,"orderStatus":1,"reservationDate":"2026-10-25"}),
            "accepted",
        ),
        (json!({"id":9,"orderStatus":1}), "uncertain"),
        (
            json!({"id":9,"orderStatus":1,"reservationDate":"2026-10-26"}),
            "uncertain",
        ),
    ] {
        let (service, _) = service(vec![
            day(true),
            response(json!({})),
            challenge(),
            response(json!({"success":true})),
            day(true),
            response(json!({"orderInfo":{"id":9}})),
            response(json!({"content":[row]})),
        ]);
        let id = service
            .execute_cgyy(CgyyCommand::Prepare { booking: booking() })
            .await
            .expect("prepared")
            .challenge
            .expect("challenge")
            .id;
        assert_eq!(
            service
                .execute_cgyy(CgyyCommand::Submit {
                    challenge_id: id,
                    x: 100.0,
                    width: None
                })
                .await
                .expect("outcome")
                .state,
            expected
        );
        assert_eq!(
            !service
                .cgyy_safety
                .lock()
                .get("synthetic")
                .is_some_and(|s| s.pending),
            expected == "accepted"
        );
    }
}

#[tokio::test]
async fn changed_slots_after_manual_captcha_do_not_submit() {
    let (service, transport) = service(vec![
        day(true),
        response(json!({})),
        challenge(),
        response(json!({"success":true})),
        day(false),
    ]);
    let id = service
        .execute_cgyy(CgyyCommand::Prepare { booking: booking() })
        .await
        .expect("prepared")
        .challenge
        .expect("challenge")
        .id;
    let outcome = service
        .execute_cgyy(CgyyCommand::Submit {
            challenge_id: id,
            x: 100.0,
            width: None,
        })
        .await
        .expect("outcome");
    assert_eq!(outcome.state, "notSubmitted");
    assert!(transport
        .requests()
        .iter()
        .all(|r| !r.url.ends_with("/order/submit")));
}

#[tokio::test]
async fn uncertain_cancellation_sends_once_and_cannot_be_replayed() {
    let (service, transport) = service(vec![
        response(
            json!({"content":[{"id":9,"orderStatus":1,"checkStatus":0,"reservationStartDate":"2099-10-25 08:00:00"}]}),
        ),
        HttpResponse::new(503, "cancel", ""),
    ]);
    assert_eq!(
        service
            .execute_cgyy(CgyyCommand::Cancel { order_id: 9 })
            .await
            .expect("outcome")
            .state,
        "uncertain"
    );
    let before = transport.request_count();
    assert_eq!(
        service
            .execute_cgyy(CgyyCommand::Cancel { order_id: 9 })
            .await
            .expect("blocked")
            .state,
        "uncertain"
    );
    assert_eq!(before, transport.request_count());
    assert_eq!(
        transport
            .requests()
            .iter()
            .filter(|r| r.method == HttpMethod::Post)
            .count(),
        1
    );
}

fn mark_pending(service: &SchoolClient<MockTransport, MemoryVault>) {
    service
        .cgyy_safety
        .lock()
        .entry("synthetic".into())
        .or_default()
        .pending = true;
}
fn is_pending(service: &SchoolClient<MockTransport, MemoryVault>) -> bool {
    service
        .cgyy_safety
        .lock()
        .get("synthetic")
        .is_some_and(|s| s.pending)
}
fn seed_caches(service: &SchoolClient<MockTransport, MemoryVault>) {
    for key in ["orders:0:", "day:1:2026-10-25"] {
        service
            .snapshots
            .cgyy
            .lock()
            .insert(key.into(), CgyyData::Orders(vec![]));
    }
}
fn assert_caches_empty(service: &SchoolClient<MockTransport, MemoryVault>) {
    for key in ["orders:0:", "day:1:2026-10-25"] {
        assert!(service.snapshots.cgyy.lock().any(&key.into()).is_none());
    }
}
fn unknown_responses() -> Vec<HttpResponse> {
    vec![
        HttpResponse::new(200, "fixture", r#"{"code":500,"data":{}}"#),
        HttpResponse::new(200, "fixture", r#"{"code":777,"data":{}}"#),
        HttpResponse::new(200, "fixture", r#"{"code":401,"data":{}}"#),
        HttpResponse::new(401, "fixture", ""),
        HttpResponse::new(503, "fixture", ""),
        HttpResponse::new(200, "fixture", "malformed"),
        HttpResponse::new(200, "fixture", r#"{"code":200}"#),
    ]
}
#[tokio::test]
async fn all_unknown_draft_results_invalidate_queries_keep_lock_and_send_once() {
    for unknown in unknown_responses() {
        let (service, transport) = service(vec![day(true), unknown]);
        seed_caches(&service);
        let result = service
            .execute_cgyy(CgyyCommand::Prepare { booking: booking() })
            .await
            .expect("unknown");
        assert_eq!(result.state, "uncertain");
        assert!(is_pending(&service));
        assert_caches_empty(&service);
        assert_eq!(
            service
                .execute_cgyy(CgyyCommand::Status)
                .await
                .expect("status")
                .state,
            "uncertain"
        );
        assert_eq!(
            service
                .execute_cgyy(CgyyCommand::Cancel { order_id: 9 })
                .await
                .expect("blocked")
                .state,
            "uncertain"
        );
        assert_eq!(
            transport
                .requests()
                .iter()
                .filter(|r| r.method == HttpMethod::Post)
                .count(),
            1
        );
    }
}
#[tokio::test]
async fn all_unknown_submit_results_invalidate_queries_keep_lock_and_send_once() {
    for unknown in unknown_responses() {
        let (service, transport) = service(vec![
            day(true),
            response(json!({})),
            challenge(),
            response(json!({"success":true})),
            day(true),
            unknown,
        ]);
        let id = service
            .execute_cgyy(CgyyCommand::Prepare { booking: booking() })
            .await
            .expect("prepare")
            .challenge
            .expect("challenge")
            .id;
        seed_caches(&service);
        let result = service
            .execute_cgyy(CgyyCommand::Submit {
                challenge_id: id.clone(),
                x: 100.0,
                width: None,
            })
            .await
            .expect("unknown");
        assert_eq!(result.state, "uncertain");
        assert!(is_pending(&service));
        assert_caches_empty(&service);
        assert_eq!(
            service
                .execute_cgyy(CgyyCommand::Submit {
                    challenge_id: id,
                    x: 100.0,
                    width: None
                })
                .await
                .expect("blocked")
                .state,
            "uncertain"
        );
        assert_eq!(
            transport
                .requests()
                .iter()
                .filter(|r| r.url.ends_with("/order/submit"))
                .count(),
            1
        );
    }
}
#[tokio::test]
async fn all_unknown_cancel_results_invalidate_queries_keep_lock_and_send_once() {
    for unknown in unknown_responses() {
        let (service, transport) = service(vec![
            response(
                json!({"content":[{"id":9,"orderStatus":1,"checkStatus":0,"reservationStartDate":"2099-10-25 08:00:00"}]}),
            ),
            unknown,
        ]);
        seed_caches(&service);
        assert_eq!(
            service
                .execute_cgyy(CgyyCommand::Cancel { order_id: 9 })
                .await
                .expect("unknown")
                .state,
            "uncertain"
        );
        assert!(is_pending(&service));
        assert_caches_empty(&service);
        assert_eq!(
            service
                .execute_cgyy(CgyyCommand::Cancel { order_id: 9 })
                .await
                .expect("blocked")
                .state,
            "uncertain"
        );
        assert_eq!(
            transport
                .requests()
                .iter()
                .filter(|r| r.method == HttpMethod::Post)
                .count(),
            1
        );
    }
}
#[test]
fn acknowledgement_schema_requires_review_id() {
    assert!(serde_json::from_value::<CgyyCommand>(json!({"action":"acknowledge"})).is_err());
    assert!(serde_json::from_value::<CgyyCommand>(
        json!({"action":"acknowledge","review_id":"synthetic"})
    )
    .is_ok());
}
#[tokio::test]
async fn review_is_fresh_visible_sanitized_and_ack_is_local_single_use() {
    let (service, transport) = service(vec![response(
        json!({"content":[{"id":9,"orderStatus":1,"checkStatus":0,"token":"hidden-token","checkContent":"hidden-personal-text","phone":"13800000000"}]}),
    )]);
    mark_pending(&service);
    seed_caches(&service);
    let result = service
        .execute_cgyy(CgyyCommand::Review)
        .await
        .expect("review");
    assert_eq!(result.state, "reviewRequired");
    let dto = serde_json::to_string(&result).expect("dto");
    for secret in ["token", "hidden", "13800000000", "checkContent"] {
        assert!(!dto.contains(secret));
    }
    let review = result.review.expect("review");
    assert_eq!(review.orders[0].id, 9);
    assert!(is_pending(&service));
    assert_eq!(transport.request_count(), 1);
    assert!(service
        .execute_cgyy(CgyyCommand::Acknowledge {
            review_id: "fake".into()
        })
        .await
        .is_err());
    assert!(is_pending(&service));
    assert_eq!(
        service
            .execute_cgyy(CgyyCommand::Acknowledge {
                review_id: review.id.clone()
            })
            .await
            .expect("ack")
            .state,
        "reviewed"
    );
    assert!(!is_pending(&service));
    assert!(service
        .execute_cgyy(CgyyCommand::Acknowledge {
            review_id: review.id
        })
        .await
        .is_err());
    assert_eq!(transport.request_count(), 1);
}
#[tokio::test]
async fn latest_review_only_and_failed_refresh_revokes_previous_credential() {
    let (service, _) = service(vec![
        response(json!({"content":[]})),
        response(json!({"content":[]})),
        HttpResponse::new(503, "fixture", ""),
    ]);
    mark_pending(&service);
    let old = service
        .execute_cgyy(CgyyCommand::Review)
        .await
        .expect("review")
        .review
        .expect("review")
        .id;
    let latest = service
        .execute_cgyy(CgyyCommand::Review)
        .await
        .expect("review")
        .review
        .expect("review")
        .id;
    assert!(service
        .execute_cgyy(CgyyCommand::Acknowledge { review_id: old })
        .await
        .is_err());
    assert!(service.execute_cgyy(CgyyCommand::Review).await.is_err());
    assert!(service
        .execute_cgyy(CgyyCommand::Acknowledge { review_id: latest })
        .await
        .is_err());
    assert!(is_pending(&service));
}
#[tokio::test]
async fn expired_review_cannot_unlock() {
    let (service, _) = service(vec![response(json!({"content":[]}))]);
    mark_pending(&service);
    let id = service
        .execute_cgyy(CgyyCommand::Review)
        .await
        .expect("review")
        .review
        .expect("review")
        .id;
    service
        .cgyy_safety
        .lock()
        .get_mut("synthetic")
        .expect("safety")
        .review
        .as_mut()
        .expect("credential")
        .created = std::time::Instant::now() - std::time::Duration::from_secs(120);
    assert!(service
        .execute_cgyy(CgyyCommand::Acknowledge { review_id: id })
        .await
        .is_err());
    assert!(is_pending(&service));
}
fn authenticate<T: crate::foundation::http::HttpTransport + Send + Sync>(
    service: &SchoolClient<T, MemoryVault>,
    account: &str,
) {
    service.set_authenticated(
        account.into(),
        UserProfile {
            school_id: account.into(),
            name: "合成".into(),
        },
    );
    service.identity.lock().cgyy_token = Some("synthetic-access-token".into());
}
#[tokio::test]
async fn same_account_reauth_and_logout_preserve_pending_but_invalidate_review() {
    let (service, _) = service(vec![response(json!({"content":[]}))]);
    mark_pending(&service);
    let id = service
        .execute_cgyy(CgyyCommand::Review)
        .await
        .expect("review")
        .review
        .expect("review")
        .id;
    authenticate(&service, "synthetic");
    assert!(is_pending(&service));
    assert!(service
        .execute_cgyy(CgyyCommand::Acknowledge { review_id: id })
        .await
        .is_err());
    service.sign_out().await;
    authenticate(&service, "synthetic");
    assert_eq!(
        service
            .execute_cgyy(CgyyCommand::Status)
            .await
            .expect("status")
            .state,
        "uncertain"
    );
}
#[tokio::test]
async fn account_b_never_inherits_account_a_lock_or_review() {
    let (service, _) = service(vec![response(json!({"content":[]}))]);
    mark_pending(&service);
    let id = service
        .execute_cgyy(CgyyCommand::Review)
        .await
        .expect("review")
        .review
        .expect("review")
        .id;
    authenticate(&service, "synthetic-b");
    assert_eq!(
        service
            .execute_cgyy(CgyyCommand::Status)
            .await
            .expect("status")
            .state,
        "ready"
    );
    assert!(service
        .execute_cgyy(CgyyCommand::Acknowledge { review_id: id })
        .await
        .is_err());
    authenticate(&service, "synthetic");
    assert_eq!(
        service
            .execute_cgyy(CgyyCommand::Status)
            .await
            .expect("status")
            .state,
        "uncertain"
    );
}

#[derive(Clone)]
struct PausedTransport {
    inner: MockTransport,
    suffix: &'static str,
    entered: std::sync::Arc<tokio::sync::Notify>,
    resume: std::sync::Arc<tokio::sync::Notify>,
}
impl crate::foundation::http::HttpTransport for PausedTransport {
    async fn send(&self, request: HttpRequest) -> Result<HttpResponse, TransportError> {
        let paused = request
            .url
            .split('?')
            .next()
            .is_some_and(|url| url.ends_with(self.suffix));
        let response = self.inner.send(request).await;
        if paused {
            self.entered.notify_one();
            self.resume.notified().await;
        }
        response
    }
}
fn paused_service(
    responses: Vec<HttpResponse>,
    suffix: &'static str,
) -> (SchoolClient<PausedTransport, MemoryVault>, PausedTransport) {
    let transport = PausedTransport {
        inner: MockTransport::with_responses(responses),
        suffix,
        entered: Default::default(),
        resume: Default::default(),
    };
    let service = SchoolClient::new(
        crate::auth::session::Session::new(transport.clone()),
        MemoryVault::default(),
    );
    authenticate(&service, "synthetic");
    (service, transport)
}
#[tokio::test]
async fn identity_change_during_draft_cannot_publish_challenge_or_clear_original_pending() {
    let (service, transport) = paused_service(
        vec![day(true), response(json!({})), challenge()],
        "/captcha/get",
    );
    let (result, ()) = tokio::join!(
        service.execute_cgyy(CgyyCommand::Prepare { booking: booking() }),
        async {
            transport.entered.notified().await;
            authenticate(&service, "synthetic-b");
            transport.resume.notify_one();
        }
    );
    assert!(result.is_err());
    assert!(service.identity.lock().cgyy_booking.is_none());
    assert!(
        service
            .cgyy_safety
            .lock()
            .get("synthetic")
            .expect("pending A")
            .pending
    );
    assert_eq!(
        service
            .execute_cgyy(CgyyCommand::Status)
            .await
            .expect("B status")
            .state,
        "ready"
    );
}
#[tokio::test]
async fn identity_change_during_review_does_not_mint_credential_for_new_account() {
    let (service, transport) =
        paused_service(vec![response(json!({"content":[]}))], "/orders/mine");
    service
        .cgyy_safety
        .lock()
        .entry("synthetic".into())
        .or_default()
        .pending = true;
    let (result, ()) = tokio::join!(service.execute_cgyy(CgyyCommand::Review), async {
        transport.entered.notified().await;
        authenticate(&service, "synthetic-b");
        transport.resume.notify_one();
    });
    assert!(result.is_err());
    assert!(service.cgyy_safety.lock().get("synthetic-b").is_none());
    let safety = service.cgyy_safety.lock();
    let original = safety.get("synthetic").expect("A safety");
    assert!(original.pending && original.review.is_none());
}
#[tokio::test]
async fn identity_change_during_cancel_precheck_sends_no_post() {
    let (service, transport) = paused_service(
        vec![response(
            json!({"content":[{"id":9,"orderStatus":1,"checkStatus":0,"reservationStartDate":"2099-10-25 08:00:00"}]}),
        )],
        "/orders/mine",
    );
    let (result, ()) = tokio::join!(
        service.execute_cgyy(CgyyCommand::Cancel { order_id: 9 }),
        async {
            transport.entered.notified().await;
            authenticate(&service, "synthetic-b");
            transport.resume.notify_one();
        }
    );
    assert!(result.is_err());
    assert!(transport
        .inner
        .requests()
        .iter()
        .all(|r| r.method == HttpMethod::Get));
}
#[tokio::test]
async fn identity_change_during_submit_preserves_original_pending_and_does_not_readback_as_b() {
    let (service, transport) = paused_service(
        vec![
            day(true),
            response(json!({})),
            challenge(),
            response(json!({"success":true})),
            day(true),
            response(json!({"orderInfo":{"id":9}})),
        ],
        "/order/submit",
    );
    let id = service
        .execute_cgyy(CgyyCommand::Prepare { booking: booking() })
        .await
        .expect("prepare")
        .challenge
        .expect("challenge")
        .id;
    let (result, ()) = tokio::join!(
        service.execute_cgyy(CgyyCommand::Submit {
            challenge_id: id,
            x: 100.0,
            width: None
        }),
        async {
            transport.entered.notified().await;
            authenticate(&service, "synthetic-b");
            transport.resume.notify_one();
        }
    );
    assert!(result.is_err());
    assert!(
        service
            .cgyy_safety
            .lock()
            .get("synthetic")
            .expect("A safety")
            .pending
    );
    assert_eq!(transport.inner.request_count(), 6);
    assert_eq!(
        service
            .execute_cgyy(CgyyCommand::Status)
            .await
            .expect("B status")
            .state,
        "ready"
    );
}
#[tokio::test]
async fn service_single_flight_refuses_second_command_without_replaying_write() {
    let (service, transport) = paused_service(
        vec![day(true), response(json!({})), challenge()],
        "/order/info",
    );
    let (result, ()) = tokio::join!(
        service.execute_cgyy(CgyyCommand::Prepare { booking: booking() }),
        async {
            transport.entered.notified().await;
            assert!(service
                .execute_cgyy(CgyyCommand::Prepare { booking: booking() })
                .await
                .is_err());
            assert_eq!(transport.inner.request_count(), 2);
            transport.resume.notify_one();
        }
    );
    assert_eq!(result.expect("first request").state, "challenge");
    assert_eq!(
        transport
            .inner
            .requests()
            .iter()
            .filter(|r| r.method == HttpMethod::Post)
            .count(),
        1
    );
}
#[tokio::test]
async fn dropped_inflight_write_keeps_pending_and_invalidates_caches() {
    let (service, transport) = paused_service(vec![day(true), response(json!({}))], "/order/info");
    let mut request = Box::pin(service.execute_cgyy(CgyyCommand::Prepare { booking: booking() }));
    tokio::select! { _ = &mut request => panic!("request should pause"), _ = transport.entered.notified() => {} }
    drop(request);
    assert!(
        service
            .cgyy_safety
            .lock()
            .get("synthetic")
            .expect("A safety")
            .pending
    );
    assert_eq!(
        service
            .execute_cgyy(CgyyCommand::Status)
            .await
            .expect("status")
            .state,
        "uncertain"
    );
    assert_eq!(transport.inner.request_count(), 2);
}
#[tokio::test]
async fn unknown_cancel_approval_never_sends_write() {
    let (service, transport) = service(vec![response(
        json!({"content":[{"id":9,"orderStatus":1,"checkStatus":99,"reservationStartDate":"2099-10-25 08:00:00"}]}),
    )]);
    assert_eq!(
        service
            .execute_cgyy(CgyyCommand::Cancel { order_id: 9 })
            .await
            .expect("unknown approval")
            .state,
        "notSubmitted"
    );
    assert!(transport
        .requests()
        .iter()
        .all(|r| r.method == HttpMethod::Get));
}
#[tokio::test]
async fn missing_cancel_approval_never_sends_write() {
    let (service, transport) = service(vec![response(
        json!({"content":[{"id":9,"orderStatus":1,"reservationStartDate":"2099-10-25 08:00:00"}]}),
    )]);
    assert_eq!(
        service
            .execute_cgyy(CgyyCommand::Cancel { order_id: 9 })
            .await
            .expect("local rejection")
            .state,
        "notSubmitted"
    );
    assert!(transport
        .requests()
        .iter()
        .all(|r| r.method == HttpMethod::Get));
}
#[tokio::test]
async fn silent_same_account_reauth_preserves_pending_and_invalidates_review() {
    let mut responses = vec![response(json!({"content":[]}))];
    responses.extend(login_chain("synthetic", "合成"));
    let (service, _) = service(responses);
    service
        .vault
        .save("synthetic", &credentials("synthetic"))
        .expect("vault");
    mark_pending(&service);
    let id = service
        .execute_cgyy(CgyyCommand::Review)
        .await
        .expect("review")
        .review
        .expect("review")
        .id;
    service.silent_login().await.expect("synthetic reauth");
    assert!(is_pending(&service));
    assert!(service
        .execute_cgyy(CgyyCommand::Acknowledge { review_id: id })
        .await
        .is_err());
}
#[tokio::test]
async fn stale_cgyy_login_cannot_publish_token_into_new_identity() {
    let (service, transport) = paused_service(
        vec![
            HttpResponse::new(
                200,
                "https://cgyy.buaa.edu.cn/venue-zhjs-server/sso/manageLogin",
                "ok",
            )
            .with_set_cookie("sso_buaa_zhjs_token=synthetic-sso; Path=/; Secure"),
            response(json!({"token":{"access_token":"old-account-token"}})),
        ],
        "/api/login",
    );
    service.identity.lock().cgyy_token = None;
    let (result, ()) = tokio::join!(service.execute_cgyy(CgyyCommand::Review), async {
        transport.entered.notified().await;
        authenticate(&service, "synthetic-b");
        transport.resume.notify_one();
    });
    assert!(result.is_err());
    assert_eq!(
        service.identity.lock().cgyy_token.as_deref(),
        Some("synthetic-access-token")
    );
    assert_eq!(transport.inner.request_count(), 2);
}
#[test]
fn order_projection_is_conservative_and_omits_personal_approval_text() {
    let mut row = json!({"id":9,"orderStatus":1,"checkStatus":0,"reservationStartDate":"2099-10-25 08:00:00","checkContent":"personal-text"});
    for (status, check, date, allowed) in [
        (json!(1), json!(0), "2099-10-25 08:00:00", true),
        (json!(3), json!(1), "2099-10-25 08:00:00", true),
        (json!(2), json!(0), "2099-10-25 08:00:00", false),
        (json!(1), json!(-1), "2099-10-25 08:00:00", false),
        (json!(1), Value::Null, "2099-10-25 08:00:00", false),
        (json!(1), json!(99), "2099-10-25 08:00:00", false),
        (Value::Null, json!(0), "2099-10-25 08:00:00", false),
        (json!(1), json!(0), "2000-10-25 08:00:00", false),
        (json!(1), json!(0), "malformed", false),
    ] {
        row["orderStatus"] = status.clone();
        row["checkStatus"] = check.clone();
        row["reservationStartDate"] = json!(date);
        let orders =
            crate::codecs::cgyy::orders(&json!({"code":200,"data":{"content":[row.clone()]}}))
                .expect("projection");
        assert_eq!(orders[0].can_cancel, allowed);
        assert_eq!(orders[0].order_status, status.as_i64());
        assert_eq!(orders[0].check_status, check.as_i64());
        assert!(!serde_json::to_string(&orders)
            .expect("dto")
            .contains("personal-text"));
    }
}
#[tokio::test]
async fn transport_failure_after_draft_dispatch_is_unknown_and_never_retried() {
    let transport =
        MockTransport::with_results(vec![Ok(day(true)), Err(TransportError::Unavailable)]);
    let service = SchoolClient::new(
        crate::auth::session::Session::new(transport.clone()),
        MemoryVault::default(),
    );
    authenticate(&service, "synthetic");
    seed_caches(&service);
    assert_eq!(
        service
            .execute_cgyy(CgyyCommand::Prepare { booking: booking() })
            .await
            .expect("unknown")
            .state,
        "uncertain"
    );
    assert!(is_pending(&service));
    assert_caches_empty(&service);
    assert_eq!(transport.request_count(), 2);
    assert_eq!(
        transport
            .requests()
            .iter()
            .filter(|r| r.method == HttpMethod::Post)
            .count(),
        1
    );
}
#[tokio::test]
async fn unknown_submit_readback_never_unlocks_or_claims_approval() {
    for last in [
        HttpResponse::new(503, "fixture", ""),
        response(json!({"content":[{"id":10,"orderStatus":1}]})),
        response(json!({"content":[{}]})),
    ] {
        let (service, transport) = service(vec![
            day(true),
            response(json!({})),
            challenge(),
            response(json!({"success":true})),
            day(true),
            response(json!({"orderInfo":{"id":9}})),
            last,
        ]);
        let id = service
            .execute_cgyy(CgyyCommand::Prepare { booking: booking() })
            .await
            .expect("prepare")
            .challenge
            .expect("challenge")
            .id;
        seed_caches(&service);
        let result = service
            .execute_cgyy(CgyyCommand::Submit {
                challenge_id: id,
                x: 100.0,
                width: None,
            })
            .await
            .expect("unknown");
        assert_eq!(result.state, "uncertain");
        assert!(!result.message.contains("成功"));
        assert!(is_pending(&service));
        assert_caches_empty(&service);
        assert_eq!(
            transport
                .requests()
                .iter()
                .filter(|r| r.url.ends_with("/order/submit"))
                .count(),
            1
        );
    }
}
#[tokio::test]
async fn unknown_captcha_response_preserves_protection_without_order_submit() {
    for last in [
        response(json!({})),
        HttpResponse::new(200, "fixture", r#"{"code":500,"data":{}}"#),
        HttpResponse::new(503, "fixture", ""),
    ] {
        let (service, transport) = service(vec![day(true), response(json!({})), challenge(), last]);
        let id = service
            .execute_cgyy(CgyyCommand::Prepare { booking: booking() })
            .await
            .expect("prepare")
            .challenge
            .expect("challenge")
            .id;
        seed_caches(&service);
        assert_eq!(
            service
                .execute_cgyy(CgyyCommand::Submit {
                    challenge_id: id,
                    x: 100.0,
                    width: None
                })
                .await
                .expect("unknown")
                .state,
            "uncertain"
        );
        assert!(is_pending(&service));
        assert_caches_empty(&service);
        assert!(transport
            .requests()
            .iter()
            .all(|r| !r.url.ends_with("/order/submit")));
    }
}
#[tokio::test]
async fn later_unknown_write_invalidates_older_successful_review_credential() {
    let (service, _) = service(vec![
        response(json!({"content":[]})),
        day(true),
        HttpResponse::new(503, "fixture", ""),
    ]);
    let old = service
        .execute_cgyy(CgyyCommand::Review)
        .await
        .expect("review")
        .review
        .expect("review")
        .id;
    assert_eq!(
        service
            .execute_cgyy(CgyyCommand::Prepare { booking: booking() })
            .await
            .expect("unknown")
            .state,
        "uncertain"
    );
    assert!(service
        .execute_cgyy(CgyyCommand::Acknowledge { review_id: old })
        .await
        .is_err());
    assert!(is_pending(&service));
}
fn day_announcing(week: Value, group: Value) -> HttpResponse {
    let mut row = json!({"id":1,"spaceName":"合成空间","1":{"reservationStatus":1}});
    if let Some(group) = group.as_i64() {
        row["venueSpaceGroupId"] = json!(group);
    }
    response(json!({
        "spaceTimeInfo":[{"id":1,"beginTime":"08:00","endTime":"09:00"}],
        "reservationDateSpaceInfo":{"2026-10-25":[row]},
        "reservationDateList":week,
        "token":"synthetic-reservation-token"
    }))
}
fn form_field(request: &HttpRequest, key: &str) -> Option<String> {
    url::form_urlencoded::parse(request.body.as_deref().unwrap_or_default().as_bytes())
        .find(|(name, _)| name == key)
        .map(|(_, value)| value.into_owned())
}
#[tokio::test]
async fn draft_takes_week_start_from_the_day_response_and_signs_the_same_json() {
    // The day response advertises a week starting 2026-10-19 while the booking
    // itself is for 2026-10-25: the form must carry the advertised anchor.
    let (announced, announced_transport) = service(vec![
        day_announcing(json!(["2026-10-19"]), json!(2)),
        response(json!({"tradeNo":"synthetic-trade"})),
        challenge(),
    ]);
    announced
        .execute_cgyy(CgyyCommand::Prepare { booking: booking() })
        .await
        .expect("prepared");
    let draft = announced_transport
        .requests()
        .into_iter()
        .find(|r| r.url.ends_with("/api/reservation/order/info"))
        .expect("draft");
    assert_eq!(
        form_field(&draft, "weekStartDate").as_deref(),
        Some("2026-10-19")
    );
    assert_eq!(
        form_field(&draft, "reservationDate").as_deref(),
        Some("2026-10-25")
    );
    assert_eq!(
        form_field(&draft, "token").as_deref(),
        Some("synthetic-reservation-token")
    );
    // Explicit-null group survives as literal JSON, not as an omitted key.
    assert_eq!(
        form_field(&draft, "reservationOrderJson").as_deref(),
        Some("[{\"spaceId\":1,\"timeId\":1,\"venueSpaceGroupId\":2}]")
    );
    let (bare, bare_transport) = service(vec![
        day_announcing(json!({}), json!(Value::Null)),
        response(json!({})),
        challenge(),
    ]);
    bare.execute_cgyy(CgyyCommand::Prepare { booking: booking() })
        .await
        .expect("prepared");
    let draft = bare_transport
        .requests()
        .into_iter()
        .find(|r| r.url.ends_with("/api/reservation/order/info"))
        .expect("draft");
    // No advertised week start -> the field is omitted, never the query date.
    assert_eq!(form_field(&draft, "weekStartDate"), None);
    assert_eq!(
        form_field(&draft, "reservationOrderJson").as_deref(),
        Some("[{\"spaceId\":1,\"timeId\":1,\"venueSpaceGroupId\":null}]")
    );
}
#[tokio::test]
async fn rotated_day_token_after_captcha_stops_before_any_submit() {
    let (service, transport) = service(vec![
        day(true),
        response(json!({})),
        challenge(),
        response(json!({"success":true})),
        // Re-check rotates the day order token instead of confirming the chain.
        response(json!({
            "spaceTimeInfo":[{"id":1,"beginTime":"08:00","endTime":"09:00"}],
            "reservationDateSpaceInfo":{"2026-10-25":[{"id":1,"spaceName":"合成空间","venueSpaceGroupId":2,"1":{"reservationStatus":1}}]},
            "token":"rotated-day-token"
        })),
    ]);
    let id = service
        .execute_cgyy(CgyyCommand::Prepare { booking: booking() })
        .await
        .expect("prepared")
        .challenge
        .expect("challenge")
        .id;
    let outcome = service
        .execute_cgyy(CgyyCommand::Submit {
            challenge_id: id,
            x: 100.0,
            width: Some(320.0),
        })
        .await
        .expect("outcome");
    assert_eq!(outcome.state, "notSubmitted");
    assert!(transport
        .requests()
        .iter()
        .all(|r| !r.url.ends_with("/order/submit")));
    // No write happened, so the local protection is released.
    assert!(!is_pending(&service));
}
#[tokio::test]
async fn orders_are_read_as_bounded_official_pages() {
    let row = |id: i64| json!({"id":id,"orderStatus":1,"reservationDate":"2026-10-25"});
    let page = |ids: Vec<i64>, total: i64| {
        response(json!({
            "content": ids.into_iter().map(row).collect::<Vec<_>>(),
            "totalElements": total
        }))
    };
    let (service, transport) = service(vec![
        page(vec![1, 2, 3, 4, 5], 11),
        page(vec![6, 7, 8, 9, 10], 11),
        page(vec![11], 11),
    ]);
    mark_pending(&service);
    let review = service
        .execute_cgyy(CgyyCommand::Review)
        .await
        .expect("review")
        .review
        .expect("review");
    assert_eq!(review.orders.len(), 11);
    let requests = transport.requests();
    let pages: Vec<String> = requests
        .iter()
        .filter(|r| r.url.contains("/api/orders/mine"))
        .map(|r| {
            url::form_urlencoded::parse(r.url.split_once('?').expect("query").1.as_bytes())
                .filter(|(name, _)| name == "page" || name == "size")
                .map(|(name, value)| format!("{name}={value}"))
                .collect::<Vec<_>>()
                .join("&")
        })
        .collect();
    // Official first request is page 0 / size 5; paging stops at totalElements.
    assert_eq!(pages, ["page=0&size=5", "page=1&size=5", "page=2&size=5"]);
}
#[tokio::test]
async fn repeated_order_id_between_pages_stops_the_walk_without_duplicates() {
    let row = |id: i64| json!({"id":id,"orderStatus":1,"reservationDate":"2026-10-25"});
    let first: Vec<Value> = [1, 2, 3, 4, 5].into_iter().map(row).collect();
    let second: Vec<Value> = [5, 6].into_iter().map(row).collect();
    let (service, transport) = service(vec![
        response(json!({"content": first})),
        // The server re-sorted: the first row of page 1 repeats page 0's last id.
        response(json!({"content": second})),
    ]);
    mark_pending(&service);
    let review = service
        .execute_cgyy(CgyyCommand::Review)
        .await
        .expect("review")
        .review
        .expect("review");
    let ids: Vec<i64> = review.orders.iter().map(|o| o.id).collect();
    assert_eq!(ids, [1, 2, 3, 4, 5]);
    assert_eq!(transport.request_count(), 2);
}
#[tokio::test]
async fn readback_trade_number_narrows_but_never_invents_an_acknowledgement() {
    // The draft names trade T1. Only a visible row with the same id, the same
    // reservation date and the same trade number may be called accepted.
    for (trade, expected) in [("T1", "accepted"), ("T2", "uncertain"), ("", "accepted")] {
        let mut row = json!({"id":9,"orderStatus":1,"reservationDate":"2026-10-25"});
        if !trade.is_empty() {
            row["tradeNo"] = json!(trade);
        }
        let (service, _) = service(vec![
            day(true),
            response(json!({"tradeNo":"T1"})),
            challenge(),
            response(json!({"success":true})),
            day(true),
            response(json!({"orderInfo":{"id":9}})),
            response(json!({"content":[row]})),
        ]);
        let id = service
            .execute_cgyy(CgyyCommand::Prepare { booking: booking() })
            .await
            .expect("prepared")
            .challenge
            .expect("challenge")
            .id;
        assert_eq!(
            service
                .execute_cgyy(CgyyCommand::Submit {
                    challenge_id: id,
                    x: 100.0,
                    width: None
                })
                .await
                .expect("outcome")
                .state,
            expected,
            "trade {trade}"
        );
    }
}
