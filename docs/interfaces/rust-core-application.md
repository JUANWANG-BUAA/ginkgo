# 应用编排（ginkgo_core）

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
命令编排、账号隔离与本机持久化。

## 目录

- [academic](#academic) (4)
- [bykc](#bykc) (3)
- [bykc_projection](#bykcprojection) (2)
- [campus_card](#campuscard) (1)
- [campus_info](#campusinfo) (2)
- [cgyy](#cgyy) (3)
- [checkin](#checkin) (4)
- [classroom](#classroom) (1)
- [graduate](#graduate) (2)
- [graduate_credit_map](#graduatecreditmap) (7)
- [homework](#homework) (10)
- [learning](#learning) (15)
- [library](#library) (8)
- [library_books](#librarybooks) (2)
- [library_loans](#libraryloans) (1)
- [library_stats](#librarystats) (1)
- [mod](#mod) (2)
- [notices](#notices) (1)
- [query_snapshots](#querysnapshots) (2)
- [session](#session) (8)
- [shuttle](#shuttle) (1)
- [tasks_service](#tasksservice) (2)
- [cgyy_pending_store](#cgyypendingstore) (6)
- [tasks_store](#tasksstore) (1)

## academic

- `pub async fn load_schedule( &self, input: &ScheduleQueryInput, ) -> Result<ScheduleOutcome, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/academic.rs:5</sub>
- `pub async fn load_today(&self, force_refresh: bool) -> Result<TodayOutcome, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/academic.rs:14</sub>
- `pub async fn load_grades( &self, term_code: Option<&str>, force_refresh: bool, ) -> Result<GradeOutcome, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/academic.rs:20</sub>
- `pub async fn load_grade_terms(&self) -> Result<Vec<Term>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/academic.rs:27</sub>

## bykc

- `pub async fn load_bykc(&self, force: bool) -> Result<BykcOutcome, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/bykc.rs:5</sub>
- `pub async fn load_bykc_chosen(&self, force: bool) -> Result<BykcChosenOutcome, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/bykc.rs:8</sub>
- `pub async fn load_bykc_statistics( &self, force: bool, ) -> Result<BykcStatisticsOutcome, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/bykc.rs:11</sub>

## bykc_projection

- `pub struct BykcCatalogView` — Page projection adds the selected term without exposing upstream fields or
  <sub>struct · rust/crates/ginkgo_core/src/application/bykc_projection.rs:7</sub>
    - `catalog: Catalog`  <sub>:9</sub>
    - `current_term: Option<crate::features::bykc::Semester>`  <sub>:10</sub>
- `pub fn project_catalog(catalog: Catalog) -> Result<BykcCatalogView, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/bykc_projection.rs:13</sub>

## campus_card

- `pub async fn campus_card_balance( &self, ) -> Result<ginkgo_domain::features::campus_card::CampusCardBalance, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/campus_card.rs:4</sub>

## campus_info

- `pub async fn load_career_events( &self, month: &str, force: bool, ) -> Result<CareerEventsOutcome, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/campus_info.rs:5</sub>
- `pub async fn load_campus_activities( &self, page: i32, force: bool, ) -> Result<CampusActivitiesOutcome, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/campus_info.rs:15</sub>

## cgyy

- `pub async fn execute_cgyy_json(&self, envelope: &str) -> Result<CgyyActionResult, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/cgyy.rs:8</sub>
- `pub async fn execute_cgyy(&self, command: CgyyCommand) -> Result<CgyyActionResult, AppError> {…}` — Legacy typed entry: only reads are allowed without an application-support root.
  <sub>fn · rust/crates/ginkgo_core/src/application/cgyy.rs:33</sub>
- `pub async fn load_cgyy(&self, query: CgyyQuery, force: bool) -> Result<CgyyOutcome, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/cgyy.rs:138</sub>

## checkin

- `pub fn checkin_load_progress(&self) -> CheckInLoadProgress {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/checkin.rs:5</sub>
- `pub async fn load_checkin(&self, force_refresh: bool) -> Result<CheckInOutcome, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/checkin.rs:8</sub>
- `pub async fn load_checkin_on_date( &self, date: Option<String>, force_refresh: bool, ) -> Result<CheckInOutcome, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/checkin.rs:11</sub>
- `pub async fn submit_checkin( &self, course_id: &str, ) -> crate::features::mutation::MutationOutcome {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/checkin.rs:23</sub>

## classroom

- `pub async fn load_classrooms( &self, input: &ClassroomQueryInput, ) -> Result<ClassroomOutcome, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/classroom.rs:5</sub>

## graduate

- `pub async fn load_graduate(&self, force: bool) -> Result<GraduateOutcome, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/graduate.rs:5</sub>
- `pub async fn load_graduate_part( &self, part: GraduatePart, force: bool, ) -> Result<GraduateOutcome, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/graduate.rs:8</sub>

## graduate_credit_map

- `pub struct GraduateCreditMap`
  <sub>struct · rust/crates/ginkgo_core/src/application/graduate_credit_map.rs:12</sub>
    - `summary: Option<GraduateCreditNode>`  <sub>:13</sub>
    - `nodes: Vec<GraduateCreditNode>`  <sub>:14</sub>
    - `notice: Option<String>`  <sub>:15</sub>
- `pub struct GraduateCreditNode`
  <sub>struct · rust/crates/ginkgo_core/src/application/graduate_credit_map.rs:19</sub>
    - `source_index: u32` — Source ordinal, not an inferred category/group relationship.  <sub>:21</sub>
    - `title: String`  <sub>:22</sub>
    - `progress: Option<GraduateCreditMetrics>`  <sub>:23</sub>
    - `rows: Vec<ReadRow>`  <sub>:24</sub>
- `pub struct GraduateCreditMetrics`
  <sub>struct · rust/crates/ginkgo_core/src/application/graduate_credit_map.rs:28</sub>
    - `state: GraduateCreditState`  <sub>:29</sub>
    - `required: Option<f64>`  <sub>:30</sub>
    - `earned: Option<f64>`  <sub>:31</sub>
    - `pending: Option<f64>`  <sub>:32</sub>
    - `remaining: Option<f64>` — Derived only from this node's official requirement and recognized credits.  <sub>:34</sub>
    - `ratio: Option<f64>`  <sub>:35</sub>
- `pub enum GraduateCreditState`
  <sub>enum · rust/crates/ginkgo_core/src/application/graduate_credit_map.rs:39</sub>
- `pub fn project_graduate_credit_map(data: &AcademicData) -> GraduateCreditMap {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/graduate_credit_map.rs:76</sub>
- `pub struct GraduateCreditMapOutcome`
  <sub>struct · rust/crates/ginkgo_core/src/application/graduate_credit_map.rs:97</sub>
    - `data: GraduateCreditMap`  <sub>:98</sub>
    - `failure: Option<AppError>`  <sub>:99</sub>
- `pub async fn load_graduate_credit_map( &self, force: bool, ) -> Result<GraduateCreditMapOutcome, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/graduate_credit_map.rs:102</sub>

## homework

- `pub async fn load_homework(&self, force: bool) -> Result<HomeworkOutcome, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/homework.rs:5</sub>
- `pub async fn load_homework_detail( &self, id: &str, force: bool, ) -> Result<HomeworkDetailOutcome, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/homework.rs:8</sub>
- `pub fn configure_homework_recovery(&self, root: &str) -> Result<(), AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/homework.rs:18</sub>
- `pub async fn pending_homework_submissions( &self, ) -> Result<Vec<HomeworkPendingSubmission>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/homework.rs:21</sub>
- `pub async fn homework_capabilities(&self, id: &str) -> Vec<HomeworkCapabilityEvidence> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/homework.rs:26</sub>
- `pub async fn homework_workspace(&self, id: &str) -> Result<HomeworkWorkspace, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/homework.rs:29</sub>
- `pub async fn upload_homework_file( &self, id: &str, name: &str, bytes: Vec<u8>, ) -> Result<HomeworkUploadReceipt, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/homework.rs:32</sub>
- `pub async fn submit_homework_file(&self, handle: &str, confirmed: bool) -> MutationOutcome {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/homework.rs:41</sub>
- `pub async fn download_homework_file( &self, id: &str, attachment_id: &str, ) -> Result<HomeworkDownload, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/homework.rs:47</sub>
- `pub async fn reconcile_homework_file(&self, handle: &str) -> MutationOutcome {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/homework.rs:56</sub>

## learning

- `pub async fn learning_courses( &self, force: bool, ) -> Result<DataOutcome<Vec<LearningCourse>>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/learning.rs:4</sub>
- `pub async fn course_announcements( &self, course: &str, force: bool, ) -> Result<DataOutcome<Vec<CourseAnnouncement>>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/learning.rs:12</sub>
- `pub async fn course_announcement_detail( &self, course: &str, id: &str, ) -> Result<CourseAnnouncementDetail, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/learning.rs:19</sub>
- `pub async fn course_announcement_attachment( &self, course: &str, id: &str, file: &str, ) -> Result<LearningDownload, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/learning.rs:26</sub>
- `pub async fn course_resources( &self, course: &str, folder: Option<&str>, page: u32, force: bool, ) -> Result<DataOutcome<CourseResourcePage>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/learning.rs:38</sub>
- `pub async fn course_resource_download( &self, course: &str, folder: Option<&str>, page: u32, id: &str, ) -> Result<LearningDownload, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/learning.rs:49</sub>
- `pub async fn course_assessments( &self, course: &str, force: bool, ) -> Result<DataOutcome<Vec<CourseAssessment>>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/learning.rs:62</sub>
- `pub async fn course_learning_columns( &self, course: &str, force: bool, ) -> Result<DataOutcome<Vec<LearningColumn>>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/learning.rs:72</sub>
- `pub async fn course_announcements_in( &self, course: &str, column: &str, force: bool, ) -> Result<DataOutcome<Vec<CourseAnnouncement>>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/learning.rs:79</sub>
- `pub async fn course_announcement_detail_in( &self, course: &str, column: &str, id: &str, ) -> Result<CourseAnnouncementDetail, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/learning.rs:89</sub>
- `pub async fn course_announcement_attachment_in( &self, course: &str, column: &str, id: &str, file: &str, ) -> Result<LearningDownload, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/learning.rs:99</sub>
- `pub async fn course_assessments_in( &self, course: &str, column: &str, force: bool, ) -> Result<DataOutcome<Vec<CourseAssessment>>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/learning.rs:110</sub>
- `pub async fn course_resources_at( &self, course: &str, path: &[String], page: u32, force: bool, ) -> Result<DataOutcome<CourseResourcePage>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/learning.rs:120</sub>
- `pub async fn course_resource_download_at( &self, course: &str, path: &[String], page: u32, id: &str, ) -> Result<LearningDownload, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/learning.rs:131</sub>
- `pub async fn course_learning_capabilities( &self, course: &str, ) -> Result<LearningCapabilities, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/learning.rs:142</sub>

## library

- `pub async fn load_library_history( &self, page: i32, force_refresh: bool, ) -> Result<LibraryHistoryOutcome, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/library.rs:5</sub>
- `pub async fn load_library_venues( &self, force_refresh: bool, ) -> Result<LibraryVenuesOutcome, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/library.rs:14</sub>
- `pub async fn load_library_areas(&self, library_id: &str) -> Result<Vec<LibraryArea>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/library.rs:20</sub>
- `pub async fn load_library_slots(&self, area_id: &str) -> Result<Vec<LibrarySlot>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/library.rs:23</sub>
- `pub async fn load_library_seats( &self, area_id: &str, slot_id: &str, day: &str, start: &str, end: &str, ) -> Result<Vec<LibrarySeat>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/library.rs:26</sub>
- `pub async fn load_library_bookings( &self, force_refresh: bool, ) -> Result<LibraryBookingsOutcome, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/library.rs:38</sub>
- `pub async fn reserve_library_seat( &self, area_id: &str, seat_id: &str, slot: LibrarySlot, ) -> MutationOutcome {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/library.rs:47</sub>
- `pub async fn perform_library_action(&self, booking_id: &str, action: &str) -> MutationOutcome {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/library.rs:57</sub>

## library_books

- `pub async fn search_library_books( &self, query: String, page: i64, sort: String, descending: bool, ) -> Result<BookPage, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/library_books.rs:6</sub>
- `pub async fn load_book_holdings(&self, bib_id: String) -> Result<Vec<BookHolding>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/library_books.rs:18</sub>

## library_loans

- `pub async fn load_library_loans(&self, page: u32) -> Result<LibraryLoanPage, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/library_loans.rs:5</sub>

## library_stats

- `pub async fn load_library_stats(&self, force: bool) -> Result<LibraryStatsOutcome, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/library_stats.rs:5</sub>

## mod

- `pub struct Workspace<U>`
  <sub>struct · rust/crates/ginkgo_core/src/application/mod.rs:15</sub>
- `pub fn new(upstream: U) -> Self {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/mod.rs:19</sub>

## notices

- `pub async fn load_notices(&self, force: bool) -> Result<NoticesOutcome, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/notices.rs:5</sub>

## query_snapshots

- `pub fn export_learning_snapshots(&self) -> Result<Vec<u8>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/query_snapshots.rs:4</sub>
- `pub fn import_learning_snapshots(&self, bytes: &[u8]) -> Result<u32, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/query_snapshots.rs:7</sub>

## session

- `pub async fn login_challenge( &self, expected_id: Option<&str>, refresh: bool, ) -> Result<ginkgo_domain::ports::LoginChallengeData, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/session.rs:5</sub>
- `pub fn status(&self) -> SessionStatus {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/session.rs:13</sub>
- `pub fn set_route(&self, preference: RoutePreference) {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/session.rs:16</sub>
- `pub async fn sign_in( &self, account: &str, password: &str, captcha: Option<&str>, remember: bool, ) -> Result<SessionOutcome, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/session.rs:19</sub>
- `pub async fn restore(&self) -> Result<SessionOutcome, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/session.rs:30</sub>
- `pub async fn sign_out(&self) {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/session.rs:33</sub>
- `pub async fn purge_credentials(&self) {…}` — Second sign-out step: delete saved passwords. Deliberately separate so
  <sub>fn · rust/crates/ginkgo_core/src/application/session.rs:38</sub>
- `pub fn clear_snapshots(&self) {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/session.rs:41</sub>

## shuttle

- `pub async fn load_shuttle_timetable(&self) -> Result<ShuttleTimetable, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/shuttle.rs:6</sub>

## tasks_service

- `pub fn edit( root: &Path, account: &str, action: &str, id: Option<&str>, title: Option<&str>, due: Option<&str>, completed: Option<bool>, ) -> Result<Vec<Task>, AppError> {…}` — Account is derived by the bridge from the authenticated Rust session.
  <sub>fn · rust/crates/ginkgo_core/src/application/tasks_service.rs:12</sub>
- `pub fn edit_tasks( &self, root: &Path, action: &str, id: Option<&str>, title: Option<&str>, due: Option<&str>, completed: Option<bool>, ) -> Result<Vec<Task>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/application/tasks_service.rs:76</sub>

## cgyy_pending_store

- `pub(crate) enum Pending`
  <sub>enum · rust/crates/ginkgo_core/src/cgyy_pending_store.rs:19</sub>
- `pub(crate) struct PendingStore`
  <sub>struct · rust/crates/ginkgo_core/src/cgyy_pending_store.rs:33</sub>
- `pub(crate) fn new(root: &Path, account: &str) -> Result<Self, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/cgyy_pending_store.rs:38</sub>
- `pub(crate) fn inspect(&self) -> Result<Pending, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/cgyy_pending_store.rs:50</sub>
- `pub(crate) fn create(&self) -> Result<bool, AppError> {…}` — Returns true only for the caller that created AND flushed the initial marker.
  <sub>fn · rust/crates/ginkgo_core/src/cgyy_pending_store.rs:76</sub>
- `pub(crate) fn clear(&self) -> Result<(), AppError> {…}` — Only after a proven terminal mutation or upstream-validated acknowledgment.
  <sub>fn · rust/crates/ginkgo_core/src/cgyy_pending_store.rs:110</sub>

## tasks_store

- `pub fn transact( root: &Path, account: &str, change: impl FnOnce(&mut Vec<Task>) -> Result<(), AppError>, ) -> Result<Vec<Task>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_core/src/tasks_store.rs:15</sub>
