use super::*;
use crate::adapters::homework_files_http as protocol;
use crate::auth::session::{RouteMode, Session};
use crate::codecs::mutation::MutationState;
use crate::AppError;
fn response(value: Value) -> HttpResponse {
    HttpResponse::new(200, "https://spoc.buaa.edu.cn/test", value.to_string())
}
fn envelope(value: Value) -> HttpResponse {
    response(serde_json::json!({"code":200,"content":value}))
}
fn auth() -> Vec<HttpResponse> {
    vec![
        HttpResponse::new(200, "https://spoc.buaa.edu.cn/spocnew/", "spa"),
        HttpResponse::new(
            404,
            "https://spoc.buaa.edu.cn/spocnew/cas?token=fixture",
            "callback",
        ),
        envelope(serde_json::json!({"rolecode":"student"})),
    ]
}
fn context(student: bool) -> Vec<HttpResponse> {
    let mut r = auth();
    r.extend([envelope(serde_json::json!({"sskcid":"course-a","zylx":"1","sfzysjn":"1","pyfs":"0","bhtjlx":"5","xzwjlx":"pdf,zip","xztjcs":9999})),envelope(serde_json::json!({"ytjcs":0})),envelope(serde_json::json!({"list":if student {vec![serde_json::json!({"kcid":"course-a"})]}else{vec![]},"hasNextPage":false}))]);
    r
}
fn recovery_root() -> std::path::PathBuf {
    let path =
        std::env::temp_dir().join(format!("ginkgo-homework-{:032x}", rand::random::<u128>()));
    std::fs::create_dir(&path).unwrap();
    std::fs::canonicalize(path).unwrap()
}
fn client(
    responses: Vec<HttpResponse>,
) -> (SchoolClient<MockTransport, MemoryVault>, MockTransport) {
    client_at(responses, &recovery_root())
}
fn client_at(
    responses: Vec<HttpResponse>,
    root: &std::path::Path,
) -> (SchoolClient<MockTransport, MemoryVault>, MockTransport) {
    let (s, t) = build_service(responses, MemoryVault::default());
    s.set_authenticated(
        "sy2501001".into(),
        UserProfile {
            school_id: "sy2501001".into(),
            name: "fixture".into(),
        },
    );
    s.session.set_route(RouteMode::Direct);
    s.configure_homework_recovery(root.to_str().unwrap())
        .unwrap();
    (s, t)
}
fn uploaded() -> Vec<HttpResponse> {
    let mut r = context(true);
    r.extend([
        response(serde_json::json!({"mc":false,"data":[1]})),
        response(serde_json::json!({"id":"file-a"})),
    ]);
    r
}
#[tokio::test]
async fn homework_file_upload_submit_single_attempt() {
    let mut r = uploaded();
    r.extend(context(true));
    r.extend([
        envelope(Value::Null),
        envelope(serde_json::json!({"tjlx":"5","scwjid":"file-a","ytjcs":1})),
    ]);
    let (s, t) = client(r);
    let receipt = s
        .upload_homework_file("spoc:work-a", "answer.pdf", vec![0, 255, 13, 10])
        .await
        .unwrap();
    assert_eq!(receipt.size, 4);
    assert_eq!(
        t.requests()
            .iter()
            .filter(|r| r.url.contains("submitKcz2"))
            .count(),
        0
    );
    assert!(matches!(
        s.submit_homework_file(&receipt.handle, false).await.state,
        MutationState::NotSubmitted
    ));
    assert!(matches!(
        s.submit_homework_file(&receipt.handle, true).await.state,
        MutationState::Accepted
    ));
    assert!(matches!(
        s.submit_homework_file(&receipt.handle, true).await.state,
        MutationState::NotSubmitted
    ));
    let count = t.request_count();
    for _ in 0..2 {
        assert!(matches!(
            s.reconcile_homework_file(&receipt.handle).await.state,
            MutationState::Accepted
        ));
    }
    assert_eq!(t.request_count(), count);
    let requests = t.requests();
    let writes: Vec<_> = requests
        .iter()
        .filter(|r| r.url.contains("submitKcz2"))
        .collect();
    assert_eq!(writes.len(), 1);
    let fields: std::collections::BTreeMap<_, _> =
        url::form_urlencoded::parse(writes[0].body.as_ref().unwrap().as_bytes())
            .into_owned()
            .collect();
    assert_eq!(fields["scwjid"], "file-a");
    assert_eq!(fields["kczyid"], "work-a");
    assert_eq!(fields["tjlx"], "5");
    let upload = requests
        .iter()
        .find(|r| r.url.ends_with("uploadFile"))
        .unwrap();
    assert!(upload.body.is_none());
    assert!(upload
        .binary_body
        .as_ref()
        .unwrap()
        .windows(4)
        .any(|b| b == [0, 255, 13, 10]));
}
#[tokio::test]
async fn homework_file_unknown_result_blocks_resend() {
    let mut r = uploaded();
    r.extend(context(true));
    r.extend([
        HttpResponse::new(503, "submit", "bad"),
        envelope(serde_json::json!({"tjlx":"5","scwjid":"different","ytjcs":1})),
    ]);
    r.extend(context(true));
    r.push(envelope(
        serde_json::json!({"tjlx":"5","scwjid":"file-a","ytjcs":1}),
    ));
    let (s, t) = client(r);
    let receipt = s
        .upload_homework_file("work-a", "answer.pdf", vec![42])
        .await
        .unwrap();
    assert!(matches!(
        s.submit_homework_file(&receipt.handle, true).await.state,
        MutationState::Uncertain
    ));
    let count = t.request_count();
    assert!(matches!(
        s.submit_homework_file(&receipt.handle, true).await.state,
        MutationState::NotSubmitted
    ));
    assert_eq!(count, t.request_count());
    assert!(matches!(
        s.reconcile_homework_file(&receipt.handle).await.state,
        MutationState::Accepted
    ));
    assert_eq!(
        t.requests()
            .iter()
            .filter(|r| r.url.contains("submitKcz2"))
            .count(),
        1
    );
}
#[tokio::test]
async fn homework_file_nonstudent_extension_account_guard() {
    let (s, t) = client(context(false));
    assert!(s
        .upload_homework_file("a", "answer.pdf", vec![1])
        .await
        .is_err());
    assert_eq!(t.request_count(), 6);
    let (s, t) = client(context(true));
    assert!(s
        .upload_homework_file("a", "answer.exe", vec![1])
        .await
        .is_err());
    assert_eq!(t.request_count(), 6);
    let (s, t) = client(uploaded());
    let receipt = s
        .upload_homework_file("a", "answer.pdf", vec![1])
        .await
        .unwrap();
    let count = t.request_count();
    s.identity.lock().generation += 1;
    assert!(matches!(
        s.submit_homework_file(&receipt.handle, true).await.state,
        MutationState::NotSubmitted
    ));
    assert_eq!(count, t.request_count());
}
#[tokio::test]
async fn homework_file_bad_file_never_contacts_network() {
    let (s, t) = client(vec![]);
    for name in ["../a.pdf", "bad\r\n.pdf", ""] {
        assert!(s.upload_homework_file("a", name, vec![1]).await.is_err());
    }
    assert!(s.upload_homework_file("a", "a.pdf", vec![]).await.is_err());
    assert_eq!(t.request_count(), 0);
}
#[tokio::test]
async fn homework_file_webvpn_byte_exact_no_write_fallback() {
    let t = MockTransport::with_responses(vec![HttpResponse::new(483, "blocked", "")]);
    let s = Session::new(t.clone());
    s.set_route(RouteMode::WebVpn);
    let auth = crate::adapters::homework_http::SpocAuth {
        token: "fixture".into(),
        role: "student".into(),
    };
    assert!(protocol::upload(&s, &auth, "a.pdf", &[255, 0, 254])
        .await
        .is_err());
    let r = t.requests();
    assert_eq!(r.len(), 1);
    assert!(r[0].url.starts_with("https://d.buaa.edu.cn/"));
    assert!(r[0]
        .binary_body
        .as_ref()
        .unwrap()
        .windows(3)
        .any(|b| b == [255, 0, 254]));
}
#[tokio::test]
async fn homework_file_malformed_chunk_never_merges() {
    let t = MockTransport::with_responses(vec![response(serde_json::json!({"unexpected":true}))]);
    let s = Session::new(t.clone());
    let a = crate::adapters::homework_http::SpocAuth {
        token: "fixture".into(),
        role: "student".into(),
    };
    assert!(protocol::upload(&s, &a, "a.pdf", &[1]).await.is_err());
    assert_eq!(t.request_count(), 1);
}

#[tokio::test]
async fn homework_file_explicit_rejection_cannot_become_an_upload_receipt() {
    let auth = crate::adapters::homework_http::SpocAuth {
        token: "fixture".into(),
        role: "student".into(),
    };
    // A contradictory deduplication reply must not bypass its rejection code.
    let transport = MockTransport::with_responses(vec![response(serde_json::json!({
        "code": 500, "mc": true, "data": {"id": "file-a"}
    }))]);
    let session = Session::new(transport.clone());
    assert_eq!(
        protocol::upload(&session, &auth, "answer.pdf", &[1])
            .await
            .unwrap_err()
            .code,
        ErrorCode::BusinessRejected
    );
    assert_eq!(transport.request_count(), 1);

    // File-service merge metadata is not evidence of success after rejection.
    let transport = MockTransport::with_responses(vec![
        response(serde_json::json!({"data": [1]})),
        response(serde_json::json!({"code": 500, "id": "file-a"})),
    ]);
    let session = Session::new(transport.clone());
    assert_eq!(
        protocol::upload(&session, &auth, "answer.pdf", &[1])
            .await
            .unwrap_err()
            .code,
        ErrorCode::BusinessRejected
    );
    assert_eq!(transport.request_count(), 2);
    assert!(!transport
        .requests()
        .iter()
        .any(|request| request.url.contains("submitKcz2")));
}

#[tokio::test]
async fn homework_file_download_checks_assignment_and_preserves_bytes() {
    let mut r = auth();
    r.extend([
        envelope(serde_json::json!({"sskcid":"course-a","zyfjid":"teacher-file"})),
        envelope(Value::Null),
        response(serde_json::json!({"wjysmc":"requirements.pdf"})),
    ]);
    let mut file = HttpResponse::new(
        200,
        "https://spoc.buaa.edu.cn/inco-filesystem/fileManagerSystem/downLoadFile",
        "",
    )
    .with_header("content-type", "application/pdf");
    file.bytes = Some(vec![255, 0, 254]);
    r.push(file);
    let (s, t) = client(r);
    let file = s.download_homework_file("a", "teacher-file").await.unwrap();
    assert_eq!(file.name, "requirements.pdf");
    assert_eq!(file.bytes, vec![255, 0, 254]);
    assert!(t.requests().last().unwrap().binary_response);
    let mut r = auth();
    r.extend([
        envelope(serde_json::json!({"sskcid":"course-a"})),
        envelope(Value::Null),
    ]);
    let (s, t) = client(r);
    assert!(s.download_homework_file("a", "arbitrary-id").await.is_err());
    assert_eq!(t.request_count(), 5);
}
#[tokio::test]
async fn homework_file_chunk_boundary_and_merge_follow_binary_payload() {
    let t = MockTransport::with_responses(vec![
        response(serde_json::json!({"data":[1]})),
        response(serde_json::json!({"data":[1,2]})),
        response(serde_json::json!({"id":"f"})),
    ]);
    let s = Session::new(t.clone());
    let auth = crate::adapters::homework_http::SpocAuth {
        token: "fixture".into(),
        role: "student".into(),
    };
    let bytes = vec![255; 4_096_001];
    assert_eq!(
        protocol::upload(&s, &auth, "answer.pdf", &bytes)
            .await
            .unwrap(),
        "f"
    );
    let requests = t.requests();
    assert_eq!(requests.len(), 3);
    let bodies: Vec<_> = requests[..2]
        .iter()
        .map(|r| String::from_utf8_lossy(r.binary_body.as_ref().unwrap()))
        .collect();
    assert!(bodies[0].contains("2048000"));
    assert!(bodies[1].contains("2048001"));
    assert!(requests[2].url.ends_with("mergeFile"));
}
#[tokio::test]
async fn homework_file_transport_failure_sends_final_write_once_and_still_reconciles() {
    let mut responses: Vec<_> = uploaded().into_iter().map(Ok).collect();
    responses.extend(context(true).into_iter().map(Ok));
    responses.push(Err(TransportError::Unavailable));
    responses.push(Ok(envelope(
        serde_json::json!({"tjlx":"5","scwjid":"file-a","ytjcs":1}),
    )));
    let t = MockTransport::with_results(responses);
    let s = SchoolClient::new(Session::new(t.clone()), MemoryVault::default());
    s.set_authenticated(
        "sy2501001".into(),
        UserProfile {
            school_id: "sy2501001".into(),
            name: "fixture".into(),
        },
    );
    s.session.set_route(RouteMode::Direct);
    s.configure_homework_recovery(recovery_root().to_str().unwrap())
        .unwrap();
    let receipt = s
        .upload_homework_file("a", "answer.pdf", vec![1])
        .await
        .unwrap();
    assert!(matches!(
        s.submit_homework_file(&receipt.handle, true).await.state,
        MutationState::Accepted
    ));
    assert_eq!(
        t.requests()
            .iter()
            .filter(|r| r.url.contains("submitKcz2"))
            .count(),
        1
    );
}

#[derive(Clone)]
struct PausedWrite {
    inner: MockTransport,
    started: std::sync::Arc<tokio::sync::Notify>,
}
impl crate::foundation::http::HttpTransport for PausedWrite {
    async fn send(&self, request: HttpRequest) -> Result<HttpResponse, TransportError> {
        if request.url.contains("submitKcz2") {
            let _ = crate::foundation::http::HttpTransport::send(&self.inner, request).await;
            self.started.notify_one();
            std::future::pending().await
        } else {
            crate::foundation::http::HttpTransport::send(&self.inner, request).await
        }
    }
}
#[tokio::test]
async fn homework_file_cancelled_write_is_journaled_before_await() {
    let mut responses = uploaded();
    responses.extend(context(true));
    responses.push(envelope(Value::Null));
    let inner = MockTransport::with_responses(responses);
    let started = std::sync::Arc::new(tokio::sync::Notify::new());
    let service = SchoolClient::new(
        Session::new(PausedWrite {
            inner: inner.clone(),
            started: started.clone(),
        }),
        MemoryVault::default(),
    );
    service.set_authenticated(
        "sy2501001".into(),
        UserProfile {
            school_id: "sy2501001".into(),
            name: "fixture".into(),
        },
    );
    service.session.set_route(RouteMode::Direct);
    service
        .configure_homework_recovery(recovery_root().to_str().unwrap())
        .unwrap();
    let receipt = service
        .upload_homework_file("a", "answer.pdf", vec![1])
        .await
        .unwrap();
    {
        let submit = service.submit_homework_file(&receipt.handle, true);
        tokio::pin!(submit);
        tokio::select! {_=&mut submit=>panic!("write must pause"),_=started.notified()=>{}}
    }
    let count = inner.request_count();
    assert!(matches!(
        service
            .submit_homework_file(&receipt.handle, true)
            .await
            .state,
        MutationState::NotSubmitted
    ));
    assert_eq!(inner.request_count(), count);
    assert!(service
        .upload_homework_file("a", "other.pdf", vec![2])
        .await
        .is_err());
    assert_eq!(
        inner
            .requests()
            .iter()
            .filter(|r| r.url.contains("uploadFile"))
            .count(),
        1
    );
}

#[test]
fn homework_file_existing_same_file_does_not_prove_new_submission() {
    let value = serde_json::json!({"tjlx":"5","scwjid":"file-a","ytjcs":2});
    assert!(protocol::matches_file(&value, "file-a", 1));
    assert!(!protocol::matches_file(&value, "file-a", 2));
    assert!(!protocol::matches_file(&value, "other", 1));
}

#[tokio::test]
async fn homework_file_read_uses_detail_query_not_editor_permission_query() {
    let (service, transport) = client(context(true));
    service.homework_workspace("spoc:work+a/b").await.unwrap();
    let requests = transport.requests();
    let request = requests
        .iter()
        .find(|r| r.url.contains("queryKczyInfoByid"))
        .unwrap();
    let url = url::Url::parse(&request.url).unwrap();
    let pairs: Vec<_> = url.query_pairs().into_owned().collect();
    assert_eq!(pairs, vec![("id".to_owned(), "work+a/b".to_owned())]);
}

#[tokio::test]
async fn homework_pending_survives_restart_and_identity_generation_without_resend() {
    let root = recovery_root();
    let mut replies = uploaded();
    replies.extend(context(true));
    replies.extend([
        HttpResponse::new(503, "submit", "unknown"),
        envelope(serde_json::json!({"tjlx":"5","scwjid":"other","ytjcs":1})),
    ]);
    let (first, transport) = client_at(replies, &root);
    let receipt = first
        .upload_homework_file("spoc:work-a", "answer.pdf", vec![1])
        .await
        .unwrap();
    assert!(matches!(
        first
            .submit_homework_file(&receipt.handle, true)
            .await
            .state,
        MutationState::Uncertain
    ));
    assert_eq!(
        transport
            .requests()
            .iter()
            .filter(|r| r.url.contains("submitKcz2"))
            .count(),
        1
    );
    drop(first);
    let mut replies = context(true);
    replies.push(envelope(
        serde_json::json!({"tjlx":"5","scwjid":"file-a","ytjcs":1}),
    ));
    let (restored, transport) = client_at(replies, &root);
    restored.identity.lock().generation += 5;
    let pending = restored.pending_homework_submissions().await.unwrap();
    assert_eq!(pending.len(), 1);
    assert_eq!(pending[0].handle, receipt.handle);
    assert_eq!(pending[0].assignment_id, "spoc:work-a");
    assert_eq!(pending[0].file_name, "answer.pdf");
    assert_eq!(pending[0].size, 1);
    assert!(restored
        .upload_homework_file("work-a", "again.pdf", vec![2])
        .await
        .is_err());
    assert!(matches!(
        restored
            .submit_homework_file(&receipt.handle, true)
            .await
            .state,
        MutationState::NotSubmitted
    ));
    assert_eq!(transport.request_count(), 0);
    assert!(matches!(
        restored
            .reconcile_homework_file(&receipt.handle)
            .await
            .state,
        MutationState::Accepted
    ));
    assert!(restored
        .pending_homework_submissions()
        .await
        .unwrap()
        .is_empty());
    assert!(!transport
        .requests()
        .iter()
        .any(|r| r.url.contains("submitKcz2")
            || r.url.contains("uploadFile")
            || r.url.contains("mergeFile")));
    std::fs::remove_dir_all(root).unwrap();
}
#[tokio::test]
async fn homework_journal_is_account_isolated_and_corruption_blocks_before_upload() {
    let root = recovery_root();
    let mut replies = uploaded();
    replies.extend(context(true));
    replies.extend([
        HttpResponse::new(503, "submit", "unknown"),
        envelope(Value::Null),
    ]);
    let (first, _) = client_at(replies, &root);
    let receipt = first
        .upload_homework_file("work-a", "answer.pdf", vec![1])
        .await
        .unwrap();
    assert!(matches!(
        first
            .submit_homework_file(&receipt.handle, true)
            .await
            .state,
        MutationState::Uncertain
    ));
    let (other, transport) = client_at(vec![], &root);
    other.set_authenticated(
        "other".into(),
        UserProfile {
            school_id: "other".into(),
            name: "other".into(),
        },
    );
    assert!(other
        .pending_homework_submissions()
        .await
        .unwrap()
        .is_empty());
    assert!(matches!(
        other.reconcile_homework_file(&receipt.handle).await.state,
        MutationState::NotSubmitted
    ));
    assert_eq!(transport.request_count(), 0);
    let folder = std::fs::read_dir(&root)
        .unwrap()
        .map(|e| e.unwrap().path())
        .find(|p| std::fs::read_dir(p).unwrap().next().is_some())
        .unwrap();
    let record = std::fs::read_dir(folder)
        .unwrap()
        .next()
        .unwrap()
        .unwrap()
        .path();
    let bytes = std::fs::read_to_string(&record).unwrap();
    assert!(!bytes.contains("sy2501001"));
    assert!(!bytes.contains("fixture"));
    assert!(!bytes.contains("token"));
    std::fs::write(record, b"partial crash record").unwrap();
    let (restored, transport) = client_at(vec![], &root);
    assert!(restored.pending_homework_submissions().await.is_err());
    assert!(restored
        .upload_homework_file("work-b", "answer.pdf", vec![2])
        .await
        .is_err());
    assert_eq!(transport.request_count(), 0);
    std::fs::remove_dir_all(root).unwrap();
}
#[tokio::test]
async fn homework_ready_receipt_is_not_recovered_and_missing_storage_never_writes() {
    let root = recovery_root();
    let (first, _) = client_at(uploaded(), &root);
    let receipt = first
        .upload_homework_file("work-a", "answer.pdf", vec![1])
        .await
        .unwrap();
    let (restored, transport) = client_at(vec![], &root);
    assert!(restored
        .pending_homework_submissions()
        .await
        .unwrap()
        .is_empty());
    assert!(matches!(
        restored
            .submit_homework_file(&receipt.handle, true)
            .await
            .state,
        MutationState::NotSubmitted
    ));
    assert_eq!(transport.request_count(), 0);
    let (unconfigured, transport) = build_service(vec![], MemoryVault::default());
    unconfigured.set_authenticated(
        "sy2501001".into(),
        UserProfile {
            school_id: "sy2501001".into(),
            name: "fixture".into(),
        },
    );
    assert!(unconfigured.pending_homework_submissions().await.is_err());
    assert!(unconfigured
        .upload_homework_file("work-a", "answer.pdf", vec![1])
        .await
        .is_err());
    assert_eq!(transport.request_count(), 0);
    std::fs::remove_dir_all(root).unwrap();
}
#[tokio::test]
async fn homework_module_capabilities_explain_unknown_and_supported_file_without_experimental_feature(
) {
    let (service, transport) = client(context(true));
    let capabilities = service.homework_capabilities("spoc:work-a").await;
    assert_eq!(capabilities.len(), 6);
    for key in ["fileUpload", "fileSubmit", "fileReconcile"] {
        assert_eq!(
            capabilities
                .iter()
                .find(|c| c.capability == key)
                .unwrap()
                .state,
            HomeworkCapabilityState::Available
        );
    }
    for key in ["textSubmit", "urlSubmit"] {
        assert_eq!(
            capabilities
                .iter()
                .find(|c| c.capability == key)
                .unwrap()
                .state,
            HomeworkCapabilityState::Unknown
        );
    }
    assert_eq!(
        capabilities
            .iter()
            .find(|c| c.capability == "groupSubmit")
            .unwrap()
            .state,
        HomeworkCapabilityState::Unsupported
    );
    assert!(!transport
        .requests()
        .iter()
        .any(|r| r.url.contains("submitKcz2")
            || r.url.contains("uploadFile")
            || r.url.contains("mergeFile")));
    let (service, transport) = client(vec![]);
    service.identity.lock().authenticated = None;
    let c = service.homework_capabilities("work-a").await;
    assert_eq!(
        c.iter()
            .find(|c| c.capability == "fileSubmit")
            .unwrap()
            .state,
        HomeworkCapabilityState::AuthRequired
    );
    assert_eq!(transport.request_count(), 0);
}
#[tokio::test]
async fn homework_chunk_owner_change_stops_remaining_upload_and_merge() {
    let transport =
        MockTransport::with_responses(vec![response(serde_json::json!({"mc":false,"data":[]}))]);
    let session = Session::new(transport.clone());
    let a = crate::adapters::homework_http::SpocAuth {
        token: "fixture".into(),
        role: "student".into(),
    };
    let checks = std::sync::atomic::AtomicUsize::new(0);
    let result = protocol::upload_checked(&session, &a, "answer.pdf", &vec![1; 4_096_001], || {
        if checks.fetch_add(1, std::sync::atomic::Ordering::SeqCst) > 0 {
            Err(AppError::session_expired())
        } else {
            Ok(())
        }
    })
    .await;
    assert_eq!(result.unwrap_err().code, ErrorCode::SessionExpired);
    assert_eq!(transport.request_count(), 1);
    assert!(!transport
        .requests()
        .iter()
        .any(|r| r.url.contains("mergeFile")));
}
#[cfg(unix)]
#[test]
fn homework_recovery_rejects_symlinks_relative_paths_and_root_switches() {
    let root = recovery_root();
    let other = recovery_root();
    let (service, _) = client_at(vec![], &root);
    assert!(service.configure_homework_recovery("relative").is_err());
    assert!(service
        .configure_homework_recovery(other.to_str().unwrap())
        .is_err());
    let link = other.join("linked");
    std::os::unix::fs::symlink(&root, &link).unwrap();
    let (unconfigured, _) = build_service(vec![], MemoryVault::default());
    assert!(unconfigured
        .configure_homework_recovery(link.to_str().unwrap())
        .is_err());
    std::fs::remove_dir_all(root).unwrap();
    std::fs::remove_dir_all(other).unwrap();
}

#[tokio::test]
async fn homework_file_explicit_auth_envelopes_are_not_plain_business_rejection() {
    for code in [401, 403] {
        let transport = MockTransport::with_responses(vec![response(
            serde_json::json!({"code":code,"content":null}),
        )]);
        let session = Session::new(transport.clone());
        let a = crate::adapters::homework_http::SpocAuth {
            token: "fixture".into(),
            role: "student".into(),
        };
        assert_eq!(
            protocol::submission(&session, &a, "work-a")
                .await
                .unwrap_err()
                .code,
            ErrorCode::SessionExpired
        );
        assert_eq!(transport.request_count(), 1);
        let transport = MockTransport::with_responses(vec![response(
            serde_json::json!({"code":code,"data":[]}),
        )]);
        let session = Session::new(transport.clone());
        assert_eq!(
            protocol::upload(&session, &a, "answer.pdf", &[1])
                .await
                .unwrap_err()
                .code,
            ErrorCode::SessionExpired
        );
        assert_eq!(transport.request_count(), 1);
    }
    let transport = MockTransport::with_responses(vec![response(
        serde_json::json!({"code":500,"msg":"登录相关普通拒绝文本","content":null}),
    )]);
    let session = Session::new(transport.clone());
    let a = crate::adapters::homework_http::SpocAuth {
        token: "fixture".into(),
        role: "student".into(),
    };
    assert_eq!(
        protocol::submission(&session, &a, "work-a")
            .await
            .unwrap_err()
            .code,
        ErrorCode::BusinessRejected
    );
    assert_eq!(transport.request_count(), 1);
}
#[tokio::test]
async fn homework_capabilities_report_explicit_auth_failure_and_never_write() {
    let mut replies = auth();
    replies.push(response(serde_json::json!({"code":403,"content":null})));
    let (service, transport) = client(replies);
    let capabilities = service.homework_capabilities("work-a").await;
    for key in ["fileUpload", "fileSubmit", "fileReconcile"] {
        assert_eq!(
            capabilities
                .iter()
                .find(|c| c.capability == key)
                .unwrap()
                .state,
            HomeworkCapabilityState::AuthRequired
        );
    }
    assert_eq!(transport.request_count(), 4);
    assert!(!transport
        .requests()
        .iter()
        .any(|r| r.url.contains("submitKcz2")
            || r.url.contains("uploadFile")
            || r.url.contains("mergeFile")));
}
