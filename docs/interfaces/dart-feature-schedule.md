# Flutter 功能域：schedule

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
`flutter/lib/features/schedule/` 的页面、域内组件与模型。

## 目录

- [features/schedule/course_range_page.dart](#featuresschedulecourserangepagedart) (1)
- [features/schedule/schedule_controls.dart](#featuresscheduleschedulecontrolsdart) (1)
- [features/schedule/schedule_course_detail.dart](#featuresscheduleschedulecoursedetaildart) (1)
- [features/schedule/schedule_day_strip.dart](#featuresschedulescheduledaystripdart) (1)
- [features/schedule/schedule_grid.dart](#featuresscheduleschedulegriddart) (1)
- [features/schedule/schedule_grid_course_block.dart](#featuresscheduleschedulegridcourseblockdart) (1)
- [features/schedule/schedule_grid_layout.dart](#featuresscheduleschedulegridlayoutdart) (1)
- [features/schedule/schedule_page.dart](#featuresscheduleschedulepagedart) (1)
- [features/schedule/schedule_style.dart](#featuresscheduleschedulestyledart) (6)
- [features/schedule/schedule_views.dart](#featuresschedulescheduleviewsdart) (3)
- [features/schedule/schedule_week_strip.dart](#featuresschedulescheduleweekstripdart) (1)
- [features/schedule/schedule_widgets.dart](#featuresscheduleschedulewidgetsdart) (8)

## features/schedule/course_range_page.dart

- `class CourseRangePage extends StatelessWidget`
  <sub>class · features/schedule/course_range_page.dart:8</sub>
    - `const CourseRangePage({ super.key, required this.preferences, required this.system, required this.courses, });`  <sub>:9</sub>
    - `Widget build(BuildContext context) => …`  <sub>:19</sub>

## features/schedule/schedule_controls.dart

- `class ScheduleControls extends StatelessWidget` — Term and week pickers shown above the schedule content.
  <sub>class · features/schedule/schedule_controls.dart:15</sub>
    - `const ScheduleControls({ super.key, required this.snapshot, required this.terms, required this.weeks, required this.selectedTerm, required this.selectedWeek, required this.onSelectTerm, required this.onSelectWeek, });`  <sub>:16</sub>
    - `final Future<void> Function(String termId) onSelectTerm;`  <sub>:31</sub>
    - `final void Function(int week) onSelectWeek;`  <sub>:32</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:35</sub>

## features/schedule/schedule_course_detail.dart

- `class ScheduleCourseDetailPage extends StatelessWidget` — The pushed course detail page.
  <sub>class · features/schedule/schedule_course_detail.dart:12</sub>
    - `const ScheduleCourseDetailPage({ super.key, required this.course, required this.termName, required this.weekNumber, required this.week, required this.dayTitle, });`  <sub>:13</sub>
    - `Widget build(BuildContext context) => …`  <sub>:28</sub>

## features/schedule/schedule_day_strip.dart

- `class ScheduleDayStrip extends StatelessWidget`
  <sub>class · features/schedule/schedule_day_strip.dart:5</sub>
    - `const ScheduleDayStrip({ super.key, required this.weekStart, required this.selectedDay, required this.onSelected, });`  <sub>:6</sub>
    - `Widget build(BuildContext context) => …`  <sub>:18</sub>

## features/schedule/schedule_grid.dart

- `class ScheduleGrid extends StatefulWidget` — Seven-day timetable grid. Course blocks span their section range and open
  <sub>class · features/schedule/schedule_grid.dart:16</sub>
    - `const ScheduleGrid({ super.key, required this.courses, required this.onCourseTap, this.weekStart, });`  <sub>:17</sub>
    - `State<ScheduleGrid> createState() => …`  <sub>:28</sub>

## features/schedule/schedule_grid_course_block.dart

- `class ScheduleGridCourseBlock extends StatelessWidget` — One course block inside the timetable grid.
  <sub>class · features/schedule/schedule_grid_course_block.dart:10</sub>
    - `const ScheduleGridCourseBlock({ super.key, required this.course, required this.onTap, });`  <sub>:11</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:20</sub>

## features/schedule/schedule_grid_layout.dart

- `class ScheduleGridLayout` — Where each course sits inside its day column, plus the section times.
  <sub>class · features/schedule/schedule_grid_layout.dart:21</sub>
    - `const ScheduleGridLayout({required this.placements, required this.times});`  <sub>:22</sub>

## features/schedule/schedule_page.dart

- `class SchedulePage extends StatefulWidget`
  <sub>class · features/schedule/schedule_page.dart:16</sub>
    - `const SchedulePage({super.key, required this.service});`  <sub>:17</sub>
    - `State<SchedulePage> createState() => …`  <sub>:20</sub>

## features/schedule/schedule_style.dart

- `TextStyle scheduleSecondary(BuildContext context) => …` — Quiet secondary text used across the schedule surface.
  <sub>function · features/schedule/schedule_style.dart:10</sub>
- `Color courseColor(BuildContext context, String? value, [String name = '']) {…}`
  <sub>function · features/schedule/schedule_style.dart:15</sub>
- `String courseDetail(ScheduleCourse course) {…}`
  <sub>function · features/schedule/schedule_style.dart:40</sub>
- `String shortDate(String date) {…}`
  <sub>function · features/schedule/schedule_style.dart:50</sub>
- `int? scheduleTodayColumn(String? weekStart) {…}` — Column of today inside a week that starts on [weekStart], counting from 1.
  <sub>function · features/schedule/schedule_style.dart:61</sub>
- `String scheduleDayTitle(int day, String? weekStart) {…}` — Title of one weekday inside a week, e.g. `周一 · 10/19 · 今天`.
  <sub>function · features/schedule/schedule_style.dart:74</sub>

## features/schedule/schedule_views.dart

- `class ScheduleCourseBrowser extends StatelessWidget` — The courses of the confirmed week: a search field plus either the weekly
  <sub>class · features/schedule/schedule_views.dart:13</sub>
    - `const ScheduleCourseBrowser({ super.key, required this.snapshot, required this.courses, required this.days, required this.weeks, required this.mode, required this.search, required this.selectedDay, required this.onSelectedDay, required this.onSearchChanged, required this.onCourseTap, });`  <sub>:14</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:39</sub>
- `class ScheduleSemesterWeeks extends StatelessWidget` — The teaching weeks of the term.
  <sub>class · features/schedule/schedule_views.dart:129</sub>
    - `const ScheduleSemesterWeeks({ super.key, required this.weeks, required this.onSelected, });`  <sub>:130</sub>
    - `Widget build(BuildContext context) => …`  <sub>:139</sub>
- `class ScheduleExamList extends StatelessWidget` — The exam schedule of the term.
  <sub>class · features/schedule/schedule_views.dart:171</sub>
    - `const ScheduleExamList({super.key, required this.exams});`  <sub>:172</sub>
    - `Widget build(BuildContext context) => …`  <sub>:176</sub>

## features/schedule/schedule_week_strip.dart

- `class ScheduleWeekStrip extends StatefulWidget` — Owns week-chip measurement, scrolling and post-layout synchronization.
  <sub>class · features/schedule/schedule_week_strip.dart:7</sub>
    - `const ScheduleWeekStrip({ super.key, required this.weeks, required this.selectedWeek, required this.onSelected, });`  <sub>:8</sub>
    - `State<ScheduleWeekStrip> createState() => …`  <sub>:18</sub>

## features/schedule/schedule_widgets.dart

- `enum ScheduleViewMode` — How the schedule page presents the confirmed snapshot.
  <sub>enum · features/schedule/schedule_widgets.dart:14</sub>
- `String scheduleViewModeLabel(ScheduleViewMode mode) => …` — Short label of a view mode.
  <sub>function · features/schedule/schedule_widgets.dart:29</sub>
- `String scheduleViewModeDescription(ScheduleViewMode mode) => …` — Label of a view mode in the large-text picker, where the grid hint has to
  <sub>function · features/schedule/schedule_widgets.dart:38</sub>
- `class ScheduleCourseRow extends StatelessWidget` — One course in the day list. Large type stacks the time above the content;
  <sub>class · features/schedule/schedule_widgets.dart:47</sub>
    - `const ScheduleCourseRow({super.key, required this.course, this.onTap});`  <sub>:48</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:53</sub>
- `class ScheduleDetailLine extends StatelessWidget` — One label/value line in the pushed course detail page.
  <sub>class · features/schedule/schedule_widgets.dart:140</sub>
    - `const ScheduleDetailLine({ super.key, required this.label, required this.value, });`  <sub>:141</sub>
    - `Widget build(BuildContext context) => …`  <sub>:148</sub>
- `class ScheduleChevronRow extends StatelessWidget` — A tappable row that reveals the next screen, with a trailing chevron.
  <sub>class · features/schedule/schedule_widgets.dart:165</sub>
    - `const ScheduleChevronRow({ super.key, required this.child, required this.onTap, });`  <sub>:166</sub>
    - `Widget build(BuildContext context) => …`  <sub>:175</sub>
- `class ScheduleSection extends StatelessWidget` — A group of rows under an optional section title.
  <sub>class · features/schedule/schedule_widgets.dart:200</sub>
    - `const ScheduleSection({ super.key, required this.children, this.title, this.footer, });`  <sub>:201</sub>
    - `Widget build(BuildContext context) => …`  <sub>:212</sub>
- `class ScheduleLoadingSection extends StatelessWidget` — A section that reports the first load of a snapshot.
  <sub>class · features/schedule/schedule_widgets.dart:220</sub>
    - `const ScheduleLoadingSection({super.key, this.label = '正在读取课表…'});`  <sub>:221</sub>
    - `Widget build(BuildContext context) => …`  <sub>:225</sub>
