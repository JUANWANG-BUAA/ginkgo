//! Synthetic use cases projected through the same public DTOs.
use super::*;

pub(super) fn load_demo_classrooms(query: ClassroomQuery) -> ClassroomResponse {
    let sort = match query.sort {
        ClassroomSort::Name => classroom_domain::Sort::Name,
        ClassroomSort::Availability => classroom_domain::Sort::Availability,
        ClassroomSort::Consecutive => classroom_domain::Sort::Consecutive,
    };
    match application::demo_classrooms(
        query.search,
        query.section,
        query.minimum_free_sections,
        query.minimum_consecutive_sections,
        query.building,
        sort,
    ) {
        Ok(result) => ClassroomResponse {
            buildings: result
                .buildings
                .into_iter()
                .map(|(name, rooms)| ClassroomBuilding {
                    name,
                    rooms: rooms
                        .into_iter()
                        .map(|r| ClassroomRow {
                            section_states: r
                                .section_states()
                                .into_iter()
                                .map(|(number, available)| SectionState { number, available })
                                .collect(),
                            id: r.room.id,
                            name: r.room.name,
                            floor: r.room.floorid,
                            sections: r.sections,
                            longest_run: r.longest_run as i32,
                        })
                        .collect(),
                })
                .collect(),
            room_count: result.summary.room_count as i32,
            building_count: result.summary.building_count as i32,
            free_slot_count: result.summary.free_slot_count as i32,
            fetched_at: None,
            from_cache: false,
            failure: None,
            failure_detail: None,
        },
        Err(error) => ClassroomResponse {
            buildings: vec![],
            room_count: 0,
            building_count: 0,
            free_slot_count: 0,
            fetched_at: None,
            from_cache: false,
            failure: Some(error.code.into()),
            failure_detail: error.detail,
        },
    }
}

pub(super) fn load_query_dates(instant: String) -> QueryDates {
    match application::demo_repository::query_dates(&instant) {
        Ok((today, tomorrow)) => QueryDates {
            today,
            tomorrow,
            failure: None,
        },
        Err(error) => QueryDates {
            today: String::new(),
            tomorrow: String::new(),
            failure: Some(error.code.into()),
        },
    }
}

pub(super) fn query_demo_classrooms(scope: DemoScope, query: ClassroomQuery) -> ClassroomResponse {
    use std::sync::{Mutex, OnceLock};
    static REPOSITORY: OnceLock<Mutex<application::demo_repository::DemoRepository>> =
        OnceLock::new();
    let result = REPOSITORY
        .get_or_init(Default::default)
        .lock()
        .map_err(|_| ginkgo_core::AppError::changed())
        .and_then(|mut repository| {
            repository.query(
                scope.campus,
                &scope.date,
                scope.force_refresh,
                classroom_domain::FilterRequest {
                    source_rooms: Default::default(),
                    search: query.search,
                    section: query.section,
                    minimum_free_sections: query.minimum_free_sections,
                    minimum_consecutive_sections: query.minimum_consecutive_sections,
                    building: query.building,
                    sort: match query.sort {
                        ClassroomSort::Name => classroom_domain::Sort::Name,
                        ClassroomSort::Availability => classroom_domain::Sort::Availability,
                        ClassroomSort::Consecutive => classroom_domain::Sort::Consecutive,
                    },
                },
            )
        });
    match result {
        Ok(result) => ClassroomResponse {
            room_count: result.result.summary.room_count as i32,
            building_count: result.result.summary.building_count as i32,
            free_slot_count: result.result.summary.free_slot_count as i32,
            buildings: result
                .result
                .buildings
                .into_iter()
                .map(|(name, rooms)| ClassroomBuilding {
                    name,
                    rooms: rooms
                        .into_iter()
                        .map(|r| ClassroomRow {
                            section_states: r
                                .section_states()
                                .into_iter()
                                .map(|(number, available)| SectionState { number, available })
                                .collect(),
                            id: r.room.id,
                            name: r.room.name,
                            floor: r.room.floorid,
                            sections: r.sections,
                            longest_run: r.longest_run as i32,
                        })
                        .collect(),
                })
                .collect(),
            fetched_at: Some(result.fetched_at),
            from_cache: result.from_cache,
            failure: None,
            failure_detail: None,
        },
        Err(error) => ClassroomResponse {
            buildings: vec![],
            room_count: 0,
            building_count: 0,
            free_slot_count: 0,
            fetched_at: None,
            from_cache: false,
            failure: Some(error.code.into()),
            failure_detail: error.detail,
        },
    }
}
