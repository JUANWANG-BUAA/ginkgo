# 桥接（ginkgo_flutter_bridge）

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
FFI DTO 与粗粒度命令；Dart 唯一可见的 Rust 面。

## 目录

- [academic](#academic) (5)
- [auth_challenge](#authchallenge) (5)
- [background_reminders](#backgroundreminders) (1)
- [bykc](#bykc) (6)
- [checkin](#checkin) (3)
- [classroom](#classroom) (1)
- [evaluation](#evaluation) (1)
- [finance](#finance) (1)
- [graduate](#graduate) (4)
- [homework](#homework) (10)
- [learning](#learning) (15)
- [library](#library) (11)
- [mapping](#mapping) (15)
- [network_account](#networkaccount) (1)
- [runtime](#runtime) (18)
- [session](#session) (6)
- [utilities](#utilities) (17)
- [live](#live) (210)
- [academic](#academic) (7)
- [classroom](#classroom) (3)
- [library](#library) (1)
- [mirror](#mirror) (55)
- [reminder_planning](#reminderplanning) (8)
- [rules](#rules) (3)

## academic

- `pub(super) async fn load_schedule( term_id: Option<String>, week: Option<i32>, force_refresh: bool, ) -> ScheduleResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/academic.rs:15</sub>
- `pub(super) async fn load_today(force_refresh: bool) -> TodayResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/academic.rs:44</sub>
- `pub(super) async fn load_checkin_today(force_refresh: bool) -> CheckInResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/academic.rs:78</sub>
- `pub(super) async fn load_grade_terms() -> GradeTermsResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/academic.rs:92</sub>
- `pub(super) async fn load_grades(term_code: Option<String>, force_refresh: bool) -> GradeResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/academic.rs:128</sub>

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
- `pub async fn load_gateway_challenge( expected_account: String, expected_id: Option<String>, refresh: bool, ) -> LoginChallengeResponse {…}` — Empty challenge fields with no failure mean there is no pending challenge.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/auth_challenge.rs:41</sub>
- `pub struct GatewayVerificationResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live/auth_challenge.rs:77</sub>
    - `verified: bool`  <sub>:78</sub>
    - `failure: Option<FailureCode>`  <sub>:79</sub>
- `pub async fn resume_gateway_login( expected_account: String, expected_id: String, answer: String, ) -> GatewayVerificationResponse {…}` — One explicit answer, bound to the current challenge; never retried here.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/auth_challenge.rs:83</sub>

## background_reminders

- `pub(super) async fn read(owner: String, checkin: bool, homework: bool) -> BackgroundReminderRead {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/background_reminders.rs:3</sub>

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
- `pub(super) async fn prepare_checkin_qr( course_id: String, revalidate_course: bool, offset_ms: u32, ) -> CheckInQrResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/checkin.rs:46</sub>

## classroom

- `pub(super) async fn load_classrooms(scope: LiveScope, query: ClassroomQuery) -> ClassroomResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/classroom.rs:4</sub>

## evaluation

- `pub(super) async fn load( expected_account: String, force_refresh: bool, ) -> TeachingEvaluationResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/evaluation.rs:4</sub>

## finance

- `pub(super) async fn load(expected_account: String) -> FinanceIncomeResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/finance.rs:4</sub>

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
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/homework.rs:6</sub>
- `pub(super) fn homework_response( result: Result<ginkgo_core::application::HomeworkOutcome, AppError>, ) -> crate::api::mirror::HomeworkResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/homework.rs:24</sub>
- `pub(super) async fn load_homework_detail( assignment_id: String, force_refresh: bool, ) -> HomeworkDetailResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/homework.rs:77</sub>
- `pub(super) async fn file_workspace(expected: String, id: String) -> HomeworkFileWorkspaceResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/homework.rs:187</sub>
- `pub(super) async fn upload_file( expected: String, id: String, name: String, bytes: Vec<u8>, ) -> HomeworkUploadResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/homework.rs:206</sub>
- `pub(super) async fn submit_file( expected: String, handle: String, confirmed: bool, reconcile: bool, ) -> MutationResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/homework.rs:242</sub>
- `pub(super) async fn download_file( expected: String, id: String, attachment: String, ) -> HomeworkFileDownloadResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/homework.rs:273</sub>
- `pub(super) async fn configure_recovery(expected: String, root: String) -> HomeworkRecoveryResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/homework.rs:297</sub>
- `pub(super) async fn pending_submissions( expected: String, assignment: Option<String>, ) -> HomeworkPendingResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/homework.rs:311</sub>
- `pub(super) async fn capabilities(expected: String, id: String) -> HomeworkCapabilitiesResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/homework.rs:341</sub>

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
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/library.rs:366</sub>

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

## network_account

- `pub(super) async fn load(expected_account: String) -> NetworkAccountResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/network_account.rs:4</sub>

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
- `pub(super) enum SubmitOutcome<T>` — Distinguishes a lock-wait timeout before the write was ever sent from a
  <sub>enum · rust/crates/ginkgo_flutter_bridge/src/api/live/runtime.rs:189</sub>
- `pub(super) async fn with_module_submit<T, F, Fut>(module: ModuleAccess, body: F) -> SubmitOutcome<T> where` — Take the session read gate and a module write gate, then run a submitted
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/runtime.rs:199</sub>
- `pub(super) fn service() -> Result<&'static LiveService, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/runtime.rs:216</sub>

## session

- `pub(super) async fn login( account: String, password: String, captcha: Option<String>, remember: bool, ) -> SessionResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/session.rs:8</sub>
- `pub(super) async fn restore_session() -> SessionResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/session.rs:35</sub>
- `pub(super) async fn sign_out() -> SessionResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/session.rs:77</sub>
- `pub(super) async fn set_route(route: RouteChoice) -> SessionResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/session.rs:103</sub>
- `pub(super) async fn clear_cache() -> bool {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/session.rs:124</sub>
- `pub(super) fn verify_credential_storage(account: String, secret: String) -> bool {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/session.rs:137</sub>

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
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:490</sub>
- `pub(super) async fn load_library_books( query: String, page: i64, sort: String, descending: bool, ) -> BookPageResponse {…}` — Public OPAC search. Read-only, anonymous and bounded by the service.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:496</sub>
- `pub(super) async fn load_shuttle_timetable() -> ShuttleTimetableResponse {…}` — Published shuttle timetable. Public page, no identity, no ticketing.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:548</sub>
- `pub(super) async fn load_library_holdings(bib_id: String) -> BookHoldingsResponse {…}` — Public holdings for one bib id. The nested JSON string is decoded in Rust.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:600</sub>
- `pub(super) async fn export_learning_snapshots(expected: String) -> LearningSnapshotResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:633</sub>
- `pub(super) async fn import_learning_snapshots( expected: String, bytes: Vec<u8>, ) -> SnapshotImportResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:653</sub>
- `pub(super) async fn load_library_loans(expected: String, page: u32) -> LibraryLoansResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:678</sub>
- `pub(super) async fn check_android_update(current: String) -> UpdateResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:721</sub>

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
- `pub struct SavedCredentialResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:70</sub>
    - `account: Option<String>`  <sub>:71</sub>
    - `password: Option<String>`  <sub>:72</sub>
    - `failure: Option<FailureCode>`  <sub>:73</sub>
- `pub async fn load_saved_credential() -> SavedCredentialResponse {…}` — Reads the single saved credential from the platform secure vault on a
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:79</sub>
- `pub async fn last_verified_route() -> Option<RouteChoice> {…}` — Local observation only: never initialize a client or probe the school.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:105</sub>
- `pub async fn switch_verified_route( expected_account: String, route: RouteChoice, ) -> Option<FailureCode> {…}` — Explicit workspace action. Unlike login setup, never discards a valid session.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:115</sub>
- `pub struct BackgroundReminderRead`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:144</sub>
    - `account: Option<String>`  <sub>:145</sub>
    - `checkin: Option<CheckInResponse>`  <sub>:146</sub>
    - `homework: Option<super::mirror::HomeworkResponse>`  <sub>:147</sub>
    - `failure: Option<FailureCode>`  <sub>:148</sub>
- `pub async fn read_background_reminders( owner: String, checkin: bool, homework: bool, ) -> BackgroundReminderRead {…}` — Cookie-only reads; never calls the interactive/saved-password restore API.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:152</sub>
- `pub async fn sign_out() -> SessionResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:160</sub>
- `pub async fn set_route(route: RouteChoice) -> SessionResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:164</sub>
- `pub async fn clear_cache() -> bool {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:168</sub>
- `pub async fn load_classrooms(scope: LiveScope, query: ClassroomQuery) -> ClassroomResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:172</sub>
- `pub async fn load_schedule( term_id: Option<String>, week: Option<i32>, force_refresh: bool, ) -> ScheduleResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:176</sub>
- `pub async fn load_today(force_refresh: bool) -> TodayResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:184</sub>
- `pub async fn load_checkin_today(force_refresh: bool) -> CheckInResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:188</sub>
- `pub struct CheckinLoadProgressDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:192</sub>
    - `phase: String`  <sub>:193</sub>
    - `elapsed_ms: Option<i64>`  <sub>:194</sub>
- `pub struct CheckinLoadProgressResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:197</sub>
    - `data: Option<CheckinLoadProgressDto>`  <sub>:198</sub>
    - `failure: Option<FailureCode>`  <sub>:199</sub>
- `pub async fn checkin_load_progress() -> CheckinLoadProgressResponse {…}` — Observe the current read without issuing any school request.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:203</sub>
- `pub async fn load_checkin_on_date(date: String, force_refresh: bool) -> CheckInResponse {…}` — Historical day in Asia/Shanghai, yyyy-MM-dd; no sign-in submission.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:208</sub>
- `pub struct GradeTermsResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:212</sub>
    - `terms: Vec<ScheduleTerm>`  <sub>:213</sub>
    - `failure: Option<FailureCode>`  <sub>:214</sub>
    - `failure_detail: Option<String>`  <sub>:215</sub>
- `pub async fn load_grade_terms() -> GradeTermsResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:218</sub>
- `pub async fn load_grades(term_code: Option<String>, force_refresh: bool) -> GradeResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:222</sub>
- `pub fn verify_credential_storage(account: String, secret: String) -> bool {…}` — Device-acceptance diagnostic: write, read and delete one synthetic secret.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:228</sub>
- `pub async fn load_library_venues(force_refresh: bool) -> LibraryVenuesResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:232</sub>
- `pub async fn load_library_areas(library_id: String) -> LibraryAreasResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:236</sub>
- `pub async fn load_library_slots(area_id: String) -> LibrarySlotsResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:240</sub>
- `pub async fn load_library_seats( area_id: String, slot_id: String, day: String, start: String, end: String, ) -> LibrarySeatsResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:244</sub>
- `pub async fn load_library_bookings(force_refresh: bool) -> LibraryBookingsResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:254</sub>
- `pub struct LibraryHistoryResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:258</sub>
    - `bookings: Vec<super::mirror::LibraryBooking>`  <sub>:259</sub>
    - `page: i32`  <sub>:260</sub>
    - `page_size: i32`  <sub>:261</sub>
    - `total: Option<i32>`  <sub>:262</sub>
    - `has_next: bool`  <sub>:263</sub>
    - `fetched_at: Option<String>`  <sub>:264</sub>
    - `from_cache: bool`  <sub>:265</sub>
    - `stale: bool`  <sub>:266</sub>
    - `failure: Option<FailureCode>`  <sub>:267</sub>
    - `failure_detail: Option<String>`  <sub>:268</sub>
- `pub async fn load_library_history(page: i32, force_refresh: bool) -> LibraryHistoryResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:271</sub>
- `pub fn load_demo_library_history(page: i32) -> LibraryHistoryResponse {…}` — Synthetic page runs the same domain parser as live history.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:276</sub>
- `pub async fn load_homework(force_refresh: bool) -> super::mirror::HomeworkResponse {…}` — Real SPOC list, API.md §7.1. Demo remains an explicit separate command.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:281</sub>
- `pub struct HomeworkDetailResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:285</sub>
    - `source_url: Option<String>`  <sub>:286</sub>
    - `content: Option<String>`  <sub>:287</sub>
    - `published_at: Option<String>`  <sub>:288</sub>
    - `due_at: Option<String>`  <sub>:289</sub>
    - `score: Option<String>`  <sub>:290</sub>
    - `status: String`  <sub>:291</sub>
    - `submitted_at: Option<String>`  <sub>:292</sub>
    - `stale: bool`  <sub>:293</sub>
    - `failure: Option<FailureCode>`  <sub>:294</sub>
- `pub async fn load_homework_detail( assignment_id: String, force_refresh: bool, ) -> HomeworkDetailResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:297</sub>
- `pub struct BykcSemesterDto` — Sanitized domain JSON, never raw upstream data, credentials or tokens.
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:305</sub>
    - `id: String`  <sub>:306</sub>
    - `name: String`  <sub>:307</sub>
    - `start: Option<String>`  <sub>:308</sub>
    - `end: Option<String>`  <sub>:309</sub>
- `pub struct BykcCourseDetailsDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:312</sub>
    - `start: Option<String>`  <sub>:313</sub>
    - `end: Option<String>`  <sub>:314</sub>
    - `select_start: Option<String>`  <sub>:315</sub>
    - `select_end: Option<String>`  <sub>:316</sub>
    - `cancel_end: Option<String>`  <sub>:317</sub>
    - `capacity: Option<i64>`  <sub>:318</sub>
    - `enrolled: Option<i64>`  <sub>:319</sub>
    - `campuses: Vec<String>`  <sub>:320</sub>
    - `summary: Option<String>`  <sub>:321</sub>
    - `selected: Option<bool>`  <sub>:322</sub>
    - `has_sign_config: Option<bool>`  <sub>:323</sub>
- `pub struct BykcCourseDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:326</sub>
    - `id: i64`  <sub>:327</sub>
    - `name: String`  <sub>:328</sub>
    - `teacher: Option<String>`  <sub>:329</sub>
    - `position: Option<String>`  <sub>:330</sub>
    - `category: Option<String>`  <sub>:331</sub>
    - `subcategory: Option<String>`  <sub>:332</sub>
    - `details: Option<BykcCourseDetailsDto>`  <sub>:333</sub>
- `pub struct BykcCatalogDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:336</sub>
    - `terms: Vec<BykcSemesterDto>`  <sub>:337</sub>
    - `courses: Vec<BykcCourseDto>`  <sub>:338</sub>
    - `current_term: Option<BykcSemesterDto>` — Chosen by the shared Beijing semester policy, not by the device clock.  <sub>:340</sub>
- `pub struct BykcChosenRecordDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:343</sub>
    - `id: i64`  <sub>:344</sub>
    - `course: BykcCourseDto`  <sub>:345</sub>
    - `selected_at: Option<String>`  <sub>:346</sub>
    - `checkin: Option<i64>`  <sub>:347</sub>
    - `passed: Option<i64>`  <sub>:348</sub>
    - `score: Option<i64>`  <sub>:349</sub>
- `pub struct BykcChosenCoursesDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:352</sub>
    - `term: Option<BykcSemesterDto>`  <sub>:353</sub>
    - `courses: Option<Vec<BykcChosenRecordDto>>` — `None` means no valid semester range was available, not zero selections.  <sub>:355</sub>
- `pub struct BykcStatisticsEntryDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:358</sub>
    - `category: String`  <sub>:359</sub>
    - `subcategory: String`  <sub>:360</sub>
    - `required: i64`  <sub>:361</sub>
    - `completed: i64`  <sub>:362</sub>
- `pub struct BykcStatisticsDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:365</sub>
    - `valid_course_count: Option<i64>`  <sub>:366</sub>
    - `entries: Vec<BykcStatisticsEntryDto>`  <sub>:367</sub>
- `pub struct BykcCatalogResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:370</sub>
    - `data: Option<BykcCatalogDto>`  <sub>:371</sub>
    - `failure: Option<FailureCode>`  <sub>:372</sub>
- `pub struct BykcChosenResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:375</sub>
    - `data: Option<BykcChosenCoursesDto>`  <sub>:376</sub>
    - `failure: Option<FailureCode>`  <sub>:377</sub>
- `pub struct BykcStatisticsResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:380</sub>
    - `data: Option<BykcStatisticsDto>`  <sub>:381</sub>
    - `failure: Option<FailureCode>`  <sub>:382</sub>
- `pub async fn load_bykc(force_refresh: bool) -> BykcCatalogResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:385</sub>
- `pub fn load_demo_bykc() -> BykcCatalogResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:389</sub>
- `pub async fn load_bykc_chosen(force_refresh: bool) -> BykcChosenResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:393</sub>
- `pub async fn load_bykc_statistics(force_refresh: bool) -> BykcStatisticsResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:397</sub>
- `pub fn load_demo_bykc_chosen() -> BykcChosenResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:401</sub>
- `pub fn load_demo_bykc_statistics() -> BykcStatisticsResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:405</sub>
- `pub struct GraduateRowDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:409</sub>
    - `title: String`  <sub>:410</sub>
    - `detail: String`  <sub>:411</sub>
    - `is_course: bool` — Explicitly distinguishes a course with an unknown result from metadata.  <sub>:413</sub>
    - `completed: Option<bool>`  <sub>:414</sub>
    - `credit: Option<f64>`  <sub>:415</sub>
    - `semester: Option<String>`  <sub>:416</sub>
- `pub struct GraduateProgressDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:419</sub>
    - `required: Option<f64>`  <sub>:420</sub>
    - `earned: Option<f64>`  <sub>:421</sub>
    - `pending: Option<f64>`  <sub>:422</sub>
- `pub struct GraduateSectionDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:425</sub>
    - `title: String`  <sub>:426</sub>
    - `rows: Vec<GraduateRowDto>`  <sub>:427</sub>
    - `progress: Option<GraduateProgressDto>`  <sub>:428</sub>
- `pub struct AcademicDataDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:431</sub>
    - `sections: Vec<GraduateSectionDto>`  <sub>:432</sub>
    - `notice: Option<String>`  <sub>:433</sub>
- `pub struct GraduateResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:436</sub>
    - `data: Option<AcademicDataDto>`  <sub>:437</sub>
    - `failure: Option<FailureCode>`  <sub>:438</sub>
- `pub async fn load_graduate_part(report: bool, force_refresh: bool) -> GraduateResponse {…}` — Independently cached sections, allowing Flutter to render the first response
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:443</sub>
- `pub fn load_demo_graduate_status() -> GraduateResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:447</sub>
- `pub fn load_demo_graduate() -> GraduateResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:451</sub>
- `pub struct LocalTaskDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:455</sub>
    - `id: String`  <sub>:456</sub>
    - `title: String`  <sub>:457</sub>
    - `due: String` — Empty means no deadline; a calendar date stays a date.  <sub>:459</sub>
    - `completed: bool`  <sub>:460</sub>
    - `source_assignment_id: Option<String>` — Set only for a historical record linked to a school assignment.  <sub>:462</sub>
- `pub struct LocalTasksResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:465</sub>
    - `data: Option<Vec<LocalTaskDto>>`  <sub>:466</sub>
    - `failure: Option<FailureCode>`  <sub>:467</sub>
- `pub async fn edit_tasks( root: String, demo: bool, action: String, id: Option<String>, title: Option<String>, due: Option<String>, completed: Option<bool>, ) -> LocalTasksResponse {…}` — Local CRUD only. Account identity comes from Rust, never a Dart-supplied identifier.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:471</sub>
- `pub struct NoticeDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:483</sub>
    - `title: String`  <sub>:484</sub>
    - `summary: String`  <sub>:485</sub>
    - `published_at: String`  <sub>:486</sub>
    - `url: String`  <sub>:487</sub>
- `pub struct NoticesResponse` — A failure may accompany data only when it is a previous successful snapshot.
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:491</sub>
    - `data: Option<Vec<NoticeDto>>`  <sub>:492</sub>
    - `failure: Option<FailureCode>`  <sub>:493</sub>
- `pub async fn load_notices(force_refresh: bool) -> NoticesResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:496</sub>
- `pub struct CampusCardBalanceResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:500</sub>
    - `balance_minor: Option<i64>`  <sub>:501</sub>
    - `fetched_at: Option<String>`  <sub>:502</sub>
    - `failure: Option<FailureCode>`  <sub>:503</sub>
    - `failure_detail: Option<String>`  <sub>:504</sub>
- `pub async fn load_campus_card_balance() -> CampusCardBalanceResponse {…}` — Explicit, user-triggered campus-card balance read. No disk cache or bank data.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:508</sub>
- `pub fn load_demo_campus_card_balance() -> CampusCardBalanceResponse {…}` — Synthetic balance for the isolated demo workspace.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:513</sub>
- `pub fn load_demo_notices() -> NoticesResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:517</sub>
- `pub async fn load_career_events(month: String, force_refresh: bool) -> CareerEventsResponse {…}` — Public career-calendar events for a school month (YYYY-MM). Read-only.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:522</sub>
- `pub struct CareerEventDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:526</sub>
    - `id: String`  <sub>:527</sub>
    - `title: String`  <sub>:528</sub>
    - `campus: String`  <sub>:529</sub>
    - `place: String`  <sub>:530</sub>
    - `begins_at: String`  <sub>:531</sub>
    - `ends_at: String`  <sub>:532</sub>
    - `fair_type: String`  <sub>:533</sub>
    - `status: String`  <sub>:534</sub>
    - `url: String`  <sub>:535</sub>
- `pub struct CareerEventsDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:538</sub>
    - `month: String`  <sub>:539</sub>
    - `events: Vec<CareerEventDto>`  <sub>:540</sub>
    - `fetched_at: String`  <sub>:541</sub>
- `pub struct CareerEventsResponse` — A failure may accompany data only when it is a previous successful snapshot.
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:545</sub>
    - `data: Option<CareerEventsDto>`  <sub>:546</sub>
    - `failure: Option<FailureCode>`  <sub>:547</sub>
- `pub struct CampusActivityDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:550</sub>
    - `id: String`  <sub>:551</sub>
    - `title: String`  <sub>:552</sub>
    - `category: String`  <sub>:553</sub>
    - `published_at: String`  <sub>:554</sub>
    - `activity_time: String`  <sub>:555</sub>
    - `place: String`  <sub>:556</sub>
    - `url: String`  <sub>:557</sub>
- `pub struct CampusActivitiesDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:560</sub>
    - `page: i32`  <sub>:561</sub>
    - `activities: Vec<CampusActivityDto>`  <sub>:562</sub>
    - `fetched_at: String`  <sub>:563</sub>
- `pub struct CampusActivitiesResponse` — Published and displayed dates stay separate fields; neither is a deadline.
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:567</sub>
    - `data: Option<CampusActivitiesDto>`  <sub>:568</sub>
    - `failure: Option<FailureCode>`  <sub>:569</sub>
- `pub async fn load_campus_activities(page: i32, force_refresh: bool) -> CampusActivitiesResponse {…}` — Public campus cultural activities (page 1-based). Read-only.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:573</sub>
- `pub struct CgyySiteDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:577</sub>
    - `id: i64`  <sub>:578</sub>
    - `name: String`  <sub>:579</sub>
    - `venue: String`  <sub>:580</sub>
    - `campus: String`  <sub>:581</sub>
    - `seats: Option<i64>`  <sub>:582</sub>
    - `open_start: String`  <sub>:583</sub>
    - `open_end: String`  <sub>:584</sub>
- `pub struct CgyySlotDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:587</sub>
    - `time: String`  <sub>:588</sub>
    - `status: String`  <sub>:589</sub>
- `pub struct CgyySpaceDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:592</sub>
    - `name: String`  <sub>:593</sub>
    - `slots: Vec<CgyySlotDto>`  <sub>:594</sub>
- `pub struct CgyyDayDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:597</sub>
    - `site_id: i64`  <sub>:598</sub>
    - `date: String`  <sub>:599</sub>
    - `dates: Vec<String>`  <sub>:600</sub>
    - `spaces: Vec<CgyySpaceDto>`  <sub>:601</sub>
- `pub struct CgyyOrderDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:604</sub>
    - `order_status: Option<i64>`  <sub>:605</sub>
    - `check_status: Option<i64>`  <sub>:606</sub>
    - `can_cancel: bool`  <sub>:607</sub>
    - `id: i64`  <sub>:608</sub>
    - `place: String`  <sub>:609</sub>
    - `date: String`  <sub>:610</sub>
    - `time: String`  <sub>:611</sub>
    - `status: String`  <sub>:612</sub>
- `pub struct CgyyLockCodeDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:615</sub>
    - `qr_code: Option<String>`  <sub>:616</sub>
    - `due_date: Option<String>`  <sub>:617</sub>
    - `trade_no: Option<String>`  <sub>:618</sub>
    - `venue_name: Option<String>`  <sub>:619</sub>
    - `site_name: Option<String>`  <sub>:620</sub>
    - `space_name: Option<String>`  <sub>:621</sub>
    - `order_name: Option<String>`  <sub>:622</sub>
    - `reservation_date: Option<String>`  <sub>:623</sub>
    - `reservation_date_detail: Option<String>`  <sub>:624</sub>
    - `reservation_start_date: Option<String>`  <sub>:625</sub>
    - `reservation_end_date: Option<String>`  <sub>:626</sub>
- `pub struct CgyyLoadResponse` — Exactly one shape field is `Some`; the rest stay `None` so Dart can switch
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:631</sub>
    - `venues: Option<Vec<CgyySiteDto>>`  <sub>:632</sub>
    - `day: Option<CgyyDayDto>`  <sub>:633</sub>
    - `orders: Option<Vec<CgyyOrderDto>>`  <sub>:634</sub>
    - `order: Option<CgyyOrderDto>`  <sub>:635</sub>
    - `lock_code: Option<CgyyLockCodeDto>`  <sub>:636</sub>
    - `failure: Option<FailureCode>`  <sub>:637</sub>
- `pub struct CgyyBookingChoiceDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:640</sub>
    - `space_id: i64`  <sub>:641</sub>
    - `space_name: String`  <sub>:642</sub>
    - `time_id: i64`  <sub>:643</sub>
    - `time: String`  <sub>:644</sub>
- `pub struct CgyyPurposeDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:647</sub>
    - `id: i64`  <sub>:648</sub>
    - `name: String`  <sub>:649</sub>
- `pub struct CgyyBookingOptionsDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:652</sub>
    - `choices: Vec<CgyyBookingChoiceDto>`  <sub>:653</sub>
    - `purposes: Vec<CgyyPurposeDto>`  <sub>:654</sub>
    - `uses_fallback_purposes: bool`  <sub>:655</sub>
- `pub struct CgyyChallengeDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:658</sub>
    - `id: String`  <sub>:659</sub>
    - `background: String`  <sub>:660</sub>
    - `jigsaw: String`  <sub>:661</sub>
- `pub struct CgyyReviewDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:664</sub>
    - `id: String`  <sub>:665</sub>
    - `orders: Vec<CgyyOrderDto>`  <sub>:666</sub>
- `pub struct CgyyActionResultDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:669</sub>
    - `state: String`  <sub>:670</sub>
    - `message: String`  <sub>:671</sub>
    - `options: Option<CgyyBookingOptionsDto>`  <sub>:672</sub>
    - `challenge: Option<CgyyChallengeDto>`  <sub>:673</sub>
    - `review: Option<CgyyReviewDto>`  <sub>:674</sub>
- `pub struct CgyyActionResultResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:677</sub>
    - `data: Option<CgyyActionResultDto>`  <sub>:678</sub>
    - `failure: Option<FailureCode>`  <sub>:679</sub>
- `pub async fn load_cgyy( kind: String, site_id: i64, date: String, force_refresh: bool, ) -> CgyyLoadResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:682</sub>
- `pub async fn execute_cgyy(command: String) -> CgyyActionResultResponse {…}` — User-confirmed CGYY commands; payload contains no upstream credentials.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:692</sub>
- `pub fn load_demo_cgyy(kind: String) -> CgyyLoadResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:696</sub>
- `pub struct BookHitDto` — Public OPAC search (read-only, anonymous). Payload is the projected page.
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:701</sub>
    - `bib_id: String`  <sub>:702</sub>
    - `title: String`  <sub>:703</sub>
    - `author: String`  <sub>:704</sub>
    - `publisher: String`  <sub>:705</sub>
    - `year: String`  <sub>:706</sub>
    - `callno: String`  <sub>:707</sub>
    - `isbn: String`  <sub>:708</sub>
    - `items_available: Option<i64>` — Reported copy availability, or `None` when the source stays silent.  <sub>:710</sub>
    - `item_count: Option<i64>`  <sub>:711</sub>
- `pub struct BookPageDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:714</sub>
    - `page: i64`  <sub>:715</sub>
    - `page_size: i64`  <sub>:716</sub>
    - `total: i64`  <sub>:717</sub>
    - `actual_total: i64`  <sub>:718</sub>
    - `items: Vec<BookHitDto>`  <sub>:719</sub>
    - `has_more: bool` — True when the school reported more matches than this page returned.  <sub>:721</sub>
- `pub struct BookPageResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:724</sub>
    - `data: Option<BookPageDto>`  <sub>:725</sub>
    - `failure: Option<FailureCode>`  <sub>:726</sub>
- `pub async fn load_library_books( query: String, page: i64, sort: String, descending: bool, ) -> BookPageResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:729</sub>
- `pub struct ShuttleRunDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:738</sub>
    - `index: String`  <sub>:739</sub>
    - `time: String`  <sub>:740</sub>
    - `capacity: String`  <sub>:741</sub>
- `pub struct ShuttleSectionDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:744</sub>
    - `label: String`  <sub>:745</sub>
    - `left: Vec<ShuttleRunDto>`  <sub>:746</sub>
    - `right: Vec<ShuttleRunDto>`  <sub>:747</sub>
- `pub struct ShuttleTableDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:750</sub>
    - `left: String`  <sub>:751</sub>
    - `right: String`  <sub>:752</sub>
    - `sections: Vec<ShuttleSectionDto>`  <sub>:753</sub>
- `pub struct ShuttleTimetableDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:756</sub>
    - `tables: Vec<ShuttleTableDto>`  <sub>:757</sub>
    - `source: String`  <sub>:758</sub>
    - `live_source: String`  <sub>:759</sub>
- `pub struct ShuttleTimetableResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:762</sub>
    - `data: Option<ShuttleTimetableDto>`  <sub>:763</sub>
    - `failure: Option<FailureCode>`  <sub>:764</sub>
- `pub async fn load_shuttle_timetable() -> ShuttleTimetableResponse {…}` — Published shuttle timetable (official page). Read-only, no ticketing.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:768</sub>
- `pub struct BookHoldingDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:772</sub>
    - `call_no: String`  <sub>:773</sub>
    - `bar_code: String`  <sub>:774</sub>
    - `library: String`  <sub>:775</sub>
    - `location: String`  <sub>:776</sub>
    - `status: String` — The school's own status text; never a local available/unavailable flag.  <sub>:778</sub>
- `pub struct BookHoldingsResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:781</sub>
    - `data: Option<Vec<BookHoldingDto>>`  <sub>:782</sub>
    - `failure: Option<FailureCode>`  <sub>:783</sub>
- `pub async fn load_library_holdings(bib_id: String) -> BookHoldingsResponse {…}` — Public holdings for one bib id; the nested JSON string never crosses the bridge.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:787</sub>
- `pub struct LearningSnapshotResponse` — Transient archive bytes. Hosts must use explicitly opted-in encrypted storage.
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:792</sub>
    - `bytes: Option<Vec<u8>>`  <sub>:793</sub>
    - `failure: Option<FailureCode>`  <sub>:794</sub>
- `pub async fn export_learning_snapshots(expected_account: String) -> LearningSnapshotResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:796</sub>
- `pub async fn import_learning_snapshots( expected_account: String, bytes: Vec<u8>, ) -> SnapshotImportResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:799</sub>
- `pub fn library_loans_portal_url() -> String {…}` — Public website metadata only. Does not initialize an authenticated session.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:808</sub>
- `pub fn student_service_url(id: String) -> Option<String> {…}` — Public destination metadata; does not initialize an authenticated session.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:814</sub>
- `pub struct LibraryLoanDto` — Explicit private read, scoped to the caller's account. No disk cache or writes.
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:819</sub>
    - `id: String`  <sub>:820</sub>
    - `title: Option<String>`  <sub>:821</sub>
    - `author: Option<String>`  <sub>:822</sub>
    - `call_number: Option<String>`  <sub>:823</sub>
    - `borrowed_at: Option<String>`  <sub>:824</sub>
    - `due_at: Option<String>`  <sub>:825</sub>
- `pub struct LibraryLoanPageDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:828</sub>
    - `items: Vec<LibraryLoanDto>`  <sub>:829</sub>
    - `page: u32`  <sub>:830</sub>
    - `total: u32`  <sub>:831</sub>
    - `has_more: bool`  <sub>:832</sub>
- `pub struct LibraryLoansResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:835</sub>
    - `data: Option<LibraryLoanPageDto>`  <sub>:836</sub>
    - `failure: Option<FailureCode>`  <sub>:837</sub>
- `pub async fn load_library_loans(expected_account: String, page: u32) -> LibraryLoansResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:840</sub>
- `pub struct CountPairDto` — Public counts only. No school identity or library token is serialized.
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:845</sub>
    - `available: i32`  <sub>:846</sub>
    - `total: i32`  <sub>:847</sub>
- `pub struct ReadingRoomDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:850</sub>
    - `name: String`  <sub>:851</sub>
    - `people: i32`  <sub>:852</sub>
- `pub struct LibraryCampusStatsDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:855</sub>
    - `id: String`  <sub>:856</sub>
    - `name: String`  <sub>:857</sub>
    - `people: i32`  <sub>:858</sub>
    - `reading_rooms: Vec<ReadingRoomDto>`  <sub>:859</sub>
    - `seats: Option<CountPairDto>` — Absent means the school did not publish that resource, not zero.  <sub>:861</sub>
    - `study_rooms: Option<CountPairDto>`  <sub>:862</sub>
    - `lockers: Option<CountPairDto>`  <sub>:863</sub>
- `pub struct LibraryStatsDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:866</sub>
    - `campuses: Vec<LibraryCampusStatsDto>`  <sub>:867</sub>
    - `fetched_at: Option<String>`  <sub>:868</sub>
    - `from_cache: bool`  <sub>:869</sub>
- `pub struct LibraryStatsResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:872</sub>
    - `data: Option<LibraryStatsDto>`  <sub>:873</sub>
    - `failure: Option<FailureCode>`  <sub>:874</sub>
- `pub async fn load_library_stats(force_refresh: bool) -> LibraryStatsResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:877</sub>
- `pub fn load_demo_library_stats() -> LibraryStatsResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:880</sub>
- `pub struct AndroidDownloadDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:884</sub>
    - `version: String`  <sub>:885</sub>
    - `name: String`  <sub>:886</sub>
    - `url: String`  <sub>:887</sub>
    - `api_url: String`  <sub>:888</sub>
    - `size: i64` — Upstream only ever publishes a verified asset inside  <sub>:891</sub>
    - `sha256: String`  <sub>:892</sub>
- `pub struct UpdateSummaryDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:895</sub>
    - `current: String`  <sub>:896</sub>
    - `latest: Option<String>`  <sub>:897</sub>
    - `available: bool`  <sub>:898</sub>
    - `page_url: Option<String>`  <sub>:899</sub>
    - `notes: Option<String>`  <sub>:900</sub>
    - `apk_available: bool`  <sub>:901</sub>
    - `download: Option<AndroidDownloadDto>`  <sub>:902</sub>
- `pub struct UpdateResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:905</sub>
    - `data: Option<UpdateSummaryDto>`  <sub>:906</sub>
    - `failure: Option<FailureCode>`  <sub>:907</sub>
- `pub async fn check_android_update(current: String) -> UpdateResponse {…}` — Deliberately independent from login, school routes and account caches.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:911</sub>
- `pub struct MutationResponse` — User-confirmed write. Never retries the mutation and never exposes raw upstream text.
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:916</sub>
    - `state: String`  <sub>:917</sub>
    - `message: String`  <sub>:918</sub>
- `pub async fn prepare_checkin_qr( course_id: String, revalidate_course: bool, offset_ms: u32, ) -> CheckInQrResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:921</sub>
- `pub async fn reserve_library_seat( area_id: String, seat_id: String, slot: crate::api::mirror::LibrarySlot, ) -> MutationResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:929</sub>
- `pub async fn perform_library_action(booking_id: String, action: String) -> MutationResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:936</sub>
- `pub struct HomeworkAttachmentDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:995</sub>
    - `id: String`  <sub>:996</sub>
    - `name: String`  <sub>:997</sub>
    - `kind: String`  <sub>:998</sub>
- `pub struct HomeworkWorkspaceDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1001</sub>
    - `assignment_id: String`  <sub>:1002</sub>
    - `allowed_methods: Vec<String>`  <sub>:1003</sub>
    - `allowed_extensions: Vec<String>`  <sub>:1004</sub>
    - `submission_limit: Option<u32>`  <sub>:1005</sub>
    - `submitted_count: Option<u32>`  <sub>:1006</sub>
    - `returned: bool`  <sub>:1007</sub>
    - `submitted_text: Option<String>`  <sub>:1008</sub>
    - `feedback: Option<String>`  <sub>:1009</sub>
    - `attachments: Vec<HomeworkAttachmentDto>`  <sub>:1010</sub>
    - `can_submit_file: bool`  <sub>:1011</sub>
    - `blocked_reason: Option<String>`  <sub>:1012</sub>
    - `file_limit_bytes: i64` — Widened from `u64`; the 20 MB upload cap keeps this lossless.  <sub>:1014</sub>
- `pub struct HomeworkFileWorkspaceResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1017</sub>
    - `data: Option<HomeworkWorkspaceDto>`  <sub>:1018</sub>
    - `failure: Option<FailureCode>`  <sub>:1019</sub>
- `pub struct HomeworkUploadReceiptDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1022</sub>
    - `handle: String`  <sub>:1023</sub>
    - `file_name: String`  <sub>:1024</sub>
    - `size: i64` — Widened from `u64`; the 20 MB upload cap keeps this lossless.  <sub>:1026</sub>
- `pub struct HomeworkUploadResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1029</sub>
    - `data: Option<HomeworkUploadReceiptDto>`  <sub>:1030</sub>
    - `failure: Option<FailureCode>`  <sub>:1031</sub>
- `pub async fn homework_file_workspace( expected_account: String, assignment_id: String, ) -> HomeworkFileWorkspaceResponse {…}` — Homework business JSON only; raw SPOC payloads never leave upstream.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1035</sub>
- `pub async fn upload_homework_file( expected_account: String, assignment_id: String, name: String, bytes: Vec<u8>, ) -> HomeworkUploadResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1041</sub>
- `pub async fn submit_homework_file( expected_account: String, handle: String, confirmed: bool, ) -> MutationResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1049</sub>
- `pub async fn reconcile_homework_file(expected_account: String, handle: String) -> MutationResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1056</sub>
- `pub struct HomeworkFileDownloadResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1059</sub>
    - `name: Option<String>`  <sub>:1060</sub>
    - `bytes: Option<Vec<u8>>`  <sub>:1061</sub>
    - `failure: Option<FailureCode>`  <sub>:1062</sub>
- `pub async fn download_homework_file( expected_account: String, assignment_id: String, attachment_id: String, ) -> HomeworkFileDownloadResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1064</sub>
- `pub struct LearningCourseDto` — Learning queries return business DTO JSON, never school response envelopes.
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1073</sub>
    - `id: String`  <sub>:1074</sub>
    - `name: String`  <sub>:1075</sub>
    - `teacher: Option<String>`  <sub>:1076</sub>
    - `term: Option<String>`  <sub>:1077</sub>
    - `source_url: String`  <sub>:1078</sub>
- `pub struct LearningCoursesResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1081</sub>
    - `data: Option<Vec<LearningCourseDto>>`  <sub>:1082</sub>
    - `failure: Option<FailureCode>`  <sub>:1083</sub>
- `pub struct CourseAnnouncementDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1086</sub>
    - `id: String`  <sub>:1087</sub>
    - `title: String`  <sub>:1088</sub>
    - `published_at: Option<String>`  <sub>:1089</sub>
- `pub struct CourseAnnouncementsResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1092</sub>
    - `data: Option<Vec<CourseAnnouncementDto>>`  <sub>:1093</sub>
    - `failure: Option<FailureCode>`  <sub>:1094</sub>
- `pub struct LearningAttachmentDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1097</sub>
    - `id: String`  <sub>:1098</sub>
    - `name: String`  <sub>:1099</sub>
- `pub struct CourseAnnouncementDetailDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1102</sub>
    - `id: String`  <sub>:1103</sub>
    - `title: String`  <sub>:1104</sub>
    - `content: Option<String>`  <sub>:1105</sub>
    - `attachments: Vec<LearningAttachmentDto>`  <sub>:1106</sub>
- `pub struct CourseAnnouncementDetailResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1109</sub>
    - `data: Option<CourseAnnouncementDetailDto>`  <sub>:1110</sub>
    - `failure: Option<FailureCode>`  <sub>:1111</sub>
- `pub struct CourseResourceDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1114</sub>
    - `id: String`  <sub>:1115</sub>
    - `name: String`  <sub>:1116</sub>
    - `folder: bool`  <sub>:1117</sub>
    - `downloadable: bool`  <sub>:1118</sub>
    - `updated_at: Option<String>`  <sub>:1119</sub>
    - `extension: Option<String>`  <sub>:1120</sub>
- `pub struct CourseResourcePageDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1123</sub>
    - `items: Vec<CourseResourceDto>`  <sub>:1124</sub>
    - `page: u32`  <sub>:1125</sub>
    - `has_next: bool`  <sub>:1126</sub>
- `pub struct CourseResourcePageResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1129</sub>
    - `data: Option<CourseResourcePageDto>`  <sub>:1130</sub>
    - `failure: Option<FailureCode>`  <sub>:1131</sub>
- `pub struct CourseAssessmentDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1134</sub>
    - `id: String`  <sub>:1135</sub>
    - `title: String`  <sub>:1136</sub>
    - `starts_at: Option<String>`  <sub>:1137</sub>
    - `due_at: Option<String>`  <sub>:1138</sub>
    - `score: Option<String>`  <sub>:1139</sub>
    - `source_url: String`  <sub>:1140</sub>
- `pub struct CourseAssessmentsResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1143</sub>
    - `data: Option<Vec<CourseAssessmentDto>>`  <sub>:1144</sub>
    - `failure: Option<FailureCode>`  <sub>:1145</sub>
- `pub enum LearningColumnKindDto`
  <sub>enum · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1148</sub>
- `pub struct LearningColumnDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1153</sub>
    - `id: String`  <sub>:1154</sub>
    - `name: String`  <sub>:1155</sub>
    - `kind: LearningColumnKindDto`  <sub>:1156</sub>
- `pub struct LearningColumnsResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1159</sub>
    - `data: Option<Vec<LearningColumnDto>>`  <sub>:1160</sub>
    - `failure: Option<FailureCode>`  <sub>:1161</sub>
- `pub enum LearningCapabilityStateDto`
  <sub>enum · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1164</sub>
- `pub struct LearningCapabilitiesDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1173</sub>
    - `columns: LearningCapabilityStateDto`  <sub>:1174</sub>
    - `announcements: LearningCapabilityStateDto`  <sub>:1175</sub>
    - `resources: LearningCapabilityStateDto`  <sub>:1176</sub>
    - `assessments: LearningCapabilityStateDto`  <sub>:1177</sub>
    - `resource_download: LearningCapabilityStateDto`  <sub>:1178</sub>
    - `announcement_download: LearningCapabilityStateDto`  <sub>:1179</sub>
- `pub struct LearningCapabilitiesResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1182</sub>
    - `data: Option<LearningCapabilitiesDto>`  <sub>:1183</sub>
    - `failure: Option<FailureCode>`  <sub>:1184</sub>
- `pub struct SnapshotImportResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1187</sub>
    - `imported: Option<u32>` — Count of snapshots actually merged, not the number offered.  <sub>:1189</sub>
    - `failure: Option<FailureCode>`  <sub>:1190</sub>
- `pub async fn learning_courses(expected_account: String, force: bool) -> LearningCoursesResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1193</sub>
- `pub async fn course_announcements( expected_account: String, course: String, force: bool, ) -> CourseAnnouncementsResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1196</sub>
- `pub async fn course_announcement_detail( expected_account: String, course: String, id: String, ) -> CourseAnnouncementDetailResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1203</sub>
- `pub async fn course_resources( expected_account: String, course: String, folder: Option<String>, page: u32, force: bool, ) -> CourseResourcePageResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1210</sub>
- `pub async fn course_assessments( expected_account: String, course: String, force: bool, ) -> CourseAssessmentsResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1219</sub>
- `pub async fn course_resource_download( expected_account: String, course: String, folder: Option<String>, page: u32, id: String, ) -> HomeworkFileDownloadResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1226</sub>
- `pub async fn course_announcement_attachment( expected_account: String, course: String, id: String, file: String, ) -> HomeworkFileDownloadResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1235</sub>
- `pub async fn course_learning_columns( expected_account: String, course: String, force: bool, ) -> LearningColumnsResponse {…}` — Explicit module context; all identifiers are revalidated by the source.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1248</sub>
- `pub async fn course_learning_capabilities( expected_account: String, course: String, ) -> LearningCapabilitiesResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1255</sub>
- `pub async fn course_announcements_in( expected_account: String, course: String, column: String, force: bool, ) -> CourseAnnouncementsResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1261</sub>
- `pub async fn course_assessments_in( expected_account: String, course: String, column: String, force: bool, ) -> CourseAssessmentsResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1269</sub>
- `pub async fn course_announcement_detail_in( expected_account: String, course: String, column: String, id: String, ) -> CourseAnnouncementDetailResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1277</sub>
- `pub async fn course_announcement_attachment_in( expected_account: String, course: String, column: String, id: String, file: String, ) -> HomeworkFileDownloadResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1285</sub>
- `pub async fn course_resources_at( expected_account: String, course: String, path: Vec<String>, page: u32, force: bool, ) -> CourseResourcePageResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1294</sub>
- `pub async fn course_resource_download_at( expected_account: String, course: String, path: Vec<String>, page: u32, id: String, ) -> HomeworkFileDownloadResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1303</sub>
- `pub enum GraduateCreditStateDto`
  <sub>enum · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1312</sub>
- `pub struct GraduateCreditMetricsDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1319</sub>
    - `state: GraduateCreditStateDto`  <sub>:1320</sub>
    - `required: Option<f64>`  <sub>:1321</sub>
    - `earned: Option<f64>`  <sub>:1322</sub>
    - `pending: Option<f64>`  <sub>:1323</sub>
    - `remaining: Option<f64>` — Derived only from this node's official requirement and earned credits.  <sub>:1325</sub>
    - `ratio: Option<f64>`  <sub>:1326</sub>
- `pub struct GraduateCreditRowDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1329</sub>
    - `title: String`  <sub>:1330</sub>
    - `detail: String`  <sub>:1331</sub>
    - `is_course: bool`  <sub>:1332</sub>
    - `completed: Option<bool>`  <sub>:1333</sub>
    - `credit: Option<f64>`  <sub>:1334</sub>
    - `semester: Option<String>`  <sub>:1335</sub>
- `pub struct GraduateCreditNodeDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1338</sub>
    - `source_index: u32` — Source ordinal, not an inferred category/group relationship.  <sub>:1340</sub>
    - `title: String`  <sub>:1341</sub>
    - `progress: Option<GraduateCreditMetricsDto>`  <sub>:1342</sub>
    - `rows: Vec<GraduateCreditRowDto>`  <sub>:1343</sub>
- `pub struct GraduateCreditMapDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1346</sub>
    - `summary: Option<GraduateCreditNodeDto>`  <sub>:1347</sub>
    - `nodes: Vec<GraduateCreditNodeDto>`  <sub>:1348</sub>
    - `notice: Option<String>`  <sub>:1349</sub>
- `pub struct GraduateCreditMapResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1352</sub>
    - `data: Option<GraduateCreditMapDto>`  <sub>:1353</sub>
    - `failure: Option<FailureCode>`  <sub>:1354</sub>
- `pub async fn load_graduate_credit_map( expected_account: String, force_refresh: bool, ) -> GraduateCreditMapResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1357</sub>
- `pub struct HomeworkPendingSubmissionDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1363</sub>
    - `handle: String`  <sub>:1364</sub>
    - `assignment_id: String`  <sub>:1365</sub>
    - `file_name: String`  <sub>:1366</sub>
    - `size: i64` — Widened from `u64`; the 20 MB upload cap keeps this lossless.  <sub>:1368</sub>
- `pub struct HomeworkPendingResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1371</sub>
    - `data: Option<Vec<HomeworkPendingSubmissionDto>>`  <sub>:1372</sub>
    - `failure: Option<FailureCode>`  <sub>:1373</sub>
- `pub enum HomeworkCapabilityStateDto`
  <sub>enum · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1376</sub>
- `pub struct HomeworkCapabilityEvidenceDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1385</sub>
    - `capability: String`  <sub>:1386</sub>
    - `state: HomeworkCapabilityStateDto`  <sub>:1387</sub>
    - `reason: String`  <sub>:1388</sub>
    - `evidence: String`  <sub>:1389</sub>
- `pub struct HomeworkCapabilitiesResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1392</sub>
    - `data: Option<Vec<HomeworkCapabilityEvidenceDto>>`  <sub>:1393</sub>
    - `failure: Option<FailureCode>`  <sub>:1394</sub>
- `pub struct HomeworkRecoveryResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1397</sub>
    - `configured: Option<bool>` — `Some(true)` only after the store accepted the private directory.  <sub>:1399</sub>
    - `failure: Option<FailureCode>`  <sub>:1400</sub>
- `pub async fn configure_homework_recovery( expected_account: String, storage_root: String, ) -> HomeworkRecoveryResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1403</sub>
- `pub async fn pending_homework_submissions( expected_account: String, assignment_id: Option<String>, ) -> HomeworkPendingResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1409</sub>
- `pub async fn homework_capabilities( expected_account: String, assignment_id: String, ) -> HomeworkCapabilitiesResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1415</sub>
- `pub struct FinanceIncomeEntryDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1422</sub>
    - `id: String`  <sub>:1423</sub>
    - `project: Option<String>`  <sub>:1424</sub>
    - `description: Option<String>`  <sub>:1425</sub>
    - `gross_minor: Option<i64>`  <sub>:1426</sub>
    - `tax_minor: Option<i64>`  <sub>:1427</sub>
    - `net_minor: Option<i64>`  <sub>:1428</sub>
    - `tax_rate: Option<String>`  <sub>:1429</sub>
    - `recorded_date: Option<String>`  <sub>:1430</sub>
    - `year: Option<String>`  <sub>:1431</sub>
    - `month: Option<String>`  <sub>:1432</sub>
- `pub struct FinanceIncomeReportDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1435</sub>
    - `entries: Vec<FinanceIncomeEntryDto>`  <sub>:1436</sub>
    - `total: u32`  <sub>:1437</sub>
    - `fetched_at: String`  <sub>:1438</sub>
- `pub struct FinanceIncomeResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1441</sub>
    - `data: Option<FinanceIncomeReportDto>`  <sub>:1442</sub>
    - `failure: Option<FailureCode>`  <sub>:1443</sub>
- `pub async fn load_finance_incomes(expected_account: String) -> FinanceIncomeResponse {…}` — Explicit on-demand student finance income read. No disk cache or bank numbers.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1447</sub>
- `pub struct PortalMetricDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1451</sub>
    - `value: String`  <sub>:1452</sub>
    - `unit: Option<String>`  <sub>:1453</sub>
- `pub struct NetworkTrafficProductDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1456</sub>
    - `product_name: Option<String>`  <sub>:1457</sub>
    - `used_text: String`  <sub>:1458</sub>
    - `free_remaining_text: String`  <sub>:1459</sub>
    - `paid_remaining_text: String`  <sub>:1460</sub>
    - `package_count: u32`  <sub>:1461</sub>
- `pub struct NetworkAccountDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1464</sub>
    - `net_fee_minor: Option<i64>`  <sub>:1465</sub>
    - `net_fee_failure: Option<FailureCode>`  <sub>:1466</sub>
    - `unreturned_books: Option<PortalMetricDto>`  <sub>:1467</sub>
    - `unread_mail: Option<PortalMetricDto>`  <sub>:1468</sub>
    - `cloud_drive_free: Option<PortalMetricDto>`  <sub>:1469</sub>
    - `portal_failure: Option<FailureCode>`  <sub>:1470</sub>
    - `traffic_products: Vec<NetworkTrafficProductDto>`  <sub>:1471</sub>
    - `traffic_failure: Option<FailureCode>`  <sub>:1472</sub>
    - `fetched_at: String`  <sub>:1473</sub>
- `pub struct NetworkAccountResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1476</sub>
    - `data: Option<NetworkAccountDto>`  <sub>:1477</sub>
    - `failure: Option<FailureCode>`  <sub>:1478</sub>
- `pub async fn load_network_account(expected_account: String) -> NetworkAccountResponse {…}` — Explicit on-demand portal metrics & campus network traffic read. No recharge writes.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1482</sub>
- `pub enum EvaluationCourseStatusDto`
  <sub>enum · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1486</sub>
- `pub struct EvaluationCourseDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1492</sub>
    - `id: String`  <sub>:1493</sub>
    - `course_name: String`  <sub>:1494</sub>
    - `teacher_name: Option<String>`  <sub>:1495</sub>
    - `questionnaire_name: Option<String>`  <sub>:1496</sub>
    - `category: Option<String>`  <sub>:1497</sub>
    - `status: EvaluationCourseStatusDto`  <sub>:1498</sub>
- `pub struct TeachingEvaluationDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1501</sub>
    - `task_id: Option<String>`  <sub>:1502</sub>
    - `task_name: Option<String>`  <sub>:1503</sub>
    - `term: Option<String>`  <sub>:1504</sub>
    - `courses: Vec<EvaluationCourseDto>`  <sub>:1505</sub>
    - `fetched_at: String`  <sub>:1506</sub>
    - `from_cache: bool`  <sub>:1507</sub>
    - `stale: bool`  <sub>:1508</sub>
- `pub struct TeachingEvaluationResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1511</sub>
    - `data: Option<TeachingEvaluationDto>`  <sub>:1512</sub>
    - `failure: Option<FailureCode>`  <sub>:1513</sub>
- `pub async fn load_teaching_evaluation( expected_account: String, force_refresh: bool, ) -> TeachingEvaluationResponse {…}` — Read-only teaching evaluation status check. Never submits evaluations.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:1517</sub>

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
- `pub(super) fn load_demo_checkin_qr(course_id: &str) -> CheckInQrResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror/academic.rs:264</sub>

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
- `pub struct CheckInQrResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:327</sub>
    - `course_id: String`  <sub>:328</sub>
    - `fetched_at: Option<String>`  <sub>:329</sub>
    - `refresh_seconds: i32`  <sub>:330</sub>
    - `matrix_size: i32`  <sub>:331</sub>
    - `modules: Vec<bool>`  <sub>:332</sub>
    - `demo: bool`  <sub>:333</sub>
    - `failure: Option<FailureCode>`  <sub>:334</sub>
    - `failure_detail: Option<String>`  <sub>:335</sub>
- `pub fn load_demo_checkin() -> CheckInResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:338</sub>
- `pub fn load_demo_checkin_qr(course_id: String) -> CheckInQrResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:342</sub>
- `pub struct LibraryVenue`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:346</sub>
    - `id: String`  <sub>:347</sub>
    - `name: String`  <sub>:348</sub>
    - `free: i32`  <sub>:349</sub>
    - `total: i32`  <sub>:350</sub>
- `pub struct LibraryArea`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:353</sub>
    - `id: String`  <sub>:354</sub>
    - `name: String`  <sub>:355</sub>
    - `free: i32`  <sub>:356</sub>
    - `total: i32`  <sub>:357</sub>
- `pub struct LibrarySlot`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:360</sub>
    - `id: String`  <sub>:361</sub>
    - `day: String`  <sub>:362</sub>
    - `start: String`  <sub>:363</sub>
    - `end: String`  <sub>:364</sub>
- `pub struct LibrarySeat`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:367</sub>
    - `id: String`  <sub>:368</sub>
    - `name: String`  <sub>:369</sub>
    - `status_name: String`  <sub>:370</sub>
    - `available: bool`  <sub>:371</sub>
- `pub struct LibraryBooking`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:374</sub>
    - `id: String`  <sub>:375</sub>
    - `title: String`  <sub>:376</sub>
    - `area_name: String`  <sub>:377</sub>
    - `seat_number: String`  <sub>:378</sub>
    - `day: String`  <sub>:379</sub>
    - `start_time: String`  <sub>:380</sub>
    - `end_time: String`  <sub>:381</sub>
    - `status_name: String`  <sub>:382</sub>
    - `actions: Option<Vec<String>>`  <sub>:383</sub>
- `pub struct LibraryVenuesResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:386</sub>
    - `venues: Vec<LibraryVenue>`  <sub>:387</sub>
    - `fetched_at: Option<String>`  <sub>:388</sub>
    - `from_cache: bool`  <sub>:389</sub>
    - `stale: bool`  <sub>:390</sub>
    - `failure: Option<FailureCode>`  <sub>:391</sub>
    - `failure_detail: Option<String>`  <sub>:392</sub>
- `pub struct LibraryAreasResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:395</sub>
    - `areas: Vec<LibraryArea>`  <sub>:396</sub>
    - `failure: Option<FailureCode>`  <sub>:397</sub>
    - `failure_detail: Option<String>`  <sub>:398</sub>
- `pub struct LibrarySlotsResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:401</sub>
    - `slots: Vec<LibrarySlot>`  <sub>:402</sub>
    - `failure: Option<FailureCode>`  <sub>:403</sub>
    - `failure_detail: Option<String>`  <sub>:404</sub>
- `pub struct LibrarySeatsResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:407</sub>
    - `seats: Vec<LibrarySeat>`  <sub>:408</sub>
    - `failure: Option<FailureCode>`  <sub>:409</sub>
    - `failure_detail: Option<String>`  <sub>:410</sub>
- `pub struct LibraryBookingsResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:413</sub>
    - `bookings: Vec<LibraryBooking>`  <sub>:414</sub>
    - `fetched_at: Option<String>`  <sub>:415</sub>
    - `from_cache: bool`  <sub>:416</sub>
    - `stale: bool`  <sub>:417</sub>
    - `failure: Option<FailureCode>`  <sub>:418</sub>
    - `failure_detail: Option<String>`  <sub>:419</sub>
- `pub struct LibraryDemoResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:422</sub>
    - `venues: Vec<LibraryVenue>`  <sub>:423</sub>
    - `areas: Vec<LibraryArea>`  <sub>:424</sub>
    - `slots: Vec<LibrarySlot>`  <sub>:425</sub>
    - `seats: Vec<LibrarySeat>`  <sub>:426</sub>
    - `bookings: Vec<LibraryBooking>`  <sub>:427</sub>
- `pub(super) fn library_venue(value: ginkgo_core::features::library::LibraryVenue) -> LibraryVenue {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:430</sub>
- `pub(super) fn library_area(value: ginkgo_core::features::library::LibraryArea) -> LibraryArea {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:439</sub>
- `pub(super) fn library_slot(value: ginkgo_core::features::library::LibrarySlot) -> LibrarySlot {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:448</sub>
- `pub(super) fn library_seat(value: ginkgo_core::features::library::LibrarySeat) -> LibrarySeat {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:457</sub>
- `pub(super) fn library_booking( value: ginkgo_core::features::library::LibraryBooking, ) -> LibraryBooking {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:466</sub>
- `pub fn load_demo_library() -> LibraryDemoResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:483</sub>

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
