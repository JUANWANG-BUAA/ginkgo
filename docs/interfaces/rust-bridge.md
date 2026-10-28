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
- [mapping](#mapping) (17)
- [runtime](#runtime) (17)
- [session](#session) (6)
- [utilities](#utilities) (17)
- [live](#live) (95)
- [academic](#academic) (6)
- [classroom](#classroom) (3)
- [library](#library) (1)
- [mirror](#mirror) (53)
- [reminder_planning](#reminderplanning) (5)

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

- `pub(super) async fn load_bykc(force_refresh: bool) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/bykc.rs:4</sub>
- `pub(super) fn load_demo_bykc() -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/bykc.rs:18</sub>
- `pub(super) async fn load_bykc_chosen(force_refresh: bool) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/bykc.rs:25</sub>
- `pub(super) async fn load_bykc_statistics(force_refresh: bool) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/bykc.rs:33</sub>
- `pub(super) fn load_demo_bykc_chosen() -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/bykc.rs:41</sub>
- `pub(super) fn load_demo_bykc_statistics() -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/bykc.rs:45</sub>

## checkin

- `pub(super) async fn checkin_load_progress() -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/checkin.rs:4</sub>
- `pub(super) async fn load_checkin_on_date(date: String, force_refresh: bool) -> CheckInResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/checkin.rs:19</sub>
- `pub(super) async fn submit_checkin(course_id: String) -> MutationResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/checkin.rs:35</sub>

## classroom

- `pub(super) async fn load_classrooms(scope: LiveScope, query: ClassroomQuery) -> ClassroomResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/classroom.rs:4</sub>

## graduate

- `pub(super) async fn load_graduate_part(report: bool, force_refresh: bool) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/graduate.rs:4</sub>
- `pub(super) fn load_demo_graduate_status() -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/graduate.rs:25</sub>
- `pub(super) fn load_demo_graduate() -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/graduate.rs:29</sub>
- `pub(super) async fn credit_map(expected: String, force: bool) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/graduate.rs:33</sub>

## homework

- `pub(super) async fn load_homework(force_refresh: bool) -> crate::api::mirror::HomeworkResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/homework.rs:4</sub>
- `pub(super) async fn load_homework_detail( assignment_id: String, force_refresh: bool, ) -> HomeworkDetailResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/homework.rs:59</sub>
- `pub(super) async fn file_workspace(expected: String, id: String) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/homework.rs:121</sub>
- `pub(super) async fn upload_file( expected: String, id: String, name: String, bytes: Vec<u8>, ) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/homework.rs:130</sub>
- `pub(super) async fn submit_file( expected: String, handle: String, confirmed: bool, reconcile: bool, ) -> MutationResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/homework.rs:146</sub>
- `pub(super) async fn download_file( expected: String, id: String, attachment: String, ) -> HomeworkFileDownloadResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/homework.rs:177</sub>
- `pub(super) async fn configure_recovery(expected: String, root: String) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/homework.rs:201</sub>
- `pub(super) async fn pending_submissions( expected: String, assignment: Option<String>, ) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/homework.rs:211</sub>
- `pub(super) async fn capabilities(expected: String, id: String) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/homework.rs:227</sub>

## learning

- `pub(super) async fn courses(expected: String, force: bool) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/learning.rs:31</sub>
- `pub(super) async fn announcements( expected: String, course: String, force: bool, ) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/learning.rs:34</sub>
- `pub(super) async fn resources( expected: String, course: String, folder: Option<String>, page: u32, force: bool, ) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/learning.rs:46</sub>
- `pub(super) async fn assessments(expected: String, course: String, force: bool) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/learning.rs:62</sub>
- `pub(super) async fn announcement_detail( expected: String, course: String, id: String, ) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/learning.rs:68</sub>
- `pub(super) async fn resource_download( expected: String, course: String, folder: Option<String>, page: u32, id: String, ) -> HomeworkFileDownloadResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/learning.rs:101</sub>
- `pub(super) async fn announcement_attachment( expected: String, course: String, id: String, file: String, ) -> HomeworkFileDownloadResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/learning.rs:117</sub>
- `pub(super) async fn columns(expected: String, course: String, force: bool) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/learning.rs:137</sub>
- `pub(super) async fn capabilities(expected: String, course: String) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/learning.rs:150</sub>
- `pub(super) async fn announcements_in( expected: String, course: String, column: String, force: bool, ) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/learning.rs:167</sub>
- `pub(super) async fn assessments_in( expected: String, course: String, column: String, force: bool, ) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/learning.rs:185</sub>
- `pub(super) async fn detail_in( expected: String, course: String, column: String, id: String, ) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/learning.rs:203</sub>
- `pub(super) async fn attachment_in( expected: String, course: String, column: String, id: String, file: String, ) -> HomeworkFileDownloadResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/learning.rs:222</sub>
- `pub(super) async fn resources_at( expected: String, course: String, path: Vec<String>, page: u32, force: bool, ) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/learning.rs:238</sub>
- `pub(super) async fn download_at( expected: String, course: String, path: Vec<String>, page: u32, id: String, ) -> HomeworkFileDownloadResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/learning.rs:257</sub>

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
- `pub(super) async fn load_library_stats(force_refresh: bool) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/library.rs:257</sub>
- `pub(super) fn load_demo_library_stats() -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/library.rs:278</sub>
- `pub(super) async fn reserve_library_seat( area_id: String, seat_id: String, slot: crate::api::mirror::LibrarySlot, ) -> MutationResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/library.rs:297</sub>
- `pub(super) async fn perform_library_action(booking_id: String, action: String) -> MutationResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/library.rs:335</sub>

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
- `pub(super) fn read_only_response<T: serde::Serialize>( result: Result<ginkgo_core::application::DataOutcome<T>, AppError>, ) -> ReadOnlyResponse {…}` — Serialization failures are typed failures, never an empty successful response.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/mapping.rs:352</sub>
- `pub(super) fn read_only_value<T: serde::Serialize>( result: Result<T, AppError>, ) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/mapping.rs:370</sub>

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
- `pub(super) static SERVICE: OnceLock<Result<LiveService, AppError>> = OnceLock::new();`
  <sub>static · rust/crates/ginkgo_flutter_bridge/src/api/live/runtime.rs:17</sub>
- `pub(super) enum ModuleAccess` — The business module a command belongs to.
  <sub>enum · rust/crates/ginkgo_flutter_bridge/src/api/live/runtime.rs:30</sub>
- `pub(super) async fn bounded_read<T>( future: impl std::future::Future<Output = Result<T, AppError>>, ) -> Result<T, AppError> {…}` — Total budget for a read including SSO redirects and fallback. Mutations
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/runtime.rs:85</sub>
- `pub(super) async fn bounded_session<T>( future: impl std::future::Future<Output = Result<T, AppError>>, ) -> Result<T, AppError> {…}` — Budget for session commands (sign-in/restore). The CAS chain alone can
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/runtime.rs:98</sub>
- `pub(super) async fn bounded_submit<T>(future: impl std::future::Future<Output = T>) -> Option<T> {…}` — Budget for a school write. A timed-out write is dropped, never retried:
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/runtime.rs:110</sub>
- `pub(super) async fn with_session_read<T, F, Fut>(body: F) -> Result<T, AppError> where` — Take the session read gate and run a read under the read budget.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/runtime.rs:121</sub>
- `pub(super) async fn with_session_read_in<T, F, Fut>( budget: std::time::Duration, body: F, ) -> Result<T, AppError>` — Same as [`with_session_read`] with an explicit work budget. A file upload
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/runtime.rs:132</sub>
- `pub(super) async fn with_session_write<T, F, Fut>(body: F) -> Result<T, AppError> where` — Take the session write gate and run a session command under the session
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/runtime.rs:149</sub>
- `pub(super) async fn with_session_submit<T, F, Fut>(body: F) -> Option<T> where` — Take the session read gate and run a submitted write under the submit
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/runtime.rs:161</sub>
- `pub(super) async fn with_module_read<T, F, Fut>( module: ModuleAccess, body: F, ) -> Result<T, AppError>` — Take the session read gate and a module read gate, then run a read.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/runtime.rs:171</sub>
- `pub(super) async fn with_module_submit<T, F, Fut>(module: ModuleAccess, body: F) -> Option<T> where` — Take the session read gate and a module write gate, then run a submitted
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/runtime.rs:189</sub>
- `pub(super) fn service() -> Result<&'static LiveService, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/runtime.rs:202</sub>

## session

- `pub(super) async fn login( account: String, password: String, captcha: Option<String>, remember: bool, ) -> SessionResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/session.rs:4</sub>
- `pub(super) async fn restore_session() -> SessionResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/session.rs:31</sub>
- `pub(super) async fn sign_out() -> SessionResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/session.rs:62</sub>
- `pub(super) async fn set_route(route: RouteChoice) -> SessionResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/session.rs:87</sub>
- `pub(super) async fn clear_cache() -> bool {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/session.rs:108</sub>
- `pub(super) fn verify_credential_storage(account: String, secret: String) -> bool {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/session.rs:121</sub>

## utilities

- `pub(super) async fn edit_tasks( root: String, demo: bool, action: String, id: Option<String>, title: Option<String>, due: Option<String>, completed: Option<bool>, ) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:4</sub>
- `pub(super) async fn load_notices(force_refresh: bool) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:51</sub>
- `pub(super) fn load_demo_notices() -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:62</sub>
- `pub(super) async fn load_career_events(month: String, force_refresh: bool) -> CareerEventsResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:66</sub>
- `pub(super) async fn load_campus_activities(page: i32, force_refresh: bool) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:116</sub>
- `pub(super) async fn load_campus_card_balance() -> CampusCardBalanceResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:129</sub>
- `pub(super) fn load_demo_campus_card_balance() -> CampusCardBalanceResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:153</sub>
- `pub(super) async fn load_cgyy( kind: String, site_id: i64, date: String, force_refresh: bool, ) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:162</sub>
- `pub(super) async fn execute_cgyy(command: String) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:189</sub>
- `pub(super) fn load_demo_cgyy(kind: String) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:219</sub>
- `pub(super) async fn load_library_books( query: String, page: i64, sort: String, descending: bool, ) -> ReadOnlyResponse {…}` — Public OPAC search. Read-only, anonymous and bounded by the service.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:224</sub>
- `pub(super) async fn load_shuttle_timetable() -> ReadOnlyResponse {…}` — Published shuttle timetable. Public page, no identity, no ticketing.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:240</sub>
- `pub(super) async fn load_library_holdings(bib_id: String) -> ReadOnlyResponse {…}` — Public holdings for one bib id. The nested JSON string is decoded in Rust.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:249</sub>
- `pub(super) async fn export_learning_snapshots(expected: String) -> LearningSnapshotResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:257</sub>
- `pub(super) async fn import_learning_snapshots( expected: String, bytes: Vec<u8>, ) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:277</sub>
- `pub(super) async fn load_library_loans(expected: String, page: u32) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:294</sub>
- `pub(super) async fn check_android_update(current: String) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:306</sub>

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
- `pub async fn checkin_load_progress() -> ReadOnlyResponse {…}` — Observe the current read without issuing any school request.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:103</sub>
- `pub async fn load_checkin_on_date(date: String, force_refresh: bool) -> CheckInResponse {…}` — Historical day in Asia/Shanghai, yyyy-MM-dd; no sign-in submission.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:108</sub>
- `pub struct GradeTermsResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:112</sub>
    - `terms: Vec<ScheduleTerm>`  <sub>:113</sub>
    - `failure: Option<FailureCode>`  <sub>:114</sub>
    - `failure_detail: Option<String>`  <sub>:115</sub>
- `pub async fn load_grade_terms() -> GradeTermsResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:118</sub>
- `pub async fn load_grades(term_code: Option<String>, force_refresh: bool) -> GradeResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:122</sub>
- `pub fn verify_credential_storage(account: String, secret: String) -> bool {…}` — Device-acceptance diagnostic: write, read and delete one synthetic secret.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:128</sub>
- `pub async fn load_library_venues(force_refresh: bool) -> LibraryVenuesResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:132</sub>
- `pub async fn load_library_areas(library_id: String) -> LibraryAreasResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:136</sub>
- `pub async fn load_library_slots(area_id: String) -> LibrarySlotsResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:140</sub>
- `pub async fn load_library_seats( area_id: String, slot_id: String, day: String, start: String, end: String, ) -> LibrarySeatsResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:144</sub>
- `pub async fn load_library_bookings(force_refresh: bool) -> LibraryBookingsResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:154</sub>
- `pub struct LibraryHistoryResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:158</sub>
    - `bookings: Vec<super::mirror::LibraryBooking>`  <sub>:159</sub>
    - `page: i32`  <sub>:160</sub>
    - `page_size: i32`  <sub>:161</sub>
    - `total: Option<i32>`  <sub>:162</sub>
    - `has_next: bool`  <sub>:163</sub>
    - `fetched_at: Option<String>`  <sub>:164</sub>
    - `from_cache: bool`  <sub>:165</sub>
    - `stale: bool`  <sub>:166</sub>
    - `failure: Option<FailureCode>`  <sub>:167</sub>
    - `failure_detail: Option<String>`  <sub>:168</sub>
- `pub async fn load_library_history(page: i32, force_refresh: bool) -> LibraryHistoryResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:171</sub>
- `pub fn load_demo_library_history(page: i32) -> LibraryHistoryResponse {…}` — Synthetic page runs the same domain parser as live history.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:176</sub>
- `pub async fn load_homework(force_refresh: bool) -> super::mirror::HomeworkResponse {…}` — Real SPOC list, API.md §7.1. Demo remains an explicit separate command.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:181</sub>
- `pub struct HomeworkDetailResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:185</sub>
    - `source_url: Option<String>`  <sub>:186</sub>
    - `content: Option<String>`  <sub>:187</sub>
    - `published_at: Option<String>`  <sub>:188</sub>
    - `due_at: Option<String>`  <sub>:189</sub>
    - `score: Option<String>`  <sub>:190</sub>
    - `status: String`  <sub>:191</sub>
    - `submitted_at: Option<String>`  <sub>:192</sub>
    - `stale: bool`  <sub>:193</sub>
    - `failure: Option<FailureCode>`  <sub>:194</sub>
- `pub async fn load_homework_detail( assignment_id: String, force_refresh: bool, ) -> HomeworkDetailResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:197</sub>
- `pub struct ReadOnlyResponse` — Sanitized domain JSON, never raw upstream data, credentials or tokens.
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:205</sub>
    - `payload: Option<String>`  <sub>:206</sub>
    - `stale: bool`  <sub>:207</sub>
    - `failure: Option<FailureCode>`  <sub>:208</sub>
- `pub async fn load_bykc(force_refresh: bool) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:210</sub>
- `pub fn load_demo_bykc() -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:214</sub>
- `pub async fn load_bykc_chosen(force_refresh: bool) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:218</sub>
- `pub async fn load_bykc_statistics(force_refresh: bool) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:222</sub>
- `pub fn load_demo_bykc_chosen() -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:226</sub>
- `pub fn load_demo_bykc_statistics() -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:230</sub>
- `pub async fn load_graduate_part(report: bool, force_refresh: bool) -> ReadOnlyResponse {…}` — Independently cached sections, allowing Flutter to render the first response
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:236</sub>
- `pub fn load_demo_graduate_status() -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:240</sub>
- `pub fn load_demo_graduate() -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:244</sub>
- `pub async fn edit_tasks( root: String, demo: bool, action: String, id: Option<String>, title: Option<String>, due: Option<String>, completed: Option<bool>, ) -> ReadOnlyResponse {…}` — Local CRUD only. Account identity comes from Rust, never a Dart-supplied identifier.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:249</sub>
- `pub async fn load_notices(force_refresh: bool) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:261</sub>
- `pub struct CampusCardBalanceResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:265</sub>
    - `balance_minor: Option<i64>`  <sub>:266</sub>
    - `fetched_at: Option<String>`  <sub>:267</sub>
    - `failure: Option<FailureCode>`  <sub>:268</sub>
    - `failure_detail: Option<String>`  <sub>:269</sub>
- `pub async fn load_campus_card_balance() -> CampusCardBalanceResponse {…}` — Explicit, user-triggered campus-card balance read. No disk cache or bank data.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:273</sub>
- `pub fn load_demo_campus_card_balance() -> CampusCardBalanceResponse {…}` — Synthetic balance for the isolated demo workspace.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:278</sub>
- `pub fn load_demo_notices() -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:282</sub>
- `pub async fn load_career_events(month: String, force_refresh: bool) -> CareerEventsResponse {…}` — Public career-calendar events for a school month (YYYY-MM). Read-only.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:287</sub>
- `pub struct CareerEventDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:291</sub>
    - `id: String`  <sub>:292</sub>
    - `title: String`  <sub>:293</sub>
    - `campus: String`  <sub>:294</sub>
    - `place: String`  <sub>:295</sub>
    - `begins_at: String`  <sub>:296</sub>
    - `ends_at: String`  <sub>:297</sub>
    - `fair_type: String`  <sub>:298</sub>
    - `status: String`  <sub>:299</sub>
    - `url: String`  <sub>:300</sub>
- `pub struct CareerEventsDto`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:303</sub>
    - `month: String`  <sub>:304</sub>
    - `events: Vec<CareerEventDto>`  <sub>:305</sub>
    - `fetched_at: String`  <sub>:306</sub>
- `pub struct CareerEventsResponse` — A failure may accompany data only when it is a previous successful snapshot.
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:310</sub>
    - `data: Option<CareerEventsDto>`  <sub>:311</sub>
    - `failure: Option<FailureCode>`  <sub>:312</sub>
- `pub async fn load_campus_activities(page: i32, force_refresh: bool) -> ReadOnlyResponse {…}` — Public campus cultural activities (page 1-based). Read-only.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:316</sub>
- `pub async fn load_cgyy( kind: String, site_id: i64, date: String, force_refresh: bool, ) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:320</sub>
- `pub async fn execute_cgyy(command: String) -> ReadOnlyResponse {…}` — User-confirmed CGYY commands; payload contains no upstream credentials.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:330</sub>
- `pub fn load_demo_cgyy(kind: String) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:334</sub>
- `pub async fn load_library_books( query: String, page: i64, sort: String, descending: bool, ) -> ReadOnlyResponse {…}` — Public OPAC search (read-only, anonymous). Payload is the projected page.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:339</sub>
- `pub async fn load_shuttle_timetable() -> ReadOnlyResponse {…}` — Published shuttle timetable (official page). Read-only, no ticketing.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:349</sub>
- `pub async fn load_library_holdings(bib_id: String) -> ReadOnlyResponse {…}` — Public holdings for one bib id; the nested JSON string never crosses the bridge.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:354</sub>
- `pub struct LearningSnapshotResponse` — Transient archive bytes. Hosts must use explicitly opted-in encrypted storage.
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:359</sub>
    - `bytes: Option<Vec<u8>>`  <sub>:360</sub>
    - `failure: Option<FailureCode>`  <sub>:361</sub>
- `pub async fn export_learning_snapshots(expected_account: String) -> LearningSnapshotResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:363</sub>
- `pub async fn import_learning_snapshots( expected_account: String, bytes: Vec<u8>, ) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:366</sub>
- `pub fn library_loans_portal_url() -> String {…}` — Public website metadata only. Does not initialize an authenticated session.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:375</sub>
- `pub fn student_service_url(id: String) -> Option<String> {…}` — Public destination metadata; does not initialize an authenticated session.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:381</sub>
- `pub async fn load_library_loans(expected_account: String, page: u32) -> ReadOnlyResponse {…}` — Explicit private read, scoped to the caller's account. No disk cache or writes.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:386</sub>
- `pub async fn load_library_stats(force_refresh: bool) -> ReadOnlyResponse {…}` — Public counts only. No school identity or library token is serialized.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:391</sub>
- `pub fn load_demo_library_stats() -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:394</sub>
- `pub async fn check_android_update(current: String) -> ReadOnlyResponse {…}` — Deliberately independent from login, school routes and account caches.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:399</sub>
- `pub struct MutationResponse` — User-confirmed write. Never retries the mutation and never exposes raw upstream text.
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:404</sub>
    - `state: String`  <sub>:405</sub>
    - `message: String`  <sub>:406</sub>
- `pub async fn submit_checkin(course_id: String) -> MutationResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:409</sub>
- `pub async fn reserve_library_seat( area_id: String, seat_id: String, slot: crate::api::mirror::LibrarySlot, ) -> MutationResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:413</sub>
- `pub async fn perform_library_action(booking_id: String, action: String) -> MutationResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:420</sub>
- `pub async fn homework_file_workspace( expected_account: String, assignment_id: String, ) -> ReadOnlyResponse {…}` — Homework business JSON only; raw SPOC payloads never leave upstream.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:459</sub>
- `pub async fn upload_homework_file( expected_account: String, assignment_id: String, name: String, bytes: Vec<u8>, ) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:465</sub>
- `pub async fn submit_homework_file( expected_account: String, handle: String, confirmed: bool, ) -> MutationResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:473</sub>
- `pub async fn reconcile_homework_file(expected_account: String, handle: String) -> MutationResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:480</sub>
- `pub struct HomeworkFileDownloadResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:483</sub>
    - `name: Option<String>`  <sub>:484</sub>
    - `bytes: Option<Vec<u8>>`  <sub>:485</sub>
    - `failure: Option<FailureCode>`  <sub>:486</sub>
- `pub async fn download_homework_file( expected_account: String, assignment_id: String, attachment_id: String, ) -> HomeworkFileDownloadResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:488</sub>
- `pub async fn learning_courses(expected_account: String, force: bool) -> ReadOnlyResponse {…}` — Learning queries return business DTO JSON, never school response envelopes.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:497</sub>
- `pub async fn course_announcements( expected_account: String, course: String, force: bool, ) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:500</sub>
- `pub async fn course_announcement_detail( expected_account: String, course: String, id: String, ) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:507</sub>
- `pub async fn course_resources( expected_account: String, course: String, folder: Option<String>, page: u32, force: bool, ) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:514</sub>
- `pub async fn course_assessments( expected_account: String, course: String, force: bool, ) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:523</sub>
- `pub async fn course_resource_download( expected_account: String, course: String, folder: Option<String>, page: u32, id: String, ) -> HomeworkFileDownloadResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:530</sub>
- `pub async fn course_announcement_attachment( expected_account: String, course: String, id: String, file: String, ) -> HomeworkFileDownloadResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:539</sub>
- `pub async fn course_learning_columns( expected_account: String, course: String, force: bool, ) -> ReadOnlyResponse {…}` — Explicit module context; all identifiers are revalidated by the source.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:552</sub>
- `pub async fn course_learning_capabilities( expected_account: String, course: String, ) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:559</sub>
- `pub async fn course_announcements_in( expected_account: String, course: String, column: String, force: bool, ) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:565</sub>
- `pub async fn course_assessments_in( expected_account: String, course: String, column: String, force: bool, ) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:573</sub>
- `pub async fn course_announcement_detail_in( expected_account: String, course: String, column: String, id: String, ) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:581</sub>
- `pub async fn course_announcement_attachment_in( expected_account: String, course: String, column: String, id: String, file: String, ) -> HomeworkFileDownloadResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:589</sub>
- `pub async fn course_resources_at( expected_account: String, course: String, path: Vec<String>, page: u32, force: bool, ) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:598</sub>
- `pub async fn course_resource_download_at( expected_account: String, course: String, path: Vec<String>, page: u32, id: String, ) -> HomeworkFileDownloadResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:607</sub>
- `pub async fn load_graduate_credit_map( expected_account: String, force_refresh: bool, ) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:616</sub>
- `pub async fn configure_homework_recovery( expected_account: String, storage_root: String, ) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:622</sub>
- `pub async fn pending_homework_submissions( expected_account: String, assignment_id: Option<String>, ) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:628</sub>
- `pub async fn homework_capabilities( expected_account: String, assignment_id: String, ) -> ReadOnlyResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/live.rs:634</sub>

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
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:80</sub>
    - `buildings: Vec<ClassroomBuilding>`  <sub>:81</sub>
    - `room_count: i32`  <sub>:82</sub>
    - `building_count: i32`  <sub>:83</sub>
    - `free_slot_count: i32`  <sub>:84</sub>
    - `fetched_at: Option<String>`  <sub>:85</sub>
    - `from_cache: bool`  <sub>:86</sub>
    - `failure: Option<FailureCode>`  <sub>:87</sub>
    - `failure_detail: Option<String>`  <sub>:88</sub>
- `pub fn load_demo_classrooms(query: ClassroomQuery) -> ClassroomResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:91</sub>
- `pub struct RuleExamples`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:95</sub>
    - `local_date: String`  <sub>:96</sub>
    - `minutes_since_midnight: i32`  <sub>:97</sub>
    - `time_zone: String`  <sub>:98</sub>
    - `cached_weeks: Vec<i32>`  <sub>:99</sub>
    - `selected_week: i32`  <sub>:100</sub>
    - `course_names: Vec<String>`  <sub>:101</sub>
    - `failure: Option<FailureCode>`  <sub>:102</sub>
- `pub fn load_rule_examples() -> RuleExamples {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:105</sub>
- `pub struct ScheduleTerm`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:109</sub>
    - `id: String`  <sub>:110</sub>
    - `name: String`  <sub>:111</sub>
    - `selected: bool`  <sub>:112</sub>
- `pub struct ScheduleWeek`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:115</sub>
    - `number: i32`  <sub>:116</sub>
    - `start_date: String`  <sub>:117</sub>
    - `end_date: String`  <sub>:118</sub>
    - `current: bool`  <sub>:119</sub>
- `pub struct ScheduleCourse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:122</sub>
    - `id: String`  <sub>:123</sub>
    - `name: String`  <sub>:124</sub>
    - `day: i32`  <sub>:125</sub>
    - `start_section: i32`  <sub>:126</sub>
    - `end_section: i32`  <sub>:127</sub>
    - `start_time: Option<String>`  <sub>:128</sub>
    - `end_time: Option<String>`  <sub>:129</sub>
    - `place: Option<String>`  <sub>:130</sub>
    - `teacher: Option<String>`  <sub>:131</sub>
    - `color: Option<String>`  <sub>:132</sub>
- `pub struct ScheduleExam`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:135</sub>
    - `id: String`  <sub>:136</sub>
    - `course_name: String`  <sub>:137</sub>
    - `course_no: Option<String>`  <sub>:138</sub>
    - `exam_time_description: Option<String>`  <sub>:139</sub>
    - `exam_date: Option<String>`  <sub>:140</sub>
    - `start_time: Option<String>`  <sub>:141</sub>
    - `end_time: Option<String>`  <sub>:142</sub>
    - `exam_place: Option<String>`  <sub>:143</sub>
    - `exam_seat_no: Option<String>`  <sub>:144</sub>
    - `week: Option<i32>`  <sub>:145</sub>
    - `exam_status: Option<String>`  <sub>:146</sub>
    - `exam_type: Option<String>`  <sub>:147</sub>
- `pub struct ScheduleResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:150</sub>
    - `terms: Vec<ScheduleTerm>`  <sub>:151</sub>
    - `weeks: Vec<ScheduleWeek>`  <sub>:152</sub>
    - `term_id: String`  <sub>:153</sub>
    - `week_number: i32`  <sub>:154</sub>
    - `courses: Vec<ScheduleCourse>`  <sub>:155</sub>
    - `exams: Vec<ScheduleExam>`  <sub>:156</sub>
    - `fetched_at: Option<String>`  <sub>:157</sub>
    - `failure: Option<FailureCode>`  <sub>:158</sub>
    - `failure_detail: Option<String>`  <sub>:159</sub>
- `pub fn load_demo_schedule() -> ScheduleResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:162</sub>
- `pub struct GradeCourse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:166</sub>
    - `id: String`  <sub>:167</sub>
    - `name: String`  <sub>:168</sub>
    - `code: Option<String>`  <sub>:169</sub>
    - `credit: Option<f64>`  <sub>:170</sub>
    - `score: String`  <sub>:171</sub>
    - `score_value: Option<f64>`  <sub>:172</sub>
    - `score_type: Option<String>`  <sub>:173</sub>
    - `course_type: Option<String>`  <sub>:174</sub>
- `pub struct GradeSummary`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:177</sub>
    - `course_count: i32`  <sub>:178</sub>
    - `credit_total: f64`  <sub>:179</sub>
    - `weighted_average: Option<f64>`  <sub>:180</sub>
    - `grade_point_average: Option<f64>`  <sub>:181</sub>
- `pub struct GradeResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:184</sub>
    - `term_id: String`  <sub>:185</sub>
    - `courses: Vec<GradeCourse>`  <sub>:186</sub>
    - `summary: GradeSummary`  <sub>:187</sub>
    - `fetched_at: Option<String>`  <sub>:188</sub>
    - `failure: Option<FailureCode>`  <sub>:189</sub>
    - `failure_detail: Option<String>`  <sub>:190</sub>
- `pub fn load_demo_grades() -> GradeResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:193</sub>
- `pub struct TodayCourse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:197</sub>
    - `name: String`  <sub>:198</sub>
    - `place: Option<String>`  <sub>:199</sub>
    - `time: Option<String>`  <sub>:200</sub>
    - `short_name: Option<String>`  <sub>:201</sub>
- `pub struct TodayResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:204</sub>
    - `date: String`  <sub>:205</sub>
    - `courses: Vec<TodayCourse>`  <sub>:206</sub>
    - `fetched_at: Option<String>`  <sub>:207</sub>
    - `failure: Option<FailureCode>`  <sub>:208</sub>
    - `failure_detail: Option<String>`  <sub>:209</sub>
- `pub fn load_demo_today() -> TodayResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:212</sub>
- `pub enum HomeworkStatus`
  <sub>enum · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:216</sub>
- `pub struct HomeworkItem`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:222</sub>
    - `course_role: Option<String>`  <sub>:223</sub>
    - `teacher_name: Option<String>`  <sub>:224</sub>
    - `id: String`  <sub>:225</sub>
    - `course_id: Option<String>`  <sub>:226</sub>
    - `course_name: String`  <sub>:227</sub>
    - `title: String`  <sub>:228</sub>
    - `published_at: Option<String>`  <sub>:229</sub>
    - `due_at: Option<String>`  <sub>:230</sub>
    - `status: HomeworkStatus`  <sub>:231</sub>
    - `status_detail: Option<String>`  <sub>:232</sub>
    - `score: Option<String>`  <sub>:233</sub>
- `pub struct HomeworkResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:236</sub>
    - `term_name: String`  <sub>:237</sub>
    - `term_code: String`  <sub>:238</sub>
    - `items: Vec<HomeworkItem>`  <sub>:239</sub>
    - `fetched_at: Option<String>`  <sub>:240</sub>
    - `roles_complete: Option<bool>`  <sub>:241</sub>
    - `failure: Option<FailureCode>`  <sub>:242</sub>
    - `failure_detail: Option<String>`  <sub>:243</sub>
- `pub fn load_demo_homework() -> HomeworkResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:246</sub>
- `pub struct QueryDates`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:250</sub>
    - `today: String`  <sub>:251</sub>
    - `tomorrow: String`  <sub>:252</sub>
    - `failure: Option<FailureCode>`  <sub>:253</sub>
- `pub fn load_query_dates(instant: String) -> QueryDates {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:255</sub>
- `pub struct DemoScope`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:259</sub>
    - `campus: i32`  <sub>:260</sub>
    - `date: String`  <sub>:261</sub>
    - `force_refresh: bool`  <sub>:262</sub>
- `pub fn query_demo_classrooms(scope: DemoScope, query: ClassroomQuery) -> ClassroomResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:265</sub>
- `pub enum CheckInStatus`
  <sub>enum · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:269</sub>
- `pub struct CheckInCourse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:275</sub>
    - `id: String`  <sub>:276</sub>
    - `course_id: Option<String>`  <sub>:277</sub>
    - `course_num: Option<String>`  <sub>:278</sub>
    - `course_name: String`  <sub>:279</sub>
    - `begins_at: String`  <sub>:280</sub>
    - `ends_at: String`  <sub>:281</sub>
    - `status: CheckInStatus`  <sub>:282</sub>
    - `teacher_name: Option<String>`  <sub>:283</sub>
    - `classroom_name: Option<String>`  <sub>:284</sub>
    - `merged_record_count: i32`  <sub>:285</sub>
    - `conflicting: bool`  <sub>:286</sub>
    - `sign_in_allowed: Option<bool>` — Explicit false covers merged sessions with conflicting records.  <sub>:288</sub>
- `pub struct CheckInResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:291</sub>
    - `date: String` — School-local date, yyyy-MM-dd.  <sub>:293</sub>
    - `courses: Vec<CheckInCourse>`  <sub>:294</sub>
    - `fetched_at: Option<String>`  <sub>:295</sub>
    - `from_cache: bool`  <sub>:296</sub>
    - `stale: bool`  <sub>:297</sub>
    - `failure: Option<FailureCode>`  <sub>:298</sub>
    - `failure_detail: Option<String>`  <sub>:299</sub>
- `pub fn load_demo_checkin() -> CheckInResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:323</sub>
- `pub struct LibraryVenue`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:327</sub>
    - `id: String`  <sub>:328</sub>
    - `name: String`  <sub>:329</sub>
    - `free: i32`  <sub>:330</sub>
    - `total: i32`  <sub>:331</sub>
- `pub struct LibraryArea`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:334</sub>
    - `id: String`  <sub>:335</sub>
    - `name: String`  <sub>:336</sub>
    - `free: i32`  <sub>:337</sub>
    - `total: i32`  <sub>:338</sub>
- `pub struct LibrarySlot`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:341</sub>
    - `id: String`  <sub>:342</sub>
    - `day: String`  <sub>:343</sub>
    - `start: String`  <sub>:344</sub>
    - `end: String`  <sub>:345</sub>
- `pub struct LibrarySeat`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:348</sub>
    - `id: String`  <sub>:349</sub>
    - `name: String`  <sub>:350</sub>
    - `status_name: String`  <sub>:351</sub>
    - `available: bool`  <sub>:352</sub>
- `pub struct LibraryBooking`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:355</sub>
    - `id: String`  <sub>:356</sub>
    - `title: String`  <sub>:357</sub>
    - `area_name: String`  <sub>:358</sub>
    - `seat_number: String`  <sub>:359</sub>
    - `day: String`  <sub>:360</sub>
    - `start_time: String`  <sub>:361</sub>
    - `end_time: String`  <sub>:362</sub>
    - `status_name: String`  <sub>:363</sub>
    - `actions: Option<Vec<String>>`  <sub>:364</sub>
- `pub struct LibraryVenuesResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:367</sub>
    - `venues: Vec<LibraryVenue>`  <sub>:368</sub>
    - `fetched_at: Option<String>`  <sub>:369</sub>
    - `from_cache: bool`  <sub>:370</sub>
    - `stale: bool`  <sub>:371</sub>
    - `failure: Option<FailureCode>`  <sub>:372</sub>
    - `failure_detail: Option<String>`  <sub>:373</sub>
- `pub struct LibraryAreasResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:376</sub>
    - `areas: Vec<LibraryArea>`  <sub>:377</sub>
    - `failure: Option<FailureCode>`  <sub>:378</sub>
    - `failure_detail: Option<String>`  <sub>:379</sub>
- `pub struct LibrarySlotsResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:382</sub>
    - `slots: Vec<LibrarySlot>`  <sub>:383</sub>
    - `failure: Option<FailureCode>`  <sub>:384</sub>
    - `failure_detail: Option<String>`  <sub>:385</sub>
- `pub struct LibrarySeatsResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:388</sub>
    - `seats: Vec<LibrarySeat>`  <sub>:389</sub>
    - `failure: Option<FailureCode>`  <sub>:390</sub>
    - `failure_detail: Option<String>`  <sub>:391</sub>
- `pub struct LibraryBookingsResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:394</sub>
    - `bookings: Vec<LibraryBooking>`  <sub>:395</sub>
    - `fetched_at: Option<String>`  <sub>:396</sub>
    - `from_cache: bool`  <sub>:397</sub>
    - `stale: bool`  <sub>:398</sub>
    - `failure: Option<FailureCode>`  <sub>:399</sub>
    - `failure_detail: Option<String>`  <sub>:400</sub>
- `pub struct LibraryDemoResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:403</sub>
    - `venues: Vec<LibraryVenue>`  <sub>:404</sub>
    - `areas: Vec<LibraryArea>`  <sub>:405</sub>
    - `slots: Vec<LibrarySlot>`  <sub>:406</sub>
    - `seats: Vec<LibrarySeat>`  <sub>:407</sub>
    - `bookings: Vec<LibraryBooking>`  <sub>:408</sub>
- `pub(super) fn library_venue(value: ginkgo_core::features::library::LibraryVenue) -> LibraryVenue {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:411</sub>
- `pub(super) fn library_area(value: ginkgo_core::features::library::LibraryArea) -> LibraryArea {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:420</sub>
- `pub(super) fn library_slot(value: ginkgo_core::features::library::LibrarySlot) -> LibrarySlot {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:429</sub>
- `pub(super) fn library_seat(value: ginkgo_core::features::library::LibrarySeat) -> LibrarySeat {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:438</sub>
- `pub(super) fn library_booking( value: ginkgo_core::features::library::LibraryBooking, ) -> LibraryBooking {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:447</sub>
- `pub fn load_demo_library() -> LibraryDemoResponse {…}`
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:464</sub>

## reminder_planning

- `pub struct CourseReminderSeed`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/reminder_planning.rs:4</sub>
    - `id: String`  <sub>:5</sub>
    - `week_start: String`  <sub>:6</sub>
    - `day: i32`  <sub>:7</sub>
    - `starts_at: String`  <sub>:8</sub>
    - `ends_at: String`  <sub>:9</sub>
- `pub struct TaskReminderSeed`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/reminder_planning.rs:12</sub>
    - `id: String`  <sub>:13</sub>
    - `due: String`  <sub>:14</sub>
    - `completed: bool`  <sub>:15</sub>
- `pub struct PlannedReminder`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/reminder_planning.rs:18</sub>
    - `key: String`  <sub>:19</sub>
    - `group: String`  <sub>:20</sub>
    - `at_millis: i64`  <sub>:21</sub>
    - `expires_millis: i64`  <sub>:22</sub>
- `pub struct ReminderPlanResponse`
  <sub>struct · rust/crates/ginkgo_flutter_bridge/src/api/reminder_planning.rs:25</sub>
    - `plans: Vec<PlannedReminder>`  <sub>:26</sub>
    - `skipped: u32`  <sub>:27</sub>
    - `unsupported: bool`  <sub>:28</sub>
- `pub fn plan_course_task_reminders( courses: Vec<CourseReminderSeed>, tasks: Vec<TaskReminderSeed>, now_millis: i64, ) -> ReminderPlanResponse {…}` — Data-only plans. Calling this never requests notification permissions or sends notifications.
  <sub>fn · rust/crates/ginkgo_flutter_bridge/src/api/reminder_planning.rs:33</sub>
