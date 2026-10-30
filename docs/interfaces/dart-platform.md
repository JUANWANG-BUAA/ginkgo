# 平台集成（flutter/lib/platform）

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
系统设置、更新门禁与启动更新。

## platform/android_update_controller.dart

- `enum UpdateDownloadSource`
  <sub>enum · platform/android_update_controller.dart:12</sub>
    - `const UpdateDownloadSource(this.label);`  <sub>:17</sub>
- `enum UpdateDownloadPhase { idle, downloading, paused, verifying, ready, failed }`
  <sub>enum · platform/android_update_controller.dart:21</sub>
- `typedef UpdateRoot = Future<Directory> Function();`
  <sub>typedef · platform/android_update_controller.dart:23</sub>
- `typedef ApkInstaller = Future<String> Function(AndroidDownload asset);`
  <sub>typedef · platform/android_update_controller.dart:24</sub>
- `class AndroidUpdateController extends ChangeNotifier`
  <sub>class · platform/android_update_controller.dart:29</sub>
    - `static final shared = AndroidUpdateController();`  <sub>:38</sub>
    - `final HttpClient Function() _newClient;`  <sub>:40</sub>
    - `UpdateDownloadPhase phase = UpdateDownloadPhase.idle;`  <sub>:53</sub>
    - `UpdateDownloadSource source = UpdateDownloadSource.automatic;`  <sub>:54</sub>
    - `int received = 0;`  <sub>:56</sub>
    - `bool installing = false;`  <sub>:60</sub>
    - `bool get busy => …`  <sub>:61</sub>
    - `double get progress => …`  <sub>:62</sub>
    - `void selectSource(UpdateDownloadSource value) {…}`  <sub>:64</sub>
    - `String get sizeLabel => …`  <sub>:70</sub>
    - `void pause() {…}`  <sub>:79</sub>
    - `Future<void> download(AndroidDownload next) async {…}`  <sub>:85</sub>
    - `Future<void> install() async {…}`  <sub>:279</sub>

## platform/startup_update.dart

- `class StartupUpdateController extends ChangeNotifier` — One best-effort check per root lifetime. No timers, downloads or installation.
  <sub>class · platform/startup_update.dart:10</sub>
    - `bool get visible => …`  <sub>:23</sub>
    - `Future<void> checkOnce() async {…}`  <sub>:25</sub>
    - `void dismiss() {…}`  <sub>:62</sub>
    - `void dispose() {…}`  <sub>:69</sub>
- `class StartupUpdateHint extends StatefulWidget` — Same quiet hint posture as diagnostics, but a separate informational state.
  <sub>class · platform/startup_update.dart:77</sub>
    - `const StartupUpdateHint({ super.key, required this.controller, required this.child, });`  <sub>:78</sub>
    - `State<StartupUpdateHint> createState() => …`  <sub>:87</sub>

## platform/system_settings_service.dart

- `abstract interface class SystemSettingsService`
  <sub>class · platform/system_settings_service.dart:6</sub>
    - `Future<String> notificationPermission();`  <sub>:8</sub>
    - `Future<String> requestNotifications();`  <sub>:9</sub>
    - `Future<bool> openNotifications();`  <sub>:10</sub>
    - `Future<bool> openAppSettings();`  <sub>:11</sub>
    - `Future<bool> shareProject();`  <sub>:12</sub>
- `class NativeSystemSettingsService implements SystemSettingsService`
  <sub>class · platform/system_settings_service.dart:15</sub>
    - `const NativeSystemSettingsService();`  <sub>:16</sub>
    - `static const channel = MethodChannel('cn.edu.buaa.ginkgo/system');`  <sub>:17</sub>
    - `bool get isAndroid => …`  <sub>:19</sub>
    - `Future<String> notificationPermission() async => …`  <sub>:21</sub>
    - `Future<String> requestNotifications() async => …`  <sub>:26</sub>
    - `Future<bool> openNotifications() async => …`  <sub>:30</sub>
    - `Future<bool> openAppSettings() async => …`  <sub>:35</sub>
    - `Future<bool> shareProject() async {…}`  <sub>:40</sub>

## platform/update_download_section.dart

- `class UpdateDownloadSection extends StatelessWidget`
  <sub>class · platform/update_download_section.dart:9</sub>
    - `const UpdateDownloadSection({ super.key, required this.asset, required this.controller, });`  <sub>:10</sub>
    - `Widget build(BuildContext context) => …`  <sub>:18</sub>

## platform/update_gate.dart

- `class UpdateGate` — 最低版本门禁：学校协议出现不兼容变化时，旧客户端不静默失败。
  <sub>class · platform/update_gate.dart:13</sub>
    - `const UpdateGate({required this.minBuild, this.message, this.releasesUrl});`  <sub>:14</sub>
    - `static const manifestUrl = 'https://juanwang-buaa.github.io/ginkgo/update-gate.json';`  <sub>:25</sub>
    - `static const defaultReleasesUrl = 'https://github.com/JUANWANG-BUAA/ginkgo/releases';`  <sub>:27</sub>
    - `static UpdateGate? parse(String body) {…}` — 解析清单；结构不符合预期时视为“没有清单”，不阻塞启动。  <sub>:49</sub>
    - `static Future<UpdateGate?> fetch({ HttpClient? client, Duration timeout = const Duration(seconds: 4), }) async {…}` — 拉取清单；任何网络/解析错误都返回 null，由调用方放行。  <sub>:72</sub>
    - `bool blocks(int buildNumber) => …`  <sub>:95</sub>
    - `Uri get releasesUri => …`  <sub>:97</sub>
- `class UpdateRequiredPage extends StatelessWidget` — 低于最低版本时替代工作区的更新页；不提供“跳过”，避免旧客户端继续写上游。
  <sub>class · platform/update_gate.dart:101</sub>
    - `const UpdateRequiredPage({ super.key, required this.gate, required this.onRetry, this.installedVersion, });`  <sub>:102</sub>
    - `final Future<void> Function() onRetry;`  <sub>:111</sub>
    - `Widget build(BuildContext context) => …`  <sub>:114</sub>
