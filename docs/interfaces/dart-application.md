# Dart 应用接口（flutter/lib/application）

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
页面依赖的 gateway、契约与局部应用状态。

## 目录

- [application/auth_challenge.dart](#applicationauthchallengedart) (2)
- [application/busy_gate.dart](#applicationbusygatedart) (1)
- [application/bykc.dart](#applicationbykcdart) (12)
- [application/campus_activities.dart](#applicationcampusactivitiesdart) (4)
- [application/career.dart](#applicationcareerdart) (3)
- [application/cgyy_commands.dart](#applicationcgyycommandsdart) (9)
- [application/checkin_progress.dart](#applicationcheckinprogressdart) (2)
- [application/collection_window.dart](#applicationcollectionwindowdart) (1)
- [application/diagnostic_log.dart](#applicationdiagnosticlogdart) (2)
- [application/environment.dart](#applicationenvironmentdart) (1)
- [application/failure_message.dart](#applicationfailuremessagedart) (2)
- [application/file_actions.dart](#applicationfileactionsdart) (5)
- [application/graduate.dart](#applicationgraduatedart) (8)
- [application/graduate_credit_map.dart](#applicationgraduatecreditmapdart) (9)
- [application/homework_files.dart](#applicationhomeworkfilesdart) (7)
- [application/learning.dart](#applicationlearningdart) (5)
- [application/learning_context.dart](#applicationlearningcontextdart) (3)
- [application/learning_file_actions.dart](#applicationlearningfileactionsdart) (2)
- [application/learning_models.dart](#applicationlearningmodelsdart) (8)
- [application/learning_ports.dart](#applicationlearningportsdart) (1)
- [application/library_books.dart](#applicationlibrarybooksdart) (3)
- [application/library_holdings.dart](#applicationlibraryholdingsdart) (2)
- [application/library_loans.dart](#applicationlibraryloansdart) (5)
- [application/library_stats.dart](#applicationlibrarystatsdart) (5)
- [application/local_tasks.dart](#applicationlocaltasksdart) (7)
- [application/maintenance.dart](#applicationmaintenancedart) (4)
- [application/mirror_service.dart](#applicationmirrorservicedart) (17)
- [application/notices.dart](#applicationnoticesdart) (2)
- [application/platform_actions.dart](#applicationplatformactionsdart) (1)
- [application/query_snapshots.dart](#applicationquerysnapshotsdart) (2)
- [application/refresh_section.dart](#applicationrefreshsectiondart) (2)
- [application/reminder_planning.dart](#applicationreminderplanningdart) (11)
- [application/reminder_platform.dart](#applicationreminderplatformdart) (1)
- [application/reminder_store.dart](#applicationreminderstoredart) (1)
- [application/school_rules.dart](#applicationschoolrulesdart) (1)
- [application/service_capabilities.dart](#applicationservicecapabilitiesdart) (1)
- [application/shuttle.dart](#applicationshuttledart) (7)
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

## application/bykc.dart

- `class BykcSemester`
  <sub>class · application/bykc.dart:6</sub>
    - `const BykcSemester({ required this.id, required this.name, this.start, this.end, });`  <sub>:7</sub>
- `class BykcCourseDetails` — Course enrollment details. Absent values stay null; they are never
  <sub>class · application/bykc.dart:20</sub>
    - `const BykcCourseDetails({ this.start, this.end, this.selectStart, this.selectEnd, this.cancelEnd, this.capacity, this.enrolled, this.campuses = const [], this.summary, this.selected, this.hasSignConfig, });`  <sub>:21</sub>
- `class BykcCourse`
  <sub>class · application/bykc.dart:54</sub>
    - `const BykcCourse({ required this.id, required this.name, this.teacher, this.position, this.category, this.subcategory, this.details, });`  <sub>:55</sub>
    - `String get categoryLabel {…}` — Subcategory wins when present; an empty chain stays unclassified.  <sub>:71</sub>
- `class BykcCatalog` — Catalog view flattened by core: `terms`, `courses` and the projected
  <sub>class · application/bykc.dart:81</sub>
    - `const BykcCatalog({required this.courses, this.currentTerm});`  <sub>:82</sub>
- `class BykcChosenRecord`
  <sub>class · application/bykc.dart:88</sub>
    - `const BykcChosenRecord({ required this.id, required this.course, this.selectedAt, this.checkin, this.passed, this.score, });`  <sub>:89</sub>
    - `String get attendanceLabel => …`  <sub>:104</sub>
    - `String get resultLabel => …`  <sub>:110</sub>
- `class BykcChosenCourses`
  <sub>class · application/bykc.dart:118</sub>
    - `const BykcChosenCourses({this.term, this.courses});`  <sub>:119</sub>
- `class BykcStatisticsEntry`
  <sub>class · application/bykc.dart:125</sub>
    - `const BykcStatisticsEntry({ required this.category, required this.subcategory, required this.requiredCount, required this.completed, });`  <sub>:126</sub>
    - `bool get complete => …`  <sub>:136</sub>
- `class BykcStatistics`
  <sub>class · application/bykc.dart:139</sub>
    - `const BykcStatistics({required this.entries, this.validCourseCount});`  <sub>:140</sub>
- `sealed class BykcPartRead`
  <sub>class · application/bykc.dart:146</sub>
    - `const BykcPartRead();`  <sub>:147</sub>
- `class BykcCatalogRead extends BykcPartRead`
  <sub>class · application/bykc.dart:151</sub>
    - `const BykcCatalogRead({this.data, this.failure});`  <sub>:152</sub>
- `class BykcChosenRead extends BykcPartRead`
  <sub>class · application/bykc.dart:158</sub>
    - `const BykcChosenRead({this.data, this.failure});`  <sub>:159</sub>
- `class BykcStatisticsRead extends BykcPartRead`
  <sub>class · application/bykc.dart:165</sub>
    - `const BykcStatisticsRead({this.data, this.failure});`  <sub>:166</sub>

## application/campus_activities.dart

- `class CampusActivity`
  <sub>class · application/campus_activities.dart:4</sub>
    - `const CampusActivity({ required this.id, required this.title, required this.category, required this.publishedAt, required this.activityTime, required this.place, required this.url, });`  <sub>:5</sub>
- `class CampusActivities`
  <sub>class · application/campus_activities.dart:18</sub>
    - `const CampusActivities({ required this.page, required this.activities, required this.fetchedAt, });`  <sub>:19</sub>
- `class CampusActivitiesRead`
  <sub>class · application/campus_activities.dart:30</sub>
    - `const CampusActivitiesRead({this.data, this.failure});`  <sub>:31</sub>
- `abstract interface class CampusActivitiesGateway implements MirrorEnvironment` — Public campus activities; no login, no writes and no background polling.
  <sub>class · application/campus_activities.dart:37</sub>
    - `Future<CampusActivitiesRead> campusActivities({int page, bool forceRefresh});`  <sub>:38</sub>

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

## application/cgyy_commands.dart

- `sealed class CgyyCommand` — Typed commands for the CGYY write boundary. JSON is produced only by the
  <sub>class · application/cgyy_commands.dart:3</sub>
    - `const CgyyCommand();`  <sub>:4</sub>
    - `Map<String, Object?> toPayload();`  <sub>:6</sub>
- `final class CgyyStatusCommand extends CgyyCommand`
  <sub>class · application/cgyy_commands.dart:9</sub>
    - `const CgyyStatusCommand();`  <sub>:10</sub>
    - `Map<String, Object?> toPayload() => …`  <sub>:13</sub>
- `final class CgyyOptionsCommand extends CgyyCommand`
  <sub>class · application/cgyy_commands.dart:16</sub>
    - `const CgyyOptionsCommand({required this.siteId, required this.date});`  <sub>:17</sub>
    - `Map<String, Object?> toPayload() => …`  <sub>:23</sub>
- `final class CgyyPrepareCommand extends CgyyCommand`
  <sub>class · application/cgyy_commands.dart:30</sub>
    - `const CgyyPrepareCommand(this.draft);`  <sub>:31</sub>
    - `Map<String, Object?> toPayload() => …`  <sub>:36</sub>
- `final class CgyySubmitCommand extends CgyyCommand`
  <sub>class · application/cgyy_commands.dart:42</sub>
    - `const CgyySubmitCommand({ required this.challengeId, required this.x, required this.width, });`  <sub>:43</sub>
    - `Map<String, Object?> toPayload() => …`  <sub>:53</sub>
- `final class CgyyCancelCommand extends CgyyCommand`
  <sub>class · application/cgyy_commands.dart:61</sub>
    - `const CgyyCancelCommand(this.orderId);`  <sub>:62</sub>
    - `Map<String, Object?> toPayload() => …`  <sub>:67</sub>
- `final class CgyyReviewCommand extends CgyyCommand`
  <sub>class · application/cgyy_commands.dart:70</sub>
    - `const CgyyReviewCommand();`  <sub>:71</sub>
    - `Map<String, Object?> toPayload() => …`  <sub>:74</sub>
- `final class CgyyAcknowledgeCommand extends CgyyCommand`
  <sub>class · application/cgyy_commands.dart:77</sub>
    - `const CgyyAcknowledgeCommand(this.reviewId);`  <sub>:78</sub>
    - `Map<String, Object?> toPayload() => …`  <sub>:83</sub>
- `class CgyyBookingDraft` — The booking form values as one snapshot. Missing values stay empty so the
  <sub>class · application/cgyy_commands.dart:91</sub>
    - `const CgyyBookingDraft({ required this.siteId, required this.siteName, required this.date, required this.spaceId, required this.spaceName, required this.timeIds, required this.times, required this.participantCount, required this.purposeId, required this.purposeName, required this.phone, required this.theme, required this.content, required this.joiners, required this.philosophy, required this.offSchool, });`  <sub>:92</sub>
    - `bool get isComplete => …`  <sub>:119</sub>
    - `String get summary => …`  <sub>:133</sub>
    - `Map<String, Object?> toPayload() => …`  <sub>:148</sub>

## application/checkin_progress.dart

- `class CheckinProgressTelemetry` — Optional iClass progress telemetry attached to a check-in read. Local hint
  <sub>class · application/checkin_progress.dart:5</sub>
    - `const CheckinProgressTelemetry({ required this.phase, required this.elapsedSeconds, });`  <sub>:6</sub>
- `class CheckinProgressRead`
  <sub>class · application/checkin_progress.dart:15</sub>
    - `const CheckinProgressRead({this.data, this.failure});`  <sub>:16</sub>

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
    - `String get summary => …`  <sub>:23</sub>
- `class DiagnosticLog extends ChangeNotifier`
  <sub>class · application/diagnostic_log.dart:26</sub>
    - `static final shared = DiagnosticLog();`  <sub>:27</sub>
    - `final List<DiagnosticEntry> entries = [];`  <sub>:28</sub>
    - `void record(FailureCode? failure, {bool showHint = true}) {…}`  <sub>:30</sub>
    - `void dismiss() {…}`  <sub>:52</sub>

## application/environment.dart

- `abstract interface class MirrorEnvironment` — Which backing environment a gateway is running against.
  <sub>class · application/environment.dart:5</sub>

## application/failure_message.dart

- `String failureMessage(FailureCode? code) {…}` — Maps typed Rust domain failure codes to human-readable Chinese error messages.
  <sub>function · application/failure_message.dart:5</sub>
- `String failureAdvice({required bool hasStaleValue, FailureCode? failure}) {…}` — The advice line shown under a failed read.
  <sub>function · application/failure_message.dart:34</sub>

## application/file_actions.dart

- `typedef HomeworkFilePicker = Future<XFile?> Function();` — Local file actions the presentation layer needs. The composition root binds
  <sub>typedef · application/file_actions.dart:9</sub>
- `typedef HomeworkFileSave = Future<FileSaveResult> Function(` — Saves the file the user chose. The commit is the authorization point: a
  <sub>typedef · application/file_actions.dart:13</sub>
- `enum FileSaveStatus { saved, cancelled, stale }`
  <sub>enum · application/file_actions.dart:19</sub>
- `enum FileOpenStatus { opened, unsupported, unavailable, stale }`
  <sub>enum · application/file_actions.dart:21</sub>
- `class FileSaveResult` — Contains a local capability only, never a school URL, credential or raw URI.
  <sub>class · application/file_actions.dart:24</sub>
    - `final Future<FileOpenStatus> Function()? _opener;`  <sub>:36</sub>
    - `bool get canOpen => …`  <sub>:37</sub>
    - `Future<FileOpenStatus> open() async => …`  <sub>:38</sub>

## application/graduate.dart

- `class GraduateRow` — Presentation values projected by Rust; no upstream fields or status inference.
  <sub>class · application/graduate.dart:4</sub>
    - `const GraduateRow({ required this.title, required this.detail, required this.isCourse, this.completed, this.credit, this.semester, });`  <sub>:5</sub>
- `class GraduateProgress` — Credit requirement projection (camelCase). Absent values stay null;
  <sub>class · application/graduate.dart:23</sub>
    - `const GraduateProgress({this.requiredCredits, this.earned, this.pending});`  <sub>:24</sub>
    - `double? get earnedRatio {…}` — Recognized share of the requirement. Null while either side is unknown:  <sub>:30</sub>
    - `double get pendingRatio {…}` — Pending share of the requirement. Pending credits are never counted as  <sub>:39</sub>
    - `num? get remaining {…}` — Credits still missing; null while either side is unknown.  <sub>:47</sub>
- `class GraduateSection`
  <sub>class · application/graduate.dart:55</sub>
    - `const GraduateSection({ required this.title, required this.rows, this.progress, });`  <sub>:56</sub>
- `class GraduateCourseEntry`
  <sub>class · application/graduate.dart:67</sub>
    - `const GraduateCourseEntry(this.section, this.row);`  <sub>:68</sub>
- `enum GraduateCourseFilter`
  <sub>enum · application/graduate.dart:73</sub>
    - `const GraduateCourseFilter(this.label);`  <sub>:79</sub>
    - `bool accepts(GraduateRow row) => …`  <sub>:82</sub>
- `enum GraduateView { credits, courses, profile }` — The three lenses on the graduate page.
  <sub>enum · application/graduate.dart:91</sub>
- `class GraduateReport` — Full report envelope: sections plus the school's own notice line.
  <sub>class · application/graduate.dart:94</sub>
    - `const GraduateReport({required this.sections, this.notice});`  <sub>:95</sub>
- `class GraduateRead`
  <sub>class · application/graduate.dart:101</sub>
    - `const GraduateRead({this.data, this.failure});`  <sub>:102</sub>

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
    - `String get message => …`  <sub>:58</sub>
- `enum GraduateCreditState { unknown, noMinimum, incomplete, requirementMet }`
  <sub>enum · application/graduate_credit_map.dart:69</sub>
- `class GraduateCreditMetrics`
  <sub>class · application/graduate_credit_map.dart:71</sub>
    - `const GraduateCreditMetrics({ required this.state, this.requiredCredits, this.earned, this.pending, this.remaining, this.ratio, });`  <sub>:72</sub>
    - `String get stateLabel => …`  <sub>:83</sub>
- `class GraduateCreditRow`
  <sub>class · application/graduate_credit_map.dart:91</sub>
    - `const GraduateCreditRow({ required this.title, required this.detail, required this.isCourse, this.completed, this.credit, this.semester, });`  <sub>:92</sub>
- `class GraduateCreditNode`
  <sub>class · application/graduate_credit_map.dart:107</sub>
- `class GraduateCreditMap`
  <sub>class · application/graduate_credit_map.dart:120</sub>
    - `bool get isEmpty => …`  <sub>:129</sub>

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
  <sub>class · application/learning.dart:5</sub>
    - `Future<LearningRead<List<LearningCourse>>> learningCourses({ bool forceRefresh = false, });`  <sub>:6</sub>
- `abstract interface class CourseAnnouncementGateway`
  <sub>class · application/learning.dart:11</sub>
    - `Future<LearningRead<List<CourseAnnouncement>>> courseAnnouncements( String course, { bool forceRefresh = false, });`  <sub>:12</sub>
    - `Future<CourseAnnouncementDetail> courseAnnouncementDetail( String course, String id, );`  <sub>:16</sub>
    - `Future<LearningDownload> courseAnnouncementAttachment( String course, String id, String file, );`  <sub>:20</sub>
- `abstract interface class CourseResourceGateway`
  <sub>class · application/learning.dart:27</sub>
    - `Future<LearningRead<CourseResourcePage>> courseResources( String course, { String? folder, int page = 1, bool forceRefresh = false, });`  <sub>:28</sub>
    - `Future<LearningDownload> courseResourceDownload( String course, String id, { String? folder, int page = 1, });`  <sub>:34</sub>
- `abstract interface class CourseAssessmentGateway`
  <sub>class · application/learning.dart:42</sub>
    - `Future<LearningRead<List<CourseAssessment>>> courseAssessments( String course, { bool forceRefresh = false, });`  <sub>:43</sub>
- `class LearningRead<T>` — An old successful value and a refresh failure must travel together.
  <sub>class · application/learning.dart:50</sub>
    - `const LearningRead(this.data, {this.stale = false, this.failure});`  <sub>:51</sub>

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

## application/library_books.dart

- `class BookHit`
  <sub>class · application/library_books.dart:5</sub>
    - `const BookHit({ required this.bibId, required this.title, required this.author, required this.publisher, required this.year, required this.callno, required this.isbn, this.itemsAvailable, this.itemCount, });`  <sub>:6</sub>
    - `String get displayTitle => …`  <sub>:23</sub>
    - `String get factLine => …`  <sub>:25</sub>
- `class BookPage`
  <sub>class · application/library_books.dart:29</sub>
    - `const BookPage({ required this.page, required this.pageSize, required this.total, required this.items, required this.hasMore, this.actualTotal, });`  <sub>:30</sub>
- `class BookPageRead`
  <sub>class · application/library_books.dart:45</sub>
    - `const BookPageRead({this.data, this.failure});`  <sub>:46</sub>

## application/library_holdings.dart

- `class BookHolding` — One physical copy. Status stays the school's own text; it is never turned
  <sub>class · application/library_holdings.dart:5</sub>
    - `const BookHolding({ required this.callNo, required this.barCode, required this.library, required this.location, required this.status, });`  <sub>:6</sub>
    - `String get place => …`  <sub>:16</sub>
- `class BookHoldingsRead`
  <sub>class · application/library_holdings.dart:20</sub>
    - `const BookHoldingsRead({this.data, this.failure});`  <sub>:21</sub>

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

## application/library_stats.dart

- `class CountPair`
  <sub>class · application/library_stats.dart:5</sub>
    - `const CountPair({required this.available, required this.total});`  <sub>:6</sub>
- `class ReadingRoom`
  <sub>class · application/library_stats.dart:10</sub>
    - `const ReadingRoom({required this.name, required this.people});`  <sub>:11</sub>
- `class LibraryCampusStats`
  <sub>class · application/library_stats.dart:16</sub>
    - `const LibraryCampusStats({ required this.id, required this.name, required this.people, required this.readingRooms, this.seats, this.studyRooms, this.lockers, });`  <sub>:17</sub>
- `class LibraryStatsSnapshot`
  <sub>class · application/library_stats.dart:35</sub>
    - `const LibraryStatsSnapshot({ required this.campuses, required this.fetchedAt, required this.fromCache, });`  <sub>:36</sub>
- `class LibraryStatsRead`
  <sub>class · application/library_stats.dart:49</sub>
    - `const LibraryStatsRead({this.data, this.failure});`  <sub>:50</sub>

## application/local_tasks.dart

- `class LocalTaskRecord` — Device-local personal task. Completion never changes a school assignment.
  <sub>class · application/local_tasks.dart:6</sub>
    - `const LocalTaskRecord({ required this.id, required this.title, required this.due, required this.completed, this.sourceAssignmentId, });`  <sub>:7</sub>
- `bool isLocalTaskDue(String value) {…}`
  <sub>function · application/local_tasks.dart:24</sub>
- `String localTaskDueFromHomework(String? value) {…}` — School wall-clock timestamps have no offset; explicitly use Beijing time.
  <sub>function · application/local_tasks.dart:39</sub>
- `String localTaskDueLabel(String due) {…}`
  <sub>function · application/local_tasks.dart:51</sub>
- `class LocalTasksRead`
  <sub>class · application/local_tasks.dart:61</sub>
    - `const LocalTasksRead({this.data, this.failure});`  <sub>:62</sub>
- `abstract interface class LocalTaskGateway implements MirrorEnvironment`
  <sub>class · application/local_tasks.dart:67</sub>
    - `Future<LocalTasksRead> editTasks({ required String root, required String action, String? id, String? title, String? due, bool? completed, });`  <sub>:68</sub>
- `Future<List<LocalTaskRecord>> editLocalTasks( LocalTaskGateway service, { required String root, required String action, String? id, String? title, String? due, bool? completed, }) async {…}` — The only JSON decoding path shared by Today, Tasks and homework linking.
  <sub>function · application/local_tasks.dart:79</sub>

## application/maintenance.dart

- `class InstalledVersion` — The update and self-check capability the settings pages use.
  <sub>class · application/maintenance.dart:7</sub>
    - `const InstalledVersion(this.version, this.build);`  <sub>:8</sub>
    - `String get label => …`  <sub>:10</sub>
- `class AndroidDownload`
  <sub>class · application/maintenance.dart:13</sub>
    - `const AndroidDownload({ required this.version, required this.name, required this.url, required this.apiUrl, required this.size, required this.sha256, });`  <sub>:14</sub>
    - `bool get isValid => …`  <sub>:24</sub>
- `class UpdateResult`
  <sub>class · application/maintenance.dart:38</sub>
    - `const UpdateResult({ required this.latest, required this.available, required this.apkAvailable, this.pageUrl, this.notes, this.download, });`  <sub>:39</sub>
    - `String get headline => …`  <sub>:50</sub>
- `abstract interface class MaintenanceService`
  <sub>class · application/maintenance.dart:59</sub>
    - `Future<bool> checkPublicService(MirrorService service);` — Network check is deliberately separate from the local checks. A cached  <sub>:65</sub>
    - `Future<InstalledVersion> version();`  <sub>:66</sub>
    - `Future<UpdateResult> checkUpdate(String current);`  <sub>:67</sub>
    - `Future<bool> openReleases(String? page);`  <sub>:68</sub>
    - `Future<bool> checkBridge();`  <sub>:69</sub>
    - `Future<bool> checkStorage();`  <sub>:70</sub>
    - `Future<bool> checkVault();`  <sub>:71</sub>

## application/mirror_service.dart

- `abstract interface class MirrorService` — Page-facing capabilities. Tests and alternative adapters need no native runtime.
  <sub>class · application/mirror_service.dart:20</sub>
- `abstract interface class CampusCardGateway implements MirrorEnvironment`
  <sub>class · application/mirror_service.dart:30</sub>
    - `Future<CampusCardBalanceResponse> campusCardBalance();`  <sub>:31</sub>
- `abstract interface class StudentServiceLinksGateway` — Public official destinations only; does not read or transmit account data.
  <sub>class · application/mirror_service.dart:35</sub>
    - `String? studentServiceUrl(String id);`  <sub>:36</sub>
- `abstract interface class CareerEventsGateway implements MirrorEnvironment` — Public career-calendar reads; no login and no background refresh.
  <sub>class · application/mirror_service.dart:40</sub>
    - `Future<CareerEventsRead> careerEvents({ required String month, bool forceRefresh = false, });`  <sub>:41</sub>
- `abstract interface class SessionGateway implements MirrorEnvironment`
  <sub>class · application/mirror_service.dart:47</sub>
    - `Future<SessionResponse> restoreSession();`  <sub>:48</sub>
    - `Future<SessionResponse> login({ required String account, required String password, String? captcha, required bool remember, });`  <sub>:50</sub>
    - `Future<SessionResponse> signOut();`  <sub>:57</sub>
    - `Future<SessionResponse> setRoute(RouteChoice route);`  <sub>:59</sub>
    - `Future<bool> clearCache();`  <sub>:61</sub>
    - `Future<bool> verifyBridgeContract();`  <sub>:63</sub>
- `abstract interface class AcademicGateway implements MirrorEnvironment`
  <sub>class · application/mirror_service.dart:66</sub>
    - `Future<QueryDates> dates(String instant);`  <sub>:67</sub>
    - `Future<ClassroomResponse> classrooms(DemoScope scope, ClassroomQuery query);`  <sub>:69</sub>
    - `Future<RuleExamples> rules();`  <sub>:71</sub>
    - `Future<ScheduleResponse> schedule({ String? termId, int? week, bool forceRefresh = false, });`  <sub>:73</sub>
    - `Future<GradeTermsResponse> gradeTerms();`  <sub>:79</sub>
    - `Future<GradeResponse> grades({String? termCode, bool forceRefresh = false});`  <sub>:81</sub>
    - `Future<TodayResponse> today({bool forceRefresh = false});`  <sub>:83</sub>
    - `Future<HomeworkResponse> homework({bool forceRefresh = false});`  <sub>:85</sub>
    - `Future<HomeworkDetailResponse> homeworkDetail( String assignmentId, { bool forceRefresh = false, });`  <sub>:87</sub>
- `abstract interface class CheckInGateway implements MirrorEnvironment`
  <sub>class · application/mirror_service.dart:93</sub>
    - `Future<CheckInResponse> checkin({bool forceRefresh = false});`  <sub>:94</sub>
    - `Future<CheckInResponse> checkinOnDate( String date, { bool forceRefresh = false, });`  <sub>:96</sub>
    - `Future<MutationResponse> submitCheckin(String courseId);`  <sub>:101</sub>
    - `Future<CheckinProgressRead> checkinProgress();`  <sub>:103</sub>
- `abstract interface class LibrarySeatingGateway implements MirrorEnvironment`
  <sub>class · application/mirror_service.dart:106</sub>
    - `Future<LibraryStatsRead> libraryStats({bool forceRefresh = false});`  <sub>:107</sub>
    - `Future<MutationResponse> reserveLibrarySeat({ required String areaId, required String seatId, required LibrarySlot slot, });`  <sub>:109</sub>
    - `Future<MutationResponse> performLibraryAction( String bookingId, String action, );`  <sub>:115</sub>
    - `Future<LibraryVenuesResponse> libraryVenues({bool forceRefresh = false});`  <sub>:120</sub>
    - `Future<LibraryAreasResponse> libraryAreas(String libraryId);`  <sub>:122</sub>
    - `Future<LibrarySlotsResponse> librarySlots(String areaId);`  <sub>:124</sub>
    - `Future<LibrarySeatsResponse> librarySeats({ required String areaId, required LibrarySlot slot, });`  <sub>:126</sub>
    - `Future<LibraryBookingsResponse> libraryBookings({bool forceRefresh = false});`  <sub>:131</sub>
    - `Future<LibraryHistoryResponse> libraryHistory( int page, { bool forceRefresh = false, });`  <sub>:133</sub>
- `abstract interface class LibraryCatalogGateway implements MirrorEnvironment`
  <sub>class · application/mirror_service.dart:139</sub>
    - `Future<BookPageRead> libraryBooks({ required String query, required int page, String sort, bool descending, });` — Public OPAC search. Anonymous and read-only; never personal records.  <sub>:142</sub>
    - `Future<BookHoldingsRead> libraryHoldings(String bibId);` — Public holdings for one bib id; the school's nested JSON stays in Rust.  <sub>:150</sub>
- `abstract interface class LibraryGateway`
  <sub>class · application/mirror_service.dart:153</sub>
- `abstract interface class BykcGateway implements MirrorEnvironment`
  <sub>class · application/mirror_service.dart:156</sub>
    - `Future<BykcPartRead> bykcPart(BykcPart part, {bool forceRefresh = false});`  <sub>:157</sub>
- `abstract interface class GraduateGateway implements MirrorEnvironment`
  <sub>class · application/mirror_service.dart:160</sub>
    - `Future<GraduateRead> graduatePart({ required bool report, required bool forceRefresh, });`  <sub>:161</sub>
- `abstract interface class NoticeGateway implements MirrorEnvironment`
  <sub>class · application/mirror_service.dart:167</sub>
    - `Future<NoticesRead> notices({bool forceRefresh = false});`  <sub>:168</sub>
- `abstract interface class CgyyGateway implements MirrorEnvironment`
  <sub>class · application/mirror_service.dart:171</sub>
    - `Future<CgyyLoadRead> cgyy({ required String kind, required int siteId, required String date, required bool forceRefresh, });`  <sub>:172</sub>
- `abstract interface class CampusGateway`
  <sub>class · application/mirror_service.dart:180</sub>
- `abstract interface class CgyyBookingGateway` — Separate capability: read-only adapters never gain writes implicitly.
  <sub>class · application/mirror_service.dart:184</sub>
    - `Future<CgyyActionResult> executeCgyy(CgyyCommand command);`  <sub>:185</sub>
- `enum BykcPart { catalog, chosen, statistics }`
  <sub>enum · application/mirror_service.dart:188</sub>

## application/notices.dart

- `class Notice` — One public notice from the school news site. The publish date is never a
  <sub>class · application/notices.dart:5</sub>
    - `const Notice({ required this.title, required this.summary, required this.publishedAt, required this.url, });`  <sub>:6</sub>
- `class NoticesRead`
  <sub>class · application/notices.dart:16</sub>
    - `const NoticesRead({this.data, this.failure});`  <sub>:17</sub>

## application/platform_actions.dart

- `class PlatformActions` — The platform actions the presentation layer needs.
  <sub>class · application/platform_actions.dart:11</sub>
    - `const PlatformActions({ this.learningFileSaver, this.homeworkFilePicker, this.homeworkFileSave, this.maintenance, });`  <sub>:12</sub>

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
  <sub>class · application/refresh_section.dart:8</sub>
    - `const SectionResult({this.value, this.error, this.failure});`  <sub>:9</sub>
- `class RefreshSection<T> extends ChangeNotifier` — Independent section refreshes preserve content and join overlapping reads.
  <sub>class · application/refresh_section.dart:21</sub>
    - `bool loading = false;`  <sub>:37</sub>
    - `void invalidate() => …` — Drops every in-flight read at its next await: call when the account or  <sub>:47</sub>
    - `Future<void> refresh( Future<SectionResult<T>> Function() read, { required String fallbackError, bool force = false, }) {…}` — A plain refresh joins the in-flight read. A forced refresh is never  <sub>:52</sub>
    - `void dispose() {…}`  <sub>:148</sub>

## application/reminder_planning.dart

- `class ReminderPlan` — One scheduled reminder. The domain decides when a reminder is due; this
  <sub>class · application/reminder_planning.dart:6</sub>
    - `const ReminderPlan({ required this.key, required this.group, required this.at, required this.expires, });`  <sub>:7</sub>
- `abstract interface class ReminderPlanningGateway` — Typed, local-only business capability. No school payload or platform API.
  <sub>class · application/reminder_planning.dart:18</sub>
    - `Future<ExtendedReminderPlans> planReminders({ required List<CourseReminderSeed> courses, required List<TaskReminderSeed> tasks, required int nowMillis, });`  <sub>:19</sub>
    - `ExtendedReminderPlans planCheckinHomeworkReminders({ required List<CheckInReminderSeed> checkin, required List<HomeworkReminderSeed> homework, required int nowMillis, });` — Plans the check-in and assignment reminders. The rule lives in the  <sub>:28</sub>
- `class CourseReminderSeed`
  <sub>class · application/reminder_planning.dart:35</sub>
    - `const CourseReminderSeed({ required this.id, required this.weekStart, required this.day, required this.startsAt, required this.endsAt, });`  <sub>:36</sub>
- `class TaskReminderSeed`
  <sub>class · application/reminder_planning.dart:47</sub>
    - `const TaskReminderSeed({ required this.id, required this.due, required this.completed, });`  <sub>:48</sub>
- `class ExtendedReminderPlans`
  <sub>class · application/reminder_planning.dart:57</sub>
- `List<CourseReminderSeed> courseReminderSeeds(ScheduleResponse data) {…}`
  <sub>function · application/reminder_planning.dart:68</sub>
- `List<TaskReminderSeed> taskReminderSeeds(Iterable<LocalTaskRecord> data) => …`
  <sub>function · application/reminder_planning.dart:84</sub>
- `List<CheckInReminderSeed> checkinReminderSeeds( String date, Iterable<CheckInCourse> courses, ) => …` — The check-in sessions of one queried day. The domain decides which of them
  <sub>function · application/reminder_planning.dart:91</sub>
- `List<HomeworkReminderSeed> homeworkReminderSeeds( Iterable<HomeworkItem> items, ) => …` — The assignments whose deadline may still be pending.
  <sub>function · application/reminder_planning.dart:109</sub>
- `class CheckInReminderSeed` — A check-in session that may still need a reminder.
  <sub>class · application/reminder_planning.dart:121</sub>
    - `const CheckInReminderSeed({ required this.id, required this.date, required this.beginsAt, required this.endsAt, required this.notSigned, required this.conflicting, required this.mergedRecordCount, this.signInAllowed, });`  <sub>:122</sub>
- `class HomeworkReminderSeed` — A school assignment that may still need a deadline reminder.
  <sub>class · application/reminder_planning.dart:146</sub>
    - `const HomeworkReminderSeed({ required this.id, required this.dueAt, required this.pending, });`  <sub>:147</sub>

## application/reminder_platform.dart

- `abstract interface class ReminderPlatform` — System notification scheduling, independent of the platform channel.
  <sub>class · application/reminder_platform.dart:2</sub>
    - `Future<void> replace(List<Map<String, Object>> plans);`  <sub>:3</sub>

## application/reminder_store.dart

- `abstract interface class ReminderStore` — Account-scoped persistence for reminder preferences and read receipts.
  <sub>class · application/reminder_store.dart:4</sub>
    - `Future<String?> read();`  <sub>:5</sub>
    - `Future<void> write(String data);`  <sub>:6</sub>

## application/school_rules.dart

- `abstract interface class SchoolRules` — The school rules the presentation layer needs. The domain owns them; a page
  <sub>class · application/school_rules.dart:8</sub>
    - `HomeworkDeadlineStatus homeworkDeadline(String? dueAt, DateTime now);` — Classify a school deadline against the Beijing wall clock.  <sub>:10</sub>
    - `bool checkinWindowOpen( String date, String beginsAt, String endsAt, DateTime now, );` — Whether a check-in session accepts a sign-in at `now`.  <sub>:13</sub>

## application/service_capabilities.dart

- `class ServiceCapabilities` — Optional capabilities of the injected service, resolved once.
  <sub>class · application/service_capabilities.dart:15</sub>
    - `const ServiceCapabilities({ this.academic, this.careerEvents, this.campusActivities, this.courseAnnouncement, this.courseAssessment, this.courseLearningContext, this.courseResource, this.cgyyBooking, this.graduateCreditMap, this.learningCourse, this.learningSnapshots, this.libraryLoans, this.libraryLoansOfficial, this.campusCard, this.reminderPlanning, this.studentServiceLinks, });`  <sub>:16</sub>
    - `static ServiceCapabilities resolve(MirrorService service) => …` — The composition root resolves every optional capability exactly once, so  <sub>:84</sub>

## application/shuttle.dart

- `class ShuttleRun` — One scheduled departure as printed by the school.
  <sub>class · application/shuttle.dart:7</sub>
    - `const ShuttleRun({ required this.index, required this.time, required this.capacity, });`  <sub>:8</sub>
    - `int? get minuteOfDay {…}` — Minutes past midnight, or null when the printed time is not `H:mm`.  <sub>:19</sub>
- `class ShuttleSection` — One direction pair under a validity label such as "星期一至星期五".
  <sub>class · application/shuttle.dart:30</sub>
    - `const ShuttleSection({ required this.label, required this.left, required this.right, });`  <sub>:31</sub>
    - `bool appliesToday(int weekday) {…}` — Published validity labels name weekdays rather than dates. Only labels  <sub>:43</sub>
- `class ShuttleTable` — One published table: two directions plus their dated sections.
  <sub>class · application/shuttle.dart:86</sub>
    - `const ShuttleTable({ required this.left, required this.right, required this.sections, });`  <sub>:87</sub>
- `class ShuttleTimetable`
  <sub>class · application/shuttle.dart:97</sub>
    - `const ShuttleTimetable({ required this.tables, required this.source, required this.liveSource, });`  <sub>:98</sub>
    - `List<ShuttleDeparture> todayRuns(DateTime clock) {…}` — Flattens every published run that applies today. Duplicate rows across  <sub>:110</sub>
- `class ShuttleDeparture` — A today-applicable departure with its direction resolved from the table.
  <sub>class · application/shuttle.dart:147</sub>
    - `const ShuttleDeparture({ required this.direction, required this.time, required this.minutes, required this.capacity, });`  <sub>:148</sub>
- `class ShuttleTimetableRead`
  <sub>class · application/shuttle.dart:161</sub>
    - `const ShuttleTimetableRead({this.data, this.failure});`  <sub>:162</sub>
- `abstract interface class ShuttleGateway implements MirrorEnvironment`
  <sub>class · application/shuttle.dart:167</sub>
    - `Future<ShuttleTimetableRead> shuttleTimetable();` — Published shuttle timetable (official page). No live seats, no ticketing.  <sub>:169</sub>

## application/task_storage_scope.dart

- `typedef TaskStorageRoot = Future<String> Function();` — Resolves the local task directory without exposing a platform plugin to pages.
  <sub>typedef · application/task_storage_scope.dart:4</sub>
- `class TaskStorageScope extends InheritedWidget`
  <sub>class · application/task_storage_scope.dart:6</sub>
    - `const TaskStorageScope({ super.key, required this.resolve, required super.child, });`  <sub>:7</sub>
    - `static TaskStorageRoot read(BuildContext context) {…}`  <sub>:15</sub>
    - `bool updateShouldNotify(TaskStorageScope oldWidget) => …`  <sub>:22</sub>
