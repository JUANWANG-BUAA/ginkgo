use super::*;
use ginkgo_core::application::{CourseResourcePage, DataOutcome, LearningDownload};
#[test]
fn learning_bridge_empty_and_stale_have_distinct_payload_and_failure() {
    let empty = response(Ok(DataOutcome {
        data: Vec::<String>::new(),
        failure: None,
    }));
    assert_eq!(empty.payload.as_deref(), Some("[]"));
    assert!(!empty.stale);
    assert!(empty.failure.is_none());
    let stale = response(Ok(DataOutcome {
        data: CourseResourcePage {
            page: 2,
            has_next: false,
            items: vec![],
        },
        failure: Some(AppError::changed()),
    }));
    assert!(stale.stale);
    assert!(matches!(stale.failure, Some(FailureCode::ChangedResponse)));
    assert_eq!(
        stale.payload.as_deref(),
        Some(r#"{"items":[],"page":2,"hasNext":false}"#)
    );
    let failed = response::<Vec<String>>(Err(AppError::session_expired()));
    assert!(failed.payload.is_none());
    assert!(!failed.stale);
    assert!(matches!(failed.failure, Some(FailureCode::SessionExpired)));
}
#[test]
fn learning_bridge_download_never_includes_bytes_or_name_on_failure() {
    let ok = download(Ok(LearningDownload {
        name: "synthetic.json".into(),
        bytes: b"{}".to_vec(),
    }));
    assert_eq!(ok.name.as_deref(), Some("synthetic.json"));
    assert_eq!(ok.bytes.as_deref(), Some(b"{}".as_slice()));
    assert!(ok.failure.is_none());
    let failed = download(Err(AppError::invalid()));
    assert!(failed.name.is_none());
    assert!(failed.bytes.is_none());
    assert!(matches!(failed.failure, Some(FailureCode::InvalidRequest)));
}
#[tokio::test]
async fn learning_bridge_missing_identity_fails_closed_without_payload() {
    assert!(
        SERVICE.get().is_none(),
        "synthetic tests must not create a live runtime"
    );
    // Empty expected-account capability fails regardless of runtime state. These
    // commands may never infer an account or manufacture a successful empty list.
    for r in [
        courses(String::new(), false).await,
        announcements(String::new(), "c".into(), true).await,
        resources(String::new(), "c".into(), Some("f".into()), 1, true).await,
        assessments(String::new(), "c".into(), true).await,
    ] {
        assert!(r.payload.is_none());
        assert!(r.failure.is_some());
        assert!(!r.stale);
    }
    assert!(
        SERVICE.get().is_none(),
        "missing identity must fail before runtime creation"
    );
}
