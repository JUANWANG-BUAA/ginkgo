# 跨域共享状态（flutter/lib/shared）

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
时间、偏好、提醒等被多个域复用的状态与值。

## 目录

- [shared/app_preferences.dart](#sharedapppreferencesdart) (6)
- [shared/checkin_sessions.dart](#sharedcheckinsessionsdart) (2)
- [shared/course_visibility.dart](#sharedcoursevisibilitydart) (2)
- [shared/homework_visibility.dart](#sharedhomeworkvisibilitydart) (1)
- [shared/query_cache_scope.dart](#sharedquerycachescopedart) (1)
- [shared/reminder_controller.dart](#sharedremindercontrollerdart) (1)
- [shared/reminder_rules.dart](#sharedreminderrulesdart) (2)
- [shared/reminder_scope.dart](#sharedreminderscopedart) (1)
- [shared/school_links.dart](#sharedschoollinksdart) (1)
- [shared/school_timestamp.dart](#sharedschooltimestampdart) (5)
- [shared/today_time.dart](#sharedtodaytimedart) (6)

## shared/app_preferences.dart

- `enum AppAppearance`
  <sub>enum · shared/app_preferences.dart:5</sub>
    - `const AppAppearance(this.label, this.brightness);`  <sub>:10</sub>
- `enum AppAccent`
  <sub>enum · shared/app_preferences.dart:17</sub>
    - `const AppAccent(this.label, this.color);`  <sub>:44</sub>
- `typedef PreferencesWriter = Future<void> Function(Map<String, Object> value);`
  <sub>typedef · shared/app_preferences.dart:49</sub>
- `typedef PreferencesReader = Future<Map<String, Object?>?> Function();`
  <sub>typedef · shared/app_preferences.dart:50</sub>
- `class AppPreferences extends ChangeNotifier` — Device-wide display choices and the session-flow marker only. Credentials
  <sub>class · shared/app_preferences.dart:55</sub>
    - `static final shared = AppPreferences();`  <sub>:61</sub>
    - `bool get readFailed => …` — An unreadable settings file cannot establish the saved sign-out choice.  <sub>:71</sub>
    - `AppAppearance appearance = AppAppearance.system;`  <sub>:72</sub>
    - `AppAccent accent = AppAccent.green;`  <sub>:73</sub>
    - `bool compactLists = false;`  <sub>:74</sub>
    - `bool reduceMotion = false;`  <sub>:75</sub>
    - `double textSize = 1;`  <sub>:76</sub>
    - `bool explicitSignOut = false;` — Set by an explicit sign-out and cleared by the next successful sign-in.  <sub>:81</sub>
    - `String? get writeError => …` — Last failed write, separate from a failed settings read.  <sub>:86</sub>
    - `String routeMode = 'automatic';` — Chosen network route, kept so the login page and the next start use the  <sub>:90</sub>
    - `Future<void> restore() async {…}`  <sub>:100</sub>
    - `Future<void> retrySave() => …` — Retries the current local snapshot without changing any setting.  <sub>:197</sub>
    - `void dispose() {…}`  <sub>:200</sub>
    - `Future<void> update({ AppAppearance? appearance, AppAccent? accent, bool? compactLists, bool? reduceMotion, double? textSize, }) {…}`  <sub>:205</sub>
    - `Future<void> setRouteMode(String value) {…}` — Persists the network route chosen on the login page.  <sub>:221</sub>
    - `Future<void> setExplicitSignOut(bool value) {…}` — Records or clears the explicit sign-out marker with the same serialized  <sub>:228</sub>
- `class AppPreferencesScope extends InheritedNotifier<AppPreferences>`
  <sub>class · shared/app_preferences.dart:236</sub>
    - `const AppPreferencesScope({ super.key, required AppPreferences preferences, required super.child, }) : super(notifier: preferences);`  <sub>:237</sub>
    - `static AppPreferences of(BuildContext context) => …`  <sub>:243</sub>

## shared/checkin_sessions.dart

- `String checkinSessionKey(CheckInCourse course) => …`
  <sub>function · shared/checkin_sessions.dart:3</sub>
- `List<CheckInCourse> uniqueCheckinSessions(Iterable<CheckInCourse> courses) {…}`
  <sub>function · shared/checkin_sessions.dart:5</sub>

## shared/course_visibility.dart

- `class CourseVisibility extends ChangeNotifier` — User classification, isolated by account and upstream system. SPOC and
  <sub>class · shared/course_visibility.dart:8</sub>
    - `final Future<void> Function(Set<String>)? save;`  <sub>:12</sub>
    - `final Future<Set<String>> Function()? load;`  <sub>:13</sub>
    - `bool ready = false;`  <sub>:15</sub>
    - `bool loadFailed = false;` — A failed read locks editing until an explicit retry succeeds, so a  <sub>:19</sub>
    - `void dispose() {…}`  <sub>:26</sub>
    - `void notifyListeners() {…}`  <sub>:32</sub>
    - `bool hidden(String system, String id) => …`  <sub>:39</sub>
    - `Future<void> restore() => …`  <sub>:41</sub>
    - `Future<void> retryRestore() {…}` — Explicit retry after a failed read. Re-opens the restore path and applies  <sub>:45</sub>
    - `Future<void> setHidden(String system, String id, bool hidden) {…}`  <sub>:82</sub>
- `class CourseVisibilityScope extends StatefulWidget`
  <sub>class · shared/course_visibility.dart:120</sub>
    - `const CourseVisibilityScope({ super.key, required this.account, required this.controllerFactory, required this.child, });`  <sub>:121</sub>
    - `final CourseVisibility Function(String account) controllerFactory;`  <sub>:128</sub>
    - `static CourseVisibility? of(BuildContext context) => …`  <sub>:130</sub>
    - `State<CourseVisibilityScope> createState() => …`  <sub>:134</sub>

## shared/homework_visibility.dart

- `List<HomeworkItem> personalHomeworkItems( Iterable<HomeworkItem> items, CourseVisibility? visibility, ) => …` — The dashboard, the full list and the reminder planner share one policy for
  <sub>function · shared/homework_visibility.dart:6</sub>

## shared/query_cache_scope.dart

- `class QueryCacheScope extends StatefulWidget` — Reset retained pages only after Rust has finished clearing its snapshots.
  <sub>class · shared/query_cache_scope.dart:5</sub>
    - `const QueryCacheScope({super.key, required this.child});`  <sub>:6</sub>
    - `static void invalidate(BuildContext context) => …`  <sub>:9</sub>
    - `State<QueryCacheScope> createState() => …`  <sub>:13</sub>

## shared/reminder_controller.dart

- `class ReminderController extends ChangeNotifier` — Account-scoped read receipts contain only digests, not school content.
  <sub>class · shared/reminder_controller.dart:22</sub>
    - `final Future<String> Function() tasksRoot;`  <sub>:43</sub>
    - `final DateTime Function() clock;`  <sub>:45</sub>
    - `bool checkinEnabled = true, homeworkEnabled = true;`  <sub>:56</sub>
    - `bool courseEnabled = false, taskEnabled = false;`  <sub>:58</sub>
    - `bool get busy => …`  <sub>:65</sub>
    - `bool get settingsReady => …`  <sub>:68</sub>
    - `bool get canRetryRestore => …`  <sub>:69</sub>
    - `int scheduled = 0;`  <sub>:70</sub>
    - `String digest(String key) => …`  <sub>:72</sub>
    - `Future<void> restore() async {…}`  <sub>:77</sub>
    - `void reportRestoreTimeout() {…}`  <sub>:122</sub>
    - `List<ReminderPlan> get plans => …`  <sub>:150</sub>
    - `int unread(String group) => …`  <sub>:162</sub>
    - `void markRead(String group) {…}`  <sub>:171</sub>
    - `void setActive(String group) {…}`  <sub>:189</sub>
    - `Future<void> setEnabled(String group, bool value) async {…}`  <sub>:194</sub>
    - `Future<void> updateSchedule(ScheduleResponse data) async {…}` — Failed or stale school reads never replace a previously accepted plan.  <sub>:222</sub>
    - `Future<void> updateTasks(List<LocalTaskRecord> tasks) async {…}`  <sub>:238</sub>
    - `void updateCheckin(CheckInResponse data) {…}`  <sub>:280</sub>
    - `void updateHomework(HomeworkResponse data) {…}`  <sub>:301</sub>
    - `Future<void> refresh({bool includeHomework = true}) async {…}`  <sub>:324</sub>
    - `Future<void> reconcile() {…}`  <sub>:413</sub>
    - `Future<void> reschedule() async {…}`  <sub>:495</sub>
    - `Future<void> stop() async {…}`  <sub>:500</sub>
    - `void dispose() {…}`  <sub>:515</sub>

## shared/reminder_rules.dart

- `DateTime? schoolInstant(String raw, {String? day}) {…}` — School wall-clock values are never interpreted in the device timezone.
  <sub>function · shared/reminder_rules.dart:6</sub>
- `bool checkinWindowOpen(CheckInCourse course, String day, DateTime now) => …` — Whether a check-in session accepts a sign-in right now.
  <sub>function · shared/reminder_rules.dart:19</sub>

## shared/reminder_scope.dart

- `class ReminderScope extends StatefulWidget` — 把 [ReminderController] 的作用域挂到子树上，并跟随应用生命周期启停。
  <sub>class · shared/reminder_scope.dart:15</sub>
    - `const ReminderScope({ super.key, required this.service, required this.account, required this.child, required this.controllerFactory, });`  <sub>:16</sub>
    - `final ReminderController Function( MirrorService service, String account, CourseVisibility? visibility, )` — The scope owns and disposes the returned controller.  <sub>:25</sub>
    - `static ReminderController? of(BuildContext context) => …`  <sub>:34</sub>
    - `static ReminderController? read(BuildContext context) => …`  <sub>:36</sub>
    - `State<ReminderScope> createState() => …`  <sub>:39</sub>

## shared/school_links.dart

- `Future<bool> openSchoolLink( String value, { required ExternalLinkLauncher launcher, }) async {…}`
  <sub>function · shared/school_links.dart:5</sub>

## shared/school_timestamp.dart

- `String schoolDateString(DateTime day) => …` — yyyy-MM-dd, the canonical query-date format the school systems accept.
  <sub>function · shared/school_timestamp.dart:16</sub>
- `String schoolDateWeekdayLabel(DateTime date) => …` — yyyy年M月d日 · 周X, the dated heading shared by list pages.
  <sub>function · shared/school_timestamp.dart:21</sub>
- `String schoolTimestampLabel(String? value) {…}` — MM月dd日 HH:mm in Beijing, with unknown and invalid inputs kept distinct.
  <sub>function · shared/school_timestamp.dart:25</sub>
- `String schoolClockLabel(String? value) {…}`
  <sub>function · shared/school_timestamp.dart:31</sub>
- `String schoolTimeRange(String beginsAt, String endsAt) {…}` — The page already labels the course day. Keep that day's times compact;
  <sub>function · shared/school_timestamp.dart:40</sub>

## shared/today_time.dart

- `DateTime todaySchoolNow(DateTime instant) => …` — UTC-shaped Beijing wall time; independent of the device timezone.
  <sub>function · shared/today_time.dart:4</sub>
- `int schoolWallClockMillis(DateTime value) {…}` — Absolute epoch milliseconds for a point the rules port was given.
  <sub>function · shared/today_time.dart:16</sub>
- `DateTime? todayDate(String value) {…}`
  <sub>function · shared/today_time.dart:22</sub>
- `DateTime? todayDue(String? value) {…}` — Presentation ordering and urgency only; never schedule an alarm from the
  <sub>function · shared/today_time.dart:36</sub>
- `int todayCompareDue(String? a, String? b) {…}`
  <sub>function · shared/today_time.dart:47</sub>
- `String todayDueLabel(String? value, DateTime now, {bool localTask = false}) {…}`
  <sub>function · shared/today_time.dart:54</sub>
