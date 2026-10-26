use super::*;
use crate::{foundation::http::HttpMethod, test_support::MockTransport};
use serde_json::json;
fn auth_fixture() -> SpocAuth {
    SpocAuth {
        token: "synthetic".into(),
        role: "01".into(),
    }
}
fn reply(v: Value) -> HttpResponse {
    HttpResponse::new(
        200,
        "https://spoc.buaa.edu.cn/spocnewht/fixture",
        json!({"code":200,"content":v}).to_string(),
    )
}
fn page(items: Value) -> Value {
    json!({"list":items,"pageNum":1,"hasNextPage":false})
}
#[tokio::test]
async fn learning_folder_requires_current_course_root_proof_before_child_request() {
    for root in [
        json!([]),
        json!([{"id":"foreign","wjmc":"other","sfwjj":"1"}]),
        json!([{"id":"target","wjmc":"not-folder","sfwjj":"0"}]),
    ] {
        let t = MockTransport::with_responses(vec![reply(page(root))]);
        let s = Session::new(t.clone());
        assert_eq!(
            resources::page(&s, &auth_fixture(), "course", Some("target"), 1)
                .await
                .unwrap_err()
                .code,
            ErrorCode::AccessPolicyDenied
        );
        assert_eq!(t.request_count(), 1);
        assert!(t.requests()[0].url.contains("/kcwj/queryListPageXs?"));
    }
    let t = MockTransport::with_responses(vec![
        reply(page(json!([{"id":"target","wjmc":"folder","sfwjj":"1"}]))),
        reply(page(json!([]))),
    ]);
    let s = Session::new(t.clone());
    assert!(
        resources::page(&s, &auth_fixture(), "course", Some("target"), 1)
            .await
            .unwrap()
            .items
            .is_empty()
    );
    let requests = t.requests();
    assert_eq!(requests.len(), 2);
    assert!(requests[1].url.contains("/grwj1/queryKcwjListgr?"));
    let url = url::Url::parse(&requests[1].url).unwrap();
    let q: std::collections::BTreeMap<_, _> = url.query_pairs().collect();
    assert_eq!(q["kcid"], "course");
    assert_eq!(q["pid"], "target");
    assert_eq!(requests[1].method, HttpMethod::Post);
}
#[tokio::test]
async fn learning_folder_discovery_is_bounded_and_invalid_page_issues_no_request() {
    let t = MockTransport::with_responses(
        (1..=5)
            .map(|n| reply(json!({"list":[],"pageNum":n,"hasNextPage":true})))
            .collect(),
    );
    let s = Session::new(t.clone());
    assert!(
        resources::page(&s, &auth_fixture(), "course", Some("unseen"), 1)
            .await
            .is_err()
    );
    assert_eq!(t.request_count(), 5);
    assert!(resources::page(&s, &auth_fixture(), "course", None, 0)
        .await
        .is_err());
    assert_eq!(t.request_count(), 5);
}
#[tokio::test]
async fn learning_notice_and_assessment_use_verified_columns_and_no_write_routes() {
    let tree = json!([{"lmlxdm":"0","children":[{"id":"n+1","lmlxdm":"01"}]},{"lmlxdm":"3","children":[{"id":"q+1","lmlxdm":"32"}]}]);
    let t = MockTransport::with_responses(vec![
        reply(tree.clone()),
        reply(json!([])),
        reply(tree),
        reply(json!({"list":[]})),
        reply(json!({"bt":"notice"})),
    ]);
    let s = Session::new(t.clone());
    assert!(announcements::list(&s, &auth_fixture(), "c+1")
        .await
        .unwrap()
        .is_empty());
    assert!(assessments::list(&s, &auth_fixture(), "c+1")
        .await
        .unwrap()
        .is_empty());
    announcements::detail(&s, &auth_fixture(), "n")
        .await
        .unwrap();
    let r = t.requests();
    assert_eq!(r.len(), 5);
    assert!(r[0].url.contains("sflx=2"));
    assert_eq!(r[1].header_value("Content-Type"), Some("application/json"));
    let b: Value = serde_json::from_str(r[1].body.as_ref().unwrap()).unwrap();
    assert_eq!(b["sslmid"], "n+1");
    assert_eq!(b["kcid"], "c+1");
    let q: std::collections::BTreeMap<_, _> =
        url::form_urlencoded::parse(r[3].body.as_ref().unwrap().as_bytes()).collect();
    assert_eq!(q["id"], "q+1");
    assert_eq!(q["flag"], "xs");
    assert!(r.iter().all(|r| !r.url.contains("updYdb")
        && !r.url.contains("addKczxFwjl")
        && !r.url.contains("myTask")));
}
#[tokio::test]
async fn learning_unknown_or_ambiguous_columns_never_fall_back_to_unscoped_query() {
    for tree in [
        json!([]),
        json!([{"lmlxdm":"0","children":[{"id":"a","lmlxdm":"01"},{"id":"b","lmlxdm":"01"}]}]),
    ] {
        let t = MockTransport::with_responses(vec![reply(tree)]);
        let s = Session::new(t.clone());
        assert!(announcements::list(&s, &auth_fixture(), "c").await.is_err());
        assert_eq!(t.request_count(), 1);
    }
}
#[tokio::test]
async fn learning_download_gate_and_post_blob_preserve_json_files() {
    let mut file = HttpResponse::new(200, "https://spoc.buaa.edu.cn/file", "")
        .with_header("Content-Type", "application/json")
        .with_header("Content-Disposition", "attachment; filename=synthetic.json");
    file.bytes = Some(b"{}".to_vec());
    let t = MockTransport::with_responses(vec![reply(json!({"flag":"1"})), file]);
    let s = Session::new(t.clone());
    assert_eq!(
        resources::download(&s, &auth_fixture(), "f+1")
            .await
            .unwrap(),
        b"{}"
    );
    let r = t.requests();
    assert_eq!(r[0].method, HttpMethod::Get);
    assert_eq!(r[1].method, HttpMethod::Post);
    assert_eq!(r[1].body.as_deref(), Some("{}"));
    assert!(r[1].binary_response);
    assert_eq!(r[1].response_limit, Some(20 * 1024 * 1024));
    let t = MockTransport::with_responses(vec![reply(json!({"flag":"0"}))]);
    let s = Session::new(t.clone());
    assert_eq!(
        resources::download(&s, &auth_fixture(), "f")
            .await
            .unwrap_err()
            .code,
        ErrorCode::AccessPolicyDenied
    );
    assert_eq!(t.request_count(), 1);
}
#[tokio::test]
async fn learning_response_classification_and_pagination_reject_drift() {
    assert_eq!(
        decode(HttpResponse::new(401, "fixture", ""))
            .unwrap_err()
            .code,
        ErrorCode::SessionExpired
    );
    assert_eq!(
        decode(HttpResponse::new(200, "fixture", "<html>login</html>"))
            .unwrap_err()
            .code,
        ErrorCode::SessionExpired
    );
    assert_eq!(
        decode(HttpResponse::new(503, "fixture", ""))
            .unwrap_err()
            .code,
        ErrorCode::ServiceUnavailable
    );
    assert!(decode(HttpResponse::new(200, "fixture", "not json")).is_err());
    let row = json!({"kcid":"c","kcmc":"course"});
    let t = MockTransport::with_responses(vec![
        reply(json!({"list":[row.clone()],"pageNum":1,"hasNextPage":true})),
        reply(json!({"list":[row],"pageNum":2,"hasNextPage":false})),
    ]);
    let s = Session::new(t.clone());
    assert!(courses(&s, &auth_fixture()).await.is_err());
    assert_eq!(t.request_count(), 2);
}

#[tokio::test]
async fn learning_binary_sniffs_login_and_error_envelopes_but_allows_real_json_html() {
    fn blob(bytes: &[u8], attachment: bool) -> HttpResponse {
        let mut r = HttpResponse::new(200, "https://spoc.buaa.edu.cn/file", "");
        r.bytes = Some(bytes.to_vec());
        if attachment {
            r = r.with_header("Content-Disposition", "attachment; filename=synthetic.html");
        }
        r
    }
    for bad in [
        blob(
            b"<html><form action=casLogin><input type=\"password\"></form></html>",
            false,
        ),
        blob(
            br#"{"code":400,"content":null,"msg":"synthetic failure"}"#,
            true,
        ),
    ] {
        let t = MockTransport::with_responses(vec![bad]);
        let s = Session::new(t);
        assert!(
            binary(&s, &auth_fixture(), "https://spoc.buaa.edu.cn/file".into())
                .await
                .is_err()
        );
    }
    for (body, mime) in [
        (
            b"<html><h1>synthetic resource</h1></html>".as_slice(),
            "text/html",
        ),
        (b"{\"synthetic\":true}".as_slice(), "application/json"),
    ] {
        let t =
            MockTransport::with_responses(vec![blob(body, true).with_header("Content-Type", mime)]);
        let s = Session::new(t);
        assert_eq!(
            binary(&s, &auth_fixture(), "https://spoc.buaa.edu.cn/file".into())
                .await
                .unwrap(),
            body
        );
    }
}

#[tokio::test]
async fn learning_explicit_column_revalidates_kind_and_course_before_scoped_read() {
    let tree = json!([{"lmlxdm":"0","children":[{"id":"a","lmlxdm":"01","lmmc2":"first"},{"id":"b+2","lmlxdm":"01","lmmc2":"second"}]},{"lmlxdm":"3","children":[{"id":"quiz","lmlxdm":"32"}]}]);
    let t = MockTransport::with_responses(vec![
        reply(tree.clone()),
        reply(json!([])),
        reply(tree.clone()),
        reply(tree),
    ]);
    let s = Session::new(t.clone());
    assert!(
        announcements::list_in(&s, &auth_fixture(), "c", Some("b+2"))
            .await
            .unwrap()
            .is_empty()
    );
    let body: Value = serde_json::from_str(t.requests()[1].body.as_ref().unwrap()).unwrap();
    assert_eq!(body["sslmid"], "b+2");
    assert_eq!(
        announcements::list_in(&s, &auth_fixture(), "c", Some("quiz"))
            .await
            .unwrap_err()
            .code,
        ErrorCode::AccessPolicyDenied
    );
    assert_eq!(
        announcements::list_in(&s, &auth_fixture(), "c", Some("foreign"))
            .await
            .unwrap_err()
            .code,
        ErrorCode::AccessPolicyDenied
    );
    assert_eq!(t.request_count(), 4);
    assert!(t.requests().iter().all(|r| !r.url.contains("updYdb")
        && !r.url.contains("addKczxFwjl")
        && !r.url.contains("myTask")));
}
#[tokio::test]
async fn learning_resource_path_proves_each_parent_and_requested_page() {
    let folder = |id| json!({"id":id,"wjmc":"directory","sfwjj":"1"});
    let t = MockTransport::with_responses(vec![
        reply(page(json!([folder("a")]))),
        reply(page(json!([folder("b+2")]))),
        reply(json!({"list":[],"pageNum":2,"hasNextPage":false})),
    ]);
    let s = Session::new(t.clone());
    let result = resources::page_at(&s, &auth_fixture(), "c", &["a".into(), "b+2".into()], 2)
        .await
        .unwrap();
    assert_eq!(result.page, 2);
    for (request, pid) in t.requests().iter().zip(["0", "a", "b+2"]) {
        let u = url::Url::parse(&request.url).unwrap();
        let q: std::collections::BTreeMap<_, _> = u.query_pairs().collect();
        assert_eq!(q["pid"], pid);
        assert_eq!(q["kcid"], "c");
        assert_eq!(request.method, HttpMethod::Post);
    }
    assert!(
        resources::page_at(&s, &auth_fixture(), "c", &["a".into(), "a".into()], 1)
            .await
            .is_err()
    );
    assert!(
        resources::page_at(&s, &auth_fixture(), "c", &vec!["x".into(); 9], 1)
            .await
            .is_err()
    );
    assert_eq!(t.request_count(), 3);
}
#[tokio::test]
async fn learning_resource_path_rejects_wrong_parent_and_cross_page_conflict() {
    let t = MockTransport::with_responses(vec![
        reply(page(json!([{"id":"a","wjmc":"directory","sfwjj":"1"}]))),
        reply(page(json!([]))),
    ]);
    let s = Session::new(t.clone());
    assert_eq!(
        resources::page_at(&s, &auth_fixture(), "c", &["a".into(), "unseen".into()], 1)
            .await
            .unwrap_err()
            .code,
        ErrorCode::AccessPolicyDenied
    );
    assert_eq!(t.request_count(), 2);
    let t = MockTransport::with_responses(vec![
        reply(
            json!({"list":[{"id":"a","wjmc":"directory","sfwjj":"1"}],"pageNum":1,"hasNextPage":true}),
        ),
        reply(
            json!({"list":[{"id":"a","wjmc":"file","sfwjj":"0"}],"pageNum":2,"hasNextPage":false}),
        ),
    ]);
    assert_eq!(
        resources::page_at(
            &Session::new(t.clone()),
            &auth_fixture(),
            "c",
            &["a".into()],
            1
        )
        .await
        .unwrap_err()
        .code,
        ErrorCode::ChangedResponse
    );
    assert_eq!(t.request_count(), 2);
}

#[tokio::test]
async fn learning_path_node_budget_stops_before_child_and_page_budget_remains_bounded() {
    let rows: Vec<_> = (0..500)
        .map(|n| json!({"id":format!("r{n}"),"wjmc":"directory","sfwjj":"1"}))
        .collect();
    let t = MockTransport::with_responses(vec![
        reply(page(json!(rows))),
        reply(page(json!((0..301)
            .map(|n| json!({"id":format!("x{n}"),"wjmc":"directory","sfwjj":"1"}))
            .collect::<Vec<_>>()))),
    ]);
    let s = Session::new(t.clone());
    assert_eq!(
        resources::page_at(&s, &auth_fixture(), "c", &["r0".into(), "x0".into()], 1)
            .await
            .unwrap_err()
            .code,
        ErrorCode::AccessPolicyDenied
    );
    assert_eq!(t.request_count(), 2);
    let t=MockTransport::with_responses((1..=5).map(|n| reply(json!({"list":[{"id":format!("d{n}"),"wjmc":"directory","sfwjj":"1"}],"pageNum":n,"hasNextPage":true}))).collect());
    assert_eq!(
        resources::page_at(
            &Session::new(t.clone()),
            &auth_fixture(),
            "c",
            &["d1".into()],
            1
        )
        .await
        .unwrap_err()
        .code,
        ErrorCode::AccessPolicyDenied
    );
    assert_eq!(t.request_count(), 5);
}
