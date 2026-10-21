//! FFI DTOs and mapping only. Business rules remain in ginkgo_core.
use ginkgo_core::{application, features::classroom, ErrorCode};

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

#[derive(Clone, Copy)]
pub enum ClassroomSort {
    Name,
    Availability,
    Consecutive,
}

pub struct ClassroomQuery {
    pub search: String,
    pub section: i32,
    pub minimum_free_sections: i32,
    pub minimum_consecutive_sections: i32,
    pub building: Option<String>,
    pub sort: ClassroomSort,
}

pub struct SectionState {
    pub number: i32,
    pub available: bool,
}

pub struct ClassroomRow {
    pub id: String,
    pub name: String,
    pub floor: String,
    pub sections: Vec<i32>,
    pub longest_run: i32,
    pub section_states: Vec<SectionState>,
}

pub struct ClassroomBuilding {
    pub name: String,
    pub rooms: Vec<ClassroomRow>,
}
pub enum FailureCode {
    InvalidRequest,
    ChangedResponse,
    UnsupportedContract,
    SessionExpired,
    ServiceUnavailable,
    CaptchaRequired,
    InvalidCredentials,
    PreLoginTip,
    AccessPolicyDenied,
    RedirectLimit,
    UnsupportedPortal,
    CredentialStore,
    BusinessRejected,
}

impl From<ErrorCode> for FailureCode {
    fn from(code: ErrorCode) -> Self {
        match code {
            ErrorCode::InvalidRequest => Self::InvalidRequest,
            ErrorCode::ChangedResponse => Self::ChangedResponse,
            ErrorCode::UnsupportedContract => Self::UnsupportedContract,
            ErrorCode::SessionExpired => Self::SessionExpired,
            ErrorCode::ServiceUnavailable => Self::ServiceUnavailable,
            ErrorCode::CaptchaRequired => Self::CaptchaRequired,
            ErrorCode::InvalidCredentials => Self::InvalidCredentials,
            ErrorCode::PreLoginTip => Self::PreLoginTip,
            ErrorCode::AccessPolicyDenied => Self::AccessPolicyDenied,
            ErrorCode::RedirectLimit => Self::RedirectLimit,
            ErrorCode::UnsupportedPortal => Self::UnsupportedPortal,
            ErrorCode::CredentialStore => Self::CredentialStore,
            ErrorCode::BusinessRejected => Self::BusinessRejected,
        }
    }
}

pub struct ClassroomResponse {
    pub buildings: Vec<ClassroomBuilding>,
    pub room_count: i32,
    pub building_count: i32,
    pub free_slot_count: i32,
    pub fetched_at: Option<String>,
    pub from_cache: bool,
    pub failure: Option<FailureCode>,
    pub failure_detail: Option<String>,
}

pub fn load_demo_classrooms(query: ClassroomQuery) -> ClassroomResponse {
    let sort = match query.sort {
        ClassroomSort::Name => classroom::Sort::Name,
        ClassroomSort::Availability => classroom::Sort::Availability,
        ClassroomSort::Consecutive => classroom::Sort::Consecutive,
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

pub struct RuleExamples {
    pub local_date: String,
    pub minutes_since_midnight: i32,
    pub time_zone: String,
    pub cached_weeks: Vec<i32>,
    pub selected_week: i32,
    pub course_names: Vec<String>,
    pub failure: Option<FailureCode>,
}

pub fn load_rule_examples() -> RuleExamples {
    match application::demo_rules() {
        Ok((day, snapshot)) => RuleExamples {
            local_date: day.local_date,
            minutes_since_midnight: day.minutes_since_midnight as i32,
            time_zone: day.time_zone,
            cached_weeks: snapshot
                .term_courses
                .as_ref()
                .into_iter()
                .flat_map(|weeks| weeks.keys())
                .filter_map(|key| key.parse::<i32>().ok())
                .collect(),
            selected_week: snapshot.week_number,
            course_names: snapshot
                .courses
                .into_iter()
                .map(|course| course.name)
                .collect(),
            failure: None,
        },
        Err(error) => RuleExamples {
            local_date: String::new(),
            minutes_since_midnight: 0,
            time_zone: String::new(),
            cached_weeks: vec![],
            selected_week: 0,
            course_names: vec![],
            failure: Some(error.code.into()),
        },
    }
}

pub struct ScheduleTerm {
    pub id: String,
    pub name: String,
    pub selected: bool,
}

pub struct ScheduleWeek {
    pub number: i32,
    pub start_date: String,
    pub end_date: String,
    pub current: bool,
}

pub struct ScheduleCourse {
    pub id: String,
    pub name: String,
    pub day: i32,
    pub start_section: i32,
    pub end_section: i32,
    pub start_time: Option<String>,
    pub end_time: Option<String>,
    pub place: Option<String>,
    pub teacher: Option<String>,
    pub color: Option<String>,
}

pub struct ScheduleExam {
    pub id: String,
    pub course_name: String,
    pub course_no: Option<String>,
    pub exam_time_description: Option<String>,
    pub exam_date: Option<String>,
    pub start_time: Option<String>,
    pub end_time: Option<String>,
    pub exam_place: Option<String>,
    pub exam_seat_no: Option<String>,
    pub week: Option<i32>,
    pub exam_status: Option<String>,
    pub exam_type: Option<String>,
}

pub struct ScheduleResponse {
    pub terms: Vec<ScheduleTerm>,
    pub weeks: Vec<ScheduleWeek>,
    pub term_id: String,
    pub week_number: i32,
    pub courses: Vec<ScheduleCourse>,
    pub exams: Vec<ScheduleExam>,
    pub fetched_at: Option<String>,
    pub failure: Option<FailureCode>,
    pub failure_detail: Option<String>,
}

pub fn load_demo_schedule() -> ScheduleResponse {
    match application::demo_schedule::load() {
        Ok(bundle) => ScheduleResponse {
            term_id: bundle
                .terms
                .iter()
                .find(|term| term.selected)
                .or_else(|| bundle.terms.first())
                .map(|term| term.id.clone())
                .unwrap_or_default(),
            terms: bundle
                .terms
                .into_iter()
                .map(|term| ScheduleTerm {
                    id: term.id,
                    name: term.name,
                    selected: term.selected,
                })
                .collect(),
            weeks: bundle
                .weeks
                .into_iter()
                .map(|week| ScheduleWeek {
                    number: week.number,
                    start_date: week.start_date.to_string(),
                    end_date: week.end_date.to_string(),
                    current: week.current,
                })
                .collect(),
            week_number: bundle.week_number,
            courses: bundle
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
            exams: bundle
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
            fetched_at: None,
            failure: None,
            failure_detail: None,
        },
        Err(error) => ScheduleResponse {
            terms: vec![],
            weeks: vec![],
            term_id: String::new(),
            week_number: 0,
            courses: vec![],
            exams: vec![],
            fetched_at: None,
            failure: Some(error.code.into()),
            failure_detail: error.detail,
        },
    }
}

pub struct GradeCourse {
    pub id: String,
    pub name: String,
    pub code: Option<String>,
    pub credit: Option<f64>,
    pub score: String,
    pub score_value: Option<f64>,
    pub score_type: Option<String>,
    pub course_type: Option<String>,
}

pub struct GradeSummary {
    pub course_count: i32,
    pub credit_total: f64,
    pub weighted_average: Option<f64>,
    pub grade_point_average: Option<f64>,
}

pub struct GradeResponse {
    pub term_id: String,
    pub courses: Vec<GradeCourse>,
    pub summary: GradeSummary,
    pub fetched_at: Option<String>,
    pub failure: Option<FailureCode>,
    pub failure_detail: Option<String>,
}

pub fn load_demo_grades() -> GradeResponse {
    match application::demo_grades::load() {
        Ok(bundle) => GradeResponse {
            term_id: bundle.term_id,
            summary: GradeSummary {
                course_count: bundle.summary.course_count,
                credit_total: bundle.summary.credit_total,
                weighted_average: bundle.summary.weighted_average,
                grade_point_average: bundle.summary.grade_point_average,
            },
            courses: bundle
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
            fetched_at: None,
            failure: None,
            failure_detail: None,
        },
        Err(error) => GradeResponse {
            term_id: String::new(),
            courses: vec![],
            summary: GradeSummary {
                course_count: 0,
                credit_total: 0.0,
                weighted_average: None,
                grade_point_average: None,
            },
            fetched_at: None,
            failure: Some(error.code.into()),
            failure_detail: error.detail,
        },
    }
}

pub struct TodayCourse {
    pub name: String,
    pub place: Option<String>,
    pub time: Option<String>,
    pub short_name: Option<String>,
}

pub struct TodayResponse {
    pub date: String,
    pub courses: Vec<TodayCourse>,
    pub fetched_at: Option<String>,
    pub failure: Option<FailureCode>,
    pub failure_detail: Option<String>,
}

pub fn load_demo_today() -> TodayResponse {
    match application::demo_today::load() {
        Ok(bundle) => TodayResponse {
            date: bundle.date,
            courses: bundle
                .courses
                .into_iter()
                .map(|course| TodayCourse {
                    name: course.name,
                    place: course.place,
                    time: course.time,
                    short_name: course.short_name,
                })
                .collect(),
            fetched_at: None,
            failure: None,
            failure_detail: None,
        },
        Err(error) => TodayResponse {
            date: String::new(),
            courses: vec![],
            fetched_at: None,
            failure: Some(error.code.into()),
            failure_detail: error.detail,
        },
    }
}

pub enum HomeworkStatus {
    Pending,
    Submitted,
    Unknown,
}

pub struct HomeworkItem {
    pub teacher_name: Option<String>,
    pub id: String,
    pub course_id: Option<String>,
    pub course_name: String,
    pub title: String,
    pub published_at: Option<String>,
    pub due_at: Option<String>,
    pub status: HomeworkStatus,
    pub status_detail: Option<String>,
    pub score: Option<String>,
}

pub struct HomeworkResponse {
    pub term_name: String,
    pub term_code: String,
    pub items: Vec<HomeworkItem>,
    pub failure: Option<FailureCode>,
    pub failure_detail: Option<String>,
}

pub fn load_demo_homework() -> HomeworkResponse {
    match application::demo_homework::load() {
        Ok(bundle) => HomeworkResponse {
            term_name: bundle.term_name,
            term_code: bundle.term_code,
            items: bundle
                .page
                .items
                .into_iter()
                .map(|item| HomeworkItem {
                    id: item.id,
                    course_id: item.course_id,
                    course_name: item.course_name,
                    teacher_name: item.teacher_name,
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
            failure: None,
            failure_detail: None,
        },
        Err(error) => HomeworkResponse {
            term_name: String::new(),
            term_code: String::new(),
            items: vec![],
            failure: Some(error.code.into()),
            failure_detail: error.detail,
        },
    }
}

pub struct QueryDates {
    pub today: String,
    pub tomorrow: String,
    pub failure: Option<FailureCode>,
}
pub fn load_query_dates(instant: String) -> QueryDates {
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

pub struct DemoScope {
    pub campus: i32,
    pub date: String,
    pub force_refresh: bool,
}

pub fn query_demo_classrooms(scope: DemoScope, query: ClassroomQuery) -> ClassroomResponse {
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
                classroom::FilterRequest {
                    source_rooms: Default::default(),
                    search: query.search,
                    section: query.section,
                    minimum_free_sections: query.minimum_free_sections,
                    minimum_consecutive_sections: query.minimum_consecutive_sections,
                    building: query.building,
                    sort: match query.sort {
                        ClassroomSort::Name => classroom::Sort::Name,
                        ClassroomSort::Availability => classroom::Sort::Availability,
                        ClassroomSort::Consecutive => classroom::Sort::Consecutive,
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

pub enum CheckInStatus {
    NotSigned,
    Signed,
    Unknown,
}

pub struct CheckInCourse {
    pub id: String,
    pub course_id: Option<String>,
    pub course_num: Option<String>,
    pub course_name: String,
    pub begins_at: String,
    pub ends_at: String,
    pub status: CheckInStatus,
    pub teacher_name: Option<String>,
    pub classroom_name: Option<String>,
    pub merged_record_count: i32,
    pub conflicting: bool,
}

pub struct CheckInResponse {
    /// School-local date, yyyy-MM-dd.
    pub date: String,
    pub courses: Vec<CheckInCourse>,
    pub fetched_at: Option<String>,
    pub from_cache: bool,
    pub stale: bool,
    pub failure: Option<FailureCode>,
    pub failure_detail: Option<String>,
}

fn checkin_course(course: ginkgo_core::features::checkin::CheckInCourse) -> CheckInCourse {
    CheckInCourse {
        id: course.id,
        course_id: course.course_id,
        course_num: course.course_num,
        course_name: course.course_name,
        begins_at: course.begins_at,
        ends_at: course.ends_at,
        status: match course.status {
            ginkgo_core::features::checkin::CheckInStatus::NotSigned => CheckInStatus::NotSigned,
            ginkgo_core::features::checkin::CheckInStatus::Signed => CheckInStatus::Signed,
            ginkgo_core::features::checkin::CheckInStatus::Unknown => CheckInStatus::Unknown,
        },
        teacher_name: course.teacher_name,
        classroom_name: course.classroom_name,
        merged_record_count: course.merged_record_count as i32,
        conflicting: course.conflicting,
    }
}

pub fn load_demo_checkin() -> CheckInResponse {
    match application::demo_checkin::load() {
        Ok(day) => CheckInResponse {
            date: day.date,
            courses: day.courses.into_iter().map(checkin_course).collect(),
            fetched_at: None,
            from_cache: false,
            stale: false,
            failure: None,
            failure_detail: None,
        },
        Err(error) => CheckInResponse {
            date: String::new(),
            courses: vec![],
            fetched_at: None,
            from_cache: false,
            stale: false,
            failure: Some(error.code.into()),
            failure_detail: error.detail,
        },
    }
}

pub struct LibraryVenue {
    pub id: String,
    pub name: String,
    pub free: i32,
    pub total: i32,
}

pub struct LibraryArea {
    pub id: String,
    pub name: String,
    pub free: i32,
    pub total: i32,
}

pub struct LibrarySlot {
    pub id: String,
    pub day: String,
    pub start: String,
    pub end: String,
}

pub struct LibrarySeat {
    pub id: String,
    pub name: String,
    pub status_name: String,
    pub available: bool,
}

pub struct LibraryBooking {
    pub id: String,
    pub title: String,
    pub area_name: String,
    pub seat_number: String,
    pub day: String,
    pub start_time: String,
    pub end_time: String,
    pub status_name: String,
    pub actions: Option<Vec<String>>,
}

pub struct LibraryVenuesResponse {
    pub venues: Vec<LibraryVenue>,
    pub fetched_at: Option<String>,
    pub from_cache: bool,
    pub stale: bool,
    pub failure: Option<FailureCode>,
    pub failure_detail: Option<String>,
}

pub struct LibraryAreasResponse {
    pub areas: Vec<LibraryArea>,
    pub failure: Option<FailureCode>,
    pub failure_detail: Option<String>,
}

pub struct LibrarySlotsResponse {
    pub slots: Vec<LibrarySlot>,
    pub failure: Option<FailureCode>,
    pub failure_detail: Option<String>,
}

pub struct LibrarySeatsResponse {
    pub seats: Vec<LibrarySeat>,
    pub failure: Option<FailureCode>,
    pub failure_detail: Option<String>,
}

pub struct LibraryBookingsResponse {
    pub bookings: Vec<LibraryBooking>,
    pub fetched_at: Option<String>,
    pub from_cache: bool,
    pub stale: bool,
    pub failure: Option<FailureCode>,
    pub failure_detail: Option<String>,
}

pub struct LibraryDemoResponse {
    pub venues: Vec<LibraryVenue>,
    pub areas: Vec<LibraryArea>,
    pub slots: Vec<LibrarySlot>,
    pub seats: Vec<LibrarySeat>,
    pub bookings: Vec<LibraryBooking>,
}

fn library_venue(value: ginkgo_core::features::library::LibraryVenue) -> LibraryVenue {
    LibraryVenue {
        id: value.id,
        name: value.name,
        free: value.free,
        total: value.total,
    }
}

fn library_area(value: ginkgo_core::features::library::LibraryArea) -> LibraryArea {
    LibraryArea {
        id: value.id,
        name: value.name,
        free: value.free,
        total: value.total,
    }
}

fn library_slot(value: ginkgo_core::features::library::LibrarySlot) -> LibrarySlot {
    LibrarySlot {
        id: value.id,
        day: value.day,
        start: value.start,
        end: value.end,
    }
}

fn library_seat(value: ginkgo_core::features::library::LibrarySeat) -> LibrarySeat {
    LibrarySeat {
        id: value.id,
        name: value.name,
        status_name: value.status_name,
        available: value.available,
    }
}

fn library_booking(value: ginkgo_core::features::library::LibraryBooking) -> LibraryBooking {
    let actions = Some(ginkgo_core::features::library::current_actions(&value));
    LibraryBooking {
        actions,
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

pub fn load_demo_library() -> LibraryDemoResponse {
    match application::demo_library::load() {
        Ok(library) => LibraryDemoResponse {
            venues: library.venues.into_iter().map(library_venue).collect(),
            areas: library.areas.into_iter().map(library_area).collect(),
            slots: library.slots.into_iter().map(library_slot).collect(),
            seats: library.seats.into_iter().map(library_seat).collect(),
            bookings: library.bookings.into_iter().map(library_booking).collect(),
        },
        Err(_) => LibraryDemoResponse {
            venues: vec![],
            areas: vec![],
            slots: vec![],
            seats: vec![],
            bookings: vec![],
        },
    }
}
