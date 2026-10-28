//! Feature implementation behind the stable live API.
use super::*;

pub(super) async fn load_library_venues(force_refresh: bool) -> LibraryVenuesResponse {
    let Ok(service) = service() else {
        return LibraryVenuesResponse {
            venues: vec![],
            fetched_at: None,
            from_cache: false,
            stale: false,
            failure: Some(FailureCode::CredentialStore),
            failure_detail: None,
        };
    };
    match with_module_read(ModuleAccess::Library, || {
        service.load_library_venues(force_refresh)
    })
    .await
    {
        Ok(outcome) => {
            let (failure, failure_detail) = outcome
                .failure
                .as_ref()
                .map(failure)
                .unwrap_or((None, None));
            LibraryVenuesResponse {
                venues: outcome.venues.into_iter().map(library_venue).collect(),
                fetched_at: Some(outcome.fetched_at),
                from_cache: outcome.from_cache,
                stale: outcome.stale,
                failure,
                failure_detail,
            }
        }
        Err(error) => LibraryVenuesResponse {
            venues: vec![],
            fetched_at: None,
            from_cache: false,
            stale: false,
            failure: Some(error.code.clone().into()),
            failure_detail: error.detail,
        },
    }
}

pub(super) async fn load_library_areas(library_id: String) -> LibraryAreasResponse {
    let _module_marker = ();
    let Ok(service) = service() else {
        return LibraryAreasResponse {
            areas: vec![],
            failure: Some(FailureCode::CredentialStore),
            failure_detail: None,
        };
    };
    match with_module_read(ModuleAccess::Library, || {
        service.load_library_areas(&library_id)
    })
    .await
    {
        Ok(areas) => LibraryAreasResponse {
            areas: areas.into_iter().map(library_area).collect(),
            failure: None,
            failure_detail: None,
        },
        Err(error) => LibraryAreasResponse {
            areas: vec![],
            failure: Some(error.code.clone().into()),
            failure_detail: error.detail,
        },
    }
}

pub(super) async fn load_library_slots(area_id: String) -> LibrarySlotsResponse {
    let _module_marker = ();
    let Ok(service) = service() else {
        return LibrarySlotsResponse {
            slots: vec![],
            failure: Some(FailureCode::CredentialStore),
            failure_detail: None,
        };
    };
    match with_module_read(ModuleAccess::Library, || {
        service.load_library_slots(&area_id)
    })
    .await
    {
        Ok(slots) => LibrarySlotsResponse {
            slots: slots.into_iter().map(library_slot).collect(),
            failure: None,
            failure_detail: None,
        },
        Err(error) => LibrarySlotsResponse {
            slots: vec![],
            failure: Some(error.code.clone().into()),
            failure_detail: error.detail,
        },
    }
}

pub(super) async fn load_library_seats(
    area_id: String,
    slot_id: String,
    day: String,
    start: String,
    end: String,
) -> LibrarySeatsResponse {
    let _module_marker = ();
    let Ok(service) = service() else {
        return LibrarySeatsResponse {
            seats: vec![],
            failure: Some(FailureCode::CredentialStore),
            failure_detail: None,
        };
    };
    match with_module_read(ModuleAccess::Library, || {
        service.load_library_seats(&area_id, &slot_id, &day, &start, &end)
    })
    .await
    {
        Ok(seats) => LibrarySeatsResponse {
            seats: seats.into_iter().map(library_seat).collect(),
            failure: None,
            failure_detail: None,
        },
        Err(error) => LibrarySeatsResponse {
            seats: vec![],
            failure: Some(error.code.clone().into()),
            failure_detail: error.detail,
        },
    }
}

pub(super) async fn load_library_bookings(force_refresh: bool) -> LibraryBookingsResponse {
    let _module_marker = ();
    let Ok(service) = service() else {
        return LibraryBookingsResponse {
            bookings: vec![],
            fetched_at: None,
            from_cache: false,
            stale: false,
            failure: Some(FailureCode::CredentialStore),
            failure_detail: None,
        };
    };
    match with_module_read(ModuleAccess::Library, || {
        service.load_library_bookings(force_refresh)
    })
    .await
    {
        Ok(outcome) => {
            let (failure, failure_detail) = outcome
                .failure
                .as_ref()
                .map(failure)
                .unwrap_or((None, None));
            LibraryBookingsResponse {
                bookings: outcome.bookings.into_iter().map(library_booking).collect(),
                fetched_at: Some(outcome.fetched_at),
                from_cache: outcome.from_cache,
                stale: outcome.stale,
                failure,
                failure_detail,
            }
        }
        Err(error) => LibraryBookingsResponse {
            bookings: vec![],
            fetched_at: None,
            from_cache: false,
            stale: false,
            failure: Some(error.code.clone().into()),
            failure_detail: error.detail,
        },
    }
}

pub(super) async fn load_library_history(page: i32, force_refresh: bool) -> LibraryHistoryResponse {
    let _module_marker = ();
    let result = match service() {
        Ok(service) => {
            with_module_read(ModuleAccess::Library, || {
                service.load_library_history(page, force_refresh)
            })
            .await
        }
        Err(error) => Err(error),
    };
    match result {
        Ok(outcome) => {
            let (failure, failure_detail) = outcome
                .failure
                .as_ref()
                .map(failure)
                .unwrap_or((None, None));
            LibraryHistoryResponse {
                bookings: outcome
                    .data
                    .bookings
                    .into_iter()
                    .map(library_booking)
                    .collect(),
                page: outcome.data.page,
                page_size: outcome.data.page_size,
                total: outcome.data.total.and_then(|n| i32::try_from(n).ok()),
                has_next: outcome.data.has_next,
                fetched_at: Some(outcome.fetched_at),
                from_cache: outcome.from_cache,
                stale: outcome.stale,
                failure,
                failure_detail,
            }
        }
        Err(error) => LibraryHistoryResponse {
            bookings: vec![],
            page,
            page_size: 40,
            total: None,
            has_next: false,
            fetched_at: None,
            from_cache: false,
            stale: false,
            failure: Some(error.code.clone().into()),
            failure_detail: error.detail,
        },
    }
}

pub(super) fn load_demo_library_history(page: i32) -> LibraryHistoryResponse {
    let result = ginkgo_runtime::demo::demo_campus::library_history(page);
    match result {
        Ok(data) => LibraryHistoryResponse {
            bookings: data.bookings.into_iter().map(library_booking).collect(),
            page,
            page_size: 40,
            total: Some(2),
            has_next: false,
            fetched_at: None,
            from_cache: false,
            stale: false,
            failure: None,
            failure_detail: None,
        },
        Err(error) => LibraryHistoryResponse {
            bookings: vec![],
            page,
            page_size: 40,
            total: None,
            has_next: false,
            fetched_at: None,
            from_cache: false,
            stale: false,
            failure: Some(error.code.into()),
            failure_detail: None,
        },
    }
}

pub(super) async fn load_library_stats(force_refresh: bool) -> ReadOnlyResponse {
    let result = match service() {
        Ok(service) => with_session_read(|| service.load_library_stats(force_refresh)).await,
        Err(error) => Err(error),
    };
    match result {
        Ok(outcome) => ReadOnlyResponse {
            payload: serde_json::to_string(&serde_json::json!({"campuses":outcome.campuses,
                "fetchedAt":outcome.fetched_at,"fromCache":outcome.from_cache}))
            .ok(),
            stale: outcome.failure.is_some(),
            failure: outcome.failure.map(|e| e.code.into()),
        },
        Err(error) => ReadOnlyResponse {
            payload: None,
            stale: false,
            failure: Some(error.code.into()),
        },
    }
}

pub(super) fn load_demo_library_stats() -> ReadOnlyResponse {
    let result = ginkgo_runtime::demo::demo_campus::library_stats();
    match result {
        Ok(campuses) => ReadOnlyResponse {
            payload: Some(
                serde_json::json!({"campuses":campuses,"fetchedAt":null,"fromCache":false})
                    .to_string(),
            ),
            stale: false,
            failure: None,
        },
        Err(error) => ReadOnlyResponse {
            payload: None,
            stale: false,
            failure: Some(error.code.into()),
        },
    }
}

pub(super) async fn reserve_library_seat(
    area_id: String,
    seat_id: String,
    slot: crate::api::mirror::LibrarySlot,
) -> MutationResponse {
    let Ok(_write) = LIBRARY_WRITE.try_lock() else {
        return MutationResponse {
            state: "notSubmitted".into(),
            message: "预约正在处理，请勿重复提交".into(),
        };
    };
    match service() {
        Ok(service) => {
            let booking = service.reserve_library_seat(
                &area_id,
                &seat_id,
                ginkgo_core::features::library::LibrarySlot {
                    id: slot.id,
                    day: slot.day,
                    start: slot.start,
                    end: slot.end,
                },
            );
            match with_module_submit(ModuleAccess::Library, || booking).await {
                Some(outcome) => mutation_response(outcome),
                None => MutationResponse {
                    state: "uncertain".into(),
                    message: "提交超时，结果待核实；请刷新确认，勿重复提交".into(),
                },
            }
        }
        Err(_) => MutationResponse {
            state: "notSubmitted".into(),
            message: "本地服务不可用，未提交预约".into(),
        },
    }
}

pub(super) async fn perform_library_action(booking_id: String, action: String) -> MutationResponse {
    let Ok(_write) = LIBRARY_WRITE.try_lock() else {
        return MutationResponse {
            state: "notSubmitted".into(),
            message: "预约正在处理，请勿重复提交".into(),
        };
    };
    match service() {
        Ok(service) => {
            match with_module_submit(ModuleAccess::Library, || {
                service.perform_library_action(&booking_id, &action)
            })
            .await
            {
                Some(outcome) => mutation_response(outcome),
                None => MutationResponse {
                    state: "uncertain".into(),
                    message: "提交超时，结果待核实；请刷新确认，勿重复提交".into(),
                },
            }
        }
        Err(_) => MutationResponse {
            state: "notSubmitted".into(),
            message: "本地服务不可用，未提交操作".into(),
        },
    }
}

static LIBRARY_WRITE: tokio::sync::Mutex<()> = tokio::sync::Mutex::const_new(());
