# 跨域共享状态（flutter/lib/shared）

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。

时间、偏好、提醒等被多个域复用的状态与值。

## AppAppearance (enum)

- `enum AppAppearance {`  
  <sub>shared/app_preferences.dart:9</sub>
    - `const AppAppearance(this.label, this.brightness);`  <sub>:14</sub>

## AppAccent (enum)

- `enum AppAccent {`  
  <sub>shared/app_preferences.dart:21</sub>
    - `const AppAccent(this.label, this.color);`  <sub>:48</sub>

## PreferencesWriter (typedef)

- `typedef PreferencesWriter = Future<void> Function(Map<String, Object> value);`  
  <sub>shared/app_preferences.dart:53</sub>

## PreferencesReader (typedef)

- `typedef PreferencesReader = Future<Map<String, dynamic>?> Function();`  
  <sub>shared/app_preferences.dart:54</sub>

## AppPreferences (class)

- `class AppPreferences extends ChangeNotifier {` — Device-wide display choices and the session-flow marker only. Credentials  
  <sub>shared/app_preferences.dart:59</sub>
    - `static final shared = AppPreferences();`  <sub>:63</sub>
    - `AppAppearance appearance = AppAppearance.system;`  <sub>:67</sub>
    - `AppAccent accent = AppAccent.green;`  <sub>:68</sub>
    - `bool compactLists = false;`  <sub>:69</sub>
    - `bool reduceMotion = false;`  <sub>:70</sub>
    - `double textSize = 1;`  <sub>:71</sub>
    - `bool explicitSignOut = false;` — Set by an explicit sign-out and cleared by the next successful sign-in.  <sub>:76</sub>
    - `Future<void> restore() async { try { final value = await _reader(); if (value == null) return; appearance = AppAppearance.values.firstWhere( (item) =…`  <sub>:98</sub>
    - `Future<void> update({ AppAppearance? appearance, AppAccent? accent, bool? compactLists, bool? reduceMotion, double? textSize, }) { this.appearance = …`  <sub>:143</sub>
    - `Future<void> setExplicitSignOut(bool value) { explicitSignOut = value; return _scheduleSave( value ? '已退出登录，本机标记保存失败，恢复功能可能仍会显示登录页' : '外观已应用，本机保存失败，请…` — Records or clears the explicit sign-out marker with the same serialized  <sub>:160</sub>

## AppPreferencesScope (class)

- `class AppPreferencesScope extends InheritedNotifier<AppPreferences> {`  
  <sub>shared/app_preferences.dart:168</sub>
    - `const AppPreferencesScope({ super.key, required AppPreferences preferences, required super.child, }) : super(notifier: preferences);`  <sub>:169</sub>
    - `static AppPreferences of(BuildContext context) => context`  <sub>:175</sub>

## QueryCacheScope (class)

- `class QueryCacheScope extends StatefulWidget {` — Reset retained pages only after Rust has finished clearing its snapshots.  
  <sub>shared/query_cache_scope.dart:5</sub>
    - `const QueryCacheScope({super.key, required this.child});`  <sub>:6</sub>
    - `static void invalidate(BuildContext context) => context.findAncestorStateOfType<_QueryCacheScopeState>()?.invalidate();`  <sub>:9</sub>
    - `State<QueryCacheScope> createState() => _QueryCacheScopeState();`  <sub>:13</sub>

## ReminderPlan (class)

- `class ReminderPlan {`  
  <sub>shared/reminder_rules.dart:35</sub>
    - `const ReminderPlan({ required this.key, required this.group, required this.at, required this.expires, });`  <sub>:36</sub>

## ReminderScope (class)

- `class ReminderScope extends StatefulWidget {` — 把 [ReminderController] 的作用域挂到子树上，并跟随应用生命周期启停。  
  <sub>shared/reminder_scope.dart:14</sub>
    - `const ReminderScope({ super.key, required this.service, required this.account, required this.child, this.controllerFactory, });`  <sub>:15</sub>
    - `final ReminderController Function( MirrorService service, String account, CourseVisibility? visibility, )?` — Optional factory; the scope owns and disposes the returned controller.  <sub>:24</sub>
    - `static ReminderController? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_ReminderData>()?.notifier;`  <sub>:33</sub>
    - `static ReminderController? read(BuildContext context) => context.getInheritedWidgetOfExactType<_ReminderData>()?.notifier;`  <sub>:35</sub>
    - `State<ReminderScope> createState() => _ReminderScopeState();`  <sub>:38</sub>

## ReminderPlatform (class)

- `abstract interface class ReminderPlatform {`  
  <sub>shared/reminders.dart:22</sub>
    - `Future<void> replace(List<Map<String, Object>> plans);`  <sub>:23</sub>

## NativeReminderPlatform (class)

- `class NativeReminderPlatform implements ReminderPlatform {`  
  <sub>shared/reminders.dart:26</sub>
    - `static const channel = MethodChannel('cn.edu.buaa.ginkgo/reminders');`  <sub>:27</sub>
    - `Future<void> replace(List<Map<String, Object>> plans) async { if (!Platform.isAndroid) { throw UnsupportedError('当前平台不支持系统提醒，应用内提示仍可用'); } await chan…`  <sub>:29</sub>

## ReminderController (class)

- `class ReminderController extends ChangeNotifier {` — Account-scoped read receipts contain only digests, not school content.  
  <sub>shared/reminders.dart:38</sub>
    - `final Future<String> Function() tasksRoot;`  <sub>:62</sub>
    - `final DateTime Function() clock;`  <sub>:63</sub>
    - `bool checkinEnabled = true, homeworkEnabled = true;`  <sub>:69</sub>
    - `bool courseEnabled = false, taskEnabled = false;`  <sub>:71</sub>
    - `int scheduled = 0;`  <sub>:75</sub>
    - `String digest(String key) => sha256.convert(utf8.encode('$account:$key')).toString();`  <sub>:77</sub>
    - `Future<void> restore() async { if (!persist) { _restored = true; return; } try { final file = await _file(); if (!await file.exists()) return; final …`  <sub>:83</sub>
    - `List<ReminderPlan> get plans => [ if (checkinEnabled) ..._checkin, if (homeworkEnabled) ..._homework, if (courseEnabled) ..._course, if (taskEnabled)…`  <sub>:137</sub>
    - `int unread(String group) => plans .where( (p) => p.group == _reminderGroup(group) && !p.at.isAfter(clock()) && !_read.containsKey(digest(p.key)), )`  <sub>:149</sub>
    - `void markRead(String group) { var changed = false; for (final plan in plans.where( (p) => p.group == _reminderGroup(group) && !p.at.isAfter(clock()),…`  <sub>:158</sub>
    - `void setActive(String group) { activeGroup = group; markRead(group); }`  <sub>:175</sub>
    - `Future<void> setEnabled(String group, bool value) async { if (group == 'checkin') { checkinEnabled = value; } else if (group == 'homework') { homewor…`  <sub>:180</sub>
    - `Future<void> updateSchedule(ScheduleResponse data) async { if (_disposed \|\| !courseEnabled) return; if (data.failure != null) { hint = '课程提醒未更新，请进入课表…` — Failed or stale school reads never replace a previously accepted plan.  <sub>:201</sub>
    - `Future<void> updateTasks(List<LocalTaskRecord> tasks) async { if (_disposed \|\| !taskEnabled) return; await _plan('task', tasks: taskReminderSeeds(tas…`  <sub>:217</sub>
    - `void updateCheckin(CheckInResponse data) { if (data.failure == null && !data.stale) _checkin = checkinReminders(data); }`  <sub>:258</sub>
    - `void updateHomework(HomeworkResponse data) { if (data.failure == null) { _homework = homeworkReminders( personalHomeworkItems(data.items, visibility)…`  <sub>:262</sub>
    - `Future<void> refresh({bool includeHomework = true}) async { if (_busy \|\| _disposed \|\| service.isDemo) return; _busy = true; hint = null; // Independe…`  <sub>:271</sub>
    - `Future<void> reconcile() async { if (_disposed \|\| (persist && !_restored)) return; _read.removeWhere((_, expiry) => expiry <= clock().millisecondsSin…`  <sub>:339</sub>
    - `Future<void> reschedule() async { _lastPlatformState = null; await reconcile(); }`  <sub>:367</sub>
    - `Future<void> stop() async { _disposed = true; if (!service.isDemo) await platform.replace([]); }`  <sub>:372</sub>
    - `void dispose() { _disposed = true; super.dispose(); }`  <sub>:378</sub>
