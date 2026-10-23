//! Real-account bridge. Cookies, credentials and recovery stay in Rust; these
//! functions only map coarse use cases to stable DTOs.
use super::mirror::{
    CheckInCourse as CheckInCourseDto, CheckInResponse, CheckInStatus as CheckInStatusDto,
    ClassroomBuilding, ClassroomQuery, ClassroomResponse, ClassroomRow, ClassroomSort, FailureCode,
    GradeCourse, GradeResponse, GradeSummary, LibraryAreasResponse, LibraryBookingsResponse,
    LibrarySeatsResponse, LibrarySlotsResponse, LibraryVenuesResponse, ScheduleCourse,
    ScheduleExam, ScheduleResponse, ScheduleTerm, ScheduleWeek, SectionState, TodayCourse,
    TodayResponse,
};
use ginkgo_core::{
    application::{
        CheckInOutcome, ClassroomOutcome, ClassroomQueryInput, GradeOutcome, ScheduleOutcome,
        ScheduleQueryInput, SessionOutcome, SessionStatus, TodayOutcome,
    },
    features::classroom as classroom_domain,
    session::CaptchaChallenge,
    AppError,
};
use std::sync::OnceLock;

use super::mirror::{library_area, library_booking, library_seat, library_slot, library_venue};
use mapping::*;
use runtime::*;
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

pub async fn login(
    account: String,
    password: String,
    captcha: Option<String>,
    remember: bool,
) -> SessionResponse {
    session::login(account, password, captcha, remember).await
}

pub async fn restore_session() -> SessionResponse {
    session::restore_session().await
}

pub async fn sign_out() -> SessionResponse {
    session::sign_out().await
}

pub async fn set_route(route: RouteChoice) -> SessionResponse {
    session::set_route(route).await
}

pub async fn clear_cache() -> bool {
    session::clear_cache().await
}

pub async fn load_classrooms(scope: LiveScope, query: ClassroomQuery) -> ClassroomResponse {
    classroom::load_classrooms(scope, query).await
}

pub async fn load_schedule(
    term_id: Option<String>,
    week: Option<i32>,
    force_refresh: bool,
) -> ScheduleResponse {
    academic::load_schedule(term_id, week, force_refresh).await
}

pub async fn load_today(force_refresh: bool) -> TodayResponse {
    academic::load_today(force_refresh).await
}

pub async fn load_checkin_today(force_refresh: bool) -> CheckInResponse {
    academic::load_checkin_today(force_refresh).await
}

/// Observe the current read without issuing any school request.
pub async fn checkin_load_progress() -> ReadOnlyResponse {
    checkin::checkin_load_progress().await
}

/// Historical day in Asia/Shanghai, yyyy-MM-dd; no sign-in submission.
pub async fn load_checkin_on_date(date: String, force_refresh: bool) -> CheckInResponse {
    checkin::load_checkin_on_date(date, force_refresh).await
}

pub struct GradeTermsResponse {
    pub terms: Vec<ScheduleTerm>,
    pub failure: Option<FailureCode>,
    pub failure_detail: Option<String>,
}

pub async fn load_grade_terms() -> GradeTermsResponse {
    academic::load_grade_terms().await
}

pub async fn load_grades(term_code: Option<String>, force_refresh: bool) -> GradeResponse {
    academic::load_grades(term_code, force_refresh).await
}

/// Device-acceptance diagnostic: write, read and delete one synthetic secret.
/// It never touches account credentials and returns only a boolean.
pub fn verify_credential_storage(account: String, secret: String) -> bool {
    session::verify_credential_storage(account, secret)
}

pub async fn load_library_venues(force_refresh: bool) -> LibraryVenuesResponse {
    library::load_library_venues(force_refresh).await
}

pub async fn load_library_areas(library_id: String) -> LibraryAreasResponse {
    library::load_library_areas(library_id).await
}

pub async fn load_library_slots(area_id: String) -> LibrarySlotsResponse {
    library::load_library_slots(area_id).await
}

pub async fn load_library_seats(
    area_id: String,
    slot_id: String,
    day: String,
    start: String,
    end: String,
) -> LibrarySeatsResponse {
    library::load_library_seats(area_id, slot_id, day, start, end).await
}

pub async fn load_library_bookings(force_refresh: bool) -> LibraryBookingsResponse {
    library::load_library_bookings(force_refresh).await
}

pub struct LibraryHistoryResponse {
    pub bookings: Vec<super::mirror::LibraryBooking>,
    pub page: i32,
    pub page_size: i32,
    pub total: Option<i32>,
    pub has_next: bool,
    pub fetched_at: Option<String>,
    pub from_cache: bool,
    pub stale: bool,
    pub failure: Option<FailureCode>,
    pub failure_detail: Option<String>,
}

pub async fn load_library_history(page: i32, force_refresh: bool) -> LibraryHistoryResponse {
    library::load_library_history(page, force_refresh).await
}

/// Synthetic page runs the same domain parser as live history.
pub fn load_demo_library_history(page: i32) -> LibraryHistoryResponse {
    library::load_demo_library_history(page)
}

/// Real SPOC list, API.md §7.1. Demo remains an explicit separate command.
pub async fn load_homework(force_refresh: bool) -> super::mirror::HomeworkResponse {
    homework::load_homework(force_refresh).await
}

pub struct HomeworkDetailResponse {
    pub source_url: Option<String>,
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
    homework::load_homework_detail(assignment_id, force_refresh).await
}

/// Sanitized domain JSON, never raw upstream data, credentials or tokens.
pub struct ReadOnlyResponse {
    pub payload: Option<String>,
    pub stale: bool,
    pub failure: Option<FailureCode>,
}
pub async fn load_bykc(force_refresh: bool) -> ReadOnlyResponse {
    bykc::load_bykc(force_refresh).await
}

pub fn load_demo_bykc() -> ReadOnlyResponse {
    bykc::load_demo_bykc()
}

pub async fn load_bykc_chosen(force_refresh: bool) -> ReadOnlyResponse {
    bykc::load_bykc_chosen(force_refresh).await
}

pub async fn load_bykc_statistics(force_refresh: bool) -> ReadOnlyResponse {
    bykc::load_bykc_statistics(force_refresh).await
}

pub fn load_demo_bykc_chosen() -> ReadOnlyResponse {
    bykc::load_demo_bykc_chosen()
}

pub fn load_demo_bykc_statistics() -> ReadOnlyResponse {
    bykc::load_demo_bykc_statistics()
}

/// Independently cached sections, allowing Flutter to render the first response
/// while the remaining academic request is still in flight.
pub async fn load_graduate_part(report: bool, force_refresh: bool) -> ReadOnlyResponse {
    graduate::load_graduate_part(report, force_refresh).await
}

pub fn load_demo_graduate_status() -> ReadOnlyResponse {
    graduate::load_demo_graduate_status()
}

pub fn load_demo_graduate() -> ReadOnlyResponse {
    graduate::load_demo_graduate()
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
    utilities::edit_tasks(root, demo, action, id, title, due, completed)
}

pub async fn load_notices(force_refresh: bool) -> ReadOnlyResponse {
    utilities::load_notices(force_refresh).await
}

pub fn load_demo_notices() -> ReadOnlyResponse {
    utilities::load_demo_notices()
}

pub async fn load_cgyy(
    kind: String,
    site_id: i64,
    date: String,
    force_refresh: bool,
) -> ReadOnlyResponse {
    utilities::load_cgyy(kind, site_id, date, force_refresh).await
}

/// User-confirmed CGYY commands; payload contains no upstream credentials.
pub async fn execute_cgyy(command: String) -> ReadOnlyResponse {
    utilities::execute_cgyy(command).await
}

pub fn load_demo_cgyy(kind: String) -> ReadOnlyResponse {
    utilities::load_demo_cgyy(kind)
}

/// Public OPAC search (read-only, anonymous). Payload is the projected page.
pub async fn load_library_books(query: String, page: i64) -> ReadOnlyResponse {
    utilities::load_library_books(query, page).await
}

/// Public holdings for one bib id; the nested JSON string never crosses the bridge.
pub async fn load_library_holdings(bib_id: String) -> ReadOnlyResponse {
    utilities::load_library_holdings(bib_id).await
}

/// Public counts only. No school identity or library token is serialized.
pub async fn load_library_stats(force_refresh: bool) -> ReadOnlyResponse {
    library::load_library_stats(force_refresh).await
}
pub fn load_demo_library_stats() -> ReadOnlyResponse {
    library::load_demo_library_stats()
}

/// Deliberately independent from login, school routes and account caches.
pub async fn check_android_update(current: String) -> ReadOnlyResponse {
    utilities::check_android_update(current).await
}
/// User-confirmed write. Never retries the mutation and never exposes raw upstream text.
/// The module gate rejects double taps rather than queuing a second write.
pub struct MutationResponse {
    pub state: String,
    pub message: String,
}

pub async fn submit_checkin(course_id: String) -> MutationResponse {
    checkin::submit_checkin(course_id).await
}

pub async fn reserve_library_seat(
    area_id: String,
    seat_id: String,
    slot: crate::api::mirror::LibrarySlot,
) -> MutationResponse {
    library::reserve_library_seat(area_id, seat_id, slot).await
}
pub async fn perform_library_action(booking_id: String, action: String) -> MutationResponse {
    library::perform_library_action(booking_id, action).await
}

#[cfg(test)]
mod lifecycle_tests {
    use super::*;
    use std::{
        future::Future,
        pin::pin,
        task::{Context, Poll, Waker},
    };

    #[test]
    fn sign_out_waits_for_active_bridge_reads() {
        let read = SESSION_ACCESS.try_read().expect("initial read");
        let mut logout = pin!(sign_out());
        let mut context = Context::from_waker(Waker::noop());
        assert!(logout.as_mut().poll(&mut context).is_pending());
        assert!(SESSION_ACCESS.try_read().is_err());
        drop(read);
        let Poll::Ready(response) = logout.as_mut().poll(&mut context) else {
            panic!("logout ready")
        };
        assert!(matches!(response.state, SessionState::SignedOut));
        assert!(SESSION_ACCESS.try_read().is_ok());
    }
}

mod academic;
mod bykc;
mod checkin;
mod classroom;
mod graduate;
mod homework;
mod library;
mod mapping;
mod runtime;
mod session;
mod utilities;
