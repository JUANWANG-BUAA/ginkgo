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
pub(super) static CGYY_ACCESS: tokio::sync::RwLock<()> = tokio::sync::RwLock::const_new(());

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

/// Budget for session commands (sign-in/restore). The CAS chain alone can
/// spend the whole read budget on redirects, so these get a wider cap. A
/// timeout reports unavailable; the service only commits local identity when
/// its chain completes, so a dropped command cannot surface a half sign-in.
/// `sign_out` stays unwrapped: it is a local clear with no school round trip.
pub(super) async fn bounded_session<T>(
    future: impl std::future::Future<Output = Result<T, AppError>>,
) -> Result<T, AppError> {
    tokio::time::timeout(std::time::Duration::from_secs(90), future)
        .await
        .map_err(|_| AppError::unavailable())?
}

/// Budget for a school write. A timed-out write is dropped, never retried:
/// the request may have been received, so callers must report the outcome as
/// unknown (`uncertain`), never as a clean not-submitted failure the UI could
/// safely resubmit.
pub(super) async fn bounded_submit<T>(future: impl std::future::Future<Output = T>) -> Option<T> {
    tokio::time::timeout(std::time::Duration::from_secs(90), future)
        .await
        .ok()
}

pub(super) fn service() -> Result<&'static LiveService, AppError> {
    SERVICE
        .get_or_init(ginkgo_runtime::create_service)
        .as_ref()
        .map_err(Clone::clone)
}

#[cfg(test)]
mod bounded_read_tests {
    use super::*;

    #[tokio::test(start_paused = true)]
    async fn a_stuck_school_read_fails_as_unavailable_after_the_budget() {
        let error = bounded_read(std::future::pending::<Result<i32, AppError>>())
            .await
            .expect_err("the 45s budget must cap a stuck read");
        assert_eq!(error.code, ginkgo_core::ErrorCode::ServiceUnavailable);
    }

    #[tokio::test]
    async fn a_fast_read_passes_through_untouched() {
        let value = bounded_read(async { Ok(7i32) }).await.expect("fast read");
        assert_eq!(value, 7);
    }

    #[tokio::test(start_paused = true)]
    async fn a_stuck_session_command_fails_as_unavailable_after_the_budget() {
        let error = bounded_session(std::future::pending::<Result<i32, AppError>>())
            .await
            .expect_err("the 90s session budget must cap a stuck sign-in");
        assert_eq!(error.code, ginkgo_core::ErrorCode::ServiceUnavailable);
    }

    #[tokio::test]
    async fn a_fast_session_command_passes_through_untouched() {
        let value = bounded_session(async { Ok("in".to_string()) })
            .await
            .expect("fast session command");
        assert_eq!(value, "in");
    }

    #[tokio::test(start_paused = true)]
    async fn a_stuck_write_yields_no_outcome_so_the_caller_reports_uncertain() {
        assert!(
            bounded_submit(std::future::pending::<i32>())
                .await
                .is_none(),
            "a dropped write must not fabricate an outcome"
        );
    }

    #[tokio::test]
    async fn a_fast_write_yields_its_outcome() {
        assert_eq!(bounded_submit(async { 5i32 }).await, Some(5));
    }
}
