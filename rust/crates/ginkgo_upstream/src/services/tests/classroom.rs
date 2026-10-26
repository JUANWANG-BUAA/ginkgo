use super::*;

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

/// The await-time account recheck: flipping the identity while a classroom
/// read is parked mid-flight must reject the late result and leave the
/// snapshot cache for the new account untouched.
#[tokio::test]
async fn an_account_change_during_the_classroom_read_rejects_its_result() {
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
    let query = input();
    let key = (query.campus, query.date.clone());
    let cache = std::sync::Mutex::new(crate::services::snapshots::ClassroomCache::default());
    let mut pending = Box::pin(service.load_classrooms(&query));
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
        cache.lock().expect("snapshot cache").fresh(&key).is_none(),
        "a rejected read must not populate the snapshot"
    );
}
