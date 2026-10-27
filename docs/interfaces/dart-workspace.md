# 工作区壳层（flutter/lib/workspace）

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。

导航、功能登记表与布局壳。

## DesktopWorkspaceShell (class)

- `class DesktopWorkspaceShell extends StatelessWidget {` — 桌面侧栏壳：侧栏 + IndexedStack 惰性挂载各目的地。选中状态、已访问  
  <sub>workspace/desktop_workspace_shell.dart:12</sub>
    - `const DesktopWorkspaceShell({ super.key, required this.shell, required this.service, this.accountName, this.accountId, this.route, this.onSignOut, });`  <sub>:13</sub>
    - `final Future<void> Function()? onSignOut;`  <sub>:27</sub>
    - `Widget build(BuildContext context) { final selected = shell.selectedId; return Row( children: [ Container( key: const Key('desktop-sidebar'), width: …`  <sub>:42</sub>

## MobileWorkspaceShell (class)

- `class MobileWorkspaceShell extends StatefulWidget {` — 移动标签壳：底部导航 + 每个目的地一个常驻导航栈。选中状态与导航栈  
  <sub>workspace/mobile_workspace_shell.dart:14</sub>
    - `const MobileWorkspaceShell({ super.key, required this.shell, required this.service, this.accountName, this.accountId, this.route, this.onSignOut, });`  <sub>:15</sub>
    - `final Future<void> Function()? onSignOut;`  <sub>:29</sub>
    - `State<MobileWorkspaceShell> createState() => _MobileWorkspaceShellState();`  <sub>:31</sub>

## ServiceDirectory (class)

- `class ServiceDirectory extends StatelessWidget {`  
  <sub>workspace/service_directory.dart:17</sub>
    - `const ServiceDirectory({ super.key, required this.service, required this.onSignOut, this.accountName, this.accountId, this.route, });`  <sub>:18</sub>
    - `final Future<void> Function() onSignOut;`  <sub>:27</sub>
    - `Widget build(BuildContext context) => Column( children: [ AppleSection( header: const Text('个人与校园'), children: [ _row( context, '校园通知', CupertinoIcon…`  <sub>:37</sub>

## WorkspaceBackController (class)

- `class WorkspaceBackController extends ChangeNotifier` — Attached to each tab's first route, so detail routes and dialogs retain  
  <sub>workspace/workspace_back_guard.dart:9</sub>
    - `bool get exitArmed => _exitWindow?.isActive ?? false;`  <sub>:16</sub>
    - `void disarm() { final wasArmed = _exitWindow != null; _exitWindow?.cancel(); _exitWindow = null; if (wasArmed) notifyListeners(); }`  <sub>:18</sub>
    - `void back({required bool atWorkspace, required VoidCallback goToWorkspace}) { if (!atWorkspace) { disarm(); goToWorkspace(); } else if (exitArmed) { …`  <sub>:25</sub>
    - `void didChangeAppLifecycleState(AppLifecycleState state) { if (state != AppLifecycleState.resumed) disarm(); }`  <sub>:41</sub>
    - `void dispose() { WidgetsBinding.instance.removeObserver(this); _exitWindow?.cancel(); super.dispose(); }`  <sub>:46</sub>

## WorkspaceBackHint (class)

- `class WorkspaceBackHint extends StatelessWidget {`  
  <sub>workspace/workspace_back_guard.dart:53</sub>
    - `const WorkspaceBackHint({super.key, required this.controller});`  <sub>:54</sub>
    - `Widget build(BuildContext context) => ListenableBuilder( listenable: controller, builder: (context, _) { return controller.exitArmed ? Positioned( bo…`  <sub>:58</sub>

## WorkspaceSection (enum)

- `enum WorkspaceSection {` — 侧栏分组。顺序即桌面侧栏的呈现顺序；新增功能只登记到既有分组即可。  
  <sub>workspace/workspace_catalog.dart:27</sub>
    - `const WorkspaceSection(this.title);`  <sub>:33</sub>

## WorkspaceContext (class)

- `class WorkspaceContext {` — 功能页面构建上下文：页面只拿到服务与工作区导航能力，不接触壳层状态。  
  <sub>workspace/workspace_catalog.dart:38</sub>
    - `const WorkspaceContext({ required this.service, required this.mobile, required this.openFeature, required this.openSettings, this.accountName, this.a…`  <sub>:39</sub>
    - `final Future<void> Function()? onSignOut;`  <sub>:55</sub>

## WorkspaceDestination (class)

- `class WorkspaceDestination {` — 一次功能登记：标题、图标、所在分组、移动端标签位置与页面构建器。  
  <sub>workspace/workspace_catalog.dart:65</sub>
    - `const WorkspaceDestination({ required this.id, required this.title, required this.icon, required this.build, this.mobileLabel, this.section, this.mob…`  <sub>:66</sub>
    - `final Widget Function(WorkspaceContext context) build;`  <sub>:81</sub>

## GinkgoApp (class)

- `class GinkgoApp extends StatelessWidget {` — 工作区外壳：只负责会话切换、移动/桌面布局与功能登记表的消费，  
  <sub>workspace/workspace_shell.dart:22</sub>
    - `const GinkgoApp({ super.key, required this.service, this.brightness, this.startupUpdate, this.accountName, this.accountId, this.route, this.onSignOut…`  <sub>:23</sub>
    - `final Future<void> Function()? onSignOut;`  <sub>:39</sub>
    - `Widget build(BuildContext context) => ginkgoApp( brightness: brightness, startupUpdate: startupUpdate, home: CourseVisibilityScope( key: ValueKey(ser…`  <sub>:41</sub>

## WorkspaceShell (class)

- `class WorkspaceShell extends StatefulWidget {` — 断点两侧共享的壳层状态。旋转跨越 760dp 时移动标签壳与桌面侧栏壳会  
  <sub>workspace/workspace_shell.dart:62</sub>
    - `const WorkspaceShell({ super.key, required this.service, this.accountName, this.accountId, this.route, this.onSignOut, });`  <sub>:63</sub>
    - `final Future<void> Function()? onSignOut;`  <sub>:75</sub>
    - `State<WorkspaceShell> createState() => WorkspaceShellState();`  <sub>:77</sub>

## WorkspaceShellState (class)

- `class WorkspaceShellState extends State<WorkspaceShell> {`  
  <sub>workspace/workspace_shell.dart:80</sub>
    - `String selectedId = mobileDestinations.first.id;`  <sub>:81</sub>
    - `final navigators = <String, GlobalKey<NavigatorState>>{};`  <sub>:82</sub>
    - `final Set<String> visited = {};`  <sub>:83</sub>
    - `int get mobileIndex { final index = mobileDestinations.indexWhere( (destination) => destination.id == selectedId, ); return index < 0 ? 0 : index; }` — 桌面选中的目的地可能是移动端没有的页面（如成绩）；此时移动壳回到  <sub>:91</sub>
    - `GlobalKey<NavigatorState> navigatorFor(String id) => navigators.putIfAbsent(id, () => GlobalKey<NavigatorState>());`  <sub>:98</sub>
    - `void onMobileTab(int index) { final id = mobileDestinations[index].id; selectedId = id; visited.add(id); }` — 移动标签切换只同步字段不触发重建：可见页面已由 tab 控制器驱动。  <sub>:102</sub>
    - `void select(String id) { ReminderScope.of(context)?.setActive(id); if (selectedId == id) { navigators[id]?.currentState?.popUntil((route) => route.is…`  <sub>:108</sub>
    - `Widget build(BuildContext context) => LayoutBuilder( builder: (context, constraints) => constraints.maxWidth >= GinkgoLayout.desktopBreakpoint ? Desk…`  <sub>:121</sub>

## WorkspaceShortcutPreferences (class)

- `class WorkspaceShortcutPreferences extends ChangeNotifier {` — Local-only, account-bound preferences. A null selection means defaults;  
  <sub>workspace/workspace_shortcut_preferences.dart:11</sub>
    - `static const defaultIds = ['checkin', 'schedule', 'homework', 'reservations'];`  <sub>:20</sub>
    - `static const maxItems = 4;`  <sub>:21</sub>
    - `final Future<String?> Function()? read;` — Test seams; the widget uses the file backend, not school services.  <sub>:27</sub>
    - `final Future<void> Function(String)? write;`  <sub>:28</sub>
    - `List<String>? get ids => _ids;`  <sub>:30</sub>
    - `bool ready = false;`  <sub>:31</sub>
    - `bool loading = false;`  <sub>:32</sub>
    - `bool saving = false;`  <sub>:33</sub>
    - `bool get memoryOnly => demo \|\| accountId == null \|\| accountId!.trim().isEmpty;`  <sub>:62</sub>
    - `void dispose() { _disposed = true; super.dispose(); }`  <sub>:65</sub>
    - `static bool validIds(List<String> ids) => ids.length <= maxItems &&`  <sub>:74</sub>
    - `static List<String> decode(String source) { final value = jsonDecode(source); if (value is! Map<String, dynamic> \|\| value.length != 2 \|\| value['versi…`  <sub>:85</sub>
    - `Future<void> restore() async { if (_disposed \|\| loading \|\| saving \|\| ready) return; loading = true; error = null; _changed(); try { final source = me…`  <sub>:140</sub>
    - `Future<bool> save(List<String> ids) async { if (_disposed \|\| !ready \|\| loading \|\| saving) return false; if (!validIds(ids)) throw ArgumentError.value…`  <sub>:160</sub>

## WorkspaceShortcut (class)

- `class WorkspaceShortcut {`  
  <sub>workspace/workspace_shortcuts.dart:8</sub>
    - `const WorkspaceShortcut({ required this.id, required this.title, required this.icon, });`  <sub>:9</sub>

## WorkspaceShortcuts (class)

- `class WorkspaceShortcuts extends StatefulWidget {` — Local-only pinned entry points. The caller owns navigation and supplies  
  <sub>workspace/workspace_shortcuts.dart:22</sub>
    - `const WorkspaceShortcuts({ super.key, required this.accountId, required this.demo, required this.choices, required this.onOpen, this.storageRoot, });`  <sub>:23</sub>
    - `State<WorkspaceShortcuts> createState() => _WorkspaceShortcutsState();`  <sub>:39</sub>

## WorkspaceTabMotion (class)

- `class WorkspaceTabMotion extends StatefulWidget {` — One clock above the tabs' inactive TickerModes. Only the original incoming  
  <sub>workspace/workspace_tab_transition.dart:5</sub>
    - `const WorkspaceTabMotion({ super.key, required this.controller, required this.child, });`  <sub>:6</sub>
    - `State<WorkspaceTabMotion> createState() => _WorkspaceTabMotionState();`  <sub>:16</sub>

## WorkspaceTabScaffold (class)

- `class WorkspaceTabScaffold extends StatefulWidget {` — Cupertino tab layout with a continuous page turn. Visited tabs retain their  
  <sub>workspace/workspace_tab_transition.dart:113</sub>
    - `const WorkspaceTabScaffold({ super.key, required this.controller, required this.tabBar, required this.tabBuilder, });`  <sub>:114</sub>
    - `State<WorkspaceTabScaffold> createState() => _WorkspaceTabScaffoldState();`  <sub>:126</sub>

## WorkspaceTabTransition (class)

- `class WorkspaceTabTransition extends StatelessWidget {` — Paint-only page-turn motion. The incoming sheet slides in one full page  
  <sub>workspace/workspace_tab_transition.dart:293</sub>
    - `const WorkspaceTabTransition({ super.key, required this.index, required this.child, });`  <sub>:294</sub>
    - `Widget build(BuildContext context) { final motion = context .dependOnInheritedWidgetOfExactType<_TabMotionScope>()! .motion; final rtl = Directionali…`  <sub>:304</sub>
