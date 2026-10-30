use super::*;

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
    let catalog = crate::codecs::bykc::parse_catalog(
        &fixture["input"]["config"],
        fixture["input"]["pages"].as_array().expect("pages"),
    )
    .expect("catalog");
    service
        .snapshots
        .bykc
        .lock()
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
    use crate::codecs::bykc;
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
        .snapshots
        .bykc
        .lock()
        .insert("catalog".into(), catalog);
    service
        .snapshots
        .bykc_chosen
        .lock()
        .insert("chosen".into(), chosen);
    service
        .snapshots
        .bykc_statistics
        .lock()
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
    use crate::codecs::bykc;
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
        .snapshots
        .bykc_chosen
        .lock()
        .insert("chosen".into(), chosen);
    service
        .snapshots
        .bykc_statistics
        .lock()
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
        .snapshots
        .bykc_chosen
        .lock()
        .any(&"chosen".into())
        .is_none());
    assert!(service
        .snapshots
        .bykc_statistics
        .lock()
        .any(&"statistics".into())
        .is_none());
    service.sign_out().await;
    assert!(service.load_bykc_chosen(false).await.is_err());
    assert!(service.load_bykc_statistics(false).await.is_err());
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
            HttpResponse::new(200, "https://sso.buaa.edu.cn/session", "seed")
                .with_set_cookie("CASTGC=synthetic-account; Domain=buaa.edu.cn; Path=/; Secure"),
            HttpResponse::new(200, url, body)
                .with_set_cookie("public-session=synthetic; Domain=buaa.edu.cn; Path=/; Secure"),
            HttpResponse::new(200, url, "<html>changed</html>"),
        ],
        MemoryVault::default(),
    );
    service
        .session
        .send_direct(HttpRequest::get("https://sso.buaa.edu.cn/session"))
        .await
        .expect("seed parent-domain login cookie");
    assert_eq!(service.load_notices(false).await.unwrap().data.len(), 1);
    assert_eq!(service.load_notices(false).await.unwrap().data.len(), 1);
    assert_eq!(transport.request_count(), 2);
    let requests = transport.requests();
    assert_eq!(requests[1].header_value("cookie"), None);
    let stale = service.load_notices(true).await.unwrap();
    assert_eq!(stale.data[0].title, "合成校园通知");
    assert_eq!(stale.failure.unwrap().code, ErrorCode::ChangedResponse);
}

#[tokio::test]
async fn notices_stay_direct_when_the_session_route_switched_to_webvpn() {
    let body = fixture("notices", "normal-v1.json")["input"]["html"]
        .as_str()
        .unwrap()
        .to_owned();
    let url = "https://news.buaa.edu.cn/tzgg.htm";
    let (service, transport) = build_service(
        vec![HttpResponse::new(200, url, body)],
        MemoryVault::default(),
    );
    service
        .session
        .set_route(crate::auth::session::RouteMode::WebVpn);
    assert_eq!(service.load_notices(true).await.unwrap().data.len(), 1);
    let requests = transport.requests();
    assert_eq!(requests.len(), 1);
    assert_eq!(requests[0].url, url);
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
    let venues = service
        .load_cgyy(ginkgo_domain::ports::CgyyQuery::Venues, false)
        .await
        .unwrap();
    let ginkgo_domain::ports::CgyyData::Venues(venues) = venues.data else {
        panic!("venues projection")
    };
    assert_eq!(venues.len(), 1);
    let day = service
        .load_cgyy(
            ginkgo_domain::ports::CgyyQuery::Day {
                site_id: 1,
                date: "2026-10-20".into(),
            },
            false,
        )
        .await
        .unwrap();
    assert_eq!(
        serde_json::to_value(&day.data).unwrap()["spaces"][0]["slots"][0]["status"],
        "空闲"
    );
    assert!(!serde_json::to_string(&day.data)
        .unwrap()
        .contains("must-not-cross-bridge"));
    let orders = service
        .load_cgyy(ginkgo_domain::ports::CgyyQuery::Orders, false)
        .await
        .unwrap();
    assert!(!serde_json::to_string(&orders.data)
        .unwrap()
        .contains("phone"));
    let count = transport.request_count();
    service
        .load_cgyy(
            ginkgo_domain::ports::CgyyQuery::Day {
                site_id: 1,
                date: "2026-10-20".into(),
            },
            false,
        )
        .await
        .unwrap();
    assert_eq!(count, transport.request_count());
    let stale = service
        .load_cgyy(
            ginkgo_domain::ports::CgyyQuery::Day {
                site_id: 1,
                date: "2026-10-20".into(),
            },
            true,
        )
        .await
        .unwrap();
    assert_eq!(
        serde_json::to_value(&stale.data).unwrap()["date"],
        "2026-10-20"
    );
    assert!(stale.failure.is_some());
    for req in transport.requests().iter().skip(5) {
        assert!(req.url.starts_with("https://cgyy.buaa.edu.cn/"));
        if req.url.contains("/api/") {
            assert!(req.header_value("sign").is_some());
        }
        assert!(req.method == HttpMethod::Get || req.url.ends_with("/api/login"));
    }
    service.clear_snapshots();
    assert!(service.identity.lock().cgyy_token.is_none());
}
