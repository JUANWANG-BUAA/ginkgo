# Dart 应用接口（flutter/lib/application）

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
页面依赖的 gateway、契约与局部应用状态。

## 目录

- [application/auth_challenge.dart](#applicationauthchallengedart) (2)
- [application/campus_activities.dart](#applicationcampusactivitiesdart) (4)
- [application/career.dart](#applicationcareerdart) (3)
- [application/collection_window.dart](#applicationcollectionwindowdart) (1)
- [application/diagnostic_log.dart](#applicationdiagnosticlogdart) (2)
- [application/graduate_credit_map.dart](#applicationgraduatecreditmapdart) (9)
- [application/homework_files.dart](#applicationhomeworkfilesdart) (7)
- [application/learning.dart](#applicationlearningdart) (5)
- [application/learning_context.dart](#applicationlearningcontextdart) (3)
- [application/learning_file_actions.dart](#applicationlearningfileactionsdart) (2)
- [application/learning_models.dart](#applicationlearningmodelsdart) (8)
- [application/library_loans.dart](#applicationlibraryloansdart) (5)
- [application/local_tasks.dart](#applicationlocaltasksdart) (1)
- [application/mirror_service.dart](#applicationmirrorservicedart) (12)
- [application/query_snapshots.dart](#applicationquerysnapshotsdart) (2)
- [application/refresh_section.dart](#applicationrefreshsectiondart) (2)
- [application/reminder_planning.dart](#applicationreminderplanningdart) (4)

## application/auth_challenge.dart

- `class LoginChallenge` — In-memory authentication UI values; never a URL or a persistence payload.
  <sub>class · application/auth_challenge.dart:4</sub>
- `abstract interface class AuthChallengeGateway`
  <sub>class · application/auth_challenge.dart:17</sub>
    - `Future<LoginChallenge> loginChallenge( {…}` — Read the current pending challenge, or explicitly replace its login page.  <sub>:20</sub>

## application/campus_activities.dart

- `class CampusActivity`
  <sub>class · application/campus_activities.dart:4</sub>
    - `const CampusActivity( {…}`  <sub>:5</sub>
- `class CampusActivities`
  <sub>class · application/campus_activities.dart:28</sub>
    - `const CampusActivities( {…}`  <sub>:29</sub>
- `class CampusActivitiesRead`
  <sub>class · application/campus_activities.dart:50</sub>
    - `const CampusActivitiesRead( {…}`  <sub>:51</sub>
- `abstract interface class CampusActivitiesGateway implements MirrorEnvironment` — Public campus activities; no login, no writes and no background polling.
  <sub>class · application/campus_activities.dart:57</sub>
    - `Future<CampusActivitiesRead> campusActivities( {…}`  <sub>:58</sub>

## application/career.dart

- `class CareerEvent` — Public career activities. School status text is preserved verbatim.
  <sub>class · application/career.dart:4</sub>
    - `const CareerEvent( {…}`  <sub>:5</sub>
- `class CareerEvents`
  <sub>class · application/career.dart:40</sub>
    - `const CareerEvents( {…}`  <sub>:41</sub>
- `class CareerEventsRead`
  <sub>class · application/career.dart:60</sub>
    - `const CareerEventsRead( {…}`  <sub>:61</sub>

## application/collection_window.dart

- `class CollectionWindow` — Bounded presentation of an already-loaded result, independent of transport.
  <sub>class · application/collection_window.dart:3</sub>
    - `int page = 0;`  <sub>:7</sub>
    - `int get count => _keys.length;`  <sub>:8</sub>
    - `int get pageCount => count == 0 ? 1 : (count / pageSize).ceil();`  <sub>:9</sub>
    - `int get start => page * pageSize;`  <sub>:10</sub>
    - `int get end => (start + pageSize).clamp(0, count);`  <sub>:11</sub>
    - `void reconcile(Iterable<String> keys, {…}`  <sub>:13</sub>
    - `void select(int value) => page = value.clamp(0, pageCount - 1);`  <sub>:24</sub>

## application/diagnostic_log.dart

- `class DiagnosticEntry` — Allowlisted diagnostics only: no exception text, URLs, account or payloads.
  <sub>class · application/diagnostic_log.dart:8</sub>
    - `const DiagnosticEntry(this.code, this.at);`  <sub>:9</sub>
    - `String get hint => switch (code) {…}`  <sub>:12</sub>
    - `String get summary => '$ {…}`  <sub>:22</sub>
- `class DiagnosticLog extends ChangeNotifier`
  <sub>class · application/diagnostic_log.dart:25</sub>
    - `static final shared = DiagnosticLog();`  <sub>:26</sub>
    - `final List<DiagnosticEntry> entries = [];`  <sub>:27</sub>
    - `void record(FailureCode? failure) {…}`  <sub>:29</sub>
    - `void dismiss() {…}`  <sub>:45</sub>

## application/graduate_credit_map.dart

- `abstract interface class GraduateCreditMapGateway`
  <sub>class · application/graduate_credit_map.dart:6</sub>
    - `Future<GraduateCreditMapRead> graduateCreditMap( {…}`  <sub>:7</sub>
- `class GraduateCreditMapRead`
  <sub>class · application/graduate_credit_map.dart:10</sub>
    - `const GraduateCreditMapRead( {…}`  <sub>:11</sub>
- `enum GraduateCreditIssueKind`
  <sub>enum · application/graduate_credit_map.dart:17</sub>
- `class GraduateCreditReadIssue` — Classification must be backed by the actual read result, never by missing
  <sub>class · application/graduate_credit_map.dart:29</sub>
    - `const GraduateCreditReadIssue(this.kind);`  <sub>:30</sub>
    - `static GraduateCreditReadIssue? fromFailure(FailureCode? code) => switch (code) {…}`  <sub>:33</sub>
    - `String get message => switch (kind) {…}`  <sub>:57</sub>
- `enum GraduateCreditState { unknown, noMinimum, incomplete, requirementMet }`
  <sub>enum · application/graduate_credit_map.dart:68</sub>
- `class GraduateCreditMetrics`
  <sub>class · application/graduate_credit_map.dart:70</sub>
    - `const GraduateCreditMetrics( {…}`  <sub>:71</sub>
    - `String get stateLabel => switch (state) {…}`  <sub>:82</sub>
- `class GraduateCreditRow`
  <sub>class · application/graduate_credit_map.dart:90</sub>
    - `const GraduateCreditRow( {…}`  <sub>:91</sub>
- `class GraduateCreditNode`
  <sub>class · application/graduate_credit_map.dart:106</sub>
- `class GraduateCreditMap`
  <sub>class · application/graduate_credit_map.dart:119</sub>
    - `bool get isEmpty => summary == null && nodes.isEmpty;`  <sub>:128</sub>

## application/homework_files.dart

- `abstract interface class HomeworkFilesGateway` — Business-only capability, independent from school endpoints and AcademicGateway.
  <sub>class · application/homework_files.dart:6</sub>
    - `Future<HomeworkFileWorkspace> homeworkFiles(String assignmentId);`  <sub>:7</sub>
    - `Future<List<HomeworkPendingSubmission>> pendingHomeworkSubmissions( {…}`  <sub>:8</sub>
    - `Future<List<HomeworkCapabilityEvidence>> homeworkCapabilities( String assignmentId, );`  <sub>:11</sub>
    - `Future<HomeworkFileReceipt> uploadHomeworkFile( String assignmentId, String name, Uint8List bytes, );`  <sub>:14</sub>
    - `Future<MutationResponse> submitHomeworkFile(String handle);`  <sub>:19</sub>
    - `Future<MutationResponse> reconcileHomeworkFile(String handle);`  <sub>:20</sub>
    - `Future<HomeworkFileDownload> downloadHomeworkFile( String assignmentId, String attachmentId, );`  <sub>:21</sub>
- `class HomeworkPendingSubmission` — Only opaque ownership-bound recovery metadata, never file bytes or names.
  <sub>class · application/homework_files.dart:28</sub>
    - `const HomeworkPendingSubmission( this.handle, this.assignmentId, {…}`  <sub>:29</sub>
- `class HomeworkCapabilityEvidence`
  <sub>class · application/homework_files.dart:47</sub>
    - `const HomeworkCapabilityEvidence( {…}`  <sub>:48</sub>
- `class HomeworkFileAttachment`
  <sub>class · application/homework_files.dart:64</sub>
    - `const HomeworkFileAttachment(this.id, this.name, this.kind);`  <sub>:65</sub>
- `class HomeworkFileWorkspace`
  <sub>class · application/homework_files.dart:69</sub>
    - `const HomeworkFileWorkspace( {…}`  <sub>:70</sub>
- `class HomeworkFileReceipt`
  <sub>class · application/homework_files.dart:120</sub>
    - `const HomeworkFileReceipt(this.handle, this.name, this.size);`  <sub>:121</sub>
- `class HomeworkFileDownload`
  <sub>class · application/homework_files.dart:126</sub>
    - `const HomeworkFileDownload(this.name, this.bytes);`  <sub>:127</sub>

## application/learning.dart

- `abstract interface class LearningCourseGateway` — Separate, read-only capabilities: implementing one never grants writes.
  <sub>class · application/learning.dart:4</sub>
    - `Future<LearningRead<List<LearningCourse>>> learningCourses( {…}`  <sub>:5</sub>
- `abstract interface class CourseAnnouncementGateway`
  <sub>class · application/learning.dart:10</sub>
    - `Future<LearningRead<List<CourseAnnouncement>>> courseAnnouncements( String course, {…}`  <sub>:11</sub>
    - `Future<CourseAnnouncementDetail> courseAnnouncementDetail( String course, String id, );`  <sub>:15</sub>
    - `Future<LearningDownload> courseAnnouncementAttachment( String course, String id, String file, );`  <sub>:19</sub>
- `abstract interface class CourseResourceGateway`
  <sub>class · application/learning.dart:26</sub>
    - `Future<LearningRead<CourseResourcePage>> courseResources( String course, {…}`  <sub>:27</sub>
    - `Future<LearningDownload> courseResourceDownload( String course, String id, {…}`  <sub>:33</sub>
- `abstract interface class CourseAssessmentGateway`
  <sub>class · application/learning.dart:41</sub>
    - `Future<LearningRead<List<CourseAssessment>>> courseAssessments( String course, {…}`  <sub>:42</sub>
- `class LearningRead<T>` — An old successful value and a refresh failure must travel together.
  <sub>class · application/learning.dart:49</sub>
    - `const LearningRead(this.data, {…}`  <sub>:50</sub>

## application/learning_context.dart

- `abstract interface class CourseLearningContextGateway` — Explicit, server-validated navigation contexts. No school URLs or tokens.
  <sub>class · application/learning_context.dart:5</sub>
    - `Future<LearningRead<List<LearningColumn>>> learningColumns( String course, {…}`  <sub>:6</sub>
    - `Future<LearningCapabilities> learningCapabilities(String course);`  <sub>:10</sub>
    - `Future<LearningRead<List<CourseAnnouncement>>> courseAnnouncementsIn( String course, String column, {…}`  <sub>:11</sub>
    - `Future<CourseAnnouncementDetail> courseAnnouncementDetailIn( String course, String column, String id, );`  <sub>:16</sub>
    - `Future<LearningDownload> courseAnnouncementAttachmentIn( String course, String column, String id, String file, );`  <sub>:21</sub>
    - `Future<LearningRead<List<CourseAssessment>>> courseAssessmentsIn( String course, String column, {…}`  <sub>:27</sub>
    - `Future<LearningRead<CourseResourcePage>> courseResourcesAt( String course, {…}`  <sub>:32</sub>
    - `Future<LearningDownload> courseResourceDownloadAt( String course, String id, {…}`  <sub>:38</sub>
- `class LearningColumn`
  <sub>class · application/learning_context.dart:46</sub>
    - `const LearningColumn( {…}`  <sub>:47</sub>
- `class LearningCapabilities` — Observations of this session, never an instruction to probe an endpoint.
  <sub>class · application/learning_context.dart:56</sub>
    - `const LearningCapabilities( {…}`  <sub>:57</sub>

## application/learning_file_actions.dart

- `typedef LearningFileSaver = Future<LearningSavedFile?> Function(` — User-initiated local save; implementors must recheck current after selection
  <sub>typedef · application/learning_file_actions.dart:5</sub>
- `class LearningSavedFile`
  <sub>class · application/learning_file_actions.dart:10</sub>
    - `const LearningSavedFile( {…}`  <sub>:11</sub>
    - `final Future<void> Function() open;`  <sub>:12</sub>

## application/learning_models.dart

- `class LearningCourse` — Business values only. School fields and authentication stay in Rust.
  <sub>class · application/learning_models.dart:4</sub>
    - `const LearningCourse( {…}`  <sub>:5</sub>
- `class CourseAnnouncement`
  <sub>class · application/learning_models.dart:16</sub>
    - `const CourseAnnouncement(this.id, this.title, this.publishedAt);`  <sub>:17</sub>
- `class LearningAttachment`
  <sub>class · application/learning_models.dart:22</sub>
    - `const LearningAttachment(this.id, this.name);`  <sub>:23</sub>
- `class CourseAnnouncementDetail`
  <sub>class · application/learning_models.dart:27</sub>
- `class CourseResource`
  <sub>class · application/learning_models.dart:39</sub>
    - `const CourseResource( {…}`  <sub>:40</sub>
- `class CourseResourcePage`
  <sub>class · application/learning_models.dart:53</sub>
- `class CourseAssessment`
  <sub>class · application/learning_models.dart:61</sub>
    - `const CourseAssessment( {…}`  <sub>:62</sub>
- `class LearningDownload`
  <sub>class · application/learning_models.dart:74</sub>

## application/library_loans.dart

- `class LibraryLoan` — Private on-demand reads. Implementations must not persist reader records.
  <sub>class · application/library_loans.dart:4</sub>
    - `const LibraryLoan( {…}`  <sub>:5</sub>
- `class LibraryLoanPage`
  <sub>class · application/library_loans.dart:17</sub>
    - `const LibraryLoanPage( {…}`  <sub>:18</sub>
- `class LibraryLoansRead`
  <sub>class · application/library_loans.dart:29</sub>
    - `const LibraryLoansRead( {…}`  <sub>:30</sub>
- `abstract interface class LibraryLoansOfficialGateway`
  <sub>class · application/library_loans.dart:35</sub>
    - `String libraryLoansPortalUrl();`  <sub>:36</sub>
- `abstract interface class LibraryLoansGateway`
  <sub>class · application/library_loans.dart:39</sub>
    - `Future<LibraryLoansRead> libraryLoans( {…}`  <sub>:40</sub>

## application/local_tasks.dart

- `class LocalTaskRecord` — Device-local personal task. Completion never changes a school assignment.
  <sub>class · application/local_tasks.dart:9</sub>
    - `const LocalTaskRecord( {…}`  <sub>:10</sub>

## application/mirror_service.dart

- `abstract interface class MirrorService` — Page-facing capabilities. Tests and alternative adapters need no native runtime.
  <sub>class · application/mirror_service.dart:5</sub>
- `abstract interface class CampusCardGateway implements MirrorEnvironment`
  <sub>class · application/mirror_service.dart:13</sub>
    - `Future<CampusCardBalanceResponse> campusCardBalance();`  <sub>:14</sub>
- `abstract interface class StudentServiceLinksGateway` — Public official destinations only; does not read or transmit account data.
  <sub>class · application/mirror_service.dart:18</sub>
    - `String? studentServiceUrl(String id);`  <sub>:19</sub>
- `abstract interface class CareerEventsGateway implements MirrorEnvironment` — Public career-calendar reads; no login and no background refresh.
  <sub>class · application/mirror_service.dart:23</sub>
    - `Future<CareerEventsRead> careerEvents( {…}`  <sub>:24</sub>
- `abstract interface class MirrorEnvironment`
  <sub>class · application/mirror_service.dart:30</sub>
- `abstract interface class SessionGateway implements MirrorEnvironment`
  <sub>class · application/mirror_service.dart:34</sub>
    - `Future<SessionResponse> restoreSession();`  <sub>:35</sub>
    - `Future<SessionResponse> login( {…}`  <sub>:37</sub>
    - `Future<SessionResponse> signOut();`  <sub>:44</sub>
    - `Future<SessionResponse> setRoute(RouteChoice route);`  <sub>:46</sub>
    - `Future<bool> clearCache();`  <sub>:48</sub>
    - `Future<bool> verifyBridgeContract();`  <sub>:50</sub>
- `abstract interface class AcademicGateway implements MirrorEnvironment`
  <sub>class · application/mirror_service.dart:53</sub>
    - `Future<QueryDates> dates(String instant);`  <sub>:54</sub>
    - `Future<ClassroomResponse> classrooms(DemoScope scope, ClassroomQuery query);`  <sub>:56</sub>
    - `Future<RuleExamples> rules();`  <sub>:58</sub>
    - `Future<ScheduleResponse> schedule( {…}`  <sub>:60</sub>
    - `Future<GradeTermsResponse> gradeTerms();`  <sub>:66</sub>
    - `Future<GradeResponse> grades( {…}`  <sub>:68</sub>
    - `Future<TodayResponse> today( {…}`  <sub>:70</sub>
    - `Future<HomeworkResponse> homework( {…}`  <sub>:72</sub>
    - `Future<HomeworkDetailResponse> homeworkDetail( String assignmentId, {…}`  <sub>:74</sub>
- `abstract interface class CheckInGateway implements MirrorEnvironment`
  <sub>class · application/mirror_service.dart:80</sub>
    - `Future<CheckInResponse> checkin( {…}`  <sub>:81</sub>
    - `Future<CheckInResponse> checkinOnDate( String date, {…}`  <sub>:83</sub>
    - `Future<MutationResponse> submitCheckin(String courseId);`  <sub>:88</sub>
    - `Future<ReadOnlyResponse> checkinProgress();`  <sub>:90</sub>
- `abstract interface class LibraryGateway implements MirrorEnvironment`
  <sub>class · application/mirror_service.dart:93</sub>
    - `Future<ReadOnlyResponse> libraryStats( {…}`  <sub>:94</sub>
    - `Future<MutationResponse> reserveLibrarySeat( {…}`  <sub>:96</sub>
    - `Future<MutationResponse> performLibraryAction( String bookingId, String action, );`  <sub>:102</sub>
    - `Future<LibraryVenuesResponse> libraryVenues( {…}`  <sub>:107</sub>
    - `Future<LibraryAreasResponse> libraryAreas(String libraryId);`  <sub>:109</sub>
    - `Future<LibrarySlotsResponse> librarySlots(String areaId);`  <sub>:111</sub>
    - `Future<LibrarySeatsResponse> librarySeats( {…}`  <sub>:113</sub>
    - `Future<LibraryBookingsResponse> libraryBookings( {…}`  <sub>:118</sub>
    - `Future<LibraryHistoryResponse> libraryHistory( int page, {…}`  <sub>:120</sub>
    - `Future<ReadOnlyResponse> libraryBooks( {…}` — Public OPAC search. Anonymous and read-only; never personal records.  <sub>:127</sub>
    - `Future<ReadOnlyResponse> libraryHoldings(String bibId);` — Public holdings for one bib id; the school's nested JSON stays in Rust.  <sub>:135</sub>
    - `Future<ReadOnlyResponse> shuttleTimetable();` — Published shuttle timetable (official page). No live seats, no ticketing.  <sub>:138</sub>
- `abstract interface class CampusGateway`
  <sub>class · application/mirror_service.dart:141</sub>
    - `Future<ReadOnlyResponse> bykcPart(BykcPart part, {…}`  <sub>:142</sub>
    - `Future<ReadOnlyResponse> graduatePart( {…}`  <sub>:144</sub>
    - `Future<ReadOnlyResponse> notices( {…}`  <sub>:149</sub>
    - `Future<ReadOnlyResponse> cgyy( {…}`  <sub>:151</sub>
    - `Future<ReadOnlyResponse> editTasks( {…}`  <sub>:158</sub>
- `abstract interface class CgyyBookingGateway` — Separate capability: read-only adapters never gain writes implicitly.
  <sub>class · application/mirror_service.dart:169</sub>
    - `Future<ReadOnlyResponse> executeCgyy(Map<String, Object?> command);`  <sub>:170</sub>
- `enum BykcPart { catalog, chosen, statistics }`
  <sub>enum · application/mirror_service.dart:173</sub>

## application/query_snapshots.dart

- `class LearningSnapshotStatus`
  <sub>class · application/query_snapshots.dart:1</sub>
    - `const LearningSnapshotStatus( {…}`  <sub>:2</sub>
- `abstract interface class LearningSnapshotGateway`
  <sub>class · application/query_snapshots.dart:11</sub>
    - `Future<LearningSnapshotStatus> learningSnapshotStatus();`  <sub>:12</sub>
    - `Future<LearningSnapshotStatus> setLearningSnapshotsEnabled(bool enabled);` — User must explicitly confirm saving private learning metadata first.  <sub>:15</sub>

## application/refresh_section.dart

- `class SectionResult<T>` — A presentation result, including a usable stale value when refresh failed.
  <sub>class · application/refresh_section.dart:5</sub>
    - `const SectionResult( {…}`  <sub>:6</sub>
- `class RefreshSection<T> extends ChangeNotifier` — Independent section refreshes preserve content and join overlapping reads.
  <sub>class · application/refresh_section.dart:13</sub>
    - `bool loading = false;`  <sub>:16</sub>
    - `void invalidate() => _generation++;` — Drops every in-flight read at its next await: call when the account or  <sub>:25</sub>
    - `Future<void> refresh( Future<SectionResult<T>> Function() read, {…}` — A plain refresh joins the in-flight read. A forced refresh is never  <sub>:30</sub>
    - `void dispose() {…}`  <sub>:92</sub>

## application/reminder_planning.dart

- `abstract interface class ReminderPlanningGateway` — Typed, local-only business capability. No school payload or platform API.
  <sub>class · application/reminder_planning.dart:6</sub>
    - `Future<ExtendedReminderPlans> planReminders( {…}`  <sub>:7</sub>
- `class CourseReminderSeed`
  <sub>class · application/reminder_planning.dart:14</sub>
    - `const CourseReminderSeed( {…}`  <sub>:15</sub>
- `class TaskReminderSeed`
  <sub>class · application/reminder_planning.dart:26</sub>
    - `const TaskReminderSeed( {…}`  <sub>:27</sub>
- `class ExtendedReminderPlans`
  <sub>class · application/reminder_planning.dart:36</sub>
