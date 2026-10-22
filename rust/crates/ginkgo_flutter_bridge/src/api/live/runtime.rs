//! Lazy native runtime and lifecycle synchronization.
use super::*;

pub(super) type LiveService = ginkgo_runtime::AppService;

// Concurrent reads are allowed. Identity/cache mutations wait for all existing
// reads, preventing an old request from repopulating a cleared/new account cache.
pub(super) static SESSION_ACCESS: tokio::sync::RwLock<()> = tokio::sync::RwLock::const_new(());

// Read/write exclusion belongs to the affected business module. A slow report
// must not hold up a user's check-in or seat action. Identity changes still
// use SESSION_ACCESS exclusively.
pub(super) static CHECKIN_ACCESS: tokio::sync::RwLock<()> = tokio::sync::RwLock::const_new(());
pub(super) static LIBRARY_ACCESS: tokio::sync::RwLock<()> = tokio::sync::RwLock::const_new(());

pub(super) static SERVICE: OnceLock<Result<LiveService, AppError>> = OnceLock::new();

/// Total budget for a read including SSO redirects and fallback. Mutations
/// deliberately do not use this helper: a submitted result is never retried.
pub(super) async fn bounded_read<T>(
    future: impl std::future::Future<Output = Result<T, AppError>>,
) -> Result<T, AppError> {
    tokio::time::timeout(std::time::Duration::from_secs(45), future)
        .await
        .map_err(|_| AppError::unavailable())?
}

pub(super) fn service() -> Result<&'static LiveService, AppError> {
    SERVICE
        .get_or_init(ginkgo_runtime::create_service)
        .as_ref()
        .map_err(Clone::clone)
}
