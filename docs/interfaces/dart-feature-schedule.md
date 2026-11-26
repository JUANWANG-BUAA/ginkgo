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
    - `const CourseRangePage({ super.key, required this.preferences, required this.system, required this.courses, this.courseRoles = const {}, });`  <sub>:9</sub>
    - `Widget build(BuildContext context) => …`  <sub>:21</sub>

## features/schedule/schedule_controls.dart

- `class ScheduleControls extends StatelessWidget` — Compact iOS Calendar-style top header replacing stacked title & control cards.
  <sub>class · features/schedule/schedule_controls.dart:11</sub>
    - `const ScheduleControls({ super.key, required this.snapshot, required this.terms, required this.weeks, required this.selectedTerm, required this.selectedWeek, required this.busy, required this.searchActive, required this.onSelectTerm, required this.onSelectWeek, required this.onToggleSearch, required this.onRefresh, this.onExportIcs, });`  <sub>:12</sub>
    - `final Future<void> Function(String termId) onSelectTerm;`  <sub>:34</sub>
    - `final void Function(int week) onSelectWeek;`  <sub>:35</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:41</sub>

## features/schedule/schedule_course_detail.dart

- `class ScheduleCourseDetailPage extends StatelessWidget` — The pushed course detail page.
  <sub>class · features/schedule/schedule_course_detail.dart:14</sub>
    - `const ScheduleCourseDetailPage({ super.key, required this.course, required this.termName, required this.weekNumber, required this.week, required this.dayTitle, this.onOpenCheckIn, });`  <sub>:15</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:32</sub>

## features/schedule/schedule_day_strip.dart

- `class ScheduleDayStrip extends StatelessWidget` — iOS Apple Calendar-style 7-day circular date selector with colored course
  <sub>class · features/schedule/schedule_day_strip.dart:12</sub>
    - `const ScheduleDayStrip({ super.key, required this.weekStart, required this.selectedDay, required this.onSelected, this.dayCourses = const {}, });`  <sub>:13</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:27</sub>

## features/schedule/schedule_grid.dart

- `class ScheduleGrid extends StatefulWidget` — Full-week 7-column iOS timetable card.
  <sub>class · features/schedule/schedule_grid.dart:20</sub>
    - `const ScheduleGrid({ super.key, required this.courses, required this.onCourseTap, this.onConflictTap, this.onSwipeWeek, this.weekStart, });`  <sub>:21</sub>
    - `State<ScheduleGrid> createState() => …`  <sub>:36</sub>

## features/schedule/schedule_grid_course_block.dart

- `class ScheduleGridCourseBlock extends StatelessWidget` — Pastel iOS timetable block with a saturated top accent bar and room tag.
  <sub>class · features/schedule/schedule_grid_course_block.dart:9</sub>
    - `const ScheduleGridCourseBlock({ super.key, required this.course, required this.onTap, this.overlapCount = 1, });`  <sub>:10</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:21</sub>

## features/schedule/schedule_grid_layout.dart

- `class ScheduleGridLayout` — Where each course sits inside its day column, plus the section times.
  <sub>class · features/schedule/schedule_grid_layout.dart:43</sub>
    - `const ScheduleGridLayout({ required this.placements, required this.times, required this.sectionCount, });`  <sub>:44</sub>

## features/schedule/schedule_page.dart

- `class SchedulePage extends StatefulWidget`
  <sub>class · features/schedule/schedule_page.dart:23</sub>
    - `const SchedulePage({ super.key, required this.service, this.fileActions = const PlatformActions(), this.onOpenCheckIn, });`  <sub>:24</sub>
    - `State<SchedulePage> createState() => …`  <sub>:34</sub>

## features/schedule/schedule_style.dart

- `TextStyle scheduleSecondary(BuildContext context) => …` — Quiet secondary text used across the schedule surface.
  <sub>function · features/schedule/schedule_style.dart:12</sub>
- `Color courseColor(BuildContext context, String? value, [String name = '']) {…}`
  <sub>function · features/schedule/schedule_style.dart:16</sub>
- `String courseDetail(ScheduleCourse course) {…}`
  <sub>function · features/schedule/schedule_style.dart:41</sub>
- `String shortDate(String date) {…}`
  <sub>function · features/schedule/schedule_style.dart:51</sub>
- `int? scheduleTodayColumn(String? weekStart) {…}` — Column of today inside a week that starts on [weekStart], counting from 1.
  <sub>function · features/schedule/schedule_style.dart:61</sub>
- `String scheduleDayTitle(int day, String? weekStart) {…}` — Title of one weekday inside a week, e.g. `周一 · 10/19 · 今天`.
  <sub>function · features/schedule/schedule_style.dart:71</sub>

## features/schedule/schedule_views.dart

- `class ScheduleCourseBrowser extends StatelessWidget` — Main schedule viewport: full 7-day iOS week timetable card by default,
  <sub>class · features/schedule/schedule_views.dart:16</sub>
    - `const ScheduleCourseBrowser({ super.key, required this.snapshot, required this.courses, required this.days, required this.weeks, required this.mode, required this.search, required this.searchVisible, required this.selectedDay, required this.onSelectedDay, required this.onSearchChanged, required this.onCourseTap, this.onConflictTap, this.onSwipeWeek, });`  <sub>:17</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:48</sub>
- `class ScheduleSemesterWeeks extends StatelessWidget` — The teaching weeks of the term, presented as an iOS grouped list.
  <sub>class · features/schedule/schedule_views.dart:179</sub>
    - `const ScheduleSemesterWeeks({ super.key, required this.weeks, required this.onSelected, });`  <sub>:180</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:189</sub>
- `class ScheduleExamList extends StatelessWidget` — The exam schedule of the term, styled after iOS Academic cards.
  <sub>class · features/schedule/schedule_views.dart:250</sub>
    - `const ScheduleExamList({super.key, required this.exams});`  <sub>:251</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:255</sub>

## features/schedule/schedule_week_strip.dart

- `class ScheduleWeekStrip extends StatefulWidget` — Owns week-chip measurement, scrolling and post-layout synchronization.
  <sub>class · features/schedule/schedule_week_strip.dart:7</sub>
    - `const ScheduleWeekStrip({ super.key, required this.weeks, required this.selectedWeek, required this.onSelected, });`  <sub>:8</sub>
    - `State<ScheduleWeekStrip> createState() => …`  <sub>:18</sub>

## features/schedule/schedule_widgets.dart

- `enum ScheduleViewMode` — How the schedule page presents the confirmed snapshot.
  <sub>enum · features/schedule/schedule_widgets.dart:16</sub>
- `String scheduleViewModeLabel(ScheduleViewMode mode) => …` — Short label of a view mode.
  <sub>function · features/schedule/schedule_widgets.dart:31</sub>
- `String scheduleViewModeDescription(ScheduleViewMode mode) => …` — Label of a view mode in the large-text picker, where the grid hint has to
  <sub>function · features/schedule/schedule_widgets.dart:40</sub>
- `class ScheduleCourseRow extends StatelessWidget` — iOS Calendar-style course row in the daily schedule list.
  <sub>class · features/schedule/schedule_widgets.dart:48</sub>
    - `const ScheduleCourseRow({super.key, required this.course, this.onTap});`  <sub>:49</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:54</sub>
- `class ScheduleDetailLine extends StatelessWidget` — One label/value line in the pushed course detail page.
  <sub>class · features/schedule/schedule_widgets.dart:212</sub>
    - `const ScheduleDetailLine({ super.key, required this.label, required this.value, });`  <sub>:213</sub>
    - `Widget build(BuildContext context) => …`  <sub>:220</sub>
- `class ScheduleChevronRow extends StatelessWidget` — A tappable row that reveals the next screen, with a trailing chevron.
  <sub>class · features/schedule/schedule_widgets.dart:225</sub>
    - `const ScheduleChevronRow({ super.key, required this.child, required this.onTap, });`  <sub>:226</sub>
    - `Widget build(BuildContext context) => …`  <sub>:235</sub>
- `class ScheduleSection extends StatelessWidget` — A group of rows under an optional section title.
  <sub>class · features/schedule/schedule_widgets.dart:261</sub>
    - `const ScheduleSection({ super.key, required this.children, this.title, this.footer, });`  <sub>:262</sub>
    - `Widget build(BuildContext context) => …`  <sub>:273</sub>
- `class ScheduleLoadingSection extends StatelessWidget` — A section that reports the first load of a snapshot.
  <sub>class · features/schedule/schedule_widgets.dart:281</sub>
    - `const ScheduleLoadingSection({super.key, this.label = '正在读取课表…'});`  <sub>:282</sub>
    - `Widget build(BuildContext context) => …`  <sub>:286</sub>
