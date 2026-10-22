//! FFI DTOs and mapping only. Business rules remain in ginkgo_core.
use ginkgo_core::{features::classroom as classroom_domain, ErrorCode};
use ginkgo_runtime::demo as application;

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
    classroom::load_demo_classrooms(query)
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
    academic::load_rule_examples()
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
    academic::load_demo_schedule()
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
    academic::load_demo_grades()
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
    academic::load_demo_today()
}

pub enum HomeworkStatus {
    Pending,
    Submitted,
    Unknown,
}

pub struct HomeworkItem {
    pub course_role: Option<String>,
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
    academic::load_demo_homework()
}

pub struct QueryDates {
    pub today: String,
    pub tomorrow: String,
    pub failure: Option<FailureCode>,
}
pub fn load_query_dates(instant: String) -> QueryDates {
    classroom::load_query_dates(instant)
}

pub struct DemoScope {
    pub campus: i32,
    pub date: String,
    pub force_refresh: bool,
}

pub fn query_demo_classrooms(scope: DemoScope, query: ClassroomQuery) -> ClassroomResponse {
    classroom::query_demo_classrooms(scope, query)
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
    academic::load_demo_checkin()
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

pub(super) fn library_venue(value: ginkgo_core::features::library::LibraryVenue) -> LibraryVenue {
    LibraryVenue {
        id: value.id,
        name: value.name,
        free: value.free,
        total: value.total,
    }
}

pub(super) fn library_area(value: ginkgo_core::features::library::LibraryArea) -> LibraryArea {
    LibraryArea {
        id: value.id,
        name: value.name,
        free: value.free,
        total: value.total,
    }
}

pub(super) fn library_slot(value: ginkgo_core::features::library::LibrarySlot) -> LibrarySlot {
    LibrarySlot {
        id: value.id,
        day: value.day,
        start: value.start,
        end: value.end,
    }
}

pub(super) fn library_seat(value: ginkgo_core::features::library::LibrarySeat) -> LibrarySeat {
    LibrarySeat {
        id: value.id,
        name: value.name,
        status_name: value.status_name,
        available: value.available,
    }
}

pub(super) fn library_booking(
    value: ginkgo_core::features::library::LibraryBooking,
) -> LibraryBooking {
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
    library::load_demo_library()
}

mod academic;
mod classroom;
mod library;
