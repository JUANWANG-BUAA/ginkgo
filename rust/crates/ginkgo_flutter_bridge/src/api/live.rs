//! Real-account bridge. Cookies, credentials and recovery stay in Rust; these
//! functions only map coarse use cases to stable DTOs.
use super::mirror::{
    CheckInCourse as CheckInCourseDto, CheckInResponse, CheckInStatus as CheckInStatusDto,
    ClassroomBuilding, ClassroomQuery, ClassroomResponse, ClassroomRow, ClassroomSort, FailureCode,
    GradeCourse, GradeResponse, GradeSummary, LibraryArea as LibraryAreaDto, LibraryAreasResponse,
    LibraryBooking as LibraryBookingDto, LibraryBookingsResponse, LibrarySeat as LibrarySeatDto,
    LibrarySeatsResponse, LibrarySlot as LibrarySlotDto, LibrarySlotsResponse,
    LibraryVenue as LibraryVenueDto, LibraryVenuesResponse, ScheduleCourse, ScheduleExam,
    ScheduleResponse, ScheduleTerm, ScheduleWeek, SectionState, TodayCourse, TodayResponse,
};
use ginkgo_core::{
    adapters::reqwest_transport::ReqwestTransport,
    application::{
        CheckInOutcome, ClassroomOutcome, ClassroomQueryInput, GradeOutcome, ScheduleOutcome,
        ScheduleQueryInput, SessionOutcome, SessionService, SessionStatus, TodayOutcome,
    },
    auth::{
        cas::CaptchaChallenge,
        platform::{platform_vault, PlatformVault},
        vault::verify_vault_round_trip,
        CredentialVault,
    },
    features::classroom,
    AppError,
};
use std::sync::OnceLock;

type LiveService = SessionService<ReqwestTransport, PlatformVault>;

static SERVICE: OnceLock<Result<LiveService, AppError>> = OnceLock::new();

fn service() -> Result<&'static LiveService, AppError> {
    SERVICE
        .get_or_init(|| {
            let transport = ReqwestTransport::new().map_err(|_| AppError::unavailable())?;
            let vault = platform_vault()?;
            Ok(SessionService::new(
                ginkgo_core::auth::session::Session::new(transport),
                vault,
            ))
        })
        .as_ref()
        .map_err(Clone::clone)
}

#[derive(Clone, Copy)]
pub enum RouteChoice {
    Automatic,
    Direct,
    WebVpn,
}

#[derive(Clone, Copy)]
pub enum SessionState {
    SignedOut,
    SignedIn,
    CaptchaRequired,
}

pub struct SessionResponse {
    pub state: SessionState,
    pub account: Option<String>,
    pub name: Option<String>,
    pub captcha_id: Option<String>,
    pub captcha_image_url: Option<String>,
    pub remembered: bool,
    pub route: Option<RouteChoice>,
    pub failure: Option<FailureCode>,
    pub failure_detail: Option<String>,
}

pub struct LiveScope {
    pub campus: i32,
    pub date: String,
    pub force_refresh: bool,
}

fn failure(error: &AppError) -> (Option<FailureCode>, Option<String>) {
    (Some(error.code.clone().into()), error.detail.clone())
}

fn signed_out() -> SessionResponse {
    SessionResponse {
        state: SessionState::SignedOut,
        account: None,
        name: None,
        captcha_id: None,
        captcha_image_url: None,
        remembered: false,
        route: None,
        failure: None,
        failure_detail: None,
    }
}

fn failure_response(error: AppError) -> SessionResponse {
    let (failure, failure_detail) = failure(&error);
    SessionResponse {
        failure,
        failure_detail,
        ..signed_out()
    }
}

fn status_response(status: SessionStatus) -> SessionResponse {
    if let (Some(account), Some(profile)) = (status.account, status.profile) {
        SessionResponse {
            state: SessionState::SignedIn,
            account: Some(account),
            name: Some(profile.name),
            route: Some(match status.route {
                ginkgo_core::application::RoutePreference::Automatic => RouteChoice::Automatic,
                ginkgo_core::application::RoutePreference::Direct => RouteChoice::Direct,
                ginkgo_core::application::RoutePreference::WebVpn => RouteChoice::WebVpn,
            }),
            ..signed_out()
        }
    } else {
        signed_out()
    }
}

fn outcome_response(
    service: &LiveService,
    outcome: SessionOutcome,
    remembered: bool,
) -> SessionResponse {
    match outcome {
        SessionOutcome::SignedIn { .. } => SessionResponse {
            remembered,
            ..status_response(service.status())
        },
        SessionOutcome::CaptchaRequired(CaptchaChallenge { id, image_url, .. }) => {
            SessionResponse {
                state: SessionState::CaptchaRequired,
                captcha_id: Some(id),
                captcha_image_url: Some(image_url),
                ..signed_out()
            }
        }
        SessionOutcome::SignedOut => signed_out(),
    }
}

pub async fn login(
    account: String,
    password: String,
    captcha: Option<String>,
    remember: bool,
) -> SessionResponse {
    let service = match service() {
        Ok(service) => service,
        Err(error) => return failure_response(error),
    };
    match service
        .sign_in(&account, &password, captcha.as_deref(), remember)
        .await
    {
        Ok(outcome) => {
            let remembered = matches!(
                &outcome,
                SessionOutcome::SignedIn {
                    remembered: true,
                    ..
                }
            );
            outcome_response(service, outcome, remembered)
        }
        Err(error) => failure_response(error),
    }
}

pub async fn restore_session() -> SessionResponse {
    if SERVICE.get().is_none() {
        let vault = match platform_vault() {
            Ok(vault) => vault,
            Err(error) => return failure_response(error),
        };
        match vault.accounts() {
            Ok(accounts) if accounts.is_empty() => return signed_out(),
            Ok(_) => {}
            Err(error) => return failure_response(error),
        }
    }
    let service = match service() {
        Ok(service) => service,
        Err(error) => return failure_response(error),
    };
    match service.restore().await {
        Ok(outcome) => {
            let remembered = matches!(
                &outcome,
                SessionOutcome::SignedIn {
                    remembered: true,
                    ..
                }
            );
            outcome_response(service, outcome, remembered)
        }
        Err(error) => failure_response(error),
    }
}

pub async fn sign_out() -> SessionResponse {
    let Some(Ok(service)) = SERVICE.get() else {
        return signed_out();
    };
    service.sign_out().await;
    signed_out()
}

pub async fn set_route(route: RouteChoice) -> SessionResponse {
    let service = match service() {
        Ok(service) => service,
        Err(error) => return failure_response(error),
    };
    let preference = match route {
        RouteChoice::Automatic => ginkgo_core::application::RoutePreference::Automatic,
        RouteChoice::Direct => ginkgo_core::application::RoutePreference::Direct,
        RouteChoice::WebVpn => ginkgo_core::application::RoutePreference::WebVpn,
    };
    service.set_route(preference);
    status_response(service.status())
}

pub async fn clear_cache() -> bool {
    match service() {
        Ok(service) => {
            service.clear_snapshots();
            true
        }
        Err(_) => false,
    }
}

pub async fn session_status() -> SessionResponse {
    match SERVICE.get() {
        Some(Ok(service)) => status_response(service.status()),
        Some(Err(error)) => failure_response(error.clone()),
        None => signed_out(),
    }
}

fn classroom_sort(sort: ClassroomSort) -> classroom::Sort {
    match sort {
        ClassroomSort::Name => classroom::Sort::Name,
        ClassroomSort::Availability => classroom::Sort::Availability,
        ClassroomSort::Consecutive => classroom::Sort::Consecutive,
    }
}

fn classroom_response(outcome: ClassroomOutcome) -> ClassroomResponse {
    let (failure, failure_detail) = outcome
        .failure
        .as_ref()
        .map(failure)
        .unwrap_or((None, None));
    ClassroomResponse {
        buildings: outcome
            .result
            .buildings
            .into_iter()
            .map(|(name, rooms)| ClassroomBuilding {
                name,
                rooms: rooms
                    .into_iter()
                    .map(|room| ClassroomRow {
                        section_states: room
                            .section_states()
                            .into_iter()
                            .map(|(number, available)| SectionState { number, available })
                            .collect(),
                        id: room.room.id,
                        name: room.room.name,
                        floor: room.room.floorid,
                        sections: room.sections,
                        longest_run: room.longest_run as i32,
                    })
                    .collect(),
            })
            .collect(),
        room_count: outcome.result.summary.room_count as i32,
        building_count: outcome.result.summary.building_count as i32,
        free_slot_count: outcome.result.summary.free_slot_count as i32,
        fetched_at: Some(outcome.fetched_at),
        from_cache: outcome.from_cache,
        failure,
        failure_detail,
    }
}

pub async fn load_classrooms(scope: LiveScope, query: ClassroomQuery) -> ClassroomResponse {
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
    match service.load_classrooms(&input).await {
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

pub async fn load_schedule(
    term_id: Option<String>,
    week: Option<i32>,
    force_refresh: bool,
) -> ScheduleResponse {
    let Ok(service) = service() else {
        return schedule_failure(FailureCode::CredentialStore, None);
    };
    match service
        .load_schedule(&ScheduleQueryInput {
            term_id,
            week,
            force_refresh,
        })
        .await
    {
        Ok(outcome) => schedule_response(outcome),
        Err(error) => schedule_failure(error.code.clone().into(), error.detail),
    }
}

fn schedule_failure(failure: FailureCode, detail: Option<String>) -> ScheduleResponse {
    ScheduleResponse {
        terms: vec![],
        weeks: vec![],
        term_id: String::new(),
        week_number: 0,
        courses: vec![],
        exams: vec![],
        fetched_at: None,
        failure: Some(failure),
        failure_detail: detail,
    }
}

fn schedule_response(outcome: ScheduleOutcome) -> ScheduleResponse {
    let (failure, failure_detail) = outcome
        .failure
        .as_ref()
        .map(failure)
        .unwrap_or((None, None));
    ScheduleResponse {
        terms: outcome
            .data
            .terms
            .into_iter()
            .map(|term| ScheduleTerm {
                id: term.id,
                name: term.name,
                selected: term.selected,
            })
            .collect(),
        weeks: outcome
            .data
            .weeks
            .into_iter()
            .map(|week| ScheduleWeek {
                number: week.number,
                start_date: week.start_date.to_string(),
                end_date: week.end_date.to_string(),
                current: week.current,
            })
            .collect(),
        term_id: outcome.data.term_id,
        week_number: outcome.data.week_number,
        courses: outcome
            .data
            .courses
            .into_iter()
            .map(|course| ScheduleCourse {
                id: course.id,
                name: course.name,
                day: course.day,
                start_section: course.start_section,
                end_section: course.end_section,
                start_time: course.start_time,
                end_time: course.end_time,
                place: course.place,
                teacher: course.teacher,
                color: course.color,
            })
            .collect(),
        exams: outcome
            .data
            .exams
            .into_iter()
            .map(|exam| ScheduleExam {
                id: exam.id,
                course_name: exam.course_name,
                course_no: exam.course_no,
                exam_time_description: exam.exam_time_description,
                exam_date: exam.exam_date,
                start_time: exam.start_time,
                end_time: exam.end_time,
                exam_place: exam.exam_place,
                exam_seat_no: exam.exam_seat_no,
                week: exam.week,
                exam_status: exam.exam_status,
                exam_type: exam.exam_type,
            })
            .collect(),
        fetched_at: Some(outcome.fetched_at),
        failure,
        failure_detail,
    }
}

pub async fn load_today(force_refresh: bool) -> TodayResponse {
    let Ok(service) = service() else {
        return TodayResponse {
            date: String::new(),
            courses: vec![],
            fetched_at: None,
            failure: Some(FailureCode::CredentialStore),
            failure_detail: None,
        };
    };
    match service.load_today(force_refresh).await {
        Ok(outcome) => today_response(outcome),
        Err(error) => {
            let (failure, failure_detail) = failure(&error);
            TodayResponse {
                date: String::new(),
                courses: vec![],
                fetched_at: None,
                failure,
                failure_detail,
            }
        }
    }
}

fn today_response(outcome: TodayOutcome) -> TodayResponse {
    let (failure, failure_detail) = outcome
        .failure
        .as_ref()
        .map(failure)
        .unwrap_or((None, None));
    TodayResponse {
        date: outcome.date,
        courses: outcome
            .courses
            .into_iter()
            .map(|course| TodayCourse {
                name: course.name,
                place: course.place,
                time: course.time,
                short_name: course.short_name,
            })
            .collect(),
        fetched_at: Some(outcome.fetched_at),
        failure,
        failure_detail,
    }
}

pub async fn load_checkin_today(force_refresh: bool) -> CheckInResponse {
    let Ok(service) = service() else {
        return checkin_failure(FailureCode::CredentialStore, None);
    };
    match service.load_checkin(force_refresh).await {
        Ok(outcome) => checkin_response(outcome),
        Err(error) => checkin_failure(error.code.clone().into(), error.detail),
    }
}

fn checkin_failure(failure: FailureCode, detail: Option<String>) -> CheckInResponse {
    CheckInResponse {
        date: String::new(),
        courses: vec![],
        fetched_at: None,
        from_cache: false,
        stale: false,
        failure: Some(failure),
        failure_detail: detail,
    }
}

fn checkin_response(outcome: CheckInOutcome) -> CheckInResponse {
    let (failure, failure_detail) = outcome
        .failure
        .as_ref()
        .map(failure)
        .unwrap_or((None, None));
    CheckInResponse {
        date: outcome.date,
        courses: outcome
            .courses
            .into_iter()
            .map(|course| CheckInCourseDto {
                id: course.id,
                course_id: course.course_id,
                course_num: course.course_num,
                course_name: course.course_name,
                begins_at: course.begins_at,
                ends_at: course.ends_at,
                status: match course.status {
                    ginkgo_core::features::checkin::CheckInStatus::NotSigned => {
                        CheckInStatusDto::NotSigned
                    }
                    ginkgo_core::features::checkin::CheckInStatus::Signed => {
                        CheckInStatusDto::Signed
                    }
                    ginkgo_core::features::checkin::CheckInStatus::Unknown => {
                        CheckInStatusDto::Unknown
                    }
                },
                teacher_name: course.teacher_name,
                classroom_name: course.classroom_name,
                merged_record_count: course.merged_record_count as i32,
                conflicting: course.conflicting,
            })
            .collect(),
        fetched_at: Some(outcome.fetched_at),
        from_cache: outcome.from_cache,
        stale: outcome.stale,
        failure,
        failure_detail,
    }
}

pub struct GradeTermsResponse {
    pub terms: Vec<ScheduleTerm>,
    pub failure: Option<FailureCode>,
    pub failure_detail: Option<String>,
}

pub async fn load_grade_terms() -> GradeTermsResponse {
    let service = match service() {
        Ok(service) => service,
        Err(error) => {
            let (failure, failure_detail) = failure(&error);
            return GradeTermsResponse {
                terms: vec![],
                failure,
                failure_detail,
            };
        }
    };
    match service.load_grade_terms().await {
        Ok(terms) => GradeTermsResponse {
            terms: terms
                .into_iter()
                .map(|term| ScheduleTerm {
                    id: term.id,
                    name: term.name,
                    selected: term.selected,
                })
                .collect(),
            failure: None,
            failure_detail: None,
        },
        Err(error) => {
            let (failure, failure_detail) = failure(&error);
            GradeTermsResponse {
                terms: vec![],
                failure,
                failure_detail,
            }
        }
    }
}

pub async fn load_grades(term_code: Option<String>, force_refresh: bool) -> GradeResponse {
    let Ok(service) = service() else {
        return grade_failure(FailureCode::CredentialStore, None);
    };
    match service
        .load_grades(term_code.as_deref(), force_refresh)
        .await
    {
        Ok(outcome) => grade_response(outcome),
        Err(error) => grade_failure(error.code.clone().into(), error.detail),
    }
}

fn grade_failure(failure: FailureCode, detail: Option<String>) -> GradeResponse {
    GradeResponse {
        term_id: String::new(),
        courses: vec![],
        summary: GradeSummary {
            course_count: 0,
            credit_total: 0.0,
            weighted_average: None,
            grade_point_average: None,
        },
        fetched_at: None,
        failure: Some(failure),
        failure_detail: detail,
    }
}

fn grade_response(outcome: GradeOutcome) -> GradeResponse {
    let (failure, failure_detail) = outcome
        .failure
        .as_ref()
        .map(failure)
        .unwrap_or((None, None));
    GradeResponse {
        term_id: outcome.term_id,
        summary: GradeSummary {
            course_count: outcome.summary.course_count,
            credit_total: outcome.summary.credit_total,
            weighted_average: outcome.summary.weighted_average,
            grade_point_average: outcome.summary.grade_point_average,
        },
        courses: outcome
            .courses
            .into_iter()
            .map(|course| GradeCourse {
                id: course.id,
                name: course.name,
                code: course.code,
                credit: course.credit,
                score: course.score,
                score_value: course.score_value,
                score_type: course.score_type,
                course_type: course.course_type,
            })
            .collect(),
        fetched_at: Some(outcome.fetched_at),
        failure,
        failure_detail,
    }
}

/// Device-acceptance diagnostic: write, read and delete one synthetic secret.
/// It never touches account credentials and returns only a boolean.
pub fn verify_credential_storage(account: String, secret: String) -> bool {
    match platform_vault() {
        Ok(vault) => verify_vault_round_trip(&vault, &account, &secret),
        Err(_) => false,
    }
}

fn library_venue(value: ginkgo_core::features::library::LibraryVenue) -> LibraryVenueDto {
    LibraryVenueDto {
        id: value.id,
        name: value.name,
        free: value.free,
        total: value.total,
    }
}

fn library_area(value: ginkgo_core::features::library::LibraryArea) -> LibraryAreaDto {
    LibraryAreaDto {
        id: value.id,
        name: value.name,
        free: value.free,
        total: value.total,
    }
}

fn library_slot(value: ginkgo_core::features::library::LibrarySlot) -> LibrarySlotDto {
    LibrarySlotDto {
        id: value.id,
        day: value.day,
        start: value.start,
        end: value.end,
    }
}

fn library_seat(value: ginkgo_core::features::library::LibrarySeat) -> LibrarySeatDto {
    LibrarySeatDto {
        id: value.id,
        name: value.name,
        status_name: value.status_name,
        available: value.available,
    }
}

fn library_booking(value: ginkgo_core::features::library::LibraryBooking) -> LibraryBookingDto {
    LibraryBookingDto {
        id: value.id,
        title: value.title,
        area_name: value.area_name,
        seat_number: value.seat_number,
        day: value.day,
        start_time: value.start_time,
        end_time: value.end_time,
        status_name: value.status_name,
    }
}

pub async fn load_library_venues(force_refresh: bool) -> LibraryVenuesResponse {
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
    match service.load_library_venues(force_refresh).await {
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

pub async fn load_library_areas(library_id: String) -> LibraryAreasResponse {
    let Ok(service) = service() else {
        return LibraryAreasResponse {
            areas: vec![],
            failure: Some(FailureCode::CredentialStore),
            failure_detail: None,
        };
    };
    match service.load_library_areas(&library_id).await {
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

pub async fn load_library_slots(area_id: String) -> LibrarySlotsResponse {
    let Ok(service) = service() else {
        return LibrarySlotsResponse {
            slots: vec![],
            failure: Some(FailureCode::CredentialStore),
            failure_detail: None,
        };
    };
    match service.load_library_slots(&area_id).await {
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

pub async fn load_library_seats(
    area_id: String,
    slot_id: String,
    day: String,
    start: String,
    end: String,
) -> LibrarySeatsResponse {
    let Ok(service) = service() else {
        return LibrarySeatsResponse {
            seats: vec![],
            failure: Some(FailureCode::CredentialStore),
            failure_detail: None,
        };
    };
    match service
        .load_library_seats(&area_id, &slot_id, &day, &start, &end)
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

pub async fn load_library_bookings(force_refresh: bool) -> LibraryBookingsResponse {
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
    match service.load_library_bookings(force_refresh).await {
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

/// Real SPOC list, API.md §7.1. Demo remains an explicit separate command.
pub async fn load_homework(force_refresh: bool) -> super::mirror::HomeworkResponse {
    use super::mirror::{HomeworkItem, HomeworkResponse, HomeworkStatus};
    let result = match service() {
        Ok(service) => service.load_homework(force_refresh).await,
        Err(error) => Err(error),
    };
    match result {
        Ok(outcome) => HomeworkResponse {
            term_name: outcome.data.term_name,
            term_code: outcome.data.term_code,
            items: outcome
                .data
                .items
                .into_iter()
                .map(|item| HomeworkItem {
                    id: item.id,
                    course_id: item.course_id,
                    course_name: item.course_name,
                    title: item.title,
                    published_at: item.published_at,
                    due_at: item.due_at,
                    status: match item.status {
                        ginkgo_core::features::homework::HomeworkStatus::Pending => {
                            HomeworkStatus::Pending
                        }
                        ginkgo_core::features::homework::HomeworkStatus::Submitted => {
                            HomeworkStatus::Submitted
                        }
                        ginkgo_core::features::homework::HomeworkStatus::Unknown => {
                            HomeworkStatus::Unknown
                        }
                    },
                    status_detail: item.status_detail,
                    score: item.score,
                })
                .collect(),
            failure_detail: None,
            failure: outcome.failure.map(|e| e.code.into()),
        },
        Err(error) => HomeworkResponse {
            term_name: String::new(),
            term_code: String::new(),
            items: vec![],
            failure_detail: None,
            failure: Some(error.code.into()),
        },
    }
}

pub struct HomeworkDetailResponse {
    pub content: Option<String>,
    pub published_at: Option<String>,
    pub due_at: Option<String>,
    pub score: Option<String>,
    pub status: String,
    pub submitted_at: Option<String>,
    pub stale: bool,
    pub failure: Option<FailureCode>,
}

pub async fn load_homework_detail(
    assignment_id: String,
    force_refresh: bool,
) -> HomeworkDetailResponse {
    let result = match service() {
        Ok(service) => {
            service
                .load_homework_detail(&assignment_id, force_refresh)
                .await
        }
        Err(error) => Err(error),
    };
    match result {
        Ok(outcome) => HomeworkDetailResponse {
            content: outcome.data.content,
            published_at: outcome.data.published_at,
            due_at: outcome.data.due_at,
            score: outcome.data.score,
            submitted_at: outcome.data.submitted_at,
            status: match outcome.data.status {
                ginkgo_core::features::homework::HomeworkStatus::Pending => "待完成".into(),
                ginkgo_core::features::homework::HomeworkStatus::Submitted => "已提交".into(),
                ginkgo_core::features::homework::HomeworkStatus::Unknown => "待确认".into(),
            },
            stale: outcome.failure.is_some(),
            failure: outcome.failure.map(|e| e.code.into()),
        },
        Err(error) => HomeworkDetailResponse {
            content: None,
            published_at: None,
            due_at: None,
            score: None,
            submitted_at: None,
            status: "待确认".into(),
            stale: false,
            failure: Some(error.code.into()),
        },
    }
}

/// Sanitized domain JSON, never raw upstream data, credentials or tokens.
pub struct ReadOnlyResponse {
    pub payload: Option<String>,
    pub stale: bool,
    pub failure: Option<FailureCode>,
}
pub async fn load_bykc(force_refresh: bool) -> ReadOnlyResponse {
    let result = match service() {
        Ok(service) => service.load_bykc(force_refresh).await,
        Err(error) => Err(error),
    };
    match result {
        Ok(outcome) => ReadOnlyResponse {
            payload: serde_json::to_string(&outcome.data).ok(),
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

pub fn load_demo_bykc() -> ReadOnlyResponse {
    let result = (|| -> Result<_, AppError> {
        let fixture: serde_json::Value = serde_json::from_str(include_str!(
            "../../../../../fixtures/bykc/catalog-normal-v1.json"
        ))
        .map_err(|_| AppError::changed())?;
        ginkgo_core::features::bykc::parse_catalog(
            &fixture["input"]["config"],
            fixture["input"]["pages"]
                .as_array()
                .ok_or_else(AppError::changed)?,
        )
    })();
    match result {
        Ok(data) => ReadOnlyResponse {
            payload: serde_json::to_string(&data).ok(),
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

pub async fn load_graduate(force_refresh: bool) -> ReadOnlyResponse {
    let result = match service() {
        Ok(service) => service.load_graduate(force_refresh).await,
        Err(error) => Err(error),
    };
    match result {
        Ok(outcome) => ReadOnlyResponse {
            payload: serde_json::to_string(&outcome.data).ok(),
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

pub fn load_demo_graduate() -> ReadOnlyResponse {
    let result = (|| -> Result<_, AppError> {
        let fixture: serde_json::Value = serde_json::from_str(include_str!(
            "../../../../../fixtures/graduate/execution-normal-v1.json"
        ))
        .map_err(|_| AppError::changed())?;
        Ok(ginkgo_core::features::graduate::AcademicData {
            sections: ginkgo_core::features::graduate::parse_execution(&fixture["input"])?,
            notice: None,
        })
    })();
    match result {
        Ok(data) => ReadOnlyResponse {
            payload: serde_json::to_string(&data).ok(),
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

/// Local CRUD only. Account identity comes from Rust, never a Dart-supplied identifier.
pub fn edit_tasks(
    root: String,
    demo: bool,
    action: String,
    id: Option<String>,
    title: Option<String>,
    due: Option<String>,
    completed: Option<bool>,
) -> ReadOnlyResponse {
    let result = if demo {
        ginkgo_core::application::tasks_service::edit(
            std::path::Path::new(&root),
            "ginkgo-isolated-demo",
            &action,
            id.as_deref(),
            title.as_deref(),
            due.as_deref(),
            completed,
        )
    } else {
        service().and_then(|s| {
            s.edit_tasks(
                std::path::Path::new(&root),
                &action,
                id.as_deref(),
                title.as_deref(),
                due.as_deref(),
                completed,
            )
        })
    };
    match result {
        Ok(tasks) => ReadOnlyResponse {
            payload: serde_json::to_string(&tasks).ok(),
            stale: false,
            failure: None,
        },
        Err(e) => ReadOnlyResponse {
            payload: None,
            stale: false,
            failure: Some(e.code.into()),
        },
    }
}
