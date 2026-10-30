# Dart 基础设施（flutter/lib/infrastructure）

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
native/demo 适配器、运行时与持久化实现。

## 目录

- [infrastructure/bykc_decode.dart](#infrastructurebykcdecodedart) (3)
- [infrastructure/cgyy_decode.dart](#infrastructurecgyydecodedart) (2)
- [infrastructure/demo_graduate_credit_map.dart](#infrastructuredemograduatecreditmapdart) (1)
- [infrastructure/demo_homework_files.dart](#infrastructuredemohomeworkfilesdart) (1)
- [infrastructure/demo_learning.dart](#infrastructuredemolearningdart) (1)
- [infrastructure/demo_library_loans.dart](#infrastructuredemolibraryloansdart) (1)
- [infrastructure/demo_mirror_service.dart](#infrastructuredemomirrorservicedart) (1)
- [infrastructure/graduate_credit_map_payload.dart](#infrastructuregraduatecreditmappayloaddart) (1)
- [infrastructure/graduate_decode.dart](#infrastructuregraduatedecodedart) (1)
- [infrastructure/homework_file_io.dart](#infrastructurehomeworkfileiodart) (6)
- [infrastructure/learning_file_actions.dart](#infrastructurelearningfileactionsdart) (1)
- [infrastructure/learning_snapshot_store.dart](#infrastructurelearningsnapshotstoredart) (4)
- [infrastructure/library_books_decode.dart](#infrastructurelibrarybooksdecodedart) (1)
- [infrastructure/library_holdings_decode.dart](#infrastructurelibraryholdingsdecodedart) (1)
- [infrastructure/library_stats_decode.dart](#infrastructurelibrarystatsdecodedart) (1)
- [infrastructure/local_tasks_decode.dart](#infrastructurelocaltasksdecodedart) (1)
- [infrastructure/maintenance_service.dart](#infrastructuremaintenanceservicedart) (1)
- [infrastructure/mirror_runtime.dart](#infrastructuremirrorruntimedart) (1)
- [infrastructure/native_auth_challenge.dart](#infrastructurenativeauthchallengedart) (2)
- [infrastructure/native_campus_activities.dart](#infrastructurenativecampusactivitiesdart) (2)
- [infrastructure/native_career.dart](#infrastructurenativecareerdart) (2)
- [infrastructure/native_learning.dart](#infrastructurenativelearningdart) (1)
- [infrastructure/native_library_loans.dart](#infrastructurenativelibraryloansdart) (2)
- [infrastructure/native_mirror_service.dart](#infrastructurenativemirrorservicedart) (1)
- [infrastructure/native_reminder_planning.dart](#infrastructurenativereminderplanningdart) (1)
- [infrastructure/native_reminder_platform.dart](#infrastructurenativereminderplatformdart) (1)
- [infrastructure/native_school_rules.dart](#infrastructurenativeschoolrulesdart) (1)
- [infrastructure/notices_decode.dart](#infrastructurenoticesdecodedart) (1)
- [infrastructure/reminder_store.dart](#infrastructurereminderstoredart) (1)
- [infrastructure/serial_reminder_platform.dart](#infrastructureserialreminderplatformdart) (1)
- [infrastructure/shuttle_decode.dart](#infrastructureshuttledecodedart) (1)
- [infrastructure/task_storage.dart](#infrastructuretaskstoragedart) (1)

## infrastructure/bykc_decode.dart

- `BykcCatalogRead decodeBykcCatalog(live.BykcCatalogResponse response) {…}`
  <sub>function · infrastructure/bykc_decode.dart:32</sub>
- `BykcChosenRead decodeBykcChosen(live.BykcChosenResponse response) {…}`
  <sub>function · infrastructure/bykc_decode.dart:50</sub>
- `BykcStatisticsRead decodeBykcStatistics(live.BykcStatisticsResponse response) {…}`
  <sub>function · infrastructure/bykc_decode.dart:78</sub>

## infrastructure/cgyy_decode.dart

- `CgyyLoadRead decodeCgyyLoad(live.CgyyLoadResponse response) {…}` — Projects the five-shape read. Exactly one shape field is non-null.
  <sub>function · infrastructure/cgyy_decode.dart:56</sub>
- `CgyyActionResult decodeCgyyAction(live.CgyyActionResultResponse response) {…}` — Projects the write result. Options/challenge/review stay optional exactly
  <sub>function · infrastructure/cgyy_decode.dart:69</sub>

## infrastructure/demo_graduate_credit_map.dart

- `mixin DemoGraduateCreditMap implements GraduateCreditMapGateway` — Synthetic presentation fixture. Values are explicit, never calculated from
  <sub>mixin · infrastructure/demo_graduate_credit_map.dart:5</sub>
    - `Future<GraduateCreditMapRead> graduateCreditMap({ bool forceRefresh = false, }) async => …`  <sub>:7</sub>

## infrastructure/demo_homework_files.dart

- `class DemoHomeworkFiles implements HomeworkFilesGateway` — Synthetic capability, never reaches a real account or SPOC.
  <sub>class · infrastructure/demo_homework_files.dart:7</sub>
    - `Future<List<HomeworkPendingSubmission>> pendingHomeworkSubmissions({ String? assignmentId, }) async => …`  <sub>:13</sub>
    - `Future<List<HomeworkCapabilityEvidence>> homeworkCapabilities( String assignmentId, ) async => …`  <sub>:17</sub>
    - `Future<HomeworkFileWorkspace> homeworkFiles(String assignmentId) async => …`  <sub>:34</sub>
    - `Future<HomeworkFileReceipt> uploadHomeworkFile( String assignmentId, String name, Uint8List bytes, ) async {…}`  <sub>:54</sub>
    - `Future<MutationResponse> submitHomeworkFile(String handle) async {…}`  <sub>:69</sub>
    - `Future<MutationResponse> reconcileHomeworkFile(String handle) async => …`  <sub>:81</sub>
    - `Future<HomeworkFileDownload> downloadHomeworkFile( String assignmentId, String attachmentId, ) async {…}`  <sub>:87</sub>

## infrastructure/demo_learning.dart

- `mixin DemoLearning` — Synthetic data only: no school requests, account, cache, or native runtime.
  <sub>mixin · infrastructure/demo_learning.dart:9</sub>

## infrastructure/demo_library_loans.dart

- `mixin DemoLibraryLoans implements LibraryLoansGateway`
  <sub>mixin · infrastructure/demo_library_loans.dart:3</sub>
    - `Future<LibraryLoansRead> libraryLoans({int page = 1}) async => …`  <sub>:5</sub>

## infrastructure/demo_mirror_service.dart

- `final class DemoMirrorService`
  <sub>class · infrastructure/demo_mirror_service.dart:35</sub>

## infrastructure/graduate_credit_map_payload.dart

- `GraduateCreditMapRead decodeGraduateCreditMapRead( live.GraduateCreditMapResponse response, ) {…}` — Projects the typed core result. Rust owns the arithmetic.
  <sub>function · infrastructure/graduate_credit_map_payload.dart:6</sub>

## infrastructure/graduate_decode.dart

- `GraduateRead decodeGraduate(live.GraduateResponse response) {…}`
  <sub>function · infrastructure/graduate_decode.dart:5</sub>

## infrastructure/homework_file_io.dart

- `Future<XFile?> pickHomeworkFile() => …`
  <sub>function · infrastructure/homework_file_io.dart:9</sub>
- `Future<FileSaveResult> saveAndOpenSchoolFile( HomeworkFileDownload file, { required bool Function() isCurrent, bool openAfterSave = false, }) => …`
  <sub>function · infrastructure/homework_file_io.dart:11</sub>
- `class SchoolFileSaveService` — Selection and byte commit are separate so a dismissed page/account never
  <sub>class · infrastructure/homework_file_io.dart:24</sub>
    - `const SchoolFileSaveService() : _select = _selectDestination;`  <sub>:25</sub>
    - `Future<FileSaveResult> save( HomeworkFileDownload file, { required bool Function() isCurrent, bool openAfterSave = false, }) async {…}`  <sub>:31</sub>
- `typedef SchoolFileDestinationPicker = Future<SchoolFileDestination?> Function(`
  <sub>typedef · infrastructure/homework_file_io.dart:82</sub>
- `class SchoolFileDestination` — Opaque local selection capability. Production never accepts a caller URI.
  <sub>class · infrastructure/homework_file_io.dart:88</sub>
    - `const SchoolFileDestination({ required this.commit, required this.discard, this.open, });`  <sub>:89</sub>
    - `final Future<void> Function(Uint8List bytes) commit;`  <sub>:94</sub>
    - `final Future<void> Function() discard;`  <sub>:95</sub>
    - `final Future<FileOpenStatus> Function()? open;`  <sub>:96</sub>
- `String safeSchoolFileName(String raw) {…}`
  <sub>function · infrastructure/homework_file_io.dart:99</sub>

## infrastructure/learning_file_actions.dart

- `Future<LearningSavedFile?> saveLearningFile( LearningDownload file, bool Function() isCurrent, ) async {…}` — Learning and homework share only the local byte-save capability, not URLs
  <sub>function · infrastructure/learning_file_actions.dart:10</sub>

## infrastructure/learning_snapshot_store.dart

- `abstract interface class LearningSnapshotStore` — The only disk adapter is Android Keystore AES-GCM. No plaintext fallback.
  <sub>class · infrastructure/learning_snapshot_store.dart:14</sub>
    - `Future<bool> enabled();`  <sub>:16</sub>
    - `Future<void> enable();`  <sub>:17</sub>
    - `Future<Uint8List?> load();`  <sub>:18</sub>
    - `Future<void> save(Uint8List bytes);`  <sub>:19</sub>
    - `Future<void> clear();`  <sub>:20</sub>
- `class AndroidLearningSnapshotStore implements LearningSnapshotStore`
  <sub>class · infrastructure/learning_snapshot_store.dart:23</sub>
    - `static const channel = MethodChannel('cn.edu.buaa.ginkgo/learning-snapshots');`  <sub>:24</sub>
    - `bool get supported => …`  <sub>:27</sub>
    - `Future<bool> enabled() async => …`  <sub>:29</sub>
    - `Future<void> enable() => …`  <sub>:32</sub>
    - `Future<Uint8List?> load() => …`  <sub>:34</sub>
    - `Future<void> save(Uint8List bytes) => …`  <sub>:36</sub>
    - `Future<void> clear() => …`  <sub>:39</sub>
- `class LearningSnapshotCoordinator` — Serializes disk read/commit with clear and account changes. Native commands
  <sub>class · infrastructure/learning_snapshot_store.dart:44</sub>
    - `final Future<Uint8List> Function(String account) export;`  <sub>:51</sub>
    - `final Future<void> Function(String account, Uint8List bytes) restore;`  <sub>:52</sub>
    - `Future<LearningSnapshotStatus> status() => …`  <sub>:63</sub>
    - `Future<LearningSnapshotStatus> setEnabled( String account, bool enabled, ) => …`  <sub>:77</sub>
    - `Future<void> clear() => …`  <sub>:111</sub>
- `mixin NativeLearningSnapshots implements LearningSnapshotGateway`
  <sub>mixin · infrastructure/learning_snapshot_store.dart:181</sub>
    - `Future<LearningSnapshotStatus> learningSnapshotStatus() => …`  <sub>:184</sub>
    - `Future<LearningSnapshotStatus> setLearningSnapshotsEnabled(bool enabled) => …`  <sub>:187</sub>

## infrastructure/library_books_decode.dart

- `BookPageRead decodeBookPage(live.BookPageResponse response) {…}`
  <sub>function · infrastructure/library_books_decode.dart:5</sub>

## infrastructure/library_holdings_decode.dart

- `BookHoldingsRead decodeBookHoldings(live.BookHoldingsResponse response) {…}`
  <sub>function · infrastructure/library_holdings_decode.dart:5</sub>

## infrastructure/library_stats_decode.dart

- `LibraryStatsRead decodeLibraryStats(live.LibraryStatsResponse response) {…}`
  <sub>function · infrastructure/library_stats_decode.dart:5</sub>

## infrastructure/local_tasks_decode.dart

- `LocalTasksRead decodeLocalTasks(live.LocalTasksResponse response) {…}` — Local records are validated by the Rust store on write, so the projection
  <sub>function · infrastructure/local_tasks_decode.dart:7</sub>

## infrastructure/maintenance_service.dart

- `class NativeMaintenanceService implements MaintenanceService`
  <sub>class · infrastructure/maintenance_service.dart:17</sub>
    - `const NativeMaintenanceService();`  <sub>:18</sub>
    - `static const repository = 'https://github.com/JUANWANG-BUAA/ginkgo';`  <sub>:19</sub>
    - `bool get supportsUpdates => …`  <sub>:21</sub>
    - `Future<InstalledVersion> version() async {…}`  <sub>:23</sub>
    - `Future<UpdateResult> checkUpdate(String current) async {…}`  <sub>:29</sub>
    - `Future<bool> openReleases(String? page) async {…}`  <sub>:56</sub>
    - `Future<bool> checkBridge() async {…}`  <sub>:72</sub>
    - `Future<bool> checkStorage() async {…}`  <sub>:78</sub>
    - `Future<bool> checkPublicService(MirrorService service) async {…}`  <sub>:98</sub>
    - `Future<bool> checkVault() => …`  <sub>:107</sub>

## infrastructure/mirror_runtime.dart

- `Future<void> initializeMirrorRuntime() => …` — Load FFI without eagerly constructing the network session.
  <sub>function · infrastructure/mirror_runtime.dart:4</sub>

## infrastructure/native_auth_challenge.dart

- `class NativeAuthChallengeGateway implements AuthChallengeGateway`
  <sub>class · infrastructure/native_auth_challenge.dart:6</sub>
    - `const NativeAuthChallengeGateway();`  <sub>:7</sub>
    - `Future<LoginChallenge> loginChallenge({ String? expectedId, bool refresh = false, }) async {…}`  <sub>:10</sub>
- `LoginChallenge decodeLoginChallenge(live.LoginChallengeResponse response) {…}`
  <sub>function · infrastructure/native_auth_challenge.dart:21</sub>

## infrastructure/native_campus_activities.dart

- `CampusActivitiesRead decodeCampusActivities( live.CampusActivitiesResponse response, ) {…}`
  <sub>function · infrastructure/native_campus_activities.dart:7</sub>
- `mixin NativeCampusActivities implements CampusActivitiesGateway`
  <sub>mixin · infrastructure/native_campus_activities.dart:38</sub>
    - `Future<CampusActivitiesRead> campusActivities({ int page = 1, bool forceRefresh = false, }) async => …`  <sub>:40</sub>

## infrastructure/native_career.dart

- `CareerEventsRead decodeCareerEvents(live.CareerEventsResponse response) {…}`
  <sub>function · infrastructure/native_career.dart:8</sub>
- `mixin NativeCareer implements CareerEventsGateway`
  <sub>mixin · infrastructure/native_career.dart:39</sub>
    - `Future<CareerEventsRead> careerEvents({ required String month, bool forceRefresh = false, }) async => …`  <sub>:41</sub>

## infrastructure/native_learning.dart

- `mixin NativeLearning`
  <sub>mixin · infrastructure/native_learning.dart:122</sub>

## infrastructure/native_library_loans.dart

- `LibraryLoansRead decodeLibraryLoans(live.LibraryLoansResponse response) {…}` — Decode the business projection, never the school OPAC envelope.
  <sub>function · infrastructure/native_library_loans.dart:8</sub>
- `mixin NativeLibraryLoans`
  <sub>mixin · infrastructure/native_library_loans.dart:37</sub>
    - `String libraryLoansPortalUrl() => …`  <sub>:40</sub>
    - `Future<LibraryLoansRead> libraryLoans({int page = 1}) async {…}`  <sub>:43</sub>

## infrastructure/native_mirror_service.dart

- `final class NativeMirrorService`
  <sub>class · infrastructure/native_mirror_service.dart:44</sub>

## infrastructure/native_reminder_planning.dart

- `mixin NativeReminderPlanning implements ReminderPlanningGateway` — Pure Rust command; does not initialize the network runtime.
  <sub>mixin · infrastructure/native_reminder_planning.dart:7</sub>
    - `Future<ExtendedReminderPlans> planReminders({ required List<CourseReminderSeed> courses, required List<TaskReminderSeed> tasks, required int nowMillis, }) async {…}`  <sub>:9</sub>
    - `ExtendedReminderPlans planCheckinHomeworkReminders({ required List<CheckInReminderSeed> checkin, required List<HomeworkReminderSeed> homework, required int nowMillis, }) {…}`  <sub>:57</sub>

## infrastructure/native_reminder_platform.dart

- `class NativeReminderPlatform implements ReminderPlatform`
  <sub>class · infrastructure/native_reminder_platform.dart:6</sub>
    - `const NativeReminderPlatform();`  <sub>:7</sub>
    - `static const channel = MethodChannel('cn.edu.buaa.ginkgo/reminders');`  <sub>:9</sub>
    - `Future<void> replace(List<Map<String, Object>> plans) async {…}`  <sub>:12</sub>

## infrastructure/native_school_rules.dart

- `class NativeSchoolRules implements SchoolRules` — The domain rules through the bridge. Pure commands, no session or network.
  <sub>class · infrastructure/native_school_rules.dart:6</sub>
    - `const NativeSchoolRules();`  <sub>:7</sub>
    - `HomeworkDeadlineStatus homeworkDeadline(String? dueAt, DateTime now) => …`  <sub>:10</sub>
    - `bool checkinWindowOpen( String date, String beginsAt, String endsAt, DateTime now, ) => …`  <sub>:17</sub>

## infrastructure/notices_decode.dart

- `NoticesRead decodeNotices(live.NoticesResponse response) {…}` — Native and demo both cross the bridge as the same typed DTO, so they share
  <sub>function · infrastructure/notices_decode.dart:7</sub>

## infrastructure/reminder_store.dart

- `class FileReminderStore implements ReminderStore` — Stores the existing account-digest-named reminder document atomically.
  <sub>class · infrastructure/reminder_store.dart:10</sub>
    - `final Future<Directory> Function() _directory;`  <sub>:18</sub>
    - `Future<String?> read() => …`  <sub>:43</sub>
    - `Future<void> write(String data) => …`  <sub>:49</sub>

## infrastructure/serial_reminder_platform.dart

- `class SerialReminderPlatform implements ReminderPlatform` — Orders replacements across controller generations sharing one scheduler.
  <sub>class · infrastructure/serial_reminder_platform.dart:4</sub>
    - `Future<void> replace(List<Map<String, Object>> plans) {…}`  <sub>:11</sub>

## infrastructure/shuttle_decode.dart

- `ShuttleTimetableRead decodeShuttleTimetable( live.ShuttleTimetableResponse response, ) {…}`
  <sub>function · infrastructure/shuttle_decode.dart:5</sub>

## infrastructure/task_storage.dart

- `Future<String> localTasksStorageRoot() async => …` — Platform-specific location for the Rust local task store.
  <sub>function · infrastructure/task_storage.dart:4</sub>
