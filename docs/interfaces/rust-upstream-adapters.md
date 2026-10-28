# 上游适配器（ginkgo_upstream::adapters）

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
请求构造、认证注入与响应分类；学校协议事实见 API.md。

## 目录

- [bykc_http](#bykchttp) (4)
- [campus_activities_http](#campusactivitieshttp) (2)
- [campus_card_http](#campuscardhttp) (7)
- [career_http](#careerhttp) (2)
- [cgyy_http](#cgyyhttp) (8)
- [checkin_http](#checkinhttp) (7)
- [classroom_http](#classroomhttp) (3)
- [grades_http](#gradeshttp) (2)
- [graduate_http](#graduatehttp) (3)
- [graduate_schedule_http](#graduateschedulehttp) (7)
- [homework_files_http](#homeworkfileshttp) (5)
- [homework_http](#homeworkhttp) (9)
- [announcements](#announcements) (4)
- [assessments](#assessments) (2)
- [mod](#mod) (9)
- [resources](#resources) (3)
- [library_books_http](#librarybookshttp) (4)
- [library_http](#libraryhttp) (13)
- [library_loans_http](#libraryloanshttp) (3)
- [library_stats_http](#librarystatshttp) (3)
- [notices_http](#noticeshttp) (1)
- [reqwest_transport](#reqwesttransport) (2)
- [schedule_http](#schedulehttp) (13)
- [shuttle_http](#shuttlehttp) (2)
- [student_services](#studentservices) (1)
- [updates_http](#updateshttp) (2)

## bykc_http

- `pub fn decode_envelope(envelope: &Value) -> Result<Value, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/bykc_http.rs:104</sub>
- `pub async fn load<T: HttpTransport>(session: &Session<T>) -> Result<Catalog, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/bykc_http.rs:139</sub>
- `pub async fn load_chosen<T: HttpTransport>( session: &Session<T>, ) -> Result<ChosenCourses, AppError> {…}` — Native BykcClient.load, queryChosenCourse; EDUCATION-DATA-MAP §2.3.
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/bykc_http.rs:166</sub>
- `pub async fn load_statistics<T: HttpTransport>( session: &Session<T>, ) -> Result<LearningStatistics, AppError> {…}` — Native BykcClient.statistics; independent of catalog or chosen-course errors.
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/bykc_http.rs:200</sub>

## campus_activities_http

- `pub fn validate_page(page: i32) -> Result<(), AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/campus_activities_http.rs:49</sub>
- `pub async fn load<T: HttpTransport + Sync>( session: &Session<T>, page: i32, ) -> Result<CampusActivities, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/campus_activities_http.rs:69</sub>

## campus_card_http

- `pub const ENTRY_URL: &str = "https://pass.cc-pay.cn/login?backUrl=https%3A%2F%2Fpass.cc-pay.cn%2Fdashboard%3Flinkfrom%3Dpass&channel=BUAASSO";`
  <sub>const · rust/crates/ginkgo_upstream/src/adapters/campus_card_http.rs:8</sub>
- `pub const USER_URL: &str = "https://pass.cc-pay.cn/api/user";`
  <sub>const · rust/crates/ginkgo_upstream/src/adapters/campus_card_http.rs:9</sub>
- `pub const CARDS_URL: &str = "https://pass.cc-pay.cn/api/campus_cards";`
  <sub>const · rust/crates/ginkgo_upstream/src/adapters/campus_card_http.rs:10</sub>
- `pub const BALANCE_URL: &str = "https://pass.cc-pay.cn/api/campus_card/balance";`
  <sub>const · rust/crates/ginkgo_upstream/src/adapters/campus_card_http.rs:11</sub>
- `pub async fn establish<T: HttpTransport + Sync>(session: &Session<T>) -> Result<(), AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/campus_card_http.rs:57</sub>
- `pub async fn card_number<T: HttpTransport + Sync>( session: &Session<T>, ) -> Result<String, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/campus_card_http.rs:63</sub>
- `pub async fn balance<T: HttpTransport + Sync>( session: &Session<T>, card_number: &str, ) -> Result<i64, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/campus_card_http.rs:70</sub>

## career_http

- `pub fn validate_month(month: &str) -> Result<(), AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/career_http.rs:23</sub>
- `pub async fn load<T: HttpTransport + Sync>( session: &Session<T>, month: &str, ) -> Result<CareerEvents, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/career_http.rs:46</sub>

## cgyy_http

- `pub fn sign(path: &str, params: &BTreeMap<String, String>, timestamp: i64) -> String {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/cgyy_http.rs:13</sub>
- `pub async fn login<T: HttpTransport>( session: &Session<T>, credentials: Option<&Credentials>, ) -> Result<String, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/cgyy_http.rs:119</sub>
- `pub const ORDERS_PAGE_SIZE: i64 = 5;` — Official mobile page size for `/api/orders/mine` (§6B.1).
  <sub>const · rust/crates/ginkgo_upstream/src/adapters/cgyy_http.rs:178</sub>
- `pub const ORDERS_MAX_PAGES: i64 = 4;` — Hard bound on the pages one read may walk. This is deliberately small: a
  <sub>const · rust/crates/ginkgo_upstream/src/adapters/cgyy_http.rs:181</sub>
- `pub async fn load<T: HttpTransport>( session: &Session<T>, kind: &str, site: i64, date: &str, token: Option<&str>, ) -> Result<Value, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/cgyy_http.rs:183</sub>
- `pub async fn load_orders<T: HttpTransport>( session: &Session<T>, page: i64, size: i64, token: &str, ) -> Result<Value, AppError> {…}` — One explicit `page`/`size` orders read. Callers own the bounded paging loop.
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/cgyy_http.rs:242</sub>
- `pub async fn read_orders<T: HttpTransport>( session: &Session<T>, token: &str, ) -> Result<Value, AppError> {…}` — Bounded orders read. Starts at the official page 0 / size 5 and merges at
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/cgyy_http.rs:271</sub>
- `pub async fn business<T: HttpTransport>(session: &Session<T>…)  -> Result<Value, AppError> {…}` — Signed business request; caller owns mutation confirmation and retry policy.
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/cgyy_http.rs:315</sub>

## checkin_http

- `pub const ENTRY_URL: &str = "https://iclass.buaa.edu.cn:8346/?type=jumpMyCenter";`
  <sub>const · rust/crates/ginkgo_upstream/src/adapters/checkin_http.rs:16</sub>
- `pub const APP_LOGIN_URL: &str = "https://iclass.buaa.edu.cn:8347/app/user/login.action";`
  <sub>const · rust/crates/ginkgo_upstream/src/adapters/checkin_http.rs:17</sub>
- `pub const COURSE_SCHEDULE_URL: &str = "https://iclass.buaa.edu.cn:8347/app/course/get_stu_course_sched.action";`
  <sub>const · rust/crates/ginkgo_upstream/src/adapters/checkin_http.rs:18</sub>
- `pub async fn resolve_login_name<T: HttpTransport>( session: &Session<T>, ) -> Result<String, AppError> {…}` — Follow the SSO entry manually (at most eight hops) and return only the
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/checkin_http.rs:23</sub>
- `pub async fn app_login<T: HttpTransport>( session: &Session<T>, login_name: &str, ) -> Result<IClassSession, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/checkin_http.rs:68</sub>
- `pub async fn course_schedule<T: HttpTransport>(session: &Session<T>…)  -> Result<Vec<CheckInCourse>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/checkin_http.rs:80</sub>
- `pub async fn sign_in<T: HttpTransport>(session: &Session<T>…)  -> crate::codecs::mutation::MutationOutcome {…}` — CheckInClient.performSignIn / API.md §7.2. Timestamp is a safe read;
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/checkin_http.rs:146</sub>

## classroom_http

- `pub const ACTIVATION_URL: &str = "https://sso.buaa.edu.cn/login?service=https%3A%2F%2Fa … ry%252Findex%26from%3Dwap%26login_from%3D&noAutoRedirect=1";`
  <sub>const · rust/crates/ginkgo_upstream/src/adapters/classroom_http.rs:14</sub>
- `pub async fn query_classrooms<T: HttpTransport>( session: &Session<T>, campus: i32, date: &str, ) -> Result<BTreeMap<String, Vec<Room>>, AppError> {…}` — Run the two documented classroom requests with the caller-owned session.
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/classroom_http.rs:20</sub>
- `pub async fn query_classrooms_with_recovery<T: HttpTransport, C: CredentialSource>(……)  -> Result<BTreeMap<String, Vec<Room>>, AppError> {…}` — Retry a classroom read exactly once after a confirmed expired session.
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/classroom_http.rs:54</sub>

## grades_http

- `pub const GRADE_URL: &str = "https://app.buaa.edu.cn/buaascore/wap/default/index";`
  <sub>const · rust/crates/ginkgo_upstream/src/adapters/grades_http.rs:9</sub>
- `pub async fn load_grades<T: HttpTransport>( session: &Session<T>, term_code: &str, ) -> Result<Vec<GradeCourse>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/grades_http.rs:11</sub>

## graduate_http

- `pub async fn load_status<T: HttpTransport>( session: &Session<T>, account: &str, ) -> Result<AcademicData, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/graduate_http.rs:65</sub>
- `pub async fn load_execution_report<T: HttpTransport>( session: &Session<T>, ) -> Result<AcademicData, AppError> {…}` — Strict report path for credit-map health. Never substitutes the plan pool.
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/graduate_http.rs:103</sub>
- `pub async fn load_report<T: HttpTransport>( session: &Session<T>, account: &str, ) -> Result<AcademicData, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/graduate_http.rs:119</sub>

## graduate_schedule_http

- `pub const ENTRY_URL: &str = "https://gsmis.buaa.edu.cn/gsapp/sys/wdkbapp/*default/index.do";`
  <sub>const · rust/crates/ginkgo_upstream/src/adapters/graduate_schedule_http.rs:11</sub>
- `pub const TERMS_URL: &str = "https://gsmis.buaa.edu.cn/gsapp/sys/wdkbapp/modules/xskcb/kfdxnxqcx.do";`
  <sub>const · rust/crates/ginkgo_upstream/src/adapters/graduate_schedule_http.rs:12</sub>
- `pub const SCHEDULE_URL: &str = "https://gsmis.buaa.edu.cn/gsapp/sys/wdkbapp/bykb/loadXskbData.do";`
  <sub>const · rust/crates/ginkgo_upstream/src/adapters/graduate_schedule_http.rs:14</sub>
- `pub struct GraduateSchedule`
  <sub>struct · rust/crates/ginkgo_upstream/src/adapters/graduate_schedule_http.rs:17</sub>
    - `weeks: Vec<Week>`  <sub>:18</sub>
    - `courses_by_week: BTreeMap<i32, Vec<CourseMeeting>>`  <sub>:19</sub>
- `pub async fn activate<T: HttpTransport>(session: &Session<T>) -> Result<(), AppError> {…}` — GSMIS activates its own SSO session by visiting the SPA entry. The BYXT
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/graduate_schedule_http.rs:24</sub>
- `pub async fn load_terms<T: HttpTransport>(session: &Session<T>) -> Result<Vec<Term>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/graduate_schedule_http.rs:37</sub>
- `pub async fn load_schedule<T: HttpTransport>( session: &Session<T>, term_id: &str, ) -> Result<GraduateSchedule, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/graduate_schedule_http.rs:51</sub>

## homework_files_http

- `pub(crate) struct Context`
  <sub>struct · rust/crates/ginkgo_upstream/src/adapters/homework_files_http.rs:65</sub>
    - `auth: SpocAuth`  <sub>:66</sub>
    - `assignment: Value`  <sub>:67</sub>
    - `workspace: HomeworkWorkspace`  <sub>:68</sub>
    - `student_owned: bool`  <sub>:69</sub>
- `pub(crate) async fn load<T: HttpTransport>( session: &Session<T>, id: &str, ) -> Result<Context, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/homework_files_http.rs:71</sub>
- `pub(crate) async fn submission<T: HttpTransport>( session: &Session<T>, auth: &SpocAuth, id: &str, ) -> Result<Value, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/homework_files_http.rs:192</sub>
- `pub(crate) fn course_id(context: &Context) -> Result<String, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/homework_files_http.rs:233</sub>
- `pub(crate) fn accepts(workspace: &HomeworkWorkspace, name: &str) -> bool {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/homework_files_http.rs:236</sub>

## homework_http

- `pub const SPOC_BASE: &str = "https://spoc.buaa.edu.cn/spocnewht";`
  <sub>const · rust/crates/ginkgo_upstream/src/adapters/homework_http.rs:9</sub>
- `pub const ASSIGNMENT_SQL_ID: &str = "1713252980496efac7d5d9985e81693116d3e8a52ebf2b";`
  <sub>const · rust/crates/ginkgo_upstream/src/adapters/homework_http.rs:10</sub>
- `pub struct SpocAuth`
  <sub>struct · rust/crates/ginkgo_upstream/src/adapters/homework_http.rs:13</sub>
    - `token: String`  <sub>:14</sub>
    - `role: String`  <sub>:15</sub>
- `pub async fn load_page<T: HttpTransport>( session: &Session<T>, auth: &SpocAuth, term_code: &str, page: i32, ) -> Result<HomeworkPage, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/homework_http.rs:18</sub>
- `pub fn page_payload(term_code: &str, page: i32) -> String {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/homework_http.rs:48</sub>
- `pub async fn authenticate<T: HttpTransport>(session: &Session<T>) -> Result<SpocAuth, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/homework_http.rs:72</sub>
- `pub async fn load<T: HttpTransport>( session: &Session<T>, ) -> Result<homework::HomeworkData, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/homework_http.rs:167</sub>
- `pub(crate) async fn course_ids<T: HttpTransport>( session: &Session<T>…)  -> Result<std::collections::BTreeSet<String>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/homework_http.rs:258</sub>
- `pub async fn load_detail<T: HttpTransport>( session: &Session<T>, id: &str, ) -> Result<homework::HomeworkDetail, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/homework_http.rs:291</sub>

## announcements

- `pub async fn list<T: HttpTransport>( s: &Session<T>, a: &SpocAuth, course: &str, ) -> Result<Vec<CourseAnnouncement>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/learning/announcements.rs:3</sub>
- `pub async fn list_in<T: HttpTransport>(s: &Session<T>…)  -> Result<Vec<CourseAnnouncement>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/learning/announcements.rs:10</sub>
- `pub async fn detail<T: HttpTransport>( s: &Session<T>, a: &SpocAuth, id: &str, ) -> Result<CourseAnnouncementDetail, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/learning/announcements.rs:29</sub>
- `pub async fn download<T: HttpTransport>( s: &Session<T>, a: &SpocAuth, file: &str, ) -> Result<Vec<u8>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/learning/announcements.rs:47</sub>

## assessments

- `pub async fn list<T: HttpTransport>( s: &Session<T>, a: &SpocAuth, course: &str, ) -> Result<Vec<CourseAssessment>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/learning/assessments.rs:3</sub>
- `pub async fn list_in<T: HttpTransport>(s: &Session<T>…)  -> Result<Vec<CourseAssessment>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/learning/assessments.rs:10</sub>

## mod

- `pub async fn auth<T: HttpTransport>(s: &Session<T>) -> Result<SpocAuth, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/learning/mod.rs:12</sub>
- `pub fn query(fields: &[(&str, &str)]) -> String {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/learning/mod.rs:15</sub>
- `pub async fn request<T: HttpTransport>( s: &Session<T>, a: &SpocAuth, r: HttpRequest, ) -> Result<Value, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/learning/mod.rs:20</sub>
- `pub async fn courses<T: HttpTransport>( s: &Session<T>, a: &SpocAuth, ) -> Result<Vec<ginkgo_domain::ports::LearningCourse>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/learning/mod.rs:43</sub>
- `pub async fn ensure_course<T: HttpTransport>( s: &Session<T>, a: &SpocAuth, id: &str, ) -> Result<(), AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/learning/mod.rs:77</sub>
- `pub async fn columns<T: HttpTransport>(s: &Session<T>…)  -> Result<Vec<ginkgo_domain::ports::LearningColumn>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/learning/mod.rs:88</sub>
- `pub(super) async fn select_column<T: HttpTransport>( s: &Session<T>…)  -> Result<String, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/learning/mod.rs:104</sub>
- `pub async fn binary<T: HttpTransport>( s: &Session<T>, a: &SpocAuth, url: String, ) -> Result<Vec<u8>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/learning/mod.rs:128</sub>
- `pub(super) async fn binary_request<T: HttpTransport>( s: &Session<T>, a: &SpocAuth, r: HttpRequest, ) -> Result<Vec<u8>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/learning/mod.rs:135</sub>

## resources

- `pub async fn page<T: HttpTransport>(s: &Session<T>…)  -> Result<CourseResourcePage, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/learning/resources.rs:3</sub>
- `pub async fn page_at<T: HttpTransport>(s: &Session<T>…)  -> Result<CourseResourcePage, AppError> {…}` — A caller provides a root-to-leaf chain, not authority. Every edge is freshly
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/learning/resources.rs:15</sub>
- `pub async fn download<T: HttpTransport>( s: &Session<T>, a: &SpocAuth, id: &str, ) -> Result<Vec<u8>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/learning/resources.rs:103</sub>

## library_books_http

- `pub const BASE: &str = "https://space.lib.buaa.edu.cn/meta-local";`
  <sub>const · rust/crates/ginkgo_upstream/src/adapters/library_books_http.rs:12</sub>
- `pub fn search_body( query: &str, page: i64, page_size: i64, sort: &str, descending: bool, ) -> serde_json::Value {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/library_books_http.rs:53</sub>
- `pub async fn search<T: HttpTransport + Sync>(shared: &Session<T>…)  -> Result<BookPage, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/library_books_http.rs:78</sub>
- `pub async fn holdings<T: HttpTransport + Sync>( shared: &Session<T>, preference: RouteMode, bib_id: &str, ) -> Result<Vec<BookHolding>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/library_books_http.rs:104</sub>

## library_http

- `pub const BASE: &str = "https://booking.lib.buaa.edu.cn";`
  <sub>const · rust/crates/ginkgo_upstream/src/adapters/library_http.rs:13</sub>
- `pub const LOGIN_START: &str = "https://sso.buaa.edu.cn/login?service=https%3A%2F%2Fbooking.lib.buaa.edu.cn%2Fv4%2Flogin%2Fcas";`
  <sub>const · rust/crates/ginkgo_upstream/src/adapters/library_http.rs:14</sub>
- `pub const LOGIN_USER: &str = "https://booking.lib.buaa.edu.cn/v4/login/user";`
  <sub>const · rust/crates/ginkgo_upstream/src/adapters/library_http.rs:15</sub>
- `pub async fn login<T: HttpTransport>(session: &Session<T>) -> Result<String, AppError> {…}` — Walk the library CAS chain manually (API.md §5.1: at most eight hops, the
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/library_http.rs:30</sub>
- `pub async fn venues<T: HttpTransport>( session: &Session<T>, token: &str, day: &str, ) -> Result<Vec<LibraryVenue>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/library_http.rs:84</sub>
- `pub async fn areas<T: HttpTransport>( session: &Session<T>, token: &str, library_id: &str, day: &str, ) -> Result<Vec<LibraryArea>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/library_http.rs:96</sub>
- `pub async fn slots<T: HttpTransport>( session: &Session<T>, token: &str, area_id: &str, ) -> Result<Vec<LibrarySlot>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/library_http.rs:121</sub>
- `pub async fn seats<T: HttpTransport>(session: &Session<T>…)  -> Result<Vec<LibrarySeat>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/library_http.rs:133</sub>
- `pub async fn bookings<T: HttpTransport>( session: &Session<T>, token: &str, ) -> Result<Vec<LibraryBooking>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/library_http.rs:160</sub>
- `pub async fn history<T: HttpTransport>(session: &Session<T>…)  -> Result<library::LibraryHistoryPage, AppError> {…}` — Read-only history, same bearer token and envelope as current bookings.
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/library_http.rs:169</sub>
- `pub fn parse_envelope(response: &HttpResponse) -> Result<Value, AppError> {…}` — The envelope is shared by every business endpoint: HTTP auth, a login
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/library_http.rs:217</sub>
- `pub fn cas_token(raw: &str) -> Option<String> {…}` — API.md §5.1: the cas parameter may follow ?, & or # and must be
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/library_http.rs:274</sub>
- `pub async fn mutate<T: HttpTransport>( session: &Session<T>, token: &str, path: &str, body: &Value, ) -> crate::codecs::mutation::MutationOutcome {…}` — Single attempt: never route-fallback, replay on auth failure, or follow a redirect.
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/library_http.rs:306</sub>

## library_loans_http

- `pub fn portal_url() -> String {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/library_loans_http.rs:12</sub>
- `pub async fn establish<T: HttpTransport + Sync>(session: &Session<T>) -> Result<(), AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/library_loans_http.rs:79</sub>
- `pub async fn load<T: HttpTransport + Sync>( session: &Session<T>, page: u32, ) -> Result<LibraryLoanPage, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/library_loans_http.rs:87</sub>

## library_stats_http

- `pub const URL: &str = "https://lib.buaa.edu.cn/engine2/buaa/more/1082575?websiteId=113745&pageId=208561&wfwfid=16662";`
  <sub>const · rust/crates/ginkgo_upstream/src/adapters/library_stats_http.rs:8</sub>
- `pub fn parse_response(response: &HttpResponse) -> Result<Vec<CampusStats>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/library_stats_http.rs:17</sub>
- `pub async fn load<T: HttpTransport + Sync>( shared: &Session<T>, preference: RouteMode, ) -> Result<Vec<CampusStats>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/library_stats_http.rs:27</sub>

## notices_http

- `pub async fn load<T: HttpTransport>(session: &Session<T>) -> Result<Vec<Notice>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/notices_http.rs:7</sub>

## reqwest_transport

- `pub struct ReqwestTransport`
  <sub>struct · rust/crates/ginkgo_upstream/src/adapters/reqwest_transport.rs:33</sub>
- `pub fn new() -> Result<Self, TransportError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/reqwest_transport.rs:41</sub>

## schedule_http

- `pub const PORTAL_URL: &str = "https://byxt.buaa.edu.cn/jwapp/sys/homeapp/api/home/currentUser.do";`
  <sub>const · rust/crates/ginkgo_upstream/src/adapters/schedule_http.rs:11</sub>
- `pub const TERMS_URL: &str = "https://byxt.buaa.edu.cn/jwapp/sys/homeapp/api/home/student/schoolCalendars.do";`
  <sub>const · rust/crates/ginkgo_upstream/src/adapters/schedule_http.rs:12</sub>
- `pub const WEEKS_URL: &str = "https://byxt.buaa.edu.cn/jwapp/sys/homeapp/api/home/getTermWeeks.do";`
  <sub>const · rust/crates/ginkgo_upstream/src/adapters/schedule_http.rs:14</sub>
- `pub const COURSES_URL: &str = "https://byxt.buaa.edu.cn/jwapp/sys/homeapp/api/home/student/getMyScheduleDetail.do";`
  <sub>const · rust/crates/ginkgo_upstream/src/adapters/schedule_http.rs:15</sub>
- `pub const EXAMS_URL: &str = "https://byxt.buaa.edu.cn/jwapp/sys/homeapp/api/home/student/exams.do";`
  <sub>const · rust/crates/ginkgo_upstream/src/adapters/schedule_http.rs:17</sub>
- `pub const TODAY_URL: &str = "https://byxt.buaa.edu.cn/jwapp/sys/homeapp/api/home/teachingSchedule/detail.do";`
  <sub>const · rust/crates/ginkgo_upstream/src/adapters/schedule_http.rs:18</sub>
- `pub enum Portal`
  <sub>enum · rust/crates/ginkgo_upstream/src/adapters/schedule_http.rs:25</sub>
- `pub async fn detect_portal<T: HttpTransport>(session: &Session<T>) -> Result<Portal, AppError> {…}` — Probe the shared session once and classify the portal (API.md §2.1).
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/schedule_http.rs:35</sub>
- `pub async fn load_terms<T: HttpTransport>(session: &Session<T>) -> Result<Vec<Term>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/schedule_http.rs:55</sub>
- `pub async fn load_weeks<T: HttpTransport>( session: &Session<T>, term_id: &str, ) -> Result<Vec<Week>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/schedule_http.rs:63</sub>
- `pub async fn load_week_courses<T: HttpTransport>( session: &Session<T>, term_id: &str, week: i32, ) -> Result<Vec<CourseMeeting>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/schedule_http.rs:80</sub>
- `pub async fn load_exams<T: HttpTransport>( session: &Session<T>, term_id: &str, ) -> Result<Vec<Exam>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/schedule_http.rs:105</sub>
- `pub async fn load_today<T: HttpTransport>( session: &Session<T>, date: &str, ) -> Result<Vec<TodayCourse>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/schedule_http.rs:125</sub>

## shuttle_http

- `pub fn parse_response(response: &HttpResponse) -> Result<ShuttleTimetable, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/shuttle_http.rs:20</sub>
- `pub async fn load<T: HttpTransport + Sync>( shared: &Session<T>, preference: RouteMode, ) -> Result<ShuttleTimetable, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/shuttle_http.rs:34</sub>

## student_services

- `pub fn official_url(id: &str) -> Option<String> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/student_services.rs:3</sub>

## updates_http

- `pub const URL: &str = "https://api.github.com/repos/JUANWANG-BUAA/ginkgo/releases?per_page=100";`
  <sub>const · rust/crates/ginkgo_upstream/src/adapters/updates_http.rs:7</sub>
- `pub async fn load<T: HttpTransport + Sync>(session: &Session<T>) -> Result<String, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/adapters/updates_http.rs:8</sub>
