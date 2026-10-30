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

pub struct CheckinLoadProgressDto {
    pub phase: String,
    pub elapsed_ms: Option<i64>,
}

pub struct CheckinLoadProgressResponse {
    pub data: Option<CheckinLoadProgressDto>,
    pub failure: Option<FailureCode>,
}

/// Observe the current read without issuing any school request.
pub async fn checkin_load_progress() -> CheckinLoadProgressResponse {
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
pub struct BykcSemesterDto {
    pub id: String,
    pub name: String,
    pub start: Option<String>,
    pub end: Option<String>,
}

pub struct BykcCourseDetailsDto {
    pub start: Option<String>,
    pub end: Option<String>,
    pub select_start: Option<String>,
    pub select_end: Option<String>,
    pub cancel_end: Option<String>,
    pub capacity: Option<i64>,
    pub enrolled: Option<i64>,
    pub campuses: Vec<String>,
    pub summary: Option<String>,
    pub selected: Option<bool>,
    pub has_sign_config: Option<bool>,
}

pub struct BykcCourseDto {
    pub id: i64,
    pub name: String,
    pub teacher: Option<String>,
    pub position: Option<String>,
    pub category: Option<String>,
    pub subcategory: Option<String>,
    pub details: Option<BykcCourseDetailsDto>,
}

pub struct BykcCatalogDto {
    pub terms: Vec<BykcSemesterDto>,
    pub courses: Vec<BykcCourseDto>,
    /// Chosen by the shared Beijing semester policy, not by the device clock.
    pub current_term: Option<BykcSemesterDto>,
}

pub struct BykcChosenRecordDto {
    pub id: i64,
    pub course: BykcCourseDto,
    pub selected_at: Option<String>,
    pub checkin: Option<i64>,
    pub passed: Option<i64>,
    pub score: Option<i64>,
}

pub struct BykcChosenCoursesDto {
    pub term: Option<BykcSemesterDto>,
    /// `None` means no valid semester range was available, not zero selections.
    pub courses: Option<Vec<BykcChosenRecordDto>>,
}

pub struct BykcStatisticsEntryDto {
    pub category: String,
    pub subcategory: String,
    pub required: i64,
    pub completed: i64,
}

pub struct BykcStatisticsDto {
    pub valid_course_count: Option<i64>,
    pub entries: Vec<BykcStatisticsEntryDto>,
}

pub struct BykcCatalogResponse {
    pub data: Option<BykcCatalogDto>,
    pub failure: Option<FailureCode>,
}

pub struct BykcChosenResponse {
    pub data: Option<BykcChosenCoursesDto>,
    pub failure: Option<FailureCode>,
}

pub struct BykcStatisticsResponse {
    pub data: Option<BykcStatisticsDto>,
    pub failure: Option<FailureCode>,
}

pub async fn load_bykc(force_refresh: bool) -> BykcCatalogResponse {
    bykc::load_bykc(force_refresh).await
}

pub fn load_demo_bykc() -> BykcCatalogResponse {
    bykc::load_demo_bykc()
}

pub async fn load_bykc_chosen(force_refresh: bool) -> BykcChosenResponse {
    bykc::load_bykc_chosen(force_refresh).await
}

pub async fn load_bykc_statistics(force_refresh: bool) -> BykcStatisticsResponse {
    bykc::load_bykc_statistics(force_refresh).await
}

pub fn load_demo_bykc_chosen() -> BykcChosenResponse {
    bykc::load_demo_bykc_chosen()
}

pub fn load_demo_bykc_statistics() -> BykcStatisticsResponse {
    bykc::load_demo_bykc_statistics()
}

pub struct GraduateRowDto {
    pub title: String,
    pub detail: String,
    /// Explicitly distinguishes a course with an unknown result from metadata.
    pub is_course: bool,
    pub completed: Option<bool>,
    pub credit: Option<f64>,
    pub semester: Option<String>,
}

pub struct GraduateProgressDto {
    pub required: Option<f64>,
    pub earned: Option<f64>,
    pub pending: Option<f64>,
}

pub struct GraduateSectionDto {
    pub title: String,
    pub rows: Vec<GraduateRowDto>,
    pub progress: Option<GraduateProgressDto>,
}

pub struct AcademicDataDto {
    pub sections: Vec<GraduateSectionDto>,
    pub notice: Option<String>,
}

pub struct GraduateResponse {
    pub data: Option<AcademicDataDto>,
    pub failure: Option<FailureCode>,
}

/// Independently cached sections, allowing Flutter to render the first response
/// while the remaining academic request is still in flight.
pub async fn load_graduate_part(report: bool, force_refresh: bool) -> GraduateResponse {
    graduate::load_graduate_part(report, force_refresh).await
}

pub fn load_demo_graduate_status() -> GraduateResponse {
    graduate::load_demo_graduate_status()
}

pub fn load_demo_graduate() -> GraduateResponse {
    graduate::load_demo_graduate()
}

pub struct LocalTaskDto {
    pub id: String,
    pub title: String,
    /// Empty means no deadline; a calendar date stays a date.
    pub due: String,
    pub completed: bool,
    /// Set only for a historical record linked to a school assignment.
    pub source_assignment_id: Option<String>,
}

pub struct LocalTasksResponse {
    pub data: Option<Vec<LocalTaskDto>>,
    pub failure: Option<FailureCode>,
}

/// Local CRUD only. Account identity comes from Rust, never a Dart-supplied identifier.
pub async fn edit_tasks(
    root: String,
    demo: bool,
    action: String,
    id: Option<String>,
    title: Option<String>,
    due: Option<String>,
    completed: Option<bool>,
) -> LocalTasksResponse {
    utilities::edit_tasks(root, demo, action, id, title, due, completed).await
}

pub struct NoticeDto {
    pub title: String,
    pub summary: String,
    pub published_at: String,
    pub url: String,
}

/// A failure may accompany data only when it is a previous successful snapshot.
pub struct NoticesResponse {
    pub data: Option<Vec<NoticeDto>>,
    pub failure: Option<FailureCode>,
}

pub async fn load_notices(force_refresh: bool) -> NoticesResponse {
    utilities::load_notices(force_refresh).await
}

pub struct CampusCardBalanceResponse {
    pub balance_minor: Option<i64>,
    pub fetched_at: Option<String>,
    pub failure: Option<FailureCode>,
    pub failure_detail: Option<String>,
}

/// Explicit, user-triggered campus-card balance read. No disk cache or bank data.
pub async fn load_campus_card_balance() -> CampusCardBalanceResponse {
    utilities::load_campus_card_balance().await
}

/// Synthetic balance for the isolated demo workspace.
pub fn load_demo_campus_card_balance() -> CampusCardBalanceResponse {
    utilities::load_demo_campus_card_balance()
}

pub fn load_demo_notices() -> NoticesResponse {
    utilities::load_demo_notices()
}

/// Public career-calendar events for a school month (YYYY-MM). Read-only.
pub async fn load_career_events(month: String, force_refresh: bool) -> CareerEventsResponse {
    utilities::load_career_events(month, force_refresh).await
}

pub struct CareerEventDto {
    pub id: String,
    pub title: String,
    pub campus: String,
    pub place: String,
    pub begins_at: String,
    pub ends_at: String,
    pub fair_type: String,
    pub status: String,
    pub url: String,
}

pub struct CareerEventsDto {
    pub month: String,
    pub events: Vec<CareerEventDto>,
    pub fetched_at: String,
}

/// A failure may accompany data only when it is a previous successful snapshot.
pub struct CareerEventsResponse {
    pub data: Option<CareerEventsDto>,
    pub failure: Option<FailureCode>,
}

pub struct CampusActivityDto {
    pub id: String,
    pub title: String,
    pub category: String,
    pub published_at: String,
    pub activity_time: String,
    pub place: String,
    pub url: String,
}

pub struct CampusActivitiesDto {
    pub page: i32,
    pub activities: Vec<CampusActivityDto>,
    pub fetched_at: String,
}

/// Published and displayed dates stay separate fields; neither is a deadline.
pub struct CampusActivitiesResponse {
    pub data: Option<CampusActivitiesDto>,
    pub failure: Option<FailureCode>,
}

/// Public campus cultural activities (page 1-based). Read-only.
pub async fn load_campus_activities(page: i32, force_refresh: bool) -> CampusActivitiesResponse {
    utilities::load_campus_activities(page, force_refresh).await
}

pub struct CgyySiteDto {
    pub id: i64,
    pub name: String,
    pub venue: String,
    pub campus: String,
    pub seats: Option<i64>,
    pub open_start: String,
    pub open_end: String,
}

pub struct CgyySlotDto {
    pub time: String,
    pub status: String,
}

pub struct CgyySpaceDto {
    pub name: String,
    pub slots: Vec<CgyySlotDto>,
}

pub struct CgyyDayDto {
    pub site_id: i64,
    pub date: String,
    pub dates: Vec<String>,
    pub spaces: Vec<CgyySpaceDto>,
}

pub struct CgyyOrderDto {
    pub order_status: Option<i64>,
    pub check_status: Option<i64>,
    pub can_cancel: bool,
    pub id: i64,
    pub place: String,
    pub date: String,
    pub time: String,
    pub status: String,
}

pub struct CgyyLockCodeDto {
    pub qr_code: Option<String>,
    pub due_date: Option<String>,
    pub trade_no: Option<String>,
    pub venue_name: Option<String>,
    pub site_name: Option<String>,
    pub space_name: Option<String>,
    pub order_name: Option<String>,
    pub reservation_date: Option<String>,
    pub reservation_date_detail: Option<String>,
    pub reservation_start_date: Option<String>,
    pub reservation_end_date: Option<String>,
}

/// Exactly one shape field is `Some`; the rest stay `None` so Dart can switch
/// on the shape without re-parsing a payload string.
pub struct CgyyLoadResponse {
    pub venues: Option<Vec<CgyySiteDto>>,
    pub day: Option<CgyyDayDto>,
    pub orders: Option<Vec<CgyyOrderDto>>,
    pub order: Option<CgyyOrderDto>,
    pub lock_code: Option<CgyyLockCodeDto>,
    pub failure: Option<FailureCode>,
}

pub struct CgyyBookingChoiceDto {
    pub space_id: i64,
    pub space_name: String,
    pub time_id: i64,
    pub time: String,
}

pub struct CgyyPurposeDto {
    pub id: i64,
    pub name: String,
}

pub struct CgyyBookingOptionsDto {
    pub choices: Vec<CgyyBookingChoiceDto>,
    pub purposes: Vec<CgyyPurposeDto>,
    pub uses_fallback_purposes: bool,
}

pub struct CgyyChallengeDto {
    pub id: String,
    pub background: String,
    pub jigsaw: String,
}

pub struct CgyyReviewDto {
    pub id: String,
    pub orders: Vec<CgyyOrderDto>,
}

pub struct CgyyActionResultDto {
    pub state: String,
    pub message: String,
    pub options: Option<CgyyBookingOptionsDto>,
    pub challenge: Option<CgyyChallengeDto>,
    pub review: Option<CgyyReviewDto>,
}

pub struct CgyyActionResultResponse {
    pub data: Option<CgyyActionResultDto>,
    pub failure: Option<FailureCode>,
}

pub async fn load_cgyy(
    kind: String,
    site_id: i64,
    date: String,
    force_refresh: bool,
) -> CgyyLoadResponse {
    utilities::load_cgyy(kind, site_id, date, force_refresh).await
}

/// User-confirmed CGYY commands; payload contains no upstream credentials.
pub async fn execute_cgyy(command: String) -> CgyyActionResultResponse {
    utilities::execute_cgyy(command).await
}

pub fn load_demo_cgyy(kind: String) -> CgyyLoadResponse {
    utilities::load_demo_cgyy(kind)
}

/// Public OPAC search (read-only, anonymous). Payload is the projected page.
pub struct BookHitDto {
    pub bib_id: String,
    pub title: String,
    pub author: String,
    pub publisher: String,
    pub year: String,
    pub callno: String,
    pub isbn: String,
    /// Reported copy availability, or `None` when the source stays silent.
    pub items_available: Option<i64>,
    pub item_count: Option<i64>,
}

pub struct BookPageDto {
    pub page: i64,
    pub page_size: i64,
    pub total: i64,
    pub actual_total: i64,
    pub items: Vec<BookHitDto>,
    /// True when the school reported more matches than this page returned.
    pub has_more: bool,
}

pub struct BookPageResponse {
    pub data: Option<BookPageDto>,
    pub failure: Option<FailureCode>,
}

pub async fn load_library_books(
    query: String,
    page: i64,
    sort: String,
    descending: bool,
) -> BookPageResponse {
    utilities::load_library_books(query, page, sort, descending).await
}

pub struct ShuttleRunDto {
    pub index: String,
    pub time: String,
    pub capacity: String,
}

pub struct ShuttleSectionDto {
    pub label: String,
    pub left: Vec<ShuttleRunDto>,
    pub right: Vec<ShuttleRunDto>,
}

pub struct ShuttleTableDto {
    pub left: String,
    pub right: String,
    pub sections: Vec<ShuttleSectionDto>,
}

pub struct ShuttleTimetableDto {
    pub tables: Vec<ShuttleTableDto>,
    pub source: String,
    pub live_source: String,
}

pub struct ShuttleTimetableResponse {
    pub data: Option<ShuttleTimetableDto>,
    pub failure: Option<FailureCode>,
}

/// Published shuttle timetable (official page). Read-only, no ticketing.
pub async fn load_shuttle_timetable() -> ShuttleTimetableResponse {
    utilities::load_shuttle_timetable().await
}

pub struct BookHoldingDto {
    pub call_no: String,
    pub bar_code: String,
    pub library: String,
    pub location: String,
    /// The school's own status text; never a local available/unavailable flag.
    pub status: String,
}

pub struct BookHoldingsResponse {
    pub data: Option<Vec<BookHoldingDto>>,
    pub failure: Option<FailureCode>,
}

/// Public holdings for one bib id; the nested JSON string never crosses the bridge.
pub async fn load_library_holdings(bib_id: String) -> BookHoldingsResponse {
    utilities::load_library_holdings(bib_id).await
}

/// Transient archive bytes. Hosts must use explicitly opted-in encrypted storage.
pub struct LearningSnapshotResponse {
    pub bytes: Option<Vec<u8>>,
    pub failure: Option<FailureCode>,
}
pub async fn export_learning_snapshots(expected_account: String) -> LearningSnapshotResponse {
    utilities::export_learning_snapshots(expected_account).await
}
pub async fn import_learning_snapshots(
    expected_account: String,
    bytes: Vec<u8>,
) -> SnapshotImportResponse {
    utilities::import_learning_snapshots(expected_account, bytes).await
}

/// Public website metadata only. Does not initialize an authenticated session.
#[flutter_rust_bridge::frb(sync)]
pub fn library_loans_portal_url() -> String {
    ginkgo_runtime::library_loans_portal_url()
}

/// Public destination metadata; does not initialize an authenticated session.
#[flutter_rust_bridge::frb(sync)]
pub fn student_service_url(id: String) -> Option<String> {
    ginkgo_runtime::student_service_url(&id)
}

/// Explicit private read, scoped to the caller's account. No disk cache or writes.
pub struct LibraryLoanDto {
    pub id: String,
    pub title: Option<String>,
    pub author: Option<String>,
    pub call_number: Option<String>,
    pub borrowed_at: Option<String>,
    pub due_at: Option<String>,
}

pub struct LibraryLoanPageDto {
    pub items: Vec<LibraryLoanDto>,
    pub page: u32,
    pub total: u32,
    pub has_more: bool,
}

pub struct LibraryLoansResponse {
    pub data: Option<LibraryLoanPageDto>,
    pub failure: Option<FailureCode>,
}

pub async fn load_library_loans(expected_account: String, page: u32) -> LibraryLoansResponse {
    utilities::load_library_loans(expected_account, page).await
}

/// Public counts only. No school identity or library token is serialized.
pub struct CountPairDto {
    pub available: i32,
    pub total: i32,
}

pub struct ReadingRoomDto {
    pub name: String,
    pub people: i32,
}

pub struct LibraryCampusStatsDto {
    pub id: String,
    pub name: String,
    pub people: i32,
    pub reading_rooms: Vec<ReadingRoomDto>,
    /// Absent means the school did not publish that resource, not zero.
    pub seats: Option<CountPairDto>,
    pub study_rooms: Option<CountPairDto>,
    pub lockers: Option<CountPairDto>,
}

pub struct LibraryStatsDto {
    pub campuses: Vec<LibraryCampusStatsDto>,
    pub fetched_at: Option<String>,
    pub from_cache: bool,
}

pub struct LibraryStatsResponse {
    pub data: Option<LibraryStatsDto>,
    pub failure: Option<FailureCode>,
}

pub async fn load_library_stats(force_refresh: bool) -> LibraryStatsResponse {
    library::load_library_stats(force_refresh).await
}
pub fn load_demo_library_stats() -> LibraryStatsResponse {
    library::load_demo_library_stats()
}

pub struct AndroidDownloadDto {
    pub version: String,
    pub name: String,
    pub url: String,
    pub api_url: String,
    /// Upstream only ever publishes a verified asset inside
    /// `1..=268_435_456`, so widening to a signed 64-bit count is lossless.
    pub size: i64,
    pub sha256: String,
}

pub struct UpdateSummaryDto {
    pub current: String,
    pub latest: Option<String>,
    pub available: bool,
    pub page_url: Option<String>,
    pub notes: Option<String>,
    pub apk_available: bool,
    pub download: Option<AndroidDownloadDto>,
}

pub struct UpdateResponse {
    pub data: Option<UpdateSummaryDto>,
    pub failure: Option<FailureCode>,
}

/// Deliberately independent from login, school routes and account caches.
pub async fn check_android_update(current: String) -> UpdateResponse {
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

    #[tokio::test]
    async fn sign_out_waits_for_active_bridge_reads() {
        let _serial = runtime::TEST_GATE.lock().await;
        let read = SESSION_ACCESS.read().await;
        let mut logout = Box::pin(sign_out());
        assert!(
            tokio::time::timeout(std::time::Duration::from_millis(50), &mut logout)
                .await
                .is_err(),
            "sign-out must wait for the active read"
        );
        drop(read);
        let response = logout.await;
        assert!(matches!(response.state, SessionState::SignedOut));
        assert!(SESSION_ACCESS.try_read().is_ok());
    }

    #[cfg(any(target_os = "android", target_os = "windows", target_os = "macos"))]
    #[tokio::test(start_paused = true)]
    async fn sign_out_revokes_locally_when_the_gate_times_out() {
        let _serial = runtime::TEST_GATE.lock().await;
        service().expect("supported platform service");
        let before = session::LOCAL_REVOCATIONS.load(std::sync::atomic::Ordering::SeqCst);
        let read = SESSION_ACCESS.read().await;
        let response = sign_out().await;
        assert!(matches!(response.state, SessionState::SignedOut));
        assert_eq!(
            session::LOCAL_REVOCATIONS.load(std::sync::atomic::Ordering::SeqCst),
            before + 1,
            "a gate timeout must not skip local identity and cookie revocation"
        );
        drop(read);
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

pub struct HomeworkAttachmentDto {
    pub id: String,
    pub name: String,
    pub kind: String,
}

pub struct HomeworkWorkspaceDto {
    pub assignment_id: String,
    pub allowed_methods: Vec<String>,
    pub allowed_extensions: Vec<String>,
    pub submission_limit: Option<u32>,
    pub submitted_count: Option<u32>,
    pub returned: bool,
    pub submitted_text: Option<String>,
    pub feedback: Option<String>,
    pub attachments: Vec<HomeworkAttachmentDto>,
    pub can_submit_file: bool,
    pub blocked_reason: Option<String>,
    /// Widened from `u64`; the 20 MB upload cap keeps this lossless.
    pub file_limit_bytes: i64,
}

pub struct HomeworkFileWorkspaceResponse {
    pub data: Option<HomeworkWorkspaceDto>,
    pub failure: Option<FailureCode>,
}

pub struct HomeworkUploadReceiptDto {
    pub handle: String,
    pub file_name: String,
    /// Widened from `u64`; the 20 MB upload cap keeps this lossless.
    pub size: i64,
}

pub struct HomeworkUploadResponse {
    pub data: Option<HomeworkUploadReceiptDto>,
    pub failure: Option<FailureCode>,
}

/// Homework business JSON only; raw SPOC payloads never leave upstream.
pub async fn homework_file_workspace(
    expected_account: String,
    assignment_id: String,
) -> HomeworkFileWorkspaceResponse {
    homework::file_workspace(expected_account, assignment_id).await
}
pub async fn upload_homework_file(
    expected_account: String,
    assignment_id: String,
    name: String,
    bytes: Vec<u8>,
) -> HomeworkUploadResponse {
    homework::upload_file(expected_account, assignment_id, name, bytes).await
}
pub async fn submit_homework_file(
    expected_account: String,
    handle: String,
    confirmed: bool,
) -> MutationResponse {
    homework::submit_file(expected_account, handle, confirmed, false).await
}
pub async fn reconcile_homework_file(expected_account: String, handle: String) -> MutationResponse {
    homework::submit_file(expected_account, handle, false, true).await
}
pub struct HomeworkFileDownloadResponse {
    pub name: Option<String>,
    pub bytes: Option<Vec<u8>>,
    pub failure: Option<FailureCode>,
}
pub async fn download_homework_file(
    expected_account: String,
    assignment_id: String,
    attachment_id: String,
) -> HomeworkFileDownloadResponse {
    homework::download_file(expected_account, assignment_id, attachment_id).await
}

/// Learning queries return business DTO JSON, never school response envelopes.
pub struct LearningCourseDto {
    pub id: String,
    pub name: String,
    pub teacher: Option<String>,
    pub term: Option<String>,
    pub source_url: String,
}

pub struct LearningCoursesResponse {
    pub data: Option<Vec<LearningCourseDto>>,
    pub failure: Option<FailureCode>,
}

pub struct CourseAnnouncementDto {
    pub id: String,
    pub title: String,
    pub published_at: Option<String>,
}

pub struct CourseAnnouncementsResponse {
    pub data: Option<Vec<CourseAnnouncementDto>>,
    pub failure: Option<FailureCode>,
}

pub struct LearningAttachmentDto {
    pub id: String,
    pub name: String,
}

pub struct CourseAnnouncementDetailDto {
    pub id: String,
    pub title: String,
    pub content: Option<String>,
    pub attachments: Vec<LearningAttachmentDto>,
}

pub struct CourseAnnouncementDetailResponse {
    pub data: Option<CourseAnnouncementDetailDto>,
    pub failure: Option<FailureCode>,
}

pub struct CourseResourceDto {
    pub id: String,
    pub name: String,
    pub folder: bool,
    pub downloadable: bool,
    pub updated_at: Option<String>,
    pub extension: Option<String>,
}

pub struct CourseResourcePageDto {
    pub items: Vec<CourseResourceDto>,
    pub page: u32,
    pub has_next: bool,
}

pub struct CourseResourcePageResponse {
    pub data: Option<CourseResourcePageDto>,
    pub failure: Option<FailureCode>,
}

pub struct CourseAssessmentDto {
    pub id: String,
    pub title: String,
    pub starts_at: Option<String>,
    pub due_at: Option<String>,
    pub score: Option<String>,
    pub source_url: String,
}

pub struct CourseAssessmentsResponse {
    pub data: Option<Vec<CourseAssessmentDto>>,
    pub failure: Option<FailureCode>,
}

pub enum LearningColumnKindDto {
    Announcement,
    Assessment,
}

pub struct LearningColumnDto {
    pub id: String,
    pub name: String,
    pub kind: LearningColumnKindDto,
}

pub struct LearningColumnsResponse {
    pub data: Option<Vec<LearningColumnDto>>,
    pub failure: Option<FailureCode>,
}

pub enum LearningCapabilityStateDto {
    Unknown,
    Available,
    AuthRequired,
    TemporarilyUnavailable,
    ProtocolChanged,
    AccessDenied,
}

pub struct LearningCapabilitiesDto {
    pub columns: LearningCapabilityStateDto,
    pub announcements: LearningCapabilityStateDto,
    pub resources: LearningCapabilityStateDto,
    pub assessments: LearningCapabilityStateDto,
    pub resource_download: LearningCapabilityStateDto,
    pub announcement_download: LearningCapabilityStateDto,
}

pub struct LearningCapabilitiesResponse {
    pub data: Option<LearningCapabilitiesDto>,
    pub failure: Option<FailureCode>,
}

pub struct SnapshotImportResponse {
    /// Count of snapshots actually merged, not the number offered.
    pub imported: Option<u32>,
    pub failure: Option<FailureCode>,
}

pub async fn learning_courses(expected_account: String, force: bool) -> LearningCoursesResponse {
    learning::courses(expected_account, force).await
}
pub async fn course_announcements(
    expected_account: String,
    course: String,
    force: bool,
) -> CourseAnnouncementsResponse {
    learning::announcements(expected_account, course, force).await
}
pub async fn course_announcement_detail(
    expected_account: String,
    course: String,
    id: String,
) -> CourseAnnouncementDetailResponse {
    learning::announcement_detail(expected_account, course, id).await
}
pub async fn course_resources(
    expected_account: String,
    course: String,
    folder: Option<String>,
    page: u32,
    force: bool,
) -> CourseResourcePageResponse {
    learning::resources(expected_account, course, folder, page, force).await
}
pub async fn course_assessments(
    expected_account: String,
    course: String,
    force: bool,
) -> CourseAssessmentsResponse {
    learning::assessments(expected_account, course, force).await
}
pub async fn course_resource_download(
    expected_account: String,
    course: String,
    folder: Option<String>,
    page: u32,
    id: String,
) -> HomeworkFileDownloadResponse {
    learning::resource_download(expected_account, course, folder, page, id).await
}
pub async fn course_announcement_attachment(
    expected_account: String,
    course: String,
    id: String,
    file: String,
) -> HomeworkFileDownloadResponse {
    learning::announcement_attachment(expected_account, course, id, file).await
}
pub mod auth_challenge;
mod learning;
pub use auth_challenge::{load_login_challenge, LoginChallengeResponse};

/// Explicit module context; all identifiers are revalidated by the source.
pub async fn course_learning_columns(
    expected_account: String,
    course: String,
    force: bool,
) -> LearningColumnsResponse {
    learning::columns(expected_account, course, force).await
}
pub async fn course_learning_capabilities(
    expected_account: String,
    course: String,
) -> LearningCapabilitiesResponse {
    learning::capabilities(expected_account, course).await
}
pub async fn course_announcements_in(
    expected_account: String,
    course: String,
    column: String,
    force: bool,
) -> CourseAnnouncementsResponse {
    learning::announcements_in(expected_account, course, column, force).await
}
pub async fn course_assessments_in(
    expected_account: String,
    course: String,
    column: String,
    force: bool,
) -> CourseAssessmentsResponse {
    learning::assessments_in(expected_account, course, column, force).await
}
pub async fn course_announcement_detail_in(
    expected_account: String,
    course: String,
    column: String,
    id: String,
) -> CourseAnnouncementDetailResponse {
    learning::detail_in(expected_account, course, column, id).await
}
pub async fn course_announcement_attachment_in(
    expected_account: String,
    course: String,
    column: String,
    id: String,
    file: String,
) -> HomeworkFileDownloadResponse {
    learning::attachment_in(expected_account, course, column, id, file).await
}
pub async fn course_resources_at(
    expected_account: String,
    course: String,
    path: Vec<String>,
    page: u32,
    force: bool,
) -> CourseResourcePageResponse {
    learning::resources_at(expected_account, course, path, page, force).await
}
pub async fn course_resource_download_at(
    expected_account: String,
    course: String,
    path: Vec<String>,
    page: u32,
    id: String,
) -> HomeworkFileDownloadResponse {
    learning::download_at(expected_account, course, path, page, id).await
}
pub enum GraduateCreditStateDto {
    Unknown,
    NoMinimum,
    Incomplete,
    RequirementMet,
}

pub struct GraduateCreditMetricsDto {
    pub state: GraduateCreditStateDto,
    pub required: Option<f64>,
    pub earned: Option<f64>,
    pub pending: Option<f64>,
    /// Derived only from this node's official requirement and earned credits.
    pub remaining: Option<f64>,
    pub ratio: Option<f64>,
}

pub struct GraduateCreditRowDto {
    pub title: String,
    pub detail: String,
    pub is_course: bool,
    pub completed: Option<bool>,
    pub credit: Option<f64>,
    pub semester: Option<String>,
}

pub struct GraduateCreditNodeDto {
    /// Source ordinal, not an inferred category/group relationship.
    pub source_index: u32,
    pub title: String,
    pub progress: Option<GraduateCreditMetricsDto>,
    pub rows: Vec<GraduateCreditRowDto>,
}

pub struct GraduateCreditMapDto {
    pub summary: Option<GraduateCreditNodeDto>,
    pub nodes: Vec<GraduateCreditNodeDto>,
    pub notice: Option<String>,
}

pub struct GraduateCreditMapResponse {
    pub data: Option<GraduateCreditMapDto>,
    pub failure: Option<FailureCode>,
}

pub async fn load_graduate_credit_map(
    expected_account: String,
    force_refresh: bool,
) -> GraduateCreditMapResponse {
    graduate::credit_map(expected_account, force_refresh).await
}
pub struct HomeworkPendingSubmissionDto {
    pub handle: String,
    pub assignment_id: String,
    pub file_name: String,
    /// Widened from `u64`; the 20 MB upload cap keeps this lossless.
    pub size: i64,
}

pub struct HomeworkPendingResponse {
    pub data: Option<Vec<HomeworkPendingSubmissionDto>>,
    pub failure: Option<FailureCode>,
}

pub enum HomeworkCapabilityStateDto {
    Available,
    Unknown,
    Unsupported,
    ProtocolChanged,
    TempUnavailable,
    AuthRequired,
}

pub struct HomeworkCapabilityEvidenceDto {
    pub capability: String,
    pub state: HomeworkCapabilityStateDto,
    pub reason: String,
    pub evidence: String,
}

pub struct HomeworkCapabilitiesResponse {
    pub data: Option<Vec<HomeworkCapabilityEvidenceDto>>,
    pub failure: Option<FailureCode>,
}

pub struct HomeworkRecoveryResponse {
    /// `Some(true)` only after the store accepted the private directory.
    pub configured: Option<bool>,
    pub failure: Option<FailureCode>,
}

pub async fn configure_homework_recovery(
    expected_account: String,
    storage_root: String,
) -> HomeworkRecoveryResponse {
    homework::configure_recovery(expected_account, storage_root).await
}
pub async fn pending_homework_submissions(
    expected_account: String,
    assignment_id: Option<String>,
) -> HomeworkPendingResponse {
    homework::pending_submissions(expected_account, assignment_id).await
}
pub async fn homework_capabilities(
    expected_account: String,
    assignment_id: String,
) -> HomeworkCapabilitiesResponse {
    homework::capabilities(expected_account, assignment_id).await
}
