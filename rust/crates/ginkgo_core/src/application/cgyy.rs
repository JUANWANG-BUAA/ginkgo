//! CGYY commands depend only on business ports and a minimal local restart guard.
use super::*;
use crate::cgyy_pending_store::{Pending, PendingStore};
use ginkgo_domain::features::cgyy_booking::{CgyyActionResult, CgyyCommand};
use std::path::Path;

impl<U: CgyyMutationSource + SessionSource> Workspace<U> {
    pub async fn execute_cgyy_json(&self, envelope: &str) -> Result<CgyyActionResult, AppError> {
        let envelope: serde_json::Value =
            serde_json::from_str(envelope).map_err(|_| AppError::invalid())?;
        let command = serde_json::from_value::<CgyyCommand>(envelope.clone())
            .map_err(|_| AppError::invalid())?;
        let root = match envelope.get("storage_root") {
            None => None,
            Some(serde_json::Value::String(root)) if !root.trim().is_empty() => {
                Some(Path::new(root))
            }
            _ => return Err(AppError::invalid()),
        };
        let expected_account = match envelope.get("expected_account") {
            None => None,
            Some(serde_json::Value::String(account)) if !account.trim().is_empty() => {
                Some(account.as_str())
            }
            _ => return Err(AppError::invalid()),
        };
        self.execute_cgyy_stored(command, root, expected_account)
            .await
    }

    /// Legacy typed entry: only reads are allowed without an application-support root.
    /// Mutating callers must use the JSON envelope so they cannot bypass the restart guard.
    pub async fn execute_cgyy(&self, command: CgyyCommand) -> Result<CgyyActionResult, AppError> {
        self.execute_cgyy_stored(command, None, None).await
    }

    async fn execute_cgyy_stored(
        &self,
        command: CgyyCommand,
        root: Option<&Path>,
        expected_account: Option<&str>,
    ) -> Result<CgyyActionResult, AppError> {
        let read_only = matches!(command, CgyyCommand::Options { .. } | CgyyCommand::Review);
        if !read_only && !root.is_some_and(Path::is_absolute) {
            return Err(AppError::invalid());
        }
        // An optional caller binding is only a precondition, never an identity source.
        // Check before every filesystem or port action, including options and review.
        let account = if expected_account.is_some() || !read_only {
            Some(self.upstream.account()?)
        } else {
            None
        };
        if expected_account.is_some() && expected_account != account.as_deref() {
            return Err(AppError::session_expired());
        }
        if read_only {
            // Neither read clears a pending marker, including a malformed one.
            return self.upstream.execute_cgyy(command).await;
        }
        let root = root.ok_or_else(AppError::invalid)?;
        // Never use an account provided by the JSON caller.
        let account = account.ok_or_else(AppError::session_expired)?;
        let store = PendingStore::new(root, &account)?;
        match command {
            CgyyCommand::Status => {
                let pending = store.inspect()?;
                let result = self.upstream.execute_cgyy(command).await;
                if pending != Pending::Missing {
                    // Disk evidence remains authoritative even if the status port fails.
                    Ok(pending_result())
                } else {
                    result
                }
            }
            CgyyCommand::Acknowledge { .. } => {
                // The upstream validates the fresh review id, account/generation and TTL.
                // Do not clear corrupt files, or report ready, before that validation.
                let mut result = self.upstream.execute_cgyy(command).await?;
                if matches!(result.state.as_str(), "reviewed" | "ready") {
                    store.clear()?;
                    result.state = "ready".into();
                }
                Ok(result)
            }
            CgyyCommand::Prepare { .. } | CgyyCommand::Cancel { .. } => {
                if !store.create()? {
                    return Ok(pending_result());
                }
                self.execute_cgyy_marked(command, &store).await
            }
            CgyyCommand::Submit { .. } => {
                match store.inspect()? {
                    Pending::Locked => return Ok(pending_result()),
                    Pending::Missing if !store.create()? => return Ok(pending_result()),
                    _ => {}
                }
                // A valid existing marker is expected for prepare -> submit. Upstream's
                // one-shot, in-memory context rejects stale/replayed/restarted challenges.
                self.execute_cgyy_marked(command, &store).await
            }
            // Statically unreachable today; a future CgyyCommand variant must fail
            // closed instead of aborting the FFI process.
            _ => Err(AppError::changed()),
        }
    }

    async fn execute_cgyy_marked(
        &self,
        command: CgyyCommand,
        store: &PendingStore,
    ) -> Result<CgyyActionResult, AppError> {
        // No sync lock is held across await. Whole-workflow serialization is supplied
        // by the FFI global write gate; direct concurrent clients need their own gate.
        let result = self.upstream.execute_cgyy(command).await?;
        if matches!(
            result.state.as_str(),
            "accepted" | "rejected" | "notSubmitted" | "not_submitted"
        ) {
            store.clear()?;
        }
        // Err, challenge, uncertain and every unknown state leave the marker intact.
        Ok(result)
    }
}

#[cfg(test)]
mod tests;

fn pending_result() -> CgyyActionResult {
    CgyyActionResult::message(
        "uncertain",
        "上次操作结果待核实，请先回查我的预约并手动确认，勿重复提交",
    )
}

impl<U: CgyySource> Workspace<U> {
    pub async fn load_cgyy(&self, query: CgyyQuery, force: bool) -> Result<CgyyOutcome, AppError> {
        self.upstream.load_cgyy(query, force).await
    }
}
