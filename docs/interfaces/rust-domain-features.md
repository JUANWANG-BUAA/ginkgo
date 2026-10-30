# 领域值类型与纯规则（ginkgo_domain::features）

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
业务数据结构与不依赖网络的规则；此处禁止出现学校 URL 与 HTTP。

## 目录

- [bykc](#bykc) (16)
- [campus_activities](#campusactivities) (2)
- [campus_card](#campuscard) (1)
- [career](#career) (2)
- [cgyy](#cgyy) (6)
- [cgyy_booking](#cgyybooking) (9)
- [checkin](#checkin) (4)
- [classroom](#classroom) (11)
- [grades](#grades) (4)
- [graduate](#graduate) (4)
- [homework](#homework) (9)
- [library](#library) (9)
- [library_books](#librarybooks) (3)
- [library_loans](#libraryloans) (2)
- [library_stats](#librarystats) (3)
- [mutation](#mutation) (5)
- [notices](#notices) (1)
- [reminders](#reminders) (8)
- [schedule](#schedule) (9)
- [shuttle](#shuttle) (4)
- [tasks](#tasks) (8)
- [today](#today) (1)
- [updates](#updates) (2)

## bykc

- `pub struct Course`
  <sub>struct · rust/crates/ginkgo_domain/src/features/bykc.rs:6</sub>
    - `id: i64`  <sub>:7</sub>
    - `name: String`  <sub>:8</sub>
    - `teacher: Option<String>`  <sub>:9</sub>
    - `position: Option<String>`  <sub>:10</sub>
    - `category: Option<String>`  <sub>:11</sub>
    - `subcategory: Option<String>`  <sub>:12</sub>
    - `details: Option<CourseDetails>`  <sub>:14</sub>
- `pub struct CourseDetails`
  <sub>struct · rust/crates/ginkgo_domain/src/features/bykc.rs:18</sub>
    - `start: Option<String>`  <sub>:19</sub>
    - `end: Option<String>`  <sub>:20</sub>
    - `select_start: Option<String>`  <sub>:21</sub>
    - `select_end: Option<String>`  <sub>:22</sub>
    - `cancel_end: Option<String>`  <sub>:23</sub>
    - `capacity: Option<i64>`  <sub>:24</sub>
    - `enrolled: Option<i64>`  <sub>:25</sub>
    - `campuses: Vec<String>`  <sub>:26</sub>
    - `summary: Option<String>`  <sub>:27</sub>
    - `selected: Option<bool>`  <sub>:28</sub>
    - `has_sign_config: Option<bool>`  <sub>:29</sub>
- `pub enum Category`
  <sub>enum · rust/crates/ginkgo_domain/src/features/bykc.rs:34</sub>
- `pub struct Filter`
  <sub>struct · rust/crates/ginkgo_domain/src/features/bykc.rs:41</sub>
    - `search_text: String`  <sub>:42</sub>
    - `category: Category`  <sub>:43</sub>
- `pub struct Request`
  <sub>struct · rust/crates/ginkgo_domain/src/features/bykc.rs:46</sub>
    - `courses: Vec<Course>`  <sub>:47</sub>
    - `filter: Filter`  <sub>:48</sub>
- `pub struct Count`
  <sub>struct · rust/crates/ginkgo_domain/src/features/bykc.rs:51</sub>
    - `category: Category`  <sub>:52</sub>
    - `count: usize`  <sub>:53</sub>
- `pub struct ResultSet`
  <sub>struct · rust/crates/ginkgo_domain/src/features/bykc.rs:57</sub>
    - `matching_course_ids: Vec<i64>`  <sub>:59</sub>
    - `category_counts: Vec<Count>`  <sub>:60</sub>
- `pub fn filter(request: Request) -> Result<ResultSet, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_domain/src/features/bykc.rs:72</sub>
- `pub struct Catalog`
  <sub>struct · rust/crates/ginkgo_domain/src/features/bykc.rs:115</sub>
    - `terms: Vec<Semester>`  <sub>:116</sub>
    - `courses: Vec<Course>`  <sub>:117</sub>
- `pub struct Semester`
  <sub>struct · rust/crates/ginkgo_domain/src/features/bykc.rs:120</sub>
    - `id: String`  <sub>:121</sub>
    - `name: String`  <sub>:122</sub>
    - `start: Option<String>`  <sub>:123</sub>
    - `end: Option<String>`  <sub>:124</sub>
- `pub struct ChosenCourse` — A chosen-record ID is distinct from its nested course ID. Only fields shown
  <sub>struct · rust/crates/ginkgo_domain/src/features/bykc.rs:132</sub>
    - `id: i64`  <sub>:133</sub>
    - `course: Course`  <sub>:134</sub>
    - `selected_at: Option<String>`  <sub>:135</sub>
    - `checkin: Option<i64>`  <sub>:136</sub>
    - `passed: Option<i64>`  <sub>:137</sub>
    - `score: Option<i64>`  <sub>:138</sub>
- `pub struct ChosenCourses`
  <sub>struct · rust/crates/ginkgo_domain/src/features/bykc.rs:142</sub>
    - `term: Option<Semester>`  <sub>:143</sub>
    - `courses: Option<Vec<ChosenCourse>>` — None means no valid semester range was available, not zero selections.  <sub>:145</sub>
- `pub struct StatisticsEntry`
  <sub>struct · rust/crates/ginkgo_domain/src/features/bykc.rs:149</sub>
    - `category: String`  <sub>:150</sub>
    - `subcategory: String`  <sub>:151</sub>
    - `required: i64`  <sub>:152</sub>
    - `completed: i64`  <sub>:153</sub>
- `pub struct LearningStatistics`
  <sub>struct · rust/crates/ginkgo_domain/src/features/bykc.rs:158</sub>
    - `valid_course_count: Option<i64>`  <sub>:159</sub>
    - `entries: Vec<StatisticsEntry>`  <sub>:160</sub>
- `pub fn current_semester(terms: &[Semester], instant: &str) -> Result<Option<Semester>, AppError> {…}` — Same active-first, latest-end fallback as BykcSemesterPolicy.swift. Naive
  <sub>fn · rust/crates/ginkgo_domain/src/features/bykc.rs:194</sub>
- `pub fn semester_range(term: &Semester) -> Option<(String, String)> {…}`
  <sub>fn · rust/crates/ginkgo_domain/src/features/bykc.rs:217</sub>

## campus_activities

- `pub struct CampusActivity`
  <sub>struct · rust/crates/ginkgo_domain/src/features/campus_activities.rs:7</sub>
    - `id: String`  <sub>:8</sub>
    - `title: String`  <sub>:9</sub>
    - `category: String`  <sub>:10</sub>
    - `published_at: String`  <sub>:11</sub>
    - `activity_time: String`  <sub>:12</sub>
    - `place: String`  <sub>:13</sub>
    - `url: String`  <sub>:14</sub>
- `pub struct CampusActivities`
  <sub>struct · rust/crates/ginkgo_domain/src/features/campus_activities.rs:19</sub>
    - `page: i32`  <sub>:20</sub>
    - `activities: Vec<CampusActivity>`  <sub>:21</sub>
    - `fetched_at: String`  <sub>:22</sub>

## campus_card

- `pub struct CampusCardBalance`
  <sub>struct · rust/crates/ginkgo_domain/src/features/campus_card.rs:2</sub>
    - `balance_minor: i64`  <sub>:3</sub>
    - `fetched_at: String`  <sub>:4</sub>

## career

- `pub struct CareerEvent`
  <sub>struct · rust/crates/ginkgo_domain/src/features/career.rs:7</sub>
    - `id: String`  <sub>:8</sub>
    - `title: String`  <sub>:9</sub>
    - `campus: String`  <sub>:10</sub>
    - `place: String`  <sub>:11</sub>
    - `begins_at: String`  <sub>:12</sub>
    - `ends_at: String`  <sub>:13</sub>
    - `fair_type: String`  <sub>:14</sub>
    - `status: String`  <sub>:15</sub>
    - `url: String`  <sub>:16</sub>
- `pub struct CareerEvents`
  <sub>struct · rust/crates/ginkgo_domain/src/features/career.rs:21</sub>
    - `month: String`  <sub>:22</sub>
    - `events: Vec<CareerEvent>`  <sub>:23</sub>
    - `fetched_at: String`  <sub>:24</sub>

## cgyy

- `pub struct Site`
  <sub>struct · rust/crates/ginkgo_domain/src/features/cgyy.rs:4</sub>
    - `id: i64`  <sub>:5</sub>
    - `name: String`  <sub>:6</sub>
    - `venue: String`  <sub>:7</sub>
    - `campus: String`  <sub>:8</sub>
    - `seats: Option<i64>`  <sub>:9</sub>
    - `open_start: String`  <sub>:10</sub>
    - `open_end: String`  <sub>:11</sub>
- `pub struct Slot`
  <sub>struct · rust/crates/ginkgo_domain/src/features/cgyy.rs:14</sub>
    - `time: String`  <sub>:15</sub>
    - `status: String`  <sub>:16</sub>
- `pub struct Space`
  <sub>struct · rust/crates/ginkgo_domain/src/features/cgyy.rs:19</sub>
    - `name: String`  <sub>:20</sub>
    - `slots: Vec<Slot>`  <sub>:21</sub>
- `pub struct Day`
  <sub>struct · rust/crates/ginkgo_domain/src/features/cgyy.rs:24</sub>
    - `site_id: i64`  <sub>:25</sub>
    - `date: String`  <sub>:26</sub>
    - `dates: Vec<String>`  <sub>:27</sub>
    - `spaces: Vec<Space>`  <sub>:28</sub>
- `pub struct Order`
  <sub>struct · rust/crates/ginkgo_domain/src/features/cgyy.rs:31</sub>
    - `order_status: Option<i64>`  <sub>:33</sub>
    - `check_status: Option<i64>`  <sub>:35</sub>
    - `can_cancel: bool`  <sub>:36</sub>
    - `id: i64`  <sub>:37</sub>
    - `place: String`  <sub>:38</sub>
    - `date: String`  <sub>:39</sub>
    - `time: String`  <sub>:40</sub>
    - `status: String`  <sub>:41</sub>
- `pub struct CgyyLockCode`
  <sub>struct · rust/crates/ginkgo_domain/src/features/cgyy.rs:46</sub>
    - `qr_code: Option<String>`  <sub>:48</sub>
    - `due_date: Option<String>`  <sub>:50</sub>
    - `trade_no: Option<String>`  <sub>:52</sub>
    - `venue_name: Option<String>`  <sub>:54</sub>
    - `site_name: Option<String>`  <sub>:56</sub>
    - `space_name: Option<String>`  <sub>:58</sub>
    - `order_name: Option<String>`  <sub>:60</sub>
    - `reservation_date: Option<String>`  <sub>:62</sub>
    - `reservation_date_detail: Option<String>`  <sub>:64</sub>
    - `reservation_start_date: Option<String>`  <sub>:66</sub>
    - `reservation_end_date: Option<String>`  <sub>:68</sub>

## cgyy_booking

- `pub struct BookingRequest`
  <sub>struct · rust/crates/ginkgo_domain/src/features/cgyy_booking.rs:5</sub>
    - `site_id: i64`  <sub>:6</sub>
    - `date: String`  <sub>:7</sub>
    - `space_id: i64`  <sub>:8</sub>
    - `time_ids: Vec<i64>`  <sub>:9</sub>
    - `phone: String`  <sub>:10</sub>
    - `theme: String`  <sub>:11</sub>
    - `purpose_type: i64`  <sub>:12</sub>
    - `joiner_num: i64`  <sub>:13</sub>
    - `activity_content: String`  <sub>:14</sub>
    - `joiners: String`  <sub>:15</sub>
    - `philosophy: bool`  <sub>:16</sub>
    - `off_school: bool`  <sub>:17</sub>
- `pub enum CgyyCommand`
  <sub>enum · rust/crates/ginkgo_domain/src/features/cgyy_booking.rs:21</sub>
- `pub struct BookingChoice`
  <sub>struct · rust/crates/ginkgo_domain/src/features/cgyy_booking.rs:49</sub>
    - `space_id: i64`  <sub>:50</sub>
    - `space_name: String`  <sub>:51</sub>
    - `time_id: i64`  <sub>:52</sub>
    - `time: String`  <sub>:53</sub>
- `pub struct Purpose`
  <sub>struct · rust/crates/ginkgo_domain/src/features/cgyy_booking.rs:56</sub>
    - `id: i64`  <sub>:57</sub>
    - `name: String`  <sub>:58</sub>
- `pub struct BookingOptions`
  <sub>struct · rust/crates/ginkgo_domain/src/features/cgyy_booking.rs:61</sub>
    - `choices: Vec<BookingChoice>`  <sub>:62</sub>
    - `purposes: Vec<Purpose>`  <sub>:63</sub>
    - `uses_fallback_purposes: bool`  <sub>:64</sub>
- `pub struct BookingChallenge`
  <sub>struct · rust/crates/ginkgo_domain/src/features/cgyy_booking.rs:67</sub>
    - `id: String`  <sub>:68</sub>
    - `background: String`  <sub>:69</sub>
    - `jigsaw: String`  <sub>:70</sub>
- `pub struct BookingReview`
  <sub>struct · rust/crates/ginkgo_domain/src/features/cgyy_booking.rs:73</sub>
    - `id: String`  <sub>:74</sub>
    - `orders: Vec<super::cgyy::Order>`  <sub>:75</sub>
- `pub struct CgyyActionResult`
  <sub>struct · rust/crates/ginkgo_domain/src/features/cgyy_booking.rs:78</sub>
    - `state: String`  <sub>:79</sub>
    - `message: String`  <sub>:80</sub>
    - `options: Option<BookingOptions>`  <sub>:82</sub>
    - `challenge: Option<BookingChallenge>`  <sub>:84</sub>
    - `review: Option<BookingReview>`  <sub>:86</sub>
- `pub fn message(state: &str, message: &str) -> Self {…}`
  <sub>fn · rust/crates/ginkgo_domain/src/features/cgyy_booking.rs:89</sub>

## checkin

- `pub enum CheckInStatus`
  <sub>enum · rust/crates/ginkgo_domain/src/features/checkin.rs:2</sub>
- `pub fn name(self) -> &'static str {…}`
  <sub>fn · rust/crates/ginkgo_domain/src/features/checkin.rs:10</sub>
- `pub struct CheckInCourse`
  <sub>struct · rust/crates/ginkgo_domain/src/features/checkin.rs:20</sub>
    - `id: String`  <sub>:21</sub>
    - `course_id: Option<String>`  <sub>:22</sub>
    - `course_num: Option<String>`  <sub>:23</sub>
    - `course_name: String`  <sub>:24</sub>
    - `begins_at: String`  <sub>:25</sub>
    - `ends_at: String`  <sub>:26</sub>
    - `status: CheckInStatus`  <sub>:27</sub>
    - `teacher_name: Option<String>`  <sub>:28</sub>
    - `classroom_name: Option<String>`  <sub>:29</sub>
    - `merged_record_count: usize`  <sub>:30</sub>
    - `conflicting: bool`  <sub>:31</sub>
    - `sign_in_allowed: bool`  <sub>:32</sub>
- `pub fn sign_in_window(date: &str, begin: &str, end: &str, now: &str) -> bool {…}` — Product rule: opens ten minutes before class, closes at its end. Parse
  <sub>fn · rust/crates/ginkgo_domain/src/features/checkin.rs:37</sub>

## classroom

- `pub struct Room`
  <sub>struct · rust/crates/ginkgo_domain/src/features/classroom.rs:7</sub>
    - `id: String`  <sub>:8</sub>
    - `floorid: String`  <sub>:9</sub>
    - `name: String`  <sub>:10</sub>
    - `kxsds: String`  <sub>:11</sub>
- `pub fn sections(&self) -> Result<Vec<i32>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_domain/src/features/classroom.rs:15</sub>
- `pub enum Sort`
  <sub>enum · rust/crates/ginkgo_domain/src/features/classroom.rs:42</sub>
- `pub struct FilterRequest`
  <sub>struct · rust/crates/ginkgo_domain/src/features/classroom.rs:50</sub>
    - `source_rooms: BTreeMap<String, Vec<Room>>`  <sub>:51</sub>
    - `search: String`  <sub>:52</sub>
    - `section: i32`  <sub>:53</sub>
    - `minimum_free_sections: i32`  <sub>:54</sub>
    - `minimum_consecutive_sections: i32`  <sub>:55</sub>
    - `building: Option<String>`  <sub>:56</sub>
    - `sort: Sort`  <sub>:57</sub>
- `pub struct Summary`
  <sub>struct · rust/crates/ginkgo_domain/src/features/classroom.rs:62</sub>
    - `room_count: usize`  <sub>:63</sub>
    - `building_count: usize`  <sub>:64</sub>
    - `free_slot_count: usize`  <sub>:65</sub>
- `pub struct RoomResult`
  <sub>struct · rust/crates/ginkgo_domain/src/features/classroom.rs:69</sub>
    - `room: Room`  <sub>:70</sub>
    - `sections: Vec<i32>`  <sub>:71</sub>
    - `longest_run: usize`  <sub>:72</sub>
- `pub fn section_states(&self) -> Vec<(i32, bool)> {…}`
  <sub>fn · rust/crates/ginkgo_domain/src/features/classroom.rs:76</sub>
- `pub struct FilterResult`
  <sub>struct · rust/crates/ginkgo_domain/src/features/classroom.rs:84</sub>
    - `buildings: BTreeMap<String, Vec<RoomResult>>`  <sub>:85</sub>
    - `summary: Summary`  <sub>:86</sub>
- `pub fn room_ids_by_building(rooms: &BTreeMap<String, Vec<Room>>) -> BTreeMap<String, Vec<String>> {…}`
  <sub>fn · rust/crates/ginkgo_domain/src/features/classroom.rs:89</sub>
- `pub fn normalize(value: &str) -> String {…}`
  <sub>fn · rust/crates/ginkgo_domain/src/features/classroom.rs:101</sub>
- `pub fn filter(request: FilterRequest) -> Result<FilterResult, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_domain/src/features/classroom.rs:140</sub>

## grades

- `pub struct GradeCourse`
  <sub>struct · rust/crates/ginkgo_domain/src/features/grades.rs:6</sub>
    - `id: String`  <sub>:7</sub>
    - `name: String`  <sub>:8</sub>
    - `code: Option<String>`  <sub>:9</sub>
    - `credit: Option<f64>`  <sub>:10</sub>
    - `score: String`  <sub>:11</sub>
    - `score_value: Option<f64>`  <sub>:12</sub>
    - `score_type: Option<String>`  <sub>:13</sub>
    - `course_type: Option<String>`  <sub>:14</sub>
- `pub struct GradeSummary`
  <sub>struct · rust/crates/ginkgo_domain/src/features/grades.rs:19</sub>
    - `course_count: i32`  <sub>:20</sub>
    - `credit_total: f64`  <sub>:21</sub>
    - `weighted_average: Option<f64>`  <sub>:22</sub>
    - `grade_point_average: Option<f64>`  <sub>:23</sub>
- `pub fn term_parts(code: &str) -> Result<(String, String), AppError> {…}`
  <sub>fn · rust/crates/ginkgo_domain/src/features/grades.rs:26</sub>
- `pub fn summarize(courses: &[GradeCourse]) -> GradeSummary {…}`
  <sub>fn · rust/crates/ginkgo_domain/src/features/grades.rs:44</sub>

## graduate

- `pub struct ReadRow`
  <sub>struct · rust/crates/ginkgo_domain/src/features/graduate.rs:4</sub>
    - `title: String`  <sub>:5</sub>
    - `detail: String`  <sub>:6</sub>
    - `is_course: bool` — Explicitly distinguishes a course with an unknown result from report metadata.  <sub>:9</sub>
    - `completed: Option<bool>`  <sub>:11</sub>
    - `credit: Option<f64>`  <sub>:13</sub>
    - `semester: Option<String>`  <sub>:15</sub>
- `pub struct ReadSection`
  <sub>struct · rust/crates/ginkgo_domain/src/features/graduate.rs:21</sub>
    - `title: String`  <sub>:22</sub>
    - `rows: Vec<ReadRow>`  <sub>:23</sub>
    - `progress: Option<CreditProgress>`  <sub>:25</sub>
- `pub struct CreditProgress` — Requirement and officially recognized credits; pending never reduces the gap.
  <sub>struct · rust/crates/ginkgo_domain/src/features/graduate.rs:30</sub>
    - `required: Option<f64>`  <sub>:31</sub>
    - `earned: Option<f64>`  <sub>:32</sub>
    - `pending: Option<f64>`  <sub>:33</sub>
- `pub struct AcademicData`
  <sub>struct · rust/crates/ginkgo_domain/src/features/graduate.rs:37</sub>
    - `sections: Vec<ReadSection>`  <sub>:38</sub>
    - `notice: Option<String>`  <sub>:39</sub>

## homework

- `pub enum HomeworkStatus`
  <sub>enum · rust/crates/ginkgo_domain/src/features/homework.rs:6</sub>
- `pub enum HomeworkDeadlineStatus`
  <sub>enum · rust/crates/ginkgo_domain/src/features/homework.rs:14</sub>
- `pub fn parse_school_deadline(text: &str) -> Option<DateTime<chrono_tz::Tz>> {…}` — Parse a school deadline string into Asia/Shanghai wall instant.
  <sub>fn · rust/crates/ginkgo_domain/src/features/homework.rs:24</sub>
- `pub fn classify_deadline( due_at: Option<&str>, beijing_now: DateTime<chrono_tz::Tz>, ) -> HomeworkDeadlineStatus {…}` — Classify a homework deadline against Beijing wall clock time.
  <sub>fn · rust/crates/ginkgo_domain/src/features/homework.rs:71</sub>
- `pub fn is_homework_overdue(due_at: Option<&str>, beijing_now: DateTime<chrono_tz::Tz>) -> bool {…}`
  <sub>fn · rust/crates/ginkgo_domain/src/features/homework.rs:122</sub>
- `pub struct HomeworkItem`
  <sub>struct · rust/crates/ginkgo_domain/src/features/homework.rs:128</sub>
    - `course_role: Option<String>`  <sub>:130</sub>
    - `id: String`  <sub>:131</sub>
    - `course_id: Option<String>`  <sub>:132</sub>
    - `course_name: String`  <sub>:133</sub>
    - `teacher_name: Option<String>`  <sub>:135</sub>
    - `title: String`  <sub>:136</sub>
    - `published_at: Option<String>`  <sub>:137</sub>
    - `due_at: Option<String>`  <sub>:138</sub>
    - `status: HomeworkStatus`  <sub>:139</sub>
    - `status_detail: Option<String>`  <sub>:140</sub>
    - `score: Option<String>`  <sub>:141</sub>
- `pub struct HomeworkPage`
  <sub>struct · rust/crates/ginkgo_domain/src/features/homework.rs:146</sub>
    - `page_num: i32`  <sub>:147</sub>
    - `pages: Option<i32>`  <sub>:148</sub>
    - `has_next: Option<bool>`  <sub>:149</sub>
    - `items: Vec<HomeworkItem>`  <sub>:150</sub>
- `pub struct HomeworkData`
  <sub>struct · rust/crates/ginkgo_domain/src/features/homework.rs:154</sub>
    - `term_code: String`  <sub>:155</sub>
    - `term_name: String`  <sub>:156</sub>
    - `items: Vec<HomeworkItem>`  <sub>:157</sub>
    - `roles_complete: bool`  <sub>:158</sub>
- `pub struct HomeworkDetail`
  <sub>struct · rust/crates/ginkgo_domain/src/features/homework.rs:163</sub>
    - `source_url: Option<String>` — Validated browser destination supplied by the provider, independent of the UI.  <sub>:166</sub>
    - `content: Option<String>`  <sub>:167</sub>
    - `published_at: Option<String>`  <sub>:168</sub>
    - `due_at: Option<String>`  <sub>:169</sub>
    - `score: Option<String>`  <sub>:170</sub>
    - `status: HomeworkStatus`  <sub>:171</sub>
    - `status_detail: Option<String>`  <sub>:172</sub>
    - `submitted_at: Option<String>`  <sub>:173</sub>

## library

- `pub struct LibraryVenue`
  <sub>struct · rust/crates/ginkgo_domain/src/features/library.rs:5</sub>
    - `id: String`  <sub>:6</sub>
    - `name: String`  <sub>:7</sub>
    - `free: i32`  <sub>:8</sub>
    - `total: i32`  <sub>:9</sub>
- `pub struct LibraryArea`
  <sub>struct · rust/crates/ginkgo_domain/src/features/library.rs:14</sub>
    - `id: String`  <sub>:15</sub>
    - `name: String`  <sub>:16</sub>
    - `free: i32`  <sub>:17</sub>
    - `total: i32`  <sub>:18</sub>
- `pub struct LibrarySlot`
  <sub>struct · rust/crates/ginkgo_domain/src/features/library.rs:23</sub>
    - `id: String` — Composite key: day + "/" + upstream segment id.  <sub>:25</sub>
    - `day: String`  <sub>:26</sub>
    - `start: String`  <sub>:27</sub>
    - `end: String`  <sub>:28</sub>
- `pub struct LibrarySeat`
  <sub>struct · rust/crates/ginkgo_domain/src/features/library.rs:33</sub>
    - `id: String`  <sub>:34</sub>
    - `name: String`  <sub>:35</sub>
    - `status_name: String`  <sub>:36</sub>
    - `available: bool`  <sub>:37</sub>
- `pub struct LibraryBooking`
  <sub>struct · rust/crates/ginkgo_domain/src/features/library.rs:42</sub>
    - `id: String`  <sub>:43</sub>
    - `title: String` — Pre-composed display title (space/area/seat), never a member identity.  <sub>:45</sub>
    - `area_name: String`  <sub>:46</sub>
    - `seat_number: String`  <sub>:47</sub>
    - `day: String`  <sub>:48</sub>
    - `start_time: String`  <sub>:49</sub>
    - `end_time: String`  <sub>:50</sub>
    - `status: String`  <sub>:51</sub>
    - `status_name: String`  <sub>:52</sub>
    - `booking_type: Option<i32>`  <sub>:54</sub>
    - `can_cancel: Option<bool>`  <sub>:56</sub>
    - `flag_in: Option<bool>`  <sub>:58</sub>
    - `flag_out: Option<bool>`  <sub>:60</sub>
    - `flag_leave: Option<bool>`  <sub>:62</sub>
- `pub struct LibraryHistoryPage`
  <sub>struct · rust/crates/ginkgo_domain/src/features/library.rs:67</sub>
    - `bookings: Vec<LibraryBooking>`  <sub>:68</sub>
    - `page: i32`  <sub>:69</sub>
    - `page_size: i32`  <sub>:70</sub>
    - `total: Option<i64>`  <sub>:71</sub>
    - `has_next: bool`  <sub>:72</sub>
- `pub fn current_actions(booking: &LibraryBooking) -> Vec<String> {…}`
  <sub>fn · rust/crates/ginkgo_domain/src/features/library.rs:75</sub>
- `pub fn active_at(&self, now: chrono::NaiveDateTime) -> bool {…}`
  <sub>fn · rust/crates/ginkgo_domain/src/features/library.rs:86</sub>
- `pub fn allows(&self, action: &str, now: chrono::NaiveDateTime) -> bool {…}`
  <sub>fn · rust/crates/ginkgo_domain/src/features/library.rs:100</sub>

## library_books

- `pub struct BookHit` — One catalogue search hit. Fields the school reports as strings, arrays or
  <sub>struct · rust/crates/ginkgo_domain/src/features/library_books.rs:9</sub>
    - `bib_id: String`  <sub>:10</sub>
    - `title: String`  <sub>:11</sub>
    - `author: String`  <sub>:12</sub>
    - `publisher: String`  <sub>:13</sub>
    - `year: String`  <sub>:14</sub>
    - `callno: String` — Search returns an array, other sources a string; both join with " · ".  <sub>:16</sub>
    - `isbn: String`  <sub>:17</sub>
    - `items_available: Option<i64>` — Reported copy availability, or `None` when the source stays silent.  <sub>:20</sub>
    - `item_count: Option<i64>` — Reported total copy count, or `None`.  <sub>:23</sub>
- `pub struct BookPage` — One bounded page of hits. `total` keeps the school's own value while
  <sub>struct · rust/crates/ginkgo_domain/src/features/library_books.rs:30</sub>
    - `page: i64`  <sub>:31</sub>
    - `page_size: i64`  <sub>:32</sub>
    - `total: i64`  <sub>:33</sub>
    - `actual_total: i64`  <sub>:34</sub>
    - `items: Vec<BookHit>`  <sub>:35</sub>
    - `has_more: bool` — True when the school reported more matches than this page returned.  <sub>:37</sub>
- `pub struct BookHolding` — One physical copy. Status stays the school's own text; it is never turned
  <sub>struct · rust/crates/ginkgo_domain/src/features/library_books.rs:44</sub>
    - `call_no: String`  <sub>:45</sub>
    - `bar_code: String`  <sub>:46</sub>
    - `library: String`  <sub>:47</sub>
    - `location: String`  <sub>:48</sub>
    - `status: String`  <sub>:49</sub>

## library_loans

- `pub struct LibraryLoan`
  <sub>struct · rust/crates/ginkgo_domain/src/features/library_loans.rs:5</sub>
    - `id: String`  <sub>:6</sub>
    - `title: Option<String>`  <sub>:7</sub>
    - `author: Option<String>`  <sub>:8</sub>
    - `call_number: Option<String>`  <sub>:9</sub>
    - `borrowed_at: Option<String>`  <sub>:10</sub>
    - `due_at: Option<String>`  <sub>:11</sub>
- `pub struct LibraryLoanPage`
  <sub>struct · rust/crates/ginkgo_domain/src/features/library_loans.rs:15</sub>
    - `items: Vec<LibraryLoan>`  <sub>:16</sub>
    - `page: u32`  <sub>:17</sub>
    - `total: u32`  <sub>:18</sub>
    - `has_more: bool`  <sub>:19</sub>

## library_stats

- `pub struct CountPair`
  <sub>struct · rust/crates/ginkgo_domain/src/features/library_stats.rs:4</sub>
    - `available: i32`  <sub>:5</sub>
    - `total: i32`  <sub>:6</sub>
- `pub struct ReadingRoom`
  <sub>struct · rust/crates/ginkgo_domain/src/features/library_stats.rs:10</sub>
    - `name: String`  <sub>:11</sub>
    - `people: i32`  <sub>:12</sub>
- `pub struct CampusStats`
  <sub>struct · rust/crates/ginkgo_domain/src/features/library_stats.rs:16</sub>
    - `id: String`  <sub>:17</sub>
    - `name: String`  <sub>:18</sub>
    - `people: i32`  <sub>:19</sub>
    - `reading_rooms: Vec<ReadingRoom>`  <sub>:20</sub>
    - `seats: Option<CountPair>`  <sub>:21</sub>
    - `study_rooms: Option<CountPair>`  <sub>:22</sub>
    - `lockers: Option<CountPair>`  <sub>:23</sub>

## mutation

- `pub enum MutationState`
  <sub>enum · rust/crates/ginkgo_domain/src/features/mutation.rs:6</sub>
- `pub struct MutationOutcome`
  <sub>struct · rust/crates/ginkgo_domain/src/features/mutation.rs:14</sub>
    - `state: MutationState`  <sub>:15</sub>
    - `message: String`  <sub>:16</sub>
- `pub fn new(state: MutationState, message: &str) -> Self {…}`
  <sub>fn · rust/crates/ginkgo_domain/src/features/mutation.rs:19</sub>
- `pub fn uncertain() -> Self {…}`
  <sub>fn · rust/crates/ginkgo_domain/src/features/mutation.rs:25</sub>
- `pub fn not_submitted(message: &str) -> Self {…}`
  <sub>fn · rust/crates/ginkgo_domain/src/features/mutation.rs:31</sub>

## notices

- `pub struct Notice`
  <sub>struct · rust/crates/ginkgo_domain/src/features/notices.rs:4</sub>
    - `title: String`  <sub>:5</sub>
    - `summary: String`  <sub>:6</sub>
    - `published_at: String`  <sub>:7</sub>
    - `url: String`  <sub>:8</sub>

## reminders

- `pub struct CourseReminderInput`
  <sub>struct · rust/crates/ginkgo_domain/src/features/reminders.rs:7</sub>
    - `id: String`  <sub>:8</sub>
    - `week_start: String` — First day of the queried week, not the phone's current week.  <sub>:10</sub>
    - `day: i32`  <sub>:11</sub>
    - `starts_at: String`  <sub>:12</sub>
    - `ends_at: String`  <sub>:13</sub>
- `pub struct TaskReminderInput`
  <sub>struct · rust/crates/ginkgo_domain/src/features/reminders.rs:17</sub>
    - `id: String`  <sub>:18</sub>
    - `due: String` — Only a validated precise RFC3339 instant is eligible; date-only is not an alarm.  <sub>:20</sub>
    - `completed: bool`  <sub>:21</sub>
- `pub struct LocalReminderPlan`
  <sub>struct · rust/crates/ginkgo_domain/src/features/reminders.rs:25</sub>
    - `key: String`  <sub>:26</sub>
    - `group: String`  <sub>:27</sub>
    - `at_millis: i64`  <sub>:28</sub>
    - `expires_millis: i64`  <sub>:29</sub>
- `pub struct ReminderPlanningResult`
  <sub>struct · rust/crates/ginkgo_domain/src/features/reminders.rs:33</sub>
    - `plans: Vec<LocalReminderPlan>`  <sub>:34</sub>
    - `skipped: u32`  <sub>:35</sub>
- `pub fn plan_local_reminders( courses: &[CourseReminderInput], tasks: &[TaskReminderInput], now_millis: i64, ) -> ReminderPlanningResult {…}` — Course: ten minutes before an explicitly timed lesson, expires at lesson start.
  <sub>fn · rust/crates/ginkgo_domain/src/features/reminders.rs:43</sub>
- `pub struct CheckInReminderInput` — A check-in session that may still need a reminder.
  <sub>struct · rust/crates/ginkgo_domain/src/features/reminders.rs:180</sub>
    - `id: String`  <sub>:181</sub>
    - `date: String` — The queried school day, not the phone's current day.  <sub>:183</sub>
    - `begins_at: String`  <sub>:184</sub>
    - `ends_at: String`  <sub>:185</sub>
    - `not_signed: bool` — True only when the session is exactly "not signed". An unknown status  <sub>:188</sub>
    - `conflicting: bool`  <sub>:189</sub>
    - `sign_in_allowed: Option<bool>` — Explicit false covers merged sessions with conflicting records.  <sub>:191</sub>
    - `merged_record_count: usize`  <sub>:192</sub>
- `pub struct HomeworkReminderInput` — A school assignment that may still need a deadline reminder.
  <sub>struct · rust/crates/ginkgo_domain/src/features/reminders.rs:197</sub>
    - `id: String`  <sub>:198</sub>
    - `due_at: String` — The school deadline string. An unparsable deadline plans nothing.  <sub>:200</sub>
    - `pending: bool`  <sub>:201</sub>
- `pub fn plan_checkin_homework_reminders( checkin: &[CheckInReminderInput], homework: &[HomeworkReminderInput], now_millis: i64, ) -> ReminderPlanningResult {…}` — Plan the check-in and assignment reminders.
  <sub>fn · rust/crates/ginkgo_domain/src/features/reminders.rs:215</sub>

## schedule

- `pub struct Term`
  <sub>struct · rust/crates/ginkgo_domain/src/features/schedule.rs:8</sub>
    - `id: String`  <sub>:9</sub>
    - `name: String`  <sub>:10</sub>
    - `selected: bool`  <sub>:11</sub>
- `pub struct Week`
  <sub>struct · rust/crates/ginkgo_domain/src/features/schedule.rs:16</sub>
    - `number: i32`  <sub>:17</sub>
    - `start_date: NaiveDate`  <sub>:18</sub>
    - `end_date: NaiveDate`  <sub>:19</sub>
    - `current: bool`  <sub>:20</sub>
- `pub struct CourseMeeting`
  <sub>struct · rust/crates/ginkgo_domain/src/features/schedule.rs:25</sub>
    - `id: String`  <sub>:26</sub>
    - `name: String`  <sub>:27</sub>
    - `day: i32`  <sub>:28</sub>
    - `start_section: i32`  <sub>:29</sub>
    - `end_section: i32`  <sub>:30</sub>
    - `start_time: Option<String>`  <sub>:31</sub>
    - `end_time: Option<String>`  <sub>:32</sub>
    - `place: Option<String>`  <sub>:33</sub>
    - `teacher: Option<String>`  <sub>:34</sub>
    - `color: Option<String>`  <sub>:35</sub>
- `pub struct Exam`
  <sub>struct · rust/crates/ginkgo_domain/src/features/schedule.rs:40</sub>
    - `id: String`  <sub>:41</sub>
    - `course_name: String`  <sub>:42</sub>
    - `course_no: Option<String>`  <sub>:43</sub>
    - `exam_time_description: Option<String>`  <sub>:44</sub>
    - `exam_date: Option<String>`  <sub>:45</sub>
    - `start_time: Option<String>`  <sub>:46</sub>
    - `end_time: Option<String>`  <sub>:47</sub>
    - `exam_place: Option<String>`  <sub>:48</sub>
    - `exam_seat_no: Option<String>`  <sub>:49</sub>
    - `week: Option<i32>`  <sub>:50</sub>
    - `exam_status: Option<String>`  <sub>:51</sub>
    - `exam_type: Option<String>`  <sub>:52</sub>
    - `task_id: Option<String>`  <sub>:53</sub>
- `pub struct Course`
  <sub>struct · rust/crates/ginkgo_domain/src/features/schedule.rs:58</sub>
    - `id: String`  <sub>:59</sub>
    - `name: String`  <sub>:60</sub>
    - `day: i32`  <sub>:61</sub>
    - `start_section: i32`  <sub>:62</sub>
    - `end_section: i32`  <sub>:63</sub>
- `pub struct Snapshot`
  <sub>struct · rust/crates/ginkgo_domain/src/features/schedule.rs:67</sub>
    - `term_id: String`  <sub>:69</sub>
    - `week_number: i32`  <sub>:70</sub>
    - `courses: Vec<Course>`  <sub>:71</sub>
    - `term_courses: Option<BTreeMap<String, Vec<Course>>>`  <sub>:72</sub>
- `pub struct MergeRequest`
  <sub>struct · rust/crates/ginkgo_domain/src/features/schedule.rs:75</sub>
    - `previous: Option<Snapshot>`  <sub>:76</sub>
    - `fetched: Snapshot`  <sub>:77</sub>
- `pub fn select_week(&self, week: i32) -> Option<Self> {…}`
  <sub>fn · rust/crates/ginkgo_domain/src/features/schedule.rs:107</sub>
- `pub fn retain_weeks(request: MergeRequest) -> Result<Snapshot, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_domain/src/features/schedule.rs:117</sub>

## shuttle

- `pub struct ShuttleRun` — One scheduled departure.
  <sub>struct · rust/crates/ginkgo_domain/src/features/shuttle.rs:8</sub>
    - `index: String` — Published sequence number ("班次").  <sub>:10</sub>
    - `time: String` — Published departure time exactly as printed.  <sub>:12</sub>
    - `capacity: String` — Published seat count ("可乘人数"); empty when the table has none.  <sub>:14</sub>
- `pub struct ShuttleSection` — One direction pair under a validity label such as "星期一至星期五".
  <sub>struct · rust/crates/ginkgo_domain/src/features/shuttle.rs:20</sub>
    - `label: String`  <sub>:21</sub>
    - `left: Vec<ShuttleRun>`  <sub>:22</sub>
    - `right: Vec<ShuttleRun>`  <sub>:23</sub>
- `pub struct ShuttleTable` — One published table: two directions plus their dated sections.
  <sub>struct · rust/crates/ginkgo_domain/src/features/shuttle.rs:29</sub>
    - `left: String`  <sub>:30</sub>
    - `right: String`  <sub>:31</sub>
    - `sections: Vec<ShuttleSection>`  <sub>:32</sub>
- `pub struct ShuttleTimetable`
  <sub>struct · rust/crates/ginkgo_domain/src/features/shuttle.rs:37</sub>
    - `tables: Vec<ShuttleTable>`  <sub>:38</sub>
    - `source: String` — Official page the data was read from, for traceability.  <sub>:40</sub>
    - `live_source: String` — Official dynamic system entrance, separate from the published timetable.  <sub>:42</sub>

## tasks

- `pub enum TaskSource` — Opaque, provider-qualified identity, scoped by the task document's account.
  <sub>enum · rust/crates/ginkgo_domain/src/features/tasks.rs:10</sub>
- `pub fn homework(assignment_id: &str) -> Result<Self, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_domain/src/features/tasks.rs:15</sub>
- `pub struct Task`
  <sub>struct · rust/crates/ginkgo_domain/src/features/tasks.rs:37</sub>
    - `id: String`  <sub>:38</sub>
    - `title: String`  <sub>:39</sub>
    - `due: String` — Empty means no deadline; a calendar date remains a date, not a precise deadline.  <sub>:42</sub>
    - `completed: bool`  <sub>:43</sub>
    - `source: Option<TaskSource>`  <sub>:45</sub>
- `pub struct Document`
  <sub>struct · rust/crates/ginkgo_domain/src/features/tasks.rs:49</sub>
    - `version: u32`  <sub>:50</sub>
    - `tasks: Vec<Task>`  <sub>:51</sub>
- `pub fn validate(title: &str, due: &str) -> Result<(), AppError> {…}`
  <sub>fn · rust/crates/ginkgo_domain/src/features/tasks.rs:53</sub>
- `pub fn compare_due(left: &str, right: &str) -> Ordering {…}` — Compare validated deadlines chronologically, with missing deadlines last.
  <sub>fn · rust/crates/ginkgo_domain/src/features/tasks.rs:136</sub>
- `pub fn parse(value: serde_json::Value) -> Result<Vec<Task>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_domain/src/features/tasks.rs:148</sub>
- `pub fn parse_bytes(bytes: &[u8]) -> Result<Vec<Task>, AppError> {…}` — Decode persisted bytes directly so duplicate object fields are rejected,
  <sub>fn · rust/crates/ginkgo_domain/src/features/tasks.rs:155</sub>

## today

- `pub struct TodayCourse`
  <sub>struct · rust/crates/ginkgo_domain/src/features/today.rs:5</sub>
    - `name: String`  <sub>:6</sub>
    - `place: Option<String>`  <sub>:7</sub>
    - `time: Option<String>`  <sub>:8</sub>
    - `short_name: Option<String>`  <sub>:9</sub>

## updates

- `pub struct UpdateSummary`
  <sub>struct · rust/crates/ginkgo_domain/src/features/updates.rs:5</sub>
    - `current: String`  <sub>:6</sub>
    - `latest: Option<String>`  <sub>:7</sub>
    - `available: bool`  <sub>:8</sub>
    - `page_url: Option<String>`  <sub>:9</sub>
    - `notes: Option<String>`  <sub>:10</sub>
    - `apk_available: bool`  <sub>:11</sub>
    - `download: Option<AndroidDownload>` — Present only when GitHub supplies a complete, verifiable arm64 asset.  <sub>:13</sub>
- `pub struct AndroidDownload`
  <sub>struct · rust/crates/ginkgo_domain/src/features/updates.rs:17</sub>
    - `version: String`  <sub>:18</sub>
    - `name: String`  <sub>:19</sub>
    - `url: String`  <sub>:20</sub>
    - `api_url: String`  <sub>:21</sub>
    - `size: u64`  <sub>:22</sub>
    - `sha256: String`  <sub>:23</sub>
