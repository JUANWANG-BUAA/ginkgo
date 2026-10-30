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
) -> LocalTasksResponse {
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
    local_tasks_response(result)
}

fn local_tasks_response(
    result: Result<Vec<ginkgo_core::features::tasks::Task>, AppError>,
) -> LocalTasksResponse {
    match result {
        Ok(tasks) => LocalTasksResponse {
            data: Some(
                tasks
                    .into_iter()
                    .map(|task| LocalTaskDto {
                        id: task.id,
                        title: task.title,
                        due: task.due,
                        completed: task.completed,
                        source_assignment_id: task.source.map(|source| match source {
                            ginkgo_core::features::tasks::TaskSource::Homework {
                                assignment_id,
                            } => assignment_id,
                        }),
                    })
                    .collect(),
            ),
            failure: None,
        },
        Err(error) => LocalTasksResponse {
            data: None,
            failure: Some(error.code.into()),
        },
    }
}

pub(super) async fn load_notices(force_refresh: bool) -> NoticesResponse {
    let result = match service() {
        Ok(service) => with_session_read(|| service.load_notices(force_refresh)).await,
        Err(error) => Err(error),
    };
    notices_response(result)
}

fn notices_response(
    result: Result<ginkgo_core::application::NoticesOutcome, AppError>,
) -> NoticesResponse {
    match result {
        Ok(outcome) => NoticesResponse {
            data: Some(outcome.data.into_iter().map(notice_dto).collect()),
            failure: outcome.failure.map(|error| error.code.into()),
        },
        Err(error) => NoticesResponse {
            data: None,
            failure: Some(error.code.into()),
        },
    }
}

fn notice_dto(notice: ginkgo_core::features::notices::Notice) -> NoticeDto {
    NoticeDto {
        title: notice.title,
        summary: notice.summary,
        published_at: notice.published_at,
        url: notice.url,
    }
}

/// The demo campus data is the same typed value the native adapter produces,
/// so the demo never has to encode JSON for the reader to decode it again.
pub(super) fn load_demo_notices() -> NoticesResponse {
    match ginkgo_runtime::demo::demo_campus::load_demo_notices() {
        Ok(items) => NoticesResponse {
            data: Some(items.into_iter().map(notice_dto).collect()),
            failure: None,
        },
        Err(error) => NoticesResponse {
            data: None,
            failure: Some(error.code.into()),
        },
    }
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

pub(super) async fn load_campus_activities(
    page: i32,
    force_refresh: bool,
) -> CampusActivitiesResponse {
    let result = match service() {
        Ok(service) => {
            with_session_read(|| service.load_campus_activities(page, force_refresh)).await
        }
        Err(error) => Err(error),
    };
    campus_activities_response(result.map(|outcome| ginkgo_core::application::DataOutcome {
        data: outcome.data,
        failure: outcome.failure,
    }))
}

fn campus_activities_response(
    result: Result<
        ginkgo_core::application::DataOutcome<
            ginkgo_core::features::campus_activities::CampusActivities,
        >,
        AppError,
    >,
) -> CampusActivitiesResponse {
    match result {
        Ok(outcome) => CampusActivitiesResponse {
            data: Some(CampusActivitiesDto {
                page: outcome.data.page,
                fetched_at: outcome.data.fetched_at,
                activities: outcome
                    .data
                    .activities
                    .into_iter()
                    .map(|activity| CampusActivityDto {
                        id: activity.id,
                        title: activity.title,
                        category: activity.category,
                        published_at: activity.published_at,
                        activity_time: activity.activity_time,
                        place: activity.place,
                        url: activity.url,
                    })
                    .collect(),
            }),
            failure: outcome.failure.map(|error| error.code.into()),
        },
        Err(error) => CampusActivitiesResponse {
            data: None,
            failure: Some(error.code.into()),
        },
    }
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

fn outcome<T>(result: Result<T, AppError>) -> (Option<T>, Option<FailureCode>) {
    match result {
        Ok(value) => (Some(value), None),
        Err(error) => (None, Some(error.code.into())),
    }
}

fn outcome_data<T>(
    result: Result<ginkgo_core::application::DataOutcome<T>, AppError>,
) -> (Option<T>, Option<FailureCode>) {
    match result {
        Ok(v) => (Some(v.data), v.failure.map(|e| e.code.into())),
        Err(e) => (None, Some(e.code.into())),
    }
}

fn order_dto(order: ginkgo_core::features::cgyy::Order) -> CgyyOrderDto {
    CgyyOrderDto {
        order_status: order.order_status,
        check_status: order.check_status,
        can_cancel: order.can_cancel,
        id: order.id,
        place: order.place,
        date: order.date,
        time: order.time,
        status: order.status,
    }
}

fn cgyy_load_response(
    data: Option<ginkgo_core::application::CgyyData>,
    failure: Option<FailureCode>,
) -> CgyyLoadResponse {
    let mut response = CgyyLoadResponse {
        venues: None,
        day: None,
        orders: None,
        order: None,
        lock_code: None,
        failure,
    };
    match data {
        Some(ginkgo_core::application::CgyyData::Venues(sites)) => {
            response.venues = Some(
                sites
                    .into_iter()
                    .map(|site| CgyySiteDto {
                        id: site.id,
                        name: site.name,
                        venue: site.venue,
                        campus: site.campus,
                        seats: site.seats,
                        open_start: site.open_start,
                        open_end: site.open_end,
                    })
                    .collect(),
            );
        }
        Some(ginkgo_core::application::CgyyData::Day(day)) => {
            response.day = Some(CgyyDayDto {
                site_id: day.site_id,
                date: day.date,
                dates: day.dates,
                spaces: day
                    .spaces
                    .into_iter()
                    .map(|space| CgyySpaceDto {
                        name: space.name,
                        slots: space
                            .slots
                            .into_iter()
                            .map(|slot| CgyySlotDto {
                                time: slot.time,
                                status: slot.status,
                            })
                            .collect(),
                    })
                    .collect(),
            });
        }
        Some(ginkgo_core::application::CgyyData::Orders(orders)) => {
            response.orders = Some(orders.into_iter().map(order_dto).collect());
        }
        Some(ginkgo_core::application::CgyyData::Order(order)) => {
            response.order = Some(order_dto(order));
        }
        Some(ginkgo_core::application::CgyyData::LockCode(code)) => {
            response.lock_code = Some(CgyyLockCodeDto {
                qr_code: code.qr_code,
                due_date: code.due_date,
                trade_no: code.trade_no,
                venue_name: code.venue_name,
                site_name: code.site_name,
                space_name: code.space_name,
                order_name: code.order_name,
                reservation_date: code.reservation_date,
                reservation_date_detail: code.reservation_date_detail,
                reservation_start_date: code.reservation_start_date,
                reservation_end_date: code.reservation_end_date,
            });
        }
        None => {}
    }
    response
}

fn cgyy_action_response(
    result: Result<ginkgo_core::features::cgyy_booking::CgyyActionResult, AppError>,
) -> CgyyActionResultResponse {
    let (data, failure) = outcome(result);
    CgyyActionResultResponse {
        data: data.map(|result| {
            let options = result.options.map(|options| CgyyBookingOptionsDto {
                choices: options
                    .choices
                    .into_iter()
                    .map(|choice| CgyyBookingChoiceDto {
                        space_id: choice.space_id,
                        space_name: choice.space_name,
                        time_id: choice.time_id,
                        time: choice.time,
                    })
                    .collect(),
                purposes: options
                    .purposes
                    .into_iter()
                    .map(|purpose| CgyyPurposeDto {
                        id: purpose.id,
                        name: purpose.name,
                    })
                    .collect(),
                uses_fallback_purposes: options.uses_fallback_purposes,
            });
            let challenge = result.challenge.map(|challenge| CgyyChallengeDto {
                id: challenge.id,
                background: challenge.background,
                jigsaw: challenge.jigsaw,
            });
            let review = result.review.map(|review| CgyyReviewDto {
                id: review.id,
                orders: review.orders.into_iter().map(order_dto).collect(),
            });
            CgyyActionResultDto {
                state: result.state,
                message: result.message,
                options,
                challenge,
                review,
            }
        }),
        failure,
    }
}

pub(super) async fn load_cgyy(
    kind: String,
    site_id: i64,
    date: String,
    force_refresh: bool,
) -> CgyyLoadResponse {
    use ginkgo_core::application::CgyyQuery;
    let query = match kind.as_str() {
        "venues" => CgyyQuery::Venues,
        "day" => CgyyQuery::Day { site_id, date },
        "orders" => CgyyQuery::Orders,
        "order" => CgyyQuery::Order { order_id: site_id },
        "lockCode" => CgyyQuery::LockCode,
        _ => {
            return CgyyLoadResponse {
                venues: None,
                day: None,
                orders: None,
                order: None,
                lock_code: None,
                failure: Some(FailureCode::InvalidRequest),
            }
        }
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
    let (data, failure) = outcome_data(result);
    cgyy_load_response(data, failure)
}

pub(super) async fn execute_cgyy(command: String) -> CgyyActionResultResponse {
    let Ok(_write) = CGYY_WRITE.try_lock() else {
        // A second submit while one is in flight is a local backstop: report
        // busy without touching the school write endpoint again.
        return CgyyActionResultResponse {
            data: None,
            failure: Some(FailureCode::ServiceUnavailable),
        };
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
    cgyy_action_response(result)
}

static CGYY_WRITE: tokio::sync::Mutex<()> = tokio::sync::Mutex::const_new(());

pub(super) fn load_demo_cgyy(kind: String) -> CgyyLoadResponse {
    let (data, failure) = outcome(ginkgo_runtime::demo::demo_campus::load_demo_cgyy(kind));
    cgyy_load_response(data, failure)
}

/// Public OPAC search. Read-only, anonymous and bounded by the service.
pub(super) async fn load_library_books(
    query: String,
    page: i64,
    sort: String,
    descending: bool,
) -> BookPageResponse {
    let result = match service() {
        Ok(service) => {
            with_session_read(|| service.search_library_books(query, page, sort, descending)).await
        }
        Err(error) => Err(error),
    };
    library_books_response(result)
}

fn library_books_response(
    result: Result<ginkgo_core::features::library_books::BookPage, AppError>,
) -> BookPageResponse {
    match result {
        Ok(page) => BookPageResponse {
            data: Some(BookPageDto {
                page: page.page,
                page_size: page.page_size,
                total: page.total,
                actual_total: page.actual_total,
                has_more: page.has_more,
                items: page
                    .items
                    .into_iter()
                    .map(|hit| BookHitDto {
                        bib_id: hit.bib_id,
                        title: hit.title,
                        author: hit.author,
                        publisher: hit.publisher,
                        year: hit.year,
                        callno: hit.callno,
                        isbn: hit.isbn,
                        items_available: hit.items_available,
                        item_count: hit.item_count,
                    })
                    .collect(),
            }),
            failure: None,
        },
        Err(error) => BookPageResponse {
            data: None,
            failure: Some(error.code.into()),
        },
    }
}

/// Published shuttle timetable. Public page, no identity, no ticketing.
pub(super) async fn load_shuttle_timetable() -> ShuttleTimetableResponse {
    let result = match service() {
        Ok(service) => with_session_read(|| service.load_shuttle_timetable()).await,
        Err(error) => Err(error),
    };
    shuttle_timetable_response(result)
}

fn shuttle_timetable_response(
    result: Result<ginkgo_core::features::shuttle::ShuttleTimetable, AppError>,
) -> ShuttleTimetableResponse {
    match result {
        Ok(timetable) => ShuttleTimetableResponse {
            data: Some(ShuttleTimetableDto {
                source: timetable.source,
                live_source: timetable.live_source,
                tables: timetable
                    .tables
                    .into_iter()
                    .map(|table| ShuttleTableDto {
                        left: table.left,
                        right: table.right,
                        sections: table
                            .sections
                            .into_iter()
                            .map(|section| ShuttleSectionDto {
                                label: section.label,
                                left: section.left.into_iter().map(shuttle_run_dto).collect(),
                                right: section.right.into_iter().map(shuttle_run_dto).collect(),
                            })
                            .collect(),
                    })
                    .collect(),
            }),
            failure: None,
        },
        Err(error) => ShuttleTimetableResponse {
            data: None,
            failure: Some(error.code.into()),
        },
    }
}

fn shuttle_run_dto(run: ginkgo_core::features::shuttle::ShuttleRun) -> ShuttleRunDto {
    ShuttleRunDto {
        index: run.index,
        time: run.time,
        capacity: run.capacity,
    }
}

/// Public holdings for one bib id. The nested JSON string is decoded in Rust.
pub(super) async fn load_library_holdings(bib_id: String) -> BookHoldingsResponse {
    let result = match service() {
        Ok(service) => with_session_read(|| service.load_book_holdings(bib_id)).await,
        Err(error) => Err(error),
    };
    book_holdings_response(result)
}

fn book_holdings_response(
    result: Result<Vec<ginkgo_core::features::library_books::BookHolding>, AppError>,
) -> BookHoldingsResponse {
    match result {
        Ok(rows) => BookHoldingsResponse {
            data: Some(
                rows.into_iter()
                    .map(|row| BookHoldingDto {
                        call_no: row.call_no,
                        bar_code: row.bar_code,
                        library: row.library,
                        location: row.location,
                        status: row.status,
                    })
                    .collect(),
            ),
            failure: None,
        },
        Err(error) => BookHoldingsResponse {
            data: None,
            failure: Some(error.code.into()),
        },
    }
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
) -> SnapshotImportResponse {
    // Import must not race a network command or session/cache invalidation.
    let result = with_session_write(|| async {
        let s = service()?;
        if expected.is_empty() || s.status().account.as_deref() != Some(expected.as_str()) {
            return Err(AppError::session_expired());
        }
        s.import_learning_snapshots(&bytes)
    })
    .await;
    match result {
        Ok(imported) => SnapshotImportResponse {
            imported: Some(imported),
            failure: None,
        },
        Err(error) => SnapshotImportResponse {
            imported: None,
            failure: Some(error.code.into()),
        },
    }
}

pub(super) async fn load_library_loans(expected: String, page: u32) -> LibraryLoansResponse {
    let result = with_session_read(|| async {
        let s = service()?;
        if expected.is_empty() || s.status().account.as_deref() != Some(expected.as_str()) {
            return Err(AppError::session_expired());
        }
        s.load_library_loans(page).await
    })
    .await;
    library_loans_response(result)
}

fn library_loans_response(
    result: Result<ginkgo_core::features::library_loans::LibraryLoanPage, AppError>,
) -> LibraryLoansResponse {
    match result {
        Ok(page) => LibraryLoansResponse {
            data: Some(LibraryLoanPageDto {
                page: page.page,
                total: page.total,
                has_more: page.has_more,
                items: page
                    .items
                    .into_iter()
                    .map(|loan| LibraryLoanDto {
                        id: loan.id,
                        title: loan.title,
                        author: loan.author,
                        call_number: loan.call_number,
                        borrowed_at: loan.borrowed_at,
                        due_at: loan.due_at,
                    })
                    .collect(),
            }),
            failure: None,
        },
        Err(error) => LibraryLoansResponse {
            data: None,
            failure: Some(error.code.into()),
        },
    }
}

pub(super) async fn check_android_update(current: String) -> UpdateResponse {
    update_response(ginkgo_runtime::check_update(&current).await)
}

fn update_response(
    result: Result<ginkgo_core::features::updates::UpdateSummary, AppError>,
) -> UpdateResponse {
    match result {
        Ok(summary) => UpdateResponse {
            data: Some(UpdateSummaryDto {
                current: summary.current,
                latest: summary.latest,
                available: summary.available,
                page_url: summary.page_url,
                notes: summary.notes,
                apk_available: summary.apk_available,
                download: summary.download.map(|asset| AndroidDownloadDto {
                    version: asset.version,
                    name: asset.name,
                    url: asset.url,
                    api_url: asset.api_url,
                    size: asset.size as i64,
                    sha256: asset.sha256,
                }),
            }),
            failure: None,
        },
        Err(error) => UpdateResponse {
            data: None,
            failure: Some(error.code.into()),
        },
    }
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

    #[test]
    fn campus_activities_typed_response_keeps_both_dates_and_the_stale_snapshot() {
        use ginkgo_core::features::campus_activities::{CampusActivities, CampusActivity};
        let make_data = |activities| CampusActivities {
            page: 2,
            fetched_at: "2026-10-28T10:00:00+08:00".into(),
            activities,
        };
        let empty = campus_activities_response(Ok(ginkgo_core::application::DataOutcome {
            data: make_data(vec![]),
            failure: None,
        }));
        // A confirmed empty page is data, not a failure.
        assert!(empty.data.unwrap().activities.is_empty());
        assert!(empty.failure.is_none());

        let stale = campus_activities_response(Ok(ginkgo_core::application::DataOutcome {
            data: make_data(vec![CampusActivity {
                id: "xswh:0".into(),
                title: "合成讲座".into(),
                category: "讲座".into(),
                published_at: "2026年10月23日".into(),
                activity_time: "10月28日".into(),
                place: "合成报告厅".into(),
                url: "https://example.invalid/info.htm".into(),
            }]),
            failure: Some(AppError::network_unreachable()),
        }));
        assert!(matches!(
            stale.failure,
            Some(FailureCode::NetworkUnreachable)
        ));
        let data = stale.data.unwrap();
        assert_eq!(data.page, 2);
        assert_eq!(data.fetched_at, "2026-10-28T10:00:00+08:00");
        let activity = &data.activities[0];
        // Publish date and event date stay separate: neither is a deadline.
        assert_eq!(
            (&*activity.published_at, &*activity.activity_time),
            ("2026年10月23日", "10月28日")
        );
        assert_eq!(
            (
                &*activity.id,
                &*activity.title,
                &*activity.category,
                &*activity.place,
                &*activity.url
            ),
            (
                "xswh:0",
                "合成讲座",
                "讲座",
                "合成报告厅",
                "https://example.invalid/info.htm"
            )
        );

        let error = campus_activities_response(Err(AppError::changed()));
        assert!(error.data.is_none());
        assert!(matches!(error.failure, Some(FailureCode::ChangedResponse)));
    }

    #[test]
    fn update_summary_crosses_as_a_typed_dto_and_keeps_the_verified_asset() {
        use ginkgo_core::features::updates::{AndroidDownload, UpdateSummary};
        let summary = |download: Option<AndroidDownload>| UpdateSummary {
            current: "0.1.0-beta.2".into(),
            latest: Some("0.1.0-beta.3".into()),
            available: true,
            page_url: Some(
                "https://github.com/JUANWANG-BUAA/ginkgo/releases/tag/android-v0.1.0-beta.3".into(),
            ),
            notes: Some("- 合成说明".into()),
            apk_available: download.is_some(),
            download,
        };
        let asset = AndroidDownload {
            version: "0.1.0-beta.3".into(),
            name: "Ginkgo-0.1.0-beta.3-android-arm64.apk".into(),
            url: "https://github.com/JUANWANG-BUAA/ginkgo/releases/download/android-v0.1.0-beta.3/Ginkgo-0.1.0-beta.3-android-arm64.apk".into(),
            api_url: "https://api.github.com/repos/JUANWANG-BUAA/ginkgo/releases/assets/7".into(),
            size: 43_851_525,
            sha256: "a".repeat(64),
        };

        let with_asset = update_response(Ok(summary(Some(asset))));
        let data = with_asset.data.expect("summary");
        assert!(with_asset.failure.is_none());
        assert_eq!(
            (&*data.current, data.available, data.apk_available),
            ("0.1.0-beta.2", true, true)
        );
        assert_eq!(data.notes.as_deref(), Some("- 合成说明"));
        let download = data.download.expect("asset");
        // The size widens to a signed count without losing the byte total.
        assert_eq!(download.size, 43_851_525);
        assert_eq!(download.sha256.len(), 64);
        assert_eq!(download.name, "Ginkgo-0.1.0-beta.3-android-arm64.apk");

        // A release without a verified arm64 asset must stay downloadable=no
        // rather than surfacing a partial asset the installer would reject.
        let without = update_response(Ok(summary(None))).data.expect("summary");
        assert!(without.download.is_none());
        assert!(!without.apk_available);

        let failed = update_response(Err(AppError::network_unreachable()));
        assert!(failed.data.is_none());
        assert!(matches!(
            failed.failure,
            Some(FailureCode::NetworkUnreachable)
        ));
    }

    #[test]
    fn shuttle_timetable_crosses_as_a_typed_dto_with_both_directions() {
        use ginkgo_core::features::shuttle::{
            ShuttleRun, ShuttleSection, ShuttleTable, ShuttleTimetable,
        };
        let run = |index: &str, time: &str| ShuttleRun {
            index: index.into(),
            time: time.into(),
            capacity: "45".into(),
        };
        let timetable = ShuttleTimetable {
            source: "https://shuttle.example.invalid/synthetic".into(),
            live_source: "https://shuttle.example.invalid/live".into(),
            tables: vec![ShuttleTable {
                left: "去往沙河".into(),
                right: "去往学院路".into(),
                sections: vec![ShuttleSection {
                    label: "星期一至星期五".into(),
                    left: vec![run("1", "07:30")],
                    right: vec![run("1", "18:00")],
                }],
            }],
        };

        let response = shuttle_timetable_response(Ok(timetable));
        assert!(response.failure.is_none());
        let data = response.data.expect("timetable");
        assert_eq!(data.source, "https://shuttle.example.invalid/synthetic");
        assert_eq!(data.live_source, "https://shuttle.example.invalid/live");
        let table = &data.tables[0];
        assert_eq!((&*table.left, &*table.right), ("去往沙河", "去往学院路"));
        let section = &table.sections[0];
        assert_eq!(section.label, "星期一至星期五");
        // Both directions and the printed sequence number survive the crossing.
        assert_eq!(
            (&*section.left[0].index, &*section.left[0].time),
            ("1", "07:30")
        );
        assert_eq!(
            (&*section.right[0].time, &*section.right[0].capacity),
            ("18:00", "45")
        );

        let failed = shuttle_timetable_response(Err(AppError::unavailable()));
        assert!(failed.data.is_none());
        assert!(matches!(
            failed.failure,
            Some(FailureCode::ServiceUnavailable)
        ));
    }

    #[test]
    fn holdings_keep_the_school_status_wording_and_a_typed_failure() {
        use ginkgo_core::features::library_books::BookHolding;
        let read = book_holdings_response(Ok(vec![BookHolding {
            call_no: "I247.5/1".into(),
            bar_code: "synthetic-barcode".into(),
            library: "学院路馆".into(),
            location: "三层".into(),
            status: "在架".into(),
        }]));
        let row = &read.data.expect("holdings")[0];
        assert_eq!(
            (&*row.call_no, &*row.bar_code),
            ("I247.5/1", "synthetic-barcode")
        );
        // The school's own wording crosses verbatim; no local availability flag.
        assert_eq!(
            (&*row.library, &*row.location, &*row.status),
            ("学院路馆", "三层", "在架")
        );

        let empty = book_holdings_response(Ok(vec![]));
        assert!(empty.data.expect("holdings").is_empty());

        let failed = book_holdings_response(Err(AppError::session_expired()));
        assert!(failed.data.is_none());
        assert!(matches!(failed.failure, Some(FailureCode::SessionExpired)));
    }

    #[test]
    fn local_tasks_project_the_assignment_link_and_a_typed_failure() {
        use ginkgo_core::features::tasks::{Task, TaskSource};
        let read = local_tasks_response(Ok(vec![
            Task {
                id: "local:1".into(),
                title: "合成待办".into(),
                due: String::new(),
                completed: false,
                source: None,
            },
            Task {
                id: "local:2".into(),
                title: "关联作业待办".into(),
                due: "2026-10-25".into(),
                completed: true,
                source: Some(TaskSource::Homework {
                    assignment_id: "spoc:1".into(),
                }),
            },
        ]));
        let rows = read.data.expect("tasks");
        // An empty due stays empty: it means "no deadline", never a fake date.
        assert_eq!((&*rows[0].id, &*rows[0].due), ("local:1", ""));
        assert!(rows[0].source_assignment_id.is_none());
        assert_eq!(rows[1].source_assignment_id.as_deref(), Some("spoc:1"));
        assert!(rows[1].completed);

        let failed = local_tasks_response(Err(AppError::unavailable()));
        assert!(failed.data.is_none());
        assert!(matches!(
            failed.failure,
            Some(FailureCode::ServiceUnavailable)
        ));
    }

    #[test]
    fn loans_keep_optional_school_fields_and_paging_flags() {
        use ginkgo_core::features::library_loans::{LibraryLoan, LibraryLoanPage};
        let page = library_loans_response(Ok(LibraryLoanPage {
            items: vec![LibraryLoan {
                id: "loan-1".into(),
                title: Some("合成书名".into()),
                author: None,
                call_number: Some("TP1/1".into()),
                borrowed_at: Some("2026-10-01".into()),
                due_at: None,
            }],
            page: 2,
            total: 7,
            has_more: true,
        }))
        .data
        .expect("loans");
        assert_eq!((page.page, page.total, page.has_more), (2, 7, true));
        let loan = &page.items[0];
        assert_eq!(
            (&*loan.id, loan.title.as_deref()),
            ("loan-1", Some("合成书名"))
        );
        // A field the school did not disclose stays absent, never guessed.
        assert!(loan.author.is_none());
        assert!(loan.due_at.is_none());
        assert_eq!(loan.call_number.as_deref(), Some("TP1/1"));
    }

    #[test]
    fn book_page_keeps_absent_copy_counts_absent() {
        use ginkgo_core::features::library_books::{BookHit, BookPage};
        let page = library_books_response(Ok(BookPage {
            page: 1,
            page_size: 20,
            total: 1,
            actual_total: 1,
            has_more: false,
            items: vec![BookHit {
                bib_id: "syn-1".into(),
                title: "合成书目".into(),
                author: String::new(),
                publisher: "合成出版社".into(),
                year: "2026".into(),
                callno: "TP1/1".into(),
                isbn: String::new(),
                items_available: None,
                item_count: Some(2),
            }],
        }))
        .data
        .expect("page");
        assert_eq!(
            (page.page, page.page_size, page.total, page.has_more),
            (1, 20, 1, false)
        );
        let hit = &page.items[0];
        assert_eq!((&*hit.bib_id, &*hit.title), ("syn-1", "合成书目"));
        // The school stayed silent on availability, so it must not read as zero.
        assert!(hit.items_available.is_none());
        assert_eq!(hit.item_count, Some(2));
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
        assert!(response.data.is_none());
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
        assert!(response.data.is_none());
    }
}
