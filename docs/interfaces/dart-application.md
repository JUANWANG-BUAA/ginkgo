# Dart 应用接口（flutter/lib/application）

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。

页面依赖的 gateway、契约与局部应用状态。

## LoginChallenge (class)

- `class LoginChallenge {` — In-memory authentication UI values; never a URL or a persistence payload.  
  <sub>application/auth_challenge.dart:4</sub>

## AuthChallengeGateway (class)

- `abstract interface class AuthChallengeGateway {`  
  <sub>application/auth_challenge.dart:17</sub>
    - `Future<LoginChallenge> loginChallenge({ String? expectedId, bool refresh = false, });` — Read the current pending challenge, or explicitly replace its login page.  <sub>:20</sub>

## CollectionWindow (class)

- `class CollectionWindow {` — Bounded presentation of an already-loaded result, independent of transport.  
  <sub>application/collection_window.dart:3</sub>
    - `int page = 0;`  <sub>:7</sub>
    - `int get count => _keys.length;`  <sub>:8</sub>
    - `int get pageCount => count == 0 ? 1 : (count / pageSize).ceil();`  <sub>:9</sub>
    - `int get start => page * pageSize;`  <sub>:10</sub>
    - `int get end => (start + pageSize).clamp(0, count);`  <sub>:11</sub>
    - `void reconcile(Iterable<String> keys, {bool reset = false}) { final anchor = _keys.isEmpty ? null : _keys[start]; _keys = keys.toList(growable: false…`  <sub>:13</sub>
    - `void select(int value) => page = value.clamp(0, pageCount - 1);`  <sub>:24</sub>

## DiagnosticEntry (class)

- `class DiagnosticEntry {` — Allowlisted diagnostics only: no exception text, URLs, account or payloads.  
  <sub>application/diagnostic_log.dart:8</sub>
    - `const DiagnosticEntry(this.code, this.at);`  <sub>:9</sub>
    - `String get hint => switch (code) { 'sessionExpired' \|\| 'invalidCredentials' \|\| 'captchaRequired' => '回到账号页重新登录；请勿分享密码、验证码或 Cookie。', 'changedResponse…`  <sub>:12</sub>
    - `String get summary => '${at.toUtc().toIso8601String()} code=$code';`  <sub>:22</sub>

## DiagnosticLog (class)

- `class DiagnosticLog extends ChangeNotifier {`  
  <sub>application/diagnostic_log.dart:25</sub>
    - `static final shared = DiagnosticLog();`  <sub>:26</sub>
    - `final List<DiagnosticEntry> entries = [];`  <sub>:27</sub>
    - `void record(FailureCode? failure) { final code = failure?.name ?? 'localService'; final now = DateTime.now(); if (entries.isNotEmpty && entries.last.…`  <sub>:29</sub>
    - `void dismiss() { current = null; notifyListeners(); }`  <sub>:45</sub>

## GraduateCreditMapGateway (class)

- `abstract interface class GraduateCreditMapGateway {`  
  <sub>application/graduate_credit_map.dart:6</sub>
    - `Future<GraduateCreditMapRead> graduateCreditMap({bool forceRefresh = false});`  <sub>:7</sub>

## GraduateCreditMapRead (class)

- `class GraduateCreditMapRead {`  
  <sub>application/graduate_credit_map.dart:10</sub>
    - `const GraduateCreditMapRead({this.data, this.issue, this.stale = false});`  <sub>:11</sub>

## GraduateCreditIssueKind (enum)

- `enum GraduateCreditIssueKind {`  
  <sub>application/graduate_credit_map.dart:17</sub>

## GraduateCreditReadIssue (class)

- `class GraduateCreditReadIssue {` — Classification must be backed by the actual read result, never by missing  
  <sub>application/graduate_credit_map.dart:29</sub>
    - `const GraduateCreditReadIssue(this.kind);`  <sub>:30</sub>
    - `static GraduateCreditReadIssue? fromFailure(FailureCode? code) => switch (code) { null => null, FailureCode.changedResponse => const GraduateCreditRe…`  <sub>:33</sub>
    - `String get message => switch (kind) { GraduateCreditIssueKind.protocolChanged => '学校执行报告接口返回结构已变化或路径失效，请前往官网核对', GraduateCreditIssueKind.authenticati…`  <sub>:57</sub>

## GraduateCreditState (enum)

- `enum GraduateCreditState { unknown, noMinimum, incomplete, requirementMet }`  
  <sub>application/graduate_credit_map.dart:68</sub>

## GraduateCreditMetrics (class)

- `class GraduateCreditMetrics {`  
  <sub>application/graduate_credit_map.dart:70</sub>
    - `const GraduateCreditMetrics({ required this.state, this.requiredCredits, this.earned, this.pending, this.remaining, this.ratio, });`  <sub>:71</sub>
    - `String get stateLabel => switch (state) { GraduateCreditState.unknown => '学分信息不完整', GraduateCreditState.noMinimum => '本项无最低学分要求', GraduateCreditState…`  <sub>:82</sub>

## GraduateCreditRow (class)

- `class GraduateCreditRow {`  
  <sub>application/graduate_credit_map.dart:90</sub>
    - `const GraduateCreditRow({ required this.title, required this.detail, required this.isCourse, this.completed, this.credit, this.semester, });`  <sub>:91</sub>

## GraduateCreditNode (class)

- `class GraduateCreditNode {`  
  <sub>application/graduate_credit_map.dart:106</sub>

## GraduateCreditMap (class)

- `class GraduateCreditMap {`  
  <sub>application/graduate_credit_map.dart:119</sub>
    - `bool get isEmpty => summary == null && nodes.isEmpty;`  <sub>:128</sub>

## HomeworkFilesGateway (class)

- `abstract interface class HomeworkFilesGateway {` — Business-only capability, independent from school endpoints and AcademicGateway.  
  <sub>application/homework_files.dart:6</sub>
    - `Future<HomeworkFileWorkspace> homeworkFiles(String assignmentId);`  <sub>:7</sub>
    - `Future<List<HomeworkPendingSubmission>> pendingHomeworkSubmissions({ String? assignmentId, });`  <sub>:8</sub>
    - `Future<List<HomeworkCapabilityEvidence>> homeworkCapabilities( String assignmentId, );`  <sub>:11</sub>
    - `Future<HomeworkFileReceipt> uploadHomeworkFile( String assignmentId, String name, Uint8List bytes, );`  <sub>:14</sub>
    - `Future<MutationResponse> submitHomeworkFile(String handle);`  <sub>:19</sub>
    - `Future<MutationResponse> reconcileHomeworkFile(String handle);`  <sub>:20</sub>
    - `Future<HomeworkFileDownload> downloadHomeworkFile( String assignmentId, String attachmentId, );`  <sub>:21</sub>

## HomeworkPendingSubmission (class)

- `class HomeworkPendingSubmission {` — Only opaque ownership-bound recovery metadata, never file bytes or names.  
  <sub>application/homework_files.dart:28</sub>
    - `const HomeworkPendingSubmission( this.handle, this.assignmentId, { this.fileName, this.size, });`  <sub>:29</sub>

## HomeworkCapabilityEvidence (class)

- `class HomeworkCapabilityEvidence {`  
  <sub>application/homework_files.dart:47</sub>
    - `const HomeworkCapabilityEvidence({ required this.capability, required this.state, required this.reason, required this.evidence, });`  <sub>:48</sub>

## HomeworkFileAttachment (class)

- `class HomeworkFileAttachment {`  
  <sub>application/homework_files.dart:64</sub>
    - `const HomeworkFileAttachment(this.id, this.name, this.kind);`  <sub>:65</sub>

## HomeworkFileWorkspace (class)

- `class HomeworkFileWorkspace {`  
  <sub>application/homework_files.dart:69</sub>
    - `const HomeworkFileWorkspace({ required this.assignmentId, required this.methods, required this.extensions, required this.attachments, required this.c…`  <sub>:70</sub>

## HomeworkFileReceipt (class)

- `class HomeworkFileReceipt {`  
  <sub>application/homework_files.dart:120</sub>
    - `const HomeworkFileReceipt(this.handle, this.name, this.size);`  <sub>:121</sub>

## HomeworkFileDownload (class)

- `class HomeworkFileDownload {`  
  <sub>application/homework_files.dart:126</sub>
    - `const HomeworkFileDownload(this.name, this.bytes);`  <sub>:127</sub>

## LearningCourseGateway (class)

- `abstract interface class LearningCourseGateway {` — Separate, read-only capabilities: implementing one never grants writes.  
  <sub>application/learning.dart:4</sub>
    - `Future<LearningRead<List<LearningCourse>>> learningCourses({ bool forceRefresh = false, });`  <sub>:5</sub>

## CourseAnnouncementGateway (class)

- `abstract interface class CourseAnnouncementGateway {`  
  <sub>application/learning.dart:10</sub>
    - `Future<LearningRead<List<CourseAnnouncement>>> courseAnnouncements( String course, { bool forceRefresh = false, });`  <sub>:11</sub>
    - `Future<CourseAnnouncementDetail> courseAnnouncementDetail( String course, String id, );`  <sub>:15</sub>
    - `Future<LearningDownload> courseAnnouncementAttachment( String course, String id, String file, );`  <sub>:19</sub>

## CourseResourceGateway (class)

- `abstract interface class CourseResourceGateway {`  
  <sub>application/learning.dart:26</sub>
    - `Future<LearningRead<CourseResourcePage>> courseResources( String course, { String? folder, int page = 1, bool forceRefresh = false, });`  <sub>:27</sub>
    - `Future<LearningDownload> courseResourceDownload( String course, String id, { String? folder, int page = 1, });`  <sub>:33</sub>

## CourseAssessmentGateway (class)

- `abstract interface class CourseAssessmentGateway {`  
  <sub>application/learning.dart:41</sub>
    - `Future<LearningRead<List<CourseAssessment>>> courseAssessments( String course, { bool forceRefresh = false, });`  <sub>:42</sub>

## LearningRead (class)

- `class LearningRead<T> {` — An old successful value and a refresh failure must travel together.  
  <sub>application/learning.dart:49</sub>
    - `const LearningRead(this.data, {this.stale = false, this.failure});`  <sub>:50</sub>

## CourseLearningContextGateway (class)

- `abstract interface class CourseLearningContextGateway {` — Explicit, server-validated navigation contexts. No school URLs or tokens.  
  <sub>application/learning_context.dart:5</sub>
    - `Future<LearningRead<List<LearningColumn>>> learningColumns( String course, { bool forceRefresh = false, });`  <sub>:6</sub>
    - `Future<LearningCapabilities> learningCapabilities(String course);`  <sub>:10</sub>
    - `Future<LearningRead<List<CourseAnnouncement>>> courseAnnouncementsIn( String course, String column, { bool forceRefresh = false, });`  <sub>:11</sub>
    - `Future<CourseAnnouncementDetail> courseAnnouncementDetailIn( String course, String column, String id, );`  <sub>:16</sub>
    - `Future<LearningDownload> courseAnnouncementAttachmentIn( String course, String column, String id, String file, );`  <sub>:21</sub>
    - `Future<LearningRead<List<CourseAssessment>>> courseAssessmentsIn( String course, String column, { bool forceRefresh = false, });`  <sub>:27</sub>
    - `Future<LearningRead<CourseResourcePage>> courseResourcesAt( String course, { List<String> path = const [], int page = 1, bool forceRefresh = false, }…`  <sub>:32</sub>
    - `Future<LearningDownload> courseResourceDownloadAt( String course, String id, { List<String> path = const [], int page = 1, });`  <sub>:38</sub>

## LearningColumn (class)

- `class LearningColumn {`  
  <sub>application/learning_context.dart:46</sub>
    - `const LearningColumn({ required this.id, required this.name, required this.kind, });`  <sub>:47</sub>

## LearningCapabilities (class)

- `class LearningCapabilities {` — Observations of this session, never an instruction to probe an endpoint.  
  <sub>application/learning_context.dart:56</sub>
    - `const LearningCapabilities({ this.columns = 'unknown', this.announcements = 'unknown', this.resources = 'unknown', this.assessments = 'unknown', this…`  <sub>:57</sub>

## LearningFileSaver (typedef)

- `typedef LearningFileSaver = Future<LearningSavedFile?> Function(` — User-initiated local save; implementors must recheck current after selection  
  <sub>application/learning_file_actions.dart:5</sub>

## LearningSavedFile (class)

- `class LearningSavedFile {`  
  <sub>application/learning_file_actions.dart:10</sub>
    - `const LearningSavedFile({required this.open});`  <sub>:11</sub>
    - `final Future<void> Function() open;`  <sub>:12</sub>

## LearningCourse (class)

- `class LearningCourse {` — Business values only. School fields and authentication stay in Rust.  
  <sub>application/learning_models.dart:4</sub>
    - `const LearningCourse({ required this.id, required this.name, required this.sourceUrl, this.teacher, this.term, });`  <sub>:5</sub>

## CourseAnnouncement (class)

- `class CourseAnnouncement {`  
  <sub>application/learning_models.dart:16</sub>
    - `const CourseAnnouncement(this.id, this.title, this.publishedAt);`  <sub>:17</sub>

## LearningAttachment (class)

- `class LearningAttachment {`  
  <sub>application/learning_models.dart:22</sub>
    - `const LearningAttachment(this.id, this.name);`  <sub>:23</sub>

## CourseAnnouncementDetail (class)

- `class CourseAnnouncementDetail {`  
  <sub>application/learning_models.dart:27</sub>

## CourseResource (class)

- `class CourseResource {`  
  <sub>application/learning_models.dart:39</sub>
    - `const CourseResource({ required this.id, required this.name, required this.folder, required this.downloadable, this.updatedAt, this.extension, });`  <sub>:40</sub>

## CourseResourcePage (class)

- `class CourseResourcePage {`  
  <sub>application/learning_models.dart:53</sub>

## CourseAssessment (class)

- `class CourseAssessment {`  
  <sub>application/learning_models.dart:61</sub>
    - `const CourseAssessment({ required this.id, required this.title, required this.sourceUrl, this.startsAt, this.dueAt, this.score, });`  <sub>:62</sub>

## LearningDownload (class)

- `class LearningDownload {`  
  <sub>application/learning_models.dart:74</sub>

## LibraryLoan (class)

- `class LibraryLoan {` — Private on-demand reads. Implementations must not persist reader records.  
  <sub>application/library_loans.dart:4</sub>
    - `const LibraryLoan({ required this.id, this.title, this.author, this.callNumber, this.borrowedAt, this.dueAt, });`  <sub>:5</sub>

## LibraryLoanPage (class)

- `class LibraryLoanPage {`  
  <sub>application/library_loans.dart:17</sub>
    - `const LibraryLoanPage({ required this.items, required this.page, required this.total, required this.hasMore, });`  <sub>:18</sub>

## LibraryLoansRead (class)

- `class LibraryLoansRead {`  
  <sub>application/library_loans.dart:29</sub>
    - `const LibraryLoansRead({this.data, this.failure});`  <sub>:30</sub>

## LibraryLoansOfficialGateway (class)

- `abstract interface class LibraryLoansOfficialGateway {`  
  <sub>application/library_loans.dart:35</sub>
    - `String libraryLoansPortalUrl();`  <sub>:36</sub>

## LibraryLoansGateway (class)

- `abstract interface class LibraryLoansGateway {`  
  <sub>application/library_loans.dart:39</sub>
    - `Future<LibraryLoansRead> libraryLoans({int page = 1});`  <sub>:40</sub>

## LocalTaskRecord (class)

- `class LocalTaskRecord {` — Device-local personal task. Completion never changes a school assignment.  
  <sub>application/local_tasks.dart:9</sub>
    - `const LocalTaskRecord({ required this.id, required this.title, required this.due, required this.completed, this.sourceAssignmentId, });`  <sub>:10</sub>

## MirrorService (class)

- `abstract interface class MirrorService` — Page-facing capabilities. Tests and alternative adapters need no native runtime.  
  <sub>application/mirror_service.dart:4</sub>

## MirrorEnvironment (class)

- `abstract interface class MirrorEnvironment {`  
  <sub>application/mirror_service.dart:12</sub>

## SessionGateway (class)

- `abstract interface class SessionGateway implements MirrorEnvironment {`  
  <sub>application/mirror_service.dart:16</sub>
    - `Future<SessionResponse> restoreSession();`  <sub>:17</sub>
    - `Future<SessionResponse> login({ required String account, required String password, String? captcha, required bool remember, });`  <sub>:19</sub>
    - `Future<SessionResponse> signOut();`  <sub>:26</sub>
    - `Future<SessionResponse> setRoute(RouteChoice route);`  <sub>:28</sub>
    - `Future<bool> clearCache();`  <sub>:30</sub>
    - `Future<bool> verifyBridgeContract();`  <sub>:32</sub>

## AcademicGateway (class)

- `abstract interface class AcademicGateway implements MirrorEnvironment {`  
  <sub>application/mirror_service.dart:35</sub>
    - `Future<QueryDates> dates(String instant);`  <sub>:36</sub>
    - `Future<ClassroomResponse> classrooms(DemoScope scope, ClassroomQuery query);`  <sub>:38</sub>
    - `Future<RuleExamples> rules();`  <sub>:40</sub>
    - `Future<ScheduleResponse> schedule({ String? termId, int? week, bool forceRefresh = false, });`  <sub>:42</sub>
    - `Future<GradeTermsResponse> gradeTerms();`  <sub>:48</sub>
    - `Future<GradeResponse> grades({String? termCode, bool forceRefresh = false});`  <sub>:50</sub>
    - `Future<TodayResponse> today({bool forceRefresh = false});`  <sub>:52</sub>
    - `Future<HomeworkResponse> homework({bool forceRefresh = false});`  <sub>:54</sub>
    - `Future<HomeworkDetailResponse> homeworkDetail( String assignmentId, { bool forceRefresh = false, });`  <sub>:56</sub>

## CheckInGateway (class)

- `abstract interface class CheckInGateway implements MirrorEnvironment {`  
  <sub>application/mirror_service.dart:62</sub>
    - `Future<CheckInResponse> checkin({bool forceRefresh = false});`  <sub>:63</sub>
    - `Future<CheckInResponse> checkinOnDate( String date, { bool forceRefresh = false, });`  <sub>:65</sub>
    - `Future<MutationResponse> submitCheckin(String courseId);`  <sub>:70</sub>
    - `Future<ReadOnlyResponse> checkinProgress();`  <sub>:72</sub>

## LibraryGateway (class)

- `abstract interface class LibraryGateway implements MirrorEnvironment {`  
  <sub>application/mirror_service.dart:75</sub>
    - `Future<ReadOnlyResponse> libraryStats({bool forceRefresh = false});`  <sub>:76</sub>
    - `Future<MutationResponse> reserveLibrarySeat({ required String areaId, required String seatId, required LibrarySlot slot, });`  <sub>:78</sub>
    - `Future<MutationResponse> performLibraryAction( String bookingId, String action, );`  <sub>:84</sub>
    - `Future<LibraryVenuesResponse> libraryVenues({bool forceRefresh = false});`  <sub>:89</sub>
    - `Future<LibraryAreasResponse> libraryAreas(String libraryId);`  <sub>:91</sub>
    - `Future<LibrarySlotsResponse> librarySlots(String areaId);`  <sub>:93</sub>
    - `Future<LibrarySeatsResponse> librarySeats({ required String areaId, required LibrarySlot slot, });`  <sub>:95</sub>
    - `Future<LibraryBookingsResponse> libraryBookings({bool forceRefresh = false});`  <sub>:100</sub>
    - `Future<LibraryHistoryResponse> libraryHistory( int page, { bool forceRefresh = false, });`  <sub>:102</sub>
    - `Future<ReadOnlyResponse> libraryBooks({ required String query, required int page, String sort, bool descending, });` — Public OPAC search. Anonymous and read-only; never personal records.  <sub>:109</sub>
    - `Future<ReadOnlyResponse> libraryHoldings(String bibId);` — Public holdings for one bib id; the school's nested JSON stays in Rust.  <sub>:117</sub>
    - `Future<ReadOnlyResponse> shuttleTimetable();` — Published shuttle timetable (official page). No live seats, no ticketing.  <sub>:120</sub>

## CampusGateway (class)

- `abstract interface class CampusGateway {`  
  <sub>application/mirror_service.dart:123</sub>
    - `Future<ReadOnlyResponse> bykcPart(BykcPart part, {bool forceRefresh = false});`  <sub>:124</sub>
    - `Future<ReadOnlyResponse> graduatePart({ required bool report, required bool forceRefresh, });`  <sub>:126</sub>
    - `Future<ReadOnlyResponse> notices({bool forceRefresh = false});`  <sub>:131</sub>
    - `Future<ReadOnlyResponse> cgyy({ required String kind, required int siteId, required String date, required bool forceRefresh, });`  <sub>:133</sub>
    - `Future<ReadOnlyResponse> editTasks({ required String root, required String action, String? id, String? title, String? due, bool? completed, });`  <sub>:140</sub>

## CgyyBookingGateway (class)

- `abstract interface class CgyyBookingGateway {` — Separate capability: read-only adapters never gain writes implicitly.  
  <sub>application/mirror_service.dart:151</sub>
    - `Future<ReadOnlyResponse> executeCgyy(Map<String, Object?> command);`  <sub>:152</sub>

## BykcPart (enum)

- `enum BykcPart { catalog, chosen, statistics }`  
  <sub>application/mirror_service.dart:155</sub>

## LearningSnapshotStatus (class)

- `class LearningSnapshotStatus {`  
  <sub>application/query_snapshots.dart:1</sub>
    - `const LearningSnapshotStatus({ required this.supported, this.enabled = false, this.message, });`  <sub>:2</sub>

## LearningSnapshotGateway (class)

- `abstract interface class LearningSnapshotGateway {`  
  <sub>application/query_snapshots.dart:11</sub>
    - `Future<LearningSnapshotStatus> learningSnapshotStatus();`  <sub>:12</sub>
    - `Future<LearningSnapshotStatus> setLearningSnapshotsEnabled(bool enabled);` — User must explicitly confirm saving private learning metadata first.  <sub>:15</sub>

## SectionResult (class)

- `class SectionResult<T> {` — A presentation result, including a usable stale value when refresh failed.  
  <sub>application/refresh_section.dart:5</sub>
    - `const SectionResult({this.value, this.error});`  <sub>:6</sub>

## RefreshSection (class)

- `class RefreshSection<T> extends ChangeNotifier {` — Independent section refreshes preserve content and join overlapping reads.  
  <sub>application/refresh_section.dart:13</sub>
    - `bool loading = false;`  <sub>:16</sub>
    - `void invalidate() => _generation++;` — Drops every in-flight read at its next await: call when the account or  <sub>:25</sub>
    - `Future<void> refresh( Future<SectionResult<T>> Function() read, { required String fallbackError, bool force = false, }) { final inFlight = _task; if …` — A plain refresh joins the in-flight read. A forced refresh is never  <sub>:30</sub>
    - `void dispose() { _disposed = true; super.dispose(); }`  <sub>:92</sub>

## ReminderPlanningGateway (class)

- `abstract interface class ReminderPlanningGateway {` — Typed, local-only business capability. No school payload or platform API.  
  <sub>application/reminder_planning.dart:6</sub>
    - `Future<ExtendedReminderPlans> planReminders({ required List<CourseReminderSeed> courses, required List<TaskReminderSeed> tasks, required int nowMilli…`  <sub>:7</sub>

## CourseReminderSeed (class)

- `class CourseReminderSeed {`  
  <sub>application/reminder_planning.dart:14</sub>
    - `const CourseReminderSeed({ required this.id, required this.weekStart, required this.day, required this.startsAt, required this.endsAt, });`  <sub>:15</sub>

## TaskReminderSeed (class)

- `class TaskReminderSeed {`  
  <sub>application/reminder_planning.dart:26</sub>
    - `const TaskReminderSeed({ required this.id, required this.due, required this.completed, });`  <sub>:27</sub>

## ExtendedReminderPlans (class)

- `class ExtendedReminderPlans {`  
  <sub>application/reminder_planning.dart:36</sub>
