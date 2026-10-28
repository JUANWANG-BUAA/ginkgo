# 工作区壳层（flutter/lib/workspace）

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
导航、功能登记表与布局壳。

## 目录

- [workspace/desktop_workspace_shell.dart](#workspacedesktopworkspaceshelldart) (1)
- [workspace/mobile_workspace_shell.dart](#workspacemobileworkspaceshelldart) (1)
- [workspace/service_directory.dart](#workspaceservicedirectorydart) (1)
- [workspace/service_search_page.dart](#workspaceservicesearchpagedart) (3)
- [workspace/workspace_back_guard.dart](#workspaceworkspacebackguarddart) (2)
- [workspace/workspace_catalog.dart](#workspaceworkspacecatalogdart) (3)
- [workspace/workspace_shell.dart](#workspaceworkspaceshelldart) (3)
- [workspace/workspace_shortcut_preferences.dart](#workspaceworkspaceshortcutpreferencesdart) (1)
- [workspace/workspace_shortcuts.dart](#workspaceworkspaceshortcutsdart) (2)
- [workspace/workspace_tab_transition.dart](#workspaceworkspacetabtransitiondart) (3)

## workspace/desktop_workspace_shell.dart

- `class DesktopWorkspaceShell extends StatelessWidget` — 桌面侧栏壳：侧栏 + IndexedStack 惰性挂载各目的地。选中状态、已访问
  <sub>class · workspace/desktop_workspace_shell.dart:15</sub>
    - `const DesktopWorkspaceShell( {…}`  <sub>:16</sub>
    - `final Future<void> Function()? onSignOut;`  <sub>:30</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:45</sub>

## workspace/mobile_workspace_shell.dart

- `class MobileWorkspaceShell extends StatefulWidget` — 移动标签壳：底部导航 + 每个目的地一个常驻导航栈。选中状态与导航栈
  <sub>class · workspace/mobile_workspace_shell.dart:16</sub>
    - `const MobileWorkspaceShell( {…}`  <sub>:17</sub>
    - `final Future<void> Function()? onSignOut;`  <sub>:31</sub>
    - `State<MobileWorkspaceShell> createState() => _MobileWorkspaceShellState();`  <sub>:33</sub>

## workspace/service_directory.dart

- `class ServiceDirectory extends StatelessWidget`
  <sub>class · workspace/service_directory.dart:17</sub>
    - `const ServiceDirectory( {…}`  <sub>:18</sub>
    - `final Future<void> Function() onSignOut;`  <sub>:27</sub>
    - `Widget build(BuildContext context) => Column( children: [ AppleSection( children: [ App … route: route, ), ), ], ), const SizedBox(height: 32), ], );`  <sub>:37</sub>

## workspace/service_search_page.dart

- `enum ServiceArea`
  <sub>enum · workspace/service_search_page.dart:8</sub>
    - `const ServiceArea(this.label);`  <sub>:16</sub>
- `class ServiceDescriptor` — Metadata refers to the existing navigation destination, not a second page factory.
  <sub>class · workspace/service_search_page.dart:21</sub>
    - `const ServiceDescriptor( {…}`  <sub>:22</sub>
    - `String get id => destination?.id ?? officialId!;`  <sub>:34</sub>
    - `String get title => destination?.title ?? officialTitle!;`  <sub>:35</sub>
    - `IconData get icon => destination?.icon ?? CupertinoIcons.globe;`  <sub>:36</sub>
    - `bool matches(String query) {…}`  <sub>:40</sub>
- `class ServiceSearchPage extends StatefulWidget`
  <sub>class · workspace/service_search_page.dart:148</sub>
    - `const ServiceSearchPage( {…}`  <sub>:149</sub>
    - `State<ServiceSearchPage> createState() => _ServiceSearchPageState();`  <sub>:152</sub>

## workspace/workspace_back_guard.dart

- `class WorkspaceBackController extends ChangeNotifier` — Attached to each tab's first route, so detail routes and dialogs retain
  <sub>class · workspace/workspace_back_guard.dart:9</sub>
    - `bool get exitArmed => _exitWindow?.isActive ?? false;`  <sub>:16</sub>
    - `void disarm() {…}`  <sub>:18</sub>
    - `void back( {…}`  <sub>:25</sub>
    - `void didChangeAppLifecycleState(AppLifecycleState state) {…}`  <sub>:41</sub>
    - `void dispose() {…}`  <sub>:46</sub>
- `class WorkspaceBackHint extends StatelessWidget`
  <sub>class · workspace/workspace_back_guard.dart:53</sub>
    - `const WorkspaceBackHint( {…}`  <sub>:54</sub>
    - `Widget build(BuildContext context) => ListenableBuilder( listenable: controller, builder: (context, _) {…}`  <sub>:58</sub>

## workspace/workspace_catalog.dart

- `enum WorkspaceSection` — 侧栏分组。顺序即桌面侧栏的呈现顺序；新增功能只登记到既有分组即可。
  <sub>enum · workspace/workspace_catalog.dart:32</sub>
    - `const WorkspaceSection(this.title);`  <sub>:38</sub>
- `class WorkspaceContext` — 功能页面构建上下文：页面只拿到服务与工作区导航能力，不接触壳层状态。
  <sub>class · workspace/workspace_catalog.dart:43</sub>
    - `const WorkspaceContext( {…}`  <sub>:44</sub>
    - `final Future<void> Function()? onSignOut;`  <sub>:60</sub>
- `class WorkspaceDestination` — 一次功能登记：标题、图标、所在分组、移动端标签位置与页面构建器。
  <sub>class · workspace/workspace_catalog.dart:70</sub>
    - `const WorkspaceDestination( {…}`  <sub>:71</sub>
    - `final Widget Function(WorkspaceContext context) build;`  <sub>:86</sub>

## workspace/workspace_shell.dart

- `class GinkgoApp extends StatelessWidget` — 工作区外壳：只负责会话切换、移动/桌面布局与功能登记表的消费，
  <sub>class · workspace/workspace_shell.dart:26</sub>
    - `const GinkgoApp( {…}`  <sub>:27</sub>
    - `final Future<void> Function()? onSignOut;`  <sub>:43</sub>
    - `Widget build(BuildContext context) => ginkgoApp( brightness: brightness, startupUpdate: … untId, route: route, onSignOut: onSignOut, ), ), ), ), ), );`  <sub>:45</sub>
- `class WorkspaceShell extends StatefulWidget` — 断点两侧共享的壳层状态。旋转跨越 760dp 时移动标签壳与桌面侧栏壳会
  <sub>class · workspace/workspace_shell.dart:74</sub>
    - `const WorkspaceShell( {…}`  <sub>:75</sub>
    - `final Future<void> Function()? onSignOut;`  <sub>:87</sub>
    - `State<WorkspaceShell> createState() => WorkspaceShellState();`  <sub>:89</sub>
- `class WorkspaceShellState extends State<WorkspaceShell>`
  <sub>class · workspace/workspace_shell.dart:92</sub>
    - `String selectedId = mobileDestinations.first.id;`  <sub>:93</sub>
    - `final navigators = <String, GlobalKey<NavigatorState>> {…}`  <sub>:94</sub>
    - `final Set<String> visited = {…}`  <sub>:95</sub>
    - `int get mobileIndex {…}` — 桌面选中的目的地可能是移动端没有的页面（如成绩）；此时移动壳回到  <sub>:103</sub>
    - `GlobalKey<NavigatorState> navigatorFor(String id) => navigators.putIfAbsent(id, () => GlobalKey<NavigatorState>());`  <sub>:110</sub>
    - `void onMobileTab(int index) {…}` — 移动标签切换只同步字段不触发重建：可见页面已由 tab 控制器驱动。  <sub>:114</sub>
    - `void select(String id) {…}`  <sub>:120</sub>
    - `Widget build(BuildContext context) => LayoutBuilder( builder: (context, constraints) => … tId, route: widget.route, onSignOut: widget.onSignOut, ), );`  <sub>:133</sub>

## workspace/workspace_shortcut_preferences.dart

- `class WorkspaceShortcutPreferences extends ChangeNotifier` — Local-only, account-bound preferences. A null selection means defaults;
  <sub>class · workspace/workspace_shortcut_preferences.dart:11</sub>
    - `static const defaultIds = ['checkin', 'schedule', 'homework', 'reservations'];`  <sub>:20</sub>
    - `static const maxItems = 4;`  <sub>:21</sub>
    - `final Future<String?> Function()? read;` — Test seams; the widget uses the file backend, not school services.  <sub>:27</sub>
    - `final Future<void> Function(String)? write;`  <sub>:28</sub>
    - `List<String>? get ids => _ids;`  <sub>:30</sub>
    - `bool ready = false;`  <sub>:31</sub>
    - `bool loading = false;`  <sub>:32</sub>
    - `bool saving = false;`  <sub>:33</sub>
    - `bool get memoryOnly => demo \|\| accountId == null \|\| accountId!.trim().isEmpty;`  <sub>:62</sub>
    - `void dispose() {…}`  <sub>:65</sub>
    - `static bool validIds(List<String> ids) => ids.length <= maxItems &&`  <sub>:74</sub>
    - `static List<String> decode(String source) {…}`  <sub>:85</sub>
    - `Future<void> restore() async {…}`  <sub>:140</sub>
    - `Future<bool> save(List<String> ids) async {…}`  <sub>:160</sub>

## workspace/workspace_shortcuts.dart

- `class WorkspaceShortcut`
  <sub>class · workspace/workspace_shortcuts.dart:8</sub>
    - `const WorkspaceShortcut( {…}`  <sub>:9</sub>
- `class WorkspaceShortcuts extends StatefulWidget` — Local-only pinned entry points. The caller owns navigation and supplies
  <sub>class · workspace/workspace_shortcuts.dart:22</sub>
    - `const WorkspaceShortcuts( {…}`  <sub>:23</sub>
    - `State<WorkspaceShortcuts> createState() => _WorkspaceShortcutsState();`  <sub>:39</sub>

## workspace/workspace_tab_transition.dart

- `class WorkspaceTabMotion extends StatefulWidget` — One clock above the tabs' inactive TickerModes. Only the original incoming
  <sub>class · workspace/workspace_tab_transition.dart:5</sub>
    - `const WorkspaceTabMotion( {…}`  <sub>:6</sub>
    - `State<WorkspaceTabMotion> createState() => _WorkspaceTabMotionState();`  <sub>:16</sub>
- `class WorkspaceTabScaffold extends StatefulWidget` — Cupertino tab layout with a continuous page turn. Visited tabs retain their
  <sub>class · workspace/workspace_tab_transition.dart:113</sub>
    - `const WorkspaceTabScaffold( {…}`  <sub>:114</sub>
    - `State<WorkspaceTabScaffold> createState() => _WorkspaceTabScaffoldState();`  <sub>:126</sub>
- `class WorkspaceTabTransition extends StatelessWidget` — Paint-only page-turn motion. The incoming sheet slides in one full page
  <sub>class · workspace/workspace_tab_transition.dart:293</sub>
    - `const WorkspaceTabTransition( {…}`  <sub>:294</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:304</sub>
