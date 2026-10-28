//! Account-bound file capabilities; read eligibility, upload, explicit single write, reconcile.
mod capabilities;
mod journal;
use super::session_service::SchoolClient;
use crate::{
    adapters::{homework_files_http as protocol, homework_http},
    auth::CredentialVault,
    foundation::http::HttpTransport,
    AppError, ErrorCode,
};
use ginkgo_domain::{
    features::mutation::{MutationOutcome, MutationState},
    ports::*,
};
use std::{
    collections::BTreeMap,
    time::{Duration, Instant},
};
#[derive(Clone, Copy, PartialEq)]
enum State {
    Ready,
    Sent,
    Accepted,
}
struct Upload {
    owner: (String, u64),
    assignment: String,
    course: String,
    file: String,
    name: String,
    size: u64,
    created: Instant,
    state: State,
    baseline: u32,
}
#[derive(Default)]
pub(crate) struct HomeworkFiles {
    root: Option<std::path::PathBuf>,
    uploads: BTreeMap<String, Upload>,
}

impl<T: HttpTransport + Send + Sync, V: CredentialVault> SchoolClient<T, V> {
    /// Root of the restart journal, read under the lock but never guessed.
    fn journal_root(&self) -> Result<std::path::PathBuf, AppError> {
        let files = self.homework_files.lock();
        journal::root_of(&files)
    }

    /// Rehydrate the restart journal without holding a lock across the disk
    /// work. Reading a directory and fsyncing it blocks the OS thread, so it
    /// runs on a blocking thread; only the merge touches shared state.
    async fn restore_journal(&self, owner: &(String, u64)) -> Result<(), AppError> {
        let root = self.journal_root()?;
        let owner_copy = owner.clone();
        let read = tokio::task::spawn_blocking(move || journal::read_records(&root, &owner_copy))
            .await
            .unwrap_or_else(|_| Err(AppError::unavailable()))?;
        journal::apply_restore(&mut self.homework_files.lock(), owner, read)
    }
}

impl<T: HttpTransport + Send + Sync, V: CredentialVault> SchoolClient<T, V> {
    fn homework_owner(&self) -> Result<(String, u64), AppError> {
        let i = self.identity.lock();
        Ok((
            i.authenticated
                .as_ref()
                .ok_or_else(AppError::session_expired)?
                .account
                .clone(),
            i.generation,
        ))
    }
    fn check_homework_owner(&self, owner: &(String, u64)) -> Result<(), AppError> {
        if &self.homework_owner()? != owner {
            Err(AppError::session_expired())
        } else {
            Ok(())
        }
    }
    async fn homework_context(&self, id: &str) -> Result<protocol::Context, AppError> {
        let mut context = protocol::load(&self.session, id).await?;
        // Account role is not course membership; require explicit student course ownership.
        let course = protocol::course_id(&context).unwrap_or_default();
        let students =
            homework_http::course_ids(&self.session, &context.auth, "/kc/queryXskcListPage")
                .await?;
        context.student_owned = students.contains(&course);
        if !context.student_owned {
            context.workspace.can_submit_file = false;
            context.workspace.blocked_reason = Some("未确认当前课程的学生身份，请前往官网".into());
        }
        Ok(context)
    }
    fn accept_homework(&self, owner: &(String, u64), handle: &str) -> bool {
        {
            let identity = self.identity.lock();
            if identity.generation != owner.1
                || identity
                    .authenticated
                    .as_ref()
                    .is_none_or(|identity| identity.account != owner.0)
            {
                return false;
            }
        }
        // Snapshot the deletion target under the lock; delete outside it.
        let target = {
            let files = self.homework_files.lock();
            if !files.uploads.get(handle).is_some_and(|u| u.owner == *owner) {
                return false;
            }
            journal::clear_target(&files, handle)
        };
        let Ok((path, file, assignment)) = target else {
            return false;
        };
        if journal::clear_record(&path, handle, &file, &assignment).is_err() {
            return false;
        }
        let mut files = self.homework_files.lock();
        if let Some(upload) = files.uploads.get_mut(handle) {
            upload.state = State::Accepted;
            true
        } else {
            false
        }
    }
    fn invalidate_homework(&self) {
        self.snapshots.homework.lock().clear();
        self.snapshots.homework_details.lock().clear();
    }
}
impl<T: HttpTransport + Send + Sync, V: CredentialVault> HomeworkSubmissionSource
    for SchoolClient<T, V>
{
    fn configure_homework_recovery(&self, root: &str) -> Result<(), AppError> {
        // Validate the private directory before taking the lock: this is a
        // syscall pair, not shared state.
        let path = journal::prepare_root(root)?;
        journal::adopt_root(&mut self.homework_files.lock(), &path)
    }
    async fn pending_homework_submissions(
        &self,
    ) -> Result<Vec<HomeworkPendingSubmission>, AppError> {
        let _gate = self.homework_file_gate.lock().await;
        let owner = self.homework_owner()?;
        self.restore_journal(&owner).await?;
        let files = self.homework_files.lock();
        let result = files
            .uploads
            .iter()
            .filter(|(_, u)| u.owner == owner && u.state == State::Sent)
            .map(|(handle, u)| HomeworkPendingSubmission {
                handle: handle.clone(),
                assignment_id: format!("spoc:{}", u.assignment),
                file_name: u.name.clone(),
                size: u.size,
            })
            .collect();
        drop(files);
        self.check_homework_owner(&owner)?;
        Ok(result)
    }
    async fn homework_capabilities(&self, id: &str) -> Vec<HomeworkCapabilityEvidence> {
        self.diagnose_homework(id).await
    }
    async fn homework_workspace(&self, id: &str) -> Result<HomeworkWorkspace, AppError> {
        let _gate = self.homework_file_gate.lock().await;
        let owner = self.homework_owner()?;
        let context = self
            .homework_context(id.strip_prefix("spoc:").unwrap_or(id))
            .await?;
        self.check_homework_owner(&owner)?;
        Ok(context.workspace)
    }
    async fn upload_homework_file(
        &self,
        id: &str,
        name: &str,
        bytes: Vec<u8>,
    ) -> Result<HomeworkUploadReceipt, AppError> {
        let _gate = self
            .homework_file_gate
            .try_lock()
            .map_err(|_| AppError::invalid())?;
        validate_homework_file(name, bytes.len())?;
        let owner = self.homework_owner()?;
        // Prove restart protection before the first upload side effect.
        self.restore_journal(&owner).await?;
        let id = id.strip_prefix("spoc:").unwrap_or(id);
        if self
            .homework_files
            .lock()
            .uploads
            .values()
            .any(|u| u.owner == owner && u.assignment == id && u.state == State::Sent)
        {
            return Err(AppError::with_detail(
                ErrorCode::BusinessRejected,
                "homework_submission_pending",
            ));
        }
        let context = self.homework_context(id).await?;
        self.check_homework_owner(&owner)?;
        if !protocol::accepts(&context.workspace, name) {
            return Err(AppError::new(ErrorCode::BusinessRejected));
        }
        let course = protocol::course_id(&context)?;
        // Reserve capacity before side effects. Never evict an unresolved submission.
        {
            let mut files = self.homework_files.lock();
            files.uploads.retain(|_, u| {
                u.owner == owner
                    && (u.state == State::Sent || u.created.elapsed() < Duration::from_secs(900))
            });
            if files
                .uploads
                .values()
                .any(|u| u.owner == owner && u.assignment == id && u.state == State::Sent)
                || files.uploads.len() >= 8
            {
                return Err(AppError::invalid());
            }
        }
        let file = protocol::upload_checked(&self.session, &context.auth, name, &bytes, || {
            self.check_homework_owner(&owner)
        })
        .await?;
        self.check_homework_owner(&owner)?;
        let handle = format!(
            "{:032x}{:032x}",
            rand::random::<u128>(),
            rand::random::<u128>()
        );
        let size = bytes.len() as u64;
        self.homework_files.lock().uploads.insert(
            handle.clone(),
            Upload {
                owner,
                assignment: id.into(),
                course,
                file,
                name: name.into(),
                size,
                created: Instant::now(),
                state: State::Ready,
                baseline: 0,
            },
        );
        Ok(HomeworkUploadReceipt {
            handle,
            file_name: name.into(),
            size,
        })
    }
    async fn submit_homework_file(&self, handle: &str, confirmed: bool) -> MutationOutcome {
        if !confirmed {
            return MutationOutcome::not_submitted("请先确认作业和文件");
        }
        let Ok(_gate) = self.homework_file_gate.try_lock() else {
            return MutationOutcome::not_submitted("作业操作正在处理，请勿重复提交");
        };
        let Ok(owner) = self.homework_owner() else {
            return MutationOutcome::not_submitted("登录已失效");
        };
        if self.restore_journal(&owner).await.is_err() {
            return MutationOutcome::not_submitted(
                "待核实保护记录不可用，请先检查本机数据，尚未提交",
            );
        }
        let data = {
            let files = self.homework_files.lock();
            match files.uploads.get(handle) {
                Some(u)
                    if u.owner == owner
                        && u.state == State::Ready
                        && u.created.elapsed() < Duration::from_secs(900) =>
                {
                    Some((
                        u.assignment.clone(),
                        u.course.clone(),
                        u.file.clone(),
                        u.name.clone(),
                    ))
                }
                _ => None,
            }
        };
        let Some((id, course, file, name)) = data else {
            return MutationOutcome::not_submitted("上传凭据过期、已使用或结果待核实，请勿重发");
        };
        if self
            .homework_files
            .lock()
            .uploads
            .values()
            .any(|u| u.owner == owner && u.assignment == id && u.state == State::Sent)
        {
            return MutationOutcome::not_submitted("此作业已有待核实提交，请先回查，勿重发");
        }
        let context = match self.homework_context(&id).await {
            Ok(c) => c,
            Err(_) => return MutationOutcome::not_submitted("无法核实当前作业状态，尚未提交"),
        };
        if self.check_homework_owner(&owner).is_err()
            || !protocol::accepts(&context.workspace, &name)
            || protocol::course_id(&context).ok().as_deref() != Some(&course)
        {
            return MutationOutcome::not_submitted("身份、作业限制或课程已变化，尚未提交");
        }
        let baseline = context.workspace.submitted_count.unwrap_or(0);
        // Hold identity through durable creation. Any cancellation after this point leaves
        // a restart-safe read-only reconciliation handle, never a retryable final write.
        {
            let identity = self.identity.lock();
            if identity.generation != owner.1
                || identity
                    .authenticated
                    .as_ref()
                    .is_none_or(|identity| identity.account != owner.0)
            {
                return MutationOutcome::not_submitted("身份已变化，尚未提交");
            }
        }
        // Snapshot the record under the lock, then fsync outside it: writing and
        // syncing a file blocks the OS thread, which must not hold the journal.
        let (record_root, record) = {
            let files = self.homework_files.lock();
            match (
                journal::root_of(&files),
                journal::record(&files, handle, baseline),
            ) {
                (Ok(root), Ok(record)) => (root, record),
                _ => return MutationOutcome::not_submitted("上传凭据已失效，尚未提交"),
            }
        };
        let account = owner.0.clone();
        let written = tokio::task::spawn_blocking(move || {
            journal::write_record(&record_root, &account, &record)
        })
        .await
        .unwrap_or_else(|_| Err(AppError::unavailable()));
        if written.is_err() {
            return MutationOutcome::not_submitted(
                "无法持久保存待核实保护记录，尚未提交；请检查本机存储",
            );
        }
        {
            let mut files = self.homework_files.lock();
            let Some(upload) = files.uploads.get_mut(handle) else {
                return MutationOutcome::not_submitted("上传凭据已失效，尚未提交");
            };
            // Recheck the owner under the lock: the fsync above released it.
            if upload.owner != owner {
                return MutationOutcome::not_submitted("身份已变化，尚未提交");
            }
            upload.state = State::Sent;
            upload.baseline = baseline;
        }
        self.invalidate_homework();
        let _ack = protocol::submit(&self.session, &context.auth, &id, &course, &file, &name).await;
        if self.check_homework_owner(&owner).is_err() {
            return MutationOutcome::uncertain();
        }
        let result = protocol::submission(&self.session, &context.auth, &id).await;
        self.invalidate_homework();
        if self.check_homework_owner(&owner).is_err() {
            return MutationOutcome::uncertain();
        }
        if result.is_ok_and(|s| protocol::matches_file(&s, &file, baseline)) {
            if !self.accept_homework(&owner, handle) {
                return MutationOutcome::uncertain();
            }
            MutationOutcome::new(
                MutationState::Accepted,
                "已回查确认作业文件提交；请在详情核对",
            )
        } else {
            MutationOutcome::uncertain()
        }
    }
    async fn reconcile_homework_file(&self, handle: &str) -> MutationOutcome {
        let _gate = self.homework_file_gate.lock().await;
        let Ok(owner) = self.homework_owner() else {
            return MutationOutcome::uncertain();
        };
        if self.restore_journal(&owner).await.is_err() {
            return MutationOutcome::new(
                MutationState::Uncertain,
                "无法读取待核实保护记录；请勿重新提交",
            );
        }
        {
            // A positive-verified handle is terminal within this identity generation.
            // Do not reread or try to delete its already-cleared restart journal.
            let identity = self.identity.lock();
            if identity.generation != owner.1
                || identity
                    .authenticated
                    .as_ref()
                    .is_none_or(|identity| identity.account != owner.0)
            {
                return MutationOutcome::uncertain();
            }
            if self
                .homework_files
                .lock()
                .uploads
                .get(handle)
                .is_some_and(|u| u.owner == owner && u.state == State::Accepted)
            {
                return MutationOutcome::new(MutationState::Accepted, "已回查确认提交");
            }
        }
        let data = {
            let files = self.homework_files.lock();
            files
                .uploads
                .get(handle)
                .filter(|u| u.owner == owner && u.state == State::Sent)
                .map(|u| {
                    (
                        u.assignment.clone(),
                        u.course.clone(),
                        u.file.clone(),
                        u.baseline,
                    )
                })
        };
        let Some((id, course, file, baseline)) = data else {
            return MutationOutcome::not_submitted("没有可回查的提交记录");
        };
        let result = async {
            let context = self.homework_context(&id).await?;
            self.check_homework_owner(&owner)?;
            if !context.student_owned || protocol::course_id(&context)?.as_str() != course {
                return Err(AppError::new(ErrorCode::BusinessRejected));
            }
            protocol::submission(&self.session, &context.auth, &id).await
        }
        .await;
        if self.check_homework_owner(&owner).is_err() {
            return MutationOutcome::uncertain();
        }
        if result.is_ok_and(|s| protocol::matches_file(&s, &file, baseline)) {
            if !self.accept_homework(&owner, handle) {
                return MutationOutcome::uncertain();
            }
            self.invalidate_homework();
            MutationOutcome::new(MutationState::Accepted, "已回查确认提交")
        } else {
            MutationOutcome::uncertain()
        }
    }
    async fn download_homework_file(
        &self,
        id: &str,
        attachment_id: &str,
    ) -> Result<HomeworkDownload, AppError> {
        let _gate = self.homework_file_gate.lock().await;
        let owner = self.homework_owner()?;
        let context = protocol::load(&self.session, id.strip_prefix("spoc:").unwrap_or(id)).await?;
        self.check_homework_owner(&owner)?;
        let attachment = context
            .workspace
            .attachments
            .iter()
            .find(|a| a.id == attachment_id)
            .ok_or_else(AppError::invalid)?;
        let bytes = protocol::download(&self.session, &context.auth, attachment_id).await?;
        self.check_homework_owner(&owner)?;
        Ok(HomeworkDownload {
            name: attachment.name.clone(),
            bytes,
        })
    }
}
