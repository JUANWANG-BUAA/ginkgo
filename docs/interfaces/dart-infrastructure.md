# Dart 基础设施（flutter/lib/infrastructure）

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。

native/demo 适配器、运行时与持久化实现。

## DemoGraduateCreditMap (mixin)

- `mixin DemoGraduateCreditMap implements GraduateCreditMapGateway {` — Synthetic presentation fixture. Values are explicit, never calculated from  
  <sub>infrastructure/demo_graduate_credit_map.dart:5</sub>
    - `Future<GraduateCreditMapRead> graduateCreditMap({ bool forceRefresh = false, }) async => GraduateCreditMapRead( data: GraduateCreditMap( notice: '演示数…`  <sub>:7</sub>

## DemoHomeworkFiles (class)

- `class DemoHomeworkFiles implements HomeworkFilesGateway {` — Synthetic capability, never reaches a real account or SPOC.  
  <sub>infrastructure/demo_homework_files.dart:7</sub>
    - `Future<List<HomeworkPendingSubmission>> pendingHomeworkSubmissions({ String? assignmentId, }) async => const [];`  <sub>:13</sub>
    - `Future<List<HomeworkCapabilityEvidence>> homeworkCapabilities( String assignmentId, ) async => const [ HomeworkCapabilityEvidence( capability: 'fileS…`  <sub>:17</sub>
    - `Future<HomeworkFileWorkspace> homeworkFiles(String assignmentId) async => HomeworkFileWorkspace( assignmentId: assignmentId, methods: const ['file'],…`  <sub>:34</sub>
    - `Future<HomeworkFileReceipt> uploadHomeworkFile( String assignmentId, String name, Uint8List bytes, ) async { if (bytes.isEmpty \|\| bytes.length > 20 *…`  <sub>:54</sub>
    - `Future<MutationResponse> submitHomeworkFile(String handle) async { if (_receipt?.handle != handle \|\| _submitted) { return const MutationResponse(stat…`  <sub>:69</sub>
    - `Future<MutationResponse> reconcileHomeworkFile(String handle) async => MutationResponse( state: _submitted ? 'accepted' : 'notSubmitted', message: '演…`  <sub>:81</sub>
    - `Future<HomeworkFileDownload> downloadHomeworkFile( String assignmentId, String attachmentId, ) async { if (attachmentId == 'teacher') { return Homewo…`  <sub>:87</sub>

## DemoLearning (mixin)

- `mixin DemoLearning` — Synthetic data only: no school requests, account, cache, or native runtime.  
  <sub>infrastructure/demo_learning.dart:9</sub>

## DemoLibraryLoans (mixin)

- `mixin DemoLibraryLoans implements LibraryLoansGateway {`  
  <sub>infrastructure/demo_library_loans.dart:3</sub>
    - `Future<LibraryLoansRead> libraryLoans({int page = 1}) async =>`  <sub>:5</sub>

## DemoMirrorService (class)

- `final class DemoMirrorService`  
  <sub>infrastructure/demo_mirror_service.dart:14</sub>

## HomeworkFilePicker (typedef)

- `typedef HomeworkFilePicker = Future<XFile?> Function();`  
  <sub>infrastructure/homework_file_io.dart:8</sub>

## HomeworkFileSaver (typedef)

- `typedef HomeworkFileSaver = Future<void> Function(HomeworkFileDownload file);`  
  <sub>infrastructure/homework_file_io.dart:9</sub>

## FileSaveStatus (enum)

- `enum FileSaveStatus { saved, cancelled, stale }`  
  <sub>infrastructure/homework_file_io.dart:11</sub>

## FileOpenStatus (enum)

- `enum FileOpenStatus { opened, unsupported, unavailable, stale }`  
  <sub>infrastructure/homework_file_io.dart:13</sub>

## FileSaveResult (class)

- `class FileSaveResult {` — Contains a local capability only, never a school URL, credential or raw URI.  
  <sub>infrastructure/homework_file_io.dart:16</sub>
    - `final Future<FileOpenStatus> Function()? _opener;`  <sub>:28</sub>
    - `bool get canOpen => status == FileSaveStatus.saved && _opener != null;`  <sub>:29</sub>
    - `Future<FileOpenStatus> open() async => await _opener?.call() ?? FileOpenStatus.unsupported;`  <sub>:30</sub>

## SchoolFileSaveService (class)

- `class SchoolFileSaveService {` — Selection and byte commit are separate so a dismissed page/account never  
  <sub>infrastructure/homework_file_io.dart:49</sub>
    - `const SchoolFileSaveService() : _select = _selectDestination;`  <sub>:50</sub>
    - `Future<FileSaveResult> save( HomeworkFileDownload file, { required bool Function() isCurrent, bool openAfterSave = false, }) async { if (!isCurrent()…`  <sub>:56</sub>

## SchoolFileDestinationPicker (typedef)

- `typedef SchoolFileDestinationPicker = Future<SchoolFileDestination?> Function(`  
  <sub>infrastructure/homework_file_io.dart:107</sub>

## SchoolFileDestination (class)

- `class SchoolFileDestination {` — Opaque local selection capability. Production never accepts a caller URI.  
  <sub>infrastructure/homework_file_io.dart:113</sub>
    - `const SchoolFileDestination({ required this.commit, required this.discard, this.open, });`  <sub>:114</sub>
    - `final Future<void> Function(Uint8List bytes) commit;`  <sub>:119</sub>
    - `final Future<void> Function() discard;`  <sub>:120</sub>
    - `final Future<FileOpenStatus> Function()? open;`  <sub>:121</sub>

## LearningSnapshotStore (class)

- `abstract interface class LearningSnapshotStore {` — The only disk adapter is Android Keystore AES-GCM. No plaintext fallback.  
  <sub>infrastructure/learning_snapshot_store.dart:12</sub>
    - `Future<bool> enabled();`  <sub>:14</sub>
    - `Future<void> enable();`  <sub>:15</sub>
    - `Future<Uint8List?> load();`  <sub>:16</sub>
    - `Future<void> save(Uint8List bytes);`  <sub>:17</sub>
    - `Future<void> clear();`  <sub>:18</sub>

## AndroidLearningSnapshotStore (class)

- `class AndroidLearningSnapshotStore implements LearningSnapshotStore {`  
  <sub>infrastructure/learning_snapshot_store.dart:21</sub>
    - `static const channel = MethodChannel('cn.edu.buaa.ginkgo/learning-snapshots');`  <sub>:22</sub>
    - `bool get supported => !kReleaseMode && Platform.isAndroid;`  <sub>:25</sub>
    - `Future<bool> enabled() async => await channel.invokeMethod<bool>('enabled') ?? false;`  <sub>:27</sub>
    - `Future<void> enable() => channel.invokeMethod<void>('enable');`  <sub>:30</sub>
    - `Future<Uint8List?> load() => channel.invokeMethod<Uint8List>('load');`  <sub>:32</sub>
    - `Future<void> save(Uint8List bytes) => channel.invokeMethod<void>('save', bytes);`  <sub>:34</sub>
    - `Future<void> clear() => channel.invokeMethod<void>('clear');`  <sub>:37</sub>

## LearningSnapshotCoordinator (class)

- `class LearningSnapshotCoordinator {` — Serializes disk read/commit with clear and account changes. Native commands  
  <sub>infrastructure/learning_snapshot_store.dart:42</sub>
    - `final Future<Uint8List> Function(String account) export;`  <sub>:49</sub>
    - `final Future<void> Function(String account, Uint8List bytes) restore;`  <sub>:50</sub>
    - `Future<LearningSnapshotStatus> status() => _serial(() async { if (!store.supported) return const LearningSnapshotStatus(supported: false); try { _ena…`  <sub>:61</sub>
    - `Future<LearningSnapshotStatus> setEnabled( String account, bool enabled, ) => _serial(() async { if (!store.supported) return const LearningSnapshotS…`  <sub>:75</sub>
    - `Future<void> clear() => _serial(() async { _enabled = false; _adoptedAccount = null; message = null; if (store.supported) { try { await store.clear()…`  <sub>:109</sub>
    - `Future<ReadOnlyResponse> read( String account, Future<ReadOnlyResponse> Function() fetch, ) async { if (!store.supported) return fetch(); // The queu…`  <sub>:122</sub>

## NativeLearningSnapshots (mixin)

- `mixin NativeLearningSnapshots implements LearningSnapshotGateway {`  
  <sub>infrastructure/learning_snapshot_store.dart:174</sub>
    - `Future<LearningSnapshotStatus> learningSnapshotStatus() => learningSnapshots.status();`  <sub>:177</sub>
    - `Future<LearningSnapshotStatus> setLearningSnapshotsEnabled(bool enabled) => learningSnapshots.setEnabled(expectedAccount ?? '', enabled);`  <sub>:180</sub>

## InstalledVersion (class)

- `class InstalledVersion {`  
  <sub>infrastructure/maintenance_service.dart:13</sub>
    - `const InstalledVersion(this.version, this.build);`  <sub>:14</sub>
    - `String get label => '$version ($build)';`  <sub>:16</sub>

## UpdateResult (class)

- `class UpdateResult {`  
  <sub>infrastructure/maintenance_service.dart:19</sub>
    - `const UpdateResult({ required this.latest, required this.available, required this.apkAvailable, this.pageUrl, this.notes, this.download, });`  <sub>:20</sub>
    - `String get headline => latest == null ? '尚无 Android 发布'`  <sub>:41</sub>

## MaintenanceService (class)

- `abstract interface class MaintenanceService {`  
  <sub>infrastructure/maintenance_service.dart:50</sub>
    - `Future<InstalledVersion> version();`  <sub>:52</sub>
    - `Future<UpdateResult> checkUpdate(String current);`  <sub>:53</sub>
    - `Future<bool> openReleases(String? page);`  <sub>:54</sub>
    - `Future<bool> checkBridge();`  <sub>:55</sub>
    - `Future<bool> checkStorage();`  <sub>:56</sub>
    - `Future<bool> checkVault();`  <sub>:57</sub>

## NativeMaintenanceService (class)

- `class NativeMaintenanceService implements MaintenanceService {`  
  <sub>infrastructure/maintenance_service.dart:60</sub>
    - `const NativeMaintenanceService();`  <sub>:61</sub>
    - `static const repository = 'https://github.com/JUANWANG-BUAA/ginkgo';`  <sub>:62</sub>
    - `bool get supportsUpdates => Platform.isAndroid;`  <sub>:64</sub>
    - `Future<InstalledVersion> version() async { final info = await PackageInfo.fromPlatform(); return InstalledVersion(info.version, info.buildNumber); }`  <sub>:66</sub>
    - `Future<UpdateResult> checkUpdate(String current) async { final result = await live.checkAndroidUpdate(current: current); if (result.failure != null \|…`  <sub>:72</sub>
    - `Future<bool> openReleases(String? page) async { final uri = Uri.parse(page ?? '$repository/releases'); if (uri.scheme != 'https' \|\| uri.host != 'gith…`  <sub>:83</sub>
    - `Future<bool> checkBridge() async { final result = await bridge.loadDemoSchedule(); return result.failure == null && result.courses.isNotEmpty; }`  <sub>:99</sub>
    - `Future<bool> checkStorage() async { Directory? probe; var passed = false; try { final root = await getApplicationSupportDirectory(); await root.creat…`  <sub>:105</sub>
    - `Future<bool> checkVault() => live.verifyCredentialStorage( account: '__ginkgo_vault_test__settings_${DateTime.now().microsecondsSinceEpoch}', secret:…`  <sub>:125</sub>

## NativeAuthChallengeGateway (class)

- `class NativeAuthChallengeGateway implements AuthChallengeGateway {`  
  <sub>infrastructure/native_auth_challenge.dart:4</sub>
    - `const NativeAuthChallengeGateway();`  <sub>:5</sub>
    - `Future<LoginChallenge> loginChallenge({ String? expectedId, bool refresh = false, }) async { final response = await live.loadLoginChallenge( expected…`  <sub>:8</sub>

## NativeLearning (mixin)

- `mixin NativeLearning` — Native business adapter shared by the account-bound workspace service.  
  <sub>infrastructure/native_learning.dart:11</sub>

## NativeLibraryLoans (mixin)

- `mixin NativeLibraryLoans`  
  <sub>infrastructure/native_library_loans.dart:39</sub>
    - `String libraryLoansPortalUrl() => live.libraryLoansPortalUrl();`  <sub>:42</sub>
    - `Future<LibraryLoansRead> libraryLoans({int page = 1}) async { final owner = expectedAccount; if (owner == null \|\| owner.isEmpty) { return const Libra…`  <sub>:45</sub>

## NativeMirrorService (class)

- `final class NativeMirrorService`  
  <sub>infrastructure/native_mirror_service.dart:18</sub>

## NativeReminderPlanning (mixin)

- `mixin NativeReminderPlanning implements ReminderPlanningGateway {` — Pure Rust command; does not initialize the network runtime.  
  <sub>infrastructure/native_reminder_planning.dart:6</sub>
    - `Future<ExtendedReminderPlans> planReminders({ required List<CourseReminderSeed> courses, required List<TaskReminderSeed> tasks, required int nowMilli…`  <sub>:8</sub>
