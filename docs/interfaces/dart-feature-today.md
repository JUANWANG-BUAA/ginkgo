# Flutter 功能域：today

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
`flutter/lib/features/today/` 的页面、域内组件与模型。

## 目录

- [features/today/today_action_row.dart](#featurestodaytodayactionrowdart) (1)
- [features/today/today_checkin_section.dart](#featurestodaytodaycheckinsectiondart) (1)
- [features/today/today_course_focus.dart](#featurestodaytodaycoursefocusdart) (2)
- [features/today/today_course_list.dart](#featurestodaytodaycourselistdart) (3)
- [features/today/today_course_section.dart](#featurestodaytodaycoursesectiondart) (2)
- [features/today/today_exam_section.dart](#featurestodaytodayexamsectiondart) (1)
- [features/today/today_homework_section.dart](#featurestodaytodayhomeworksectiondart) (2)
- [features/today/today_page.dart](#featurestodaytodaypagedart) (1)
- [features/today/today_page_actions.dart](#featurestodaytodaypageactionsdart) (1)
- [features/today/today_page_header.dart](#featurestodaytodaypageheaderdart) (3)
- [features/today/today_presentation.dart](#featurestodaytodaypresentationdart) (1)
- [features/today/today_status_strip.dart](#featurestodaytodaystatusstripdart) (1)
- [features/today/today_tasks_section.dart](#featurestodaytodaytaskssectiondart) (2)

## features/today/today_action_row.dart

- `class TodayActionRow extends StatelessWidget` — Dashboard action rows reflow naturally and retain a 48dp minimum target.
  <sub>class · features/today/today_action_row.dart:7</sub>
    - `const TodayActionRow({ super.key, required this.title, this.subtitle, this.status, this.statusColor, this.trailing, this.onTap, this.emphasized = false, this.summary = false, this.caption = false, });`  <sub>:8</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:34</sub>

## features/today/today_checkin_section.dart

- `class TodayCheckInSection extends StatelessWidget` — The sign-in state of today's courses.
  <sub>class · features/today/today_checkin_section.dart:21</sub>
    - `const TodayCheckInSection({ super.key, required this.section, required this.now, required this.onRetry, required this.onOpen, this.hasCoursesToday = true, this.todaySchedule, this.homework, this.handledByCourses = false, this.fusedCourseIds = const {}, });`  <sub>:22</sub>
    - `static List<CheckInCourse> personalCourses( CheckInResponse? data, { CourseVisibility? visibility, HomeworkResponse? homework, TodayResponse? todaySchedule, }) => …`  <sub>:45</sub>
    - `static List<CheckInCourse> pendingCourses( CheckInResponse? data, { CourseVisibility? visibility, HomeworkResponse? homework, TodayResponse? todaySchedule, }) {…}`  <sub>:58</sub>
    - `static StatusChip chip(CheckInStatus status) => …`  <sub>:80</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:87</sub>

## features/today/today_course_focus.dart

- `class TodayCourseWindow` — Presentation-only interpretation of the existing Today clock range.
  <sub>class · features/today/today_course_focus.dart:15</sub>
    - `const TodayCourseWindow(this.starts, this.ends);`  <sub>:16</sub>
    - `static TodayCourseWindow? parse(String date, String? time) {…}`  <sub>:19</sub>
    - `String status(DateTime now) => …`  <sub>:35</sub>
- `class TodayCourseFocus extends StatelessWidget`
  <sub>class · features/today/today_course_focus.dart:42</sub>
    - `const TodayCourseFocus({ super.key, required this.data, required this.now, this.onOpen, this.stale = false, this.checkinCourses = const [], this.onOpenCheckIn, });`  <sub>:43</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:63</sub>

## features/today/today_course_list.dart

- `class TodayCourseRow extends StatelessWidget` — Keep course times on a visible axis, like the native Today views. At large
  <sub>class · features/today/today_course_list.dart:11</sub>
    - `const TodayCourseRow({ super.key, required this.course, required this.status, this.checkin, this.onOpenCheckIn, });`  <sub>:12</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:25</sub>
- `class TodayCourseEmpty extends StatelessWidget` — Empty / unconfirmed course state. Large type stacks the identity above the
  <sub>class · features/today/today_course_list.dart:187</sub>
    - `const TodayCourseEmpty({ super.key, required this.error, required this.onOpenSchedule, });`  <sub>:188</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:198</sub>
- `class TodayCourseEmptyBadge extends StatelessWidget` — The icon tile that marks an empty or unconfirmed course list.
  <sub>class · features/today/today_course_list.dart:317</sub>
    - `const TodayCourseEmptyBadge({ super.key, required this.icon, required this.accent, required this.failed, required this.size, required this.iconSize, required this.radius, });`  <sub>:318</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:334</sub>

## features/today/today_course_section.dart

- `class TodayCoursePlaceholder extends StatelessWidget` — Shown until the first course payload lands. The section keeps the same
  <sub>class · features/today/today_course_section.dart:18</sub>
    - `const TodayCoursePlaceholder({ super.key, required this.loading, required this.error, required this.onRetry, });`  <sub>:19</sub>
    - `Widget build(BuildContext context) => …`  <sub>:31</sub>
- `class TodayCourseSection extends StatelessWidget` — The loaded "today's courses" section: timeline focus card, fused inline
  <sub>class · features/today/today_course_section.dart:47</sub>
    - `const TodayCourseSection({ super.key, required this.data, required this.now, required this.loading, required this.error, required this.expanded, required this.onToggleExpanded, required this.onRetry, this.onOpenSchedule, this.demo = false, this.checkinSection, this.checkinCourses = const [], this.onCheckInRetry, this.onOpenCheckIn, });`  <sub>:48</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:82</sub>

## features/today/today_exam_section.dart

- `class TodayExamSection extends StatefulWidget`
  <sub>class · features/today/today_exam_section.dart:13</sub>
    - `const TodayExamSection({ super.key, required this.service, required this.now, this.refreshToken = 0, this.onOpen, this.onVisibilityChanged, this.onWeekNumberChanged, });`  <sub>:14</sub>
    - `State<TodayExamSection> createState() => …`  <sub>:32</sub>

## features/today/today_homework_section.dart

- `List<HomeworkItem> todayVisibleHomework( HomeworkResponse? data, CourseVisibility? visibility, DateTime now, ) {…}` — The exact rows rendered on the dashboard, also used to avoid hiding an
  <sub>function · features/today/today_homework_section.dart:18</sub>
- `class TodayHomeworkSection extends StatelessWidget` — A separate read can finish before or after today's timetable.
  <sub>class · features/today/today_homework_section.dart:40</sub>
    - `const TodayHomeworkSection({ super.key, required this.section, required this.onRetry, this.onOpen, this.onOpenItem, this.now, });`  <sub>:41</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:58</sub>

## features/today/today_page.dart

- `class TodayPage extends StatefulWidget`
  <sub>class · features/today/today_page.dart:33</sub>
    - `const TodayPage({ super.key, required this.service, required this.fileActions, this.accountName, this.accountId, this.storageRoot, this.now, this.onOpenFeature, });`  <sub>:34</sub>
    - `final DateTime Function()? now;` — An instant, converted to Beijing wall time for presentation.  <sub>:56</sub>
    - `State<TodayPage> createState() => …`  <sub>:58</sub>

## features/today/today_page_actions.dart

- `class TodayNavigator` — Opens the pages the today dashboard links to. Only one route may be
  <sub>class · features/today/today_page_actions.dart:12</sub>
    - `bool get opening => …` — True while a linked page is being opened.  <sub>:16</sub>
    - `Future<void> openTasks( BuildContext context, { required MirrorService service, required PlatformActions fileActions, required String? storageRoot, required String? taskId, required bool Function() isCurrent, required Future<void> Function() reload, required void Function(String message) onFailure, }) async {…}`  <sub>:18</sub>
    - `Future<void> openHomework( BuildContext context, { required MirrorService service, required PlatformActions fileActions, required String? storageRoot, required HomeworkItem item, required bool Function() isCurrent, required Future<void> Function() reload, required void Function(String message) onFailure, }) async {…}`  <sub>:53</sub>

## features/today/today_page_header.dart

- `class TodayPageHeader extends StatelessWidget` — The today header carries the current school date context and page refresh
  <sub>class · features/today/today_page_header.dart:10</sub>
    - `const TodayPageHeader({ super.key, required this.title, this.dateLabel, required this.busy, required this.onRefresh, });`  <sub>:11</sub>
    - `Widget build(BuildContext context) => …`  <sub>:25</sub>
- `class TodayDateContext extends StatelessWidget` — Compact date and academic-week anchor shown directly beneath the mobile
  <sub>class · features/today/today_page_header.dart:44</sub>
    - `const TodayDateContext({super.key, required this.label});`  <sub>:45</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:50</sub>
- `class TodayAllQuietView extends StatelessWidget` — Calm all-clear view shown on days with no classes, homework, exams or tasks.
  <sub>class · features/today/today_page_header.dart:67</sub>
    - `const TodayAllQuietView({super.key, required this.now});`  <sub>:68</sub>
    - `Widget build(BuildContext context) => …`  <sub>:73</sub>

## features/today/today_presentation.dart

- `String todayCoursePlaceLabel(String? place) {…}` — Course fields the school left out stay readable: a missing place never
  <sub>function · features/today/today_presentation.dart:7</sub>

## features/today/today_status_strip.dart

- `class TodayStatusStrip extends StatelessWidget` — Compact single-line status bar at the top of TodayPage: keeps next-course
  <sub>class · features/today/today_status_strip.dart:13</sub>
    - `const TodayStatusStrip({ super.key, required this.demo, required this.loadingLabels, required this.readySections, required this.errorSections, required this.routeRevision, this.captivePortal = false, this.onOpenWifiSettings, this.verifiedRoute, this.tracker, this.onOpenDiagnostics, });`  <sub>:14</sub>
    - `final Future<bool> Function()? onOpenWifiSettings;`  <sub>:34</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:40</sub>

## features/today/today_tasks_section.dart

- `class TodayTasksSnapshot`
  <sub>class · features/today/today_tasks_section.dart:16</sub>
    - `const TodayTasksSnapshot(this.items, this.loadedAt);`  <sub>:17</sub>
- `class TodayTasksSection extends StatelessWidget`
  <sub>class · features/today/today_tasks_section.dart:22</sub>
    - `const TodayTasksSection({ super.key, required this.section, required this.now, required this.onRetry, required this.onOpen, this.visibleHomeworkIds = const {}, });`  <sub>:23</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:38</sub>
