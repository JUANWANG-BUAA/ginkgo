//! These consumers compile without any school implementation, HTTP or vault.
use ginkgo_core::{
    application::{
        CheckInMutationSource, DataOutcome, NoticeSource, NoticesOutcome, RoutePreference,
        SessionOutcome, SessionSource, SessionStatus, Workspace,
    },
    features::{
        mutation::{MutationOutcome, MutationState},
        notices::Notice,
    },
    session::UserProfile,
    AppError,
};
use std::sync::{
    atomic::{AtomicUsize, Ordering},
    Arc, Mutex,
};

struct ReplacementNotices {
    calls: Arc<AtomicUsize>,
}
impl NoticeSource for ReplacementNotices {
    async fn load_notices(&self, force: bool) -> Result<NoticesOutcome, AppError> {
        self.calls.fetch_add(1, Ordering::SeqCst);
        Ok(DataOutcome {
            data: vec![Notice {
                title: "合成通知".into(),
                summary: String::new(),
                published_at: "2026-10-22".into(),
                url: "synthetic:notice".into(),
            }],
            failure: force.then(AppError::unavailable),
        })
    }
}

#[tokio::test]
async fn a_single_replacement_capability_preserves_fallback_data_and_failure() {
    let calls = Arc::new(AtomicUsize::new(0));
    let app = Workspace::new(ReplacementNotices {
        calls: calls.clone(),
    });
    let result = app.load_notices(true).await.expect("old data is usable");
    assert_eq!(result.data[0].title, "合成通知");
    assert_eq!(result.failure, Some(AppError::unavailable()));
    assert_eq!(calls.load(Ordering::SeqCst), 1);
}

struct UncertainWrite {
    calls: Arc<AtomicUsize>,
}
impl CheckInMutationSource for UncertainWrite {
    async fn submit_checkin(&self, _: &str) -> MutationOutcome {
        self.calls.fetch_add(1, Ordering::SeqCst);
        MutationOutcome::uncertain()
    }
}

#[tokio::test]
async fn an_uncertain_write_is_returned_without_replaying_the_command() {
    let calls = Arc::new(AtomicUsize::new(0));
    // No read, HTTP, credential or login capability is required for this test.
    let app = Workspace::new(UncertainWrite {
        calls: calls.clone(),
    });
    let result = app.submit_checkin("synthetic-course").await;
    assert_eq!(result.state, MutationState::Uncertain);
    assert_eq!(calls.load(Ordering::SeqCst), 1);
}

struct LocalIdentity {
    account: Arc<Mutex<Option<String>>>,
}
impl SessionSource for LocalIdentity {
    fn account(&self) -> Result<String, AppError> {
        self.account
            .lock()
            .expect("identity")
            .clone()
            .ok_or_else(AppError::session_expired)
    }
    fn status(&self) -> SessionStatus {
        let account = self.account().ok();
        SessionStatus {
            profile: account.as_ref().map(|account| UserProfile {
                school_id: account.clone(),
                name: "synthetic".into(),
            }),
            account,
            route: RoutePreference::Automatic,
        }
    }
    fn set_route(&self, _: RoutePreference) {}
    async fn sign_in(
        &self,
        _: &str,
        _: &str,
        _: Option<&str>,
        _: bool,
    ) -> Result<SessionOutcome, AppError> {
        Err(AppError::unavailable())
    }
    async fn restore(&self) -> Result<SessionOutcome, AppError> {
        Ok(SessionOutcome::SignedOut)
    }
    async fn sign_out(&self) {
        *self.account.lock().expect("identity") = None;
    }
    fn clear_snapshots(&self) {}
}

#[tokio::test]
async fn local_tasks_follow_the_injected_identity_and_remain_account_isolated() {
    let root = std::env::temp_dir().join(format!("ginkgo-port-{:x}", rand::random::<u64>()));
    let account = Arc::new(Mutex::new(Some("sy2501001".into())));
    let app = Workspace::new(LocalIdentity {
        account: account.clone(),
    });
    app.edit_tasks(
        &root,
        "add",
        None,
        Some("合成待办"),
        Some("2026-10-22"),
        None,
    )
    .expect("add");
    *account.lock().expect("switch identity") = Some("sy2501002".into());
    assert!(app
        .edit_tasks(&root, "load", None, None, None, None)
        .expect("other account")
        .is_empty());
    *account.lock().expect("switch back") = Some("sy2501001".into());
    assert_eq!(
        app.edit_tasks(&root, "load", None, None, None, None)
            .expect("first account")[0]
            .title,
        "合成待办"
    );
    app.sign_out().await;
    assert_eq!(
        app.edit_tasks(&root, "load", None, None, None, None)
            .expect_err("signed out"),
        AppError::session_expired()
    );
    std::fs::remove_dir_all(root).expect("remove synthetic files");
}

/// Clearing query snapshots and signing out must never touch the task
/// document: these are the user's own records, not cached school data.
#[tokio::test]
async fn clearing_snapshots_and_signing_out_preserve_local_task_documents() {
    let root = std::env::temp_dir().join(format!("ginkgo-port-{:x}", rand::random::<u64>()));
    let account = Arc::new(Mutex::new(Some("sy2501001".into())));
    let app = Workspace::new(LocalIdentity {
        account: account.clone(),
    });
    app.edit_tasks(
        &root,
        "add",
        None,
        Some("退登后仍在的待办"),
        Some("2026-10-22"),
        None,
    )
    .expect("add");

    app.clear_snapshots();
    assert_eq!(
        app.edit_tasks(&root, "load", None, None, None, None)
            .expect("tasks survive clear_snapshots")[0]
            .title,
        "退登后仍在的待办"
    );

    app.sign_out().await;
    *account.lock().expect("sign back in") = Some("sy2501001".into());
    assert_eq!(
        app.edit_tasks(&root, "load", None, None, None, None)
            .expect("tasks survive sign_out")[0]
            .title,
        "退登后仍在的待办"
    );
    std::fs::remove_dir_all(root).expect("remove synthetic files");
}
