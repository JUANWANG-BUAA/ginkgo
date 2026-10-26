use super::*;
use crate::{
    auth::{session::Session, vault::MemoryVault},
    foundation::http::HttpResponse,
    test_support::MockTransport,
    ErrorCode,
};
use serde_json::json;
fn client() -> SchoolClient<MockTransport, MemoryVault> {
    let s = SchoolClient::new(
        Session::new(MockTransport::default()),
        MemoryVault::default(),
    );
    identity(&s, "a");
    s
}
fn identity(s: &SchoolClient<MockTransport, MemoryVault>, id: &str) {
    s.set_authenticated(
        id.into(),
        crate::auth::UserProfile {
            school_id: id.into(),
            name: "synthetic".into(),
        },
    );
}
fn course() -> LearningCourse {
    LearningCourse {
        id: "c".into(),
        name: "course".into(),
        teacher: None,
        term: None,
        source_url: "https://example.invalid".into(),
    }
}
#[tokio::test]
async fn learning_cache_empty_covers_old_failure_keeps_timestamp_and_hit_skips_fetch() {
    let s = client();
    let cache = &s.snapshots.learning.courses;
    let old = s
        .learning_cached(cache, "k".into(), true, || async { Ok(vec![course()]) })
        .await
        .unwrap();
    assert_eq!(old.data.len(), 1);
    let scoped = serde_json::to_string(&(s.learning_owner().unwrap(), "k")).unwrap();
    let (at, stamp) = {
        let c = cache.lock();
        let entry = c.any(&scoped).unwrap();
        (entry.fetched_at, entry.timestamp.clone())
    };
    let hit = s
        .learning_cached(cache, "k".into(), false, || async {
            panic!("fresh hit must not fetch");
            #[allow(unreachable_code)]
            Ok(Vec::<LearningCourse>::new())
        })
        .await
        .unwrap();
    assert_eq!(hit.data.len(), 1);
    let failed = s
        .learning_cached(cache, "k".into(), true, || async {
            Err::<Vec<LearningCourse>, _>(AppError::changed())
        })
        .await
        .unwrap();
    assert_eq!(failed.data.len(), 1);
    assert_eq!(failed.failure.unwrap().code, ErrorCode::ChangedResponse);
    {
        let c = cache.lock();
        let entry = c.any(&scoped).unwrap();
        assert_eq!(entry.fetched_at, at);
        assert_eq!(entry.timestamp, stamp);
    }
    assert!(s
        .learning_cached(cache, "k".into(), true, || async {
            Ok(Vec::<LearningCourse>::new())
        })
        .await
        .unwrap()
        .data
        .is_empty());
}
#[tokio::test]
async fn learning_cache_account_generation_and_query_keys_are_isolated() {
    let s = client();
    let cache = &s.snapshots.learning.courses;
    s.learning_cached(cache, "course-a/folder-a/1".into(), true, || async {
        Ok(vec![course()])
    })
    .await
    .unwrap();
    for key in [
        "course-b/folder-a/1",
        "course-a/folder-b/1",
        "course-a/folder-a/2",
    ] {
        assert!(s
            .learning_cached(cache, key.into(), false, || async {
                Err::<Vec<LearningCourse>, _>(AppError::changed())
            })
            .await
            .is_err());
    }
    identity(&s, "b");
    assert!(s
        .learning_cached(cache, "course-a/folder-a/1".into(), false, || async {
            Err::<Vec<LearningCourse>, _>(AppError::changed())
        })
        .await
        .is_err());
    identity(&s, "a");
    assert!(s
        .learning_cached(cache, "course-a/folder-a/1".into(), false, || async {
            Err::<Vec<LearningCourse>, _>(AppError::changed())
        })
        .await
        .is_err());
}
#[tokio::test]
async fn learning_late_success_and_failure_never_cross_clear_or_a_b_a() {
    let s = client();
    let cache = &s.snapshots.learning.courses;
    for fail in [false, true] {
        let r = s
            .learning_cached(cache, "k".into(), true, || async {
                s.clear_caches();
                if fail {
                    Err(AppError::changed())
                } else {
                    Ok(vec![course()])
                }
            })
            .await;
        assert_eq!(r.unwrap_err().code, ErrorCode::SessionExpired);
        assert!(s
            .learning_cached(cache, "k".into(), false, || async {
                Err::<Vec<LearningCourse>, _>(AppError::changed())
            })
            .await
            .is_err());
    }
    let r = s
        .learning_cached(cache, "k".into(), true, || async {
            identity(&s, "b");
            identity(&s, "a");
            Ok(vec![course()])
        })
        .await;
    assert_eq!(r.unwrap_err().code, ErrorCode::SessionExpired);
    assert!(s
        .learning_cached(cache, "k".into(), false, || async {
            Err::<Vec<LearningCourse>, _>(AppError::changed())
        })
        .await
        .is_err());
}
#[tokio::test]
async fn learning_production_course_port_caches_and_preserves_failed_snapshot() {
    fn response(v: serde_json::Value) -> HttpResponse {
        HttpResponse::new(
            200,
            "https://spoc.buaa.edu.cn/fixture",
            json!({"code":200,"content":v}).to_string(),
        )
    }
    fn auth() -> Vec<HttpResponse> {
        vec![
            HttpResponse::new(200, "https://spoc.buaa.edu.cn/spocnew/", "spa"),
            HttpResponse::new(
                200,
                "https://spoc.buaa.edu.cn/spocnew/cas?token=synthetic",
                "",
            ),
            response(json!({"rolecode":"01"})),
        ]
    }
    let mut replies = auth();
    replies.push(response(
        json!({"list":[{"kcid":"c","kcmc":"course"}],"hasNextPage":false,"pageNum":1}),
    ));
    replies.extend(auth());
    replies.push(response(json!({"list":{}})));
    replies.extend(auth());
    replies.push(response(json!({"list":[],"hasNextPage":false,"pageNum":1})));
    let t = MockTransport::with_responses(replies);
    let s = SchoolClient::new(Session::new(t.clone()), MemoryVault::default());
    identity(&s, "a");
    assert_eq!(s.learning_courses(true).await.unwrap().data.len(), 1);
    let count = t.request_count();
    assert_eq!(s.learning_courses(false).await.unwrap().data.len(), 1);
    assert_eq!(t.request_count(), count);
    let failed = s.learning_courses(true).await.unwrap();
    assert_eq!(failed.data.len(), 1);
    assert_eq!(failed.failure.unwrap().code, ErrorCode::ChangedResponse);
    assert!(s.learning_courses(true).await.unwrap().data.is_empty());
}

#[tokio::test]
async fn learning_reuses_single_silent_recovery_without_rejecting_same_account() {
    use crate::auth::{Credentials, LOGIN_URL, UC_ACTIVATION_URL, UC_STATUS_URL};
    use std::sync::atomic::{AtomicUsize, Ordering};
    let account = "a";
    let form =
        r#"<form action="/login" method="post"><input name="execution" value="fixture" /></form>"#;
    let t = MockTransport::with_responses(vec![
        HttpResponse::new(200, LOGIN_URL, form),
        HttpResponse::new(302, LOGIN_URL, "")
            .with_header(
                "Location",
                "https://sso.buaa.edu.cn/login?ticket=ST-synthetic",
            )
            .with_set_cookie("CASTGC=TGT-fixture; Path=/; Secure; HttpOnly"),
        HttpResponse::new(
            200,
            "https://sso.buaa.edu.cn/login?ticket=ST-synthetic",
            "<html>ok</html>",
        ),
        HttpResponse::new(200, UC_ACTIVATION_URL, ""),
        HttpResponse::new(
            200,
            UC_STATUS_URL,
            json!({"code":0,"data":{"schoolid":account,"name":"synthetic"}}).to_string(),
        ),
    ]);
    let vault = MemoryVault::with(
        account,
        Credentials {
            username: account.into(),
            password: "synthetic".into(),
            captcha_text: None,
        },
    );
    let s = SchoolClient::new(Session::new(t.clone()), vault);
    identity(&s, account);
    let owner = s.learning_owner().unwrap();
    let calls = AtomicUsize::new(0);
    let result = s
        .learning_read(|| async {
            if calls.fetch_add(1, Ordering::SeqCst) == 0 {
                Err(AppError::session_expired())
            } else {
                Ok(7)
            }
        })
        .await
        .unwrap();
    assert_eq!(result, 7);
    assert_eq!(calls.load(Ordering::SeqCst), 2);
    assert_eq!(s.learning_owner().unwrap(), (account.into(), owner.1 + 1));
    assert_eq!(t.request_count(), 5);
}

#[tokio::test]
async fn learning_does_not_retry_non_auth_failure_or_recover_foreign_identity() {
    use std::sync::atomic::{AtomicUsize, Ordering};
    let s = client();
    let calls = AtomicUsize::new(0);
    assert_eq!(
        s.learning_read(|| async {
            calls.fetch_add(1, Ordering::SeqCst);
            Err::<(), _>(AppError::unavailable())
        })
        .await
        .unwrap_err()
        .code,
        ErrorCode::ServiceUnavailable
    );
    assert_eq!(calls.load(Ordering::SeqCst), 1);
    assert_eq!(
        s.learning_read(|| async {
            identity(&s, "b");
            Err::<(), _>(AppError::session_expired())
        })
        .await
        .unwrap_err()
        .code,
        ErrorCode::SessionExpired
    );
}

#[tokio::test]
async fn learning_wrong_course_page_keeps_previous_snapshot() {
    fn response(v: serde_json::Value) -> HttpResponse {
        HttpResponse::new(
            200,
            "https://spoc.buaa.edu.cn/fixture",
            json!({"code":200,"content":v}).to_string(),
        )
    }
    fn auth() -> Vec<HttpResponse> {
        vec![
            HttpResponse::new(200, "https://spoc.buaa.edu.cn/spocnew/", "spa"),
            HttpResponse::new(
                200,
                "https://spoc.buaa.edu.cn/spocnew/cas?token=synthetic",
                "",
            ),
            response(json!({"rolecode":"01"})),
        ]
    }
    let mut replies = auth();
    replies.push(response(
        json!({"list":[{"kcid":"c","kcmc":"course"}],"pageNum":1,"hasNextPage":false}),
    ));
    replies.extend(auth());
    replies.push(response(json!({"list":[],"pageNum":2,"hasNextPage":false})));
    let t = MockTransport::with_responses(replies);
    let s = SchoolClient::new(Session::new(t), MemoryVault::default());
    identity(&s, "a");
    assert_eq!(s.learning_courses(true).await.unwrap().data.len(), 1);
    let failed = s.learning_courses(true).await.unwrap();
    assert_eq!(failed.data.len(), 1);
    assert_eq!(failed.failure.unwrap().code, ErrorCode::ChangedResponse);
}

#[tokio::test]
async fn learning_conflicting_resource_identity_never_reaches_download_gate() {
    fn response(v: serde_json::Value) -> HttpResponse {
        HttpResponse::new(
            200,
            "https://spoc.buaa.edu.cn/fixture",
            json!({"code":200,"content":v}).to_string(),
        )
    }
    let t = MockTransport::with_responses(vec![
        HttpResponse::new(200, "https://spoc.buaa.edu.cn/spocnew/", "spa"),
        HttpResponse::new(
            200,
            "https://spoc.buaa.edu.cn/spocnew/cas?token=synthetic",
            "",
        ),
        response(json!({"rolecode":"01"})),
        response(json!({"list":[{"kcid":"c","kcmc":"course"}],"pageNum":1,"hasNextPage":false})),
        response(
            json!({"list":[{"id":"same","wjmc":"folder","sfwjj":"1","sfkxz":"0"},{"id":"same","wjmc":"file","sfwjj":"0","sfkxz":"1"}],"pageNum":1,"hasNextPage":false}),
        ),
    ]);
    let s = SchoolClient::new(Session::new(t.clone()), MemoryVault::default());
    identity(&s, "a");
    assert_eq!(
        s.course_resource_download("c", None, 1, "same")
            .await
            .err()
            .unwrap()
            .code,
        ErrorCode::ChangedResponse
    );
    assert_eq!(t.request_count(), 5);
    assert!(!t
        .requests()
        .iter()
        .any(|r| r.url.contains("getWjids") || r.url.contains("downLoadFile")));
}

#[tokio::test]
async fn learning_capability_is_passive_scoped_and_records_real_failure_not_stale_success() {
    use LearningCapabilityState::*;
    let t = MockTransport::default();
    let s = SchoolClient::new(Session::new(t.clone()), MemoryVault::default());
    identity(&s, "a");
    assert_eq!(
        s.course_learning_capabilities("c").await.unwrap().resources,
        Unknown
    );
    assert_eq!(t.request_count(), 0);
    let scope = s.learning_scope().unwrap();
    s.learning_observe("c", &scope, |c| &mut c.resources, None);
    assert_eq!(
        s.course_learning_capabilities("c").await.unwrap().resources,
        Available
    );
    for (code, expected) in [
        (ErrorCode::ServiceUnavailable, TemporarilyUnavailable),
        (ErrorCode::ChangedResponse, ProtocolChanged),
        (ErrorCode::SessionExpired, AuthRequired),
        (ErrorCode::AccessPolicyDenied, AccessDenied),
    ] {
        let result: Result<DataOutcome<Vec<String>>, AppError> = Ok(DataOutcome {
            data: vec![],
            failure: Some(AppError::new(code)),
        });
        s.learning_observe("c", &scope, |c| &mut c.resources, outcome_failure(&result));
        assert_eq!(
            s.course_learning_capabilities("c").await.unwrap().resources,
            expected
        );
    }
    assert_eq!(
        s.course_learning_capabilities("other")
            .await
            .unwrap()
            .resources,
        Unknown
    );
    s.snapshots.learning.clear();
    s.learning_observe("c", &scope, |c| &mut c.resources, None);
    assert_eq!(
        s.course_learning_capabilities("c").await.unwrap().resources,
        Unknown
    );
    identity(&s, "b");
    identity(&s, "a");
    s.learning_observe("c", &scope, |c| &mut c.resources, None);
    assert_eq!(
        s.course_learning_capabilities("c").await.unwrap().resources,
        Unknown
    );
    assert_eq!(t.request_count(), 0);
}
#[tokio::test]
async fn learning_context_columns_cache_empty_success_and_keep_failure_distinct() {
    fn response(v: serde_json::Value) -> HttpResponse {
        HttpResponse::new(
            200,
            "https://spoc.buaa.edu.cn/fixture",
            json!({"code":200,"content":v}).to_string(),
        )
    }
    fn auth() -> Vec<HttpResponse> {
        vec![
            HttpResponse::new(200, "https://spoc.buaa.edu.cn/spocnew/", "spa"),
            HttpResponse::new(
                200,
                "https://spoc.buaa.edu.cn/spocnew/cas?token=synthetic",
                "",
            ),
            response(json!({"rolecode":"01"})),
            response(
                json!({"list":[{"kcid":"c","kcmc":"course"}],"pageNum":1,"hasNextPage":false}),
            ),
        ]
    }
    let mut replies = auth();
    replies.push(response(json!([])));
    replies.extend(auth());
    replies.push(response(json!({"bad":"tree"})));
    let t = MockTransport::with_responses(replies);
    let s = SchoolClient::new(Session::new(t.clone()), MemoryVault::default());
    identity(&s, "a");
    assert!(s
        .course_learning_columns("c", true)
        .await
        .unwrap()
        .data
        .is_empty());
    assert_eq!(
        s.course_learning_capabilities("c").await.unwrap().columns,
        LearningCapabilityState::Available
    );
    let count = t.request_count();
    s.course_learning_columns("c", false).await.unwrap();
    assert_eq!(t.request_count(), count);
    let failed = s.course_learning_columns("c", true).await.unwrap();
    assert!(failed.data.is_empty());
    assert_eq!(failed.failure.unwrap().code, ErrorCode::ChangedResponse);
    assert_eq!(
        s.course_learning_capabilities("c").await.unwrap().columns,
        LearningCapabilityState::ProtocolChanged
    );
}

#[tokio::test]
async fn learning_context_selection_cache_keys_are_independent_and_download_rechecks_chain() {
    fn response(v: serde_json::Value) -> HttpResponse {
        HttpResponse::new(
            200,
            "https://spoc.buaa.edu.cn/fixture",
            json!({"code":200,"content":v}).to_string(),
        )
    }
    fn auth() -> Vec<HttpResponse> {
        vec![
            HttpResponse::new(200, "https://spoc.buaa.edu.cn/spocnew/", "spa"),
            HttpResponse::new(
                200,
                "https://spoc.buaa.edu.cn/spocnew/cas?token=synthetic",
                "",
            ),
            response(json!({"rolecode":"01"})),
            response(
                json!({"list":[{"kcid":"c","kcmc":"course"}],"pageNum":1,"hasNextPage":false}),
            ),
        ]
    }
    let tree =
        json!([{"lmlxdm":"0","children":[{"id":"a","lmlxdm":"01"},{"id":"b","lmlxdm":"01"}]}]);
    let mut replies = auth();
    replies.extend([
        response(tree.clone()),
        response(json!([{"id":"notice-a","bt":"a"}])),
    ]);
    replies.extend(auth());
    replies.extend([response(tree), response(json!([]))]);
    replies.extend(auth());
    for id in ["root-folder", "child-folder"] {
        replies.push(response(json!({"list":[{"id":id,"wjmc":"directory","sfwjj":"1"}],"pageNum":1,"hasNextPage":false})));
    }
    replies.push(response(json!({"list":[{"id":"file","wjmc":"synthetic.txt","sfwjj":"0","sfkxz":"1"}],"pageNum":2,"hasNextPage":false})));
    replies.push(response(json!({"flag":"1"})));
    let mut blob = HttpResponse::new(200, "https://spoc.buaa.edu.cn/blob", "");
    blob.bytes = Some(b"synthetic".to_vec());
    replies.push(blob);
    let t = MockTransport::with_responses(replies);
    let s = SchoolClient::new(Session::new(t.clone()), MemoryVault::default());
    identity(&s, "a");
    assert_eq!(
        s.course_announcements_in("c", "a", false)
            .await
            .unwrap()
            .data[0]
            .id,
        "notice-a"
    );
    assert!(s
        .course_announcements_in("c", "b", false)
        .await
        .unwrap()
        .data
        .is_empty());
    let count = t.request_count();
    assert_eq!(
        s.course_announcements_in("c", "a", false)
            .await
            .unwrap()
            .data[0]
            .id,
        "notice-a"
    );
    assert_eq!(t.request_count(), count);
    let file = s
        .course_resource_download_at(
            "c",
            &["root-folder".into(), "child-folder".into()],
            2,
            "file",
        )
        .await
        .unwrap();
    assert_eq!(file.name, "synthetic.txt");
    assert_eq!(file.bytes, b"synthetic");
    assert_eq!(
        s.course_learning_capabilities("c")
            .await
            .unwrap()
            .resource_download,
        LearningCapabilityState::Available
    );
    let r = t.requests();
    assert_eq!(r.last().unwrap().response_limit, Some(20 * 1024 * 1024));
    assert!(r.iter().all(|r| !r.url.contains("updYdb")
        && !r.url.contains("addKczxFwjl")
        && !r.url.contains("myTask")
        && !r.url.contains("upload")));
}
