//! Feature implementation behind the stable live API.
use super::*;

pub(super) async fn edit_tasks(
    root: String,
    demo: bool,
    action: String,
    id: Option<String>,
    title: Option<String>,
    due: Option<String>,
    completed: Option<bool>,
) -> ReadOnlyResponse {
    // Local CRUD waits for the session gate instead of failing while a login
    // holds the write lock: the command is queued, never silently dropped.
    let _access = SESSION_ACCESS.read().await;
    // The account namespace comes from the authenticated Rust session, never
    // from a Dart-supplied identifier.
    let account = if demo {
        "ginkgo-isolated-demo".to_owned()
    } else {
        match service() {
            Ok(service) => match service.status().account.clone() {
                Some(account) => account,
                None => return read_only_value::<()>(Err(AppError::session_expired())),
            },
            Err(error) => return read_only_value::<()>(Err(error)),
        }
    };
    // Local storage does blocking fsync work; keep it off the async worker so a
    // large待办 file cannot stall other commands.
    let result = tokio::task::spawn_blocking(move || {
        ginkgo_core::application::tasks_service::edit(
            std::path::Path::new(&root),
            &account,
            &action,
            id.as_deref(),
            title.as_deref(),
            due.as_deref(),
            completed,
        )
    })
    .await
    .unwrap_or_else(|_| Err(AppError::unavailable()));
    read_only_value(result)
}

pub(super) async fn load_notices(force_refresh: bool) -> ReadOnlyResponse {
    let _access = SESSION_ACCESS.read().await;
    let result = match service() {
        Ok(service) => bounded_read(service.load_notices(force_refresh)).await,
        Err(error) => Err(error),
    };
    read_only_response(result)
}

pub(super) fn load_demo_notices() -> ReadOnlyResponse {
    read_only_value(ginkgo_runtime::demo::demo_campus::load_demo_notices())
}

pub(super) async fn load_cgyy(
    kind: String,
    site_id: i64,
    date: String,
    force_refresh: bool,
) -> ReadOnlyResponse {
    use ginkgo_core::application::CgyyQuery;
    let query = match kind.as_str() {
        "venues" => CgyyQuery::Venues,
        "day" => CgyyQuery::Day { site_id, date },
        "orders" => CgyyQuery::Orders,
        "order" => CgyyQuery::Order { order_id: site_id },
        "lockCode" => CgyyQuery::LockCode,
        _ => return read_only_value::<()>(Err(AppError::invalid())),
    };
    let _access = SESSION_ACCESS.read().await;
    let _module = CGYY_ACCESS.read().await;
    let result = match service() {
        Ok(service) => bounded_read(service.load_cgyy(query, force_refresh)).await,
        Err(error) => Err(error),
    };
    read_only_response(result)
}

pub(super) async fn execute_cgyy(command: String) -> ReadOnlyResponse {
    let Ok(_write) = CGYY_WRITE.try_lock() else {
        // A second submit while one is in flight is a local backstop: report
        // busy without touching the school write endpoint again.
        return read_only_value::<()>(Err(AppError::unavailable()));
    };
    let _access = SESSION_ACCESS.read().await;
    let _module = CGYY_ACCESS.write().await;
    let result = match service() {
        // A dropped command may still have been submitted school-side; the
        // pending marker the command wrote survives the drop and the next
        // status read reports the outcome as unverified.
        Ok(service) => match bounded_submit(service.execute_cgyy_json(&command)).await {
            Some(result) => result,
            None => Err(AppError::unavailable()),
        },
        Err(error) => Err(error),
    };
    read_only_value(result)
}

static CGYY_WRITE: tokio::sync::Mutex<()> = tokio::sync::Mutex::const_new(());

pub(super) fn load_demo_cgyy(kind: String) -> ReadOnlyResponse {
    read_only_value(ginkgo_runtime::demo::demo_campus::load_demo_cgyy(kind))
}

/// Public OPAC search. Read-only, anonymous and bounded by the service.
pub(super) async fn load_library_books(
    query: String,
    page: i64,
    sort: String,
    descending: bool,
) -> ReadOnlyResponse {
    let _access = SESSION_ACCESS.read().await;
    let result = match service() {
        Ok(service) => {
            bounded_read(service.search_library_books(query, page, sort, descending)).await
        }
        Err(error) => Err(error),
    };
    read_only_value(result)
}

/// Published shuttle timetable. Public page, no identity, no ticketing.
pub(super) async fn load_shuttle_timetable() -> ReadOnlyResponse {
    let _access = SESSION_ACCESS.read().await;
    let result = match service() {
        Ok(service) => bounded_read(service.load_shuttle_timetable()).await,
        Err(error) => Err(error),
    };
    read_only_value(result)
}

/// Public holdings for one bib id. The nested JSON string is decoded in Rust.
pub(super) async fn load_library_holdings(bib_id: String) -> ReadOnlyResponse {
    let _access = SESSION_ACCESS.read().await;
    let result = match service() {
        Ok(service) => bounded_read(service.load_book_holdings(bib_id)).await,
        Err(error) => Err(error),
    };
    read_only_value(result)
}

pub(super) async fn export_learning_snapshots(expected: String) -> LearningSnapshotResponse {
    let _access = SESSION_ACCESS.read().await;
    let result = (|| {
        let s = service()?;
        if expected.is_empty() || s.status().account.as_deref() != Some(expected.as_str()) {
            return Err(AppError::session_expired());
        }
        s.export_learning_snapshots()
    })();
    match result {
        Ok(bytes) => LearningSnapshotResponse {
            bytes: Some(bytes),
            failure: None,
        },
        Err(e) => LearningSnapshotResponse {
            bytes: None,
            failure: Some(e.code.into()),
        },
    }
}
pub(super) async fn import_learning_snapshots(
    expected: String,
    bytes: Vec<u8>,
) -> ReadOnlyResponse {
    // Import must not race a network command or session/cache invalidation.
    let _access = SESSION_ACCESS.write().await;
    read_only_value((|| {
        let s = service()?;
        if expected.is_empty() || s.status().account.as_deref() != Some(expected.as_str()) {
            return Err(AppError::session_expired());
        }
        s.import_learning_snapshots(&bytes)
    })())
}

pub(super) async fn load_library_loans(expected: String, page: u32) -> ReadOnlyResponse {
    let _access = SESSION_ACCESS.read().await;
    let result = async {
        let s = service()?;
        if expected.is_empty() || s.status().account.as_deref() != Some(expected.as_str()) {
            return Err(AppError::session_expired());
        }
        bounded_read(s.load_library_loans(page)).await
    }
    .await;
    read_only_value(result)
}

pub(super) async fn check_android_update(current: String) -> ReadOnlyResponse {
    read_only_value(ginkgo_runtime::check_update(&current).await)
}

#[cfg(test)]
mod gate_tests {
    use super::*;
    use std::{
        future::Future,
        pin::pin,
        task::{Context, Poll, Waker},
    };

    #[test]
    fn a_second_cgyy_submit_is_rejected_locally_without_queueing() {
        let _first = CGYY_WRITE.try_lock().expect("first submit holds the gate");
        let mut second = pin!(execute_cgyy("{}".into()));
        let mut context = Context::from_waker(Waker::noop());
        let Poll::Ready(response) = second.as_mut().poll(&mut context) else {
            panic!("the busy backstop must not queue a second write");
        };
        assert!(matches!(
            response.failure,
            Some(FailureCode::ServiceUnavailable)
        ));
        assert!(response.payload.is_none());
        assert!(!response.stale);
    }
}
