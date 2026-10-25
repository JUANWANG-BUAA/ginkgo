//! Feature implementation behind the stable live API.
use super::*;

pub(super) async fn load_classrooms(scope: LiveScope, query: ClassroomQuery) -> ClassroomResponse {
    let _access = SESSION_ACCESS.read().await;
    let Ok(service) = service() else {
        return ClassroomResponse {
            buildings: vec![],
            room_count: 0,
            building_count: 0,
            free_slot_count: 0,
            fetched_at: None,
            from_cache: false,
            failure: Some(FailureCode::CredentialStore),
            failure_detail: None,
        };
    };
    let input = ClassroomQueryInput {
        campus: scope.campus,
        date: scope.date,
        force_refresh: scope.force_refresh,
        search: query.search,
        section: query.section,
        minimum_free_sections: query.minimum_free_sections,
        minimum_consecutive_sections: query.minimum_consecutive_sections,
        building: query.building,
        sort: classroom_sort(query.sort),
    };
    match bounded_read(service.load_classrooms(&input)).await {
        Ok(outcome) => classroom_response(outcome),
        Err(error) => {
            let (failure, failure_detail) = failure(&error);
            ClassroomResponse {
                buildings: vec![],
                room_count: 0,
                building_count: 0,
                free_slot_count: 0,
                fetched_at: None,
                from_cache: false,
                failure,
                failure_detail,
            }
        }
    }
}
