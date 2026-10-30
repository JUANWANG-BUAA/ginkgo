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

pub(super) async fn load_library_stats(force_refresh: bool) -> LibraryStatsResponse {
    let result = match service() {
        Ok(service) => with_session_read(|| service.load_library_stats(force_refresh)).await,
        Err(error) => Err(error),
    };
    match result {
        Ok(outcome) => LibraryStatsResponse {
            data: Some(LibraryStatsDto {
                campuses: outcome.campuses.into_iter().map(campus_stats_dto).collect(),
                fetched_at: Some(outcome.fetched_at),
                from_cache: outcome.from_cache,
            }),
            failure: outcome.failure.map(|e| e.code.into()),
        },
        Err(error) => LibraryStatsResponse {
            data: None,
            failure: Some(error.code.into()),
        },
    }
}

fn count_pair_dto(pair: ginkgo_core::features::library_stats::CountPair) -> CountPairDto {
    CountPairDto {
        available: pair.available,
        total: pair.total,
    }
}

fn campus_stats_dto(
    stats: ginkgo_core::features::library_stats::CampusStats,
) -> LibraryCampusStatsDto {
    LibraryCampusStatsDto {
        id: stats.id,
        name: stats.name,
        people: stats.people,
        reading_rooms: stats
            .reading_rooms
            .into_iter()
            .map(|room| ReadingRoomDto {
                name: room.name,
                people: room.people,
            })
            .collect(),
        // An absent resource stays absent; it is never reported as zero.
        seats: stats.seats.map(count_pair_dto),
        study_rooms: stats.study_rooms.map(count_pair_dto),
        lockers: stats.lockers.map(count_pair_dto),
    }
}

pub(super) fn load_demo_library_stats() -> LibraryStatsResponse {
    match ginkgo_runtime::demo::demo_campus::library_stats() {
        Ok(campuses) => LibraryStatsResponse {
            data: Some(LibraryStatsDto {
                campuses: campuses.into_iter().map(campus_stats_dto).collect(),
                fetched_at: None,
                from_cache: false,
            }),
            failure: None,
        },
        Err(error) => LibraryStatsResponse {
            data: None,
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

#[cfg(test)]
mod library_stats_tests {
    use super::*;

    #[test]
    fn campus_stats_keep_absent_resources_absent_and_nested_rooms_typed() {
        use ginkgo_core::features::library_stats::{CampusStats, CountPair, ReadingRoom};
        let dto = campus_stats_dto(CampusStats {
            id: "a1".into(),
            name: "学院路馆".into(),
            people: 812,
            reading_rooms: vec![ReadingRoom {
                name: "一层阅览室".into(),
                people: 120,
            }],
            seats: Some(CountPair {
                available: 40,
                total: 200,
            }),
            study_rooms: None,
            lockers: None,
        });
        assert_eq!((&*dto.id, &*dto.name, dto.people), ("a1", "学院路馆", 812));
        assert_eq!(dto.reading_rooms[0].name, "一层阅览室");
        assert_eq!(dto.seats.as_ref().map(|s| s.available), Some(40));
        // A resource the school did not publish stays absent, not zero.
        assert!(dto.study_rooms.is_none());
        assert!(dto.lockers.is_none());
    }
}
