# Dart 基础设施（flutter/lib/infrastructure）

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
native/demo 适配器、运行时与持久化实现。

## 目录

- [infrastructure/demo_graduate_credit_map.dart](#infrastructuredemograduatecreditmapdart) (1)
- [infrastructure/demo_homework_files.dart](#infrastructuredemohomeworkfilesdart) (1)
- [infrastructure/demo_learning.dart](#infrastructuredemolearningdart) (1)
- [infrastructure/demo_library_loans.dart](#infrastructuredemolibraryloansdart) (1)
- [infrastructure/demo_mirror_service.dart](#infrastructuredemomirrorservicedart) (1)
- [infrastructure/homework_file_io.dart](#infrastructurehomeworkfileiodart) (8)
- [infrastructure/learning_snapshot_store.dart](#infrastructurelearningsnapshotstoredart) (4)
- [infrastructure/maintenance_service.dart](#infrastructuremaintenanceservicedart) (4)
- [infrastructure/native_auth_challenge.dart](#infrastructurenativeauthchallengedart) (1)
- [infrastructure/native_campus_activities.dart](#infrastructurenativecampusactivitiesdart) (1)
- [infrastructure/native_career.dart](#infrastructurenativecareerdart) (1)
- [infrastructure/native_learning.dart](#infrastructurenativelearningdart) (1)
- [infrastructure/native_library_loans.dart](#infrastructurenativelibraryloansdart) (1)
- [infrastructure/native_mirror_service.dart](#infrastructurenativemirrorservicedart) (1)
- [infrastructure/native_reminder_planning.dart](#infrastructurenativereminderplanningdart) (1)

## infrastructure/demo_graduate_credit_map.dart

- `mixin DemoGraduateCreditMap implements GraduateCreditMapGateway` — Synthetic presentation fixture. Values are explicit, never calculated from
  <sub>mixin · infrastructure/demo_graduate_credit_map.dart:5</sub>
    - `Future<GraduateCreditMapRead> graduateCreditMap( {…}`  <sub>:7</sub>

## infrastructure/demo_homework_files.dart

- `class DemoHomeworkFiles implements HomeworkFilesGateway` — Synthetic capability, never reaches a real account or SPOC.
  <sub>class · infrastructure/demo_homework_files.dart:7</sub>
    - `Future<List<HomeworkPendingSubmission>> pendingHomeworkSubmissions( {…}`  <sub>:13</sub>
    - `Future<List<HomeworkCapabilityEvidence>> homeworkCapabilities( String assignmentId, ) a … ted', reason: '文本作答尚未接入，请前往官网', evidence: 'synthetic', ), ];`  <sub>:17</sub>
    - `Future<HomeworkFileWorkspace> homeworkFiles(String assignmentId) async => HomeworkFileW … count: _submitted && _assignment == assignmentId ? 1 : 0, );`  <sub>:34</sub>
    - `Future<HomeworkFileReceipt> uploadHomeworkFile( String assignmentId, String name, Uint8List bytes, ) async {…}`  <sub>:54</sub>
    - `Future<MutationResponse> submitHomeworkFile(String handle) async {…}`  <sub>:69</sub>
    - `Future<MutationResponse> reconcileHomeworkFile(String handle) async => MutationResponse … ? 'accepted' : 'notSubmitted', message: '演示回查（未访问学校系统）', );`  <sub>:81</sub>
    - `Future<HomeworkFileDownload> downloadHomeworkFile( String assignmentId, String attachmentId, ) async {…}`  <sub>:87</sub>

## infrastructure/demo_learning.dart

- `mixin DemoLearning` — Synthetic data only: no school requests, account, cache, or native runtime.
  <sub>mixin · infrastructure/demo_learning.dart:9</sub>

## infrastructure/demo_library_loans.dart

- `mixin DemoLibraryLoans implements LibraryLoansGateway`
  <sub>mixin · infrastructure/demo_library_loans.dart:3</sub>
    - `Future<LibraryLoansRead> libraryLoans( {…}`  <sub>:5</sub>

## infrastructure/demo_mirror_service.dart

- `final class DemoMirrorService`
  <sub>class · infrastructure/demo_mirror_service.dart:17</sub>

## infrastructure/homework_file_io.dart

- `typedef HomeworkFilePicker = Future<XFile?> Function();`
  <sub>typedef · infrastructure/homework_file_io.dart:8</sub>
- `typedef HomeworkFileSaver = Future<void> Function(HomeworkFileDownload file);`
  <sub>typedef · infrastructure/homework_file_io.dart:9</sub>
- `enum FileSaveStatus { saved, cancelled, stale }`
  <sub>enum · infrastructure/homework_file_io.dart:11</sub>
- `enum FileOpenStatus { opened, unsupported, unavailable, stale }`
  <sub>enum · infrastructure/homework_file_io.dart:13</sub>
- `class FileSaveResult` — Contains a local capability only, never a school URL, credential or raw URI.
  <sub>class · infrastructure/homework_file_io.dart:16</sub>
    - `final Future<FileOpenStatus> Function()? _opener;`  <sub>:28</sub>
    - `bool get canOpen => status == FileSaveStatus.saved && _opener != null;`  <sub>:29</sub>
    - `Future<FileOpenStatus> open() async => await _opener?.call() ?? FileOpenStatus.unsupported;`  <sub>:30</sub>
- `class SchoolFileSaveService` — Selection and byte commit are separate so a dismissed page/account never
  <sub>class · infrastructure/homework_file_io.dart:49</sub>
    - `const SchoolFileSaveService() : _select = _selectDestination;`  <sub>:50</sub>
    - `Future<FileSaveResult> save( HomeworkFileDownload file, {…}`  <sub>:56</sub>
- `typedef SchoolFileDestinationPicker = Future<SchoolFileDestination?> Function(`
  <sub>typedef · infrastructure/homework_file_io.dart:107</sub>
- `class SchoolFileDestination` — Opaque local selection capability. Production never accepts a caller URI.
  <sub>class · infrastructure/homework_file_io.dart:113</sub>
    - `const SchoolFileDestination( {…}`  <sub>:114</sub>
    - `final Future<void> Function(Uint8List bytes) commit;`  <sub>:119</sub>
    - `final Future<void> Function() discard;`  <sub>:120</sub>
    - `final Future<FileOpenStatus> Function()? open;`  <sub>:121</sub>

## infrastructure/learning_snapshot_store.dart

- `abstract interface class LearningSnapshotStore` — The only disk adapter is Android Keystore AES-GCM. No plaintext fallback.
  <sub>class · infrastructure/learning_snapshot_store.dart:12</sub>
    - `Future<bool> enabled();`  <sub>:14</sub>
    - `Future<void> enable();`  <sub>:15</sub>
    - `Future<Uint8List?> load();`  <sub>:16</sub>
    - `Future<void> save(Uint8List bytes);`  <sub>:17</sub>
    - `Future<void> clear();`  <sub>:18</sub>
- `class AndroidLearningSnapshotStore implements LearningSnapshotStore`
  <sub>class · infrastructure/learning_snapshot_store.dart:21</sub>
    - `static const channel = MethodChannel('cn.edu.buaa.ginkgo/learning-snapshots');`  <sub>:22</sub>
    - `bool get supported => !kReleaseMode && Platform.isAndroid;`  <sub>:25</sub>
    - `Future<bool> enabled() async => await channel.invokeMethod<bool>('enabled') ?? false;`  <sub>:27</sub>
    - `Future<void> enable() => channel.invokeMethod<void>('enable');`  <sub>:30</sub>
    - `Future<Uint8List?> load() => channel.invokeMethod<Uint8List>('load');`  <sub>:32</sub>
    - `Future<void> save(Uint8List bytes) => channel.invokeMethod<void>('save', bytes);`  <sub>:34</sub>
    - `Future<void> clear() => channel.invokeMethod<void>('clear');`  <sub>:37</sub>
- `class LearningSnapshotCoordinator` — Serializes disk read/commit with clear and account changes. Native commands
  <sub>class · infrastructure/learning_snapshot_store.dart:42</sub>
    - `final Future<Uint8List> Function(String account) export;`  <sub>:49</sub>
    - `final Future<void> Function(String account, Uint8List bytes) restore;`  <sub>:50</sub>
    - `Future<LearningSnapshotStatus> status() => _serial(() async {…}`  <sub>:61</sub>
    - `Future<LearningSnapshotStatus> setEnabled( String account, bool enabled, ) => _serial(() async {…}`  <sub>:75</sub>
    - `Future<void> clear() => _serial(() async {…}`  <sub>:109</sub>
    - `Future<ReadOnlyResponse> read( String account, Future<ReadOnlyResponse> Function() fetch, ) async {…}`  <sub>:122</sub>
- `mixin NativeLearningSnapshots implements LearningSnapshotGateway`
  <sub>mixin · infrastructure/learning_snapshot_store.dart:174</sub>
    - `Future<LearningSnapshotStatus> learningSnapshotStatus() => learningSnapshots.status();`  <sub>:177</sub>
    - `Future<LearningSnapshotStatus> setLearningSnapshotsEnabled(bool enabled) => learningSnapshots.setEnabled(expectedAccount ?? '', enabled);`  <sub>:180</sub>

## infrastructure/maintenance_service.dart

- `class InstalledVersion`
  <sub>class · infrastructure/maintenance_service.dart:13</sub>
    - `const InstalledVersion(this.version, this.build);`  <sub>:14</sub>
    - `String get label => '$version ($build)';`  <sub>:16</sub>
- `class UpdateResult`
  <sub>class · infrastructure/maintenance_service.dart:19</sub>
    - `const UpdateResult( {…}`  <sub>:20</sub>
    - `String get headline => latest == null ? '尚无 Android 发布'`  <sub>:41</sub>
- `abstract interface class MaintenanceService`
  <sub>class · infrastructure/maintenance_service.dart:50</sub>
    - `Future<InstalledVersion> version();`  <sub>:52</sub>
    - `Future<UpdateResult> checkUpdate(String current);`  <sub>:53</sub>
    - `Future<bool> openReleases(String? page);`  <sub>:54</sub>
    - `Future<bool> checkBridge();`  <sub>:55</sub>
    - `Future<bool> checkStorage();`  <sub>:56</sub>
    - `Future<bool> checkVault();`  <sub>:57</sub>
- `class NativeMaintenanceService implements MaintenanceService`
  <sub>class · infrastructure/maintenance_service.dart:60</sub>
    - `const NativeMaintenanceService();`  <sub>:61</sub>
    - `static const repository = 'https://github.com/JUANWANG-BUAA/ginkgo';`  <sub>:62</sub>
    - `bool get supportsUpdates => Platform.isAndroid;`  <sub>:64</sub>
    - `Future<InstalledVersion> version() async {…}`  <sub>:66</sub>
    - `Future<UpdateResult> checkUpdate(String current) async {…}`  <sub>:72</sub>
    - `Future<bool> openReleases(String? page) async {…}`  <sub>:83</sub>
    - `Future<bool> checkBridge() async {…}`  <sub>:99</sub>
    - `Future<bool> checkStorage() async {…}`  <sub>:105</sub>
    - `Future<bool> checkVault() => live.verifyCredentialStorage( account: '__ginkgo_vault_test__settings_$ {…}`  <sub>:125</sub>

## infrastructure/native_auth_challenge.dart

- `class NativeAuthChallengeGateway implements AuthChallengeGateway`
  <sub>class · infrastructure/native_auth_challenge.dart:4</sub>
    - `const NativeAuthChallengeGateway();`  <sub>:5</sub>
    - `Future<LoginChallenge> loginChallenge( {…}`  <sub>:8</sub>

## infrastructure/native_campus_activities.dart

- `mixin NativeCampusActivities implements CampusActivitiesGateway`
  <sub>mixin · infrastructure/native_campus_activities.dart:25</sub>
    - `Future<CampusActivitiesRead> campusActivities( {…}`  <sub>:27</sub>

## infrastructure/native_career.dart

- `mixin NativeCareer implements CareerEventsGateway`
  <sub>mixin · infrastructure/native_career.dart:26</sub>
    - `Future<CareerEventsRead> careerEvents( {…}`  <sub>:28</sub>

## infrastructure/native_learning.dart

- `mixin NativeLearning` — Native business adapter shared by the account-bound workspace service.
  <sub>mixin · infrastructure/native_learning.dart:11</sub>

## infrastructure/native_library_loans.dart

- `mixin NativeLibraryLoans`
  <sub>mixin · infrastructure/native_library_loans.dart:39</sub>
    - `String libraryLoansPortalUrl() => live.libraryLoansPortalUrl();`  <sub>:42</sub>
    - `Future<LibraryLoansRead> libraryLoans( {…}`  <sub>:45</sub>

## infrastructure/native_mirror_service.dart

- `final class NativeMirrorService`
  <sub>class · infrastructure/native_mirror_service.dart:22</sub>

## infrastructure/native_reminder_planning.dart

- `mixin NativeReminderPlanning implements ReminderPlanningGateway` — Pure Rust command; does not initialize the network runtime.
  <sub>mixin · infrastructure/native_reminder_planning.dart:6</sub>
    - `Future<ExtendedReminderPlans> planReminders( {…}`  <sub>:8</sub>
