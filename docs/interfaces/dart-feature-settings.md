# Flutter 功能域：settings

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
`flutter/lib/features/settings/` 的页面、域内组件与模型。

## features/settings/accent_theme_preview.dart

- `class AccentThemePicker extends StatelessWidget` — Device-level palette selection. Preview content is synthetic, never a course
  <sub>class · features/settings/accent_theme_preview.dart:7</sub>
    - `const AccentThemePicker( {…}`  <sub>:8</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:11</sub>
- `class AccentCoursePreview extends StatefulWidget`
  <sub>class · features/settings/accent_theme_preview.dart:130</sub>
    - `const AccentCoursePreview( {…}`  <sub>:131</sub>
    - `State<AccentCoursePreview> createState() => _AccentCoursePreviewState();`  <sub>:135</sub>

## features/settings/maintenance_pages.dart

- `class MaintenanceScaffold extends StatelessWidget`
  <sub>class · features/settings/maintenance_pages.dart:16</sub>
    - `const MaintenanceScaffold( {…}`  <sub>:17</sub>
    - `final Future<void> Function()? onRefresh;`  <sub>:29</sub>
    - `Widget build(BuildContext context) => CupertinoPageScaffold( backgroundColor: Cupertino … ildren: [...children, const SizedBox(height: 96)]), ], ), );`  <sub>:34</sub>
- `class SoftwareUpdatePage extends StatefulWidget`
  <sub>class · features/settings/maintenance_pages.dart:56</sub>
    - `const SoftwareUpdatePage( {…}`  <sub>:57</sub>
    - `State<SoftwareUpdatePage> createState() => _SoftwareUpdatePageState();`  <sub>:71</sub>
- `class DiagnosticsPage extends StatefulWidget`
  <sub>class · features/settings/maintenance_pages.dart:245</sub>
    - `const DiagnosticsPage( {…}`  <sub>:246</sub>
    - `State<DiagnosticsPage> createState() => _DiagnosticsPageState();`  <sub>:254</sub>

## features/settings/network_diagnostics_page.dart

- `typedef AcademicProbe = Future<live.ReadOnlyResponse> Function(`
  <sub>typedef · features/settings/network_diagnostics_page.dart:11</sub>
- `class NetworkProbeResult` — Only aggregate counts and error codes leave a probe. Response bodies and
  <sub>class · features/settings/network_diagnostics_page.dart:18</sub>
    - `const NetworkProbeResult( {…}`  <sub>:19</sub>
- `class NetworkProbe`
  <sub>class · features/settings/network_diagnostics_page.dart:31</sub>
    - `const NetworkProbe(this.title, this.read);`  <sub>:32</sub>
    - `final Future<NetworkProbeResult> Function(bool force) read;`  <sub>:34</sub>
- `class NetworkDiagnosticsPage extends StatelessWidget`
  <sub>class · features/settings/network_diagnostics_page.dart:86</sub>
    - `const NetworkDiagnosticsPage( {…}`  <sub>:87</sub>
    - `Widget build(BuildContext context) => service.isDemo ? const MaintenanceScaffold( title … 请先登录学校账号'), subtitle: Text('离线演示不能测量学校接口耗时。'), ), ], ), ], )`  <sub>:90</sub>
- `class SchoolNetworkChecks extends StatefulWidget` — Injectable checks also allow deterministic delayed-render tests without
  <sub>class · features/settings/network_diagnostics_page.dart:119</sub>
    - `const SchoolNetworkChecks( {…}`  <sub>:120</sub>
    - `State<SchoolNetworkChecks> createState() => _SchoolNetworkChecksState();`  <sub>:123</sub>

## features/settings/preferences_pages.dart

- `class AppearancePage extends StatelessWidget`
  <sub>class · features/settings/preferences_pages.dart:13</sub>
    - `const AppearancePage( {…}`  <sub>:14</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:16</sub>
- `class SystemPreferencesPage extends StatefulWidget`
  <sub>class · features/settings/preferences_pages.dart:93</sub>
    - `const SystemPreferencesPage( {…}`  <sub>:94</sub>
    - `State<SystemPreferencesPage> createState() => _SystemPreferencesPageState();`  <sub>:100</sub>
- `class PrivacyPage extends StatelessWidget`
  <sub>class · features/settings/preferences_pages.dart:270</sub>
    - `const PrivacyPage( {…}`  <sub>:271</sub>
    - `Widget build(BuildContext context) => const MaintenanceScaffold( title: '账号与隐私', sectio … 自检结果在本机显示。反馈前请遮盖姓名、学号、课表和票据，不要发送密码或原始网络记录。'), ), ], ), ], );`  <sub>:273</sub>
- `class AboutPage extends StatefulWidget`
  <sub>class · features/settings/preferences_pages.dart:317</sub>
    - `const AboutPage( {…}`  <sub>:318</sub>
    - `State<AboutPage> createState() => _AboutPageState();`  <sub>:324</sub>

## features/settings/settings_page.dart

- `class SettingsPage extends StatefulWidget`
  <sub>class · features/settings/settings_page.dart:18</sub>
    - `const SettingsPage( {…}`  <sub>:19</sub>
    - `final Future<void> Function() onSignOut;`  <sub>:30</sub>
    - `State<SettingsPage> createState() => _SettingsPageState();`  <sub>:35</sub>
