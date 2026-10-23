//! Public catalogue reads: anonymous, validated before any request.
use super::*;
use ginkgo_domain::ports::LibraryCatalogSource;

fn search_response() -> HttpResponse {
    HttpResponse::new(
        200,
        "https://space.lib.buaa.edu.cn/meta-local/opac/search?coverFirst=false&disable_facet=false",
        serde_json::json!({
            "code": 0,
            "data": {
                "total": 30,
                "actualTotal": 30,
                "dataList": [
                    {"bibId": "B1", "title": "合成书名", "author": ["甲"], "callno": ["TP1/1"]}
                ]
            }
        })
        .to_string(),
    )
}

fn holdings_response() -> HttpResponse {
    let inner = serde_json::json!([
        {"callNo": "TP1/1", "barCode": "C1", "library": "学院路", "locationName": "三层", "circStatus": "可借"}
    ]);
    HttpResponse::new(
        200,
        "https://space.lib.buaa.edu.cn/meta-local/opac/bibs/B1/holdings?isMobile=0&relateStat=1",
        serde_json::json!({"code": 0, "data": {"holdings": inner.to_string()}}).to_string(),
    )
}

#[tokio::test]
async fn search_and_holdings_are_projected_from_public_codes() {
    let (service, transport) = build_service(
        vec![search_response(), holdings_response()],
        MemoryVault::default(),
    );
    let page = service
        .search_books("合成".into(), 1)
        .await
        .expect("search");
    assert_eq!(page.actual_total, 30);
    assert!(page.has_more);
    assert_eq!(page.items[0].callno, "TP1/1");
    let rows = service.book_holdings("B1".into()).await.expect("holdings");
    assert_eq!(rows[0].status, "可借");
    let requests = transport.requests();
    // Anonymous reads: no authorization header is attached to either request.
    assert_eq!(requests.len(), 2);
    for request in &requests {
        assert_eq!(request.header_value("authorization"), None);
        assert_eq!(request.header_value("cgAuthorization"), None);
    }
    assert_eq!(requests[0].method, HttpMethod::Post);
    let body: Value =
        serde_json::from_str(requests[0].body.as_deref().expect("body")).expect("json");
    assert_eq!(body["page"], 1);
    assert_eq!(body["pageSize"], 20);
    assert_eq!(body["queryFieldList"][0]["values"][0], "合成");
}

#[tokio::test]
async fn invalid_input_never_reaches_the_school() {
    let (service, transport) = build_service(vec![], MemoryVault::default());
    for (query, page) in [
        ("".to_string(), 1),
        ("   ".into(), 1),
        ("x".repeat(200), 1),
        ("合成".into(), 0),
        ("合成".into(), 101),
    ] {
        assert!(service.search_books(query, page).await.is_err());
    }
    for bib in ["", "   ", "a\tb"] {
        assert!(service.book_holdings(bib.into()).await.is_err());
    }
    assert_eq!(transport.request_count(), 0);
}

#[tokio::test]
async fn non_zero_business_code_is_not_an_empty_catalogue() {
    let denied = HttpResponse::new(
        200,
        "https://space.lib.buaa.edu.cn/meta-local/opac/search?coverFirst=false&disable_facet=false",
        serde_json::json!({"code": 401, "message": "denied"}).to_string(),
    );
    let (service, _) = build_service(vec![denied], MemoryVault::default());
    assert_eq!(
        service
            .search_books("合成".into(), 1)
            .await
            .expect_err("denied")
            .code,
        ErrorCode::BusinessRejected
    );
}

#[tokio::test]
async fn holdings_on_a_foreign_or_non_200_response_is_unavailable() {
    for response in [
        HttpResponse::new(
            500,
            "https://space.lib.buaa.edu.cn/meta-local/opac/bibs/B1/holdings?isMobile=0&relateStat=1",
            "",
        ),
        HttpResponse::new(
            200,
            "https://example.invalid/meta-local/opac/bibs/B1/holdings",
            serde_json::json!({"code": 0, "data": {"holdings": "[]"}}).to_string(),
        ),
    ] {
        let (service, _) = build_service(vec![response], MemoryVault::default());
        assert!(service.book_holdings("B1".into()).await.is_err());
    }
}
