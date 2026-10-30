# 工作区壳层（flutter/lib/workspace）

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
导航、功能登记表与布局壳。

## 目录

- [workspace/desktop_workspace_shell.dart](#workspacedesktopworkspaceshelldart) (1)
- [workspace/desktop_workspace_sidebar.dart](#workspacedesktopworkspacesidebardart) (3)
- [workspace/mobile_workspace_shell.dart](#workspacemobileworkspaceshelldart) (1)
- [workspace/service_directory.dart](#workspaceservicedirectorydart) (1)
- [workspace/service_search_page.dart](#workspaceservicesearchpagedart) (4)
- [workspace/workspace_back_guard.dart](#workspaceworkspacebackguarddart) (3)
- [workspace/workspace_catalog.dart](#workspaceworkspacecatalogdart) (2)
- [workspace/workspace_shell.dart](#workspaceworkspaceshelldart) (1)
- [workspace/workspace_shell_controller.dart](#workspaceworkspaceshellcontrollerdart) (2)
- [workspace/workspace_shortcut_preferences.dart](#workspaceworkspaceshortcutpreferencesdart) (1)
- [workspace/workspace_shortcuts.dart](#workspaceworkspaceshortcutsdart) (2)
- [workspace/workspace_tab_transition.dart](#workspaceworkspacetabtransitiondart) (3)
- [workspace/workspace_types.dart](#workspaceworkspacetypesdart) (3)

## workspace/desktop_workspace_shell.dart

- `class DesktopWorkspaceShell extends StatelessWidget` — 桌面侧栏壳：侧栏 + IndexedStack 惰性挂载各目的地。选中状态、已访问
  <sub>class · workspace/desktop_workspace_shell.dart:16</sub>
    - `const DesktopWorkspaceShell({ super.key, required this.shell, required this.service, required this.platformActions, this.accountName, this.accountId, this.route, this.onSignOut, });`  <sub>:17</sub>
    - `final Future<void> Function()? onSignOut;`  <sub>:33</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:49</sub>

## workspace/desktop_workspace_sidebar.dart

- `Widget workspaceBrandIdentity( BuildContext context, { required String? accountName, required bool isDemo, }) {…}` — 品牌区与侧栏条目：桌面壳的静态装饰部分，不持有任何状态。
  <sub>function · workspace/desktop_workspace_sidebar.dart:9</sub>
- `Widget workspaceSidebarItem( BuildContext context, { required WorkspaceDestination destination, required bool selected, required VoidCallback onPressed, }) => …`
  <sub>function · workspace/desktop_workspace_sidebar.dart:110</sub>
- `Widget workspaceSidebarFooter( BuildContext context, { required bool Function(String id) isSelected, required void Function(String id) onSelect, }) => …`
  <sub>function · workspace/desktop_workspace_sidebar.dart:127</sub>

## workspace/mobile_workspace_shell.dart

- `class MobileWorkspaceShell extends StatefulWidget` — 移动标签壳：底部导航 + 每个目的地一个常驻导航栈。选中状态与导航栈
  <sub>class · workspace/mobile_workspace_shell.dart:17</sub>
    - `const MobileWorkspaceShell({ super.key, required this.shell, required this.service, required this.platformActions, this.accountName, this.accountId, this.route, this.onSignOut, });`  <sub>:18</sub>
    - `final Future<void> Function()? onSignOut;`  <sub>:34</sub>
    - `State<MobileWorkspaceShell> createState() => …`  <sub>:36</sub>

## workspace/service_directory.dart

- `class ServiceDirectory extends StatelessWidget`
  <sub>class · workspace/service_directory.dart:19</sub>
    - `const ServiceDirectory({ super.key, required this.service, required this.platformActions, required this.destinations, required this.onSignOut, this.accountName, this.accountId, this.route, });`  <sub>:20</sub>
    - `final Future<void> Function() onSignOut;`  <sub>:33</sub>
    - `Widget build(BuildContext context) => …`  <sub>:43</sub>

## workspace/service_search_page.dart

- `enum ServiceArea`
  <sub>enum · workspace/service_search_page.dart:7</sub>
    - `const ServiceArea(this.label);`  <sub>:15</sub>
- `class ServiceDescriptor` — Metadata refers to the existing navigation destination, not a second page factory.
  <sub>class · workspace/service_search_page.dart:20</sub>
    - `const ServiceDescriptor({ this.destination, this.officialId, this.officialTitle, required this.area, required this.aliases, required this.description, required this.sensitivity, required this.cachePolicy, });`  <sub>:21</sub>
    - `String get id => …`  <sub>:33</sub>
    - `String get title => …`  <sub>:34</sub>
    - `IconData get icon => …`  <sub>:35</sub>
    - `bool matches(String query) {…}`  <sub>:39</sub>
- `List<ServiceDescriptor> searchableServices( List<WorkspaceDestination> destinations, ) => …` — Searches compile-time metadata; it does not request school or personal data.
  <sub>function · workspace/service_search_page.dart:52</sub>
- `class ServiceSearchPage extends StatefulWidget`
  <sub>class · workspace/service_search_page.dart:148</sub>
    - `const ServiceSearchPage({ super.key, required this.context, required this.destinations, });`  <sub>:149</sub>
    - `State<ServiceSearchPage> createState() => …`  <sub>:157</sub>

## workspace/workspace_back_guard.dart

- `class WorkspaceBackController extends ChangeNotifier` — Attached to each tab's first route, so detail routes and dialogs retain
  <sub>class · workspace/workspace_back_guard.dart:9</sub>
    - `bool get exitArmed => …`  <sub>:16</sub>
    - `void disarm() {…}`  <sub>:18</sub>
    - `void back({required bool atWorkspace, required VoidCallback goToWorkspace}) {…}`  <sub>:25</sub>
    - `void didChangeAppLifecycleState(AppLifecycleState state) {…}`  <sub>:41</sub>
    - `void dispose() {…}`  <sub>:46</sub>
- `class WorkspaceBackHint extends StatelessWidget`
  <sub>class · workspace/workspace_back_guard.dart:53</sub>
    - `const WorkspaceBackHint({super.key, required this.controller});`  <sub>:54</sub>
    - `Widget build(BuildContext context) => …`  <sub>:58</sub>
- `Widget guardWorkspaceBack({ required Widget child, required VoidCallback onBack, }) => …`
  <sub>function · workspace/workspace_back_guard.dart:97</sub>

## workspace/workspace_catalog.dart

- `WorkspaceDestination? destinationById(String id) {…}` — 按 id 查找；壳层与今日快捷入口只使用字符串标识。
  <sub>function · workspace/workspace_catalog.dart:256</sub>
- `List<WorkspaceDestination> sidebarDestinations(WorkspaceSection section) => …` — 某个侧栏分组内的条目，顺序即登记顺序。
  <sub>function · workspace/workspace_catalog.dart:274</sub>

## workspace/workspace_shell.dart

- `class GinkgoApp extends StatelessWidget` — 工作区外壳：只负责会话切换、移动/桌面布局与功能登记表的消费，
  <sub>class · workspace/workspace_shell.dart:31</sub>
    - `const GinkgoApp({ super.key, required this.service, this.platformActions = const PlatformActions(), this.brightness, this.startupUpdate, this.accountName, this.accountId, this.route, this.onSignOut, });`  <sub>:32</sub>
    - `final Future<void> Function()? onSignOut;`  <sub>:53</sub>
    - `Widget build(BuildContext context) => …`  <sub>:55</sub>

## workspace/workspace_shell_controller.dart

- `class WorkspaceShell extends StatefulWidget` — Shared navigation state above the mobile/desktop breakpoint. The concrete
  <sub>class · workspace/workspace_shell_controller.dart:12</sub>
    - `const WorkspaceShell({ super.key, required this.service, required this.platformActions, required this.mobileBuilder, required this.desktopBuilder, this.accountName, this.accountId, this.route, this.onSignOut, });`  <sub>:13</sub>
    - `final Widget Function(WorkspaceShellState shell) mobileBuilder;`  <sub>:27</sub>
    - `final Widget Function(WorkspaceShellState shell) desktopBuilder;`  <sub>:28</sub>
    - `final Future<void> Function()? onSignOut;`  <sub>:32</sub>
    - `State<WorkspaceShell> createState() => …`  <sub>:35</sub>
- `class WorkspaceShellState extends State<WorkspaceShell>`
  <sub>class · workspace/workspace_shell_controller.dart:38</sub>
    - `String selectedId = mobileDestinations.first.id;`  <sub>:39</sub>
    - `final navigators = <String, GlobalKey<NavigatorState>> {…}`  <sub>:40</sub>
    - `final Set<String> visited = {…}`  <sub>:41</sub>
    - `int get mobileIndex {…}`  <sub>:47</sub>
    - `GlobalKey<NavigatorState> navigatorFor(String id) => …`  <sub>:54</sub>
    - `void onMobileTab(int index) {…}`  <sub>:57</sub>
    - `void select(String id) {…}`  <sub>:63</sub>
    - `Widget build(BuildContext context) => …`  <sub>:76</sub>

## workspace/workspace_shortcut_preferences.dart

- `class WorkspaceShortcutPreferences extends ChangeNotifier` — Local-only, account-bound preferences. A null selection means defaults;
  <sub>class · workspace/workspace_shortcut_preferences.dart:11</sub>
    - `static const defaultIds = ['checkin', 'schedule', 'homework', 'reservations'];`  <sub>:20</sub>
    - `static const maxItems = 4;`  <sub>:21</sub>
    - `final Future<String?> Function()? read;` — Test seams; the widget uses the file backend, not school services.  <sub>:27</sub>
    - `final Future<void> Function(String)? write;`  <sub>:28</sub>
    - `List<String>? get ids => …`  <sub>:30</sub>
    - `bool ready = false;`  <sub>:31</sub>
    - `bool loading = false;`  <sub>:32</sub>
    - `bool saving = false;`  <sub>:33</sub>
    - `bool get memoryOnly => …`  <sub>:62</sub>
    - `void dispose() {…}`  <sub>:65</sub>
    - `static bool validIds(List<String> ids) => …`  <sub>:74</sub>
    - `static List<String> decode(String source) {…}`  <sub>:85</sub>
    - `Future<void> restore() async {…}`  <sub>:140</sub>
    - `Future<bool> save(List<String> ids) async {…}`  <sub>:160</sub>

## workspace/workspace_shortcuts.dart

- `class WorkspaceShortcut`
  <sub>class · workspace/workspace_shortcuts.dart:9</sub>
    - `const WorkspaceShortcut({ required this.id, required this.title, required this.icon, });`  <sub>:10</sub>
- `class WorkspaceShortcuts extends StatefulWidget` — Local-only pinned entry points. The caller owns navigation and supplies
  <sub>class · workspace/workspace_shortcuts.dart:23</sub>
    - `const WorkspaceShortcuts({ super.key, required this.accountId, required this.demo, required this.choices, required this.onOpen, this.storageRoot, });`  <sub>:24</sub>
    - `State<WorkspaceShortcuts> createState() => …`  <sub>:40</sub>

## workspace/workspace_tab_transition.dart

- `class WorkspaceTabMotion extends StatefulWidget` — One clock above the tabs' inactive TickerModes. Only the original incoming
  <sub>class · workspace/workspace_tab_transition.dart:5</sub>
    - `const WorkspaceTabMotion({ super.key, required this.controller, required this.child, });`  <sub>:6</sub>
    - `State<WorkspaceTabMotion> createState() => …`  <sub>:16</sub>
- `class WorkspaceTabScaffold extends StatefulWidget` — Cupertino tab layout with a continuous page turn. Visited tabs retain their
  <sub>class · workspace/workspace_tab_transition.dart:113</sub>
    - `const WorkspaceTabScaffold({ super.key, required this.controller, required this.tabBar, required this.tabBuilder, });`  <sub>:114</sub>
    - `State<WorkspaceTabScaffold> createState() => …`  <sub>:126</sub>
- `class WorkspaceTabTransition extends StatelessWidget` — Paint-only page-turn motion. The incoming sheet slides in one full page
  <sub>class · workspace/workspace_tab_transition.dart:293</sub>
    - `const WorkspaceTabTransition({ super.key, required this.index, required this.child, });`  <sub>:294</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:304</sub>

## workspace/workspace_types.dart

- `enum WorkspaceSection`
  <sub>enum · workspace/workspace_types.dart:8</sub>
    - `const WorkspaceSection(this.title);`  <sub>:14</sub>
- `class WorkspaceContext` — Page construction context: capabilities are resolved once above the page.
  <sub>class · workspace/workspace_types.dart:19</sub>
    - `final Future<void> Function()? onSignOut;`  <sub>:42</sub>
- `class WorkspaceDestination`
  <sub>class · workspace/workspace_types.dart:47</sub>
    - `const WorkspaceDestination({ required this.id, required this.title, required this.icon, required this.build, this.mobileLabel, this.section, this.mobileTab, this.sidebar = true, this.footer = false, });`  <sub>:48</sub>
    - `final Widget Function(WorkspaceContext context) build;`  <sub>:63</sub>
