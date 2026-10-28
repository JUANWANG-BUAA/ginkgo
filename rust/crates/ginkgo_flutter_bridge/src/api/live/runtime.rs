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

/// The session gate is a process-wide static, so the tests that take it
/// must not overlap: one test's hold would look like another's queue.
#[cfg(test)]
pub(super) static TEST_GATE: tokio::sync::Mutex<()> = tokio::sync::Mutex::const_new(());

/// The business module a command belongs to.
///
/// Read/write exclusion belongs to the affected module: a slow report must not
/// hold up a user's check-in or seat action. Identity changes still use
/// `SESSION_ACCESS` exclusively.
#[derive(Clone, Copy)]
pub(super) enum ModuleAccess {
    Library,
    CheckIn,
    Cgyy,
}

impl ModuleAccess {
    async fn read(self) -> tokio::sync::RwLockReadGuard<'static, ()> {
        match self {
            ModuleAccess::Library => LIBRARY_ACCESS.read().await,
            ModuleAccess::CheckIn => CHECKIN_ACCESS.read().await,
            ModuleAccess::Cgyy => CGYY_ACCESS.read().await,
        }
    }

    async fn write(self) -> tokio::sync::RwLockWriteGuard<'static, ()> {
        match self {
            ModuleAccess::Library => LIBRARY_ACCESS.write().await,
            ModuleAccess::CheckIn => CHECKIN_ACCESS.write().await,
            ModuleAccess::Cgyy => CGYY_ACCESS.write().await,
        }
    }
}

/// Budget for taking a concurrency gate.
///
/// A gate wait used to be unbounded: a command that queued behind a long
/// login or a stuck write never returned, and the Dart future stayed pending
/// forever. Every gate is now taken under its own budget, so a command can
/// only fail as unavailable — it can never hang.
const GATE_BUDGET: std::time::Duration = std::time::Duration::from_secs(45);

/// Session commands get a wider gate budget: the CAS chain they run under
/// the same lock is already slow, and a queued sign-in should still be able
/// to complete rather than fail at the door.
const SESSION_GATE_BUDGET: std::time::Duration = std::time::Duration::from_secs(90);

async fn gate_read(
    budget: std::time::Duration,
) -> Result<tokio::sync::RwLockReadGuard<'static, ()>, AppError> {
    tokio::time::timeout(budget, SESSION_ACCESS.read())
        .await
        .map_err(|_| AppError::unavailable())
}

async fn gate_write(
    budget: std::time::Duration,
) -> Result<tokio::sync::RwLockWriteGuard<'static, ()>, AppError> {
    tokio::time::timeout(budget, SESSION_ACCESS.write())
        .await
        .map_err(|_| AppError::unavailable())
}

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

/// Take the session read gate and run a read under the read budget.
///
/// The gate wait and the school round trip are both bounded, so a command
/// always terminates: it either answers or reports unavailable. The gate is
/// released when `body` finishes.
pub(super) async fn with_session_read<T, F, Fut>(body: F) -> Result<T, AppError>
where
    F: FnOnce() -> Fut,
    Fut: std::future::Future<Output = Result<T, AppError>> + Send,
{
    let _access = gate_read(GATE_BUDGET).await?;
    bounded_read(body()).await
}

/// Same as [`with_session_read`] with an explicit work budget. A file upload
/// carries a large payload and legitimately needs longer than a plain read.
pub(super) async fn with_session_read_in<T, F, Fut>(
    budget: std::time::Duration,
    body: F,
) -> Result<T, AppError>
where
    F: FnOnce() -> Fut,
    Fut: std::future::Future<Output = Result<T, AppError>> + Send,
{
    let _access = gate_read(GATE_BUDGET).await?;
    tokio::time::timeout(budget, body())
        .await
        .map_err(|_| AppError::unavailable())?
}

/// Take the session write gate and run a session command under the session
/// budget. Sign-in, restore, sign-out and route changes all mutate identity
/// or cached state, so they hold the gate exclusively.
pub(super) async fn with_session_write<T, F, Fut>(body: F) -> Result<T, AppError>
where
    F: FnOnce() -> Fut,
    Fut: std::future::Future<Output = Result<T, AppError>> + Send,
{
    let _access = gate_write(SESSION_GATE_BUDGET).await?;
    bounded_session(body()).await
}

/// Take the session read gate and run a submitted write under the submit
/// budget. A dropped submit yields no outcome: the caller reports the result
/// as unknown instead of resubmitting.
pub(super) async fn with_session_submit<T, F, Fut>(body: F) -> Option<T>
where
    F: FnOnce() -> Fut,
    Fut: std::future::Future<Output = T> + Send,
{
    let _access = gate_read(GATE_BUDGET).await.ok()?;
    bounded_submit(body()).await
}

/// Take the session read gate and a module read gate, then run a read.
pub(super) async fn with_module_read<T, F, Fut>(
    module: ModuleAccess,
    body: F,
) -> Result<T, AppError>
where
    F: FnOnce() -> Fut,
    Fut: std::future::Future<Output = Result<T, AppError>> + Send,
{
    let _access = gate_read(GATE_BUDGET).await?;
    let _module = tokio::time::timeout(GATE_BUDGET, module.read())
        .await
        .map_err(|_| AppError::unavailable())?;
    bounded_read(body()).await
}

/// Take the session read gate and a module write gate, then run a submitted
/// write. A dropped submit yields no outcome, exactly like
/// [`with_session_submit`].
pub(super) async fn with_module_submit<T, F, Fut>(module: ModuleAccess, body: F) -> Option<T>
where
    F: FnOnce() -> Fut,
    Fut: std::future::Future<Output = T> + Send,
{
    let _access = gate_read(GATE_BUDGET).await.ok()?;
    let _module = tokio::time::timeout(GATE_BUDGET, module.write())
        .await
        .map_err(|_| AppError::unavailable())
        .ok()?;
    bounded_submit(body()).await
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

/// The gate budget is the fix for an unbounded wait: a command queued behind
/// a long login or a stuck write must fail as unavailable, never hang.
#[cfg(test)]
mod gate_budget_tests {
    use super::*;

    #[tokio::test(start_paused = true)]
    async fn a_read_queued_behind_a_write_gate_fails_instead_of_waiting_forever() {
        let _serial = TEST_GATE.lock().await;
        let write = SESSION_ACCESS.write().await;
        let error = with_session_read(|| async { Ok::<_, AppError>(1) })
            .await
            .expect_err("a queued read must not wait forever");
        assert_eq!(error.code, ginkgo_core::ErrorCode::ServiceUnavailable);
        drop(write);
    }

    #[tokio::test(start_paused = true)]
    async fn a_write_queued_behind_a_read_gate_fails_instead_of_waiting_forever() {
        let _serial = TEST_GATE.lock().await;
        let read = SESSION_ACCESS.read().await;
        let error = with_session_write(|| async { Ok::<_, AppError>(1) })
            .await
            .expect_err("a queued write must not wait forever");
        assert_eq!(error.code, ginkgo_core::ErrorCode::ServiceUnavailable);
        drop(read);
    }

    #[tokio::test(start_paused = true)]
    async fn a_submit_queued_behind_a_write_gate_yields_no_outcome() {
        let _serial = TEST_GATE.lock().await;
        // A submit takes the read gate, so only an exclusive writer (a sign-in
        // or a sign-out) can make it queue.
        let write = SESSION_ACCESS.write().await;
        let outcome = with_session_submit(|| async { 5i32 }).await;
        assert!(
            outcome.is_none(),
            "a queued submit must not report a fabricated outcome"
        );
        drop(write);
    }

    #[tokio::test(start_paused = true)]
    async fn a_module_read_queued_behind_a_module_write_fails_instead_of_hanging() {
        let _serial = TEST_GATE.lock().await;
        let write = CGYY_ACCESS.write().await;
        let error = with_module_read(ModuleAccess::Cgyy, || async { Ok::<_, AppError>(1) })
            .await
            .expect_err("a queued module read must not wait forever");
        assert_eq!(error.code, ginkgo_core::ErrorCode::ServiceUnavailable);
        drop(write);
    }

    #[tokio::test]
    async fn the_gate_is_held_for_the_body_and_released_afterwards() {
        let _serial = TEST_GATE.lock().await;
        let held = SESSION_ACCESS.read().await;
        assert!(SESSION_ACCESS.try_read().is_ok(), "reads share the gate");
        assert!(
            SESSION_ACCESS.try_write().is_err(),
            "the write gate must be exclusive while a read is held"
        );
        drop(held);

        let value = with_session_read(|| async { Ok::<_, AppError>(9) })
            .await
            .expect("an uncontended read must succeed");
        assert_eq!(value, 9);
        // Await the exclusive gate instead of probing it: a neighbouring test
        // may still be finishing a read, and that is not this test's failure.
        let released =
            tokio::time::timeout(std::time::Duration::from_secs(30), gate_write(GATE_BUDGET)).await;
        assert!(
            matches!(released, Ok(Ok(_))),
            "the gate must be released after the body finishes"
        );
    }

    #[tokio::test]
    async fn the_body_error_is_preserved_and_not_turned_into_a_timeout() {
        let _serial = TEST_GATE.lock().await;
        let error = with_session_read(|| async { Err::<i32, _>(AppError::invalid()) })
            .await
            .expect_err("the body error must reach the caller");
        assert_eq!(error.code, ginkgo_core::ErrorCode::InvalidRequest);
    }
}
