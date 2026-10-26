use ginkgo_core::{application::Workspace, AppError};
use ginkgo_domain::{
    features::mutation::{MutationOutcome, MutationState},
    ports::*,
};
use std::sync::{
    atomic::{AtomicUsize, Ordering},
    Arc,
};
struct Files(Arc<AtomicUsize>);
impl HomeworkSubmissionSource for Files {
    async fn homework_workspace(&self, _: &str) -> Result<HomeworkWorkspace, AppError> {
        Err(AppError::invalid())
    }
    async fn upload_homework_file(
        &self,
        _: &str,
        name: &str,
        bytes: Vec<u8>,
    ) -> Result<HomeworkUploadReceipt, AppError> {
        self.0.fetch_add(1, Ordering::SeqCst);
        Ok(HomeworkUploadReceipt {
            handle: "opaque".into(),
            file_name: name.into(),
            size: bytes.len() as u64,
        })
    }
    async fn submit_homework_file(&self, _: &str, _: bool) -> MutationOutcome {
        self.0.fetch_add(1, Ordering::SeqCst);
        MutationOutcome::new(MutationState::Accepted, "fixture")
    }
    async fn download_homework_file(&self, _: &str, _: &str) -> Result<HomeworkDownload, AppError> {
        Ok(HomeworkDownload {
            name: "test".into(),
            bytes: vec![0, 255],
        })
    }
    async fn reconcile_homework_file(&self, _: &str) -> MutationOutcome {
        MutationOutcome::uncertain()
    }
}
#[tokio::test]
async fn homework_capability_is_independent_and_requires_confirmation() {
    let calls = Arc::new(AtomicUsize::new(0));
    let workspace = Workspace::new(Files(calls.clone()));
    assert!(workspace
        .upload_homework_file("a", "a.pdf", vec![])
        .await
        .is_err());
    assert!(matches!(
        workspace.submit_homework_file("opaque", false).await.state,
        MutationState::NotSubmitted
    ));
    assert_eq!(calls.load(Ordering::SeqCst), 0);
    assert_eq!(
        workspace
            .upload_homework_file("a", "a.pdf", vec![0, 255])
            .await
            .unwrap()
            .size,
        2
    );
    assert!(matches!(
        workspace.submit_homework_file("opaque", true).await.state,
        MutationState::Accepted
    ));
    assert_eq!(calls.load(Ordering::SeqCst), 2);
    assert_eq!(
        workspace
            .download_homework_file("a", "f")
            .await
            .unwrap()
            .bytes,
        vec![0, 255]
    );
}

struct Recovery;
impl HomeworkSubmissionSource for Recovery {
    fn configure_homework_recovery(&self, root: &str) -> Result<(), AppError> {
        if root == "/private/application" {
            Ok(())
        } else {
            Err(AppError::invalid())
        }
    }
    async fn pending_homework_submissions(
        &self,
    ) -> Result<Vec<HomeworkPendingSubmission>, AppError> {
        Ok(vec![HomeworkPendingSubmission {
            handle: "opaque".into(),
            assignment_id: "spoc:a".into(),
            file_name: "answer.pdf".into(),
            size: 9,
        }])
    }
    async fn homework_capabilities(&self, id: &str) -> Vec<HomeworkCapabilityEvidence> {
        vec![HomeworkCapabilityEvidence {
            capability: "fileSubmit".into(),
            state: HomeworkCapabilityState::Unknown,
            reason: id.into(),
            evidence: "fixture".into(),
        }]
    }
    async fn homework_workspace(&self, _: &str) -> Result<HomeworkWorkspace, AppError> {
        Err(AppError::invalid())
    }
    async fn upload_homework_file(
        &self,
        _: &str,
        _: &str,
        _: Vec<u8>,
    ) -> Result<HomeworkUploadReceipt, AppError> {
        Err(AppError::invalid())
    }
    async fn submit_homework_file(&self, _: &str, _: bool) -> MutationOutcome {
        MutationOutcome::uncertain()
    }
    async fn download_homework_file(&self, _: &str, _: &str) -> Result<HomeworkDownload, AppError> {
        Err(AppError::invalid())
    }
    async fn reconcile_homework_file(&self, _: &str) -> MutationOutcome {
        MutationOutcome::uncertain()
    }
}
#[tokio::test]
async fn homework_recovery_and_evidence_use_typed_business_ports() {
    let workspace = Workspace::new(Recovery);
    assert!(workspace
        .configure_homework_recovery("/private/application")
        .is_ok());
    assert!(workspace
        .configure_homework_recovery("../arbitrary")
        .is_err());
    let pending = workspace.pending_homework_submissions().await.unwrap();
    assert_eq!(pending[0].assignment_id, "spoc:a");
    assert_eq!(pending[0].file_name, "answer.pdf");
    assert_eq!(pending[0].size, 9);
    let evidence = workspace.homework_capabilities("spoc:a").await;
    assert_eq!(evidence[0].state, HomeworkCapabilityState::Unknown);
    assert_eq!(evidence[0].reason, "spoc:a");
}
