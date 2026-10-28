# Dart 应用接口（flutter/lib/application）

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
页面依赖的 gateway、契约与局部应用状态。

## 目录

- [application/auth_challenge.dart](#applicationauthchallengedart) (2)
- [application/busy_gate.dart](#applicationbusygatedart) (1)
- [application/campus_activities.dart](#applicationcampusactivitiesdart) (4)
- [application/career.dart](#applicationcareerdart) (3)
- [application/collection_window.dart](#applicationcollectionwindowdart) (1)
- [application/diagnostic_log.dart](#applicationdiagnosticlogdart) (2)
- [application/failure_message.dart](#applicationfailuremessagedart) (1)
- [application/graduate_credit_map.dart](#applicationgraduatecreditmapdart) (9)
- [application/homework_files.dart](#applicationhomeworkfilesdart) (7)
- [application/learning.dart](#applicationlearningdart) (5)
- [application/learning_context.dart](#applicationlearningcontextdart) (3)
- [application/learning_file_actions.dart](#applicationlearningfileactionsdart) (2)
- [application/learning_models.dart](#applicationlearningmodelsdart) (8)
- [application/learning_ports.dart](#applicationlearningportsdart) (1)
- [application/library_loans.dart](#applicationlibraryloansdart) (5)
- [application/local_tasks.dart](#applicationlocaltasksdart) (6)
- [application/mirror_service.dart](#applicationmirrorservicedart) (20)
- [application/query_snapshots.dart](#applicationquerysnapshotsdart) (2)
- [application/refresh_section.dart](#applicationrefreshsectiondart) (2)
- [application/reminder_planning.dart](#applicationreminderplanningdart) (6)
- [application/reminder_platform.dart](#applicationreminderplatformdart) (1)
- [application/reminder_store.dart](#applicationreminderstoredart) (1)
- [application/service_capabilities.dart](#applicationservicecapabilitiesdart) (1)
- [application/task_storage_scope.dart](#applicationtaskstoragescopedart) (2)

## application/auth_challenge.dart

- `class LoginChallenge` — In-memory authentication UI values; never a URL or a persistence payload.
  <sub>class · application/auth_challenge.dart:4</sub>
- `abstract interface class AuthChallengeGateway`
  <sub>class · application/auth_challenge.dart:17</sub>
    - `Future<LoginChallenge> loginChallenge({ String? expectedId, bool refresh = false, });` — Read the current pending challenge, or explicitly replace its login page.  <sub>:20</sub>

## application/busy_gate.dart

- `class BusyGate` — A busy flag that recovers on its own.
  <sub>class · application/busy_gate.dart:15</sub>
    - `bool get busy => …`  <sub>:24</sub>
    - `bool enter() {…}` — Close the gate. Returns false when it was already closed.  <sub>:27</sub>
    - `void leave() {…}` — Reopen the gate. Safe to call when already open.  <sub>:41</sub>
    - `void Function()? onExpired;` — Called when the deadline passed while the work was still in flight.  <sub>:51</sub>
    - `void dispose() {…}`  <sub>:53</sub>

## application/campus_activities.dart

- `class CampusActivity`
  <sub>class · application/campus_activities.dart:4</sub>
    - `const CampusActivity({ required this.id, required this.title, required this.category, required this.publishedAt, required this.activityTime, required this.place, required this.url, });`  <sub>:5</sub>
- `class CampusActivities`
  <sub>class · application/campus_activities.dart:28</sub>
    - `const CampusActivities({ required this.page, required this.activities, required this.fetchedAt, });`  <sub>:29</sub>
- `class CampusActivitiesRead`
  <sub>class · application/campus_activities.dart:53</sub>
    - `const CampusActivitiesRead({this.data, this.failure});`  <sub>:54</sub>
- `abstract interface class CampusActivitiesGateway implements MirrorEnvironment` — Public campus activities; no login, no writes and no background polling.
  <sub>class · application/campus_activities.dart:60</sub>
    - `Future<CampusActivitiesRead> campusActivities({int page, bool forceRefresh});`  <sub>:61</sub>

## application/career.dart

- `class CareerEvent` — Public career activities. School status text is preserved verbatim.
  <sub>class · application/career.dart:4</sub>
    - `const CareerEvent({ required this.id, required this.title, required this.campus, required this.place, required this.beginsAt, required this.endsAt, required this.fairType, required this.status, required this.url, });`  <sub>:5</sub>
- `class CareerEvents`
  <sub>class · application/career.dart:28</sub>
    - `const CareerEvents({ required this.month, required this.events, required this.fetchedAt, });`  <sub>:29</sub>
- `class CareerEventsRead`
  <sub>class · application/career.dart:39</sub>
    - `const CareerEventsRead({this.data, this.failure});`  <sub>:40</sub>

## application/collection_window.dart

- `class CollectionWindow` — Bounded presentation of an already-loaded result, independent of transport.
  <sub>class · application/collection_window.dart:3</sub>
    - `int page = 0;`  <sub>:7</sub>
    - `int get count => …`  <sub>:8</sub>
    - `int get pageCount => …`  <sub>:9</sub>
    - `int get start => …`  <sub>:10</sub>
    - `int get end => …`  <sub>:11</sub>
    - `void reconcile(Iterable<String> keys, {bool reset = false}) {…}`  <sub>:13</sub>
    - `void select(int value) => …`  <sub>:24</sub>

## application/diagnostic_log.dart

- `class DiagnosticEntry` — Allowlisted diagnostics only: no exception text, URLs, account or payloads.
  <sub>class · application/diagnostic_log.dart:8</sub>
    - `const DiagnosticEntry(this.code, this.at);`  <sub>:9</sub>
    - `String get hint => …`  <sub>:12</sub>
    - `String get summary => …`  <sub>:22</sub>
- `class DiagnosticLog extends ChangeNotifier`
  <sub>class · application/diagnostic_log.dart:25</sub>
    - `static final shared = DiagnosticLog();`  <sub>:26</sub>
    - `final List<DiagnosticEntry> entries = [];`  <sub>:27</sub>
    - `void record(FailureCode? failure) {…}`  <sub>:29</sub>
    - `void dismiss() {…}`  <sub>:45</sub>

## application/failure_message.dart

- `String failureMessage(FailureCode? code) {…}` — Maps typed Rust domain failure codes to human-readable Chinese error messages.
  <sub>function · application/failure_message.dart:5</sub>

## application/graduate_credit_map.dart

- `abstract interface class GraduateCreditMapGateway`
  <sub>class · application/graduate_credit_map.dart:6</sub>
    - `Future<GraduateCreditMapRead> graduateCreditMap({bool forceRefresh = false});`  <sub>:7</sub>
- `class GraduateCreditMapRead`
  <sub>class · application/graduate_credit_map.dart:10</sub>
    - `const GraduateCreditMapRead({this.data, this.issue, this.stale = false});`  <sub>:11</sub>
- `enum GraduateCreditIssueKind`
  <sub>enum · application/graduate_credit_map.dart:17</sub>
- `class GraduateCreditReadIssue` — Classification must be backed by the actual read result, never by missing
  <sub>class · application/graduate_credit_map.dart:29</sub>
    - `const GraduateCreditReadIssue(this.kind);`  <sub>:30</sub>
    - `static GraduateCreditReadIssue? fromFailure(FailureCode? code) => …`  <sub>:33</sub>
    - `String get message => …`  <sub>:57</sub>
- `enum GraduateCreditState { unknown, noMinimum, incomplete, requirementMet }`
  <sub>enum · application/graduate_credit_map.dart:68</sub>
- `class GraduateCreditMetrics`
  <sub>class · application/graduate_credit_map.dart:70</sub>
    - `const GraduateCreditMetrics({ required this.state, this.requiredCredits, this.earned, this.pending, this.remaining, this.ratio, });`  <sub>:71</sub>
    - `String get stateLabel => …`  <sub>:82</sub>
- `class GraduateCreditRow`
  <sub>class · application/graduate_credit_map.dart:90</sub>
    - `const GraduateCreditRow({ required this.title, required this.detail, required this.isCourse, this.completed, this.credit, this.semester, });`  <sub>:91</sub>
- `class GraduateCreditNode`
  <sub>class · application/graduate_credit_map.dart:106</sub>
- `class GraduateCreditMap`
  <sub>class · application/graduate_credit_map.dart:119</sub>
    - `bool get isEmpty => …`  <sub>:128</sub>

## application/homework_files.dart

- `abstract interface class HomeworkFilesGateway` — Business-only capability, independent from school endpoints and AcademicGateway.
  <sub>class · application/homework_files.dart:6</sub>
    - `Future<HomeworkFileWorkspace> homeworkFiles(String assignmentId);`  <sub>:7</sub>
    - `Future<List<HomeworkPendingSubmission>> pendingHomeworkSubmissions({ String? assignmentId, });`  <sub>:8</sub>
    - `Future<List<HomeworkCapabilityEvidence>> homeworkCapabilities( String assignmentId, );`  <sub>:11</sub>
    - `Future<HomeworkFileReceipt> uploadHomeworkFile( String assignmentId, String name, Uint8List bytes, );`  <sub>:14</sub>
    - `Future<MutationResponse> submitHomeworkFile(String handle);`  <sub>:19</sub>
    - `Future<MutationResponse> reconcileHomeworkFile(String handle);`  <sub>:20</sub>
    - `Future<HomeworkFileDownload> downloadHomeworkFile( String assignmentId, String attachmentId, );`  <sub>:21</sub>
- `class HomeworkPendingSubmission` — Only opaque ownership-bound recovery metadata, never file bytes or names.
  <sub>class · application/homework_files.dart:28</sub>
    - `const HomeworkPendingSubmission( this.handle, this.assignmentId, { this.fileName, this.size, });`  <sub>:29</sub>
- `class HomeworkCapabilityEvidence`
  <sub>class · application/homework_files.dart:47</sub>
    - `const HomeworkCapabilityEvidence({ required this.capability, required this.state, required this.reason, required this.evidence, });`  <sub>:48</sub>
- `class HomeworkFileAttachment`
  <sub>class · application/homework_files.dart:64</sub>
    - `const HomeworkFileAttachment(this.id, this.name, this.kind);`  <sub>:65</sub>
- `class HomeworkFileWorkspace`
  <sub>class · application/homework_files.dart:69</sub>
    - `const HomeworkFileWorkspace({ required this.assignmentId, required this.methods, required this.extensions, required this.attachments, required this.canSubmit, required this.limitBytes, this.limit, this.count, this.blockedReason, this.returned = false, this.text, this.feedback, });`  <sub>:70</sub>
- `class HomeworkFileReceipt`
  <sub>class · application/homework_files.dart:120</sub>
    - `const HomeworkFileReceipt(this.handle, this.name, this.size);`  <sub>:121</sub>
- `class HomeworkFileDownload`
  <sub>class · application/homework_files.dart:126</sub>
    - `const HomeworkFileDownload(this.name, this.bytes);`  <sub>:127</sub>

## application/learning.dart

- `abstract interface class LearningCourseGateway` — Separate, read-only capabilities: implementing one never grants writes.
  <sub>class · application/learning.dart:4</sub>
    - `Future<LearningRead<List<LearningCourse>>> learningCourses({ bool forceRefresh = false, });`  <sub>:5</sub>
- `abstract interface class CourseAnnouncementGateway`
  <sub>class · application/learning.dart:10</sub>
    - `Future<LearningRead<List<CourseAnnouncement>>> courseAnnouncements( String course, { bool forceRefresh = false, });`  <sub>:11</sub>
    - `Future<CourseAnnouncementDetail> courseAnnouncementDetail( String course, String id, );`  <sub>:15</sub>
    - `Future<LearningDownload> courseAnnouncementAttachment( String course, String id, String file, );`  <sub>:19</sub>
- `abstract interface class CourseResourceGateway`
  <sub>class · application/learning.dart:26</sub>
    - `Future<LearningRead<CourseResourcePage>> courseResources( String course, { String? folder, int page = 1, bool forceRefresh = false, });`  <sub>:27</sub>
    - `Future<LearningDownload> courseResourceDownload( String course, String id, { String? folder, int page = 1, });`  <sub>:33</sub>
- `abstract interface class CourseAssessmentGateway`
  <sub>class · application/learning.dart:41</sub>
    - `Future<LearningRead<List<CourseAssessment>>> courseAssessments( String course, { bool forceRefresh = false, });`  <sub>:42</sub>
- `class LearningRead<T>` — An old successful value and a refresh failure must travel together.
  <sub>class · application/learning.dart:49</sub>
    - `const LearningRead(this.data, {this.stale = false, this.failure});`  <sub>:50</sub>

## application/learning_context.dart

- `abstract interface class CourseLearningContextGateway` — Explicit, server-validated navigation contexts. No school URLs or tokens.
  <sub>class · application/learning_context.dart:5</sub>
    - `Future<LearningRead<List<LearningColumn>>> learningColumns( String course, { bool forceRefresh = false, });`  <sub>:6</sub>
    - `Future<LearningCapabilities> learningCapabilities(String course);`  <sub>:10</sub>
    - `Future<LearningRead<List<CourseAnnouncement>>> courseAnnouncementsIn( String course, String column, { bool forceRefresh = false, });`  <sub>:11</sub>
    - `Future<CourseAnnouncementDetail> courseAnnouncementDetailIn( String course, String column, String id, );`  <sub>:16</sub>
    - `Future<LearningDownload> courseAnnouncementAttachmentIn( String course, String column, String id, String file, );`  <sub>:21</sub>
    - `Future<LearningRead<List<CourseAssessment>>> courseAssessmentsIn( String course, String column, { bool forceRefresh = false, });`  <sub>:27</sub>
    - `Future<LearningRead<CourseResourcePage>> courseResourcesAt( String course, { List<String> path = const [], int page = 1, bool forceRefresh = false, });`  <sub>:32</sub>
    - `Future<LearningDownload> courseResourceDownloadAt( String course, String id, { List<String> path = const [], int page = 1, });`  <sub>:38</sub>
- `class LearningColumn`
  <sub>class · application/learning_context.dart:46</sub>
    - `const LearningColumn({ required this.id, required this.name, required this.kind, });`  <sub>:47</sub>
- `class LearningCapabilities` — Observations of this session, never an instruction to probe an endpoint.
  <sub>class · application/learning_context.dart:56</sub>
    - `const LearningCapabilities({ this.columns = 'unknown', this.announcements = 'unknown', this.resources = 'unknown', this.assessments = 'unknown', this.resourceDownload = 'unknown', this.announcementDownload = 'unknown', });`  <sub>:57</sub>

## application/learning_file_actions.dart

- `typedef LearningFileSaver = Future<LearningSavedFile?> Function(` — User-initiated local save; implementors must recheck current after selection
  <sub>typedef · application/learning_file_actions.dart:5</sub>
- `class LearningSavedFile`
  <sub>class · application/learning_file_actions.dart:10</sub>
    - `const LearningSavedFile({required this.open});`  <sub>:11</sub>
    - `final Future<void> Function() open;`  <sub>:12</sub>

## application/learning_models.dart

- `class LearningCourse` — Business values only. School fields and authentication stay in Rust.
  <sub>class · application/learning_models.dart:4</sub>
    - `const LearningCourse({ required this.id, required this.name, required this.sourceUrl, this.teacher, this.term, });`  <sub>:5</sub>
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
    - `const CourseResource({ required this.id, required this.name, required this.folder, required this.downloadable, this.updatedAt, this.extension, });`  <sub>:40</sub>
- `class CourseResourcePage`
  <sub>class · application/learning_models.dart:53</sub>
- `class CourseAssessment`
  <sub>class · application/learning_models.dart:61</sub>
    - `const CourseAssessment({ required this.id, required this.title, required this.sourceUrl, this.startsAt, this.dueAt, this.score, });`  <sub>:62</sub>
- `class LearningDownload`
  <sub>class · application/learning_models.dart:74</sub>

## application/learning_ports.dart

- `class LearningPorts` — The learning ports a service offers, resolved once.
  <sub>class · application/learning_ports.dart:9</sub>
    - `const LearningPorts({ this.context, this.announcements, this.resources, this.assessments, this.courses, });`  <sub>:10</sub>

## application/library_loans.dart

- `class LibraryLoan` — Private on-demand reads. Implementations must not persist reader records.
  <sub>class · application/library_loans.dart:4</sub>
    - `const LibraryLoan({ required this.id, this.title, this.author, this.callNumber, this.borrowedAt, this.dueAt, });`  <sub>:5</sub>
- `class LibraryLoanPage`
  <sub>class · application/library_loans.dart:17</sub>
    - `const LibraryLoanPage({ required this.items, required this.page, required this.total, required this.hasMore, });`  <sub>:18</sub>
- `class LibraryLoansRead`
  <sub>class · application/library_loans.dart:29</sub>
    - `const LibraryLoansRead({this.data, this.failure});`  <sub>:30</sub>
- `abstract interface class LibraryLoansOfficialGateway`
  <sub>class · application/library_loans.dart:35</sub>
    - `String libraryLoansPortalUrl();`  <sub>:36</sub>
- `abstract interface class LibraryLoansGateway`
  <sub>class · application/library_loans.dart:39</sub>
    - `Future<LibraryLoansRead> libraryLoans({int page = 1});`  <sub>:40</sub>

## application/local_tasks.dart

- `class LocalTaskRecord` — Device-local personal task. Completion never changes a school assignment.
  <sub>class · application/local_tasks.dart:7</sub>
    - `const LocalTaskRecord({ required this.id, required this.title, required this.due, required this.completed, this.sourceAssignmentId, });`  <sub>:8</sub>
- `List<LocalTaskRecord> parseLocalTasksPayload(String? payload) {…}` — Fail closed: null, malformed lists/rows and duplicate ids are not empty data.
  <sub>function · application/local_tasks.dart:60</sub>
- `bool isLocalTaskDue(String value) {…}`
  <sub>function · application/local_tasks.dart:77</sub>
- `String localTaskDueFromHomework(String? value) {…}` — School wall-clock timestamps have no offset; explicitly use Beijing time.
  <sub>function · application/local_tasks.dart:92</sub>
- `String localTaskDueLabel(String due) {…}`
  <sub>function · application/local_tasks.dart:104</sub>
- `Future<List<LocalTaskRecord>> editLocalTasks( LocalTaskGateway service, { required String root, required String action, String? id, String? title, String? due, bool? completed, }) async {…}` — The only JSON decoding path shared by Today, Tasks and homework linking.
  <sub>function · application/local_tasks.dart:115</sub>

## application/mirror_service.dart

- `abstract interface class MirrorService` — Page-facing capabilities. Tests and alternative adapters need no native runtime.
  <sub>class · application/mirror_service.dart:5</sub>
- `abstract interface class CampusCardGateway implements MirrorEnvironment`
  <sub>class · application/mirror_service.dart:15</sub>
    - `Future<CampusCardBalanceResponse> campusCardBalance();`  <sub>:16</sub>
- `abstract interface class StudentServiceLinksGateway` — Public official destinations only; does not read or transmit account data.
  <sub>class · application/mirror_service.dart:20</sub>
    - `String? studentServiceUrl(String id);`  <sub>:21</sub>
- `abstract interface class CareerEventsGateway implements MirrorEnvironment` — Public career-calendar reads; no login and no background refresh.
  <sub>class · application/mirror_service.dart:25</sub>
    - `Future<CareerEventsRead> careerEvents({ required String month, bool forceRefresh = false, });`  <sub>:26</sub>
- `abstract interface class MirrorEnvironment`
  <sub>class · application/mirror_service.dart:32</sub>
- `abstract interface class SessionGateway implements MirrorEnvironment`
  <sub>class · application/mirror_service.dart:36</sub>
    - `Future<SessionResponse> restoreSession();`  <sub>:37</sub>
    - `Future<SessionResponse> login({ required String account, required String password, String? captcha, required bool remember, });`  <sub>:39</sub>
    - `Future<SessionResponse> signOut();`  <sub>:46</sub>
    - `Future<SessionResponse> setRoute(RouteChoice route);`  <sub>:48</sub>
    - `Future<bool> clearCache();`  <sub>:50</sub>
    - `Future<bool> verifyBridgeContract();`  <sub>:52</sub>
- `abstract interface class AcademicGateway implements MirrorEnvironment`
  <sub>class · application/mirror_service.dart:55</sub>
    - `Future<QueryDates> dates(String instant);`  <sub>:56</sub>
    - `Future<ClassroomResponse> classrooms(DemoScope scope, ClassroomQuery query);`  <sub>:58</sub>
    - `Future<RuleExamples> rules();`  <sub>:60</sub>
    - `Future<ScheduleResponse> schedule({ String? termId, int? week, bool forceRefresh = false, });`  <sub>:62</sub>
    - `Future<GradeTermsResponse> gradeTerms();`  <sub>:68</sub>
    - `Future<GradeResponse> grades({String? termCode, bool forceRefresh = false});`  <sub>:70</sub>
    - `Future<TodayResponse> today({bool forceRefresh = false});`  <sub>:72</sub>
    - `Future<HomeworkResponse> homework({bool forceRefresh = false});`  <sub>:74</sub>
    - `Future<HomeworkDetailResponse> homeworkDetail( String assignmentId, { bool forceRefresh = false, });`  <sub>:76</sub>
- `abstract interface class CheckInGateway implements MirrorEnvironment`
  <sub>class · application/mirror_service.dart:82</sub>
    - `Future<CheckInResponse> checkin({bool forceRefresh = false});`  <sub>:83</sub>
    - `Future<CheckInResponse> checkinOnDate( String date, { bool forceRefresh = false, });`  <sub>:85</sub>
    - `Future<MutationResponse> submitCheckin(String courseId);`  <sub>:90</sub>
    - `Future<ReadOnlyResponse> checkinProgress();`  <sub>:92</sub>
- `abstract interface class LibrarySeatingGateway implements MirrorEnvironment`
  <sub>class · application/mirror_service.dart:95</sub>
    - `Future<ReadOnlyResponse> libraryStats({bool forceRefresh = false});`  <sub>:96</sub>
    - `Future<MutationResponse> reserveLibrarySeat({ required String areaId, required String seatId, required LibrarySlot slot, });`  <sub>:98</sub>
    - `Future<MutationResponse> performLibraryAction( String bookingId, String action, );`  <sub>:104</sub>
    - `Future<LibraryVenuesResponse> libraryVenues({bool forceRefresh = false});`  <sub>:109</sub>
    - `Future<LibraryAreasResponse> libraryAreas(String libraryId);`  <sub>:111</sub>
    - `Future<LibrarySlotsResponse> librarySlots(String areaId);`  <sub>:113</sub>
    - `Future<LibrarySeatsResponse> librarySeats({ required String areaId, required LibrarySlot slot, });`  <sub>:115</sub>
    - `Future<LibraryBookingsResponse> libraryBookings({bool forceRefresh = false});`  <sub>:120</sub>
    - `Future<LibraryHistoryResponse> libraryHistory( int page, { bool forceRefresh = false, });`  <sub>:122</sub>
- `abstract interface class LibraryCatalogGateway implements MirrorEnvironment`
  <sub>class · application/mirror_service.dart:128</sub>
    - `Future<ReadOnlyResponse> libraryBooks({ required String query, required int page, String sort, bool descending, });` — Public OPAC search. Anonymous and read-only; never personal records.  <sub>:131</sub>
    - `Future<ReadOnlyResponse> libraryHoldings(String bibId);` — Public holdings for one bib id; the school's nested JSON stays in Rust.  <sub>:139</sub>
- `abstract interface class LibraryGateway`
  <sub>class · application/mirror_service.dart:142</sub>
- `abstract interface class ShuttleGateway implements MirrorEnvironment`
  <sub>class · application/mirror_service.dart:145</sub>
    - `Future<ReadOnlyResponse> shuttleTimetable();` — Published shuttle timetable (official page). No live seats, no ticketing.  <sub>:147</sub>
- `abstract interface class BykcGateway implements MirrorEnvironment`
  <sub>class · application/mirror_service.dart:150</sub>
    - `Future<ReadOnlyResponse> bykcPart(BykcPart part, {bool forceRefresh = false});`  <sub>:151</sub>
- `abstract interface class GraduateGateway implements MirrorEnvironment`
  <sub>class · application/mirror_service.dart:154</sub>
    - `Future<ReadOnlyResponse> graduatePart({ required bool report, required bool forceRefresh, });`  <sub>:155</sub>
- `abstract interface class NoticeGateway implements MirrorEnvironment`
  <sub>class · application/mirror_service.dart:161</sub>
    - `Future<ReadOnlyResponse> notices({bool forceRefresh = false});`  <sub>:162</sub>
- `abstract interface class CgyyGateway implements MirrorEnvironment`
  <sub>class · application/mirror_service.dart:165</sub>
    - `Future<ReadOnlyResponse> cgyy({ required String kind, required int siteId, required String date, required bool forceRefresh, });`  <sub>:166</sub>
- `abstract interface class CampusGateway`
  <sub>class · application/mirror_service.dart:174</sub>
- `abstract interface class LocalTaskGateway implements MirrorEnvironment`
  <sub>class · application/mirror_service.dart:177</sub>
    - `Future<ReadOnlyResponse> editTasks({ required String root, required String action, String? id, String? title, String? due, bool? completed, });`  <sub>:178</sub>
- `abstract interface class CgyyBookingGateway` — Separate capability: read-only adapters never gain writes implicitly.
  <sub>class · application/mirror_service.dart:189</sub>
    - `Future<ReadOnlyResponse> executeCgyy(Map<String, Object?> command);`  <sub>:190</sub>
- `enum BykcPart { catalog, chosen, statistics }`
  <sub>enum · application/mirror_service.dart:193</sub>

## application/query_snapshots.dart

- `class LearningSnapshotStatus`
  <sub>class · application/query_snapshots.dart:1</sub>
    - `const LearningSnapshotStatus({ required this.supported, this.enabled = false, this.message, });`  <sub>:2</sub>
- `abstract interface class LearningSnapshotGateway`
  <sub>class · application/query_snapshots.dart:11</sub>
    - `Future<LearningSnapshotStatus> learningSnapshotStatus();`  <sub>:12</sub>
    - `Future<LearningSnapshotStatus> setLearningSnapshotsEnabled(bool enabled);` — User must explicitly confirm saving private learning metadata first.  <sub>:15</sub>

## application/refresh_section.dart

- `class SectionResult<T>` — A presentation result, including a usable stale value when refresh failed.
  <sub>class · application/refresh_section.dart:7</sub>
    - `const SectionResult({this.value, this.error});`  <sub>:8</sub>
- `class RefreshSection<T> extends ChangeNotifier` — Independent section refreshes preserve content and join overlapping reads.
  <sub>class · application/refresh_section.dart:15</sub>
    - `bool loading = false;`  <sub>:28</sub>
    - `void invalidate() => …` — Drops every in-flight read at its next await: call when the account or  <sub>:38</sub>
    - `Future<void> refresh( Future<SectionResult<T>> Function() read, { required String fallbackError, bool force = false, }) {…}` — A plain refresh joins the in-flight read. A forced refresh is never  <sub>:43</sub>
    - `void dispose() {…}`  <sub>:137</sub>

## application/reminder_planning.dart

- `abstract interface class ReminderPlanningGateway` — Typed, local-only business capability. No school payload or platform API.
  <sub>class · application/reminder_planning.dart:6</sub>
    - `Future<ExtendedReminderPlans> planReminders({ required List<CourseReminderSeed> courses, required List<TaskReminderSeed> tasks, required int nowMillis, });`  <sub>:7</sub>
- `class CourseReminderSeed`
  <sub>class · application/reminder_planning.dart:14</sub>
    - `const CourseReminderSeed({ required this.id, required this.weekStart, required this.day, required this.startsAt, required this.endsAt, });`  <sub>:15</sub>
- `class TaskReminderSeed`
  <sub>class · application/reminder_planning.dart:26</sub>
    - `const TaskReminderSeed({ required this.id, required this.due, required this.completed, });`  <sub>:27</sub>
- `class ExtendedReminderPlans`
  <sub>class · application/reminder_planning.dart:36</sub>
- `List<CourseReminderSeed> courseReminderSeeds(ScheduleResponse data) {…}`
  <sub>function · application/reminder_planning.dart:47</sub>
- `List<TaskReminderSeed> taskReminderSeeds(Iterable<LocalTaskRecord> data) => …`
  <sub>function · application/reminder_planning.dart:63</sub>

## application/reminder_platform.dart

- `abstract interface class ReminderPlatform` — System notification scheduling, independent of the platform channel.
  <sub>class · application/reminder_platform.dart:2</sub>
    - `Future<void> replace(List<Map<String, Object>> plans);`  <sub>:3</sub>

## application/reminder_store.dart

- `abstract interface class ReminderStore` — Account-scoped persistence for reminder preferences and read receipts.
  <sub>class · application/reminder_store.dart:4</sub>
    - `Future<String?> read();`  <sub>:5</sub>
    - `Future<void> write(String data);`  <sub>:6</sub>

## application/service_capabilities.dart

- `class ServiceCapabilities` — Optional capabilities of the injected service, resolved once.
  <sub>class · application/service_capabilities.dart:15</sub>
    - `const ServiceCapabilities({ this.academic, this.careerEvents, this.campusActivities, this.courseAnnouncement, this.courseAssessment, this.courseLearningContext, this.courseResource, this.cgyyBooking, this.graduateCreditMap, this.learningCourse, this.learningSnapshots, this.libraryLoans, this.libraryLoansOfficial, this.campusCard, this.reminderPlanning, this.studentServiceLinks, });`  <sub>:16</sub>
    - `static ServiceCapabilities resolve(MirrorService service) => …` — The composition root resolves every optional capability exactly once, so  <sub>:84</sub>

## application/task_storage_scope.dart

- `typedef TaskStorageRoot = Future<String> Function();` — Resolves the local task directory without exposing a platform plugin to pages.
  <sub>typedef · application/task_storage_scope.dart:4</sub>
- `class TaskStorageScope extends InheritedWidget`
  <sub>class · application/task_storage_scope.dart:6</sub>
    - `const TaskStorageScope({ super.key, required this.resolve, required super.child, });`  <sub>:7</sub>
    - `static TaskStorageRoot read(BuildContext context) {…}`  <sub>:15</sub>
    - `bool updateShouldNotify(TaskStorageScope oldWidget) => …`  <sub>:22</sub>
