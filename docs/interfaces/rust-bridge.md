# 桥接（ginkgo_flutter_bridge）

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。

FFI DTO 与粗粒度命令；Dart 唯一可见的 Rust 面。

## academic

- `pub(super) async fn load_schedule( term_id: Option<String>, week: Option<i32>, force_refresh: bool, ) -> ScheduleResponse { let _access = SESSION_ACC…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/academic.rs:4</sub>
- `pub(super) async fn load_today(force_refresh: bool) -> TodayResponse { let _access = SESSION_ACCESS.read().await; let Ok(service) = service() else { …`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/academic.rs:25</sub>
- `pub(super) async fn load_checkin_today(force_refresh: bool) -> CheckInResponse { let _access = SESSION_ACCESS.read().await; let _module = CHECKIN_ACC…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/academic.rs:51</sub>
- `pub(super) async fn load_grade_terms() -> GradeTermsResponse { let _access = SESSION_ACCESS.read().await; let service = match service() { Ok(service)…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/academic.rs:63</sub>
- `pub(super) async fn load_grades(term_code: Option<String>, force_refresh: bool) -> GradeResponse { let _access = SESSION_ACCESS.read().await; let Ok(…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/academic.rs:100</sub>

## auth_challenge

- `pub struct LoginChallengeResponse {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/auth_challenge.rs:4</sub>
    - `challenge_id: Option<String>`  <sub>:5</sub>
    - `challenge_type: Option<String>`  <sub>:6</sub>
    - `text_supported: bool`  <sub>:7</sub>
    - `image: Vec<u8>`  <sub>:8</sub>
    - `failure: Option<FailureCode>`  <sub>:9</sub>
- `pub async fn load_login_challenge( expected_id: Option<String>, refresh: bool, ) -> LoginChallengeResponse { let _access = SESSION_ACCESS.write().awa…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/auth_challenge.rs:12</sub>

## bykc

- `pub(super) async fn load_bykc(force_refresh: bool) -> ReadOnlyResponse { let _access = SESSION_ACCESS.read().await; let result = match service() { Ok…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/bykc.rs:4</sub>
- `pub(super) fn load_demo_bykc() -> ReadOnlyResponse { read_only_value( ginkgo_runtime::demo::demo_campus::load_demo_bykc() .and_then(ginkgo_core::appl…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/bykc.rs:19</sub>
- `pub(super) async fn load_bykc_chosen(force_refresh: bool) -> ReadOnlyResponse { let _access = SESSION_ACCESS.read().await; let result = match service…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/bykc.rs:26</sub>
- `pub(super) async fn load_bykc_statistics(force_refresh: bool) -> ReadOnlyResponse { let _access = SESSION_ACCESS.read().await; let result = match ser…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/bykc.rs:35</sub>
- `pub(super) fn load_demo_bykc_chosen() -> ReadOnlyResponse { read_only_value(ginkgo_runtime::demo::demo_campus::load_demo_bykc_chosen()) }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/bykc.rs:44</sub>
- `pub(super) fn load_demo_bykc_statistics() -> ReadOnlyResponse { read_only_value(ginkgo_runtime::demo::demo_campus::load_demo_bykc_statistics()) }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/bykc.rs:48</sub>

## checkin

- `pub(super) async fn checkin_load_progress() -> ReadOnlyResponse { match service() { Ok(service) => ReadOnlyResponse { payload: serde_json::to_string(…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/checkin.rs:4</sub>
- `pub(super) async fn load_checkin_on_date(date: String, force_refresh: bool) -> CheckInResponse { let _access = SESSION_ACCESS.read().await; let _modu…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/checkin.rs:19</sub>
- `pub(super) async fn submit_checkin(course_id: String) -> MutationResponse { let Ok(_write) = CHECKIN_WRITE.try_lock() else { return MutationResponse …`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/checkin.rs:32</sub>

## classroom

- `pub(super) async fn load_classrooms(scope: LiveScope, query: ClassroomQuery) -> ClassroomResponse { let _access = SESSION_ACCESS.read().await; let Ok…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/classroom.rs:4</sub>

## graduate

- `pub(super) async fn load_graduate_part(report: bool, force_refresh: bool) -> ReadOnlyResponse { use ginkgo_core::application::GraduatePart; let _acce…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/graduate.rs:4</sub>
- `pub(super) fn load_demo_graduate_status() -> ReadOnlyResponse { read_only_value(ginkgo_runtime::demo::demo_campus::graduate_status()) }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/graduate.rs:24</sub>
- `pub(super) fn load_demo_graduate() -> ReadOnlyResponse { read_only_value(ginkgo_runtime::demo::demo_campus::load_demo_graduate()) }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/graduate.rs:28</sub>
- `pub(super) async fn credit_map(expected: String, force: bool) -> ReadOnlyResponse { let _session = SESSION_ACCESS.read().await; let result = async { …`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/graduate.rs:32</sub>

## homework

- `pub(super) async fn load_homework(force_refresh: bool) -> crate::api::mirror::HomeworkResponse { let _access = SESSION_ACCESS.read().await; use crate…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/homework.rs:4</sub>
- `pub(super) async fn load_homework_detail( assignment_id: String, force_refresh: bool, ) -> HomeworkDetailResponse { let _access = SESSION_ACCESS.read…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/homework.rs:56</sub>
- `pub(super) async fn file_workspace(expected: String, id: String) -> ReadOnlyResponse { let _session = SESSION_ACCESS.read().await; file_response(matc…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/homework.rs:119</sub>
- `pub(super) async fn upload_file( expected: String, id: String, name: String, bytes: Vec<u8>, ) -> ReadOnlyResponse { let Ok(_write) = FILE_WRITE.try_…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/homework.rs:126</sub>
- `pub(super) async fn submit_file( expected: String, handle: String, confirmed: bool, reconcile: bool, ) -> MutationResponse { let Ok(_write) = FILE_WR…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/homework.rs:148</sub>
- `pub(super) async fn download_file( expected: String, id: String, attachment: String, ) -> HomeworkFileDownloadResponse { let _session = SESSION_ACCES…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/homework.rs:176</sub>
- `pub(super) async fn configure_recovery(expected: String, root: String) -> ReadOnlyResponse { let _write = FILE_WRITE.lock().await; let _session = SES…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/homework.rs:201</sub>
- `pub(super) async fn pending_submissions( expected: String, assignment: Option<String>, ) -> ReadOnlyResponse { let _session = SESSION_ACCESS.read().a…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/homework.rs:206</sub>
- `pub(super) async fn capabilities(expected: String, id: String) -> ReadOnlyResponse { let _session = SESSION_ACCESS.read().await; file_response( async…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/homework.rs:223</sub>

## learning

- `pub(super) async fn courses(expected: String, force: bool) -> ReadOnlyResponse { let _access = SESSION_ACCESS.read().await; response(async { bounded_…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/learning.rs:31</sub>
- `pub(super) async fn announcements( expected: String, course: String, force: bool, ) -> ReadOnlyResponse { let _access = SESSION_ACCESS.read().await; …`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/learning.rs:35</sub>
- `pub(super) async fn resources( expected: String, course: String, folder: Option<String>, page: u32, force: bool, ) -> ReadOnlyResponse { let _access …`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/learning.rs:45</sub>
- `pub(super) async fn assessments(expected: String, course: String, force: bool) -> ReadOnlyResponse { let _access = SESSION_ACCESS.read().await; respo…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/learning.rs:66</sub>
- `pub(super) async fn announcement_detail( expected: String, course: String, id: String, ) -> ReadOnlyResponse { let _access = SESSION_ACCESS.read().aw…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/learning.rs:72</sub>
- `pub(super) async fn resource_download( expected: String, course: String, folder: Option<String>, page: u32, id: String, ) -> HomeworkFileDownloadResp…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/learning.rs:104</sub>
- `pub(super) async fn announcement_attachment( expected: String, course: String, id: String, file: String, ) -> HomeworkFileDownloadResponse { let _acc…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/learning.rs:125</sub>

## library

- `pub(super) async fn load_library_venues(force_refresh: bool) -> LibraryVenuesResponse { let _access = SESSION_ACCESS.read().await; let _module = LIBR…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/library.rs:4</sub>
- `pub(super) async fn load_library_areas(library_id: String) -> LibraryAreasResponse { let _access = SESSION_ACCESS.read().await; let _module = LIBRARY…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/library.rs:44</sub>
- `pub(super) async fn load_library_slots(area_id: String) -> LibrarySlotsResponse { let _access = SESSION_ACCESS.read().await; let _module = LIBRARY_AC…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/library.rs:68</sub>
- `pub(super) async fn load_library_seats( area_id: String, slot_id: String, day: String, start: String, end: String, ) -> LibrarySeatsResponse { let _a…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/library.rs:92</sub>
- `pub(super) async fn load_library_bookings(force_refresh: bool) -> LibraryBookingsResponse { let _access = SESSION_ACCESS.read().await; let _module = …`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/library.rs:122</sub>
- `pub(super) async fn load_library_history(page: i32, force_refresh: bool) -> LibraryHistoryResponse { let _access = SESSION_ACCESS.read().await; let _…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/library.rs:162</sub>
- `pub(super) fn load_demo_library_history(page: i32) -> LibraryHistoryResponse { let result = ginkgo_runtime::demo::demo_campus::library_history(page);…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/library.rs:209</sub>
- `pub(super) async fn load_library_stats(force_refresh: bool) -> ReadOnlyResponse { let _access = SESSION_ACCESS.read().await; let result = match servi…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/library.rs:239</sub>
- `pub(super) fn load_demo_library_stats() -> ReadOnlyResponse { let result = ginkgo_runtime::demo::demo_campus::library_stats(); match result { Ok(camp…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/library.rs:261</sub>
- `pub(super) async fn reserve_library_seat( area_id: String, seat_id: String, slot: crate::api::mirror::LibrarySlot, ) -> MutationResponse { let Ok(_wr…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/library.rs:280</sub>
- `pub(super) async fn perform_library_action(booking_id: String, action: String) -> MutationResponse { let Ok(_write) = LIBRARY_WRITE.try_lock() else {…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/library.rs:320</sub>

## mapping

- `pub(super) fn mutation_response( outcome: ginkgo_core::features::mutation::MutationOutcome, ) -> MutationResponse { use ginkgo_core::features::mutati…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/mapping.rs:4</sub>
- `pub(super) fn grade_response(outcome: GradeOutcome) -> GradeResponse { let (failure, failure_detail) = outcome .failure .as_ref() .map(failure) .unwr…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/mapping.rs:20</sub>
- `pub(super) fn grade_failure(failure: FailureCode, detail: Option<String>) -> GradeResponse { GradeResponse { term_id: String::new(), courses: vec![],…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/mapping.rs:54</sub>
- `pub(super) fn checkin_response(outcome: CheckInOutcome) -> CheckInResponse { let (failure, failure_detail) = outcome .failure .as_ref() .map(failure)…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/mapping.rs:70</sub>
- `pub(super) fn checkin_failure(failure: FailureCode, detail: Option<String>) -> CheckInResponse { CheckInResponse { date: String::new(), courses: vec!…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/mapping.rs:114</sub>
- `pub(super) fn today_response(outcome: TodayOutcome) -> TodayResponse { let (failure, failure_detail) = outcome .failure .as_ref() .map(failure) .unwr…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/mapping.rs:126</sub>
- `pub(super) fn schedule_response(outcome: ScheduleOutcome) -> ScheduleResponse { let (failure, failure_detail) = outcome .failure .as_ref() .map(failu…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/mapping.rs:150</sub>
- `pub(super) fn schedule_failure(failure: FailureCode, detail: Option<String>) -> ScheduleResponse { ScheduleResponse { terms: vec![], weeks: vec![], t…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/mapping.rs:222</sub>
- `pub(super) fn classroom_response(outcome: ClassroomOutcome) -> ClassroomResponse { let (failure, failure_detail) = outcome .failure .as_ref() .map(fa…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/mapping.rs:236</sub>
- `pub(super) fn classroom_sort(sort: ClassroomSort) -> classroom_domain::Sort { match sort { ClassroomSort::Name => classroom_domain::Sort::Name, Class…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/mapping.rs:276</sub>
- `pub(super) fn outcome_response( service: &LiveService, outcome: SessionOutcome, remembered: bool, ) -> SessionResponse { match outcome { SessionOutco…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/mapping.rs:284</sub>
- `pub(super) fn status_response(status: SessionStatus) -> SessionResponse { if let (Some(account), Some(profile)) = (status.account, status.profile) { …`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/mapping.rs:306</sub>
- `pub(super) fn failure_response(error: AppError) -> SessionResponse { let (failure, failure_detail) = failure(&error); SessionResponse { failure, fail…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/mapping.rs:324</sub>
- `pub(super) fn signed_out() -> SessionResponse { SessionResponse { state: SessionState::SignedOut, account: None, name: None, captcha_id: None, captch…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/mapping.rs:333</sub>
- `pub(super) fn failure(error: &AppError) -> (Option<FailureCode>, Option<String>) { (Some(error.code.clone().into()), error.detail.clone()) }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/mapping.rs:347</sub>
- `pub(super) fn read_only_response<T: serde::Serialize>( result: Result<ginkgo_core::application::DataOutcome<T>, AppError>, ) -> ReadOnlyResponse { le…` — Serialization failures are typed failures, never an empty successful response.  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/mapping.rs:352</sub>
- `pub(super) fn read_only_value<T: serde::Serialize>( result: Result<T, AppError>, ) -> ReadOnlyResponse { read_only_response(result.map(\|data\| ginkgo_…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/mapping.rs:370</sub>

## runtime

- `pub(super) type LiveService = ginkgo_runtime::AppService;`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/runtime.rs:4</sub>
- `pub(super) static SESSION_ACCESS: tokio::sync::RwLock<()> = tokio::sync::RwLock::const_new(());`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/runtime.rs:8</sub>
- `pub(super) static CHECKIN_ACCESS: tokio::sync::RwLock<()> = tokio::sync::RwLock::const_new(());`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/runtime.rs:13</sub>
- `pub(super) static LIBRARY_ACCESS: tokio::sync::RwLock<()> = tokio::sync::RwLock::const_new(());`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/runtime.rs:14</sub>
- `pub(super) static CGYY_ACCESS: tokio::sync::RwLock<()> = tokio::sync::RwLock::const_new(());`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/runtime.rs:15</sub>
- `pub(super) static SERVICE: OnceLock<Result<LiveService, AppError>> = OnceLock::new();`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/runtime.rs:17</sub>
- `pub(super) async fn bounded_read<T>( future: impl std::future::Future<Output = Result<T, AppError>>, ) -> Result<T, AppError> { tokio::time::timeout(…` — Total budget for a read including SSO redirects and fallback. Mutations  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/runtime.rs:21</sub>
- `pub(super) async fn bounded_session<T>( future: impl std::future::Future<Output = Result<T, AppError>>, ) -> Result<T, AppError> { tokio::time::timeo…` — Budget for session commands (sign-in/restore). The CAS chain alone can  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/runtime.rs:34</sub>
- `pub(super) async fn bounded_submit<T>(future: impl std::future::Future<Output = T>) -> Option<T> { tokio::time::timeout(std::time::Duration::from_sec…` — Budget for a school write. A timed-out write is dropped, never retried:  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/runtime.rs:46</sub>
- `pub(super) fn service() -> Result<&'static LiveService, AppError> { SERVICE .get_or_init(ginkgo_runtime::create_service) .as_ref() .map_err(Clone::cl…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/runtime.rs:52</sub>

## session

- `pub(super) async fn login( account: String, password: String, captcha: Option<String>, remember: bool, ) -> SessionResponse { let _access = SESSION_A…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/session.rs:4</sub>
- `pub(super) async fn restore_session() -> SessionResponse { let _access = SESSION_ACCESS.write().await; if SERVICE.get().is_none() { match ginkgo_runt…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/session.rs:31</sub>
- `pub(super) async fn sign_out() -> SessionResponse { let _access = SESSION_ACCESS.write().await; let Some(Ok(service)) = SERVICE.get() else { return s…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/session.rs:60</sub>
- `pub(super) async fn set_route(route: RouteChoice) -> SessionResponse { let _access = SESSION_ACCESS.write().await; let service = match service() { Ok…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/session.rs:69</sub>
- `pub(super) async fn clear_cache() -> bool { let _access = SESSION_ACCESS.write().await; match service() { Ok(service) => { service.clear_snapshots();…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/session.rs:84</sub>
- `pub(super) fn verify_credential_storage(account: String, secret: String) -> bool { ginkgo_runtime::verify_credential_storage(&account, &secret) }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/session.rs:95</sub>

## utilities

- `pub(super) fn edit_tasks( root: String, demo: bool, action: String, id: Option<String>, title: Option<String>, due: Option<String>, completed: Option…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:4</sub>
- `pub(super) async fn load_notices(force_refresh: bool) -> ReadOnlyResponse { let _access = SESSION_ACCESS.read().await; let result = match service() {…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:45</sub>
- `pub(super) fn load_demo_notices() -> ReadOnlyResponse { read_only_value(ginkgo_runtime::demo::demo_campus::load_demo_notices()) }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:54</sub>
- `pub(super) async fn load_cgyy( kind: String, site_id: i64, date: String, force_refresh: bool, ) -> ReadOnlyResponse { use ginkgo_core::application::C…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:58</sub>
- `pub(super) async fn execute_cgyy(command: String) -> ReadOnlyResponse { let Ok(_write) = CGYY_WRITE.try_lock() else { // A second submit while one is…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:80</sub>
- `pub(super) fn load_demo_cgyy(kind: String) -> ReadOnlyResponse { read_only_value(ginkgo_runtime::demo::demo_campus::load_demo_cgyy(kind)) }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:103</sub>
- `pub(super) async fn load_library_books( query: String, page: i64, sort: String, descending: bool, ) -> ReadOnlyResponse { let _access = SESSION_ACCES…` — Public OPAC search. Read-only, anonymous and bounded by the service.  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:108</sub>
- `pub(super) async fn load_shuttle_timetable() -> ReadOnlyResponse { let _access = SESSION_ACCESS.read().await; let result = match service() { Ok(servi…` — Published shuttle timetable. Public page, no identity, no ticketing.  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:125</sub>
- `pub(super) async fn load_library_holdings(bib_id: String) -> ReadOnlyResponse { let _access = SESSION_ACCESS.read().await; let result = match service…` — Public holdings for one bib id. The nested JSON string is decoded in Rust.  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:135</sub>
- `pub(super) async fn export_learning_snapshots(expected: String) -> LearningSnapshotResponse { let _access = SESSION_ACCESS.read().await; let result =…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:144</sub>
- `pub(super) async fn import_learning_snapshots( expected: String, bytes: Vec<u8>, ) -> ReadOnlyResponse { // Import must not race a network command or…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:164</sub>
- `pub(super) async fn load_library_loans(expected: String, page: u32) -> ReadOnlyResponse { let _access = SESSION_ACCESS.read().await; let result = asy…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:179</sub>
- `pub(super) async fn check_android_update(current: String) -> ReadOnlyResponse { read_only_value(ginkgo_runtime::check_update(&current).await) }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live/utilities.rs:192</sub>

## live

- `pub enum RouteChoice {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:26</sub>
- `pub enum SessionState {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:33</sub>
- `pub struct SessionResponse {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:39</sub>
    - `state: SessionState`  <sub>:40</sub>
    - `account: Option<String>`  <sub>:41</sub>
    - `name: Option<String>`  <sub>:42</sub>
    - `captcha_id: Option<String>`  <sub>:43</sub>
    - `captcha_image_url: Option<String>`  <sub>:44</sub>
    - `remembered: bool`  <sub>:45</sub>
    - `route: Option<RouteChoice>`  <sub>:46</sub>
    - `failure: Option<FailureCode>`  <sub>:47</sub>
    - `failure_detail: Option<String>`  <sub>:48</sub>
- `pub struct LiveScope {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:51</sub>
    - `campus: i32`  <sub>:52</sub>
    - `date: String`  <sub>:53</sub>
    - `force_refresh: bool`  <sub>:54</sub>
- `pub async fn login( account: String, password: String, captcha: Option<String>, remember: bool, ) -> SessionResponse { session::login(account, passwo…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:57</sub>
- `pub async fn restore_session() -> SessionResponse { session::restore_session().await }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:66</sub>
- `pub async fn sign_out() -> SessionResponse { session::sign_out().await }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:70</sub>
- `pub async fn set_route(route: RouteChoice) -> SessionResponse { session::set_route(route).await }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:74</sub>
- `pub async fn clear_cache() -> bool { session::clear_cache().await }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:78</sub>
- `pub async fn load_classrooms(scope: LiveScope, query: ClassroomQuery) -> ClassroomResponse { classroom::load_classrooms(scope, query).await }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:82</sub>
- `pub async fn load_schedule( term_id: Option<String>, week: Option<i32>, force_refresh: bool, ) -> ScheduleResponse { academic::load_schedule(term_id,…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:86</sub>
- `pub async fn load_today(force_refresh: bool) -> TodayResponse { academic::load_today(force_refresh).await }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:94</sub>
- `pub async fn load_checkin_today(force_refresh: bool) -> CheckInResponse { academic::load_checkin_today(force_refresh).await }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:98</sub>
- `pub async fn checkin_load_progress() -> ReadOnlyResponse { checkin::checkin_load_progress().await }` — Observe the current read without issuing any school request.  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:103</sub>
- `pub async fn load_checkin_on_date(date: String, force_refresh: bool) -> CheckInResponse { checkin::load_checkin_on_date(date, force_refresh).await }` — Historical day in Asia/Shanghai, yyyy-MM-dd; no sign-in submission.  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:108</sub>
- `pub struct GradeTermsResponse {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:112</sub>
    - `terms: Vec<ScheduleTerm>`  <sub>:113</sub>
    - `failure: Option<FailureCode>`  <sub>:114</sub>
    - `failure_detail: Option<String>`  <sub>:115</sub>
- `pub async fn load_grade_terms() -> GradeTermsResponse { academic::load_grade_terms().await }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:118</sub>
- `pub async fn load_grades(term_code: Option<String>, force_refresh: bool) -> GradeResponse { academic::load_grades(term_code, force_refresh).await }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:122</sub>
- `pub fn verify_credential_storage(account: String, secret: String) -> bool { session::verify_credential_storage(account, secret) }` — Device-acceptance diagnostic: write, read and delete one synthetic secret.  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:128</sub>
- `pub async fn load_library_venues(force_refresh: bool) -> LibraryVenuesResponse { library::load_library_venues(force_refresh).await }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:132</sub>
- `pub async fn load_library_areas(library_id: String) -> LibraryAreasResponse { library::load_library_areas(library_id).await }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:136</sub>
- `pub async fn load_library_slots(area_id: String) -> LibrarySlotsResponse { library::load_library_slots(area_id).await }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:140</sub>
- `pub async fn load_library_seats( area_id: String, slot_id: String, day: String, start: String, end: String, ) -> LibrarySeatsResponse { library::load…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:144</sub>
- `pub async fn load_library_bookings(force_refresh: bool) -> LibraryBookingsResponse { library::load_library_bookings(force_refresh).await }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:154</sub>
- `pub struct LibraryHistoryResponse {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:158</sub>
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
- `pub async fn load_library_history(page: i32, force_refresh: bool) -> LibraryHistoryResponse { library::load_library_history(page, force_refresh).awai…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:171</sub>
- `pub fn load_demo_library_history(page: i32) -> LibraryHistoryResponse { library::load_demo_library_history(page) }` — Synthetic page runs the same domain parser as live history.  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:176</sub>
- `pub async fn load_homework(force_refresh: bool) -> super::mirror::HomeworkResponse { homework::load_homework(force_refresh).await }` — Real SPOC list, API.md §7.1. Demo remains an explicit separate command.  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:181</sub>
- `pub struct HomeworkDetailResponse {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:185</sub>
    - `source_url: Option<String>`  <sub>:186</sub>
    - `content: Option<String>`  <sub>:187</sub>
    - `published_at: Option<String>`  <sub>:188</sub>
    - `due_at: Option<String>`  <sub>:189</sub>
    - `score: Option<String>`  <sub>:190</sub>
    - `status: String`  <sub>:191</sub>
    - `submitted_at: Option<String>`  <sub>:192</sub>
    - `stale: bool`  <sub>:193</sub>
    - `failure: Option<FailureCode>`  <sub>:194</sub>
- `pub async fn load_homework_detail( assignment_id: String, force_refresh: bool, ) -> HomeworkDetailResponse { homework::load_homework_detail(assignmen…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:197</sub>
- `pub struct ReadOnlyResponse {` — Sanitized domain JSON, never raw upstream data, credentials or tokens.  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:205</sub>
    - `payload: Option<String>`  <sub>:206</sub>
    - `stale: bool`  <sub>:207</sub>
    - `failure: Option<FailureCode>`  <sub>:208</sub>
- `pub async fn load_bykc(force_refresh: bool) -> ReadOnlyResponse { bykc::load_bykc(force_refresh).await }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:210</sub>
- `pub fn load_demo_bykc() -> ReadOnlyResponse { bykc::load_demo_bykc() }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:214</sub>
- `pub async fn load_bykc_chosen(force_refresh: bool) -> ReadOnlyResponse { bykc::load_bykc_chosen(force_refresh).await }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:218</sub>
- `pub async fn load_bykc_statistics(force_refresh: bool) -> ReadOnlyResponse { bykc::load_bykc_statistics(force_refresh).await }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:222</sub>
- `pub fn load_demo_bykc_chosen() -> ReadOnlyResponse { bykc::load_demo_bykc_chosen() }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:226</sub>
- `pub fn load_demo_bykc_statistics() -> ReadOnlyResponse { bykc::load_demo_bykc_statistics() }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:230</sub>
- `pub async fn load_graduate_part(report: bool, force_refresh: bool) -> ReadOnlyResponse { graduate::load_graduate_part(report, force_refresh).await }` — Independently cached sections, allowing Flutter to render the first response  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:236</sub>
- `pub fn load_demo_graduate_status() -> ReadOnlyResponse { graduate::load_demo_graduate_status() }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:240</sub>
- `pub fn load_demo_graduate() -> ReadOnlyResponse { graduate::load_demo_graduate() }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:244</sub>
- `pub fn edit_tasks( root: String, demo: bool, action: String, id: Option<String>, title: Option<String>, due: Option<String>, completed: Option<bool>,…` — Local CRUD only. Account identity comes from Rust, never a Dart-supplied identifier.  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:249</sub>
- `pub async fn load_notices(force_refresh: bool) -> ReadOnlyResponse { utilities::load_notices(force_refresh).await }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:261</sub>
- `pub fn load_demo_notices() -> ReadOnlyResponse { utilities::load_demo_notices() }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:265</sub>
- `pub async fn load_cgyy( kind: String, site_id: i64, date: String, force_refresh: bool, ) -> ReadOnlyResponse { utilities::load_cgyy(kind, site_id, da…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:269</sub>
- `pub async fn execute_cgyy(command: String) -> ReadOnlyResponse { utilities::execute_cgyy(command).await }` — User-confirmed CGYY commands; payload contains no upstream credentials.  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:279</sub>
- `pub fn load_demo_cgyy(kind: String) -> ReadOnlyResponse { utilities::load_demo_cgyy(kind) }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:283</sub>
- `pub async fn load_library_books( query: String, page: i64, sort: String, descending: bool, ) -> ReadOnlyResponse { utilities::load_library_books(quer…` — Public OPAC search (read-only, anonymous). Payload is the projected page.  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:288</sub>
- `pub async fn load_shuttle_timetable() -> ReadOnlyResponse { utilities::load_shuttle_timetable().await }` — Published shuttle timetable (official page). Read-only, no ticketing.  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:298</sub>
- `pub async fn load_library_holdings(bib_id: String) -> ReadOnlyResponse { utilities::load_library_holdings(bib_id).await }` — Public holdings for one bib id; the nested JSON string never crosses the bridge.  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:303</sub>
- `pub struct LearningSnapshotResponse {` — Transient archive bytes. Hosts must use explicitly opted-in encrypted storage.  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:308</sub>
    - `bytes: Option<Vec<u8>>`  <sub>:309</sub>
    - `failure: Option<FailureCode>`  <sub>:310</sub>
- `pub async fn export_learning_snapshots(expected_account: String) -> LearningSnapshotResponse { utilities::export_learning_snapshots(expected_account)…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:312</sub>
- `pub async fn import_learning_snapshots( expected_account: String, bytes: Vec<u8>, ) -> ReadOnlyResponse { utilities::import_learning_snapshots(expect…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:315</sub>
- `pub fn library_loans_portal_url() -> String { ginkgo_runtime::library_loans_portal_url() }` — Public website metadata only. Does not initialize an authenticated session.  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:324</sub>
- `pub async fn load_library_loans(expected_account: String, page: u32) -> ReadOnlyResponse { utilities::load_library_loans(expected_account, page).awai…` — Explicit private read, scoped to the caller's account. No disk cache or writes.  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:329</sub>
- `pub async fn load_library_stats(force_refresh: bool) -> ReadOnlyResponse { library::load_library_stats(force_refresh).await }` — Public counts only. No school identity or library token is serialized.  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:334</sub>
- `pub fn load_demo_library_stats() -> ReadOnlyResponse { library::load_demo_library_stats() }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:337</sub>
- `pub async fn check_android_update(current: String) -> ReadOnlyResponse { utilities::check_android_update(current).await }` — Deliberately independent from login, school routes and account caches.  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:342</sub>
- `pub struct MutationResponse {` — User-confirmed write. Never retries the mutation and never exposes raw upstream text.  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:347</sub>
    - `state: String`  <sub>:348</sub>
    - `message: String`  <sub>:349</sub>
- `pub async fn submit_checkin(course_id: String) -> MutationResponse { checkin::submit_checkin(course_id).await }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:352</sub>
- `pub async fn reserve_library_seat( area_id: String, seat_id: String, slot: crate::api::mirror::LibrarySlot, ) -> MutationResponse { library::reserve_…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:356</sub>
- `pub async fn perform_library_action(booking_id: String, action: String) -> MutationResponse { library::perform_library_action(booking_id, action).awa…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/live.rs:363</sub>

## academic

- `pub(super) fn load_rule_examples() -> RuleExamples { match application::demo_rules() { Ok((day, snapshot)) => RuleExamples { local_date: day.local_da…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror/academic.rs:4</sub>
- `pub(super) fn load_demo_schedule() -> ScheduleResponse { match application::demo_schedule::load() { Ok(bundle) => ScheduleResponse { term_id: bundle …`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror/academic.rs:37</sub>
- `pub(super) fn load_demo_grades() -> GradeResponse { match application::demo_grades::load() { Ok(bundle) => GradeResponse { term_id: bundle.term_id, s…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror/academic.rs:119</sub>
- `pub(super) fn load_demo_today() -> TodayResponse { match application::demo_today::load() { Ok(bundle) => TodayResponse { date: bundle.date, courses: …`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror/academic.rs:163</sub>
- `pub(super) fn load_demo_homework() -> HomeworkResponse { match application::demo_homework::load() { Ok(bundle) => HomeworkResponse { term_name: bundl…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror/academic.rs:191</sub>
- `pub(super) fn load_demo_checkin() -> CheckInResponse { match application::demo_checkin::load() { Ok(day) => CheckInResponse { date: day.date, courses…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror/academic.rs:237</sub>

## classroom

- `pub(super) fn load_demo_classrooms(query: ClassroomQuery) -> ClassroomResponse { let sort = match query.sort { ClassroomSort::Name => classroom_domai…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror/classroom.rs:4</sub>
- `pub(super) fn load_query_dates(instant: String) -> QueryDates { match application::demo_repository::query_dates(&instant) { Ok((today, tomorrow)) => …`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror/classroom.rs:62</sub>
- `pub(super) fn query_demo_classrooms(scope: DemoScope, query: ClassroomQuery) -> ClassroomResponse { use std::sync::{Mutex, OnceLock}; static REPOSITO…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror/classroom.rs:77</sub>

## library

- `pub(super) fn load_demo_library() -> LibraryDemoResponse { match application::demo_library::load() { Ok(library) => LibraryDemoResponse { venues: lib…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror/library.rs:4</sub>

## mirror

- `pub fn init_app() { flutter_rust_bridge::setup_default_user_utils(); }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:6</sub>
- `pub enum ClassroomSort {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:11</sub>
- `pub struct ClassroomQuery {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:17</sub>
    - `search: String`  <sub>:18</sub>
    - `section: i32`  <sub>:19</sub>
    - `minimum_free_sections: i32`  <sub>:20</sub>
    - `minimum_consecutive_sections: i32`  <sub>:21</sub>
    - `building: Option<String>`  <sub>:22</sub>
    - `sort: ClassroomSort`  <sub>:23</sub>
- `pub struct SectionState {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:26</sub>
    - `number: i32`  <sub>:27</sub>
    - `available: bool`  <sub>:28</sub>
- `pub struct ClassroomRow {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:31</sub>
    - `id: String`  <sub>:32</sub>
    - `name: String`  <sub>:33</sub>
    - `floor: String`  <sub>:34</sub>
    - `sections: Vec<i32>`  <sub>:35</sub>
    - `longest_run: i32`  <sub>:36</sub>
    - `section_states: Vec<SectionState>`  <sub>:37</sub>
- `pub struct ClassroomBuilding {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:40</sub>
    - `name: String`  <sub>:41</sub>
    - `rooms: Vec<ClassroomRow>`  <sub>:42</sub>
- `pub enum FailureCode {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:44</sub>
- `pub struct ClassroomResponse {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:80</sub>
    - `buildings: Vec<ClassroomBuilding>`  <sub>:81</sub>
    - `room_count: i32`  <sub>:82</sub>
    - `building_count: i32`  <sub>:83</sub>
    - `free_slot_count: i32`  <sub>:84</sub>
    - `fetched_at: Option<String>`  <sub>:85</sub>
    - `from_cache: bool`  <sub>:86</sub>
    - `failure: Option<FailureCode>`  <sub>:87</sub>
    - `failure_detail: Option<String>`  <sub>:88</sub>
- `pub fn load_demo_classrooms(query: ClassroomQuery) -> ClassroomResponse { classroom::load_demo_classrooms(query) }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:91</sub>
- `pub struct RuleExamples {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:95</sub>
    - `local_date: String`  <sub>:96</sub>
    - `minutes_since_midnight: i32`  <sub>:97</sub>
    - `time_zone: String`  <sub>:98</sub>
    - `cached_weeks: Vec<i32>`  <sub>:99</sub>
    - `selected_week: i32`  <sub>:100</sub>
    - `course_names: Vec<String>`  <sub>:101</sub>
    - `failure: Option<FailureCode>`  <sub>:102</sub>
- `pub fn load_rule_examples() -> RuleExamples { academic::load_rule_examples() }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:105</sub>
- `pub struct ScheduleTerm {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:109</sub>
    - `id: String`  <sub>:110</sub>
    - `name: String`  <sub>:111</sub>
    - `selected: bool`  <sub>:112</sub>
- `pub struct ScheduleWeek {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:115</sub>
    - `number: i32`  <sub>:116</sub>
    - `start_date: String`  <sub>:117</sub>
    - `end_date: String`  <sub>:118</sub>
    - `current: bool`  <sub>:119</sub>
- `pub struct ScheduleCourse {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:122</sub>
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
- `pub struct ScheduleExam {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:135</sub>
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
- `pub struct ScheduleResponse {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:150</sub>
    - `terms: Vec<ScheduleTerm>`  <sub>:151</sub>
    - `weeks: Vec<ScheduleWeek>`  <sub>:152</sub>
    - `term_id: String`  <sub>:153</sub>
    - `week_number: i32`  <sub>:154</sub>
    - `courses: Vec<ScheduleCourse>`  <sub>:155</sub>
    - `exams: Vec<ScheduleExam>`  <sub>:156</sub>
    - `fetched_at: Option<String>`  <sub>:157</sub>
    - `failure: Option<FailureCode>`  <sub>:158</sub>
    - `failure_detail: Option<String>`  <sub>:159</sub>
- `pub fn load_demo_schedule() -> ScheduleResponse { academic::load_demo_schedule() }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:162</sub>
- `pub struct GradeCourse {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:166</sub>
    - `id: String`  <sub>:167</sub>
    - `name: String`  <sub>:168</sub>
    - `code: Option<String>`  <sub>:169</sub>
    - `credit: Option<f64>`  <sub>:170</sub>
    - `score: String`  <sub>:171</sub>
    - `score_value: Option<f64>`  <sub>:172</sub>
    - `score_type: Option<String>`  <sub>:173</sub>
    - `course_type: Option<String>`  <sub>:174</sub>
- `pub struct GradeSummary {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:177</sub>
    - `course_count: i32`  <sub>:178</sub>
    - `credit_total: f64`  <sub>:179</sub>
    - `weighted_average: Option<f64>`  <sub>:180</sub>
    - `grade_point_average: Option<f64>`  <sub>:181</sub>
- `pub struct GradeResponse {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:184</sub>
    - `term_id: String`  <sub>:185</sub>
    - `courses: Vec<GradeCourse>`  <sub>:186</sub>
    - `summary: GradeSummary`  <sub>:187</sub>
    - `fetched_at: Option<String>`  <sub>:188</sub>
    - `failure: Option<FailureCode>`  <sub>:189</sub>
    - `failure_detail: Option<String>`  <sub>:190</sub>
- `pub fn load_demo_grades() -> GradeResponse { academic::load_demo_grades() }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:193</sub>
- `pub struct TodayCourse {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:197</sub>
    - `name: String`  <sub>:198</sub>
    - `place: Option<String>`  <sub>:199</sub>
    - `time: Option<String>`  <sub>:200</sub>
    - `short_name: Option<String>`  <sub>:201</sub>
- `pub struct TodayResponse {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:204</sub>
    - `date: String`  <sub>:205</sub>
    - `courses: Vec<TodayCourse>`  <sub>:206</sub>
    - `fetched_at: Option<String>`  <sub>:207</sub>
    - `failure: Option<FailureCode>`  <sub>:208</sub>
    - `failure_detail: Option<String>`  <sub>:209</sub>
- `pub fn load_demo_today() -> TodayResponse { academic::load_demo_today() }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:212</sub>
- `pub enum HomeworkStatus {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:216</sub>
- `pub struct HomeworkItem {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:222</sub>
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
- `pub struct HomeworkResponse {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:236</sub>
    - `term_name: String`  <sub>:237</sub>
    - `term_code: String`  <sub>:238</sub>
    - `items: Vec<HomeworkItem>`  <sub>:239</sub>
    - `failure: Option<FailureCode>`  <sub>:240</sub>
    - `failure_detail: Option<String>`  <sub>:241</sub>
- `pub fn load_demo_homework() -> HomeworkResponse { academic::load_demo_homework() }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:244</sub>
- `pub struct QueryDates {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:248</sub>
    - `today: String`  <sub>:249</sub>
    - `tomorrow: String`  <sub>:250</sub>
    - `failure: Option<FailureCode>`  <sub>:251</sub>
- `pub fn load_query_dates(instant: String) -> QueryDates { classroom::load_query_dates(instant) }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:253</sub>
- `pub struct DemoScope {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:257</sub>
    - `campus: i32`  <sub>:258</sub>
    - `date: String`  <sub>:259</sub>
    - `force_refresh: bool`  <sub>:260</sub>
- `pub fn query_demo_classrooms(scope: DemoScope, query: ClassroomQuery) -> ClassroomResponse { classroom::query_demo_classrooms(scope, query) }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:263</sub>
- `pub enum CheckInStatus {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:267</sub>
- `pub struct CheckInCourse {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:273</sub>
    - `id: String`  <sub>:274</sub>
    - `course_id: Option<String>`  <sub>:275</sub>
    - `course_num: Option<String>`  <sub>:276</sub>
    - `course_name: String`  <sub>:277</sub>
    - `begins_at: String`  <sub>:278</sub>
    - `ends_at: String`  <sub>:279</sub>
    - `status: CheckInStatus`  <sub>:280</sub>
    - `teacher_name: Option<String>`  <sub>:281</sub>
    - `classroom_name: Option<String>`  <sub>:282</sub>
    - `merged_record_count: i32`  <sub>:283</sub>
    - `conflicting: bool`  <sub>:284</sub>
    - `sign_in_allowed: Option<bool>` — Explicit false also covers merged sessions containing multiple upstream IDs.  <sub>:286</sub>
- `pub struct CheckInResponse {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:289</sub>
    - `date: String` — School-local date, yyyy-MM-dd.  <sub>:291</sub>
    - `courses: Vec<CheckInCourse>`  <sub>:292</sub>
    - `fetched_at: Option<String>`  <sub>:293</sub>
    - `from_cache: bool`  <sub>:294</sub>
    - `stale: bool`  <sub>:295</sub>
    - `failure: Option<FailureCode>`  <sub>:296</sub>
    - `failure_detail: Option<String>`  <sub>:297</sub>
- `pub fn load_demo_checkin() -> CheckInResponse { academic::load_demo_checkin() }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:321</sub>
- `pub struct LibraryVenue {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:325</sub>
    - `id: String`  <sub>:326</sub>
    - `name: String`  <sub>:327</sub>
    - `free: i32`  <sub>:328</sub>
    - `total: i32`  <sub>:329</sub>
- `pub struct LibraryArea {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:332</sub>
    - `id: String`  <sub>:333</sub>
    - `name: String`  <sub>:334</sub>
    - `free: i32`  <sub>:335</sub>
    - `total: i32`  <sub>:336</sub>
- `pub struct LibrarySlot {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:339</sub>
    - `id: String`  <sub>:340</sub>
    - `day: String`  <sub>:341</sub>
    - `start: String`  <sub>:342</sub>
    - `end: String`  <sub>:343</sub>
- `pub struct LibrarySeat {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:346</sub>
    - `id: String`  <sub>:347</sub>
    - `name: String`  <sub>:348</sub>
    - `status_name: String`  <sub>:349</sub>
    - `available: bool`  <sub>:350</sub>
- `pub struct LibraryBooking {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:353</sub>
    - `id: String`  <sub>:354</sub>
    - `title: String`  <sub>:355</sub>
    - `area_name: String`  <sub>:356</sub>
    - `seat_number: String`  <sub>:357</sub>
    - `day: String`  <sub>:358</sub>
    - `start_time: String`  <sub>:359</sub>
    - `end_time: String`  <sub>:360</sub>
    - `status_name: String`  <sub>:361</sub>
    - `actions: Option<Vec<String>>`  <sub>:362</sub>
- `pub struct LibraryVenuesResponse {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:365</sub>
    - `venues: Vec<LibraryVenue>`  <sub>:366</sub>
    - `fetched_at: Option<String>`  <sub>:367</sub>
    - `from_cache: bool`  <sub>:368</sub>
    - `stale: bool`  <sub>:369</sub>
    - `failure: Option<FailureCode>`  <sub>:370</sub>
    - `failure_detail: Option<String>`  <sub>:371</sub>
- `pub struct LibraryAreasResponse {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:374</sub>
    - `areas: Vec<LibraryArea>`  <sub>:375</sub>
    - `failure: Option<FailureCode>`  <sub>:376</sub>
    - `failure_detail: Option<String>`  <sub>:377</sub>
- `pub struct LibrarySlotsResponse {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:380</sub>
    - `slots: Vec<LibrarySlot>`  <sub>:381</sub>
    - `failure: Option<FailureCode>`  <sub>:382</sub>
    - `failure_detail: Option<String>`  <sub>:383</sub>
- `pub struct LibrarySeatsResponse {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:386</sub>
    - `seats: Vec<LibrarySeat>`  <sub>:387</sub>
    - `failure: Option<FailureCode>`  <sub>:388</sub>
    - `failure_detail: Option<String>`  <sub>:389</sub>
- `pub struct LibraryBookingsResponse {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:392</sub>
    - `bookings: Vec<LibraryBooking>`  <sub>:393</sub>
    - `fetched_at: Option<String>`  <sub>:394</sub>
    - `from_cache: bool`  <sub>:395</sub>
    - `stale: bool`  <sub>:396</sub>
    - `failure: Option<FailureCode>`  <sub>:397</sub>
    - `failure_detail: Option<String>`  <sub>:398</sub>
- `pub struct LibraryDemoResponse {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:401</sub>
    - `venues: Vec<LibraryVenue>`  <sub>:402</sub>
    - `areas: Vec<LibraryArea>`  <sub>:403</sub>
    - `slots: Vec<LibrarySlot>`  <sub>:404</sub>
    - `seats: Vec<LibrarySeat>`  <sub>:405</sub>
    - `bookings: Vec<LibraryBooking>`  <sub>:406</sub>
- `pub(super) fn library_venue(value: ginkgo_core::features::library::LibraryVenue) -> LibraryVenue { LibraryVenue { id: value.id, name: value.name, fre…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:409</sub>
- `pub(super) fn library_area(value: ginkgo_core::features::library::LibraryArea) -> LibraryArea { LibraryArea { id: value.id, name: value.name, free: v…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:418</sub>
- `pub(super) fn library_slot(value: ginkgo_core::features::library::LibrarySlot) -> LibrarySlot { LibrarySlot { id: value.id, day: value.day, start: va…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:427</sub>
- `pub(super) fn library_seat(value: ginkgo_core::features::library::LibrarySeat) -> LibrarySeat { LibrarySeat { id: value.id, name: value.name, status_…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:436</sub>
- `pub(super) fn library_booking( value: ginkgo_core::features::library::LibraryBooking, ) -> LibraryBooking { let actions = Some(ginkgo_core::features:…`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:445</sub>
- `pub fn load_demo_library() -> LibraryDemoResponse { library::load_demo_library() }`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/mirror.rs:462</sub>

## reminder_planning

- `pub struct CourseReminderSeed {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/reminder_planning.rs:4</sub>
    - `id: String`  <sub>:5</sub>
    - `week_start: String`  <sub>:6</sub>
    - `day: i32`  <sub>:7</sub>
    - `starts_at: String`  <sub>:8</sub>
    - `ends_at: String`  <sub>:9</sub>
- `pub struct TaskReminderSeed {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/reminder_planning.rs:12</sub>
    - `id: String`  <sub>:13</sub>
    - `due: String`  <sub>:14</sub>
    - `completed: bool`  <sub>:15</sub>
- `pub struct PlannedReminder {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/reminder_planning.rs:18</sub>
    - `key: String`  <sub>:19</sub>
    - `group: String`  <sub>:20</sub>
    - `at_millis: i64`  <sub>:21</sub>
    - `expires_millis: i64`  <sub>:22</sub>
- `pub struct ReminderPlanResponse {`  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/reminder_planning.rs:25</sub>
    - `plans: Vec<PlannedReminder>`  <sub>:26</sub>
    - `skipped: u32`  <sub>:27</sub>
    - `unsupported: bool`  <sub>:28</sub>
- `pub fn plan_course_task_reminders( courses: Vec<CourseReminderSeed>, tasks: Vec<TaskReminderSeed>, now_millis: i64, ) -> ReminderPlanResponse { // Bo…` — Data-only plans. Calling this never requests notification permissions or sends notifications.  
  <sub>rust/crates/ginkgo_flutter_bridge/src/api/reminder_planning.rs:33</sub>
