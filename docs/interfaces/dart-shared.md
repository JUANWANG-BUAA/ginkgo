# 跨域共享状态（flutter/lib/shared）

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。

时间、偏好、提醒等被多个域复用的状态与值。

## shared/app_preferences.dart

- `enum AppAppearance`  
  <sub>enum · shared/app_preferences.dart:9</sub>
    - `const AppAppearance(this.label, this.brightness);`  <sub>:14</sub>
- `enum AppAccent`  
  <sub>enum · shared/app_preferences.dart:21</sub>
    - `const AppAccent(this.label, this.color);`  <sub>:48</sub>
- `typedef PreferencesWriter = Future<void> Function(Map<String, Object> value);`  
  <sub>typedef · shared/app_preferences.dart:53</sub>
- `typedef PreferencesReader = Future<Map<String, dynamic>?> Function();`  
  <sub>typedef · shared/app_preferences.dart:54</sub>
- `class AppPreferences extends ChangeNotifier` — Device-wide display choices and the session-flow marker only. Credentials  
  <sub>class · shared/app_preferences.dart:59</sub>
    - `static final shared = AppPreferences();`  <sub>:63</sub>
    - `AppAppearance appearance = AppAppearance.system;`  <sub>:67</sub>
    - `AppAccent accent = AppAccent.green;`  <sub>:68</sub>
    - `bool compactLists = false;`  <sub>:69</sub>
    - `bool reduceMotion = false;`  <sub>:70</sub>
    - `double textSize = 1;`  <sub>:71</sub>
    - `bool explicitSignOut = false;` — Set by an explicit sign-out and cleared by the next successful sign-in.  <sub>:76</sub>
    - `Future<void> restore() async {…}`  <sub>:98</sub>
    - `Future<void> update( {…}`  <sub>:143</sub>
    - `Future<void> setExplicitSignOut(bool value) {…}` — Records or clears the explicit sign-out marker with the same serialized  <sub>:160</sub>
- `class AppPreferencesScope extends InheritedNotifier<AppPreferences>`  
  <sub>class · shared/app_preferences.dart:168</sub>
    - `const AppPreferencesScope( {…}`  <sub>:169</sub>
    - `static AppPreferences of(BuildContext context) => context`  <sub>:175</sub>

## shared/query_cache_scope.dart

- `class QueryCacheScope extends StatefulWidget` — Reset retained pages only after Rust has finished clearing its snapshots.  
  <sub>class · shared/query_cache_scope.dart:5</sub>
    - `const QueryCacheScope( {…}`  <sub>:6</sub>
    - `static void invalidate(BuildContext context) => context.findAncestorStateOfType<_QueryCacheScopeState>()?.invalidate();`  <sub>:9</sub>
    - `State<QueryCacheScope> createState() => _QueryCacheScopeState();`  <sub>:13</sub>

## shared/reminder_rules.dart

- `class ReminderPlan`  
  <sub>class · shared/reminder_rules.dart:35</sub>
    - `const ReminderPlan( {…}`  <sub>:36</sub>

## shared/reminder_scope.dart

- `class ReminderScope extends StatefulWidget` — 把 [ReminderController] 的作用域挂到子树上，并跟随应用生命周期启停。  
  <sub>class · shared/reminder_scope.dart:14</sub>
    - `const ReminderScope( {…}`  <sub>:15</sub>
    - `final ReminderController Function( MirrorService service, String account, CourseVisibility? visibility, )?` — Optional factory; the scope owns and disposes the returned controller.  <sub>:24</sub>
    - `static ReminderController? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_ReminderData>()?.notifier;`  <sub>:33</sub>
    - `static ReminderController? read(BuildContext context) => context.getInheritedWidgetOfExactType<_ReminderData>()?.notifier;`  <sub>:35</sub>
    - `State<ReminderScope> createState() => _ReminderScopeState();`  <sub>:38</sub>

## shared/reminders.dart

- `abstract interface class ReminderPlatform`  
  <sub>class · shared/reminders.dart:22</sub>
    - `Future<void> replace(List<Map<String, Object>> plans);`  <sub>:23</sub>
- `class NativeReminderPlatform implements ReminderPlatform`  
  <sub>class · shared/reminders.dart:26</sub>
    - `static const channel = MethodChannel('cn.edu.buaa.ginkgo/reminders');`  <sub>:27</sub>
    - `Future<void> replace(List<Map<String, Object>> plans) async {…}`  <sub>:29</sub>
- `class ReminderController extends ChangeNotifier` — Account-scoped read receipts contain only digests, not school content.  
  <sub>class · shared/reminders.dart:38</sub>
    - `final Future<String> Function() tasksRoot;`  <sub>:62</sub>
    - `final DateTime Function() clock;`  <sub>:63</sub>
    - `bool checkinEnabled = true, homeworkEnabled = true;`  <sub>:69</sub>
    - `bool courseEnabled = false, taskEnabled = false;`  <sub>:71</sub>
    - `int scheduled = 0;`  <sub>:75</sub>
    - `String digest(String key) => sha256.convert(utf8.encode('$account:$key')).toString();`  <sub>:77</sub>
    - `Future<void> restore() async {…}`  <sub>:83</sub>
    - `List<ReminderPlan> get plans => [ if (checkinEnabled) ..._checkin, if (homeworkEnabled) … ._task, ].where((p) => p.expires.isAfter(clock())).toList();`  <sub>:137</sub>
    - `int unread(String group) => plans .where( (p) => p.group == _reminderGroup(group) && !p.at.isAfter(clock()) && !_read.containsKey(digest(p.key)), )`  <sub>:149</sub>
    - `void markRead(String group) {…}`  <sub>:158</sub>
    - `void setActive(String group) {…}`  <sub>:175</sub>
    - `Future<void> setEnabled(String group, bool value) async {…}`  <sub>:180</sub>
    - `Future<void> updateSchedule(ScheduleResponse data) async {…}` — Failed or stale school reads never replace a previously accepted plan.  <sub>:201</sub>
    - `Future<void> updateTasks(List<LocalTaskRecord> tasks) async {…}`  <sub>:217</sub>
    - `void updateCheckin(CheckInResponse data) {…}`  <sub>:258</sub>
    - `void updateHomework(HomeworkResponse data) {…}`  <sub>:262</sub>
    - `Future<void> refresh( {…}`  <sub>:271</sub>
    - `Future<void> reconcile() async {…}`  <sub>:339</sub>
    - `Future<void> reschedule() async {…}`  <sub>:367</sub>
    - `Future<void> stop() async {…}`  <sub>:372</sub>
    - `void dispose() {…}`  <sub>:378</sub>
