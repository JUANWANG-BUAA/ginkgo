# Flutter 功能域：settings

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
`flutter/lib/features/settings/` 的页面、域内组件与模型。

## features/settings/accent_theme_preview.dart

- `class AccentThemePicker extends StatelessWidget` — Device-level palette selection. Preview content is synthetic, never a course
  <sub>class · features/settings/accent_theme_preview.dart:7</sub>
    - `const AccentThemePicker({super.key});`  <sub>:8</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:11</sub>
- `class AccentCoursePreview extends StatefulWidget`
  <sub>class · features/settings/accent_theme_preview.dart:130</sub>
    - `const AccentCoursePreview({super.key, required this.accent});`  <sub>:131</sub>
    - `State<AccentCoursePreview> createState() => …`  <sub>:135</sub>

## features/settings/maintenance_pages.dart

- `class MaintenanceScaffold extends StatelessWidget`
  <sub>class · features/settings/maintenance_pages.dart:17</sub>
    - `const MaintenanceScaffold({ super.key, required this.title, required this.children, this.onRefresh, this.busy = false, this.section, this.subtitle, this.icon, });`  <sub>:18</sub>
    - `final Future<void> Function()? onRefresh;`  <sub>:30</sub>
    - `Widget build(BuildContext context) => …`  <sub>:35</sub>
- `class SoftwareUpdatePage extends StatefulWidget`
  <sub>class · features/settings/maintenance_pages.dart:59</sub>
    - `const SoftwareUpdatePage({ super.key, required this.service, this.downloader, this.initialVersion, this.initialResult, this.initialCheckedAt, });`  <sub>:60</sub>
    - `State<SoftwareUpdatePage> createState() => …`  <sub>:74</sub>
- `class DiagnosticsPage extends StatefulWidget`
  <sub>class · features/settings/maintenance_pages.dart:233</sub>
    - `const DiagnosticsPage({ super.key, required this.service, required this.mirror, });`  <sub>:234</sub>
    - `State<DiagnosticsPage> createState() => …`  <sub>:242</sub>

## features/settings/network_diagnostics_page.dart

- `typedef AcademicProbe = Future<GraduateRead> Function(`
  <sub>typedef · features/settings/network_diagnostics_page.dart:10</sub>
- `class NetworkProbeResult` — Only aggregate counts and error codes leave a probe. Response bodies and
  <sub>class · features/settings/network_diagnostics_page.dart:17</sub>
    - `const NetworkProbeResult({ required this.count, this.fromCache, this.stale = false, this.failure, });`  <sub>:18</sub>
- `class NetworkProbe`
  <sub>class · features/settings/network_diagnostics_page.dart:30</sub>
    - `const NetworkProbe(this.title, this.read);`  <sub>:31</sub>
    - `final Future<NetworkProbeResult> Function(bool force) read;`  <sub>:33</sub>
- `List<NetworkProbe> schoolNetworkProbes( MirrorService service, { AcademicProbe? academic, }) {…}`
  <sub>function · features/settings/network_diagnostics_page.dart:36</sub>
- `class NetworkDiagnosticsPage extends StatelessWidget`
  <sub>class · features/settings/network_diagnostics_page.dart:90</sub>
    - `const NetworkDiagnosticsPage({super.key, required this.service});`  <sub>:91</sub>
    - `Widget build(BuildContext context) => …`  <sub>:94</sub>
- `class SchoolNetworkChecks extends StatefulWidget` — Injectable checks also allow deterministic delayed-render tests without
  <sub>class · features/settings/network_diagnostics_page.dart:123</sub>
    - `const SchoolNetworkChecks({super.key, required this.probes});`  <sub>:124</sub>
    - `State<SchoolNetworkChecks> createState() => …`  <sub>:127</sub>

## features/settings/preferences_pages.dart

- `class AppearancePage extends StatelessWidget`
  <sub>class · features/settings/preferences_pages.dart:13</sub>
    - `const AppearancePage({super.key});`  <sub>:14</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:16</sub>
- `class SystemPreferencesPage extends StatefulWidget`
  <sub>class · features/settings/preferences_pages.dart:93</sub>
    - `const SystemPreferencesPage({ super.key, this.service = const NativeSystemSettingsService(), });`  <sub>:94</sub>
    - `State<SystemPreferencesPage> createState() => …`  <sub>:100</sub>
- `class PrivacyPage extends StatelessWidget`
  <sub>class · features/settings/preferences_pages.dart:287</sub>
    - `const PrivacyPage({super.key});`  <sub>:288</sub>
    - `Widget build(BuildContext context) => …`  <sub>:290</sub>
- `class AboutPage extends StatefulWidget`
  <sub>class · features/settings/preferences_pages.dart:334</sub>
    - `const AboutPage({ super.key, this.system = const NativeSystemSettingsService(), });`  <sub>:335</sub>
    - `State<AboutPage> createState() => …`  <sub>:341</sub>

## features/settings/settings_page.dart

- `class SettingsPage extends StatefulWidget`
  <sub>class · features/settings/settings_page.dart:20</sub>
    - `const SettingsPage({ super.key, required this.service, required this.onSignOut, this.accountName, this.accountId, this.route, required this.maintenance, });`  <sub>:21</sub>
    - `final Future<void> Function() onSignOut;`  <sub>:35</sub>
    - `State<SettingsPage> createState() => …`  <sub>:40</sub>
