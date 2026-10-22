//! cgyy application commands depend only on business ports.
use ginkgo_domain::features::cgyy_booking::{CgyyActionResult, CgyyCommand};

impl<U: CgyyMutationSource> Workspace<U> {
    pub async fn execute_cgyy_json(&self, command: &str) -> Result<CgyyActionResult, AppError> {
        let command =
            serde_json::from_str::<CgyyCommand>(command).map_err(|_| AppError::invalid())?;
        self.execute_cgyy(command).await
    }

    pub async fn execute_cgyy(&self, command: CgyyCommand) -> Result<CgyyActionResult, AppError> {
        self.upstream.execute_cgyy(command).await
    }
}
use super::*;

impl<U: CgyySource> Workspace<U> {
    pub async fn load_cgyy(&self, query: CgyyQuery, force: bool) -> Result<CgyyOutcome, AppError> {
        self.upstream.load_cgyy(query, force).await
    }
}
