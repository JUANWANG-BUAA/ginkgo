use super::*;

fn calendar_body() -> String {
    serde_json::json!({
        "state": 1,
        "data": [{
            "id": "career-1",
            "title": "合成专场宣讲会",
            "campus": "学院路校区",
            "field": "主楼101",
            "startTime": "2026-10-28 14:00:00",
            "endTime": "2026-10-28 15:30:00",
            "fairTypeName": "线下宣讲会",
            "status": "1",
            "url": "/f/recruitmentFair/show?recruitmentFairId=career-1"
        }]
    })
    .to_string()
}

fn career_response(status: u16, body: &str) -> HttpResponse {
    HttpResponse::new(
        status,
        "https://career.buaa.edu.cn/f/recruitmentFair/ajax_calendar_list?time=2026-10",
        body,
    )
}

#[tokio::test]
async fn career_events_cache_and_failure_preserves_old_snapshot() {
    let responses = vec![
        HttpResponse::new(200, "https://sso.buaa.edu.cn/session", "seed")
            .with_set_cookie("CASTGC=synthetic-account; Domain=buaa.edu.cn; Path=/; Secure"),
        career_response(200, &calendar_body())
            .with_set_cookie("public-session=synthetic; Domain=buaa.edu.cn; Path=/; Secure"),
        career_response(503, "unavailable"),
        career_response(200, &calendar_body()),
    ];
    let (service, transport) = build_service(responses, MemoryVault::default());
    service
        .session
        .send_direct(HttpRequest::get("https://sso.buaa.edu.cn/session"))
        .await
        .expect("seed parent-domain login cookie");
    let first = service
        .load_career_events("2026-10", false)
        .await
        .expect("calendar");
    assert!(first.failure.is_none());
    assert_eq!(first.data.events.len(), 1);
    assert_eq!(first.data.events[0].campus, "学院路校区");
    assert_eq!(
        first.data.events[0].url,
        "https://career.buaa.edu.cn/f/recruitmentFair/show?recruitmentFairId=career-1"
    );
    let requests = transport.requests();
    assert_eq!(requests.len(), 2);
    assert_eq!(requests[1].header_value("cookie"), None);
    let count = transport.request_count();
    let cached = service
        .load_career_events("2026-10", false)
        .await
        .expect("cache");
    assert!(cached.failure.is_none());
    assert_eq!(transport.request_count(), count);
    assert_eq!(cached.data, first.data);

    let stale = service
        .load_career_events("2026-10", true)
        .await
        .expect("stale");
    assert!(stale.failure.is_some());
    assert_eq!(stale.data.events.len(), 1);
    assert_eq!(stale.data.fetched_at, cached.data.fetched_at);

    let fresh = service
        .load_career_events("2026-10", true)
        .await
        .expect("refresh");
    assert!(fresh.failure.is_none());
    assert_eq!(fresh.data.events.len(), 1);
}

#[tokio::test]
async fn career_events_empty_and_changed_responses_are_distinct() {
    let empty = serde_json::json!({"state": 1, "data": []}).to_string();
    let (service, _) = build_service(
        vec![
            career_response(200, &empty),
            career_response(200, "{\"state\":0}"),
        ],
        MemoryVault::default(),
    );
    let first = service
        .load_career_events("2026-10", false)
        .await
        .expect("empty success");
    assert!(first.failure.is_none());
    assert!(first.data.events.is_empty());
    let changed = service
        .load_career_events("2026-10", true)
        .await
        .expect("failure preserves old success-empty snapshot");
    assert_eq!(
        changed.failure.map(|error| error.code),
        Some(ErrorCode::ChangedResponse)
    );
    assert!(changed.data.events.is_empty());
}
