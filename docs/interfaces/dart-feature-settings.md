# Flutter 功能域：settings

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。

`flutter/lib/features/settings/` 的页面、域内组件与模型。

## AccentThemePicker (class)

- `class AccentThemePicker extends StatelessWidget {` — Device-level palette selection. Preview content is synthetic, never a course  
  <sub>features/settings/accent_theme_preview.dart:7</sub>
    - `const AccentThemePicker({super.key});`  <sub>:8</sub>
    - `Widget build(BuildContext context) { final preferences = AppPreferencesScope.of(context); return Padding( padding: const EdgeInsets.all(16), child: C…`  <sub>:11</sub>

## AccentCoursePreview (class)

- `class AccentCoursePreview extends StatefulWidget {`  
  <sub>features/settings/accent_theme_preview.dart:130</sub>
    - `const AccentCoursePreview({super.key, required this.accent});`  <sub>:131</sub>
    - `State<AccentCoursePreview> createState() => _AccentCoursePreviewState();`  <sub>:135</sub>

## MaintenanceScaffold (class)

- `class MaintenanceScaffold extends StatelessWidget {`  
  <sub>features/settings/maintenance_pages.dart:16</sub>
    - `const MaintenanceScaffold({ super.key, required this.title, required this.children, this.onRefresh, this.busy = false, this.section, this.subtitle, t…`  <sub>:17</sub>
    - `final Future<void> Function()? onRefresh;`  <sub>:29</sub>
    - `Widget build(BuildContext context) => CupertinoPageScaffold( backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom( context, ), child:…`  <sub>:34</sub>

## SoftwareUpdatePage (class)

- `class SoftwareUpdatePage extends StatefulWidget {`  
  <sub>features/settings/maintenance_pages.dart:56</sub>
    - `const SoftwareUpdatePage({ super.key, required this.service, this.downloader, this.initialVersion, this.initialResult, this.initialCheckedAt, });`  <sub>:57</sub>
    - `State<SoftwareUpdatePage> createState() => _SoftwareUpdatePageState();`  <sub>:71</sub>

## DiagnosticsPage (class)

- `class DiagnosticsPage extends StatefulWidget {`  
  <sub>features/settings/maintenance_pages.dart:245</sub>
    - `const DiagnosticsPage({ super.key, required this.service, required this.mirror, });`  <sub>:246</sub>
    - `State<DiagnosticsPage> createState() => _DiagnosticsPageState();`  <sub>:254</sub>

## AcademicProbe (typedef)

- `typedef AcademicProbe = Future<live.ReadOnlyResponse> Function({`  
  <sub>features/settings/network_diagnostics_page.dart:11</sub>

## NetworkProbeResult (class)

- `class NetworkProbeResult {` — Only aggregate counts and error codes leave a probe. Response bodies and  
  <sub>features/settings/network_diagnostics_page.dart:18</sub>
    - `const NetworkProbeResult({ required this.count, this.fromCache, this.stale = false, this.failure, });`  <sub>:19</sub>

## NetworkProbe (class)

- `class NetworkProbe {`  
  <sub>features/settings/network_diagnostics_page.dart:31</sub>
    - `const NetworkProbe(this.title, this.read);`  <sub>:32</sub>
    - `final Future<NetworkProbeResult> Function(bool force) read;`  <sub>:34</sub>

## NetworkDiagnosticsPage (class)

- `class NetworkDiagnosticsPage extends StatelessWidget {`  
  <sub>features/settings/network_diagnostics_page.dart:86</sub>
    - `const NetworkDiagnosticsPage({super.key, required this.service});`  <sub>:87</sub>
    - `Widget build(BuildContext context) => service.isDemo ? const MaintenanceScaffold( title: '学校接口耗时', section: 'Ginkgo', subtitle: '比较当前账号的缓存与刷新等待', ico…`  <sub>:90</sub>

## SchoolNetworkChecks (class)

- `class SchoolNetworkChecks extends StatefulWidget {` — Injectable checks also allow deterministic delayed-render tests without  
  <sub>features/settings/network_diagnostics_page.dart:119</sub>
    - `const SchoolNetworkChecks({super.key, required this.probes});`  <sub>:120</sub>
    - `State<SchoolNetworkChecks> createState() => _SchoolNetworkChecksState();`  <sub>:123</sub>

## AppearancePage (class)

- `class AppearancePage extends StatelessWidget {`  
  <sub>features/settings/preferences_pages.dart:13</sub>
    - `const AppearancePage({super.key});`  <sub>:14</sub>
    - `Widget build(BuildContext context) { final preferences = AppPreferencesScope.of(context); return MaintenanceScaffold( title: '显示与阅读', section: '设置', …`  <sub>:16</sub>

## SystemPreferencesPage (class)

- `class SystemPreferencesPage extends StatefulWidget {`  
  <sub>features/settings/preferences_pages.dart:93</sub>
    - `const SystemPreferencesPage({ super.key, this.service = const NativeSystemSettingsService(), });`  <sub>:94</sub>
    - `State<SystemPreferencesPage> createState() => _SystemPreferencesPageState();`  <sub>:100</sub>

## PrivacyPage (class)

- `class PrivacyPage extends StatelessWidget {`  
  <sub>features/settings/preferences_pages.dart:270</sub>
    - `const PrivacyPage({super.key});`  <sub>:271</sub>
    - `Widget build(BuildContext context) => const MaintenanceScaffold( title: '账号与隐私', section: '设置', subtitle: '自动登录、本机数据与请求去向', icon: CupertinoIcons.lock…`  <sub>:273</sub>

## AboutPage (class)

- `class AboutPage extends StatefulWidget {`  
  <sub>features/settings/preferences_pages.dart:317</sub>
    - `const AboutPage({ super.key, this.system = const NativeSystemSettingsService(), });`  <sub>:318</sub>
    - `State<AboutPage> createState() => _AboutPageState();`  <sub>:324</sub>

## SettingsPage (class)

- `class SettingsPage extends StatefulWidget {`  
  <sub>features/settings/settings_page.dart:18</sub>
    - `const SettingsPage({ super.key, required this.service, required this.onSignOut, this.accountName, this.accountId, this.route, this.maintenance = cons…`  <sub>:19</sub>
    - `final Future<void> Function() onSignOut;`  <sub>:30</sub>
    - `State<SettingsPage> createState() => _SettingsPageState();`  <sub>:35</sub>
