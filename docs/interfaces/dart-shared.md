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
- [shared/reminder_rules.dart](#sharedreminderrulesdart) (5)
- [shared/reminder_scope.dart](#sharedreminderscopedart) (1)
- [shared/school_links.dart](#sharedschoollinksdart) (2)
- [shared/school_timestamp.dart](#sharedschooltimestampdart) (6)
- [shared/today_time.dart](#sharedtodaytimedart) (5)

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
    - `Future<void> update({ AppAppearance? appearance, AppAccent? accent, bool? compactLists, bool? reduceMotion, double? textSize, }) {…}`  <sub>:145</sub>
    - `Future<void> setExplicitSignOut(bool value) {…}` — Records or clears the explicit sign-out marker with the same serialized  <sub>:162</sub>
- `class AppPreferencesScope extends InheritedNotifier<AppPreferences>`
  <sub>class · shared/app_preferences.dart:170</sub>
    - `const AppPreferencesScope({ super.key, required AppPreferences preferences, required super.child, }) : super(notifier: preferences);`  <sub>:171</sub>
    - `static AppPreferences of(BuildContext context) => …`  <sub>:177</sub>

## shared/checkin_sessions.dart

- `String checkinSessionKey(CheckInCourse course) => …`
  <sub>function · shared/checkin_sessions.dart:3</sub>
- `List<CheckInCourse> uniqueCheckinSessions(Iterable<CheckInCourse> courses) {…}`
  <sub>function · shared/checkin_sessions.dart:5</sub>

## shared/course_visibility.dart

- `class CourseVisibility extends ChangeNotifier` — User classification, isolated by account and upstream system. SPOC and
  <sub>class · shared/course_visibility.dart:11</sub>
    - `final Future<void> Function(Set<String>)? save;`  <sub>:14</sub>
    - `final Future<Set<String>> Function()? load;`  <sub>:15</sub>
    - `bool ready = false;`  <sub>:17</sub>
    - `bool loadFailed = false;` — A failed read locks editing until an explicit retry succeeds, so a  <sub>:21</sub>
    - `void dispose() {…}`  <sub>:28</sub>
    - `void notifyListeners() {…}`  <sub>:34</sub>
    - `bool hidden(String system, String id) => …`  <sub>:47</sub>
    - `Future<void> restore() => …`  <sub>:49</sub>
    - `Future<void> retryRestore() {…}` — Explicit retry after a failed read. Re-opens the restore path and applies  <sub>:53</sub>
    - `Future<void> setHidden(String system, String id, bool hidden) {…}`  <sub>:99</sub>
- `class CourseVisibilityScope extends StatefulWidget`
  <sub>class · shared/course_visibility.dart:135</sub>
    - `const CourseVisibilityScope({ super.key, required this.account, required this.child, });`  <sub>:136</sub>
    - `static CourseVisibility? of(BuildContext context) => …`  <sub>:143</sub>
    - `State<CourseVisibilityScope> createState() => …`  <sub>:147</sub>

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
  <sub>class · shared/reminder_controller.dart:23</sub>
    - `final Future<String> Function() tasksRoot;`  <sub>:44</sub>
    - `final DateTime Function() clock;`  <sub>:46</sub>
    - `bool checkinEnabled = true, homeworkEnabled = true;`  <sub>:52</sub>
    - `bool courseEnabled = false, taskEnabled = false;`  <sub>:54</sub>
    - `bool get busy => …`  <sub>:61</sub>
    - `bool get settingsReady => …`  <sub>:64</sub>
    - `bool get canRetryRestore => …`  <sub>:65</sub>
    - `int scheduled = 0;`  <sub>:66</sub>
    - `String digest(String key) => …`  <sub>:68</sub>
    - `Future<void> restore() async {…}`  <sub>:73</sub>
    - `void reportRestoreTimeout() {…}`  <sub>:118</sub>
    - `List<ReminderPlan> get plans => …`  <sub>:146</sub>
    - `int unread(String group) => …`  <sub>:158</sub>
    - `void markRead(String group) {…}`  <sub>:167</sub>
    - `void setActive(String group) {…}`  <sub>:185</sub>
    - `Future<void> setEnabled(String group, bool value) async {…}`  <sub>:190</sub>
    - `Future<void> updateSchedule(ScheduleResponse data) async {…}` — Failed or stale school reads never replace a previously accepted plan.  <sub>:217</sub>
    - `Future<void> updateTasks(List<LocalTaskRecord> tasks) async {…}`  <sub>:233</sub>
    - `void updateCheckin(CheckInResponse data) {…}`  <sub>:274</sub>
    - `void updateHomework(HomeworkResponse data) {…}`  <sub>:278</sub>
    - `Future<void> refresh({bool includeHomework = true}) async {…}`  <sub>:287</sub>
    - `Future<void> reconcile() {…}`  <sub>:372</sub>
    - `Future<void> reschedule() async {…}`  <sub>:419</sub>
    - `Future<void> stop() async {…}`  <sub>:424</sub>
    - `void dispose() {…}`  <sub>:430</sub>

## shared/reminder_rules.dart

- `DateTime? schoolInstant(String raw, {String? day}) {…}` — School wall-clock values are never interpreted in the device timezone.
  <sub>function · shared/reminder_rules.dart:6</sub>
- `bool checkinWindowOpen(CheckInCourse course, String day, DateTime now) {…}`
  <sub>function · shared/reminder_rules.dart:19</sub>
- `class ReminderPlan`
  <sub>class · shared/reminder_rules.dart:36</sub>
    - `const ReminderPlan({ required this.key, required this.group, required this.at, required this.expires, });`  <sub>:37</sub>
- `List<ReminderPlan> checkinReminders(CheckInResponse data) => …`
  <sub>function · shared/reminder_rules.dart:47</sub>
- `List<ReminderPlan> homeworkReminders( Iterable<HomeworkItem> items, DateTime now, ) {…}`
  <sub>function · shared/reminder_rules.dart:66</sub>

## shared/reminder_scope.dart

- `class ReminderScope extends StatefulWidget` — 把 [ReminderController] 的作用域挂到子树上，并跟随应用生命周期启停。
  <sub>class · shared/reminder_scope.dart:15</sub>
    - `const ReminderScope({ super.key, required this.service, required this.account, required this.child, required this.controllerFactory, });`  <sub>:16</sub>
    - `final ReminderController Function( MirrorService service, String account, CourseVisibility? visibility, )` — The scope owns and disposes the returned controller.  <sub>:25</sub>
    - `static ReminderController? of(BuildContext context) => …`  <sub>:34</sub>
    - `static ReminderController? read(BuildContext context) => …`  <sub>:36</sub>
    - `State<ReminderScope> createState() => …`  <sub>:39</sub>

## shared/school_links.dart

- `Future<bool> openSchoolLink( String value, { Future<bool> Function(Uri url)? launcher, }) async {…}`
  <sub>function · shared/school_links.dart:6</sub>
- `Future<void> showSchoolLinkError(BuildContext context) => …`
  <sub>function · shared/school_links.dart:25</sub>

## shared/school_timestamp.dart

- `DateTime? parseSchoolTimestamp(String? value) {…}` — Presentation-only school time. Unzoned upstream values already describe
  <sub>function · shared/school_timestamp.dart:3</sub>
- `String schoolDateString(DateTime day) => …` — yyyy-MM-dd, the canonical query-date format the school systems accept.
  <sub>function · shared/school_timestamp.dart:40</sub>
- `String schoolDateWeekdayLabel(DateTime date) => …` — yyyy年M月d日 · 周X, the dated heading shared by list pages.
  <sub>function · shared/school_timestamp.dart:45</sub>
- `String schoolTimestampLabel(String? value) {…}` — MM月dd日 HH:mm in Beijing, with unknown and invalid inputs kept distinct.
  <sub>function · shared/school_timestamp.dart:49</sub>
- `String schoolClockLabel(String? value) {…}`
  <sub>function · shared/school_timestamp.dart:55</sub>
- `String schoolTimeRange(String beginsAt, String endsAt) {…}` — The page already labels the course day. Keep that day's times compact;
  <sub>function · shared/school_timestamp.dart:64</sub>

## shared/today_time.dart

- `DateTime todaySchoolNow(DateTime instant) => …` — UTC-shaped Beijing wall time; independent of the device timezone.
  <sub>function · shared/today_time.dart:4</sub>
- `DateTime? todayDate(String value) {…}`
  <sub>function · shared/today_time.dart:7</sub>
- `DateTime? todayDue(String? value) {…}` — Presentation ordering and urgency only; never schedule an alarm from the
  <sub>function · shared/today_time.dart:21</sub>
- `int todayCompareDue(String? a, String? b) {…}`
  <sub>function · shared/today_time.dart:32</sub>
- `String todayDueLabel(String? value, DateTime now, {bool localTask = false}) {…}`
  <sub>function · shared/today_time.dart:39</sub>
