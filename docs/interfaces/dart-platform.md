# 平台集成（flutter/lib/platform）

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
系统设置、更新门禁与启动更新。

## platform/android_update_controller.dart

- `enum UpdateDownloadSource`
  <sub>enum · platform/android_update_controller.dart:12</sub>
    - `const UpdateDownloadSource(this.label);`  <sub>:18</sub>
- `enum UpdateDownloadPhase { idle, downloading, paused, verifying, ready, failed }`
  <sub>enum · platform/android_update_controller.dart:22</sub>
- `typedef UpdateRoot = Future<Directory> Function();`
  <sub>typedef · platform/android_update_controller.dart:24</sub>
- `typedef ApkInstaller = Future<String> Function(AndroidDownload asset);`
  <sub>typedef · platform/android_update_controller.dart:25</sub>
- `class AndroidUpdateController extends ChangeNotifier`
  <sub>class · platform/android_update_controller.dart:30</sub>
    - `static final shared = AndroidUpdateController();`  <sub>:39</sub>
    - `final HttpClient Function() _newClient;`  <sub>:41</sub>
    - `UpdateDownloadPhase phase = UpdateDownloadPhase.idle;`  <sub>:54</sub>
    - `UpdateDownloadSource source = UpdateDownloadSource.automatic;`  <sub>:55</sub>
    - `int received = 0;`  <sub>:57</sub>
    - `bool installing = false;`  <sub>:61</sub>
    - `bool get busy => …`  <sub>:62</sub>
    - `double get progress => …`  <sub>:63</sub>
    - `void selectSource(UpdateDownloadSource value) {…}`  <sub>:65</sub>
    - `String get sizeLabel => …`  <sub>:71</sub>
    - `void pause() {…}`  <sub>:80</sub>
    - `Future<void> download(AndroidDownload next) async {…}`  <sub>:86</sub>
    - `Future<void> install() async {…}`  <sub>:283</sub>

## platform/external_links.dart

- `Future<bool> launchExternalLink(Uri url) => …`
  <sub>function · platform/external_links.dart:3</sub>

## platform/system_settings_service.dart

- `abstract interface class SystemSettingsService`
  <sub>class · platform/system_settings_service.dart:6</sub>
    - `Future<String> notificationPermission();`  <sub>:8</sub>
    - `Future<String> requestNotifications();`  <sub>:9</sub>
    - `Future<bool> openNotifications();`  <sub>:10</sub>
    - `Future<bool> openAppSettings();`  <sub>:11</sub>
    - `Future<bool> shareProject();`  <sub>:12</sub>
    - `Future<String> networkStatus();`  <sub>:13</sub>
    - `Future<bool> openWifiSettings();`  <sub>:14</sub>
- `class BackgroundReminderStatus`
  <sub>class · platform/system_settings_service.dart:17</sub>
    - `const BackgroundReminderStatus({ required this.enabled, required this.scheduled, required this.status, this.lastRun, });`  <sub>:18</sub>
- `abstract interface class BackgroundReminderStatusService`
  <sub>class · platform/system_settings_service.dart:29</sub>
    - `Future<BackgroundReminderStatus> backgroundReminderStatus();`  <sub>:30</sub>
- `class NativeSystemSettingsService`
  <sub>class · platform/system_settings_service.dart:33</sub>
    - `const NativeSystemSettingsService();`  <sub>:35</sub>
    - `static const channel = MethodChannel('cn.edu.buaa.ginkgo/system');`  <sub>:36</sub>
    - `bool get isAndroid => …`  <sub>:38</sub>
    - `Future<BackgroundReminderStatus> backgroundReminderStatus() async {…}`  <sub>:40</sub>
    - `Future<String> notificationPermission() async => …`  <sub>:62</sub>
    - `Future<String> requestNotifications() async => …`  <sub>:67</sub>
    - `Future<bool> openNotifications() async => …`  <sub>:71</sub>
    - `Future<bool> openAppSettings() async => …`  <sub>:76</sub>
    - `Future<bool> shareProject() async {…}`  <sub>:81</sub>
    - `Future<String> networkStatus() async => …`  <sub>:92</sub>
    - `Future<bool> openWifiSettings() async => …`  <sub>:97</sub>

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
    - `static const mirrorManifestUrl = 'https://gh-proxy.com/https://juanwang-buaa.github.io/ginkgo/update-gate.json';`  <sub>:27</sub>
    - `static const defaultReleasesUrl = 'https://github.com/JUANWANG-BUAA/ginkgo/releases';`  <sub>:29</sub>
    - `static UpdateGate? parse(String body) {…}` — 解析清单；结构不符合预期时视为“没有清单”，不阻塞启动。  <sub>:51</sub>
    - `static Future<UpdateGate?> fetch({ HttpClient? client, Duration timeout = const Duration(milliseconds: 1800), }) async {…}` — 拉取清单；任何网络/解析错误都返回 null，由调用方放行。  <sub>:75</sub>
    - `bool blocks(int buildNumber) => …`  <sub>:101</sub>
    - `Uri get releasesUri => …`  <sub>:103</sub>
- `class UpdateRequiredPage extends StatelessWidget` — 低于最低版本时替代工作区的更新页；不提供“跳过”，避免旧客户端继续写上游。
  <sub>class · platform/update_gate.dart:107</sub>
    - `const UpdateRequiredPage({ super.key, required this.gate, required this.onRetry, this.installedVersion, });`  <sub>:108</sub>
    - `final Future<void> Function() onRetry;`  <sub>:117</sub>
    - `Widget build(BuildContext context) => …`  <sub>:120</sub>
