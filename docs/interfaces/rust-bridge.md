# 桥接（ginkgo_flutter_bridge）

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
FFI DTO 与粗粒度命令；Dart 唯一可见的 Rust 面。

## 目录

- [academic](#academic) (5)
- [auth_challenge](#authchallenge) (2)
- [bykc](#bykc) (6)
- [checkin](#checkin) (3)
- [classroom](#classroom) (1)
- [graduate](#graduate) (4)
- [homework](#homework) (9)
- [learning](#learning) (15)
- [library](#library) (11)
- [mapping](#mapping) (15)
- [runtime](#runtime) (17)
- [session](#session) (6)
- [utilities](#utilities) (17)
- [live](#live) (190)
- [academic](#academic) (6)
- [classroom](#classroom) (3)
- [library](#library) (1)
- [mirror](#mirror) (53)
- [reminder_planning](#reminderplanning) (8)
- [rules](#rules) (3)

## academic

- `pub(super) async fn load_schedule( term_id: Option<String>, week: Option<i32>, force_refresh: bool, ) -> ScheduleResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/academic.rs:4</sub>
- `pub(super) async fn load_today(force_refresh: bool) -> TodayResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/academic.rs:23</sub>
- `pub(super) async fn load_checkin_today(force_refresh: bool) -> CheckInResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/academic.rs:48</sub>
- `pub(super) async fn load_grade_terms() -> GradeTermsResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/academic.rs:62</sub>
- `pub(super) async fn load_grades(term_code: Option<String>, force_refresh: bool) -> GradeResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/academic.rs:98</sub>

## auth_challenge

- `pub struct LoginChallengeResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live/auth_challenge.rs:4</sub>
    - `challenge_id: Option<String>`  <sub>:5</sub>
    - `challenge_type: Option<String>`  <sub>:6</sub>
    - `text_supported: bool`  <sub>:7</sub>
    - `image: Vec<u8>`  <sub>:8</sub>
    - `failure: Option<FailureCode>`  <sub>:9</sub>
- `pub async fn load_login_challenge( expected_id: Option<String>, refresh: bool, ) -> LoginChallengeResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/auth_challenge.rs:12</sub>

## bykc

- `pub(super) async fn load_bykc(force_refresh: bool) -> BykcCatalogResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/bykc.rs:4</sub>
- `pub(super) fn load_demo_bykc() -> BykcCatalogResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/bykc.rs:18</sub>
- `pub(super) async fn load_bykc_chosen(force_refresh: bool) -> BykcChosenResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/bykc.rs:26</sub>
- `pub(super) async fn load_bykc_statistics(force_refresh: bool) -> BykcStatisticsResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/bykc.rs:34</sub>
- `pub(super) fn load_demo_bykc_chosen() -> BykcChosenResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/bykc.rs:42</sub>
- `pub(super) fn load_demo_bykc_statistics() -> BykcStatisticsResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/bykc.rs:46</sub>

## checkin

- `pub(super) async fn checkin_load_progress() -> CheckinLoadProgressResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/checkin.rs:4</sub>
- `pub(super) async fn load_checkin_on_date(date: String, force_refresh: bool) -> CheckInResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/checkin.rs:30</sub>
- `pub(super) async fn submit_checkin(course_id: String) -> MutationResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/checkin.rs:46</sub>

## classroom

- `pub(super) async fn load_classrooms(scope: LiveScope, query: ClassroomQuery) -> ClassroomResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/classroom.rs:4</sub>

## graduate

- `pub(super) async fn load_graduate_part(report: bool, force_refresh: bool) -> GraduateResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/graduate.rs:4</sub>
- `pub(super) fn load_demo_graduate_status() -> GraduateResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/graduate.rs:25</sub>
- `pub(super) fn load_demo_graduate() -> GraduateResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/graduate.rs:36</sub>
- `pub(super) async fn credit_map(expected: String, force: bool) -> GraduateCreditMapResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/graduate.rs:89</sub>

## homework

- `pub(super) async fn load_homework(force_refresh: bool) -> crate::api::mirror::HomeworkResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/homework.rs:4</sub>
- `pub(super) async fn load_homework_detail( assignment_id: String, force_refresh: bool, ) -> HomeworkDetailResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/homework.rs:59</sub>
- `pub(super) async fn file_workspace(expected: String, id: String) -> HomeworkFileWorkspaceResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/homework.rs:169</sub>
- `pub(super) async fn upload_file( expected: String, id: String, name: String, bytes: Vec<u8>, ) -> HomeworkUploadResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/homework.rs:188</sub>
- `pub(super) async fn submit_file( expected: String, handle: String, confirmed: bool, reconcile: bool, ) -> MutationResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/homework.rs:224</sub>
- `pub(super) async fn download_file( expected: String, id: String, attachment: String, ) -> HomeworkFileDownloadResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/homework.rs:255</sub>
- `pub(super) async fn configure_recovery(expected: String, root: String) -> HomeworkRecoveryResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/homework.rs:279</sub>
- `pub(super) async fn pending_submissions( expected: String, assignment: Option<String>, ) -> HomeworkPendingResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/homework.rs:293</sub>
- `pub(super) async fn capabilities(expected: String, id: String) -> HomeworkCapabilitiesResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/homework.rs:323</sub>

## learning

- `pub(super) async fn courses(expected: String, force: bool) -> LearningCoursesResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/learning.rs:28</sub>
- `pub(super) async fn announcements( expected: String, course: String, force: bool, ) -> CourseAnnouncementsResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/learning.rs:49</sub>
- `pub(super) async fn resources( expected: String, course: String, folder: Option<String>, page: u32, force: bool, ) -> CourseResourcePageResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/learning.rs:74</sub>
- `pub(super) async fn assessments( expected: String, course: String, force: bool, ) -> CourseAssessmentsResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/learning.rs:104</sub>
- `pub(super) async fn announcement_detail( expected: String, course: String, id: String, ) -> CourseAnnouncementDetailResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/learning.rs:130</sub>
- `pub(super) async fn resource_download( expected: String, course: String, folder: Option<String>, page: u32, id: String, ) -> HomeworkFileDownloadResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/learning.rs:170</sub>
- `pub(super) async fn announcement_attachment( expected: String, course: String, id: String, file: String, ) -> HomeworkFileDownloadResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/learning.rs:187</sub>
- `pub(super) async fn columns( expected: String, course: String, force: bool, ) -> LearningColumnsResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/learning.rs:203</sub>
- `pub(super) async fn capabilities(expected: String, course: String) -> LearningCapabilitiesResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/learning.rs:237</sub>
- `pub(super) async fn announcements_in( expected: String, course: String, column: String, force: bool, ) -> CourseAnnouncementsResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/learning.rs:256</sub>
- `pub(super) async fn assessments_in( expected: String, course: String, column: String, force: bool, ) -> CourseAssessmentsResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/learning.rs:284</sub>
- `pub(super) async fn detail_in( expected: String, course: String, column: String, id: String, ) -> CourseAnnouncementDetailResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/learning.rs:315</sub>
- `pub(super) async fn attachment_in( expected: String, course: String, column: String, id: String, file: String, ) -> HomeworkFileDownloadResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/learning.rs:339</sub>
- `pub(super) async fn resources_at( expected: String, course: String, path: Vec<String>, page: u32, force: bool, ) -> CourseResourcePageResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/learning.rs:356</sub>
- `pub(super) async fn download_at( expected: String, course: String, path: Vec<String>, page: u32, id: String, ) -> HomeworkFileDownloadResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/learning.rs:377</sub>

## library

- `pub(super) async fn load_library_venues(force_refresh: bool) -> LibraryVenuesResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/library.rs:4</sub>
- `pub(super) async fn load_library_areas(library_id: String) -> LibraryAreasResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/library.rs:46</sub>
- `pub(super) async fn load_library_slots(area_id: String) -> LibrarySlotsResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/library.rs:73</sub>
- `pub(super) async fn load_library_seats( area_id: String, slot_id: String, day: String, start: String, end: String, ) -> LibrarySeatsResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/library.rs:100</sub>
- `pub(super) async fn load_library_bookings(force_refresh: bool) -> LibraryBookingsResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/library.rs:133</sub>
- `pub(super) async fn load_library_history(page: i32, force_refresh: bool) -> LibraryHistoryResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/library.rs:176</sub>
- `pub(super) fn load_demo_library_history(page: i32) -> LibraryHistoryResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/library.rs:227</sub>
- `pub(super) async fn load_library_stats(force_refresh: bool) -> LibraryStatsResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/library.rs:257</sub>
- `pub(super) fn load_demo_library_stats() -> LibraryStatsResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/library.rs:307</sub>
- `pub(super) async fn reserve_library_seat( area_id: String, seat_id: String, slot: crate::api::mirror::LibrarySlot, ) -> MutationResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/library.rs:324</sub>
- `pub(super) async fn perform_library_action(booking_id: String, action: String) -> MutationResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/library.rs:362</sub>

## mapping

- `pub(super) fn mutation_response( outcome: ginkgo_core::features::mutation::MutationOutcome, ) -> MutationResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/mapping.rs:4</sub>
- `pub(super) fn grade_response(outcome: GradeOutcome) -> GradeResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/mapping.rs:20</sub>
- `pub(super) fn grade_failure(failure: FailureCode, detail: Option<String>) -> GradeResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/mapping.rs:54</sub>
- `pub(super) fn checkin_response(outcome: CheckInOutcome) -> CheckInResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/mapping.rs:70</sub>
- `pub(super) fn checkin_failure(failure: FailureCode, detail: Option<String>) -> CheckInResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/mapping.rs:114</sub>
- `pub(super) fn today_response(outcome: TodayOutcome) -> TodayResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/mapping.rs:126</sub>
- `pub(super) fn schedule_response(outcome: ScheduleOutcome) -> ScheduleResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/mapping.rs:150</sub>
- `pub(super) fn schedule_failure(failure: FailureCode, detail: Option<String>) -> ScheduleResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/mapping.rs:222</sub>
- `pub(super) fn classroom_response(outcome: ClassroomOutcome) -> ClassroomResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/mapping.rs:236</sub>
- `pub(super) fn classroom_sort(sort: ClassroomSort) -> classroom_domain::Sort {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/mapping.rs:276</sub>
- `pub(super) fn outcome_response( service: &LiveService, outcome: SessionOutcome, remembered: bool, ) -> SessionResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/mapping.rs:284</sub>
- `pub(super) fn status_response(status: SessionStatus) -> SessionResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/mapping.rs:306</sub>
- `pub(super) fn failure_response(error: AppError) -> SessionResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/mapping.rs:324</sub>
- `pub(super) fn signed_out() -> SessionResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/mapping.rs:333</sub>
- `pub(super) fn failure(error: &AppError) -> (Option<FailureCode>, Option<String>) {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/mapping.rs:347</sub>

## runtime

- `pub(super) type LiveService = ginkgo_runtime::AppService;`
  <sub>type · rust/crates/ginkgo_flutter_bridge/src/api/live/runtime.rs:4</sub>
- `pub(super) static SESSION_ACCESS: tokio::sync::RwLock<()> = tokio::sync::RwLock::const_new(());`
  <sub>static · rust/crates/ginkgo_flutter_bridge/src/api/live/runtime.rs:8</sub>
- `pub(super) static CHECKIN_ACCESS: tokio::sync::RwLock<()> = tokio::sync::RwLock::const_new(());`
  <sub>static · rust/crates/ginkgo_flutter_bridge/src/api/live/runtime.rs:13</sub>
- `pub(super) static LIBRARY_ACCESS: tokio::sync::RwLock<()> = tokio::sync::RwLock::const_new(());`
  <sub>static · rust/crates/ginkgo_flutter_bridge/src/api/live/runtime.rs:14</sub>
- `pub(super) static CGYY_ACCESS: tokio::sync::RwLock<()> = tokio::sync::RwLock::const_new(());`
  <sub>static · rust/crates/ginkgo_flutter_bridge/src/api/live/runtime.rs:15</sub>
- `pub(super) static SERVICE: OnceLock<LiveService> = OnceLock::new();`
  <sub>static · rust/crates/ginkgo_flutter_bridge/src/api/live/runtime.rs:17</sub>
- `pub(super) enum ModuleAccess` — The business module a command belongs to.
  <sub>enum · rust/crates/ginkgo_flutter_bridge/src/api/live/runtime.rs:31</sub>
- `pub(super) async fn bounded_read<T>( future: impl std::future::Future<Output = Result<T, AppError>>, ) -> Result<T, AppError> {…}` — Total budget for a read including SSO redirects and fallback. Mutations
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/runtime.rs:86</sub>
- `pub(super) async fn bounded_session<T>( future: impl std::future::Future<Output = Result<T, AppError>>, ) -> Result<T, AppError> {…}` — Budget for session commands (sign-in/restore). The CAS chain alone can
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/runtime.rs:99</sub>
- `pub(super) async fn bounded_submit<T>(future: impl std::future::Future<Output = T>) -> Option<T> {…}` — Budget for a school write. A timed-out write is dropped, never retried:
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/runtime.rs:111</sub>
- `pub(super) async fn with_session_read<T, F, Fut>(body: F) -> Result<T, AppError> where` — Take the session read gate and run a read under the read budget.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/runtime.rs:122</sub>
- `pub(super) async fn with_session_read_in<T, F, Fut>( budget: std::time::Duration, body: F, ) -> Result<T, AppError>` — Same as [`with_session_read`] with an explicit work budget. A file upload
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/runtime.rs:133</sub>
- `pub(super) async fn with_session_write<T, F, Fut>(body: F) -> Result<T, AppError> where` — Take the session write gate and run a session command under the session
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/runtime.rs:150</sub>
- `pub(super) async fn with_session_submit<T, F, Fut>(body: F) -> Option<T> where` — Take the session read gate and run a submitted write under the submit
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/runtime.rs:162</sub>
- `pub(super) async fn with_module_read<T, F, Fut>( module: ModuleAccess, body: F, ) -> Result<T, AppError>` — Take the session read gate and a module read gate, then run a read.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/runtime.rs:172</sub>
- `pub(super) async fn with_module_submit<T, F, Fut>(module: ModuleAccess, body: F) -> Option<T> where` — Take the session read gate and a module write gate, then run a submitted
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/runtime.rs:190</sub>
- `pub(super) fn service() -> Result<&'static LiveService, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/runtime.rs:203</sub>

## session

- `pub(super) async fn login( account: String, password: String, captcha: Option<String>, remember: bool, ) -> SessionResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/session.rs:8</sub>
- `pub(super) async fn restore_session() -> SessionResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/session.rs:35</sub>
- `pub(super) async fn sign_out() -> SessionResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/session.rs:72</sub>
- `pub(super) async fn set_route(route: RouteChoice) -> SessionResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/session.rs:98</sub>
- `pub(super) async fn clear_cache() -> bool {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/session.rs:119</sub>
- `pub(super) fn verify_credential_storage(account: String, secret: String) -> bool {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/session.rs:132</sub>

## utilities

- `pub(super) async fn edit_tasks( root: String, demo: bool, action: String, id: Option<String>, title: Option<String>, due: Option<String>, completed: Option<bool>, ) -> LocalTasksResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:4</sub>
- `pub(super) async fn load_notices(force_refresh: bool) -> NoticesResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:81</sub>
- `pub(super) fn load_demo_notices() -> NoticesResponse {…}` — The demo campus data is the same typed value the native adapter produces,
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:115</sub>
- `pub(super) async fn load_career_events(month: String, force_refresh: bool) -> CareerEventsResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:128</sub>
- `pub(super) async fn load_campus_activities( page: i32, force_refresh: bool, ) -> CampusActivitiesResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:178</sub>
- `pub(super) async fn load_campus_card_balance() -> CampusCardBalanceResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:231</sub>
- `pub(super) fn load_demo_campus_card_balance() -> CampusCardBalanceResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:255</sub>
- `pub(super) async fn load_cgyy( kind: String, site_id: i64, date: String, force_refresh: bool, ) -> CgyyLoadResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:418</sub>
- `pub(super) async fn execute_cgyy(command: String) -> CgyyActionResultResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:455</sub>
- `pub(super) fn load_demo_cgyy(kind: String) -> CgyyLoadResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:488</sub>
- `pub(super) async fn load_library_books( query: String, page: i64, sort: String, descending: bool, ) -> BookPageResponse {…}` — Public OPAC search. Read-only, anonymous and bounded by the service.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:494</sub>
- `pub(super) async fn load_shuttle_timetable() -> ShuttleTimetableResponse {…}` — Published shuttle timetable. Public page, no identity, no ticketing.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:546</sub>
- `pub(super) async fn load_library_holdings(bib_id: String) -> BookHoldingsResponse {…}` — Public holdings for one bib id. The nested JSON string is decoded in Rust.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:598</sub>
- `pub(super) async fn export_learning_snapshots(expected: String) -> LearningSnapshotResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:631</sub>
- `pub(super) async fn import_learning_snapshots( expected: String, bytes: Vec<u8>, ) -> SnapshotImportResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:651</sub>
- `pub(super) async fn load_library_loans(expected: String, page: u32) -> LibraryLoansResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:676</sub>
- `pub(super) async fn check_android_update(current: String) -> UpdateResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:719</sub>

## live

- `pub enum RouteChoice`
  <sub>enum · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:26</sub>
- `pub enum SessionState`
  <sub>enum · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:33</sub>
- `pub struct SessionResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:39</sub>
    - `state: SessionState`  <sub>:40</sub>
    - `account: Option<String>`  <sub>:41</sub>
    - `name: Option<String>`  <sub>:42</sub>
    - `captcha_id: Option<String>`  <sub>:43</sub>
    - `captcha_image_url: Option<String>`  <sub>:44</sub>
    - `remembered: bool`  <sub>:45</sub>
    - `route: Option<RouteChoice>`  <sub>:46</sub>
    - `failure: Option<FailureCode>`  <sub>:47</sub>
    - `failure_detail: Option<String>`  <sub>:48</sub>
- `pub struct LiveScope`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:51</sub>
    - `campus: i32`  <sub>:52</sub>
    - `date: String`  <sub>:53</sub>
    - `force_refresh: bool`  <sub>:54</sub>
- `pub async fn login( account: String, password: String, captcha: Option<String>, remember: bool, ) -> SessionResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:57</sub>
- `pub async fn restore_session() -> SessionResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:66</sub>
- `pub async fn sign_out() -> SessionResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:70</sub>
- `pub async fn set_route(route: RouteChoice) -> SessionResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:74</sub>
- `pub async fn clear_cache() -> bool {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:78</sub>
- `pub async fn load_classrooms(scope: LiveScope, query: ClassroomQuery) -> ClassroomResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:82</sub>
- `pub async fn load_schedule( term_id: Option<String>, week: Option<i32>, force_refresh: bool, ) -> ScheduleResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:86</sub>
- `pub async fn load_today(force_refresh: bool) -> TodayResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:94</sub>
- `pub async fn load_checkin_today(force_refresh: bool) -> CheckInResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:98</sub>
- `pub struct CheckinLoadProgressDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:102</sub>
    - `phase: String`  <sub>:103</sub>
    - `elapsed_ms: Option<i64>`  <sub>:104</sub>
- `pub struct CheckinLoadProgressResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:107</sub>
    - `data: Option<CheckinLoadProgressDto>`  <sub>:108</sub>
    - `failure: Option<FailureCode>`  <sub>:109</sub>
- `pub async fn checkin_load_progress() -> CheckinLoadProgressResponse {…}` — Observe the current read without issuing any school request.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:113</sub>
- `pub async fn load_checkin_on_date(date: String, force_refresh: bool) -> CheckInResponse {…}` — Historical day in Asia/Shanghai, yyyy-MM-dd; no sign-in submission.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:118</sub>
- `pub struct GradeTermsResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:122</sub>
    - `terms: Vec<ScheduleTerm>`  <sub>:123</sub>
    - `failure: Option<FailureCode>`  <sub>:124</sub>
    - `failure_detail: Option<String>`  <sub>:125</sub>
- `pub async fn load_grade_terms() -> GradeTermsResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:128</sub>
- `pub async fn load_grades(term_code: Option<String>, force_refresh: bool) -> GradeResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:132</sub>
- `pub fn verify_credential_storage(account: String, secret: String) -> bool {…}` — Device-acceptance diagnostic: write, read and delete one synthetic secret.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:138</sub>
- `pub async fn load_library_venues(force_refresh: bool) -> LibraryVenuesResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:142</sub>
- `pub async fn load_library_areas(library_id: String) -> LibraryAreasResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:146</sub>
- `pub async fn load_library_slots(area_id: String) -> LibrarySlotsResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:150</sub>
- `pub async fn load_library_seats( area_id: String, slot_id: String, day: String, start: String, end: String, ) -> LibrarySeatsResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:154</sub>
- `pub async fn load_library_bookings(force_refresh: bool) -> LibraryBookingsResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:164</sub>
- `pub struct LibraryHistoryResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:168</sub>
    - `bookings: Vec<super::mirror::LibraryBooking>`  <sub>:169</sub>
    - `page: i32`  <sub>:170</sub>
    - `page_size: i32`  <sub>:171</sub>
    - `total: Option<i32>`  <sub>:172</sub>
    - `has_next: bool`  <sub>:173</sub>
    - `fetched_at: Option<String>`  <sub>:174</sub>
    - `from_cache: bool`  <sub>:175</sub>
    - `stale: bool`  <sub>:176</sub>
    - `failure: Option<FailureCode>`  <sub>:177</sub>
    - `failure_detail: Option<String>`  <sub>:178</sub>
- `pub async fn load_library_history(page: i32, force_refresh: bool) -> LibraryHistoryResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:181</sub>
- `pub fn load_demo_library_history(page: i32) -> LibraryHistoryResponse {…}` — Synthetic page runs the same domain parser as live history.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:186</sub>
- `pub async fn load_homework(force_refresh: bool) -> super::mirror::HomeworkResponse {…}` — Real SPOC list, API.md §7.1. Demo remains an explicit separate command.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:191</sub>
- `pub struct HomeworkDetailResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:195</sub>
    - `source_url: Option<String>`  <sub>:196</sub>
    - `content: Option<String>`  <sub>:197</sub>
    - `published_at: Option<String>`  <sub>:198</sub>
    - `due_at: Option<String>`  <sub>:199</sub>
    - `score: Option<String>`  <sub>:200</sub>
    - `status: String`  <sub>:201</sub>
    - `submitted_at: Option<String>`  <sub>:202</sub>
    - `stale: bool`  <sub>:203</sub>
    - `failure: Option<FailureCode>`  <sub>:204</sub>
- `pub async fn load_homework_detail( assignment_id: String, force_refresh: bool, ) -> HomeworkDetailResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:207</sub>
- `pub struct BykcSemesterDto` — Sanitized domain JSON, never raw upstream data, credentials or tokens.
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:215</sub>
    - `id: String`  <sub>:216</sub>
    - `name: String`  <sub>:217</sub>
    - `start: Option<String>`  <sub>:218</sub>
    - `end: Option<String>`  <sub>:219</sub>
- `pub struct BykcCourseDetailsDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:222</sub>
    - `start: Option<String>`  <sub>:223</sub>
    - `end: Option<String>`  <sub>:224</sub>
    - `select_start: Option<String>`  <sub>:225</sub>
    - `select_end: Option<String>`  <sub>:226</sub>
    - `cancel_end: Option<String>`  <sub>:227</sub>
    - `capacity: Option<i64>`  <sub>:228</sub>
    - `enrolled: Option<i64>`  <sub>:229</sub>
    - `campuses: Vec<String>`  <sub>:230</sub>
    - `summary: Option<String>`  <sub>:231</sub>
    - `selected: Option<bool>`  <sub>:232</sub>
    - `has_sign_config: Option<bool>`  <sub>:233</sub>
- `pub struct BykcCourseDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:236</sub>
    - `id: i64`  <sub>:237</sub>
    - `name: String`  <sub>:238</sub>
    - `teacher: Option<String>`  <sub>:239</sub>
    - `position: Option<String>`  <sub>:240</sub>
    - `category: Option<String>`  <sub>:241</sub>
    - `subcategory: Option<String>`  <sub>:242</sub>
    - `details: Option<BykcCourseDetailsDto>`  <sub>:243</sub>
- `pub struct BykcCatalogDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:246</sub>
    - `terms: Vec<BykcSemesterDto>`  <sub>:247</sub>
    - `courses: Vec<BykcCourseDto>`  <sub>:248</sub>
    - `current_term: Option<BykcSemesterDto>` — Chosen by the shared Beijing semester policy, not by the device clock.  <sub>:250</sub>
- `pub struct BykcChosenRecordDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:253</sub>
    - `id: i64`  <sub>:254</sub>
    - `course: BykcCourseDto`  <sub>:255</sub>
    - `selected_at: Option<String>`  <sub>:256</sub>
    - `checkin: Option<i64>`  <sub>:257</sub>
    - `passed: Option<i64>`  <sub>:258</sub>
    - `score: Option<i64>`  <sub>:259</sub>
- `pub struct BykcChosenCoursesDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:262</sub>
    - `term: Option<BykcSemesterDto>`  <sub>:263</sub>
    - `courses: Option<Vec<BykcChosenRecordDto>>` — `None` means no valid semester range was available, not zero selections.  <sub>:265</sub>
- `pub struct BykcStatisticsEntryDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:268</sub>
    - `category: String`  <sub>:269</sub>
    - `subcategory: String`  <sub>:270</sub>
    - `required: i64`  <sub>:271</sub>
    - `completed: i64`  <sub>:272</sub>
- `pub struct BykcStatisticsDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:275</sub>
    - `valid_course_count: Option<i64>`  <sub>:276</sub>
    - `entries: Vec<BykcStatisticsEntryDto>`  <sub>:277</sub>
- `pub struct BykcCatalogResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:280</sub>
    - `data: Option<BykcCatalogDto>`  <sub>:281</sub>
    - `failure: Option<FailureCode>`  <sub>:282</sub>
- `pub struct BykcChosenResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:285</sub>
    - `data: Option<BykcChosenCoursesDto>`  <sub>:286</sub>
    - `failure: Option<FailureCode>`  <sub>:287</sub>
- `pub struct BykcStatisticsResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:290</sub>
    - `data: Option<BykcStatisticsDto>`  <sub>:291</sub>
    - `failure: Option<FailureCode>`  <sub>:292</sub>
- `pub async fn load_bykc(force_refresh: bool) -> BykcCatalogResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:295</sub>
- `pub fn load_demo_bykc() -> BykcCatalogResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:299</sub>
- `pub async fn load_bykc_chosen(force_refresh: bool) -> BykcChosenResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:303</sub>
- `pub async fn load_bykc_statistics(force_refresh: bool) -> BykcStatisticsResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:307</sub>
- `pub fn load_demo_bykc_chosen() -> BykcChosenResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:311</sub>
- `pub fn load_demo_bykc_statistics() -> BykcStatisticsResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:315</sub>
- `pub struct GraduateRowDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:319</sub>
    - `title: String`  <sub>:320</sub>
    - `detail: String`  <sub>:321</sub>
    - `is_course: bool` — Explicitly distinguishes a course with an unknown result from metadata.  <sub>:323</sub>
    - `completed: Option<bool>`  <sub>:324</sub>
    - `credit: Option<f64>`  <sub>:325</sub>
    - `semester: Option<String>`  <sub>:326</sub>
- `pub struct GraduateProgressDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:329</sub>
    - `required: Option<f64>`  <sub>:330</sub>
    - `earned: Option<f64>`  <sub>:331</sub>
    - `pending: Option<f64>`  <sub>:332</sub>
- `pub struct GraduateSectionDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:335</sub>
    - `title: String`  <sub>:336</sub>
    - `rows: Vec<GraduateRowDto>`  <sub>:337</sub>
    - `progress: Option<GraduateProgressDto>`  <sub>:338</sub>
- `pub struct AcademicDataDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:341</sub>
    - `sections: Vec<GraduateSectionDto>`  <sub>:342</sub>
    - `notice: Option<String>`  <sub>:343</sub>
- `pub struct GraduateResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:346</sub>
    - `data: Option<AcademicDataDto>`  <sub>:347</sub>
    - `failure: Option<FailureCode>`  <sub>:348</sub>
- `pub async fn load_graduate_part(report: bool, force_refresh: bool) -> GraduateResponse {…}` — Independently cached sections, allowing Flutter to render the first response
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:353</sub>
- `pub fn load_demo_graduate_status() -> GraduateResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:357</sub>
- `pub fn load_demo_graduate() -> GraduateResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:361</sub>
- `pub struct LocalTaskDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:365</sub>
    - `id: String`  <sub>:366</sub>
    - `title: String`  <sub>:367</sub>
    - `due: String` — Empty means no deadline; a calendar date stays a date.  <sub>:369</sub>
    - `completed: bool`  <sub>:370</sub>
    - `source_assignment_id: Option<String>` — Set only for a historical record linked to a school assignment.  <sub>:372</sub>
- `pub struct LocalTasksResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:375</sub>
    - `data: Option<Vec<LocalTaskDto>>`  <sub>:376</sub>
    - `failure: Option<FailureCode>`  <sub>:377</sub>
- `pub async fn edit_tasks( root: String, demo: bool, action: String, id: Option<String>, title: Option<String>, due: Option<String>, completed: Option<bool>, ) -> LocalTasksResponse {…}` — Local CRUD only. Account identity comes from Rust, never a Dart-supplied identifier.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:381</sub>
- `pub struct NoticeDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:393</sub>
    - `title: String`  <sub>:394</sub>
    - `summary: String`  <sub>:395</sub>
    - `published_at: String`  <sub>:396</sub>
    - `url: String`  <sub>:397</sub>
- `pub struct NoticesResponse` — A failure may accompany data only when it is a previous successful snapshot.
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:401</sub>
    - `data: Option<Vec<NoticeDto>>`  <sub>:402</sub>
    - `failure: Option<FailureCode>`  <sub>:403</sub>
- `pub async fn load_notices(force_refresh: bool) -> NoticesResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:406</sub>
- `pub struct CampusCardBalanceResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:410</sub>
    - `balance_minor: Option<i64>`  <sub>:411</sub>
    - `fetched_at: Option<String>`  <sub>:412</sub>
    - `failure: Option<FailureCode>`  <sub>:413</sub>
    - `failure_detail: Option<String>`  <sub>:414</sub>
- `pub async fn load_campus_card_balance() -> CampusCardBalanceResponse {…}` — Explicit, user-triggered campus-card balance read. No disk cache or bank data.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:418</sub>
- `pub fn load_demo_campus_card_balance() -> CampusCardBalanceResponse {…}` — Synthetic balance for the isolated demo workspace.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:423</sub>
- `pub fn load_demo_notices() -> NoticesResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:427</sub>
- `pub async fn load_career_events(month: String, force_refresh: bool) -> CareerEventsResponse {…}` — Public career-calendar events for a school month (YYYY-MM). Read-only.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:432</sub>
- `pub struct CareerEventDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:436</sub>
    - `id: String`  <sub>:437</sub>
    - `title: String`  <sub>:438</sub>
    - `campus: String`  <sub>:439</sub>
    - `place: String`  <sub>:440</sub>
    - `begins_at: String`  <sub>:441</sub>
    - `ends_at: String`  <sub>:442</sub>
    - `fair_type: String`  <sub>:443</sub>
    - `status: String`  <sub>:444</sub>
    - `url: String`  <sub>:445</sub>
- `pub struct CareerEventsDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:448</sub>
    - `month: String`  <sub>:449</sub>
    - `events: Vec<CareerEventDto>`  <sub>:450</sub>
    - `fetched_at: String`  <sub>:451</sub>
- `pub struct CareerEventsResponse` — A failure may accompany data only when it is a previous successful snapshot.
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:455</sub>
    - `data: Option<CareerEventsDto>`  <sub>:456</sub>
    - `failure: Option<FailureCode>`  <sub>:457</sub>
- `pub struct CampusActivityDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:460</sub>
    - `id: String`  <sub>:461</sub>
    - `title: String`  <sub>:462</sub>
    - `category: String`  <sub>:463</sub>
    - `published_at: String`  <sub>:464</sub>
    - `activity_time: String`  <sub>:465</sub>
    - `place: String`  <sub>:466</sub>
    - `url: String`  <sub>:467</sub>
- `pub struct CampusActivitiesDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:470</sub>
    - `page: i32`  <sub>:471</sub>
    - `activities: Vec<CampusActivityDto>`  <sub>:472</sub>
    - `fetched_at: String`  <sub>:473</sub>
- `pub struct CampusActivitiesResponse` — Published and displayed dates stay separate fields; neither is a deadline.
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:477</sub>
    - `data: Option<CampusActivitiesDto>`  <sub>:478</sub>
    - `failure: Option<FailureCode>`  <sub>:479</sub>
- `pub async fn load_campus_activities(page: i32, force_refresh: bool) -> CampusActivitiesResponse {…}` — Public campus cultural activities (page 1-based). Read-only.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:483</sub>
- `pub struct CgyySiteDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:487</sub>
    - `id: i64`  <sub>:488</sub>
    - `name: String`  <sub>:489</sub>
    - `venue: String`  <sub>:490</sub>
    - `campus: String`  <sub>:491</sub>
    - `seats: Option<i64>`  <sub>:492</sub>
    - `open_start: String`  <sub>:493</sub>
    - `open_end: String`  <sub>:494</sub>
- `pub struct CgyySlotDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:497</sub>
    - `time: String`  <sub>:498</sub>
    - `status: String`  <sub>:499</sub>
- `pub struct CgyySpaceDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:502</sub>
    - `name: String`  <sub>:503</sub>
    - `slots: Vec<CgyySlotDto>`  <sub>:504</sub>
- `pub struct CgyyDayDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:507</sub>
    - `site_id: i64`  <sub>:508</sub>
    - `date: String`  <sub>:509</sub>
    - `dates: Vec<String>`  <sub>:510</sub>
    - `spaces: Vec<CgyySpaceDto>`  <sub>:511</sub>
- `pub struct CgyyOrderDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:514</sub>
    - `order_status: Option<i64>`  <sub>:515</sub>
    - `check_status: Option<i64>`  <sub>:516</sub>
    - `can_cancel: bool`  <sub>:517</sub>
    - `id: i64`  <sub>:518</sub>
    - `place: String`  <sub>:519</sub>
    - `date: String`  <sub>:520</sub>
    - `time: String`  <sub>:521</sub>
    - `status: String`  <sub>:522</sub>
- `pub struct CgyyLockCodeDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:525</sub>
    - `qr_code: Option<String>`  <sub>:526</sub>
    - `due_date: Option<String>`  <sub>:527</sub>
    - `trade_no: Option<String>`  <sub>:528</sub>
    - `venue_name: Option<String>`  <sub>:529</sub>
    - `site_name: Option<String>`  <sub>:530</sub>
    - `space_name: Option<String>`  <sub>:531</sub>
    - `order_name: Option<String>`  <sub>:532</sub>
    - `reservation_date: Option<String>`  <sub>:533</sub>
    - `reservation_date_detail: Option<String>`  <sub>:534</sub>
    - `reservation_start_date: Option<String>`  <sub>:535</sub>
    - `reservation_end_date: Option<String>`  <sub>:536</sub>
- `pub struct CgyyLoadResponse` — Exactly one shape field is `Some`; the rest stay `None` so Dart can switch
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:541</sub>
    - `venues: Option<Vec<CgyySiteDto>>`  <sub>:542</sub>
    - `day: Option<CgyyDayDto>`  <sub>:543</sub>
    - `orders: Option<Vec<CgyyOrderDto>>`  <sub>:544</sub>
    - `order: Option<CgyyOrderDto>`  <sub>:545</sub>
    - `lock_code: Option<CgyyLockCodeDto>`  <sub>:546</sub>
    - `failure: Option<FailureCode>`  <sub>:547</sub>
- `pub struct CgyyBookingChoiceDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:550</sub>
    - `space_id: i64`  <sub>:551</sub>
    - `space_name: String`  <sub>:552</sub>
    - `time_id: i64`  <sub>:553</sub>
    - `time: String`  <sub>:554</sub>
- `pub struct CgyyPurposeDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:557</sub>
    - `id: i64`  <sub>:558</sub>
    - `name: String`  <sub>:559</sub>
- `pub struct CgyyBookingOptionsDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:562</sub>
    - `choices: Vec<CgyyBookingChoiceDto>`  <sub>:563</sub>
    - `purposes: Vec<CgyyPurposeDto>`  <sub>:564</sub>
    - `uses_fallback_purposes: bool`  <sub>:565</sub>
- `pub struct CgyyChallengeDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:568</sub>
    - `id: String`  <sub>:569</sub>
    - `background: String`  <sub>:570</sub>
    - `jigsaw: String`  <sub>:571</sub>
- `pub struct CgyyReviewDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:574</sub>
    - `id: String`  <sub>:575</sub>
    - `orders: Vec<CgyyOrderDto>`  <sub>:576</sub>
- `pub struct CgyyActionResultDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:579</sub>
    - `state: String`  <sub>:580</sub>
    - `message: String`  <sub>:581</sub>
    - `options: Option<CgyyBookingOptionsDto>`  <sub>:582</sub>
    - `challenge: Option<CgyyChallengeDto>`  <sub>:583</sub>
    - `review: Option<CgyyReviewDto>`  <sub>:584</sub>
- `pub struct CgyyActionResultResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:587</sub>
    - `data: Option<CgyyActionResultDto>`  <sub>:588</sub>
    - `failure: Option<FailureCode>`  <sub>:589</sub>
- `pub async fn load_cgyy( kind: String, site_id: i64, date: String, force_refresh: bool, ) -> CgyyLoadResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:592</sub>
- `pub async fn execute_cgyy(command: String) -> CgyyActionResultResponse {…}` — User-confirmed CGYY commands; payload contains no upstream credentials.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:602</sub>
- `pub fn load_demo_cgyy(kind: String) -> CgyyLoadResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:606</sub>
- `pub struct BookHitDto` — Public OPAC search (read-only, anonymous). Payload is the projected page.
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:611</sub>
    - `bib_id: String`  <sub>:612</sub>
    - `title: String`  <sub>:613</sub>
    - `author: String`  <sub>:614</sub>
    - `publisher: String`  <sub>:615</sub>
    - `year: String`  <sub>:616</sub>
    - `callno: String`  <sub>:617</sub>
    - `isbn: String`  <sub>:618</sub>
    - `items_available: Option<i64>` — Reported copy availability, or `None` when the source stays silent.  <sub>:620</sub>
    - `item_count: Option<i64>`  <sub>:621</sub>
- `pub struct BookPageDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:624</sub>
    - `page: i64`  <sub>:625</sub>
    - `page_size: i64`  <sub>:626</sub>
    - `total: i64`  <sub>:627</sub>
    - `actual_total: i64`  <sub>:628</sub>
    - `items: Vec<BookHitDto>`  <sub>:629</sub>
    - `has_more: bool` — True when the school reported more matches than this page returned.  <sub>:631</sub>
- `pub struct BookPageResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:634</sub>
    - `data: Option<BookPageDto>`  <sub>:635</sub>
    - `failure: Option<FailureCode>`  <sub>:636</sub>
- `pub async fn load_library_books( query: String, page: i64, sort: String, descending: bool, ) -> BookPageResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:639</sub>
- `pub struct ShuttleRunDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:648</sub>
    - `index: String`  <sub>:649</sub>
    - `time: String`  <sub>:650</sub>
    - `capacity: String`  <sub>:651</sub>
- `pub struct ShuttleSectionDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:654</sub>
    - `label: String`  <sub>:655</sub>
    - `left: Vec<ShuttleRunDto>`  <sub>:656</sub>
    - `right: Vec<ShuttleRunDto>`  <sub>:657</sub>
- `pub struct ShuttleTableDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:660</sub>
    - `left: String`  <sub>:661</sub>
    - `right: String`  <sub>:662</sub>
    - `sections: Vec<ShuttleSectionDto>`  <sub>:663</sub>
- `pub struct ShuttleTimetableDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:666</sub>
    - `tables: Vec<ShuttleTableDto>`  <sub>:667</sub>
    - `source: String`  <sub>:668</sub>
    - `live_source: String`  <sub>:669</sub>
- `pub struct ShuttleTimetableResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:672</sub>
    - `data: Option<ShuttleTimetableDto>`  <sub>:673</sub>
    - `failure: Option<FailureCode>`  <sub>:674</sub>
- `pub async fn load_shuttle_timetable() -> ShuttleTimetableResponse {…}` — Published shuttle timetable (official page). Read-only, no ticketing.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:678</sub>
- `pub struct BookHoldingDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:682</sub>
    - `call_no: String`  <sub>:683</sub>
    - `bar_code: String`  <sub>:684</sub>
    - `library: String`  <sub>:685</sub>
    - `location: String`  <sub>:686</sub>
    - `status: String` — The school's own status text; never a local available/unavailable flag.  <sub>:688</sub>
- `pub struct BookHoldingsResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:691</sub>
    - `data: Option<Vec<BookHoldingDto>>`  <sub>:692</sub>
    - `failure: Option<FailureCode>`  <sub>:693</sub>
- `pub async fn load_library_holdings(bib_id: String) -> BookHoldingsResponse {…}` — Public holdings for one bib id; the nested JSON string never crosses the bridge.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:697</sub>
- `pub struct LearningSnapshotResponse` — Transient archive bytes. Hosts must use explicitly opted-in encrypted storage.
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:702</sub>
    - `bytes: Option<Vec<u8>>`  <sub>:703</sub>
    - `failure: Option<FailureCode>`  <sub>:704</sub>
- `pub async fn export_learning_snapshots(expected_account: String) -> LearningSnapshotResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:706</sub>
- `pub async fn import_learning_snapshots( expected_account: String, bytes: Vec<u8>, ) -> SnapshotImportResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:709</sub>
- `pub fn library_loans_portal_url() -> String {…}` — Public website metadata only. Does not initialize an authenticated session.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:718</sub>
- `pub fn student_service_url(id: String) -> Option<String> {…}` — Public destination metadata; does not initialize an authenticated session.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:724</sub>
- `pub struct LibraryLoanDto` — Explicit private read, scoped to the caller's account. No disk cache or writes.
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:729</sub>
    - `id: String`  <sub>:730</sub>
    - `title: Option<String>`  <sub>:731</sub>
    - `author: Option<String>`  <sub>:732</sub>
    - `call_number: Option<String>`  <sub>:733</sub>
    - `borrowed_at: Option<String>`  <sub>:734</sub>
    - `due_at: Option<String>`  <sub>:735</sub>
- `pub struct LibraryLoanPageDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:738</sub>
    - `items: Vec<LibraryLoanDto>`  <sub>:739</sub>
    - `page: u32`  <sub>:740</sub>
    - `total: u32`  <sub>:741</sub>
    - `has_more: bool`  <sub>:742</sub>
- `pub struct LibraryLoansResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:745</sub>
    - `data: Option<LibraryLoanPageDto>`  <sub>:746</sub>
    - `failure: Option<FailureCode>`  <sub>:747</sub>
- `pub async fn load_library_loans(expected_account: String, page: u32) -> LibraryLoansResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:750</sub>
- `pub struct CountPairDto` — Public counts only. No school identity or library token is serialized.
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:755</sub>
    - `available: i32`  <sub>:756</sub>
    - `total: i32`  <sub>:757</sub>
- `pub struct ReadingRoomDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:760</sub>
    - `name: String`  <sub>:761</sub>
    - `people: i32`  <sub>:762</sub>
- `pub struct LibraryCampusStatsDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:765</sub>
    - `id: String`  <sub>:766</sub>
    - `name: String`  <sub>:767</sub>
    - `people: i32`  <sub>:768</sub>
    - `reading_rooms: Vec<ReadingRoomDto>`  <sub>:769</sub>
    - `seats: Option<CountPairDto>` — Absent means the school did not publish that resource, not zero.  <sub>:771</sub>
    - `study_rooms: Option<CountPairDto>`  <sub>:772</sub>
    - `lockers: Option<CountPairDto>`  <sub>:773</sub>
- `pub struct LibraryStatsDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:776</sub>
    - `campuses: Vec<LibraryCampusStatsDto>`  <sub>:777</sub>
    - `fetched_at: Option<String>`  <sub>:778</sub>
    - `from_cache: bool`  <sub>:779</sub>
- `pub struct LibraryStatsResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:782</sub>
    - `data: Option<LibraryStatsDto>`  <sub>:783</sub>
    - `failure: Option<FailureCode>`  <sub>:784</sub>
- `pub async fn load_library_stats(force_refresh: bool) -> LibraryStatsResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:787</sub>
- `pub fn load_demo_library_stats() -> LibraryStatsResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:790</sub>
- `pub struct AndroidDownloadDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:794</sub>
    - `version: String`  <sub>:795</sub>
    - `name: String`  <sub>:796</sub>
    - `url: String`  <sub>:797</sub>
    - `api_url: String`  <sub>:798</sub>
    - `size: i64` — Upstream only ever publishes a verified asset inside  <sub>:801</sub>
    - `sha256: String`  <sub>:802</sub>
- `pub struct UpdateSummaryDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:805</sub>
    - `current: String`  <sub>:806</sub>
    - `latest: Option<String>`  <sub>:807</sub>
    - `available: bool`  <sub>:808</sub>
    - `page_url: Option<String>`  <sub>:809</sub>
    - `notes: Option<String>`  <sub>:810</sub>
    - `apk_available: bool`  <sub>:811</sub>
    - `download: Option<AndroidDownloadDto>`  <sub>:812</sub>
- `pub struct UpdateResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:815</sub>
    - `data: Option<UpdateSummaryDto>`  <sub>:816</sub>
    - `failure: Option<FailureCode>`  <sub>:817</sub>
- `pub async fn check_android_update(current: String) -> UpdateResponse {…}` — Deliberately independent from login, school routes and account caches.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:821</sub>
- `pub struct MutationResponse` — User-confirmed write. Never retries the mutation and never exposes raw upstream text.
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:826</sub>
    - `state: String`  <sub>:827</sub>
    - `message: String`  <sub>:828</sub>
- `pub async fn submit_checkin(course_id: String) -> MutationResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:831</sub>
- `pub async fn reserve_library_seat( area_id: String, seat_id: String, slot: crate::api::mirror::LibrarySlot, ) -> MutationResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:835</sub>
- `pub async fn perform_library_action(booking_id: String, action: String) -> MutationResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:842</sub>
- `pub struct HomeworkAttachmentDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:897</sub>
    - `id: String`  <sub>:898</sub>
    - `name: String`  <sub>:899</sub>
    - `kind: String`  <sub>:900</sub>
- `pub struct HomeworkWorkspaceDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:903</sub>
    - `assignment_id: String`  <sub>:904</sub>
    - `allowed_methods: Vec<String>`  <sub>:905</sub>
    - `allowed_extensions: Vec<String>`  <sub>:906</sub>
    - `submission_limit: Option<u32>`  <sub>:907</sub>
    - `submitted_count: Option<u32>`  <sub>:908</sub>
    - `returned: bool`  <sub>:909</sub>
    - `submitted_text: Option<String>`  <sub>:910</sub>
    - `feedback: Option<String>`  <sub>:911</sub>
    - `attachments: Vec<HomeworkAttachmentDto>`  <sub>:912</sub>
    - `can_submit_file: bool`  <sub>:913</sub>
    - `blocked_reason: Option<String>`  <sub>:914</sub>
    - `file_limit_bytes: i64` — Widened from `u64`; the 20 MB upload cap keeps this lossless.  <sub>:916</sub>
- `pub struct HomeworkFileWorkspaceResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:919</sub>
    - `data: Option<HomeworkWorkspaceDto>`  <sub>:920</sub>
    - `failure: Option<FailureCode>`  <sub>:921</sub>
- `pub struct HomeworkUploadReceiptDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:924</sub>
    - `handle: String`  <sub>:925</sub>
    - `file_name: String`  <sub>:926</sub>
    - `size: i64` — Widened from `u64`; the 20 MB upload cap keeps this lossless.  <sub>:928</sub>
- `pub struct HomeworkUploadResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:931</sub>
    - `data: Option<HomeworkUploadReceiptDto>`  <sub>:932</sub>
    - `failure: Option<FailureCode>`  <sub>:933</sub>
- `pub async fn homework_file_workspace( expected_account: String, assignment_id: String, ) -> HomeworkFileWorkspaceResponse {…}` — Homework business JSON only; raw SPOC payloads never leave upstream.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:937</sub>
- `pub async fn upload_homework_file( expected_account: String, assignment_id: String, name: String, bytes: Vec<u8>, ) -> HomeworkUploadResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:943</sub>
- `pub async fn submit_homework_file( expected_account: String, handle: String, confirmed: bool, ) -> MutationResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:951</sub>
- `pub async fn reconcile_homework_file(expected_account: String, handle: String) -> MutationResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:958</sub>
- `pub struct HomeworkFileDownloadResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:961</sub>
    - `name: Option<String>`  <sub>:962</sub>
    - `bytes: Option<Vec<u8>>`  <sub>:963</sub>
    - `failure: Option<FailureCode>`  <sub>:964</sub>
- `pub async fn download_homework_file( expected_account: String, assignment_id: String, attachment_id: String, ) -> HomeworkFileDownloadResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:966</sub>
- `pub struct LearningCourseDto` — Learning queries return business DTO JSON, never school response envelopes.
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:975</sub>
    - `id: String`  <sub>:976</sub>
    - `name: String`  <sub>:977</sub>
    - `teacher: Option<String>`  <sub>:978</sub>
    - `term: Option<String>`  <sub>:979</sub>
    - `source_url: String`  <sub>:980</sub>
- `pub struct LearningCoursesResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:983</sub>
    - `data: Option<Vec<LearningCourseDto>>`  <sub>:984</sub>
    - `failure: Option<FailureCode>`  <sub>:985</sub>
- `pub struct CourseAnnouncementDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:988</sub>
    - `id: String`  <sub>:989</sub>
    - `title: String`  <sub>:990</sub>
    - `published_at: Option<String>`  <sub>:991</sub>
- `pub struct CourseAnnouncementsResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:994</sub>
    - `data: Option<Vec<CourseAnnouncementDto>>`  <sub>:995</sub>
    - `failure: Option<FailureCode>`  <sub>:996</sub>
- `pub struct LearningAttachmentDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:999</sub>
    - `id: String`  <sub>:1000</sub>
    - `name: String`  <sub>:1001</sub>
- `pub struct CourseAnnouncementDetailDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1004</sub>
    - `id: String`  <sub>:1005</sub>
    - `title: String`  <sub>:1006</sub>
    - `content: Option<String>`  <sub>:1007</sub>
    - `attachments: Vec<LearningAttachmentDto>`  <sub>:1008</sub>
- `pub struct CourseAnnouncementDetailResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1011</sub>
    - `data: Option<CourseAnnouncementDetailDto>`  <sub>:1012</sub>
    - `failure: Option<FailureCode>`  <sub>:1013</sub>
- `pub struct CourseResourceDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1016</sub>
    - `id: String`  <sub>:1017</sub>
    - `name: String`  <sub>:1018</sub>
    - `folder: bool`  <sub>:1019</sub>
    - `downloadable: bool`  <sub>:1020</sub>
    - `updated_at: Option<String>`  <sub>:1021</sub>
    - `extension: Option<String>`  <sub>:1022</sub>
- `pub struct CourseResourcePageDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1025</sub>
    - `items: Vec<CourseResourceDto>`  <sub>:1026</sub>
    - `page: u32`  <sub>:1027</sub>
    - `has_next: bool`  <sub>:1028</sub>
- `pub struct CourseResourcePageResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1031</sub>
    - `data: Option<CourseResourcePageDto>`  <sub>:1032</sub>
    - `failure: Option<FailureCode>`  <sub>:1033</sub>
- `pub struct CourseAssessmentDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1036</sub>
    - `id: String`  <sub>:1037</sub>
    - `title: String`  <sub>:1038</sub>
    - `starts_at: Option<String>`  <sub>:1039</sub>
    - `due_at: Option<String>`  <sub>:1040</sub>
    - `score: Option<String>`  <sub>:1041</sub>
    - `source_url: String`  <sub>:1042</sub>
- `pub struct CourseAssessmentsResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1045</sub>
    - `data: Option<Vec<CourseAssessmentDto>>`  <sub>:1046</sub>
    - `failure: Option<FailureCode>`  <sub>:1047</sub>
- `pub enum LearningColumnKindDto`
  <sub>enum · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1050</sub>
- `pub struct LearningColumnDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1055</sub>
    - `id: String`  <sub>:1056</sub>
    - `name: String`  <sub>:1057</sub>
    - `kind: LearningColumnKindDto`  <sub>:1058</sub>
- `pub struct LearningColumnsResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1061</sub>
    - `data: Option<Vec<LearningColumnDto>>`  <sub>:1062</sub>
    - `failure: Option<FailureCode>`  <sub>:1063</sub>
- `pub enum LearningCapabilityStateDto`
  <sub>enum · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1066</sub>
- `pub struct LearningCapabilitiesDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1075</sub>
    - `columns: LearningCapabilityStateDto`  <sub>:1076</sub>
    - `announcements: LearningCapabilityStateDto`  <sub>:1077</sub>
    - `resources: LearningCapabilityStateDto`  <sub>:1078</sub>
    - `assessments: LearningCapabilityStateDto`  <sub>:1079</sub>
    - `resource_download: LearningCapabilityStateDto`  <sub>:1080</sub>
    - `announcement_download: LearningCapabilityStateDto`  <sub>:1081</sub>
- `pub struct LearningCapabilitiesResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1084</sub>
    - `data: Option<LearningCapabilitiesDto>`  <sub>:1085</sub>
    - `failure: Option<FailureCode>`  <sub>:1086</sub>
- `pub struct SnapshotImportResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1089</sub>
    - `imported: Option<u32>` — Count of snapshots actually merged, not the number offered.  <sub>:1091</sub>
    - `failure: Option<FailureCode>`  <sub>:1092</sub>
- `pub async fn learning_courses(expected_account: String, force: bool) -> LearningCoursesResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1095</sub>
- `pub async fn course_announcements( expected_account: String, course: String, force: bool, ) -> CourseAnnouncementsResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1098</sub>
- `pub async fn course_announcement_detail( expected_account: String, course: String, id: String, ) -> CourseAnnouncementDetailResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1105</sub>
- `pub async fn course_resources( expected_account: String, course: String, folder: Option<String>, page: u32, force: bool, ) -> CourseResourcePageResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1112</sub>
- `pub async fn course_assessments( expected_account: String, course: String, force: bool, ) -> CourseAssessmentsResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1121</sub>
- `pub async fn course_resource_download( expected_account: String, course: String, folder: Option<String>, page: u32, id: String, ) -> HomeworkFileDownloadResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1128</sub>
- `pub async fn course_announcement_attachment( expected_account: String, course: String, id: String, file: String, ) -> HomeworkFileDownloadResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1137</sub>
- `pub async fn course_learning_columns( expected_account: String, course: String, force: bool, ) -> LearningColumnsResponse {…}` — Explicit module context; all identifiers are revalidated by the source.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1150</sub>
- `pub async fn course_learning_capabilities( expected_account: String, course: String, ) -> LearningCapabilitiesResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1157</sub>
- `pub async fn course_announcements_in( expected_account: String, course: String, column: String, force: bool, ) -> CourseAnnouncementsResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1163</sub>
- `pub async fn course_assessments_in( expected_account: String, course: String, column: String, force: bool, ) -> CourseAssessmentsResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1171</sub>
- `pub async fn course_announcement_detail_in( expected_account: String, course: String, column: String, id: String, ) -> CourseAnnouncementDetailResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1179</sub>
- `pub async fn course_announcement_attachment_in( expected_account: String, course: String, column: String, id: String, file: String, ) -> HomeworkFileDownloadResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1187</sub>
- `pub async fn course_resources_at( expected_account: String, course: String, path: Vec<String>, page: u32, force: bool, ) -> CourseResourcePageResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1196</sub>
- `pub async fn course_resource_download_at( expected_account: String, course: String, path: Vec<String>, page: u32, id: String, ) -> HomeworkFileDownloadResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1205</sub>
- `pub enum GraduateCreditStateDto`
  <sub>enum · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1214</sub>
- `pub struct GraduateCreditMetricsDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1221</sub>
    - `state: GraduateCreditStateDto`  <sub>:1222</sub>
    - `required: Option<f64>`  <sub>:1223</sub>
    - `earned: Option<f64>`  <sub>:1224</sub>
    - `pending: Option<f64>`  <sub>:1225</sub>
    - `remaining: Option<f64>` — Derived only from this node's official requirement and earned credits.  <sub>:1227</sub>
    - `ratio: Option<f64>`  <sub>:1228</sub>
- `pub struct GraduateCreditRowDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1231</sub>
    - `title: String`  <sub>:1232</sub>
    - `detail: String`  <sub>:1233</sub>
    - `is_course: bool`  <sub>:1234</sub>
    - `completed: Option<bool>`  <sub>:1235</sub>
    - `credit: Option<f64>`  <sub>:1236</sub>
    - `semester: Option<String>`  <sub>:1237</sub>
- `pub struct GraduateCreditNodeDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1240</sub>
    - `source_index: u32` — Source ordinal, not an inferred category/group relationship.  <sub>:1242</sub>
    - `title: String`  <sub>:1243</sub>
    - `progress: Option<GraduateCreditMetricsDto>`  <sub>:1244</sub>
    - `rows: Vec<GraduateCreditRowDto>`  <sub>:1245</sub>
- `pub struct GraduateCreditMapDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1248</sub>
    - `summary: Option<GraduateCreditNodeDto>`  <sub>:1249</sub>
    - `nodes: Vec<GraduateCreditNodeDto>`  <sub>:1250</sub>
    - `notice: Option<String>`  <sub>:1251</sub>
- `pub struct GraduateCreditMapResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1254</sub>
    - `data: Option<GraduateCreditMapDto>`  <sub>:1255</sub>
    - `failure: Option<FailureCode>`  <sub>:1256</sub>
- `pub async fn load_graduate_credit_map( expected_account: String, force_refresh: bool, ) -> GraduateCreditMapResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1259</sub>
- `pub struct HomeworkPendingSubmissionDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1265</sub>
    - `handle: String`  <sub>:1266</sub>
    - `assignment_id: String`  <sub>:1267</sub>
    - `file_name: String`  <sub>:1268</sub>
    - `size: i64` — Widened from `u64`; the 20 MB upload cap keeps this lossless.  <sub>:1270</sub>
- `pub struct HomeworkPendingResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1273</sub>
    - `data: Option<Vec<HomeworkPendingSubmissionDto>>`  <sub>:1274</sub>
    - `failure: Option<FailureCode>`  <sub>:1275</sub>
- `pub enum HomeworkCapabilityStateDto`
  <sub>enum · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1278</sub>
- `pub struct HomeworkCapabilityEvidenceDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1287</sub>
    - `capability: String`  <sub>:1288</sub>
    - `state: HomeworkCapabilityStateDto`  <sub>:1289</sub>
    - `reason: String`  <sub>:1290</sub>
    - `evidence: String`  <sub>:1291</sub>
- `pub struct HomeworkCapabilitiesResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1294</sub>
    - `data: Option<Vec<HomeworkCapabilityEvidenceDto>>`  <sub>:1295</sub>
    - `failure: Option<FailureCode>`  <sub>:1296</sub>
- `pub struct HomeworkRecoveryResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1299</sub>
    - `configured: Option<bool>` — `Some(true)` only after the store accepted the private directory.  <sub>:1301</sub>
    - `failure: Option<FailureCode>`  <sub>:1302</sub>
- `pub async fn configure_homework_recovery( expected_account: String, storage_root: String, ) -> HomeworkRecoveryResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1305</sub>
- `pub async fn pending_homework_submissions( expected_account: String, assignment_id: Option<String>, ) -> HomeworkPendingResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1311</sub>
- `pub async fn homework_capabilities( expected_account: String, assignment_id: String, ) -> HomeworkCapabilitiesResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1317</sub>

## academic

- `pub(super) fn load_rule_examples() -> RuleExamples {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror/academic.rs:4</sub>
- `pub(super) fn load_demo_schedule() -> ScheduleResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror/academic.rs:37</sub>
- `pub(super) fn load_demo_grades() -> GradeResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror/academic.rs:119</sub>
- `pub(super) fn load_demo_today() -> TodayResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror/academic.rs:163</sub>
- `pub(super) fn load_demo_homework() -> HomeworkResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror/academic.rs:191</sub>
- `pub(super) fn load_demo_checkin() -> CheckInResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror/academic.rs:241</sub>

## classroom

- `pub(super) fn load_demo_classrooms(query: ClassroomQuery) -> ClassroomResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror/classroom.rs:4</sub>
- `pub(super) fn load_query_dates(instant: String) -> QueryDates {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror/classroom.rs:62</sub>
- `pub(super) fn query_demo_classrooms(scope: DemoScope, query: ClassroomQuery) -> ClassroomResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror/classroom.rs:77</sub>

## library

- `pub(super) fn load_demo_library() -> LibraryDemoResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror/library.rs:4</sub>

## mirror

- `pub fn init_app() {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:6</sub>
- `pub enum ClassroomSort`
  <sub>enum · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:11</sub>
- `pub struct ClassroomQuery`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:17</sub>
    - `search: String`  <sub>:18</sub>
    - `section: i32`  <sub>:19</sub>
    - `minimum_free_sections: i32`  <sub>:20</sub>
    - `minimum_consecutive_sections: i32`  <sub>:21</sub>
    - `building: Option<String>`  <sub>:22</sub>
    - `sort: ClassroomSort`  <sub>:23</sub>
- `pub struct SectionState`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:26</sub>
    - `number: i32`  <sub>:27</sub>
    - `available: bool`  <sub>:28</sub>
- `pub struct ClassroomRow`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:31</sub>
    - `id: String`  <sub>:32</sub>
    - `name: String`  <sub>:33</sub>
    - `floor: String`  <sub>:34</sub>
    - `sections: Vec<i32>`  <sub>:35</sub>
    - `longest_run: i32`  <sub>:36</sub>
    - `section_states: Vec<SectionState>`  <sub>:37</sub>
- `pub struct ClassroomBuilding`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:40</sub>
    - `name: String`  <sub>:41</sub>
    - `rooms: Vec<ClassroomRow>`  <sub>:42</sub>
- `pub enum FailureCode`
  <sub>enum · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:44</sub>
- `pub struct ClassroomResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:84</sub>
    - `buildings: Vec<ClassroomBuilding>`  <sub>:85</sub>
    - `room_count: i32`  <sub>:86</sub>
    - `building_count: i32`  <sub>:87</sub>
    - `free_slot_count: i32`  <sub>:88</sub>
    - `fetched_at: Option<String>`  <sub>:89</sub>
    - `from_cache: bool`  <sub>:90</sub>
    - `failure: Option<FailureCode>`  <sub>:91</sub>
    - `failure_detail: Option<String>`  <sub>:92</sub>
- `pub fn load_demo_classrooms(query: ClassroomQuery) -> ClassroomResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:95</sub>
- `pub struct RuleExamples`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:99</sub>
    - `local_date: String`  <sub>:100</sub>
    - `minutes_since_midnight: i32`  <sub>:101</sub>
    - `time_zone: String`  <sub>:102</sub>
    - `cached_weeks: Vec<i32>`  <sub>:103</sub>
    - `selected_week: i32`  <sub>:104</sub>
    - `course_names: Vec<String>`  <sub>:105</sub>
    - `failure: Option<FailureCode>`  <sub>:106</sub>
- `pub fn load_rule_examples() -> RuleExamples {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:109</sub>
- `pub struct ScheduleTerm`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:113</sub>
    - `id: String`  <sub>:114</sub>
    - `name: String`  <sub>:115</sub>
    - `selected: bool`  <sub>:116</sub>
- `pub struct ScheduleWeek`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:119</sub>
    - `number: i32`  <sub>:120</sub>
    - `start_date: String`  <sub>:121</sub>
    - `end_date: String`  <sub>:122</sub>
    - `current: bool`  <sub>:123</sub>
- `pub struct ScheduleCourse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:126</sub>
    - `id: String`  <sub>:127</sub>
    - `name: String`  <sub>:128</sub>
    - `day: i32`  <sub>:129</sub>
    - `start_section: i32`  <sub>:130</sub>
    - `end_section: i32`  <sub>:131</sub>
    - `start_time: Option<String>`  <sub>:132</sub>
    - `end_time: Option<String>`  <sub>:133</sub>
    - `place: Option<String>`  <sub>:134</sub>
    - `teacher: Option<String>`  <sub>:135</sub>
    - `color: Option<String>`  <sub>:136</sub>
- `pub struct ScheduleExam`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:139</sub>
    - `id: String`  <sub>:140</sub>
    - `course_name: String`  <sub>:141</sub>
    - `course_no: Option<String>`  <sub>:142</sub>
    - `exam_time_description: Option<String>`  <sub>:143</sub>
    - `exam_date: Option<String>`  <sub>:144</sub>
    - `start_time: Option<String>`  <sub>:145</sub>
    - `end_time: Option<String>`  <sub>:146</sub>
    - `exam_place: Option<String>`  <sub>:147</sub>
    - `exam_seat_no: Option<String>`  <sub>:148</sub>
    - `week: Option<i32>`  <sub>:149</sub>
    - `exam_status: Option<String>`  <sub>:150</sub>
    - `exam_type: Option<String>`  <sub>:151</sub>
- `pub struct ScheduleResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:154</sub>
    - `terms: Vec<ScheduleTerm>`  <sub>:155</sub>
    - `weeks: Vec<ScheduleWeek>`  <sub>:156</sub>
    - `term_id: String`  <sub>:157</sub>
    - `week_number: i32`  <sub>:158</sub>
    - `courses: Vec<ScheduleCourse>`  <sub>:159</sub>
    - `exams: Vec<ScheduleExam>`  <sub>:160</sub>
    - `fetched_at: Option<String>`  <sub>:161</sub>
    - `failure: Option<FailureCode>`  <sub>:162</sub>
    - `failure_detail: Option<String>`  <sub>:163</sub>
- `pub fn load_demo_schedule() -> ScheduleResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:166</sub>
- `pub struct GradeCourse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:170</sub>
    - `id: String`  <sub>:171</sub>
    - `name: String`  <sub>:172</sub>
    - `code: Option<String>`  <sub>:173</sub>
    - `credit: Option<f64>`  <sub>:174</sub>
    - `score: String`  <sub>:175</sub>
    - `score_value: Option<f64>`  <sub>:176</sub>
    - `score_type: Option<String>`  <sub>:177</sub>
    - `course_type: Option<String>`  <sub>:178</sub>
- `pub struct GradeSummary`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:181</sub>
    - `course_count: i32`  <sub>:182</sub>
    - `credit_total: f64`  <sub>:183</sub>
    - `weighted_average: Option<f64>`  <sub>:184</sub>
    - `grade_point_average: Option<f64>`  <sub>:185</sub>
- `pub struct GradeResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:188</sub>
    - `term_id: String`  <sub>:189</sub>
    - `courses: Vec<GradeCourse>`  <sub>:190</sub>
    - `summary: GradeSummary`  <sub>:191</sub>
    - `fetched_at: Option<String>`  <sub>:192</sub>
    - `failure: Option<FailureCode>`  <sub>:193</sub>
    - `failure_detail: Option<String>`  <sub>:194</sub>
- `pub fn load_demo_grades() -> GradeResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:197</sub>
- `pub struct TodayCourse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:201</sub>
    - `name: String`  <sub>:202</sub>
    - `place: Option<String>`  <sub>:203</sub>
    - `time: Option<String>`  <sub>:204</sub>
    - `short_name: Option<String>`  <sub>:205</sub>
- `pub struct TodayResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:208</sub>
    - `date: String`  <sub>:209</sub>
    - `courses: Vec<TodayCourse>`  <sub>:210</sub>
    - `fetched_at: Option<String>`  <sub>:211</sub>
    - `failure: Option<FailureCode>`  <sub>:212</sub>
    - `failure_detail: Option<String>`  <sub>:213</sub>
- `pub fn load_demo_today() -> TodayResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:216</sub>
- `pub enum HomeworkStatus`
  <sub>enum · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:220</sub>
- `pub struct HomeworkItem`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:226</sub>
    - `course_role: Option<String>`  <sub>:227</sub>
    - `teacher_name: Option<String>`  <sub>:228</sub>
    - `id: String`  <sub>:229</sub>
    - `course_id: Option<String>`  <sub>:230</sub>
    - `course_name: String`  <sub>:231</sub>
    - `title: String`  <sub>:232</sub>
    - `published_at: Option<String>`  <sub>:233</sub>
    - `due_at: Option<String>`  <sub>:234</sub>
    - `status: HomeworkStatus`  <sub>:235</sub>
    - `status_detail: Option<String>`  <sub>:236</sub>
    - `score: Option<String>`  <sub>:237</sub>
- `pub struct HomeworkResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:240</sub>
    - `term_name: String`  <sub>:241</sub>
    - `term_code: String`  <sub>:242</sub>
    - `items: Vec<HomeworkItem>`  <sub>:243</sub>
    - `fetched_at: Option<String>`  <sub>:244</sub>
    - `roles_complete: Option<bool>`  <sub>:245</sub>
    - `failure: Option<FailureCode>`  <sub>:246</sub>
    - `failure_detail: Option<String>`  <sub>:247</sub>
- `pub fn load_demo_homework() -> HomeworkResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:250</sub>
- `pub struct QueryDates`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:254</sub>
    - `today: String`  <sub>:255</sub>
    - `tomorrow: String`  <sub>:256</sub>
    - `failure: Option<FailureCode>`  <sub>:257</sub>
- `pub fn load_query_dates(instant: String) -> QueryDates {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:259</sub>
- `pub struct DemoScope`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:263</sub>
    - `campus: i32`  <sub>:264</sub>
    - `date: String`  <sub>:265</sub>
    - `force_refresh: bool`  <sub>:266</sub>
- `pub fn query_demo_classrooms(scope: DemoScope, query: ClassroomQuery) -> ClassroomResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:269</sub>
- `pub enum CheckInStatus`
  <sub>enum · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:273</sub>
- `pub struct CheckInCourse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:279</sub>
    - `id: String`  <sub>:280</sub>
    - `course_id: Option<String>`  <sub>:281</sub>
    - `course_num: Option<String>`  <sub>:282</sub>
    - `course_name: String`  <sub>:283</sub>
    - `begins_at: String`  <sub>:284</sub>
    - `ends_at: String`  <sub>:285</sub>
    - `status: CheckInStatus`  <sub>:286</sub>
    - `teacher_name: Option<String>`  <sub>:287</sub>
    - `classroom_name: Option<String>`  <sub>:288</sub>
    - `merged_record_count: i32`  <sub>:289</sub>
    - `conflicting: bool`  <sub>:290</sub>
    - `sign_in_allowed: Option<bool>` — Explicit false covers merged sessions with conflicting records.  <sub>:292</sub>
- `pub struct CheckInResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:295</sub>
    - `date: String` — School-local date, yyyy-MM-dd.  <sub>:297</sub>
    - `courses: Vec<CheckInCourse>`  <sub>:298</sub>
    - `fetched_at: Option<String>`  <sub>:299</sub>
    - `from_cache: bool`  <sub>:300</sub>
    - `stale: bool`  <sub>:301</sub>
    - `failure: Option<FailureCode>`  <sub>:302</sub>
    - `failure_detail: Option<String>`  <sub>:303</sub>
- `pub fn load_demo_checkin() -> CheckInResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:327</sub>
- `pub struct LibraryVenue`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:331</sub>
    - `id: String`  <sub>:332</sub>
    - `name: String`  <sub>:333</sub>
    - `free: i32`  <sub>:334</sub>
    - `total: i32`  <sub>:335</sub>
- `pub struct LibraryArea`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:338</sub>
    - `id: String`  <sub>:339</sub>
    - `name: String`  <sub>:340</sub>
    - `free: i32`  <sub>:341</sub>
    - `total: i32`  <sub>:342</sub>
- `pub struct LibrarySlot`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:345</sub>
    - `id: String`  <sub>:346</sub>
    - `day: String`  <sub>:347</sub>
    - `start: String`  <sub>:348</sub>
    - `end: String`  <sub>:349</sub>
- `pub struct LibrarySeat`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:352</sub>
    - `id: String`  <sub>:353</sub>
    - `name: String`  <sub>:354</sub>
    - `status_name: String`  <sub>:355</sub>
    - `available: bool`  <sub>:356</sub>
- `pub struct LibraryBooking`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:359</sub>
    - `id: String`  <sub>:360</sub>
    - `title: String`  <sub>:361</sub>
    - `area_name: String`  <sub>:362</sub>
    - `seat_number: String`  <sub>:363</sub>
    - `day: String`  <sub>:364</sub>
    - `start_time: String`  <sub>:365</sub>
    - `end_time: String`  <sub>:366</sub>
    - `status_name: String`  <sub>:367</sub>
    - `actions: Option<Vec<String>>`  <sub>:368</sub>
- `pub struct LibraryVenuesResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:371</sub>
    - `venues: Vec<LibraryVenue>`  <sub>:372</sub>
    - `fetched_at: Option<String>`  <sub>:373</sub>
    - `from_cache: bool`  <sub>:374</sub>
    - `stale: bool`  <sub>:375</sub>
    - `failure: Option<FailureCode>`  <sub>:376</sub>
    - `failure_detail: Option<String>`  <sub>:377</sub>
- `pub struct LibraryAreasResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:380</sub>
    - `areas: Vec<LibraryArea>`  <sub>:381</sub>
    - `failure: Option<FailureCode>`  <sub>:382</sub>
    - `failure_detail: Option<String>`  <sub>:383</sub>
- `pub struct LibrarySlotsResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:386</sub>
    - `slots: Vec<LibrarySlot>`  <sub>:387</sub>
    - `failure: Option<FailureCode>`  <sub>:388</sub>
    - `failure_detail: Option<String>`  <sub>:389</sub>
- `pub struct LibrarySeatsResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:392</sub>
    - `seats: Vec<LibrarySeat>`  <sub>:393</sub>
    - `failure: Option<FailureCode>`  <sub>:394</sub>
    - `failure_detail: Option<String>`  <sub>:395</sub>
- `pub struct LibraryBookingsResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:398</sub>
    - `bookings: Vec<LibraryBooking>`  <sub>:399</sub>
    - `fetched_at: Option<String>`  <sub>:400</sub>
    - `from_cache: bool`  <sub>:401</sub>
    - `stale: bool`  <sub>:402</sub>
    - `failure: Option<FailureCode>`  <sub>:403</sub>
    - `failure_detail: Option<String>`  <sub>:404</sub>
- `pub struct LibraryDemoResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:407</sub>
    - `venues: Vec<LibraryVenue>`  <sub>:408</sub>
    - `areas: Vec<LibraryArea>`  <sub>:409</sub>
    - `slots: Vec<LibrarySlot>`  <sub>:410</sub>
    - `seats: Vec<LibrarySeat>`  <sub>:411</sub>
    - `bookings: Vec<LibraryBooking>`  <sub>:412</sub>
- `pub(super) fn library_venue(value: ginkgo_core::features::library::LibraryVenue) -> LibraryVenue {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:415</sub>
- `pub(super) fn library_area(value: ginkgo_core::features::library::LibraryArea) -> LibraryArea {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:424</sub>
- `pub(super) fn library_slot(value: ginkgo_core::features::library::LibrarySlot) -> LibrarySlot {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:433</sub>
- `pub(super) fn library_seat(value: ginkgo_core::features::library::LibrarySeat) -> LibrarySeat {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:442</sub>
- `pub(super) fn library_booking( value: ginkgo_core::features::library::LibraryBooking, ) -> LibraryBooking {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:451</sub>
- `pub fn load_demo_library() -> LibraryDemoResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:468</sub>

## reminder_planning

- `pub struct CourseReminderSeed`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/reminder_planning.rs:6</sub>
    - `id: String`  <sub>:7</sub>
    - `week_start: String`  <sub>:8</sub>
    - `day: i32`  <sub>:9</sub>
    - `starts_at: String`  <sub>:10</sub>
    - `ends_at: String`  <sub>:11</sub>
- `pub struct TaskReminderSeed`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/reminder_planning.rs:14</sub>
    - `id: String`  <sub>:15</sub>
    - `due: String`  <sub>:16</sub>
    - `completed: bool`  <sub>:17</sub>
- `pub struct PlannedReminder`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/reminder_planning.rs:20</sub>
    - `key: String`  <sub>:21</sub>
    - `group: String`  <sub>:22</sub>
    - `at_millis: i64`  <sub>:23</sub>
    - `expires_millis: i64`  <sub>:24</sub>
- `pub struct ReminderPlanResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/reminder_planning.rs:27</sub>
    - `plans: Vec<PlannedReminder>`  <sub>:28</sub>
    - `skipped: u32`  <sub>:29</sub>
    - `unsupported: bool`  <sub>:30</sub>
- `pub fn plan_course_task_reminders( courses: Vec<CourseReminderSeed>, tasks: Vec<TaskReminderSeed>, now_millis: i64, ) -> ReminderPlanResponse {…}` — Data-only plans. Calling this never requests notification permissions or sends notifications.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/reminder_planning.rs:35</sub>
- `pub struct CheckInReminderSeed`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/reminder_planning.rs:83</sub>
    - `id: String`  <sub>:84</sub>
    - `date: String`  <sub>:85</sub>
    - `begins_at: String`  <sub>:86</sub>
    - `ends_at: String`  <sub>:87</sub>
    - `not_signed: bool`  <sub>:88</sub>
    - `conflicting: bool`  <sub>:89</sub>
    - `sign_in_allowed: Option<bool>`  <sub>:90</sub>
    - `merged_record_count: u32`  <sub>:91</sub>
- `pub struct HomeworkReminderSeed`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/reminder_planning.rs:94</sub>
    - `id: String`  <sub>:95</sub>
    - `due_at: String`  <sub>:96</sub>
    - `pending: bool`  <sub>:97</sub>
- `pub fn plan_checkin_homework_reminders( checkin: Vec<CheckInReminderSeed>, homework: Vec<HomeworkReminderSeed>, now_millis: i64, ) -> ReminderPlanResponse {…}` — Data-only plans for check-in and assignment deadlines. The rule lives in the
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/reminder_planning.rs:103</sub>

## rules

- `pub enum HomeworkDeadlineStatus`
  <sub>enum · rust/crates/ginkgo_flutter_bridge/src/api/rules.rs:6</sub>
- `pub fn classify_homework_deadline( due_at: Option<String>, now_millis: i64, ) -> HomeworkDeadlineStatus {…}` — Classify a school deadline against the Beijing wall clock.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/rules.rs:29</sub>
- `pub fn checkin_sign_in_window( date: String, begins_at: String, ends_at: String, now_millis: i64, ) -> bool {…}` — Whether a check-in session accepts a sign-in at `now_millis`.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/rules.rs:48</sub>
