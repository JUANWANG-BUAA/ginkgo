use super::resources_response;
use super::*;
use ginkgo_core::application::CourseResourcePage;
use ginkgo_core::application::{DataOutcome, LearningDownload};
#[test]
fn typed_resources_page_keeps_an_empty_success_and_a_stale_snapshot_distinct() {
    let empty = resources_response(Ok(DataOutcome {
        data: CourseResourcePage {
            page: 1,
            has_next: false,
            items: vec![],
        },
        failure: None,
    }));
    // A confirmed empty page is data with no failure, not an error.
    assert!(empty.data.expect("page").items.is_empty());
    assert!(!empty.failure.is_some());

    let stale = resources_response(Ok(DataOutcome {
        data: CourseResourcePage {
            page: 2,
            has_next: false,
            items: vec![],
        },
        failure: Some(AppError::changed()),
    }));
    // The previous snapshot crosses with its failure attached.
    assert!(stale.failure.is_some());
    assert!(matches!(stale.failure, Some(FailureCode::ChangedResponse)));
    assert_eq!(stale.data.expect("page").page, 2);
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
async fn learning_bridge_missing_identity_fails_closed_without_data() {
    assert!(
        SERVICE.get().is_none(),
        "synthetic tests must not create a live runtime"
    );
    // Empty expected-account capability fails regardless of runtime state. These
    // commands may never infer an account or manufacture a successful empty list.
    let courses = courses(String::new(), false).await;
    assert!(courses.data.is_none());
    assert!(courses.failure.is_some());
    let announcements = announcements(String::new(), "c".into(), true).await;
    assert!(announcements.data.is_none());
    assert!(announcements.failure.is_some());
    let resources = resources(String::new(), "c".into(), Some("f".into()), 1, true).await;
    assert!(resources.data.is_none());
    assert!(resources.failure.is_some());
    let assessments = assessments(String::new(), "c".into(), true).await;
    assert!(assessments.data.is_none());
    assert!(assessments.failure.is_some());
    assert!(
        SERVICE.get().is_none(),
        "missing identity must fail before runtime creation"
    );
}
