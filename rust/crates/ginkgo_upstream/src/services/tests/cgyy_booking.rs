use super::*;
use ginkgo_domain::features::cgyy_booking::{BookingRequest, CgyyCommand};
use serde_json::json;

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
            x: 100,
        })
        .await
        .expect("outcome");
    assert_eq!(result.state, "uncertain");
    let before = transport.request_count();
    assert_eq!(
        service
            .execute_cgyy(CgyyCommand::Submit {
                challenge_id: id,
                x: 100
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
    service.identity.lock().cgyy_review_required = true;
    assert!(service
        .execute_cgyy(CgyyCommand::Acknowledge)
        .await
        .is_err());
    assert!(service.identity.lock().cgyy_review_required);
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
                x: 0
            })
            .await
            .expect("outcome")
            .state,
        "rejected"
    );
    assert!(service
        .execute_cgyy(CgyyCommand::Submit {
            challenge_id: id,
            x: 0
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
    let (service, _) = service(vec![
        day(true),
        response(json!({})),
        challenge(),
        response(json!({"success":true})),
        day(true),
        response(json!({"orderInfo":{"id":9}})),
        response(json!({"content":[{"id":9,"orderStatus":1}]})),
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
                x: 100
            })
            .await
            .expect("outcome")
            .state,
        "accepted"
    );
    assert!(!service.identity.lock().cgyy_review_required);
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
            x: 100,
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
            json!({"content":[{"id":9,"orderStatus":1,"reservationStartDate":"2099-10-25 08:00:00"}]}),
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
