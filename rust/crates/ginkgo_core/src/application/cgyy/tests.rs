//! Offline-only ports; no transport, school endpoint or real identity is constructed.
use super::*;
use crate::ErrorCode;
use serde_json::{json, Value};
use sha1::{Digest, Sha1};
use std::{
    collections::VecDeque,
    fs,
    path::PathBuf,
    sync::{
        atomic::{AtomicU64, Ordering},
        Mutex,
    },
};

const ACCOUNT: &str = "synthetic-cgyy-account-a";
const MARKER: &[u8] = br#"{"version":1,"pending":true}"#;
static NEXT_TEMP: AtomicU64 = AtomicU64::new(0);

struct TempRoot(PathBuf);
impl TempRoot {
    fn new() -> Self {
        let root = std::env::temp_dir().join(format!(
            "ginkgo-cgyy-core-{}-{}-{}",
            std::process::id(),
            NEXT_TEMP.fetch_add(1, Ordering::Relaxed),
            rand::random::<u64>()
        ));
        fs::create_dir(&root).expect("create isolated test directory");
        Self(root)
    }
    fn marker(&self, account: &str) -> PathBuf {
        self.0.join(format!(
            "cgyy-pending-{:x}.json",
            Sha1::digest(account.as_bytes())
        ))
    }
}
impl Drop for TempRoot {
    fn drop(&mut self) {
        // Only ever clean up this fixture's verified absolute, unique temp directory.
        assert!(self.0.is_absolute());
        assert_eq!(self.0.parent(), Some(std::env::temp_dir().as_path()));
        assert!(self
            .0
            .file_name()
            .expect("temp name")
            .to_string_lossy()
            .starts_with("ginkgo-cgyy-core-"));
        fs::remove_dir_all(&self.0).expect("remove isolated test directory");
    }
}

struct Mock {
    account: Option<String>,
    root: Option<PathBuf>,
    calls: Mutex<Vec<&'static str>>,
    replies: Mutex<VecDeque<Result<CgyyActionResult, AppError>>>,
    context: Mutex<bool>,
    reviewed: Mutex<bool>,
}
impl Mock {
    fn new(account: &str, root: Option<&Path>) -> Self {
        Self {
            account: Some(account.into()),
            root: root.map(Path::to_path_buf),
            calls: Mutex::new(Vec::new()),
            replies: Mutex::new(VecDeque::new()),
            context: Mutex::new(false),
            reviewed: Mutex::new(false),
        }
    }
    fn reply(&self, state: &str) {
        self.replies
            .lock()
            .expect("replies")
            .push_back(Ok(CgyyActionResult::message(state, "synthetic")));
    }
    fn fail(&self) {
        self.replies
            .lock()
            .expect("replies")
            .push_back(Err(AppError::unavailable()));
    }
    fn calls(&self) -> Vec<&'static str> {
        self.calls.lock().expect("calls").clone()
    }
}
impl CgyyMutationSource for Mock {
    async fn execute_cgyy(&self, command: CgyyCommand) -> Result<CgyyActionResult, AppError> {
        let action = match &command {
            CgyyCommand::Prepare { .. } => "prepare",
            CgyyCommand::Submit { .. } => "submit",
            CgyyCommand::Cancel { .. } => "cancel",
            CgyyCommand::Status => "status",
            CgyyCommand::Review => "review",
            CgyyCommand::Acknowledge { .. } => "acknowledge",
            CgyyCommand::Options { .. } => "options",
        };
        self.calls.lock().expect("calls").push(action);
        if matches!(action, "prepare" | "submit" | "cancel") {
            let root = self.root.as_ref().expect("write has storage root");
            let store = PendingStore::new(root, self.account.as_deref().expect("account"))?;
            assert_eq!(
                store.inspect()?,
                Pending::Present,
                "marker must exist BEFORE port dispatch"
            );
        }
        if let Some(reply) = self.replies.lock().expect("replies").pop_front() {
            return reply;
        }
        let state = match command {
            CgyyCommand::Prepare { .. } => {
                *self.context.lock().expect("context") = true;
                "challenge"
            }
            CgyyCommand::Submit { challenge_id, .. } => {
                // Model the upstream one-shot in-memory context, not disk recovery.
                if !std::mem::take(&mut *self.context.lock().expect("context"))
                    || challenge_id != "fixture-challenge"
                {
                    return Err(AppError::invalid());
                }
                "uncertain"
            }
            CgyyCommand::Cancel { .. } => "uncertain",
            CgyyCommand::Status => "ready",
            CgyyCommand::Review => {
                *self.reviewed.lock().expect("reviewed") = true;
                "review"
            }
            CgyyCommand::Acknowledge { review_id } => {
                if review_id != "fixture-review"
                    || !std::mem::take(&mut *self.reviewed.lock().expect("reviewed"))
                {
                    return Err(AppError::invalid());
                }
                "reviewed"
            }
            CgyyCommand::Options { .. } => "options",
        };
        Ok(CgyyActionResult::message(state, "synthetic"))
    }
}
impl SessionSource for Mock {
    fn status(&self) -> SessionStatus {
        SessionStatus {
            account: self.account.clone(),
            profile: None,
            route: RoutePreference::Automatic,
        }
    }
    fn account(&self) -> Result<String, AppError> {
        self.account.clone().ok_or_else(AppError::session_expired)
    }
    fn set_route(&self, _: RoutePreference) {}
    async fn sign_in(
        &self,
        _: &str,
        _: &str,
        _: Option<&str>,
        _: bool,
    ) -> Result<SessionOutcome, AppError> {
        Err(AppError::invalid())
    }
    async fn restore(&self) -> Result<SessionOutcome, AppError> {
        Err(AppError::invalid())
    }
    async fn sign_out(&self) {}
    async fn purge_credentials(&self) {}
    fn clear_snapshots(&self) {}
}

fn command(action: &str) -> Value {
    match action {
        "prepare" => json!({"action": action, "booking": {
            "site_id": 1, "date": "2026-10-22", "space_id": 2, "time_ids": [3],
            "phone": "10000000000", "theme": "synthetic-private-form", "purpose_type": 1,
            "joiner_num": 1, "activity_content": "synthetic-private-activity", "joiners": "synthetic-private-joiner",
            "philosophy": false, "off_school": false
        }}),
        "submit" => json!({"action": action, "challenge_id": "fixture-challenge", "x": 10}),
        "cancel" => json!({"action": action, "order_id": 123}),
        "options" => json!({"action": action, "site_id": 1, "date": "2026-10-22"}),
        "acknowledge" => json!({"action": action, "review_id": "fixture-review"}),
        _ => json!({"action": action}),
    }
}
async fn run(
    workspace: &Workspace<Mock>,
    root: &Path,
    action: &str,
) -> Result<CgyyActionResult, AppError> {
    let mut value = command(action);
    value["storage_root"] = json!(root);
    workspace.execute_cgyy_json(&value.to_string()).await
}
fn state(result: Result<CgyyActionResult, AppError>) -> String {
    result.expect("result").state
}
fn error(result: Result<CgyyActionResult, AppError>) -> ErrorCode {
    match result {
        Err(error) => error.code,
        Ok(_) => panic!("expected error"),
    }
}

#[tokio::test]
async fn serial_prepare_submit_keeps_marker_and_blocks_second_writes() {
    let root = TempRoot::new();
    let workspace = Workspace::new(Mock::new(ACCOUNT, Some(&root.0)));
    assert_eq!(
        state(run(&workspace, &root.0, "prepare").await),
        "challenge"
    );
    assert_eq!(fs::read(root.marker(ACCOUNT)).expect("marker"), MARKER);
    assert_eq!(
        state(run(&workspace, &root.0, "prepare").await),
        "uncertain"
    );
    assert_eq!(state(run(&workspace, &root.0, "cancel").await), "uncertain");
    assert_eq!(workspace.upstream.calls(), ["prepare"]);
    assert_eq!(state(run(&workspace, &root.0, "submit").await), "uncertain");
    assert_eq!(
        error(run(&workspace, &root.0, "submit").await),
        ErrorCode::InvalidRequest
    );
    assert!(root.marker(ACCOUNT).exists());
}

#[tokio::test]
async fn reconstruction_same_account_locks_and_old_challenge_has_no_context() {
    let root = TempRoot::new();
    {
        let workspace = Workspace::new(Mock::new(ACCOUNT, Some(&root.0)));
        assert_eq!(
            state(run(&workspace, &root.0, "prepare").await),
            "challenge"
        );
    }
    let rebuilt = Workspace::new(Mock::new(ACCOUNT, Some(&root.0)));
    assert_eq!(state(run(&rebuilt, &root.0, "status").await), "uncertain");
    assert_eq!(state(run(&rebuilt, &root.0, "cancel").await), "uncertain");
    assert_eq!(state(run(&rebuilt, &root.0, "prepare").await), "uncertain");
    assert_eq!(rebuilt.upstream.calls(), ["status"]);
    assert_eq!(
        error(run(&rebuilt, &root.0, "submit").await),
        ErrorCode::InvalidRequest
    );
    assert!(root.marker(ACCOUNT).exists());
}

#[tokio::test]
async fn first_submit_creates_marker_before_dispatch() {
    let root = TempRoot::new();
    let workspace = Workspace::new(Mock::new(ACCOUNT, Some(&root.0)));
    assert_eq!(
        error(run(&workspace, &root.0, "submit").await),
        ErrorCode::InvalidRequest
    );
    assert_eq!(workspace.upstream.calls(), ["submit"]);
    assert_eq!(fs::read(root.marker(ACCOUNT)).expect("marker"), MARKER);
}

#[tokio::test]
async fn only_explicit_terminal_states_clear_marker() {
    for terminal in ["accepted", "rejected", "notSubmitted", "not_submitted"] {
        let root = TempRoot::new();
        let workspace = Workspace::new(Mock::new(ACCOUNT, Some(&root.0)));
        workspace.upstream.reply(terminal);
        assert_eq!(state(run(&workspace, &root.0, "cancel").await), terminal);
        assert!(!root.marker(ACCOUNT).exists());
        assert_eq!(state(run(&workspace, &root.0, "status").await), "ready");
    }
    for nonterminal in [
        "challenge",
        "uncertain",
        "unknown",
        "ready",
        "",
        "Accepted",
        "review",
    ] {
        let root = TempRoot::new();
        let workspace = Workspace::new(Mock::new(ACCOUNT, Some(&root.0)));
        workspace.upstream.reply(nonterminal);
        assert_eq!(state(run(&workspace, &root.0, "cancel").await), nonterminal);
        assert!(root.marker(ACCOUNT).exists());
    }
}

#[tokio::test]
async fn errors_preserve_marker_and_status_merges_both_sources() {
    let root = TempRoot::new();
    let workspace = Workspace::new(Mock::new(ACCOUNT, Some(&root.0)));
    workspace.upstream.reply("uncertain");
    assert_eq!(state(run(&workspace, &root.0, "status").await), "uncertain");
    workspace.upstream.fail();
    assert_eq!(
        error(run(&workspace, &root.0, "cancel").await),
        ErrorCode::ServiceUnavailable
    );
    assert!(root.marker(ACCOUNT).exists());
    assert_eq!(state(run(&workspace, &root.0, "status").await), "uncertain");
    workspace.upstream.fail();
    assert_eq!(state(run(&workspace, &root.0, "status").await), "uncertain");
}

#[tokio::test]
async fn malformed_markers_lock_all_writes_without_overwriting() {
    for bytes in [
        b"".as_slice(),
        b"{",
        br#"{"version":2,"pending":true}"#,
        br#"{"version":1,"pending":false}"#,
        br#"{"version":1,"pending":true,"token":"fixture-secret"}"#,
        br#"{"version":1,"version":1,"pending":true}"#,
    ] {
        let root = TempRoot::new();
        fs::write(root.marker(ACCOUNT), bytes).expect("corrupt marker");
        let workspace = Workspace::new(Mock::new(ACCOUNT, Some(&root.0)));
        for action in ["prepare", "cancel", "submit", "status"] {
            assert_eq!(state(run(&workspace, &root.0, action).await), "uncertain");
        }
        assert_eq!(workspace.upstream.calls(), ["status"]);
        assert_eq!(fs::read(root.marker(ACCOUNT)).expect("unchanged"), bytes);
    }
}

#[tokio::test]
async fn review_never_clears_and_ack_requires_valid_fresh_review() {
    let root = TempRoot::new();
    fs::write(root.marker(ACCOUNT), b"malformed").expect("corrupt marker");
    let workspace = Workspace::new(Mock::new(ACCOUNT, Some(&root.0)));
    assert_eq!(
        error(run(&workspace, &root.0, "acknowledge").await),
        ErrorCode::InvalidRequest
    );
    assert_eq!(
        fs::read(root.marker(ACCOUNT)).expect("unchanged"),
        b"malformed"
    );
    assert_eq!(state(run(&workspace, &root.0, "review").await), "review");
    assert!(root.marker(ACCOUNT).exists());
    let mut invalid = command("acknowledge");
    invalid["storage_root"] = json!(root.0);
    invalid["review_id"] = json!("wrong-review");
    assert_eq!(
        error(workspace.execute_cgyy_json(&invalid.to_string()).await),
        ErrorCode::InvalidRequest
    );
    assert!(root.marker(ACCOUNT).exists());
    assert_eq!(state(run(&workspace, &root.0, "review").await), "review");
    assert_eq!(
        state(run(&workspace, &root.0, "acknowledge").await),
        "ready"
    );
    assert!(!root.marker(ACCOUNT).exists());
    assert_eq!(state(run(&workspace, &root.0, "status").await), "ready");
    assert_eq!(state(run(&workspace, &root.0, "cancel").await), "uncertain");
    assert!(root.marker(ACCOUNT).exists());
}

#[tokio::test]
async fn ack_nonready_or_error_does_not_clear_and_cleanup_failure_never_returns_ready() {
    let root = TempRoot::new();
    fs::write(root.marker(ACCOUNT), MARKER).expect("marker");
    let workspace = Workspace::new(Mock::new(ACCOUNT, Some(&root.0)));
    for reply in ["uncertain", "accepted", "rejected", "unknown"] {
        workspace.upstream.reply(reply);
        assert_eq!(state(run(&workspace, &root.0, "acknowledge").await), reply);
        assert!(root.marker(ACCOUNT).exists());
    }
    workspace.upstream.fail();
    assert_eq!(
        error(run(&workspace, &root.0, "acknowledge").await),
        ErrorCode::ServiceUnavailable
    );
    assert!(root.marker(ACCOUNT).exists());
    // A directory at the marker path cannot be silently removed by clear().
    fs::remove_file(root.marker(ACCOUNT)).expect("remove fixture marker");
    fs::create_dir(root.marker(ACCOUNT)).expect("unremovable marker entry");
    assert_eq!(state(run(&workspace, &root.0, "review").await), "review");
    assert_eq!(
        error(run(&workspace, &root.0, "acknowledge").await),
        ErrorCode::ServiceUnavailable
    );
    assert!(root.marker(ACCOUNT).is_dir());
    assert_eq!(state(run(&workspace, &root.0, "status").await), "uncertain");
}

#[tokio::test]
async fn account_and_root_isolation_ignores_caller_supplied_account() {
    let root = TempRoot::new();
    let other_root = TempRoot::new();
    let workspace = Workspace::new(Mock::new(ACCOUNT, Some(&root.0)));
    let mut value = command("cancel");
    value["storage_root"] = json!(root.0);
    value["account"] = json!("caller-controlled-account");
    assert_eq!(
        state(workspace.execute_cgyy_json(&value.to_string()).await),
        "uncertain"
    );
    assert!(root.marker(ACCOUNT).exists());
    assert!(!root.marker("caller-controlled-account").exists());
    let other = Workspace::new(Mock::new("synthetic-cgyy-account-b", Some(&root.0)));
    assert_eq!(state(run(&other, &root.0, "status").await), "ready");
    assert_eq!(state(run(&other, &root.0, "cancel").await), "uncertain");
    assert!(root.marker("synthetic-cgyy-account-b").exists());
    let isolated = Workspace::new(Mock::new(ACCOUNT, Some(&other_root.0)));
    assert_eq!(
        state(run(&isolated, &other_root.0, "status").await),
        "ready"
    );
}

#[tokio::test]
async fn marker_contains_no_account_form_challenge_or_credentials() {
    let root = TempRoot::new();
    let workspace = Workspace::new(Mock::new(ACCOUNT, Some(&root.0)));
    let mut value = command("prepare");
    value["storage_root"] = json!(root.0);
    value["password"] = json!("synthetic-password");
    value["school_token"] = json!("synthetic-token");
    state(workspace.execute_cgyy_json(&value.to_string()).await);
    let entries: Vec<_> = fs::read_dir(&root.0)
        .expect("entries")
        .map(|entry| entry.expect("entry").path())
        .collect();
    assert_eq!(entries, [root.marker(ACCOUNT)]);
    assert!(!entries[0]
        .file_name()
        .expect("name")
        .to_string_lossy()
        .contains(ACCOUNT));
    assert_eq!(fs::read(&entries[0]).expect("minimal marker"), MARKER);
    let result = serde_json::to_string(&run(&workspace, &root.0, "status").await.expect("status"))
        .expect("JSON");
    for secret in [
        ACCOUNT,
        "synthetic-private-form",
        "synthetic-password",
        "synthetic-token",
        "fixture-challenge",
    ] {
        assert!(!result.contains(secret));
    }
}

#[tokio::test]
async fn missing_or_invalid_root_is_rejected_without_dispatch_and_reads_remain_compatible() {
    let root = TempRoot::new();
    let workspace = Workspace::new(Mock::new(ACCOUNT, Some(&root.0)));
    for action in ["status", "prepare", "submit", "cancel", "acknowledge"] {
        assert_eq!(
            error(
                workspace
                    .execute_cgyy_json(&command(action).to_string())
                    .await
            ),
            ErrorCode::InvalidRequest
        );
        for invalid in [json!(null), json!(""), json!("relative"), json!(17)] {
            let mut value = command(action);
            value["storage_root"] = invalid;
            assert_eq!(
                error(workspace.execute_cgyy_json(&value.to_string()).await),
                ErrorCode::InvalidRequest
            );
        }
    }
    assert_eq!(
        error(
            workspace
                .execute_cgyy(CgyyCommand::Cancel { order_id: 1 })
                .await
        ),
        ErrorCode::InvalidRequest
    );
    assert!(workspace.upstream.calls().is_empty());
    for action in ["options", "review"] {
        assert_eq!(
            state(
                workspace
                    .execute_cgyy_json(&command(action).to_string())
                    .await
            ),
            action
        );
    }
    assert!(!root.marker(ACCOUNT).exists());
}

#[tokio::test]
async fn missing_session_never_uses_caller_account() {
    let root = TempRoot::new();
    let mut mock = Mock::new(ACCOUNT, Some(&root.0));
    mock.account = None;
    let workspace = Workspace::new(mock);
    let mut value = command("cancel");
    value["storage_root"] = json!(root.0);
    value["account"] = json!(ACCOUNT);
    assert_eq!(
        error(workspace.execute_cgyy_json(&value.to_string()).await),
        ErrorCode::SessionExpired
    );
    assert!(workspace.upstream.calls().is_empty());
    assert!(!root.marker(ACCOUNT).exists());
}

#[tokio::test]
async fn invalid_filesystem_root_never_dispatches_writes() {
    let root = TempRoot::new();
    let file_root = root.0.join("not-a-directory");
    fs::write(&file_root, b"fixture").expect("root obstruction");
    let workspace = Workspace::new(Mock::new(ACCOUNT, Some(&file_root)));
    for action in ["prepare", "cancel", "submit"] {
        // An inaccessible/invalid marker path is locked, not treated as absent.
        assert_eq!(
            state(run(&workspace, &file_root, action).await),
            "uncertain"
        );
    }
    assert!(workspace.upstream.calls().is_empty());
    assert_eq!(
        fs::read(&file_root).expect("unchanged obstruction"),
        b"fixture"
    );
}

#[cfg(unix)]
#[tokio::test]
async fn denied_creation_and_unreadable_marker_fail_closed() {
    use std::os::unix::fs::PermissionsExt;
    let root = TempRoot::new();
    fs::set_permissions(&root.0, fs::Permissions::from_mode(0o500)).expect("deny creation");
    let workspace = Workspace::new(Mock::new(ACCOUNT, Some(&root.0)));
    let result = run(&workspace, &root.0, "cancel").await;
    fs::set_permissions(&root.0, fs::Permissions::from_mode(0o700)).expect("restore permissions");
    assert_eq!(error(result), ErrorCode::ServiceUnavailable);
    assert!(workspace.upstream.calls().is_empty());
    assert!(!root.marker(ACCOUNT).exists());
    fs::write(root.marker(ACCOUNT), MARKER).expect("marker");
    fs::set_permissions(root.marker(ACCOUNT), fs::Permissions::from_mode(0o000))
        .expect("deny reading");
    for action in ["prepare", "cancel", "submit", "status"] {
        assert_eq!(state(run(&workspace, &root.0, action).await), "uncertain");
    }
    assert_eq!(workspace.upstream.calls(), ["status"]);
    state(run(&workspace, &root.0, "review").await);
    assert_eq!(
        state(run(&workspace, &root.0, "acknowledge").await),
        "ready"
    );
    assert!(!root.marker(ACCOUNT).exists());
}

#[tokio::test]
async fn expected_account_mismatch_precedes_every_file_and_port_action() {
    let root = TempRoot::new();
    fs::write(root.marker(ACCOUNT), b"malformed").expect("fixture marker");
    let workspace = Workspace::new(Mock::new(ACCOUNT, Some(&root.0)));
    for action in [
        "options",
        "review",
        "status",
        "prepare",
        "submit",
        "cancel",
        "acknowledge",
    ] {
        let mut value = command(action);
        value["storage_root"] = json!(root.0);
        value["expected_account"] = json!("synthetic-previous-session-account");
        value["account"] = json!(ACCOUNT);
        assert_eq!(
            error(workspace.execute_cgyy_json(&value.to_string()).await),
            ErrorCode::SessionExpired
        );
        assert_eq!(
            fs::read(root.marker(ACCOUNT)).expect("unchanged"),
            b"malformed"
        );
    }
    assert!(workspace.upstream.calls().is_empty());
    let mut review = command("review");
    review["expected_account"] = json!(ACCOUNT);
    assert_eq!(
        state(workspace.execute_cgyy_json(&review.to_string()).await),
        "review"
    );
    let mut ack = command("acknowledge");
    ack["storage_root"] = json!(root.0);
    ack["expected_account"] = json!(ACCOUNT);
    assert_eq!(
        state(workspace.execute_cgyy_json(&ack.to_string()).await),
        "ready"
    );
    assert!(!root.marker(ACCOUNT).exists());
}

#[tokio::test]
async fn invalid_expected_account_is_not_ignored() {
    let root = TempRoot::new();
    let workspace = Workspace::new(Mock::new(ACCOUNT, Some(&root.0)));
    for expected in [json!(null), json!(""), json!("   "), json!(17)] {
        let mut value = command("cancel");
        value["storage_root"] = json!(root.0);
        value["expected_account"] = expected;
        assert_eq!(
            error(workspace.execute_cgyy_json(&value.to_string()).await),
            ErrorCode::InvalidRequest
        );
    }
    assert!(workspace.upstream.calls().is_empty());
    assert!(!root.marker(ACCOUNT).exists());
}

#[tokio::test]
async fn legacy_ready_ack_is_normalized_only_after_disk_cleanup() {
    let root = TempRoot::new();
    fs::write(root.marker(ACCOUNT), MARKER).expect("marker");
    let workspace = Workspace::new(Mock::new(ACCOUNT, Some(&root.0)));
    workspace.upstream.reply("ready");
    assert_eq!(
        state(run(&workspace, &root.0, "acknowledge").await),
        "ready"
    );
    assert!(!root.marker(ACCOUNT).exists());
}

#[tokio::test]
async fn oversized_or_directory_marker_is_locked_not_missing() {
    for directory in [false, true] {
        let root = TempRoot::new();
        if directory {
            fs::create_dir(root.marker(ACCOUNT)).expect("marker directory");
        } else {
            fs::write(root.marker(ACCOUNT), vec![b' '; 257]).expect("oversized marker");
        }
        let workspace = Workspace::new(Mock::new(ACCOUNT, Some(&root.0)));
        for action in ["prepare", "submit", "cancel", "status"] {
            assert_eq!(state(run(&workspace, &root.0, action).await), "uncertain");
        }
        assert_eq!(workspace.upstream.calls(), ["status"]);
    }
}

#[cfg(unix)]
#[tokio::test]
async fn symlink_marker_locks_without_touching_its_target() {
    let root = TempRoot::new();
    let target = root.0.join("unrelated-fixture");
    fs::write(&target, MARKER).expect("target");
    std::os::unix::fs::symlink(&target, root.marker(ACCOUNT)).expect("symlink");
    let workspace = Workspace::new(Mock::new(ACCOUNT, Some(&root.0)));
    for action in ["prepare", "submit", "cancel"] {
        assert_eq!(state(run(&workspace, &root.0, action).await), "uncertain");
    }
    assert!(workspace.upstream.calls().is_empty());
    state(run(&workspace, &root.0, "review").await);
    assert_eq!(
        state(run(&workspace, &root.0, "acknowledge").await),
        "ready"
    );
    assert!(!root.marker(ACCOUNT).exists());
    assert_eq!(fs::read(target).expect("untouched target"), MARKER);
}

#[test]
fn synchronous_create_new_has_only_one_initial_winner() {
    let root = TempRoot::new();
    let successes: usize = std::thread::scope(|scope| {
        let handles: Vec<_> = (0..8)
            .map(|_| {
                scope.spawn(|| {
                    PendingStore::new(&root.0, ACCOUNT)
                        .expect("store")
                        .create()
                        .expect("create") as usize
                })
            })
            .collect();
        handles
            .into_iter()
            .map(|handle| handle.join().expect("thread"))
            .sum()
    });
    assert_eq!(successes, 1);
    assert_eq!(fs::read(root.marker(ACCOUNT)).expect("marker"), MARKER);
}
