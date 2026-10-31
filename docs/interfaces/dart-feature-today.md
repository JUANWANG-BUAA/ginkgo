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
- [features/today/today_notice_section.dart](#featurestodaytodaynoticesectiondart) (1)
- [features/today/today_page.dart](#featurestodaytodaypagedart) (1)
- [features/today/today_page_actions.dart](#featurestodaytodaypageactionsdart) (2)
- [features/today/today_page_header.dart](#featurestodaytodaypageheaderdart) (1)
- [features/today/today_presentation.dart](#featurestodaytodaypresentationdart) (4)
- [features/today/today_tasks_section.dart](#featurestodaytodaytaskssectiondart) (2)

## features/today/today_action_row.dart

- `class TodayActionRow extends StatelessWidget` — Dashboard action rows reflow naturally and retain a 48dp minimum target.
  <sub>class · features/today/today_action_row.dart:6</sub>
    - `const TodayActionRow({ super.key, required this.title, this.subtitle, this.status, this.statusColor, this.trailing, this.onTap, this.emphasized = false, this.summary = false, this.caption = false, });`  <sub>:7</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:33</sub>

## features/today/today_checkin_section.dart

- `class TodayCheckInSection extends StatelessWidget` — The sign-in state of today's courses.
  <sub>class · features/today/today_checkin_section.dart:16</sub>
    - `const TodayCheckInSection({ super.key, required this.section, required this.onRetry, required this.onOpen, });`  <sub>:17</sub>
    - `static List<CheckInCourse> pendingCourses(CheckInResponse? data) {…}`  <sub>:28</sub>
    - `static StatusChip chip(CheckInStatus status) => …`  <sub>:40</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:47</sub>

## features/today/today_course_focus.dart

- `class TodayCourseWindow` — Presentation-only interpretation of the existing Today clock range.
  <sub>class · features/today/today_course_focus.dart:11</sub>
    - `const TodayCourseWindow(this.starts, this.ends);`  <sub>:12</sub>
    - `static TodayCourseWindow? parse(String date, String? time) {…}`  <sub>:15</sub>
    - `String status(DateTime now) => …`  <sub>:31</sub>
- `class TodayCourseFocus extends StatelessWidget`
  <sub>class · features/today/today_course_focus.dart:38</sub>
    - `const TodayCourseFocus({ super.key, required this.data, required this.now, this.onOpen, this.stale = false, });`  <sub>:39</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:52</sub>

## features/today/today_course_list.dart

- `class TodayCourseRow extends StatelessWidget` — Keep course times on a visible axis, like the native Today views. At large
  <sub>class · features/today/today_course_list.dart:10</sub>
    - `const TodayCourseRow({super.key, required this.course, required this.status});`  <sub>:11</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:16</sub>
- `class TodayCourseEmpty extends StatelessWidget` — Empty / unconfirmed course state. Large type stacks the identity above the
  <sub>class · features/today/today_course_list.dart:109</sub>
    - `const TodayCourseEmpty({ super.key, required this.error, required this.onOpenSchedule, });`  <sub>:110</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:120</sub>
- `class TodayCourseEmptyBadge extends StatelessWidget` — The icon tile that marks an empty or unconfirmed course list.
  <sub>class · features/today/today_course_list.dart:239</sub>
    - `const TodayCourseEmptyBadge({ super.key, required this.icon, required this.accent, required this.failed, required this.size, required this.iconSize, required this.radius, });`  <sub>:240</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:256</sub>

## features/today/today_course_section.dart

- `class TodayCoursePlaceholder extends StatelessWidget` — Shown until the first course payload lands. The section keeps the same
  <sub>class · features/today/today_course_section.dart:15</sub>
    - `const TodayCoursePlaceholder({ super.key, required this.loading, required this.error, required this.onRetry, });`  <sub>:16</sub>
    - `Widget build(BuildContext context) => …`  <sub>:28</sub>
- `class TodayCourseSection extends StatelessWidget` — The loaded "today's courses" section: heading, focus card, the expandable
  <sub>class · features/today/today_course_section.dart:44</sub>
    - `const TodayCourseSection({ super.key, required this.data, required this.now, required this.loading, required this.error, required this.expanded, required this.onToggleExpanded, required this.onRetry, this.onOpenSchedule, this.demo = false, });`  <sub>:45</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:71</sub>

## features/today/today_exam_section.dart

- `class TodayExamSection extends StatefulWidget`
  <sub>class · features/today/today_exam_section.dart:12</sub>
    - `const TodayExamSection({ super.key, required this.service, required this.now, this.refreshToken = 0, this.onOpen, });`  <sub>:13</sub>
    - `State<TodayExamSection> createState() => …`  <sub>:27</sub>

## features/today/today_homework_section.dart

- `List<HomeworkItem> todayVisibleHomework( HomeworkResponse? data, CourseVisibility? visibility, DateTime now, ) {…}` — The exact rows rendered on the dashboard, also used to avoid hiding an
  <sub>function · features/today/today_homework_section.dart:18</sub>
- `class TodayHomeworkSection extends StatelessWidget` — A separate read can finish before or after today's timetable.
  <sub>class · features/today/today_homework_section.dart:36</sub>
    - `const TodayHomeworkSection({ super.key, required this.section, required this.onRetry, this.onOpen, this.onOpenItem, this.now, });`  <sub>:37</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:54</sub>

## features/today/today_notice_section.dart

- `class TodayNoticeSection extends StatelessWidget` — The latest school notices. A publication date is never a personal
  <sub>class · features/today/today_notice_section.dart:13</sub>
    - `const TodayNoticeSection({ super.key, required this.section, required this.onRetry, required this.onOpen, });`  <sub>:14</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:26</sub>

## features/today/today_page.dart

- `class TodayPage extends StatefulWidget`
  <sub>class · features/today/today_page.dart:27</sub>
    - `const TodayPage({ super.key, required this.service, required this.fileActions, this.accountName, this.accountId, this.storageRoot, this.now, this.onAccountAction, this.onOpenFeature, this.onOpenSettings, });`  <sub>:28</sub>
    - `final DateTime Function()? now;` — An instant, converted to Beijing wall time for presentation.  <sub>:53</sub>
    - `final Future<void> Function()? onAccountAction;`  <sub>:54</sub>
    - `State<TodayPage> createState() => …`  <sub>:56</sub>

## features/today/today_page_actions.dart

- `class TodayNavigator` — Opens the pages the today dashboard links to. Only one route may be
  <sub>class · features/today/today_page_actions.dart:12</sub>
    - `bool get opening => …` — True while a linked page is being opened.  <sub>:16</sub>
    - `Future<void> openTasks( BuildContext context, { required MirrorService service, required PlatformActions fileActions, required String? storageRoot, required String? taskId, required bool Function() isCurrent, required Future<void> Function() reload, required void Function(String message) onFailure, }) async {…}`  <sub>:18</sub>
    - `Future<void> openHomework( BuildContext context, { required MirrorService service, required PlatformActions fileActions, required String? storageRoot, required HomeworkItem item, required bool Function() isCurrent, required Future<void> Function() reload, required void Function(String message) onFailure, }) async {…}`  <sub>:53</sub>
- `Future<bool> showTodayAccountDialog( BuildContext context, { required String? accountName, required bool demo, }) async {…}` — Ask what to do with the current account. Returns true when the user asked
  <sub>function · features/today/today_page_actions.dart:90</sub>

## features/today/today_page_header.dart

- `class TodayPageHeader extends StatelessWidget` — The today header carries the account / settings shortcut and the refresh
  <sub>class · features/today/today_page_header.dart:9</sub>
    - `const TodayPageHeader({ super.key, required this.title, required this.busy, required this.onRefresh, this.onOpenSettings, this.onAccountAction, this.demo = false, });`  <sub>:10</sub>
    - `Widget build(BuildContext context) => …`  <sub>:28</sub>

## features/today/today_presentation.dart

- `String todayCoursePlaceLabel(String? place) {…}` — Course fields the school left out stay readable: a missing place never
  <sub>function · features/today/today_presentation.dart:9</sub>
- `class TodayVisualDivider extends StatelessWidget` — A quiet inset rule for rows nested inside a reveal animation.
  <sub>class · features/today/today_presentation.dart:15</sub>
    - `const TodayVisualDivider({super.key});`  <sub>:16</sub>
    - `Widget build(BuildContext context) => …`  <sub>:19</sub>
- `class TodayVisualSection extends StatelessWidget` — Today-only typography and spacing; the shared section keeps its behavior.
  <sub>class · features/today/today_presentation.dart:31</sub>
    - `const TodayVisualSection({ super.key, required this.children, this.header, this.footer, });`  <sub>:32</sub>
    - `Widget build(BuildContext context) => …`  <sub>:43</sub>
- `class TodaySectionHeader extends StatelessWidget` — A structured section header with theme icon, bold title, count capsule badge,
  <sub>class · features/today/today_presentation.dart:70</sub>
    - `const TodaySectionHeader({ super.key, required this.title, this.icon, this.badge, this.actionLabel, this.actionKey, this.onAction, });`  <sub>:71</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:89</sub>

## features/today/today_tasks_section.dart

- `class TodayTasksSnapshot`
  <sub>class · features/today/today_tasks_section.dart:14</sub>
    - `const TodayTasksSnapshot(this.items, this.loadedAt);`  <sub>:15</sub>
- `class TodayTasksSection extends StatelessWidget`
  <sub>class · features/today/today_tasks_section.dart:20</sub>
    - `const TodayTasksSection({ super.key, required this.section, required this.now, required this.onRetry, required this.onOpen, this.visibleHomeworkIds = const {}, });`  <sub>:21</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:36</sub>
