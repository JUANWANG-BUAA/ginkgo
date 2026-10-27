# Flutter 功能域：today

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。

`flutter/lib/features/today/` 的页面、域内组件与模型。

## 目录

- [features/today/today_action_row.dart](#featurestodaytodayactionrowdart) (1)
- [features/today/today_course_focus.dart](#featurestodaytodaycoursefocusdart) (2)
- [features/today/today_course_list.dart](#featurestodaytodaycourselistdart) (3)
- [features/today/today_course_section.dart](#featurestodaytodaycoursesectiondart) (2)
- [features/today/today_homework_section.dart](#featurestodaytodayhomeworksectiondart) (1)
- [features/today/today_page.dart](#featurestodaytodaypagedart) (1)
- [features/today/today_page_actions.dart](#featurestodaytodaypageactionsdart) (1)
- [features/today/today_page_header.dart](#featurestodaytodaypageheaderdart) (1)
- [features/today/today_presentation.dart](#featurestodaytodaypresentationdart) (3)
- [features/today/today_tasks_section.dart](#featurestodaytodaytaskssectiondart) (2)

## features/today/today_action_row.dart

- `class TodayActionRow extends StatelessWidget` — Dashboard action rows reflow naturally and retain a 48dp minimum target.  
  <sub>class · features/today/today_action_row.dart:6</sub>
    - `const TodayActionRow( {…}`  <sub>:7</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:29</sub>

## features/today/today_course_focus.dart

- `class TodayCourseWindow` — Presentation-only interpretation of the existing Today clock range.  
  <sub>class · features/today/today_course_focus.dart:11</sub>
    - `const TodayCourseWindow(this.starts, this.ends);`  <sub>:12</sub>
    - `static TodayCourseWindow? parse(String date, String? time) {…}`  <sub>:15</sub>
    - `String status(DateTime now) => now.isBefore(starts) ? '尚未开始'`  <sub>:31</sub>
- `class TodayCourseFocus extends StatelessWidget`  
  <sub>class · features/today/today_course_focus.dart:38</sub>
    - `const TodayCourseFocus( {…}`  <sub>:39</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:52</sub>

## features/today/today_course_list.dart

- `class TodayCourseRow extends StatelessWidget` — Keep course times on a visible axis, like the native Today views. At large  
  <sub>class · features/today/today_course_list.dart:10</sub>
    - `const TodayCourseRow( {…}`  <sub>:11</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:16</sub>
- `class TodayCourseEmpty extends StatelessWidget` — Empty / unconfirmed course state. Large type stacks the identity above the  
  <sub>class · features/today/today_course_list.dart:109</sub>
    - `const TodayCourseEmpty( {…}`  <sub>:110</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:120</sub>
- `class TodayCourseEmptyBadge extends StatelessWidget` — The icon tile that marks an empty or unconfirmed course list.  
  <sub>class · features/today/today_course_list.dart:239</sub>
    - `const TodayCourseEmptyBadge( {…}`  <sub>:240</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:256</sub>

## features/today/today_course_section.dart

- `class TodayCoursePlaceholder extends StatelessWidget` — Shown until the first course payload lands. The section keeps the same  
  <sub>class · features/today/today_course_section.dart:15</sub>
    - `const TodayCoursePlaceholder( {…}`  <sub>:16</sub>
    - `Widget build(BuildContext context) => TodayVisualSection( header: const Text('今日课程'), c … …', hasData: false, error: error, onRetry: onRetry, ), ], );`  <sub>:28</sub>
- `class TodayCourseSection extends StatelessWidget` — The loaded "today's courses" section: heading, focus card, the expandable  
  <sub>class · features/today/today_course_section.dart:44</sub>
    - `const TodayCourseSection( {…}`  <sub>:45</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:71</sub>

## features/today/today_homework_section.dart

- `class TodayHomeworkSection extends StatelessWidget` — A separate read can finish before or after today's timetable.  
  <sub>class · features/today/today_homework_section.dart:13</sub>
    - `const TodayHomeworkSection( {…}`  <sub>:14</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:31</sub>

## features/today/today_page.dart

- `class TodayPage extends StatefulWidget`  
  <sub>class · features/today/today_page.dart:21</sub>
    - `const TodayPage( {…}`  <sub>:22</sub>
    - `final DateTime Function()? now;` — An instant, converted to Beijing wall time for presentation.  <sub>:47</sub>
    - `final Future<void> Function()? onAccountAction;`  <sub>:48</sub>
    - `State<TodayPage> createState() => _TodayPageState();`  <sub>:50</sub>

## features/today/today_page_actions.dart

- `class TodayNavigator` — Opens the pages the today dashboard links to. Only one route may be  
  <sub>class · features/today/today_page_actions.dart:12</sub>
    - `bool get opening => _opening;` — True while a linked page is being opened.  <sub>:16</sub>
    - `Future<void> openTasks( BuildContext context, {…}`  <sub>:18</sub>
    - `Future<void> openHomework( BuildContext context, {…}`  <sub>:53</sub>

## features/today/today_page_header.dart

- `class TodayPageHeader extends StatelessWidget` — The today header carries the account / settings shortcut and the refresh  
  <sub>class · features/today/today_page_header.dart:9</sub>
    - `const TodayPageHeader( {…}`  <sub>:10</sub>
    - `Widget build(BuildContext context) => ApplePageHeader( largeTitle: Text(title), border: … : const Icon(CupertinoIcons.refresh, size: 24), ), ], ), );`  <sub>:28</sub>

## features/today/today_presentation.dart

- `class TodayVisualDivider extends StatelessWidget` — A quiet inset rule for rows nested inside a reveal animation.  
  <sub>class · features/today/today_presentation.dart:16</sub>
    - `const TodayVisualDivider( {…}`  <sub>:17</sub>
    - `Widget build(BuildContext context) => Padding( padding: GinkgoSpacing.edgeInsetsPage, c … : const SizedBox(height: 0.5, width: double.infinity), ), );`  <sub>:20</sub>
- `class TodayVisualSection extends StatelessWidget` — Today-only typography and spacing; the shared section keeps its behavior.  
  <sub>class · features/today/today_presentation.dart:32</sub>
    - `const TodayVisualSection( {…}`  <sub>:33</sub>
    - `Widget build(BuildContext context) => Padding( padding: EdgeInsets.only(top: AppleDesig … om(context), ), child: footer!, ), children: children, ), );`  <sub>:44</sub>
- `class TodaySectionHeader extends StatelessWidget` — A structured section header with theme icon, bold title, count capsule badge,  
  <sub>class · features/today/today_presentation.dart:71</sub>
    - `const TodaySectionHeader( {…}`  <sub>:72</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:88</sub>

## features/today/today_tasks_section.dart

- `class TodayTasksSnapshot`  
  <sub>class · features/today/today_tasks_section.dart:11</sub>
    - `const TodayTasksSnapshot(this.items, this.loadedAt);`  <sub>:12</sub>
- `class TodayTasksSection extends StatelessWidget`  
  <sub>class · features/today/today_tasks_section.dart:17</sub>
    - `const TodayTasksSection( {…}`  <sub>:18</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:31</sub>
