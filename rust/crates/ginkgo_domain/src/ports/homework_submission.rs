//! Provider-neutral homework files.
use crate::{features::mutation::MutationOutcome, AppError};
use serde::{Deserialize, Serialize};
pub const HOMEWORK_FILE_LIMIT: usize = 20 * 1024 * 1024;
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HomeworkAttachment {
    pub id: String,
    pub name: String,
    pub kind: String,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HomeworkWorkspace {
    pub assignment_id: String,
    pub allowed_methods: Vec<String>,
    pub allowed_extensions: Vec<String>,
    pub submission_limit: Option<u32>,
    pub submitted_count: Option<u32>,
    pub returned: bool,
    pub submitted_text: Option<String>,
    pub feedback: Option<String>,
    pub attachments: Vec<HomeworkAttachment>,
    pub can_submit_file: bool,
    pub blocked_reason: Option<String>,
    pub file_limit_bytes: u64,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HomeworkUploadReceipt {
    pub handle: String,
    pub file_name: String,
    pub size: u64,
}
pub struct HomeworkDownload {
    pub name: String,
    pub bytes: Vec<u8>,
}
pub fn validate_homework_file(name: &str, size: usize) -> Result<(), AppError> {
    if size == 0
        || size > HOMEWORK_FILE_LIMIT
        || name.trim().is_empty()
        || name.len() > 240
        || name
            .chars()
            .any(|c| c.is_control() || [47u32, 92, 34].contains(&(c as u32)))
    {
        return Err(AppError::invalid());
    }
    Ok(())
}
/// Evidence about one homework capability, not a claim of a real submitted write.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum HomeworkCapabilityState {
    Available,
    Unknown,
    Unsupported,
    ProtocolChanged,
    TempUnavailable,
    AuthRequired,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HomeworkCapabilityEvidence {
    pub capability: String,
    pub state: HomeworkCapabilityState,
    pub reason: String,
    pub evidence: String,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HomeworkPendingSubmission {
    pub handle: String,
    pub assignment_id: String,
    pub file_name: String,
    pub size: u64,
}
pub trait HomeworkSubmissionSource: Send + Sync {
    /// Trusted application-private directory only; never a caller-selected document path.
    fn configure_homework_recovery(&self, _root: &str) -> Result<(), AppError> {
        Err(AppError::invalid())
    }
    fn pending_homework_submissions(
        &self,
    ) -> impl std::future::Future<Output = Result<Vec<HomeworkPendingSubmission>, AppError>> + Send
    {
        async { Ok(vec![]) }
    }
    fn homework_capabilities(
        &self,
        _id: &str,
    ) -> impl std::future::Future<Output = Vec<HomeworkCapabilityEvidence>> + Send {
        async {
            vec![HomeworkCapabilityEvidence {
                capability: "fileSubmit".into(),
                state: HomeworkCapabilityState::Unknown,
                reason: "此适配器未提供作业能力诊断".into(),
                evidence: "adapterNotProvided".into(),
            }]
        }
    }
    fn homework_workspace(
        &self,
        id: &str,
    ) -> impl std::future::Future<Output = Result<HomeworkWorkspace, AppError>> + Send;
    fn upload_homework_file(
        &self,
        id: &str,
        name: &str,
        bytes: Vec<u8>,
    ) -> impl std::future::Future<Output = Result<HomeworkUploadReceipt, AppError>> + Send;
    fn submit_homework_file(
        &self,
        handle: &str,
        confirmed: bool,
    ) -> impl std::future::Future<Output = MutationOutcome> + Send;
    fn download_homework_file(
        &self,
        id: &str,
        attachment_id: &str,
    ) -> impl std::future::Future<Output = Result<HomeworkDownload, AppError>> + Send;
    fn reconcile_homework_file(
        &self,
        handle: &str,
    ) -> impl std::future::Future<Output = MutationOutcome> + Send;
}
