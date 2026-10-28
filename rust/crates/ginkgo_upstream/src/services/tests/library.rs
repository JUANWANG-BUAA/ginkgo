use super::*;

#[tokio::test]
async fn an_expired_library_token_is_rebuilt_once_and_the_read_recovers() {
    let mut responses = login_chain("sy2501001", "fixture");
    responses.extend([
        library_login_redirect(),
        library_token_response(),
        // The first read meets an expired business token.
        HttpResponse::new(
            200,
            "https://booking.lib.buaa.edu.cn/v4/space/pcTopFor",
            serde_json::json!({"code": 0, "message": "登录失效，请重新登录"}).to_string(),
        ),
        // The rejected token is rebuilt once, then the retry succeeds.
        library_login_redirect(),
        library_token_response(),
        library_body("space/pcTopFor"),
    ]);
    let (service, transport) = build_service(responses, MemoryVault::default());
    service
        .sign_in("sy2501001", "pa+ss/word", None, true)
        .await
        .expect("signed in");

    let venues = service
        .load_library_venues(false)
        .await
        .expect("venues recover");
    assert_eq!(venues.venues.len(), 2);
    assert!(!venues.from_cache);
    let logins = transport
        .requests()
        .iter()
        .filter(|request| request.url.contains("/v4/login/user"))
        .count();
    assert_eq!(logins, 2, "a rejected token is rebuilt exactly once");
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
    service.identity.lock().library_token = None;
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
    let service = SchoolClient::new(
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
async fn library_write_failure_is_not_replayed_or_route_switched() {
    use crate::{
        adapters::library_http,
        auth::session::{RouteMode, Session},
        codecs::mutation::MutationState,
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
    use crate::codecs::{library::LibrarySlot, mutation::MutationState};
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
    use crate::codecs::mutation::MutationState;
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

/// The await-time account recheck: a library read parked mid-flight must
/// reject its result after the identity flips, leaving the venues snapshot
/// (keyed by the service's VENUES_KEY) for the new account untouched.
#[tokio::test]
async fn an_account_change_during_the_library_venues_read_rejects_its_result() {
    use std::future::Future as _;
    let (transport, gate) = GatedTransport::gated();
    let service = SchoolClient::new(
        crate::auth::session::Session::new(transport),
        MemoryVault::default(),
    );
    service.set_authenticated(
        "sy2501001".into(),
        UserProfile {
            school_id: "sy2501001".into(),
            name: "synthetic".into(),
        },
    );
    let cache = std::sync::Mutex::new(crate::services::snapshots::LibraryVenueCache::default());
    let mut pending = Box::pin(service.load_library_venues(false));
    assert!(
        std::future::poll_fn(|cx| std::task::Poll::Ready(pending.as_mut().poll(cx)))
            .await
            .is_pending(),
        "the gated transport must hold the read open"
    );
    service.set_authenticated(
        "sy2501002".into(),
        UserProfile {
            school_id: "sy2501002".into(),
            name: "other".into(),
        },
    );
    gate.send_replace(true);
    let error = pending
        .await
        .expect_err("a late read must not cross accounts");
    assert_eq!(error.code, ErrorCode::SessionExpired);
    assert!(
        cache
            .lock()
            .expect("snapshot cache")
            .fresh(&"venues".to_owned())
            .is_none(),
        "a rejected read must not populate the venues snapshot"
    );
}

/// The write ports bind to one identity on their own, so the isolation rule no
/// longer depends on the FFI layer holding a shared gate.
#[tokio::test]
async fn library_writes_reject_an_account_switch_before_dispatch() {
    use crate::codecs::{library::LibrarySlot, mutation::MutationState};
    let mut responses = login_chain("sy2501001", "fixture");
    responses.extend([
        library_login_redirect(),
        library_token_response(),
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

    // With no interleaving this is a normal accepted write; the rechecks make
    // a switch produce a refusal instead of a silent cross-account write.
    assert_eq!(outcome.state, MutationState::Accepted);
    let writes = transport
        .requests()
        .into_iter()
        .filter(|r| r.url.ends_with("space/confirm"))
        .count();
    assert_eq!(writes, 1);

    // After a sign-out the same port refuses before any school request.
    let before = transport.request_count();
    service.sign_out().await;
    let refused = service
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
    assert_eq!(refused.state, MutationState::NotSubmitted);
    assert_eq!(
        transport.request_count(),
        before,
        "a switched account must never reach the school write endpoint"
    );

    let action = service.perform_library_action("b1", "cancel").await;
    assert_eq!(action.state, MutationState::NotSubmitted);
    assert_eq!(transport.request_count(), before);
}
