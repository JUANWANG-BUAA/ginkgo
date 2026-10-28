# 上游服务（ginkgo_upstream::services）

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
业务会话、token、查询缓存与协议时序。

## 目录

- [cache](#cache) (14)
- [campus_activities_service](#campusactivitiesservice) (1)
- [career_service](#careerservice) (1)
- [protocol](#protocol) (12)
- [cgyy_booking_service](#cgyybookingservice) (4)
- [cgyy_service](#cgyyservice) (1)
- [checkin_service](#checkinservice) (1)
- [contracts](#contracts) (1)
- [demo_campus](#democampus) (9)
- [demo_checkin](#democheckin) (2)
- [demo_grades](#demogrades) (2)
- [demo_homework](#demohomework) (2)
- [demo_library](#demolibrary) (2)
- [demo_repository](#demorepository) (4)
- [demo_schedule](#demoschedule) (2)
- [demo_today](#demotoday) (2)
- [homework_service](#homeworkservice) (2)
- [capabilities](#capabilities) (1)
- [journal](#journal) (11)
- [homework_submission_service](#homeworksubmissionservice) (1)
- [learning_service](#learningservice) (2)
- [library_service](#libraryservice) (1)
- [library_stats_service](#librarystatsservice) (1)
- [mod](#mod) (2)
- [session_service](#sessionservice) (18)
- [snapshots](#snapshots) (10)
- [updates_service](#updatesservice) (1)

## cache

- `pub(crate) const CACHE_TTL: Duration = Duration::from_secs(300);`
  <sub>const · rust/crates/ginkgo_upstream/src/services/cache.rs:11</sub>
- `pub(crate) struct Timed<T>`
  <sub>struct · rust/crates/ginkgo_upstream/src/services/cache.rs:14</sub>
    - `fetched_at: Instant`  <sub>:15</sub>
    - `timestamp: String`  <sub>:16</sub>
    - `value: T`  <sub>:17</sub>
    - `restored: bool` — Restored disk values never count as a fresh network/cache success.  <sub>:19</sub>
- `pub(crate) struct SnapshotCache<K, V>`
  <sub>struct · rust/crates/ginkgo_upstream/src/services/cache.rs:22</sub>
- `pub fn fresh(&self, key: &K) -> Option<&Timed<V>> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/cache.rs:45</sub>
- `pub fn any(&self, key: &K) -> Option<&Timed<V>> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/cache.rs:51</sub>
- `pub fn begin(&mut self, key: &K) -> u64 {…}` — Issue the writer ticket for a new request on this key. Call it before
  <sub>fn · rust/crates/ginkgo_upstream/src/services/cache.rs:57</sub>
- `pub fn insert_if_current(&mut self, key: K, ticket: u64, value: V) -> String {…}` — Insert only when no newer request for the same key has started. The
  <sub>fn · rust/crates/ginkgo_upstream/src/services/cache.rs:67</sub>
- `pub(super) fn entries(&self) -> impl Iterator<Item = (&K, &Timed<V>)> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/cache.rs:106</sub>
- `pub(super) fn restore(&mut self, key: K, value: V, timestamp: String, age: Duration) {…}` — Rebind only after archive validation and current authenticated-owner checks.
  <sub>fn · rust/crates/ginkgo_upstream/src/services/cache.rs:112</sub>
- `pub fn clear(&mut self) {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/cache.rs:123</sub>
- `pub fn resolve_current( &mut self, key: K, ticket: u64, result: Result<V, crate::AppError>, ) -> Result<super::DataOutcome<V>, crate::AppError> {…}` — Replace on success, including an empty value, unless a newer request
  <sub>fn · rust/crates/ginkgo_upstream/src/services/cache.rs:133</sub>
- `pub(crate) async fn read_with_snapshot<K, V, F>( cache: &crate::foundation::mutex::Mutex<SnapshotCache<K, V>>, key: K, force: bool, read: F, ) -> Result<ginkgo_domain::ports::ReadSnapshot<V>, crate::AppError>`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/cache.rs:165</sub>
- `pub(crate) async fn read_with_snapshot_checked<K, V, F, G>( cache: &crate::foundation::mutex::Mutex<SnapshotCache<K, V>>, key: K, force: bool, read: F, check: G, ) -> Result<ginkgo_domain::ports::ReadSnapshot<V>, crate::AppError>`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/cache.rs:179</sub>
- `pub(crate) fn now_shanghai() -> String {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/cache.rs:238</sub>

## campus_activities_service

- `pub(crate) type CampusActivitiesCache = SnapshotCache<String, CampusActivities>;`
  <sub>type · rust/crates/ginkgo_upstream/src/services/campus_activities_service.rs:9</sub>

## career_service

- `pub(crate) type CareerEventsCache = SnapshotCache<String, CareerEvents>;`
  <sub>type · rust/crates/ginkgo_upstream/src/services/career_service.rs:9</sub>

## protocol

- `pub(super) fn number(v: &Value) -> Option<i64> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/cgyy_booking_service/protocol.rs:11</sub>
- `pub(super) fn text(v: &Value) -> Option<&str> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/cgyy_booking_service/protocol.rs:15</sub>
- `pub(super) fn data(value: &Value) -> Result<&Value, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/cgyy_booking_service/protocol.rs:19</sub>
- `pub(super) fn validate(booking: &BookingRequest) -> Result<(), AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/cgyy_booking_service/protocol.rs:23</sub>
- `pub(super) fn choices(value: &Value, date: &str) -> Result<Vec<BookingChoice>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/cgyy_booking_service/protocol.rs:54</sub>
- `pub(super) fn selections(value: &Value, booking: &BookingRequest) -> Result<String, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/cgyy_booking_service/protocol.rs:84</sub>
- `pub(super) fn purposes(value: &Value) -> Vec<Purpose> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/cgyy_booking_service/protocol.rs:109</sub>
- `pub(super) fn fallback_purposes() -> Vec<Purpose> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/cgyy_booking_service/protocol.rs:141</sub>
- `pub(super) fn base_form(context: &BookingContext) -> BTreeMap<String, String> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/cgyy_booking_service/protocol.rs:163</sub>
- `pub(super) fn encrypt(text: &str, secret: &str) -> Result<String, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/cgyy_booking_service/protocol.rs:178</sub>
- `pub(super) fn protocol_point(offset: f64, width: Option<f64>) -> Result<String, AppError> {…}` — Upstream captcha coordinate: `310 * offset / width` (§6B.1). Raw device or
  <sub>fn · rust/crates/ginkgo_upstream/src/services/cgyy_booking_service/protocol.rs:206</sub>
- `pub(super) fn trade_matches(draft: &str, response: &str, row: &Value) -> bool {…}` — A trade number only narrows the match when both sides report one; an absent
  <sub>fn · rust/crates/ginkgo_upstream/src/services/cgyy_booking_service/protocol.rs:226</sub>

## cgyy_booking_service

- `pub(crate) struct BookingSafety`
  <sub>struct · rust/crates/ginkgo_upstream/src/services/cgyy_booking_service.rs:24</sub>
    - `pending: bool`  <sub>:25</sub>
    - `review: Option<ReviewCredential>`  <sub>:26</sub>
- `pub(crate) struct ReviewCredential`
  <sub>struct · rust/crates/ginkgo_upstream/src/services/cgyy_booking_service.rs:28</sub>
    - `id: String`  <sub>:29</sub>
    - `created: Instant`  <sub>:30</sub>
- `pub(crate) struct BookingContext`
  <sub>struct · rust/crates/ginkgo_upstream/src/services/cgyy_booking_service.rs:33</sub>
- `pub(super) async fn load_booking_read( &self, owner: &AccountOwner, kind: &str, site: i64, date: &str, ) -> Result<(Value, String), AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/cgyy_booking_service.rs:79</sub>

## cgyy_service

- `pub(super) async fn cgyy_token(&self, renew: bool) -> Result<String, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/cgyy_service.rs:10</sub>

## checkin_service

- `pub(crate) struct CheckInProgress` — Local timing only: no account, URLs, cookies, course names or session IDs.
  <sub>struct · rust/crates/ginkgo_upstream/src/services/checkin_service.rs:21</sub>

## contracts

- `pub fn execute_contract(contract: &str, version: u32, input: Value) -> Result<Value, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/contracts.rs:17</sub>

## demo_campus

- `pub fn load_demo_bykc() -> Result<crate::codecs::bykc::Catalog, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/demo_campus.rs:4</sub>
- `pub fn load_demo_bykc_chosen() -> Result<crate::codecs::bykc::ChosenCourses, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/demo_campus.rs:17</sub>
- `pub fn load_demo_bykc_statistics() -> Result<crate::codecs::bykc::LearningStatistics, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/demo_campus.rs:34</sub>
- `pub fn load_demo_graduate() -> Result<crate::codecs::graduate::AcademicData, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/demo_campus.rs:42</sub>
- `pub fn load_demo_notices() -> Result<Vec<crate::codecs::notices::Notice>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/demo_campus.rs:53</sub>
- `pub fn load_demo_cgyy(kind: String) -> Result<serde_json::Value, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/demo_campus.rs:65</sub>
- `pub fn graduate_status() -> Result<crate::codecs::graduate::AcademicData, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/demo_campus.rs:78</sub>
- `pub fn library_history(page: i32) -> Result<crate::codecs::library::LibraryHistoryPage, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/demo_campus.rs:87</sub>
- `pub fn library_stats() -> Result<Vec<crate::codecs::library_stats::CampusStats>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/demo_campus.rs:102</sub>

## demo_checkin

- `pub struct DemoCheckIn`
  <sub>struct · rust/crates/ginkgo_upstream/src/services/demo_checkin.rs:8</sub>
    - `date: String`  <sub>:9</sub>
    - `courses: Vec<CheckInCourse>`  <sub>:10</sub>
- `pub fn load() -> Result<DemoCheckIn, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/demo_checkin.rs:13</sub>

## demo_grades

- `pub struct DemoGrades`
  <sub>struct · rust/crates/ginkgo_upstream/src/services/demo_grades.rs:8</sub>
    - `term_id: String`  <sub>:9</sub>
    - `courses: Vec<GradeCourse>`  <sub>:10</sub>
    - `summary: GradeSummary`  <sub>:11</sub>
- `pub fn load() -> Result<DemoGrades, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/demo_grades.rs:14</sub>

## demo_homework

- `pub struct DemoHomework`
  <sub>struct · rust/crates/ginkgo_upstream/src/services/demo_homework.rs:8</sub>
    - `term_name: String`  <sub>:9</sub>
    - `term_code: String`  <sub>:10</sub>
    - `page: HomeworkPage`  <sub>:11</sub>
- `pub fn load() -> Result<DemoHomework, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/demo_homework.rs:14</sub>

## demo_library

- `pub struct DemoLibrary`
  <sub>struct · rust/crates/ginkgo_upstream/src/services/demo_library.rs:8</sub>
    - `venues: Vec<LibraryVenue>`  <sub>:9</sub>
    - `areas: Vec<LibraryArea>`  <sub>:10</sub>
    - `slots: Vec<LibrarySlot>`  <sub>:11</sub>
    - `seats: Vec<LibrarySeat>`  <sub>:12</sub>
    - `bookings: Vec<LibraryBooking>`  <sub>:13</sub>
- `pub fn load() -> Result<DemoLibrary, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/demo_library.rs:42</sub>

## demo_repository

- `pub struct DemoRepository`
  <sub>struct · rust/crates/ginkgo_upstream/src/services/demo_repository.rs:15</sub>
- `pub struct DemoQueryResult`
  <sub>struct · rust/crates/ginkgo_upstream/src/services/demo_repository.rs:19</sub>
    - `result: FilterResult`  <sub>:20</sub>
    - `fetched_at: String`  <sub>:21</sub>
    - `from_cache: bool`  <sub>:22</sub>
- `pub fn query( &mut self, campus: i32, date: &str, force: bool, mut filter: FilterRequest, ) -> Result<DemoQueryResult, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/demo_repository.rs:26</sub>
- `pub fn query_dates(instant: &str) -> Result<(String, String), AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/demo_repository.rs:92</sub>

## demo_schedule

- `pub struct DemoSchedule`
  <sub>struct · rust/crates/ginkgo_upstream/src/services/demo_schedule.rs:8</sub>
    - `terms: Vec<Term>`  <sub>:9</sub>
    - `weeks: Vec<Week>`  <sub>:10</sub>
    - `week_number: i32`  <sub>:11</sub>
    - `courses: Vec<CourseMeeting>`  <sub>:12</sub>
    - `exams: Vec<Exam>`  <sub>:13</sub>
- `pub fn load() -> Result<DemoSchedule, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/demo_schedule.rs:16</sub>

## demo_today

- `pub struct DemoToday`
  <sub>struct · rust/crates/ginkgo_upstream/src/services/demo_today.rs:8</sub>
    - `date: String`  <sub>:9</sub>
    - `courses: Vec<TodayCourse>`  <sub>:10</sub>
- `pub fn load() -> Result<DemoToday, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/demo_today.rs:13</sub>

## homework_service

- `pub(crate) type HomeworkCache = SnapshotCache<String, HomeworkData>;`
  <sub>type · rust/crates/ginkgo_upstream/src/services/homework_service.rs:12</sub>
- `pub(crate) type HomeworkDetailCache = SnapshotCache<String, HomeworkDetail>;`
  <sub>type · rust/crates/ginkgo_upstream/src/services/homework_service.rs:13</sub>

## capabilities

- `pub(super) async fn diagnose_homework(&self, id: &str) -> Vec<HomeworkCapabilityEvidence> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/homework_submission_service/capabilities.rs:27</sub>

## journal

- `pub(super) struct Record`
  <sub>struct · rust/crates/ginkgo_upstream/src/services/homework_submission_service/journal.rs:16</sub>
- `pub(super) struct Recovered` — One validated journal row, safe to move across threads.
  <sub>struct · rust/crates/ginkgo_upstream/src/services/homework_submission_service/journal.rs:28</sub>
    - `handle: String`  <sub>:29</sub>
    - `assignment: String`  <sub>:30</sub>
    - `course: String`  <sub>:31</sub>
    - `file: String`  <sub>:32</sub>
    - `name: String`  <sub>:33</sub>
    - `size: u64`  <sub>:34</sub>
    - `baseline: u32`  <sub>:35</sub>
- `pub(super) fn prepare_root(root: &str) -> Result<PathBuf, AppError> {…}` — Disk phase of [`configure`]: validate the directory without holding a lock.
  <sub>fn · rust/crates/ginkgo_upstream/src/services/homework_submission_service/journal.rs:81</sub>
- `pub(super) fn adopt_root(files: &mut HomeworkFiles, path: &Path) -> Result<(), AppError> {…}` — Memory phase of [`configure`]: adopt an already-validated root.
  <sub>fn · rust/crates/ginkgo_upstream/src/services/homework_submission_service/journal.rs:91</sub>
- `pub(super) fn root_of(files: &HomeworkFiles) -> Result<PathBuf, AppError> {…}` — The configured journal root, copied so callers can do disk work unlocked.
  <sub>fn · rust/crates/ginkgo_upstream/src/services/homework_submission_service/journal.rs:101</sub>
- `pub(super) fn read_records(root: &Path, owner: &(String, u64)) -> Result<Vec<Recovered>, AppError> {…}` — Rehydrate only Sent records. Ready receipts deliberately expire with process/identity.
  <sub>fn · rust/crates/ginkgo_upstream/src/services/homework_submission_service/journal.rs:123</sub>
- `pub(super) fn apply_restore( files: &mut HomeworkFiles, owner: &(String, u64), recovered: Vec<Recovered>, ) -> Result<(), AppError> {…}` — Merge journal records into memory. **Memory only**: callers hold the lock
  <sub>fn · rust/crates/ginkgo_upstream/src/services/homework_submission_service/journal.rs:172</sub>
- `pub(super) fn record( files: &HomeworkFiles, handle: &str, baseline: u32, ) -> Result<Record, AppError> {…}` — Snapshot one upload into a durable record. **Memory only**, cheap.
  <sub>fn · rust/crates/ginkgo_upstream/src/services/homework_submission_service/journal.rs:207</sub>
- `pub(super) fn write_record(root: &Path, account: &str, record: &Record) -> Result<(), AppError> {…}` — Persist before sending. A partial write remains as a fail-closed guard.
  <sub>fn · rust/crates/ginkgo_upstream/src/services/homework_submission_service/journal.rs:228</sub>
- `pub(super) fn clear_target( files: &HomeworkFiles, handle: &str, ) -> Result<(PathBuf, String, String), AppError> {…}` — The facts `clear` needs, snapshotted under the lock so the deletion itself
  <sub>fn · rust/crates/ginkgo_upstream/src/services/homework_submission_service/journal.rs:246</sub>
- `pub(super) fn clear_record( path: &Path, handle: &str, file: &str, assignment: &str, ) -> Result<(), AppError> {…}` — Delete only the exact positive-verified record, never acknowledge a negative/unknown read.
  <sub>fn · rust/crates/ginkgo_upstream/src/services/homework_submission_service/journal.rs:260</sub>

## homework_submission_service

- `pub(crate) struct HomeworkFiles`
  <sub>struct · rust/crates/ginkgo_upstream/src/services/homework_submission_service.rs:37</sub>

## learning_service

- `pub(crate) struct LearningSnapshots`
  <sub>struct · rust/crates/ginkgo_upstream/src/services/learning_service.rs:11</sub>
- `pub fn clear(&self) {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/learning_service.rs:21</sub>

## library_service

- `pub(crate) async fn library_token(&self) -> Result<String, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/library_service.rs:34</sub>

## library_stats_service

- `pub(crate) type LibraryStatsCache = SnapshotCache<String, Vec<CampusStats>>;`
  <sub>type · rust/crates/ginkgo_upstream/src/services/library_stats_service.rs:7</sub>

## mod

- `pub fn demo_classrooms( search: String, section: i32, minimum_free_sections: i32, minimum_consecutive_sections: i32, building: Option<String>, sort: classroom::Sort, ) -> Result<classroom::FilterResult, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/mod.rs:42</sub>
- `pub fn demo_rules() -> Result<(school_time::SchoolDay, schedule::Snapshot), AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/mod.rs:63</sub>

## session_service

- `pub(crate) struct AuthenticatedIdentity` — Published together so readers never observe an account without its profile.
  <sub>struct · rust/crates/ginkgo_upstream/src/services/session_service.rs:47</sub>
    - `account: String`  <sub>:48</sub>
    - `profile: UserProfile`  <sub>:49</sub>
- `pub(crate) struct AccountOwner`
  <sub>struct · rust/crates/ginkgo_upstream/src/services/session_service.rs:53</sub>
    - `account: String`  <sub>:54</sub>
    - `generation: u64`  <sub>:55</sub>
- `pub(crate) struct PendingLogin`
  <sub>struct · rust/crates/ginkgo_upstream/src/services/session_service.rs:58</sub>
- `pub(crate) struct Identity` — All account-scoped authentication state has one lifetime and one reset.
  <sub>struct · rust/crates/ginkgo_upstream/src/services/session_service.rs:76</sub>
    - `authenticated: Option<AuthenticatedIdentity>`  <sub>:77</sub>
    - `pending_login: Option<PendingLogin>`  <sub>:78</sub>
    - `iclass: Option<IClassSession>`  <sub>:79</sub>
    - `library_token: Option<String>`  <sub>:80</sub>
    - `cgyy_token: Option<String>`  <sub>:81</sub>
    - `cgyy_booking: Option<super::cgyy_booking_service::BookingContext>`  <sub>:82</sub>
    - `generation: u64`  <sub>:83</sub>
- `pub struct SchoolClient<T: HttpTransport, V: CredentialVault>`
  <sub>struct · rust/crates/ginkgo_upstream/src/services/session_service.rs:86</sub>
    - `session: Session<T>`  <sub>:87</sub>
    - `learning_gate: tokio::sync::Mutex<()>`  <sub>:88</sub>
    - `homework_files: Mutex<super::homework_submission_service::HomeworkFiles>`  <sub>:89</sub>
    - `homework_file_gate: tokio::sync::Mutex<()>`  <sub>:90</sub>
    - `vault: V`  <sub>:91</sub>
    - `identity: Mutex<Identity>`  <sub>:92</sub>
    - `route: StdMutex<RoutePreference>`  <sub>:93</sub>
    - `snapshots: ReadSnapshots`  <sub>:94</sub>
    - `bykc_access: tokio::sync::Mutex<()>`  <sub>:95</sub>
    - `checkin_progress: Mutex<super::checkin_service::CheckInProgress>`  <sub>:98</sub>
    - `school_recovery_gate: tokio::sync::Mutex<()>`  <sub>:99</sub>
    - `automatic_login_failure: Mutex<Option<(Instant, AppError)>>`  <sub>:101</sub>
    - `graduate_request_gate: tokio::sync::Mutex<()>`  <sub>:104</sub>
    - `library_login_gate: tokio::sync::Mutex<()>`  <sub>:105</sub>
    - `cgyy_mutation_gate: tokio::sync::Mutex<()>`  <sub>:109</sub>
    - `forgotten_account: Mutex<Option<String>>` — Account revoked by the last sign-out, handed from the fast revocation  <sub>:112</sub>
- `pub fn new(session: Session<T>, vault: V) -> Self {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/session_service.rs:116</sub>
- `pub(crate) fn checkin_day_gate(&self, date: &str) -> std::sync::Arc<tokio::sync::Mutex<()>> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/session_service.rs:142</sub>
- `pub(crate) fn set_authenticated(&self, account: String, profile: UserProfile) {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/session_service.rs:150</sub>
- `pub fn verify_vault_round_trip(&self, account: &str, secret: &str) -> bool {…}` — Diagnostic used by device acceptance: write, read back and remove one
  <sub>fn · rust/crates/ginkgo_upstream/src/services/session_service.rs:181</sub>
- `pub fn lock_poison_events(&self) -> u64 {…}` — How often one of this client's in-memory locks was recovered from a
  <sub>fn · rust/crates/ginkgo_upstream/src/services/session_service.rs:192</sub>
- `pub(crate) fn preference(&self) -> RoutePreference {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/session_service.rs:201</sub>
- `pub(crate) fn current_account(&self) -> Result<String, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/session_service.rs:205</sub>
- `pub(crate) fn account_owner(&self) -> Result<AccountOwner, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/session_service.rs:214</sub>
- `pub(crate) fn check_account_owner(&self, owner: &AccountOwner) -> Result<(), AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/session_service.rs:227</sub>
- `pub(crate) async fn silent_login(&self) -> Result<(), AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/session_service.rs:240</sub>
- `pub(crate) async fn ensure_webvpn_session(&self) -> Result<(), AppError> {…}` — Establish the WebVPN gateway's own CAS session after an automatic route
  <sub>fn · rust/crates/ginkgo_upstream/src/services/session_service.rs:284</sub>
- `pub(crate) fn clear_caches(&self) {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/session_service.rs:330</sub>
- `pub(crate) fn is_library_login_error(error: &AppError) -> bool {…}` — booking.lib answers 200 with its own login-expired message; that only means
  <sub>fn · rust/crates/ginkgo_upstream/src/services/session_service.rs:356</sub>

## snapshots

- `pub(crate) type ClassroomCache = SnapshotCache<(i32, String), BTreeMap<String, Vec<Room>>>;`
  <sub>type · rust/crates/ginkgo_upstream/src/services/snapshots.rs:17</sub>
- `pub(crate) type ScheduleCache = SnapshotCache<(Option<String>, Option<i32>), ScheduleData>;`
  <sub>type · rust/crates/ginkgo_upstream/src/services/snapshots.rs:18</sub>
- `pub(crate) type TodayCache = SnapshotCache<String, Vec<TodayCourse>>;`
  <sub>type · rust/crates/ginkgo_upstream/src/services/snapshots.rs:19</sub>
- `pub(crate) type GradeCache = SnapshotCache<String, GradeData>;`
  <sub>type · rust/crates/ginkgo_upstream/src/services/snapshots.rs:20</sub>
- `pub(crate) type CheckInCache = SnapshotCache<String, Vec<CheckInCourse>>;`
  <sub>type · rust/crates/ginkgo_upstream/src/services/snapshots.rs:21</sub>
- `pub(crate) type LibraryVenueCache = SnapshotCache<String, Vec<LibraryVenue>>;`
  <sub>type · rust/crates/ginkgo_upstream/src/services/snapshots.rs:22</sub>
- `pub(crate) type LibraryBookingCache = SnapshotCache<String, Vec<LibraryBooking>>;`
  <sub>type · rust/crates/ginkgo_upstream/src/services/snapshots.rs:23</sub>
- `pub(crate) struct ReadSnapshots`
  <sub>struct · rust/crates/ginkgo_upstream/src/services/snapshots.rs:26</sub>
    - `learning: super::learning_service::LearningSnapshots`  <sub>:27</sub>
    - `classrooms: Mutex<ClassroomCache>`  <sub>:28</sub>
    - `schedules: Mutex<ScheduleCache>`  <sub>:29</sub>
    - `cgyy: Mutex<SnapshotCache<String, ginkgo_domain::ports::CgyyData>>`  <sub>:30</sub>
    - `notices: Mutex<SnapshotCache<String, Vec<crate::codecs::notices::Notice>>>`  <sub>:31</sub>
    - `career: Mutex<super::career_service::CareerEventsCache>`  <sub>:32</sub>
    - `activities: Mutex<super::campus_activities_service::CampusActivitiesCache>`  <sub>:33</sub>
    - `graduate: Mutex<SnapshotCache<String, crate::codecs::graduate::AcademicData>>`  <sub>:34</sub>
    - `bykc: Mutex<SnapshotCache<String, crate::codecs::bykc::Catalog>>`  <sub>:35</sub>
    - `bykc_chosen: Mutex<SnapshotCache<String, crate::codecs::bykc::ChosenCourses>>`  <sub>:36</sub>
    - `homework: Mutex<super::homework_service::HomeworkCache>`  <sub>:39</sub>
    - `homework_details: Mutex<super::homework_service::HomeworkDetailCache>`  <sub>:40</sub>
    - `today: Mutex<TodayCache>`  <sub>:41</sub>
    - `grades: Mutex<GradeCache>`  <sub>:42</sub>
    - `checkin: Mutex<CheckInCache>`  <sub>:43</sub>
    - `library_stats: Mutex<super::library_stats_service::LibraryStatsCache>`  <sub>:44</sub>
    - `library_venues: Mutex<LibraryVenueCache>`  <sub>:45</sub>
    - `library_bookings: Mutex<LibraryBookingCache>`  <sub>:46</sub>
    - `library_history: Mutex<SnapshotCache<i32, LibraryHistoryPage>>`  <sub>:47</sub>
- `pub fn clear(&self) {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/services/snapshots.rs:51</sub>
- `pub fn poison_events(&self) -> u64 {…}` — How often one of the snapshot locks was recovered from a poisoned state.
  <sub>fn · rust/crates/ginkgo_upstream/src/services/snapshots.rs:78</sub>

## updates_service

- `pub async fn check<T: HttpTransport + Sync>( transport: T, current: &str, ) -> Result<UpdateSummary, AppError> {…}` — Caller provides a dedicated transport, never the account session.
  <sub>fn · rust/crates/ginkgo_upstream/src/services/updates_service.rs:9</sub>
