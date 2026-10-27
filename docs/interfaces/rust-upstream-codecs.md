# 上游解析（ginkgo_upstream::codecs）

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。

响应结构到领域值的映射；不推断缺失字段。

## bykc

- `pub fn parse_chosen(data: &serde_json::Value) -> Result<Vec<ChosenCourse>, AppError> { let rows = data["courseList"] .as_array() .ok_or_else(AppError…` — BykcClient.chosenCourses / EDUCATION-DATA-MAP §2.3. Reject a partial or  
  <sub>rust/crates/ginkgo_upstream/src/codecs/bykc.rs:98</sub>
- `pub fn parse_statistics(data: &serde_json::Value) -> Result<LearningStatistics, AppError> { let statistical = data["statistical"] .as_object() .ok_or…` — BykcClient.statistics / EDUCATION-DATA-MAP §2.3. Counts remain exact,  
  <sub>rust/crates/ginkgo_upstream/src/codecs/bykc.rs:135</sub>
- `pub fn parse_catalog( config: &serde_json::Value, pages: &[serde_json::Value], ) -> Result<Catalog, AppError> { use serde_json::Value; let string = \|…`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/bykc.rs:180</sub>

## cgyy

- `pub fn number(v: &Value) -> Option<i64> { v.as_i64().or_else(\|\| v.as_str()?.parse().ok()) }`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/cgyy.rs:5</sub>
- `pub fn envelope(value: &Value) -> Result<&Value, AppError> { let code = number(&value["code"]).ok_or_else(AppError::changed)?; if code == 401 { retur…`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/cgyy.rs:14</sub>
- `pub fn sites(value: &Value) -> Result<Vec<Site>, AppError> { let data = envelope(value)?; let rows = data .as_array() .or_else(\|\| data["content"].as_…`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/cgyy.rs:27</sub>
- `pub fn day(value: &Value, site_id: i64, date: &str) -> Result<Day, AppError> { let data = envelope(value)?; let times = data["spaceTimeInfo"] .as_arr…`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/cgyy.rs:69</sub>
- `pub fn week_start(value: &Value) -> Option<String> { let data = envelope(value).ok()?; ["reservationDateList", "ableReservationDateList"] .iter() .fi…` — Draft `weekStartDate`: the first date the day response advertises  
  <sub>rust/crates/ginkgo_upstream/src/codecs/cgyy.rs:147</sub>
- `pub(crate) fn can_cancel(row: &Value) -> bool { let start = chrono::NaiveDateTime::parse_from_str( &text(&row["reservationStartDate"]), "%Y-%m-%d %H:…` — Conservative local cancellation gate; the mutation service rechecks fresh data.  
  <sub>rust/crates/ginkgo_upstream/src/codecs/cgyy.rs:165</sub>
- `pub fn orders(value: &Value) -> Result<Vec<Order>, AppError> { order_page(value).map(\|(orders, _)\| orders) }`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/cgyy.rs:177</sub>
- `pub fn order_page(value: &Value) -> Result<(Vec<Order>, Option<i64>), AppError> { let data = envelope(value)?; let rows = data["content"] .as_array()…` — One official orders page: the `content` rows plus `totalElements` when the  
  <sub>rust/crates/ginkgo_upstream/src/codecs/cgyy.rs:183</sub>

## checkin

- `pub fn parse_app_login(value: &Value) -> Result<IClassSession, AppError> { let status = status_text(value.get("STATUS")).ok_or_else(AppError::changed…`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/checkin.rs:46</sub>
- `pub fn parse_course_schedule(value: &Value) -> Result<Vec<CheckInCourse>, AppError> { let status = status_text(value.get("STATUS")).ok_or_else(AppErr…` — Parse the day's course list. STATUS == "2" is upstream's documented  
  <sub>rust/crates/ginkgo_upstream/src/codecs/checkin.rs:75</sub>
- `pub fn login_name_from_url(url: &str) -> Option<String> { let url = url::Url::parse(url).ok()?; url.query_pairs() .find(\|(key, _)\| key.eq_ignore_asci…` — The only field borrowed from the SSO landing URL. It is used once for the  
  <sub>rust/crates/ginkgo_upstream/src/codecs/checkin.rs:251</sub>
- `pub fn summary(courses: &[CheckInCourse]) -> Value { json!({ "courses": courses.iter().map(\|course\| json!({ "id": course.id, "courseName": course.cou…` — Compact shape shared with the fixture contracts.  
  <sub>rust/crates/ginkgo_upstream/src/codecs/checkin.rs:260</sub>
- `pub struct DayInput {`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/checkin.rs:277</sub>
    - `body: Value`  <sub>:278</sub>

## classroom

- `pub fn parse_upstream_response(value: Value) -> Result<BTreeMap<String, Vec<Room>>, AppError> { let response: UpstreamEnvelope = serde_json::from_val…` — Decode the documented `buaafreeclass/search1` envelope without treating a  
  <sub>rust/crates/ginkgo_upstream/src/codecs/classroom.rs:20</sub>

## grades

- `pub fn parse_courses(value: Value) -> Result<Vec<GradeCourse>, AppError> { let status = value .get("e") .and_then(Value::as_i64) .ok_or_else(AppError…`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/grades.rs:6</sub>

## graduate

- `pub fn parse_execution(envelope: &Value) -> Result<Vec<ReadSection>, AppError> { let code = text(&envelope["code"]).ok_or_else(AppError::changed)?; i…`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/graduate.rs:74</sub>
- `pub fn parse_status(value: &Value) -> Result<ReadSection, AppError> { let row = value["datas"]["xsjcxxcx"]["rows"] .as_array() .and_then(\|rows\| rows.…`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/graduate.rs:189</sub>
- `pub fn parse_plan(header: &Value, pool: &Value) -> Result<Vec<ReadSection>, AppError> { let row = header["datas"]["facx"]["rows"] .as_array() .and_th…`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/graduate.rs:224</sub>

## homework

- `pub fn encrypt_page_param(plain: &str) -> String { let mut data = plain.as_bytes().to_vec(); let padding = (16 - data.len() % 16) % 16; data.extend(s…`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/homework.rs:17</sub>
- `pub fn parse_page(value: Value) -> Result<HomeworkPage, AppError> { let rows = value .get("list") .and_then(Value::as_array) .ok_or_else(AppError::ch…`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/homework.rs:37</sub>
- `pub fn apply_course_context(items: &mut [HomeworkItem], courses: &Value) -> Result<(), AppError> { let rows = courses.as_array().ok_or_else(AppError:…` — Course context uses kcid/kcmc/skjs, matching SpocHomeworkClient.Course.  
  <sub>rust/crates/ginkgo_upstream/src/codecs/homework.rs:92</sub>
- `pub fn content(value: &Value) -> Result<&Value, AppError> { let code = value .get("code") .and_then(\|v\| v.as_i64().or_else(\|\| v.as_str()?.parse().ok(…` — SPOC envelope success is 200 (API.md §7.1), independent of other portals.  
  <sub>rust/crates/ginkgo_upstream/src/codecs/homework.rs:148</sub>
- `pub fn parse_detail(value: &Value) -> Result<HomeworkDetail, AppError> { let assignment = content(&value["assignment"])?; if !assignment.is_object() …`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/homework.rs:160</sub>

## announcements

- `pub fn list(v: &Value) -> Result<Vec<CourseAnnouncement>, AppError> { rows(v)? .iter() .map(\|r\| { Ok(CourseAnnouncement { id: required(r, "id")?, tit…`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/learning/announcements.rs:3</sub>
- `pub fn detail(v: &Value, id: &str) -> Result<CourseAnnouncementDetail, AppError> { if !v.is_object() { return Err(AppError::changed()); } if let Some…`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/learning/announcements.rs:19</sub>

## assessments

- `pub fn list(v: &Value, course: &str) -> Result<Vec<CourseAssessment>, AppError> { rows(&v["list"])? .iter() .map(\|r\| { Ok(CourseAssessment { id: requ…`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/learning/assessments.rs:3</sub>

## mod

- `pub fn optional(v: &Value, k: &str) -> Result<Option<String>, AppError> { match v.get(k) { None \| Some(Value::Null) => Ok(None), Some(Value::String(s…`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/learning/mod.rs:7</sub>
- `pub fn required(v: &Value, k: &str) -> Result<String, AppError> { optional(v, k)?.ok_or_else(AppError::changed) }`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/learning/mod.rs:15</sub>
- `pub fn rows(v: &Value) -> Result<&Vec<Value>, AppError> { let rows = v.as_array().ok_or_else(AppError::changed)?; if rows.len() > 500 { return Err(Ap…`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/learning/mod.rs:18</sub>
- `pub fn columns(v: &Value) -> Result<Vec<ginkgo_domain::ports::LearningColumn>, AppError> { use ginkgo_domain::ports::{LearningColumn, LearningColumnK…` — Verified student kinds only; titles never determine dispatch.  
  <sub>rust/crates/ginkgo_upstream/src/codecs/learning/mod.rs:26</sub>
- `pub fn column(v: &Value, parent_kind: &str, child_kind: &str) -> Result<String, AppError> { use ginkgo_domain::ports::LearningColumnKind; let wanted …`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/learning/mod.rs:83</sub>
- `pub fn course_url(_id: &str) -> String { // Course deep-link/history-mode availability has not been verified. "https://spoc.buaa.edu.cn/spocnew/".int…`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/learning/mod.rs:100</sub>
- `pub fn courses(v: &Value) -> Result<Vec<ginkgo_domain::ports::LearningCourse>, AppError> { rows(&v["list"])? .iter() .map(\|r\| { let id = required(r, …`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/learning/mod.rs:104</sub>

## resources

- `pub fn page(v: &Value, requested: u32) -> Result<CourseResourcePage, AppError> { let page = optional(v, "pageNum")? .ok_or_else(AppError::changed)? .…`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/learning/resources.rs:3</sub>

## library

- `pub fn parse_login_user(value: &Value) -> Result<String, AppError> { let token = value .get("data") .and_then(\|data\| data.get("member")) .and_then(\|m…`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/library.rs:6</sub>
- `pub fn parse_venues(data: &Value) -> Result<Vec<LibraryVenue>, AppError> { let rows = data .get("list") .and_then(Value::as_array) .ok_or_else(AppErr…`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/library.rs:16</sub>
- `pub fn parse_areas(data: &Value) -> Result<Vec<LibraryArea>, AppError> { let rows = data .get("area") .and_then(Value::as_array) .ok_or_else(AppError…`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/library.rs:40</sub>
- `pub fn parse_slots(data: &Value) -> Result<Vec<LibrarySlot>, AppError> { let rows = data .get("date") .and_then(\|date\| date.get("list")) .and_then(Va…`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/library.rs:64</sub>
- `pub fn parse_seats(data: &Value) -> Result<Vec<LibrarySeat>, AppError> { let rows = data .get("list") .and_then(Value::as_array) .ok_or_else(AppError…`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/library.rs:96</sub>
- `pub fn parse_bookings(data: &Value) -> Result<Vec<LibraryBooking>, AppError> { if data.is_null() { return Ok(Vec::new()); } let rows = match data { V…` — The current-booking endpoint answers data as an array; older bodies wrap it  
  <sub>rust/crates/ginkgo_upstream/src/codecs/library.rs:129</sub>
- `pub fn parse_history( data: &Value, requested_page: i32, limit: i32, ) -> Result<LibraryHistoryPage, AppError> { if requested_page < 1 \|\| !(1..=100).…` — member/seat pagination, matching LibraryClient.swift:392–453.  
  <sub>rust/crates/ginkgo_upstream/src/codecs/library.rs:323</sub>

## library_books

- `pub const HOLDINGS_MAX_BYTES: usize = 512 * 1024;` — A holdings document larger than this is treated as a changed response.  
  <sub>rust/crates/ginkgo_upstream/src/codecs/library_books.rs:9</sub>
- `pub const HOLDINGS_MAX_DEPTH: usize = 8;` — Nesting bound for the second decode; the real document is two levels deep.  
  <sub>rust/crates/ginkgo_upstream/src/codecs/library_books.rs:11</sub>
- `pub const HOLDINGS_MAX_ITEMS: usize = 500;` — Copy bound for one book's holdings.  
  <sub>rust/crates/ginkgo_upstream/src/codecs/library_books.rs:13</sub>
- `pub fn envelope(value: &Value) -> Result<&Value, AppError> { let code = number(&value["code"]).ok_or_else(AppError::changed)?; if code != 0 { return …` — The OPAC envelope uses a numeric `code === 0`; HTTP 200 alone is not success.  
  <sub>rust/crates/ginkgo_upstream/src/codecs/library_books.rs:52</sub>
- `pub fn page(value: &Value, page: i64, page_size: i64) -> Result<BookPage, AppError> { let data = envelope(value)?; let total = number(&data["total"])…`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/library_books.rs:60</sub>
- `pub fn holdings(value: &Value) -> Result<Vec<BookHolding>, AppError> { let data = envelope(value)?; let encoded = data["holdings"] .as_str() .or_else…` — `data.holdings` is a JSON string; anything else is a changed response.  
  <sub>rust/crates/ginkgo_upstream/src/codecs/library_books.rs:124</sub>

## library_loans

- `pub const PAGE_SIZE: u32 = 100;`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/library_loans.rs:5</sub>
- `pub fn page(v: &Value, requested: u32) -> Result<LibraryLoanPage, AppError> { match v.get("code").and_then(Value::as_i64) { Some(0) => {} Some(_) => …`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/library_loans.rs:30</sub>

## library_mutation

- `pub fn encrypt(value: &Value, day: &str) -> Result<String, AppError> { let parsed = chrono::NaiveDate::parse_from_str(day, "%Y-%m-%d").map_err(\|_\| Ap…`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/library_mutation.rs:11</sub>
- `pub fn parse_result(value: &Value) -> MutationOutcome { let code = value["code"] .as_i64() .or_else(\|\| value["code"].as_str()?.trim().parse().ok()); …`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/library_mutation.rs:34</sub>

## library_stats

- `pub fn parse(html: &str) -> Result<Vec<CampusStats>, AppError> { let campuses = Regex::new( r#"(?is)<img\b[^>]*\bsrc=["'][^"']*/more/custom/t_(xylxq\|…`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/library_stats.rs:33</sub>

## notices

- `pub fn parse(html: &str) -> Result<Vec<Notice>, AppError> { let base = &*crate::endpoints::NOTICE_PAGE; static ROWS: LazyLock<Regex> = LazyLock::new(…`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/notices.rs:40</sub>

## graduate

- `pub fn parse_graduate_terms(value: Value) -> Result<Vec<Term>, AppError> { let code = optional_string(&value, "code").ok_or_else(AppError::changed)?;…` — GSMIS terms (`20261` form). GSMIS does not return a selected flag; the  
  <sub>rust/crates/ginkgo_upstream/src/codecs/schedule/graduate.rs:17</sub>
- `pub fn parse_graduate_weeks(value: Value, term_id: &str) -> Result<Vec<Week>, AppError> { let now: chrono::DateTime<chrono::Utc> = std::time::SystemT…` — GSMIS weeks are not returned directly: the term start is inferred from each  
  <sub>rust/crates/ginkgo_upstream/src/codecs/schedule/graduate.rs:58</sub>
- `pub fn parse_graduate_weeks_at( value: Value, term_id: &str, today: NaiveDate, ) -> Result<Vec<Week>, AppError> { let code = optional_string(&value, …`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/schedule/graduate.rs:64</sub>
- `pub fn parse_graduate_courses( value: Value, term_id: &str, week: i32, ) -> Result<Vec<CourseMeeting>, AppError> { if week < 1 { return Err(AppError:…` — Parse one week from the all-term GSMIS response. Courses are filtered by the  
  <sub>rust/crates/ginkgo_upstream/src/codecs/schedule/graduate.rs:165</sub>

## schedule

- `pub fn parse_terms(value: Value) -> Result<Vec<Term>, AppError> { require_success(&value)?; let rows = value .get("datas") .and_then(Value::as_array)…`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/schedule.rs:7</sub>
- `pub fn parse_weeks(value: Value) -> Result<Vec<Week>, AppError> { require_success(&value)?; let rows = value .get("datas") .and_then(Value::as_array)…`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/schedule.rs:36</sub>
- `pub fn parse_undergraduate_courses(value: Value) -> Result<Vec<CourseMeeting>, AppError> { require_success(&value)?; let rows = value .get("datas") .…`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/schedule.rs:77</sub>
- `pub fn parse_exams(value: Value) -> Result<Vec<Exam>, AppError> { require_success(&value)?; let rows = value .get("datas") .and_then(Value::as_array)…`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/schedule.rs:116</sub>

## shuttle

- `pub const SOURCE_URL: &str = "https://www.buaa.edu.cn/info/1065/1762.htm";`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/shuttle.rs:12</sub>
- `pub fn parse(html: &str) -> Result<ShuttleTimetable, AppError> { let mut tables = Vec::new(); for table in table_re().captures_iter(html).take(MAX_TA…`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/shuttle.rs:86</sub>

## today

- `pub fn parse_courses(value: Value) -> Result<Vec<TodayCourse>, AppError> { let code = value .get("code") .and_then(\|code\| { code.as_str() .map(str::t…`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/today.rs:6</sub>

## updates

- `pub const REPOSITORY: &str = "https://github.com/JUANWANG-BUAA/ginkgo";`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/updates.rs:7</sub>
- `pub fn parse(body: &str, current: &str) -> Result<UpdateSummary, AppError> { let current_version = Version::parse(current).map_err(\|_\| AppError::inva…`  
  <sub>rust/crates/ginkgo_upstream/src/codecs/updates.rs:37</sub>
