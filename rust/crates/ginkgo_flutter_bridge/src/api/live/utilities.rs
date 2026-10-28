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
    // The gate wait and the write are both bounded, so the command always
    // terminates even if the disk stalls.
    let result = with_session_read(|| async {
        // The account namespace comes from the authenticated Rust session, never
        // from a Dart-supplied identifier.
        let account = if demo {
            "ginkgo-isolated-demo".to_owned()
        } else {
            match service() {
                Ok(service) => match service.status().account.clone() {
                    Some(account) => account,
                    None => return Err(AppError::session_expired()),
                },
                Err(error) => return Err(error),
            }
        };
        // Local storage does blocking fsync work; keep it off the async worker so a
        // large待办 file cannot stall other commands.
        tokio::task::spawn_blocking(move || {
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
        .unwrap_or_else(|_| Err(AppError::unavailable()))
    })
    .await;
    read_only_value(result)
}

pub(super) async fn load_notices(force_refresh: bool) -> ReadOnlyResponse {
    let result = match service() {
        Ok(service) => with_session_read(|| service.load_notices(force_refresh)).await,
        Err(error) => Err(error),
    };
    read_only_response(result.map(|outcome| ginkgo_core::application::DataOutcome {
        data: outcome.data,
        failure: outcome.failure,
    }))
}

pub(super) fn load_demo_notices() -> ReadOnlyResponse {
    read_only_value(ginkgo_runtime::demo::demo_campus::load_demo_notices())
}

pub(super) async fn load_career_events(month: String, force_refresh: bool) -> CareerEventsResponse {
    let result = match service() {
        Ok(service) => {
            with_session_read(|| service.load_career_events(&month, force_refresh)).await
        }
        Err(error) => Err(error),
    };
    career_events_response(result.map(|outcome| ginkgo_core::application::DataOutcome {
        data: outcome.data,
        failure: outcome.failure,
    }))
}

fn career_events_response(
    result: Result<
        ginkgo_core::application::DataOutcome<ginkgo_core::features::career::CareerEvents>,
        AppError,
    >,
) -> CareerEventsResponse {
    match result {
        Ok(outcome) => CareerEventsResponse {
            data: Some(CareerEventsDto {
                month: outcome.data.month,
                fetched_at: outcome.data.fetched_at,
                events: outcome
                    .data
                    .events
                    .into_iter()
                    .map(|event| CareerEventDto {
                        id: event.id,
                        title: event.title,
                        campus: event.campus,
                        place: event.place,
                        begins_at: event.begins_at,
                        ends_at: event.ends_at,
                        fair_type: event.fair_type,
                        status: event.status,
                        url: event.url,
                    })
                    .collect(),
            }),
            failure: outcome.failure.map(|error| error.code.into()),
        },
        Err(error) => CareerEventsResponse {
            data: None,
            failure: Some(error.code.into()),
        },
    }
}

pub(super) async fn load_campus_activities(page: i32, force_refresh: bool) -> ReadOnlyResponse {
    let result = match service() {
        Ok(service) => {
            with_session_read(|| service.load_campus_activities(page, force_refresh)).await
        }
        Err(error) => Err(error),
    };
    read_only_response(result.map(|outcome| ginkgo_core::application::DataOutcome {
        data: outcome.data,
        failure: outcome.failure,
    }))
}

pub(super) async fn load_campus_card_balance() -> CampusCardBalanceResponse {
    let result = match service() {
        Ok(service) => with_session_read(|| service.campus_card_balance()).await,
        Err(error) => Err(error),
    };
    match result {
        Ok(balance) => CampusCardBalanceResponse {
            balance_minor: Some(balance.balance_minor),
            fetched_at: Some(balance.fetched_at),
            failure: None,
            failure_detail: None,
        },
        Err(error) => {
            let (failure, failure_detail) = failure(&error);
            CampusCardBalanceResponse {
                balance_minor: None,
                fetched_at: None,
                failure,
                failure_detail,
            }
        }
    }
}

pub(super) fn load_demo_campus_card_balance() -> CampusCardBalanceResponse {
    CampusCardBalanceResponse {
        balance_minor: Some(12345),
        fetched_at: Some("2026-10-20T08:00:00+08:00".into()),
        failure: None,
        failure_detail: None,
    }
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
    let result = match service() {
        Ok(service) => {
            with_module_read(ModuleAccess::Cgyy, || {
                service.load_cgyy(query, force_refresh)
            })
            .await
        }
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
    let result = match service() {
        // A dropped command may still have been submitted school-side; the
        // pending marker the command wrote survives the drop and the next
        // status read reports the outcome as unverified.
        Ok(service) => {
            let runtime = tokio::runtime::Handle::current();
            match with_module_submit(ModuleAccess::Cgyy, || {
                tokio::task::spawn_blocking(move || {
                    runtime.block_on(service.execute_cgyy_json(&command))
                })
            })
            .await
            {
                Some(Ok(result)) => result,
                Some(Err(_)) | None => Err(AppError::unavailable()),
            }
        }
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
    let result = match service() {
        Ok(service) => {
            with_session_read(|| service.search_library_books(query, page, sort, descending)).await
        }
        Err(error) => Err(error),
    };
    read_only_value(result)
}

/// Published shuttle timetable. Public page, no identity, no ticketing.
pub(super) async fn load_shuttle_timetable() -> ReadOnlyResponse {
    let result = match service() {
        Ok(service) => with_session_read(|| service.load_shuttle_timetable()).await,
        Err(error) => Err(error),
    };
    read_only_value(result)
}

/// Public holdings for one bib id. The nested JSON string is decoded in Rust.
pub(super) async fn load_library_holdings(bib_id: String) -> ReadOnlyResponse {
    let result = match service() {
        Ok(service) => with_session_read(|| service.load_book_holdings(bib_id)).await,
        Err(error) => Err(error),
    };
    read_only_value(result)
}

pub(super) async fn export_learning_snapshots(expected: String) -> LearningSnapshotResponse {
    let result = with_session_read(|| async {
        let s = service()?;
        if expected.is_empty() || s.status().account.as_deref() != Some(expected.as_str()) {
            return Err(AppError::session_expired());
        }
        s.export_learning_snapshots()
    })
    .await;
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
    read_only_value(
        with_session_write(|| async {
            let s = service()?;
            if expected.is_empty() || s.status().account.as_deref() != Some(expected.as_str()) {
                return Err(AppError::session_expired());
            }
            s.import_learning_snapshots(&bytes)
        })
        .await,
    )
}

pub(super) async fn load_library_loans(expected: String, page: u32) -> ReadOnlyResponse {
    let result = with_session_read(|| async {
        let s = service()?;
        if expected.is_empty() || s.status().account.as_deref() != Some(expected.as_str()) {
            return Err(AppError::session_expired());
        }
        s.load_library_loans(page).await
    })
    .await;
    read_only_value(result)
}

pub(super) async fn check_android_update(current: String) -> ReadOnlyResponse {
    read_only_value(ginkgo_runtime::check_update(&current).await)
}

#[cfg(test)]
mod bounded_command_tests {
    use super::*;

    #[test]
    fn career_typed_response_preserves_empty_snapshot_failure_and_event_fields() {
        use ginkgo_core::features::career::{CareerEvent, CareerEvents};
        let make_data = |events| CareerEvents {
            month: "2026-10".into(),
            fetched_at: "2026-10-28T10:00:00+08:00".into(),
            events,
        };
        let empty = career_events_response(Ok(ginkgo_core::application::DataOutcome {
            data: make_data(vec![]),
            failure: None,
        }));
        assert!(empty.data.unwrap().events.is_empty());
        assert!(empty.failure.is_none());

        let stale = career_events_response(Ok(ginkgo_core::application::DataOutcome {
            data: make_data(vec![CareerEvent {
                id: "1".into(),
                title: "合成宣讲".into(),
                campus: "学院路".into(),
                place: "合成楼".into(),
                begins_at: "10:00".into(),
                ends_at: "11:00".into(),
                fair_type: "宣讲".into(),
                status: "学校原文".into(),
                url: "https://example.invalid".into(),
            }]),
            failure: Some(AppError::unavailable()),
        }));
        assert!(matches!(
            stale.failure,
            Some(FailureCode::ServiceUnavailable)
        ));
        let data = stale.data.unwrap();
        assert_eq!(data.fetched_at, "2026-10-28T10:00:00+08:00");
        let event = &data.events[0];
        assert_eq!(
            (&*event.id, &*event.title, &*event.campus, &*event.place),
            ("1", "合成宣讲", "学院路", "合成楼")
        );
        assert_eq!(
            (
                &*event.begins_at,
                &*event.ends_at,
                &*event.fair_type,
                &*event.status,
                &*event.url
            ),
            (
                "10:00",
                "11:00",
                "宣讲",
                "学校原文",
                "https://example.invalid"
            )
        );

        let error = career_events_response(Err(AppError::session_expired()));
        assert!(error.data.is_none());
        assert!(matches!(error.failure, Some(FailureCode::SessionExpired)));
    }

    /// Local CRUD does blocking fsync work. A stalled disk must surface as a
    /// failure, not as a command that never returns.
    #[tokio::test(start_paused = true)]
    async fn a_queued_local_write_fails_instead_of_waiting_for_the_gate() {
        let _serial = TEST_GATE.lock().await;
        let write = SESSION_ACCESS.write().await;
        let response = edit_tasks(
            "/tmp/ginkgo-unused".into(),
            true,
            "load".into(),
            None,
            None,
            None,
            None,
        )
        .await;
        assert!(
            matches!(response.failure, Some(FailureCode::ServiceUnavailable)),
            "a queued local write must report unavailable, not hang"
        );
        assert!(response.payload.is_none());
        drop(write);
    }
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
