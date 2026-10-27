# 上游解析（ginkgo_upstream::codecs）

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。

响应结构到领域值的映射；不推断缺失字段。

## 目录

- [bykc](#bykc) (3)
- [cgyy](#cgyy) (8)
- [checkin](#checkin) (5)
- [classroom](#classroom) (1)
- [grades](#grades) (1)
- [graduate](#graduate) (3)
- [homework](#homework) (5)
- [announcements](#announcements) (2)
- [assessments](#assessments) (1)
- [mod](#mod) (7)
- [resources](#resources) (1)
- [library](#library) (7)
- [library_books](#librarybooks) (6)
- [library_loans](#libraryloans) (2)
- [library_mutation](#librarymutation) (2)
- [library_stats](#librarystats) (1)
- [notices](#notices) (1)
- [graduate](#graduate) (4)
- [schedule](#schedule) (4)
- [shuttle](#shuttle) (2)
- [today](#today) (1)
- [updates](#updates) (2)

## bykc

- `pub fn parse_chosen(data: &serde_json::Value) -> Result<Vec<ChosenCourse>, AppError> {…}` — BykcClient.chosenCourses / EDUCATION-DATA-MAP §2.3. Reject a partial or  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/bykc.rs:98</sub>
- `pub fn parse_statistics(data: &serde_json::Value) -> Result<LearningStatistics, AppError> {…}` — BykcClient.statistics / EDUCATION-DATA-MAP §2.3. Counts remain exact,  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/bykc.rs:135</sub>
- `pub fn parse_catalog( config: &serde_json::Value, pages: &[serde_json::Value], ) -> Result<Catalog, AppError> {…}`  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/bykc.rs:180</sub>

## cgyy

- `pub fn number(v: &Value) -> Option<i64> {…}`  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/cgyy.rs:5</sub>
- `pub fn envelope(value: &Value) -> Result<&Value, AppError> {…}`  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/cgyy.rs:14</sub>
- `pub fn sites(value: &Value) -> Result<Vec<Site>, AppError> {…}`  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/cgyy.rs:27</sub>
- `pub fn day(value: &Value, site_id: i64, date: &str) -> Result<Day, AppError> {…}`  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/cgyy.rs:69</sub>
- `pub fn week_start(value: &Value) -> Option<String> {…}` — Draft `weekStartDate`: the first date the day response advertises  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/cgyy.rs:147</sub>
- `pub(crate) fn can_cancel(row: &Value) -> bool {…}` — Conservative local cancellation gate; the mutation service rechecks fresh data.  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/cgyy.rs:165</sub>
- `pub fn orders(value: &Value) -> Result<Vec<Order>, AppError> {…}`  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/cgyy.rs:177</sub>
- `pub fn order_page(value: &Value) -> Result<(Vec<Order>, Option<i64>), AppError> {…}` — One official orders page: the `content` rows plus `totalElements` when the  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/cgyy.rs:183</sub>

## checkin

- `pub fn parse_app_login(value: &Value) -> Result<IClassSession, AppError> {…}`  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/checkin.rs:46</sub>
- `pub fn parse_course_schedule(value: &Value) -> Result<Vec<CheckInCourse>, AppError> {…}` — Parse the day's course list. STATUS == "2" is upstream's documented  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/checkin.rs:75</sub>
- `pub fn login_name_from_url(url: &str) -> Option<String> {…}` — The only field borrowed from the SSO landing URL. It is used once for the  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/checkin.rs:251</sub>
- `pub fn summary(courses: &[CheckInCourse]) -> Value {…}` — Compact shape shared with the fixture contracts.  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/checkin.rs:260</sub>
- `pub struct DayInput`  
  <sub>struct · rust/crates/ginkgo_upstream/src/codecs/checkin.rs:277</sub>
    - `body: Value`  <sub>:278</sub>

## classroom

- `pub fn parse_upstream_response(value: Value) -> Result<BTreeMap<String, Vec<Room>>, AppError> {…}` — Decode the documented `buaafreeclass/search1` envelope without treating a  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/classroom.rs:20</sub>

## grades

- `pub fn parse_courses(value: Value) -> Result<Vec<GradeCourse>, AppError> {…}`  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/grades.rs:6</sub>

## graduate

- `pub fn parse_execution(envelope: &Value) -> Result<Vec<ReadSection>, AppError> {…}`  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/graduate.rs:74</sub>
- `pub fn parse_status(value: &Value) -> Result<ReadSection, AppError> {…}`  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/graduate.rs:189</sub>
- `pub fn parse_plan(header: &Value, pool: &Value) -> Result<Vec<ReadSection>, AppError> {…}`  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/graduate.rs:224</sub>

## homework

- `pub fn encrypt_page_param(plain: &str) -> String {…}`  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/homework.rs:17</sub>
- `pub fn parse_page(value: Value) -> Result<HomeworkPage, AppError> {…}`  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/homework.rs:37</sub>
- `pub fn apply_course_context(items: &mut [HomeworkItem], courses: &Value) -> Result<(), AppError> {…}` — Course context uses kcid/kcmc/skjs, matching SpocHomeworkClient.Course.  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/homework.rs:92</sub>
- `pub fn content(value: &Value) -> Result<&Value, AppError> {…}` — SPOC envelope success is 200 (API.md §7.1), independent of other portals.  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/homework.rs:148</sub>
- `pub fn parse_detail(value: &Value) -> Result<HomeworkDetail, AppError> {…}`  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/homework.rs:160</sub>

## announcements

- `pub fn list(v: &Value) -> Result<Vec<CourseAnnouncement>, AppError> {…}`  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/learning/announcements.rs:3</sub>
- `pub fn detail(v: &Value, id: &str) -> Result<CourseAnnouncementDetail, AppError> {…}`  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/learning/announcements.rs:19</sub>

## assessments

- `pub fn list(v: &Value, course: &str) -> Result<Vec<CourseAssessment>, AppError> {…}`  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/learning/assessments.rs:3</sub>

## mod

- `pub fn optional(v: &Value, k: &str) -> Result<Option<String>, AppError> {…}`  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/learning/mod.rs:7</sub>
- `pub fn required(v: &Value, k: &str) -> Result<String, AppError> {…}`  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/learning/mod.rs:15</sub>
- `pub fn rows(v: &Value) -> Result<&Vec<Value>, AppError> {…}`  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/learning/mod.rs:18</sub>
- `pub fn columns(v: &Value) -> Result<Vec<ginkgo_domain::ports::LearningColumn>, AppError> {…}` — Verified student kinds only; titles never determine dispatch.  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/learning/mod.rs:26</sub>
- `pub fn column(v: &Value, parent_kind: &str, child_kind: &str) -> Result<String, AppError> {…}`  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/learning/mod.rs:83</sub>
- `pub fn course_url(_id: &str) -> String {…}`  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/learning/mod.rs:100</sub>
- `pub fn courses(v: &Value) -> Result<Vec<ginkgo_domain::ports::LearningCourse>, AppError> {…}`  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/learning/mod.rs:104</sub>

## resources

- `pub fn page(v: &Value, requested: u32) -> Result<CourseResourcePage, AppError> {…}`  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/learning/resources.rs:3</sub>

## library

- `pub fn parse_login_user(value: &Value) -> Result<String, AppError> {…}`  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/library.rs:6</sub>
- `pub fn parse_venues(data: &Value) -> Result<Vec<LibraryVenue>, AppError> {…}`  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/library.rs:16</sub>
- `pub fn parse_areas(data: &Value) -> Result<Vec<LibraryArea>, AppError> {…}`  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/library.rs:40</sub>
- `pub fn parse_slots(data: &Value) -> Result<Vec<LibrarySlot>, AppError> {…}`  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/library.rs:64</sub>
- `pub fn parse_seats(data: &Value) -> Result<Vec<LibrarySeat>, AppError> {…}`  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/library.rs:96</sub>
- `pub fn parse_bookings(data: &Value) -> Result<Vec<LibraryBooking>, AppError> {…}` — The current-booking endpoint answers data as an array; older bodies wrap it  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/library.rs:129</sub>
- `pub fn parse_history( data: &Value, requested_page: i32, limit: i32, ) -> Result<LibraryHistoryPage, AppError> {…}` — member/seat pagination, matching LibraryClient.swift:392–453.  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/library.rs:323</sub>

## library_books

- `pub const HOLDINGS_MAX_BYTES: usize = 512 * 1024;` — A holdings document larger than this is treated as a changed response.  
  <sub>const · rust/crates/ginkgo_upstream/src/codecs/library_books.rs:9</sub>
- `pub const HOLDINGS_MAX_DEPTH: usize = 8;` — Nesting bound for the second decode; the real document is two levels deep.  
  <sub>const · rust/crates/ginkgo_upstream/src/codecs/library_books.rs:11</sub>
- `pub const HOLDINGS_MAX_ITEMS: usize = 500;` — Copy bound for one book's holdings.  
  <sub>const · rust/crates/ginkgo_upstream/src/codecs/library_books.rs:13</sub>
- `pub fn envelope(value: &Value) -> Result<&Value, AppError> {…}` — The OPAC envelope uses a numeric `code === 0`; HTTP 200 alone is not success.  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/library_books.rs:52</sub>
- `pub fn page(value: &Value, page: i64, page_size: i64) -> Result<BookPage, AppError> {…}`  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/library_books.rs:60</sub>
- `pub fn holdings(value: &Value) -> Result<Vec<BookHolding>, AppError> {…}` — `data.holdings` is a JSON string; anything else is a changed response.  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/library_books.rs:124</sub>

## library_loans

- `pub const PAGE_SIZE: u32 = 100;`  
  <sub>const · rust/crates/ginkgo_upstream/src/codecs/library_loans.rs:5</sub>
- `pub fn page(v: &Value, requested: u32) -> Result<LibraryLoanPage, AppError> {…}`  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/library_loans.rs:30</sub>

## library_mutation

- `pub fn encrypt(value: &Value, day: &str) -> Result<String, AppError> {…}`  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/library_mutation.rs:11</sub>
- `pub fn parse_result(value: &Value) -> MutationOutcome {…}`  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/library_mutation.rs:34</sub>

## library_stats

- `pub fn parse(html: &str) -> Result<Vec<CampusStats>, AppError> {…}`  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/library_stats.rs:33</sub>

## notices

- `pub fn parse(html: &str) -> Result<Vec<Notice>, AppError> {…}`  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/notices.rs:40</sub>

## graduate

- `pub fn parse_graduate_terms(value: Value) -> Result<Vec<Term>, AppError> {…}` — GSMIS terms (`20261` form). GSMIS does not return a selected flag; the  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/schedule/graduate.rs:17</sub>
- `pub fn parse_graduate_weeks(value: Value, term_id: &str) -> Result<Vec<Week>, AppError> {…}` — GSMIS weeks are not returned directly: the term start is inferred from each  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/schedule/graduate.rs:58</sub>
- `pub fn parse_graduate_weeks_at( value: Value, term_id: &str, today: NaiveDate, ) -> Result<Vec<Week>, AppError> {…}`  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/schedule/graduate.rs:64</sub>
- `pub fn parse_graduate_courses( value: Value, term_id: &str, week: i32, ) -> Result<Vec<CourseMeeting>, AppError> {…}` — Parse one week from the all-term GSMIS response. Courses are filtered by the  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/schedule/graduate.rs:165</sub>

## schedule

- `pub fn parse_terms(value: Value) -> Result<Vec<Term>, AppError> {…}`  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/schedule.rs:7</sub>
- `pub fn parse_weeks(value: Value) -> Result<Vec<Week>, AppError> {…}`  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/schedule.rs:36</sub>
- `pub fn parse_undergraduate_courses(value: Value) -> Result<Vec<CourseMeeting>, AppError> {…}`  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/schedule.rs:77</sub>
- `pub fn parse_exams(value: Value) -> Result<Vec<Exam>, AppError> {…}`  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/schedule.rs:116</sub>

## shuttle

- `pub const SOURCE_URL: &str = "https://www.buaa.edu.cn/info/1065/1762.htm";`  
  <sub>const · rust/crates/ginkgo_upstream/src/codecs/shuttle.rs:12</sub>
- `pub fn parse(html: &str) -> Result<ShuttleTimetable, AppError> {…}`  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/shuttle.rs:86</sub>

## today

- `pub fn parse_courses(value: Value) -> Result<Vec<TodayCourse>, AppError> {…}`  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/today.rs:6</sub>

## updates

- `pub const REPOSITORY: &str = "https://github.com/JUANWANG-BUAA/ginkgo";`  
  <sub>const · rust/crates/ginkgo_upstream/src/codecs/updates.rs:7</sub>
- `pub fn parse(body: &str, current: &str) -> Result<UpdateSummary, AppError> {…}`  
  <sub>fn · rust/crates/ginkgo_upstream/src/codecs/updates.rs:37</sub>
