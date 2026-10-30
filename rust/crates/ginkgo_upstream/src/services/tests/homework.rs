use super::*;

#[tokio::test]
async fn homework_full_read_chain_caches_list_and_reads_detail() {
    use crate::adapters::homework_http::SPOC_BASE;
    let envelope = |content: Value| serde_json::json!({"code":200,"content":content}).to_string();
    let mut responses = login_chain("sy2501001", "fixture");
    let spoc_auth = || {
        vec![
            HttpResponse::new(200, "https://spoc.buaa.edu.cn/spocnew/", "spa"),
            HttpResponse::new(
                404,
                "https://spoc.buaa.edu.cn/spocnew/cas?token=fixture",
                "callback",
            ),
            HttpResponse::new(
                200,
                format!("{SPOC_BASE}/sys/casLogin"),
                envelope(serde_json::json!({"rolecode":"01"})),
            ),
        ]
    };
    responses.extend(spoc_auth());
    responses.extend([
        HttpResponse::new(
            200,
            "term",
            envelope(serde_json::json!({"mrxq":"2026-20271","dqxq":"合成学期"})),
        ),
        HttpResponse::new(
            200,
            "courses",
            envelope(serde_json::json!([{"kcid":"c1","kcmc":"合成课程","skjs":"合成教师"}])),
        ),
        HttpResponse::new(
            200,
            "page",
            envelope(fixture("homework", "spoc-page-v1.json")["input"]["body"].clone()),
        ),
        HttpResponse::new(
            200,
            "student-courses",
            envelope(serde_json::json!({"list":[{"kcid":"c1"}],"hasNextPage":false})),
        ),
        HttpResponse::new(
            200,
            "assistant-courses",
            envelope(serde_json::json!({"list":[],"hasNextPage":false})),
        ),
    ]);
    responses.extend(spoc_auth());
    responses.extend([
        HttpResponse::new(
            200,
            "assignment",
            envelope(serde_json::json!({"zynr":"<p>合成说明</p>"})),
        ),
        HttpResponse::new(200, "submission", envelope(serde_json::json!({"tjzt":"1"}))),
        HttpResponse::new(503, "spa", "unavailable"),
    ]);
    let (service, transport) = build_service(responses, MemoryVault::default());
    service
        .sign_in("sy2501001", "pa+ss/word", None, true)
        .await
        .expect("login");
    let list = service.load_homework(false).await.expect("list");
    assert!(list.data.roles_complete);
    assert_eq!(list.data.items.len(), 2);
    assert_eq!(list.data.items[0].teacher_name.as_deref(), Some("合成教师"));
    assert_eq!(list.data.items[0].course_role.as_deref(), Some("student"));
    assert!(list.data.items[1].teacher_name.is_none());
    let count = transport.request_count();
    assert_eq!(
        service
            .load_homework(false)
            .await
            .expect("cache")
            .data
            .term_code,
        "2026-20271"
    );
    assert_eq!(count, transport.request_count());
    let detail = service
        .load_homework_detail("spoc:a", false)
        .await
        .expect("detail");
    assert_eq!(detail.data.content.as_deref(), Some("合成说明"));
    assert_eq!(
        detail.data.source_url.as_deref(),
        Some(crate::endpoints::HOMEWORK_PORTAL)
    );
    assert!(transport
        .requests()
        .iter()
        .any(|r| r.url.ends_with("/kczy/queryKczyInfoByid?id=a")));
    assert!(!transport
        .requests()
        .iter()
        .any(|r| r.url.contains("id=spoc")));
    assert_eq!(
        detail.data.status,
        crate::codecs::homework::HomeworkStatus::Submitted
    );
    // Teacher context belongs to the cached snapshot, including failed refresh.
    let stale = service.load_homework(true).await.expect("stale");
    assert!(stale.failure.is_some());
    assert_eq!(
        stale.data.items[0].teacher_name.as_deref(),
        Some("合成教师")
    );
    service.sign_out().await;
    assert!(service.load_homework(false).await.is_err());
}

#[tokio::test]
async fn homework_keeps_assignments_when_course_role_lookup_fails() {
    use crate::adapters::homework_http::SPOC_BASE;
    let envelope = |content: Value| serde_json::json!({"code":200,"content":content}).to_string();
    let mut responses = login_chain("sy2501001", "fixture");
    responses.extend([
        HttpResponse::new(200, "https://spoc.buaa.edu.cn/spocnew/", "spa"),
        HttpResponse::new(
            404,
            "https://spoc.buaa.edu.cn/spocnew/cas?token=fixture",
            "callback",
        ),
        HttpResponse::new(
            200,
            format!("{SPOC_BASE}/sys/casLogin"),
            envelope(serde_json::json!({"rolecode":"01"})),
        ),
        HttpResponse::new(
            200,
            "term",
            envelope(serde_json::json!({"mrxq":"2026-20271","dqxq":"合成学期"})),
        ),
        HttpResponse::new(
            200,
            "courses",
            envelope(serde_json::json!([{"kcid":"c1","kcmc":"合成课程"}])),
        ),
        HttpResponse::new(
            200,
            "page",
            envelope(fixture("homework", "spoc-page-v1.json")["input"]["body"].clone()),
        ),
        HttpResponse::new(503, "student-courses", "unavailable"),
        HttpResponse::new(
            200,
            "assistant-courses",
            envelope(serde_json::json!({"list":[],"hasNextPage":false})),
        ),
    ]);
    let (service, _) = build_service(responses, MemoryVault::default());
    service
        .sign_in("sy2501001", "pa+ss/word", None, true)
        .await
        .expect("login");
    let list = service
        .load_homework(false)
        .await
        .expect("assignments remain available");
    assert!(!list.data.roles_complete);
    assert_eq!(list.data.items.len(), 2);
}

#[tokio::test]
async fn homework_changed_body_preserves_cached_text_and_native_ids_share_cache() {
    use crate::{adapters::homework_http::SPOC_BASE, codecs::homework};
    let envelope = |content: Value| serde_json::json!({"code":200,"content":content}).to_string();
    let mut responses = login_chain("sy2501001", "fixture");
    responses.extend([
        HttpResponse::new(200, "https://spoc.buaa.edu.cn/spocnew/", "spa"),
        HttpResponse::new(
            404,
            "https://spoc.buaa.edu.cn/spocnew/cas?token=fixture",
            "callback",
        ),
        HttpResponse::new(
            200,
            format!("{SPOC_BASE}/sys/casLogin"),
            envelope(serde_json::json!({"rolecode":"01"})),
        ),
        HttpResponse::new(
            200,
            "detail",
            envelope(serde_json::json!({"zynr":{"text":"invalid structure"}})),
        ),
        HttpResponse::new(200, "submission", envelope(Value::Null)),
    ]);
    let (service, transport) = build_service(responses, MemoryVault::default());
    service
        .sign_in("sy2501001", "pa+ss/word", None, true)
        .await
        .expect("signed in");
    let cached =
        homework::parse_detail(&fixture("homework", "spoc-detail-normal-v1.json")["input"])
            .expect("synthetic detail");
    service
        .snapshots
        .homework_details
        .lock()
        .insert("synthetic+a/b".into(), cached);
    let initial = transport.request_count();
    assert_eq!(
        service
            .load_homework_detail("spoc:synthetic+a/b", false)
            .await
            .expect("cache")
            .data
            .content
            .as_deref(),
        Some("合成说明")
    );
    assert_eq!(transport.request_count(), initial);
    let result = service
        .load_homework_detail("synthetic+a/b", true)
        .await
        .expect("prior snapshot");
    assert_eq!(
        result.failure.expect("structure failure").code,
        ErrorCode::ChangedResponse
    );
    assert_eq!(result.data.content.as_deref(), Some("合成说明"));
    assert!(transport.requests().iter().any(|request| request
        .url
        .ends_with("queryKczyInfoByid?id=synthetic%2Ba%2Fb")));
}

/// The await-time account recheck: a homework read parked mid-flight must
/// reject its result after the identity flips instead of landing under the
/// new account.
#[tokio::test]
async fn an_account_change_during_the_homework_read_rejects_its_result() {
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
    let mut pending = Box::pin(service.load_homework(false));
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
}

/// A module that refuses its own token must not be reported as a global
/// session expiry, and it must not drag the whole session through a silent
/// re-login: the shared session may still be working for every other module.
#[tokio::test]
async fn a_module_auth_refusal_never_relogins_the_shared_session() {
    use crate::adapters::homework_http::SPOC_BASE;
    let envelope = |content: Value| serde_json::json!({"code":200,"content":content}).to_string();
    let mut responses = login_chain("sy2501001", "fixture");
    responses.extend([
        HttpResponse::new(200, "https://spoc.buaa.edu.cn/spocnew/", "spa"),
        HttpResponse::new(
            404,
            "https://spoc.buaa.edu.cn/spocnew/cas?token=fixture",
            "callback",
        ),
        HttpResponse::new(
            200,
            format!("{SPOC_BASE}/sys/casLogin"),
            envelope(serde_json::json!({"rolecode":"01"})),
        ),
        // SPOC refuses its own token on the first real read.
        HttpResponse::new(
            200,
            "term",
            serde_json::json!({"code":401,"content":null}).to_string(),
        ),
    ]);
    let (service, transport) = build_service(responses, MemoryVault::default());
    service
        .sign_in("sy2501001", "pa+ss/word", None, true)
        .await
        .expect("login");
    let logins_before = transport
        .requests()
        .iter()
        .filter(|request| request.url == LOGIN_URL)
        .count();

    let error = service
        .load_homework(false)
        .await
        .expect_err("the module refused its own token");
    assert_eq!(error.code, ErrorCode::ModuleAuthRequired);

    let logins_after = transport
        .requests()
        .iter()
        .filter(|request| request.url == LOGIN_URL)
        .count();
    assert_eq!(
        logins_after, logins_before,
        "a module-scoped refusal must not re-login the shared session"
    );
}
