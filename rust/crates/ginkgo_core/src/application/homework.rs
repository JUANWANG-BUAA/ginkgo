//! homework application commands depend only on business ports.
use super::*;

impl<U: HomeworkSource> Workspace<U> {
    pub async fn load_homework(&self, force: bool) -> Result<HomeworkOutcome, AppError> {
        self.upstream.load_homework(force).await
    }
    pub async fn load_homework_detail(
        &self,
        id: &str,
        force: bool,
    ) -> Result<HomeworkDetailOutcome, AppError> {
        self.upstream.load_homework_detail(id, force).await
    }
}

impl<U: HomeworkSubmissionSource> Workspace<U> {
    pub fn configure_homework_recovery(&self, root: &str) -> Result<(), AppError> {
        self.upstream.configure_homework_recovery(root)
    }
    pub async fn pending_homework_submissions(
        &self,
    ) -> Result<Vec<HomeworkPendingSubmission>, AppError> {
        self.upstream.pending_homework_submissions().await
    }
    pub async fn homework_capabilities(&self, id: &str) -> Vec<HomeworkCapabilityEvidence> {
        self.upstream.homework_capabilities(id).await
    }
    pub async fn homework_workspace(&self, id: &str) -> Result<HomeworkWorkspace, AppError> {
        self.upstream.homework_workspace(id).await
    }
    pub async fn upload_homework_file(
        &self,
        id: &str,
        name: &str,
        bytes: Vec<u8>,
    ) -> Result<HomeworkUploadReceipt, AppError> {
        ginkgo_domain::ports::validate_homework_file(name, bytes.len())?;
        self.upstream.upload_homework_file(id, name, bytes).await
    }
    pub async fn submit_homework_file(&self, handle: &str, confirmed: bool) -> MutationOutcome {
        if !confirmed {
            return MutationOutcome::not_submitted("请先确认作业和文件");
        }
        self.upstream.submit_homework_file(handle, true).await
    }
    pub async fn download_homework_file(
        &self,
        id: &str,
        attachment_id: &str,
    ) -> Result<HomeworkDownload, AppError> {
        self.upstream
            .download_homework_file(id, attachment_id)
            .await
    }
    pub async fn reconcile_homework_file(&self, handle: &str) -> MutationOutcome {
        self.upstream.reconcile_homework_file(handle).await
    }
}
