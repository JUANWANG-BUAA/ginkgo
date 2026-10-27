# 上游服务（ginkgo_upstream::services）

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。

业务会话、token、查询缓存与协议时序。

## cache

- `pub(crate) const CACHE_TTL: Duration = Duration::from_secs(300);`  
  <sub>rust/crates/ginkgo_upstream/src/services/cache.rs:11</sub>
- `pub(crate) struct Timed<T> {`  
  <sub>rust/crates/ginkgo_upstream/src/services/cache.rs:14</sub>
    - `fetched_at: Instant`  <sub>:15</sub>
    - `timestamp: String`  <sub>:16</sub>
    - `value: T`  <sub>:17</sub>
    - `restored: bool` — Restored disk values never count as a fresh network/cache success.  <sub>:19</sub>
- `pub(crate) struct SnapshotCache<K, V> {`  
  <sub>rust/crates/ginkgo_upstream/src/services/cache.rs:22</sub>
- `pub fn fresh(&self, key: &K) -> Option<&Timed<V>> { self.entries .get(key) .filter(\|entry\| !entry.restored && entry.fetched_at.elapsed() < CACHE_TTL)…`  
  <sub>rust/crates/ginkgo_upstream/src/services/cache.rs:45</sub>
- `pub fn any(&self, key: &K) -> Option<&Timed<V>> { self.entries.get(key) }`  
  <sub>rust/crates/ginkgo_upstream/src/services/cache.rs:51</sub>
- `pub fn begin(&mut self, key: &K) -> u64 { self.next_ticket = self.next_ticket.wrapping_add(1); let ticket = self.next_ticket; self.tickets.insert(key…` — Issue the writer ticket for a new request on this key. Call it before  
  <sub>rust/crates/ginkgo_upstream/src/services/cache.rs:57</sub>
- `pub fn insert_if_current(&mut self, key: K, ticket: u64, value: V) -> String { let timestamp = now_shanghai(); if self.tickets.get(&key).copied() == …` — Insert only when no newer request for the same key has started. The  
  <sub>rust/crates/ginkgo_upstream/src/services/cache.rs:67</sub>

## protocol

- `pub(super) fn number(v: &Value) -> Option<i64> { crate::features::cgyy::number(v) }`  
  <sub>rust/crates/ginkgo_upstream/src/services/cgyy_booking_service/protocol.rs:11</sub>
- `pub(super) fn text(v: &Value) -> Option<&str> { v.as_str().filter(\|s\| !s.is_empty()) }`  
  <sub>rust/crates/ginkgo_upstream/src/services/cgyy_booking_service/protocol.rs:15</sub>
- `pub(super) fn data(value: &Value) -> Result<&Value, AppError> { crate::features::cgyy::envelope(value) }`  
  <sub>rust/crates/ginkgo_upstream/src/services/cgyy_booking_service/protocol.rs:19</sub>
- `pub(super) fn validate(booking: &BookingRequest) -> Result<(), AppError> { if booking.site_id <= 0 \|\| booking.space_id <= 0 \|\| booking.time_ids.is_em…`  
  <sub>rust/crates/ginkgo_upstream/src/services/cgyy_booking_service/protocol.rs:23</sub>
- `pub(super) fn choices(value: &Value, date: &str) -> Result<Vec<BookingChoice>, AppError> { // Reuse strict read parser's availability semantics; neve…`  
  <sub>rust/crates/ginkgo_upstream/src/services/cgyy_booking_service/protocol.rs:54</sub>
- `pub(super) fn selections(value: &Value, booking: &BookingRequest) -> Result<String, AppError> { let available = choices(value, &booking.date)?; if !b…`  
  <sub>rust/crates/ginkgo_upstream/src/services/cgyy_booking_service/protocol.rs:84</sub>
- `pub(super) fn purposes(value: &Value) -> Vec<Purpose> { fn visit(value: &Value, result: &mut BTreeMap<i64, String>) { match value { Value::Array(item…`  
  <sub>rust/crates/ginkgo_upstream/src/services/cgyy_booking_service/protocol.rs:109</sub>
- `pub(super) fn base_form(context: &BookingContext) -> BTreeMap<String, String> { let mut form = BTreeMap::from([ ("venueSiteId".into(), context.bookin…`  
  <sub>rust/crates/ginkgo_upstream/src/services/cgyy_booking_service/protocol.rs:141</sub>
- `pub(super) fn encrypt(text: &str, secret: &str) -> Result<String, AppError> { use aes::{Aes128, Aes192, Aes256}; use base64::Engine; use cipher::{Blo…`  
  <sub>rust/crates/ginkgo_upstream/src/services/cgyy_booking_service/protocol.rs:156</sub>
- `pub(super) fn protocol_point(offset: f64, width: Option<f64>) -> Result<String, AppError> { if !offset.is_finite() \|\| !(0.0..=10_000.0).contains(&off…` — Upstream captcha coordinate: `310 * offset / width` (§6B.1). Raw device or  
  <sub>rust/crates/ginkgo_upstream/src/services/cgyy_booking_service/protocol.rs:184</sub>
- `pub(super) fn trade_matches(draft: &str, response: &str, row: &Value) -> bool { let row = row["tradeNo"].as_str().unwrap_or_default(); [draft, respon…` — A trade number only narrows the match when both sides report one; an absent  
  <sub>rust/crates/ginkgo_upstream/src/services/cgyy_booking_service/protocol.rs:204</sub>

## cgyy_booking_service

- `pub(crate) struct BookingSafety {`  
  <sub>rust/crates/ginkgo_upstream/src/services/cgyy_booking_service.rs:24</sub>
    - `pending: bool`  <sub>:25</sub>
    - `review: Option<ReviewCredential>`  <sub>:26</sub>
- `pub(crate) struct ReviewCredential {`  
  <sub>rust/crates/ginkgo_upstream/src/services/cgyy_booking_service.rs:28</sub>
    - `id: String`  <sub>:29</sub>
    - `created: Instant`  <sub>:30</sub>
- `pub(super) struct BookingOwner {`  
  <sub>rust/crates/ginkgo_upstream/src/services/cgyy_booking_service.rs:34</sub>
    - `account: String`  <sub>:35</sub>
    - `generation: u64`  <sub>:36</sub>
- `pub(crate) struct BookingContext {`  
  <sub>rust/crates/ginkgo_upstream/src/services/cgyy_booking_service.rs:39</sub>
- `pub(super) fn booking_owner(&self) -> Result<BookingOwner, AppError> { let identity = self.identity.lock(); Ok(BookingOwner { account: identity .auth…`  
  <sub>rust/crates/ginkgo_upstream/src/services/cgyy_booking_service.rs:57</sub>
- `pub(super) fn check_booking_owner(&self, owner: &BookingOwner) -> Result<(), AppError> { let identity = self.identity.lock(); if identity.generation …`  
  <sub>rust/crates/ginkgo_upstream/src/services/cgyy_booking_service.rs:69</sub>

## cgyy_service

- `pub(super) async fn cgyy_token(&self, renew: bool) -> Result<String, AppError> { let owner = self.booking_owner()?; { let identity = self.identity.lo…`  
  <sub>rust/crates/ginkgo_upstream/src/services/cgyy_service.rs:10</sub>

## checkin_service

- `pub(crate) struct CheckInProgress {` — Local timing only: no account, URLs, cookies, course names or session IDs.  
  <sub>rust/crates/ginkgo_upstream/src/services/checkin_service.rs:21</sub>

## contracts

- `pub fn execute_contract(contract: &str, version: u32, input: Value) -> Result<Value, AppError> { if version != 1 { return Err(AppError::new(ErrorCode…`  
  <sub>rust/crates/ginkgo_upstream/src/services/contracts.rs:17</sub>

## demo_campus

- `pub fn load_demo_bykc() -> Result<crate::features::bykc::Catalog, AppError> { let fixture: serde_json::Value = serde_json::from_str(include_str!( "..…`  
  <sub>rust/crates/ginkgo_upstream/src/services/demo_campus.rs:4</sub>
- `pub fn load_demo_bykc_chosen() -> Result<crate::features::bykc::ChosenCourses, AppError> { let fixture: serde_json::Value = serde_json::from_str(incl…`  
  <sub>rust/crates/ginkgo_upstream/src/services/demo_campus.rs:17</sub>
- `pub fn load_demo_bykc_statistics() -> Result<crate::features::bykc::LearningStatistics, AppError> { let fixture: serde_json::Value = serde_json::from…`  
  <sub>rust/crates/ginkgo_upstream/src/services/demo_campus.rs:34</sub>
- `pub fn load_demo_graduate() -> Result<crate::features::graduate::AcademicData, AppError> { let fixture: serde_json::Value = serde_json::from_str(incl…`  
  <sub>rust/crates/ginkgo_upstream/src/services/demo_campus.rs:42</sub>
- `pub fn load_demo_notices() -> Result<Vec<crate::features::notices::Notice>, AppError> { let fixture: serde_json::Value = serde_json::from_str(include…`  
  <sub>rust/crates/ginkgo_upstream/src/services/demo_campus.rs:53</sub>
- `pub fn load_demo_cgyy(kind: String) -> Result<serde_json::Value, AppError> { let fixture: serde_json::Value = serde_json::from_str(match kind.as_str(…`  
  <sub>rust/crates/ginkgo_upstream/src/services/demo_campus.rs:65</sub>
- `pub fn graduate_status() -> Result<crate::features::graduate::AcademicData, AppError> { let status = serde_json::json!({"datas":{"xsjcxxcx":{"rows":[…`  
  <sub>rust/crates/ginkgo_upstream/src/services/demo_campus.rs:76</sub>
- `pub fn library_history( page: i32, ) -> Result<crate::features::library::LibraryHistoryPage, AppError> { let fixture: serde_json::Value = serde_json:…`  
  <sub>rust/crates/ginkgo_upstream/src/services/demo_campus.rs:85</sub>
- `pub fn library_stats() -> Result<Vec<crate::features::library_stats::CampusStats>, AppError> { let fixture: serde_json::Value = serde_json::from_str(…`  
  <sub>rust/crates/ginkgo_upstream/src/services/demo_campus.rs:102</sub>

## demo_checkin

- `pub struct DemoCheckIn {`  
  <sub>rust/crates/ginkgo_upstream/src/services/demo_checkin.rs:8</sub>
    - `date: String`  <sub>:9</sub>
    - `courses: Vec<CheckInCourse>`  <sub>:10</sub>
- `pub fn load() -> Result<DemoCheckIn, AppError> { let fixture: Value = serde_json::from_str(include_str!( "../../../../../fixtures/checkin/course-sche…`  
  <sub>rust/crates/ginkgo_upstream/src/services/demo_checkin.rs:13</sub>

## demo_grades

- `pub struct DemoGrades {`  
  <sub>rust/crates/ginkgo_upstream/src/services/demo_grades.rs:8</sub>
    - `term_id: String`  <sub>:9</sub>
    - `courses: Vec<GradeCourse>`  <sub>:10</sub>
    - `summary: GradeSummary`  <sub>:11</sub>
- `pub fn load() -> Result<DemoGrades, AppError> { let text = include_str!("../../../../../fixtures/grades/normal-v1.json"); let fixture: Value = serde_…`  
  <sub>rust/crates/ginkgo_upstream/src/services/demo_grades.rs:14</sub>

## demo_homework

- `pub struct DemoHomework {`  
  <sub>rust/crates/ginkgo_upstream/src/services/demo_homework.rs:8</sub>
    - `term_name: String`  <sub>:9</sub>
    - `term_code: String`  <sub>:10</sub>
    - `page: HomeworkPage`  <sub>:11</sub>
- `pub fn load() -> Result<DemoHomework, AppError> { let fixture: Value = serde_json::from_str(include_str!( "../../../../../fixtures/homework/spoc-page…`  
  <sub>rust/crates/ginkgo_upstream/src/services/demo_homework.rs:14</sub>

## demo_library

- `pub struct DemoLibrary {`  
  <sub>rust/crates/ginkgo_upstream/src/services/demo_library.rs:10</sub>
    - `venues: Vec<LibraryVenue>`  <sub>:11</sub>
    - `areas: Vec<LibraryArea>`  <sub>:12</sub>
    - `slots: Vec<LibrarySlot>`  <sub>:13</sub>
    - `seats: Vec<LibrarySeat>`  <sub>:14</sub>
    - `bookings: Vec<LibraryBooking>`  <sub>:15</sub>
- `pub fn load() -> Result<DemoLibrary, AppError> { Ok(DemoLibrary { venues: library::parse_venues(&data("venues")?)?, areas: library::parse_areas(&data…`  
  <sub>rust/crates/ginkgo_upstream/src/services/demo_library.rs:44</sub>

## demo_repository

- `pub struct DemoRepository {`  
  <sub>rust/crates/ginkgo_upstream/src/services/demo_repository.rs:15</sub>
- `pub struct DemoQueryResult {`  
  <sub>rust/crates/ginkgo_upstream/src/services/demo_repository.rs:19</sub>
    - `result: FilterResult`  <sub>:20</sub>
    - `fetched_at: String`  <sub>:21</sub>
    - `from_cache: bool`  <sub>:22</sub>
- `pub fn query( &mut self, campus: i32, date: &str, force: bool, mut filter: FilterRequest, ) -> Result<DemoQueryResult, AppError> { if !(1..=3).contai…`  
  <sub>rust/crates/ginkgo_upstream/src/services/demo_repository.rs:26</sub>
- `pub fn query_dates(instant: &str) -> Result<(String, String), AppError> { let day = school_time::beijing_day(instant)?; let date = NaiveDate::parse_f…`  
  <sub>rust/crates/ginkgo_upstream/src/services/demo_repository.rs:92</sub>

## demo_schedule

- `pub struct DemoSchedule {`  
  <sub>rust/crates/ginkgo_upstream/src/services/demo_schedule.rs:8</sub>
    - `terms: Vec<Term>`  <sub>:9</sub>
    - `weeks: Vec<Week>`  <sub>:10</sub>
    - `week_number: i32`  <sub>:11</sub>
    - `courses: Vec<CourseMeeting>`  <sub>:12</sub>
    - `exams: Vec<Exam>`  <sub>:13</sub>
- `pub fn load() -> Result<DemoSchedule, AppError> { let terms = schedule::parse_terms(body(include_str!( "../../../../../fixtures/schedule/terms-normal…`  
  <sub>rust/crates/ginkgo_upstream/src/services/demo_schedule.rs:16</sub>

## demo_today

- `pub struct DemoToday {`  
  <sub>rust/crates/ginkgo_upstream/src/services/demo_today.rs:8</sub>
    - `date: String`  <sub>:9</sub>
    - `courses: Vec<TodayCourse>`  <sub>:10</sub>
- `pub fn load() -> Result<DemoToday, AppError> { let fixture: Value = serde_json::from_str(include_str!( "../../../../../fixtures/schedule/today-normal…`  
  <sub>rust/crates/ginkgo_upstream/src/services/demo_today.rs:13</sub>

## homework_service

- `pub(crate) type HomeworkCache = SnapshotCache<String, HomeworkData>;`  
  <sub>rust/crates/ginkgo_upstream/src/services/homework_service.rs:12</sub>
- `pub(crate) type HomeworkDetailCache = SnapshotCache<String, HomeworkDetail>;`  
  <sub>rust/crates/ginkgo_upstream/src/services/homework_service.rs:13</sub>

## capabilities

- `pub(super) async fn diagnose_homework(&self, id: &str) -> Vec<HomeworkCapabilityEvidence> { let _gate = self.homework_file_gate.lock().await; let mut…`  
  <sub>rust/crates/ginkgo_upstream/src/services/homework_submission_service/capabilities.rs:27</sub>

## journal

- `pub(super) fn configure(files: &mut HomeworkFiles, root: &str) -> Result<(), AppError> { let path = Path::new(root); if !path.is_absolute() { return …`  
  <sub>rust/crates/ginkgo_upstream/src/services/homework_submission_service/journal.rs:69</sub>
- `pub(super) fn restore(files: &mut HomeworkFiles, owner: &(String, u64)) -> Result<(), AppError> { let directory = account_directory(root(files)?, &ow…` — Rehydrate only Sent records. Ready receipts deliberately expire with process/identity.  
  <sub>rust/crates/ginkgo_upstream/src/services/homework_submission_service/journal.rs:99</sub>
- `pub(super) fn create(files: &HomeworkFiles, handle: &str, baseline: u32) -> Result<(), AppError> { let upload = files.uploads.get(handle).ok_or_else(…` — Persist before sending. A partial write remains as a fail-closed guard.  
  <sub>rust/crates/ginkgo_upstream/src/services/homework_submission_service/journal.rs:165</sub>
- `pub(super) fn clear(files: &HomeworkFiles, handle: &str) -> Result<(), AppError> { let upload = files.uploads.get(handle).ok_or_else(AppError::invali…` — Delete only the exact positive-verified record, never acknowledge a negative/unknown read.  
  <sub>rust/crates/ginkgo_upstream/src/services/homework_submission_service/journal.rs:194</sub>

## homework_submission_service

- `pub(crate) struct HomeworkFiles {`  
  <sub>rust/crates/ginkgo_upstream/src/services/homework_submission_service.rs:37</sub>

## learning_service

- `pub(crate) struct LearningSnapshots {`  
  <sub>rust/crates/ginkgo_upstream/src/services/learning_service.rs:11</sub>
- `pub fn clear(&self) { self.epoch.fetch_add(1, std::sync::atomic::Ordering::AcqRel); self.courses.lock().clear(); self.columns.lock().clear(); self.ca…`  
  <sub>rust/crates/ginkgo_upstream/src/services/learning_service.rs:21</sub>

## library_service

- `pub(crate) async fn library_token(&self) -> Result<String, AppError> { let cached = { self.identity.lock().library_token.clone() }; if let Some(token…`  
  <sub>rust/crates/ginkgo_upstream/src/services/library_service.rs:34</sub>

## library_stats_service

- `pub(crate) type LibraryStatsCache = SnapshotCache<String, Vec<CampusStats>>;`  
  <sub>rust/crates/ginkgo_upstream/src/services/library_stats_service.rs:7</sub>

## mod

- `pub fn demo_classrooms( search: String, section: i32, minimum_free_sections: i32, minimum_consecutive_sections: i32, building: Option<String>, sort: …`  
  <sub>rust/crates/ginkgo_upstream/src/services/mod.rs:41</sub>
- `pub fn demo_rules() -> Result<(school_time::SchoolDay, schedule::Snapshot), AppError> { #[derive(Deserialize)] struct TimeFixture { input: school_tim…`  
  <sub>rust/crates/ginkgo_upstream/src/services/mod.rs:62</sub>

## session_service

- `pub(crate) struct AuthenticatedIdentity {` — Published together so readers never observe an account without its profile.  
  <sub>rust/crates/ginkgo_upstream/src/services/session_service.rs:47</sub>
    - `account: String`  <sub>:48</sub>
    - `profile: UserProfile`  <sub>:49</sub>
- `pub(crate) struct PendingLogin {`  
  <sub>rust/crates/ginkgo_upstream/src/services/session_service.rs:52</sub>
- `pub(crate) struct Identity {` — All account-scoped authentication state has one lifetime and one reset.  
  <sub>rust/crates/ginkgo_upstream/src/services/session_service.rs:70</sub>
    - `authenticated: Option<AuthenticatedIdentity>`  <sub>:71</sub>
    - `pending_login: Option<PendingLogin>`  <sub>:72</sub>
    - `iclass: Option<IClassSession>`  <sub>:73</sub>
    - `library_token: Option<String>`  <sub>:74</sub>
    - `cgyy_token: Option<String>`  <sub>:75</sub>
    - `cgyy_booking: Option<super::cgyy_booking_service::BookingContext>`  <sub>:76</sub>
    - `generation: u64`  <sub>:77</sub>
- `pub struct SchoolClient<T: HttpTransport, V: CredentialVault> {`  
  <sub>rust/crates/ginkgo_upstream/src/services/session_service.rs:80</sub>
    - `session: Session<T>`  <sub>:81</sub>
    - `learning_gate: tokio::sync::Mutex<()>`  <sub>:82</sub>
    - `homework_files: Mutex<super::homework_submission_service::HomeworkFiles>`  <sub>:83</sub>
    - `homework_file_gate: tokio::sync::Mutex<()>`  <sub>:84</sub>
    - `vault: V`  <sub>:85</sub>
    - `identity: Mutex<Identity>`  <sub>:86</sub>
    - `route: StdMutex<RoutePreference>`  <sub>:87</sub>
    - `snapshots: ReadSnapshots`  <sub>:88</sub>
    - `bykc_access: tokio::sync::Mutex<()>`  <sub>:89</sub>
    - `checkin_request_gate: tokio::sync::Mutex<()>`  <sub>:90</sub>
    - `checkin_progress: Mutex<super::checkin_service::CheckInProgress>`  <sub>:91</sub>
    - `automatic_login_failure: Mutex<Option<(Instant, AppError)>>`  <sub>:93</sub>
    - `graduate_request_gate: tokio::sync::Mutex<()>`  <sub>:96</sub>
    - `library_login_gate: tokio::sync::Mutex<()>`  <sub>:97</sub>
    - `cgyy_mutation_gate: tokio::sync::Mutex<()>`  <sub>:101</sub>
- `pub fn new(session: Session<T>, vault: V) -> Self { Self { session, learning_gate: tokio::sync::Mutex::new(()), homework_files: Mutex::default(), hom…`  
  <sub>rust/crates/ginkgo_upstream/src/services/session_service.rs:105</sub>
- `pub(crate) fn set_authenticated(&self, account: String, profile: UserProfile) { let mut identity = self.identity.lock(); // Central invariant: the pu…`  
  <sub>rust/crates/ginkgo_upstream/src/services/session_service.rs:129</sub>
- `pub fn verify_vault_round_trip(&self, account: &str, secret: &str) -> bool { auth::vault::verify_vault_round_trip(&self.vault, account, secret) }` — Diagnostic used by device acceptance: write, read back and remove one  
  <sub>rust/crates/ginkgo_upstream/src/services/session_service.rs:160</sub>
- `pub fn lock_poison_events(&self) -> u64 { self.identity.poison_count() + self.checkin_progress.poison_count() + self.automatic_login_failure.poison_c…` — How often one of this client's in-memory locks was recovered from a  
  <sub>rust/crates/ginkgo_upstream/src/services/session_service.rs:171</sub>
- `pub(crate) fn preference(&self) -> RoutePreference { *lock_value(&self.route) }`  
  <sub>rust/crates/ginkgo_upstream/src/services/session_service.rs:180</sub>
- `pub(crate) fn current_account(&self) -> Result<String, AppError> { self.identity .lock() .authenticated .as_ref() .map(\|user\| user.account.clone()) .…`  
  <sub>rust/crates/ginkgo_upstream/src/services/session_service.rs:184</sub>
- `pub(crate) async fn silent_login(&self) -> Result<(), AppError> { let generation = self.school_generation.load(Ordering::Acquire); let _recovery = se…`  
  <sub>rust/crates/ginkgo_upstream/src/services/session_service.rs:193</sub>
- `pub(crate) async fn ensure_webvpn_session(&self) -> Result<(), AppError> { let generation = self.gateway_generation.load(Ordering::Acquire); let _rec…` — Establish the WebVPN gateway's own CAS session after an automatic route  
  <sub>rust/crates/ginkgo_upstream/src/services/session_service.rs:237</sub>
- `pub(crate) fn clear_caches(&self) { self.snapshots.clear(); { let mut identity = self.identity.lock(); identity.cgyy_token = None; identity.cgyy_book…`  
  <sub>rust/crates/ginkgo_upstream/src/services/session_service.rs:283</sub>
- `pub(crate) fn is_library_login_error(error: &AppError) -> bool { error.code == ErrorCode::SessionExpired && error.detail.as_deref() == Some("library_…` — booking.lib answers 200 with its own login-expired message; that only means  
  <sub>rust/crates/ginkgo_upstream/src/services/session_service.rs:309</sub>

## snapshots

- `pub(crate) type ClassroomCache = SnapshotCache<(i32, String), BTreeMap<String, Vec<Room>>>;`  
  <sub>rust/crates/ginkgo_upstream/src/services/snapshots.rs:17</sub>
- `pub(crate) type ScheduleCache = SnapshotCache<(Option<String>, Option<i32>), ScheduleData>;`  
  <sub>rust/crates/ginkgo_upstream/src/services/snapshots.rs:18</sub>
- `pub(crate) type TodayCache = SnapshotCache<String, Vec<TodayCourse>>;`  
  <sub>rust/crates/ginkgo_upstream/src/services/snapshots.rs:19</sub>
- `pub(crate) type GradeCache = SnapshotCache<String, GradeData>;`  
  <sub>rust/crates/ginkgo_upstream/src/services/snapshots.rs:20</sub>
- `pub(crate) type CheckInCache = SnapshotCache<String, Vec<CheckInCourse>>;`  
  <sub>rust/crates/ginkgo_upstream/src/services/snapshots.rs:21</sub>
- `pub(crate) type LibraryVenueCache = SnapshotCache<String, Vec<LibraryVenue>>;`  
  <sub>rust/crates/ginkgo_upstream/src/services/snapshots.rs:22</sub>
- `pub(crate) type LibraryBookingCache = SnapshotCache<String, Vec<LibraryBooking>>;`  
  <sub>rust/crates/ginkgo_upstream/src/services/snapshots.rs:23</sub>
- `pub(crate) struct ReadSnapshots {`  
  <sub>rust/crates/ginkgo_upstream/src/services/snapshots.rs:26</sub>
    - `learning: super::learning_service::LearningSnapshots`  <sub>:27</sub>
    - `classrooms: Mutex<ClassroomCache>`  <sub>:28</sub>
    - `schedules: Mutex<ScheduleCache>`  <sub>:29</sub>
    - `cgyy: Mutex<SnapshotCache<String, ginkgo_domain::ports::CgyyData>>`  <sub>:30</sub>
    - `notices: Mutex<SnapshotCache<String, Vec<crate::features::notices::Notice>>>`  <sub>:31</sub>
    - `graduate: Mutex<SnapshotCache<String, crate::features::graduate::AcademicData>>`  <sub>:32</sub>
    - `bykc: Mutex<SnapshotCache<String, crate::features::bykc::Catalog>>`  <sub>:33</sub>
    - `bykc_chosen: Mutex<SnapshotCache<String, crate::features::bykc::ChosenCourses>>`  <sub>:34</sub>
    - `homework: Mutex<super::homework_service::HomeworkCache>`  <sub>:37</sub>
    - `homework_details: Mutex<super::homework_service::HomeworkDetailCache>`  <sub>:38</sub>
    - `today: Mutex<TodayCache>`  <sub>:39</sub>
    - `grades: Mutex<GradeCache>`  <sub>:40</sub>
    - `checkin: Mutex<CheckInCache>`  <sub>:41</sub>
    - `library_stats: Mutex<super::library_stats_service::LibraryStatsCache>`  <sub>:42</sub>
    - `library_venues: Mutex<LibraryVenueCache>`  <sub>:43</sub>
    - `library_bookings: Mutex<LibraryBookingCache>`  <sub>:44</sub>
    - `library_history: Mutex<SnapshotCache<i32, LibraryHistoryPage>>`  <sub>:45</sub>
- `pub fn clear(&self) { self.learning.clear(); self.classrooms.lock().clear(); self.schedules.lock().clear(); self.cgyy.lock().clear(); self.notices.lo…`  
  <sub>rust/crates/ginkgo_upstream/src/services/snapshots.rs:49</sub>
- `pub fn poison_events(&self) -> u64 { self.classrooms.poison_count() + self.schedules.poison_count() + self.cgyy.poison_count() + self.notices.poison_…` — How often one of the snapshot locks was recovered from a poisoned state.  
  <sub>rust/crates/ginkgo_upstream/src/services/snapshots.rs:74</sub>

## updates_service

- `pub async fn check<T: HttpTransport + Sync>( transport: T, current: &str, ) -> Result<UpdateSummary, AppError> { let session = Session::new(transport…` — Caller provides a dedicated transport, never the account session.  
  <sub>rust/crates/ginkgo_upstream/src/services/updates_service.rs:9</sub>
