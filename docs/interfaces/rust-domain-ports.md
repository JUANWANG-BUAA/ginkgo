# 领域业务端口（ginkgo_domain::ports）

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。

稳定能力边界；core 只依赖这些 trait，不依赖学校实现。

## 目录

- [academic](#academic) (9)
- [bykc](#bykc) (4)
- [cgyy](#cgyy) (5)
- [checkin](#checkin) (5)
- [classroom](#classroom) (3)
- [graduate](#graduate) (3)
- [homework](#homework) (3)
- [homework_submission](#homeworksubmission) (10)
- [learning](#learning) (17)
- [library](#library) (5)
- [library_books](#librarybooks) (7)
- [library_loans](#libraryloans) (1)
- [library_stats](#librarystats) (2)
- [notices](#notices) (2)
- [outcome](#outcome) (1)
- [query_snapshots](#querysnapshots) (1)
- [session](#session) (6)
- [shuttle](#shuttle) (1)

## academic

- `pub struct ScheduleData`  
  <sub>struct · rust/crates/ginkgo_domain/src/ports/academic.rs:11</sub>
    - `terms: Vec<Term>`  <sub>:12</sub>
    - `weeks: Vec<Week>`  <sub>:13</sub>
    - `term_id: String`  <sub>:14</sub>
    - `week_number: i32`  <sub>:15</sub>
    - `courses: Vec<CourseMeeting>`  <sub>:16</sub>
    - `exams: Vec<Exam>`  <sub>:17</sub>
- `pub struct ScheduleQueryInput`  
  <sub>struct · rust/crates/ginkgo_domain/src/ports/academic.rs:20</sub>
    - `term_id: Option<String>`  <sub>:21</sub>
    - `week: Option<i32>`  <sub>:22</sub>
    - `force_refresh: bool`  <sub>:23</sub>
- `pub struct ScheduleOutcome`  
  <sub>struct · rust/crates/ginkgo_domain/src/ports/academic.rs:27</sub>
    - `data: ScheduleData`  <sub>:28</sub>
    - `fetched_at: String`  <sub>:29</sub>
    - `from_cache: bool`  <sub>:30</sub>
    - `stale: bool`  <sub>:31</sub>
    - `failure: Option<AppError>`  <sub>:32</sub>
- `pub struct TodayOutcome`  
  <sub>struct · rust/crates/ginkgo_domain/src/ports/academic.rs:36</sub>
    - `date: String`  <sub>:37</sub>
    - `courses: Vec<TodayCourse>`  <sub>:38</sub>
    - `fetched_at: String`  <sub>:39</sub>
    - `from_cache: bool`  <sub>:40</sub>
    - `stale: bool`  <sub>:41</sub>
    - `failure: Option<AppError>`  <sub>:42</sub>
- `pub struct GradeData`  
  <sub>struct · rust/crates/ginkgo_domain/src/ports/academic.rs:46</sub>
    - `term_id: String`  <sub>:47</sub>
    - `courses: Vec<GradeCourse>`  <sub>:48</sub>
- `pub struct GradeOutcome`  
  <sub>struct · rust/crates/ginkgo_domain/src/ports/academic.rs:51</sub>
    - `term_id: String`  <sub>:52</sub>
    - `courses: Vec<GradeCourse>`  <sub>:53</sub>
    - `summary: GradeSummary`  <sub>:54</sub>
    - `fetched_at: String`  <sub>:55</sub>
    - `from_cache: bool`  <sub>:56</sub>
    - `stale: bool`  <sub>:57</sub>
    - `failure: Option<AppError>`  <sub>:58</sub>
- `pub trait ScheduleSource: Send + Sync`  
  <sub>trait · rust/crates/ginkgo_domain/src/ports/academic.rs:61</sub>
    - `fn load_schedule( &self, input: &ScheduleQueryInput, ) -> Future<Result<ScheduleOutcome, AppError>>;`  <sub>:62</sub>
- `pub trait TodaySource: Send + Sync`  
  <sub>trait · rust/crates/ginkgo_domain/src/ports/academic.rs:68</sub>
    - `fn load_today( &self, force_refresh: bool, ) -> Future<Result<TodayOutcome, AppError>>;`  <sub>:69</sub>
- `pub trait GradeSource: Send + Sync`  
  <sub>trait · rust/crates/ginkgo_domain/src/ports/academic.rs:75</sub>
    - `fn load_grades( &self, term_code: Option<&str>, force_refresh: bool, ) -> Future<Result<GradeOutcome, AppError>>;`  <sub>:76</sub>
    - `fn load_grade_terms( &self, ) -> Future<Result<Vec<Term>, AppError>>;`  <sub>:81</sub>

## bykc

- `pub trait BykcSource: Send + Sync`  
  <sub>trait · rust/crates/ginkgo_domain/src/ports/bykc.rs:4</sub>
    - `fn load_bykc( &self, force: bool, ) -> Future<Result<BykcOutcome, AppError>>;`  <sub>:5</sub>
    - `fn load_bykc_chosen( &self, force: bool, ) -> Future<Result<BykcChosenOutcome, AppError>>;`  <sub>:9</sub>
    - `fn load_bykc_statistics( &self, force: bool, ) -> Future<Result<BykcStatisticsOutcome, AppError>>;`  <sub>:13</sub>
- `pub type BykcOutcome = DataOutcome<crate::features::bykc::Catalog>;`  
  <sub>type · rust/crates/ginkgo_domain/src/ports/bykc.rs:19</sub>
- `pub type BykcChosenOutcome = DataOutcome<crate::features::bykc::ChosenCourses>;`  
  <sub>type · rust/crates/ginkgo_domain/src/ports/bykc.rs:21</sub>
- `pub type BykcStatisticsOutcome = DataOutcome<crate::features::bykc::LearningStatistics>;`  
  <sub>type · rust/crates/ginkgo_domain/src/ports/bykc.rs:23</sub>

## cgyy

- `pub enum CgyyQuery`  
  <sub>enum · rust/crates/ginkgo_domain/src/ports/cgyy.rs:5</sub>
- `pub enum CgyyData`  
  <sub>enum · rust/crates/ginkgo_domain/src/ports/cgyy.rs:15</sub>
- `pub trait CgyySource: Send + Sync`  
  <sub>trait · rust/crates/ginkgo_domain/src/ports/cgyy.rs:23</sub>
    - `fn load_cgyy( &self, query: CgyyQuery, force: bool, ) -> Future<Result<CgyyOutcome, AppError>>;`  <sub>:24</sub>
- `pub type CgyyOutcome = DataOutcome<CgyyData>;`  
  <sub>type · rust/crates/ginkgo_domain/src/ports/cgyy.rs:31</sub>
- `pub trait CgyyMutationSource: Send + Sync`  
  <sub>trait · rust/crates/ginkgo_domain/src/ports/cgyy.rs:33</sub>
    - `fn execute_cgyy( &self, command: crate::features::cgyy_booking::CgyyCommand, ) -> impl std::future::Future<`  <sub>:34</sub>

## checkin

- `pub struct CheckInOutcome`  
  <sub>struct · rust/crates/ginkgo_domain/src/ports/checkin.rs:4</sub>
    - `date: String` — School-local date, yyyy-MM-dd.  <sub>:6</sub>
    - `courses: Vec<CheckInCourse>`  <sub>:7</sub>
    - `fetched_at: String`  <sub>:8</sub>
    - `from_cache: bool`  <sub>:9</sub>
    - `stale: bool`  <sub>:10</sub>
    - `failure: Option<AppError>`  <sub>:11</sub>
- `pub struct CheckInLoadProgress`  
  <sub>struct · rust/crates/ginkgo_domain/src/ports/checkin.rs:16</sub>
    - `phase: String`  <sub>:17</sub>
    - `elapsed_ms: Option<u128>`  <sub>:18</sub>
    - `stages: Vec<CheckInLoadStage>`  <sub>:19</sub>
- `pub struct CheckInLoadStage`  
  <sub>struct · rust/crates/ginkgo_domain/src/ports/checkin.rs:23</sub>
    - `phase: String`  <sub>:24</sub>
    - `milliseconds: u128`  <sub>:25</sub>
- `pub trait CheckInSource: Send + Sync`  
  <sub>trait · rust/crates/ginkgo_domain/src/ports/checkin.rs:28</sub>
    - `fn checkin_load_progress(&self) -> CheckInLoadProgress;`  <sub>:29</sub>
    - `fn load_checkin( &self, force_refresh: bool, ) -> Future<Result<CheckInOutcome, AppError>>;`  <sub>:30</sub>
    - `fn load_checkin_on_date( &self, date: Option<String>, force_refresh: bool, ) -> Future<Result<CheckInOutcome, AppError>>;`  <sub>:34</sub>
- `pub trait CheckInMutationSource: Send + Sync`  
  <sub>trait · rust/crates/ginkgo_domain/src/ports/checkin.rs:41</sub>
    - `fn submit_checkin( &self, course_id: &str, ) -> Future<crate::features::mutation::MutationOutcome>;`  <sub>:42</sub>

## classroom

- `pub struct ClassroomQueryInput`  
  <sub>struct · rust/crates/ginkgo_domain/src/ports/classroom.rs:7</sub>
    - `campus: i32`  <sub>:8</sub>
    - `date: String`  <sub>:9</sub>
    - `force_refresh: bool`  <sub>:10</sub>
    - `search: String`  <sub>:11</sub>
    - `section: i32`  <sub>:12</sub>
    - `minimum_free_sections: i32`  <sub>:13</sub>
    - `minimum_consecutive_sections: i32`  <sub>:14</sub>
    - `building: Option<String>`  <sub>:15</sub>
    - `sort: Sort`  <sub>:16</sub>
- `pub struct ClassroomOutcome`  
  <sub>struct · rust/crates/ginkgo_domain/src/ports/classroom.rs:20</sub>
    - `result: FilterResult`  <sub>:21</sub>
    - `fetched_at: String`  <sub>:22</sub>
    - `from_cache: bool`  <sub>:23</sub>
    - `stale: bool`  <sub>:24</sub>
    - `failure: Option<AppError>`  <sub>:25</sub>
- `pub trait ClassroomSource: Send + Sync`  
  <sub>trait · rust/crates/ginkgo_domain/src/ports/classroom.rs:28</sub>
    - `fn load_classrooms( &self, input: &ClassroomQueryInput, ) -> Future<Result<ClassroomOutcome, AppError>>;`  <sub>:29</sub>

## graduate

- `pub enum GraduatePart`  
  <sub>enum · rust/crates/ginkgo_domain/src/ports/graduate.rs:5</sub>
- `pub trait GraduateSource: Send + Sync`  
  <sub>trait · rust/crates/ginkgo_domain/src/ports/graduate.rs:10</sub>
    - `fn load_graduate( &self, force: bool, ) -> Future<Result<GraduateOutcome, AppError>>;`  <sub>:11</sub>
    - `fn load_graduate_execution( &self, force: bool, ) -> Future<Result<GraduateOutcome, AppError>> {…}` — Execution-report-only read. Existing fakes may delegate to Report; real  <sub>:17</sub>
    - `fn load_graduate_part( &self, part: GraduatePart, force: bool, ) -> Future<Result<GraduateOutcome, AppError>>;`  <sub>:23</sub>
- `pub type GraduateOutcome = DataOutcome<crate::features::graduate::AcademicData>;`  
  <sub>type · rust/crates/ginkgo_domain/src/ports/graduate.rs:30</sub>

## homework

- `pub struct HomeworkOutcome`  
  <sub>struct · rust/crates/ginkgo_domain/src/ports/homework.rs:5</sub>
    - `data: HomeworkData`  <sub>:6</sub>
    - `fetched_at: String`  <sub>:7</sub>
    - `failure: Option<AppError>`  <sub>:8</sub>
- `pub trait HomeworkSource: Send + Sync`  
  <sub>trait · rust/crates/ginkgo_domain/src/ports/homework.rs:11</sub>
    - `fn load_homework( &self, force: bool, ) -> Future<Result<HomeworkOutcome, AppError>>;`  <sub>:12</sub>
    - `fn load_homework_detail( &self, id: &str, force: bool, ) -> Future<Result<HomeworkDetailOutcome, AppError>>;`  <sub>:16</sub>
- `pub type HomeworkDetailOutcome = DataOutcome<crate::features::homework::HomeworkDetail>;`  
  <sub>type · rust/crates/ginkgo_domain/src/ports/homework.rs:23</sub>

## homework_submission

- `pub const HOMEWORK_FILE_LIMIT: usize = 20 * 1024 * 1024;`  
  <sub>const · rust/crates/ginkgo_domain/src/ports/homework_submission.rs:4</sub>
- `pub struct HomeworkAttachment`  
  <sub>struct · rust/crates/ginkgo_domain/src/ports/homework_submission.rs:7</sub>
    - `id: String`  <sub>:8</sub>
    - `name: String`  <sub>:9</sub>
    - `kind: String`  <sub>:10</sub>
- `pub struct HomeworkWorkspace`  
  <sub>struct · rust/crates/ginkgo_domain/src/ports/homework_submission.rs:14</sub>
    - `assignment_id: String`  <sub>:15</sub>
    - `allowed_methods: Vec<String>`  <sub>:16</sub>
    - `allowed_extensions: Vec<String>`  <sub>:17</sub>
    - `submission_limit: Option<u32>`  <sub>:18</sub>
    - `submitted_count: Option<u32>`  <sub>:19</sub>
    - `returned: bool`  <sub>:20</sub>
    - `submitted_text: Option<String>`  <sub>:21</sub>
    - `feedback: Option<String>`  <sub>:22</sub>
    - `attachments: Vec<HomeworkAttachment>`  <sub>:23</sub>
    - `can_submit_file: bool`  <sub>:24</sub>
    - `blocked_reason: Option<String>`  <sub>:25</sub>
    - `file_limit_bytes: u64`  <sub>:26</sub>
- `pub struct HomeworkUploadReceipt`  
  <sub>struct · rust/crates/ginkgo_domain/src/ports/homework_submission.rs:30</sub>
    - `handle: String`  <sub>:31</sub>
    - `file_name: String`  <sub>:32</sub>
    - `size: u64`  <sub>:33</sub>
- `pub struct HomeworkDownload`  
  <sub>struct · rust/crates/ginkgo_domain/src/ports/homework_submission.rs:35</sub>
    - `name: String`  <sub>:36</sub>
    - `bytes: Vec<u8>`  <sub>:37</sub>
- `pub fn validate_homework_file(name: &str, size: usize) -> Result<(), AppError> {…}`  
  <sub>fn · rust/crates/ginkgo_domain/src/ports/homework_submission.rs:39</sub>
- `pub enum HomeworkCapabilityState` — Evidence about one homework capability, not a claim of a real submitted write.  
  <sub>enum · rust/crates/ginkgo_domain/src/ports/homework_submission.rs:55</sub>
- `pub struct HomeworkCapabilityEvidence`  
  <sub>struct · rust/crates/ginkgo_domain/src/ports/homework_submission.rs:65</sub>
    - `capability: String`  <sub>:66</sub>
    - `state: HomeworkCapabilityState`  <sub>:67</sub>
    - `reason: String`  <sub>:68</sub>
    - `evidence: String`  <sub>:69</sub>
- `pub struct HomeworkPendingSubmission`  
  <sub>struct · rust/crates/ginkgo_domain/src/ports/homework_submission.rs:73</sub>
    - `handle: String`  <sub>:74</sub>
    - `assignment_id: String`  <sub>:75</sub>
    - `file_name: String`  <sub>:76</sub>
    - `size: u64`  <sub>:77</sub>
- `pub trait HomeworkSubmissionSource: Send + Sync`  
  <sub>trait · rust/crates/ginkgo_domain/src/ports/homework_submission.rs:79</sub>
    - `fn configure_homework_recovery(&self, _root: &str) -> Result<(), AppError> {…}` — Trusted application-private directory only; never a caller-selected document path.  <sub>:81</sub>
    - `fn pending_homework_submissions( &self, ) -> Future<Result<Vec<HomeworkPendingSubmission>, AppError>>`  <sub>:84</sub>
    - `fn homework_capabilities( &self, _id: &str, ) -> Future<Vec<HomeworkCapabilityEvidence>> {…}`  <sub>:90</sub>
    - `fn homework_workspace( &self, id: &str, ) -> Future<Result<HomeworkWorkspace, AppError>>;`  <sub>:103</sub>
    - `fn upload_homework_file( &self, id: &str, name: &str, bytes: Vec<u8>, ) -> Future<Result<HomeworkUploadReceipt, AppError>>;`  <sub>:107</sub>
    - `fn submit_homework_file( &self, handle: &str, confirmed: bool, ) -> Future<MutationOutcome>;`  <sub>:113</sub>
    - `fn download_homework_file( &self, id: &str, attachment_id: &str, ) -> Future<Result<HomeworkDownload, AppError>>;`  <sub>:118</sub>
    - `fn reconcile_homework_file( &self, handle: &str, ) -> Future<MutationOutcome>;`  <sub>:123</sub>

## learning

- `pub struct LearningCourse`  
  <sub>struct · rust/crates/ginkgo_domain/src/ports/learning.rs:7</sub>
    - `id: String`  <sub>:8</sub>
    - `name: String`  <sub>:9</sub>
    - `teacher: Option<String>`  <sub>:10</sub>
    - `term: Option<String>`  <sub>:11</sub>
    - `source_url: String`  <sub>:12</sub>
- `pub struct CourseAnnouncement`  
  <sub>struct · rust/crates/ginkgo_domain/src/ports/learning.rs:16</sub>
    - `id: String`  <sub>:17</sub>
    - `title: String`  <sub>:18</sub>
    - `published_at: Option<String>`  <sub>:19</sub>
- `pub struct LearningAttachment`  
  <sub>struct · rust/crates/ginkgo_domain/src/ports/learning.rs:23</sub>
    - `id: String`  <sub>:24</sub>
    - `name: String`  <sub>:25</sub>
- `pub struct CourseAnnouncementDetail`  
  <sub>struct · rust/crates/ginkgo_domain/src/ports/learning.rs:29</sub>
    - `id: String`  <sub>:30</sub>
    - `title: String`  <sub>:31</sub>
    - `content: Option<String>`  <sub>:32</sub>
    - `attachments: Vec<LearningAttachment>`  <sub>:33</sub>
- `pub struct CourseResource`  
  <sub>struct · rust/crates/ginkgo_domain/src/ports/learning.rs:37</sub>
    - `id: String`  <sub>:38</sub>
    - `name: String`  <sub>:39</sub>
    - `folder: bool`  <sub>:40</sub>
    - `downloadable: bool`  <sub>:41</sub>
    - `updated_at: Option<String>`  <sub>:42</sub>
    - `extension: Option<String>`  <sub>:43</sub>
- `pub struct CourseResourcePage`  
  <sub>struct · rust/crates/ginkgo_domain/src/ports/learning.rs:47</sub>
    - `items: Vec<CourseResource>`  <sub>:48</sub>
    - `page: u32`  <sub>:49</sub>
    - `has_next: bool`  <sub>:50</sub>
- `pub struct CourseAssessment`  
  <sub>struct · rust/crates/ginkgo_domain/src/ports/learning.rs:54</sub>
    - `id: String`  <sub>:55</sub>
    - `title: String`  <sub>:56</sub>
    - `starts_at: Option<String>`  <sub>:57</sub>
    - `due_at: Option<String>`  <sub>:58</sub>
    - `score: Option<String>`  <sub>:59</sub>
    - `source_url: String`  <sub>:60</sub>
- `pub struct LearningDownload`  
  <sub>struct · rust/crates/ginkgo_domain/src/ports/learning.rs:62</sub>
    - `name: String`  <sub>:63</sub>
    - `bytes: Vec<u8>`  <sub>:64</sub>
- `pub trait LearningCourseSource: Send + Sync`  
  <sub>trait · rust/crates/ginkgo_domain/src/ports/learning.rs:66</sub>
    - `fn learning_courses( &self, force: bool, ) -> Future<Result<DataOutcome<Vec<LearningCourse>>, AppError>>;`  <sub>:67</sub>
- `pub trait CourseAnnouncementSource: Send + Sync`  
  <sub>trait · rust/crates/ginkgo_domain/src/ports/learning.rs:72</sub>
    - `fn course_announcements( &self, course: &str, force: bool, ) -> Future<Result<DataOutcome<Vec<CourseAnnouncement>>, AppError>>;`  <sub>:73</sub>
    - `fn course_announcement_detail( &self, course: &str, id: &str, ) -> Future<Result<CourseAnnouncementDetail, AppError>>;`  <sub>:78</sub>
    - `fn course_announcement_attachment( &self, course: &str, id: &str, file: &str, ) -> Future<Result<LearningDownload, AppError>>;`  <sub>:83</sub>
- `pub trait CourseResourceSource: Send + Sync`  
  <sub>trait · rust/crates/ginkgo_domain/src/ports/learning.rs:90</sub>
    - `fn course_resources(&self…)  -> Future<Result<DataOutcome<CourseResourcePage>, AppError>>;`  <sub>:91</sub>
    - `fn course_resource_download( &self, course: &str, folder: Option<&str>, page: u32, id: &str, ) -> Future<Result<LearningDownload, AppError>>;`  <sub>:98</sub>
- `pub trait CourseAssessmentSource: Send + Sync`  
  <sub>trait · rust/crates/ginkgo_domain/src/ports/learning.rs:106</sub>
    - `fn course_assessments( &self, course: &str, force: bool, ) -> Future<Result<DataOutcome<Vec<CourseAssessment>>, AppError>>;`  <sub>:107</sub>
- `pub enum LearningColumnKind` — Opaque course-owned context, never a school endpoint or editable type code.  
  <sub>enum · rust/crates/ginkgo_domain/src/ports/learning.rs:117</sub>
- `pub struct LearningColumn`  
  <sub>struct · rust/crates/ginkgo_domain/src/ports/learning.rs:123</sub>
    - `id: String`  <sub>:124</sub>
    - `name: String`  <sub>:125</sub>
    - `kind: LearningColumnKind`  <sub>:126</sub>
- `pub enum LearningCapabilityState`  
  <sub>enum · rust/crates/ginkgo_domain/src/ports/learning.rs:130</sub>
- `pub struct LearningCapabilities` — Last actual authorized read result in the current identity/cache epoch.  
  <sub>struct · rust/crates/ginkgo_domain/src/ports/learning.rs:143</sub>
    - `columns: LearningCapabilityState`  <sub>:144</sub>
    - `announcements: LearningCapabilityState`  <sub>:145</sub>
    - `resources: LearningCapabilityState`  <sub>:146</sub>
    - `assessments: LearningCapabilityState`  <sub>:147</sub>
    - `resource_download: LearningCapabilityState`  <sub>:148</sub>
    - `announcement_download: LearningCapabilityState`  <sub>:149</sub>
- `pub trait CourseLearningContextSource: Send + Sync` — Additional contextual queries; original independent source traits remain compatible.  
  <sub>trait · rust/crates/ginkgo_domain/src/ports/learning.rs:152</sub>
    - `fn course_learning_columns( &self, course: &str, force: bool, ) -> Future<Result<DataOutcome<Vec<LearningColumn>>, AppError>>;`  <sub>:153</sub>
    - `fn course_announcements_in( &self, course: &str, column: &str, force: bool, ) -> Future<Result<DataOutcome<Vec<CourseAnnouncement>>, AppError>>;`  <sub>:158</sub>
    - `fn course_announcement_detail_in( &self, course: &str, column: &str, id: &str, ) -> Future<Result<CourseAnnouncementDetail, AppError>>;`  <sub>:164</sub>
    - `fn course_announcement_attachment_in( &self, course: &str, column: &str, id: &str, file: &str, ) -> Future<Result<LearningDownload, AppError>>;`  <sub>:170</sub>
    - `fn course_assessments_in( &self, course: &str, column: &str, force: bool, ) -> Future<Result<DataOutcome<Vec<CourseAssessment>>, AppError>>;`  <sub>:177</sub>
    - `fn course_resources_at( &self, course: &str, path: &[String], page: u32, force: bool, ) -> Future<Result<DataOutcome<CourseResourcePage>, AppError>>;`  <sub>:183</sub>
    - `fn course_resource_download_at( &self, course: &str, path: &[String], page: u32, id: &str, ) -> Future<Result<LearningDownload, AppError>>;`  <sub>:190</sub>
    - `fn course_learning_capabilities( &self, course: &str, ) -> Future<Result<LearningCapabilities, AppError>>;`  <sub>:197</sub>

## library

- `pub struct LibraryVenuesOutcome`  
  <sub>struct · rust/crates/ginkgo_domain/src/ports/library.rs:10</sub>
    - `venues: Vec<LibraryVenue>`  <sub>:11</sub>
    - `fetched_at: String`  <sub>:12</sub>
    - `from_cache: bool`  <sub>:13</sub>
    - `stale: bool`  <sub>:14</sub>
    - `failure: Option<AppError>`  <sub>:15</sub>
- `pub struct LibraryBookingsOutcome`  
  <sub>struct · rust/crates/ginkgo_domain/src/ports/library.rs:19</sub>
    - `bookings: Vec<LibraryBooking>`  <sub>:20</sub>
    - `fetched_at: String`  <sub>:21</sub>
    - `from_cache: bool`  <sub>:22</sub>
    - `stale: bool`  <sub>:23</sub>
    - `failure: Option<AppError>`  <sub>:24</sub>
- `pub struct LibraryHistoryOutcome`  
  <sub>struct · rust/crates/ginkgo_domain/src/ports/library.rs:28</sub>
    - `data: crate::features::library::LibraryHistoryPage`  <sub>:29</sub>
    - `fetched_at: String`  <sub>:30</sub>
    - `from_cache: bool`  <sub>:31</sub>
    - `stale: bool`  <sub>:32</sub>
    - `failure: Option<AppError>`  <sub>:33</sub>
- `pub trait LibrarySource: Send + Sync`  
  <sub>trait · rust/crates/ginkgo_domain/src/ports/library.rs:36</sub>
    - `fn load_library_history( &self, page: i32, force_refresh: bool, ) -> Future<Result<LibraryHistoryOutcome, AppError>>;`  <sub>:37</sub>
    - `fn load_library_venues( &self, force_refresh: bool, ) -> Future<Result<LibraryVenuesOutcome, AppError>>;`  <sub>:42</sub>
    - `fn load_library_areas( &self, library_id: &str, ) -> Future<Result<Vec<LibraryArea>, AppError>>;`  <sub>:46</sub>
    - `fn load_library_slots( &self, area_id: &str, ) -> Future<Result<Vec<LibrarySlot>, AppError>>;`  <sub>:50</sub>
    - `fn load_library_seats( &self, area_id: &str, slot_id: &str, day: &str, start: &str, end: &str, ) -> Future<Result<Vec<LibrarySeat>, AppError>>;`  <sub>:54</sub>
    - `fn load_library_bookings( &self, force_refresh: bool, ) -> Future<Result<LibraryBookingsOutcome, AppError>>;`  <sub>:62</sub>
- `pub trait LibraryMutationSource: Send + Sync`  
  <sub>trait · rust/crates/ginkgo_domain/src/ports/library.rs:68</sub>
    - `fn reserve_library_seat( &self, area_id: &str, seat_id: &str, slot: LibrarySlot, ) -> Future<MutationOutcome>;`  <sub>:69</sub>
    - `fn perform_library_action( &self, booking_id: &str, action: &str, ) -> Future<MutationOutcome>;`  <sub>:75</sub>

## library_books

- `pub trait LibraryCatalogSource: Send + Sync`  
  <sub>trait · rust/crates/ginkgo_domain/src/ports/library_books.rs:8</sub>
    - `fn search_books( &self, query: String, page: i64, sort: String, descending: bool, ) -> Future<Result<BookPage, AppError>>;` — `sort` is one of [`SORT_FIELDS`]; `descending` maps to `sortType`.  <sub>:10</sub>
    - `fn book_holdings( &self, bib_id: String, ) -> Future<Result<Vec<BookHolding>, AppError>>;`  <sub>:18</sub>
- `pub const QUERY_MAX_CHARS: usize = 80;` — Caller-supplied search bounds. The service clamps instead of trusting the  
  <sub>const · rust/crates/ginkgo_domain/src/ports/library_books.rs:26</sub>
- `pub const PAGE_MIN: i64 = 1;`  
  <sub>const · rust/crates/ginkgo_domain/src/ports/library_books.rs:27</sub>
- `pub const PAGE_MAX: i64 = 100;`  
  <sub>const · rust/crates/ginkgo_domain/src/ports/library_books.rs:28</sub>
- `pub const PAGE_SIZE: i64 = 20;`  
  <sub>const · rust/crates/ginkgo_domain/src/ports/library_books.rs:29</sub>
- `pub const SORT_FIELDS: [&str; 3] = ["relevance", "pub_year", "title"];` — Sort fields confirmed against the live endpoint (2026-10-23): each one  
  <sub>const · rust/crates/ginkgo_domain/src/ports/library_books.rs:33</sub>
- `pub const DEFAULT_SORT: &str = "relevance";`  
  <sub>const · rust/crates/ginkgo_domain/src/ports/library_books.rs:34</sub>

## library_loans

- `pub trait LibraryLoansSource: Send + Sync`  
  <sub>trait · rust/crates/ginkgo_domain/src/ports/library_loans.rs:3</sub>
    - `fn library_loans( &self, page: u32, ) -> Future<Result<LibraryLoanPage, AppError>>;`  <sub>:4</sub>

## library_stats

- `pub struct LibraryStatsOutcome`  
  <sub>struct · rust/crates/ginkgo_domain/src/ports/library_stats.rs:4</sub>
    - `campuses: Vec<CampusStats>`  <sub>:5</sub>
    - `fetched_at: String`  <sub>:6</sub>
    - `from_cache: bool`  <sub>:7</sub>
    - `failure: Option<AppError>`  <sub>:8</sub>
- `pub trait LibraryStatsSource: Send + Sync`  
  <sub>trait · rust/crates/ginkgo_domain/src/ports/library_stats.rs:11</sub>
    - `fn load_library_stats( &self, force: bool, ) -> Future<Result<LibraryStatsOutcome, AppError>>;`  <sub>:12</sub>

## notices

- `pub trait NoticeSource: Send + Sync`  
  <sub>trait · rust/crates/ginkgo_domain/src/ports/notices.rs:4</sub>
    - `fn load_notices( &self, force: bool, ) -> Future<Result<NoticesOutcome, AppError>>;`  <sub>:5</sub>
- `pub type NoticesOutcome = DataOutcome<Vec<crate::features::notices::Notice>>;`  
  <sub>type · rust/crates/ginkgo_domain/src/ports/notices.rs:11</sub>

## outcome

- `pub struct DataOutcome<T>`  
  <sub>struct · rust/crates/ginkgo_domain/src/ports/outcome.rs:4</sub>
    - `data: T`  <sub>:5</sub>
    - `failure: Option<AppError>`  <sub>:6</sub>

## query_snapshots

- `pub trait LearningSnapshotSource: Send + Sync` — Optional private learning-query archives, never credentials or downloaded files.  
  <sub>trait · rust/crates/ginkgo_domain/src/ports/query_snapshots.rs:3</sub>
    - `fn export_learning_snapshots(&self) -> Result<Vec<u8>, crate::AppError>;`  <sub>:4</sub>
    - `fn import_learning_snapshots(&self, bytes: &[u8]) -> Result<u32, crate::AppError>;` — Caller must already have authenticated the current account. Never logs in.  <sub>:6</sub>

## session

- `pub enum RoutePreference`  
  <sub>enum · rust/crates/ginkgo_domain/src/ports/session.rs:7</sub>
- `pub struct SessionStatus`  
  <sub>struct · rust/crates/ginkgo_domain/src/ports/session.rs:14</sub>
    - `account: Option<String>`  <sub>:15</sub>
    - `profile: Option<UserProfile>`  <sub>:16</sub>
    - `route: RoutePreference`  <sub>:17</sub>
- `pub enum SessionOutcome`  
  <sub>enum · rust/crates/ginkgo_domain/src/ports/session.rs:21</sub>
- `pub fn signed_in(&self) -> bool {…}`  
  <sub>fn · rust/crates/ginkgo_domain/src/ports/session.rs:31</sub>
- `pub struct LoginChallengeData` — Transient image bytes; never persisted or used as an identity proof.  
  <sub>struct · rust/crates/ginkgo_domain/src/ports/session.rs:38</sub>
    - `challenge_id: String`  <sub>:39</sub>
    - `challenge_type: String`  <sub>:40</sub>
    - `text_supported: bool`  <sub>:41</sub>
    - `image: Vec<u8>`  <sub>:42</sub>
- `pub trait SessionSource: Send + Sync`  
  <sub>trait · rust/crates/ginkgo_domain/src/ports/session.rs:45</sub>
    - `fn login_challenge( &self, _expected_id: Option<&str>, _refresh: bool, ) -> Future<Result<LoginChallengeData, AppError>> {…}`  <sub>:46</sub>
    - `fn status(&self) -> SessionStatus;`  <sub>:54</sub>
    - `fn set_route(&self, preference: RoutePreference);`  <sub>:55</sub>
    - `fn sign_in( &self, account: &str, password: &str, captcha: Option<&str>, remember: bool, ) -> Future<Result<SessionOutcome, AppError>>;`  <sub>:56</sub>
    - `fn restore(&self) -> Future<Result<SessionOutcome, AppError>>;`  <sub>:63</sub>
    - `fn sign_out(&self) -> Future<()>;`  <sub>:65</sub>
    - `fn clear_snapshots(&self);`  <sub>:66</sub>
    - `fn account(&self) -> Result<String, AppError>;`  <sub>:67</sub>

## shuttle

- `pub trait ShuttleSource: Send + Sync`  
  <sub>trait · rust/crates/ginkgo_domain/src/ports/shuttle.rs:5</sub>
    - `fn load_shuttle_timetable( &self, ) -> Future<Result<ShuttleTimetable, AppError>>;`  <sub>:6</sub>
