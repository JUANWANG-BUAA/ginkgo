# Flutter 功能域：schedule

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
`flutter/lib/features/schedule/` 的页面、域内组件与模型。

## 目录

- [features/schedule/course_visibility.dart](#featuresschedulecoursevisibilitydart) (3)
- [features/schedule/schedule_controls.dart](#featuresscheduleschedulecontrolsdart) (1)
- [features/schedule/schedule_course_detail.dart](#featuresscheduleschedulecoursedetaildart) (1)
- [features/schedule/schedule_day_strip.dart](#featuresschedulescheduledaystripdart) (1)
- [features/schedule/schedule_grid.dart](#featuresscheduleschedulegriddart) (1)
- [features/schedule/schedule_grid_course_block.dart](#featuresscheduleschedulegridcourseblockdart) (1)
- [features/schedule/schedule_grid_layout.dart](#featuresscheduleschedulegridlayoutdart) (1)
- [features/schedule/schedule_page.dart](#featuresscheduleschedulepagedart) (1)
- [features/schedule/schedule_views.dart](#featuresschedulescheduleviewsdart) (3)
- [features/schedule/schedule_week_strip.dart](#featuresschedulescheduleweekstripdart) (1)
- [features/schedule/schedule_widgets.dart](#featuresscheduleschedulewidgetsdart) (7)

## features/schedule/course_visibility.dart

- `class CourseVisibility extends ChangeNotifier` — User classification, isolated by account and upstream system. SPOC and
  <sub>class · features/schedule/course_visibility.dart:14</sub>
    - `final Future<void> Function(Set<String>)? save;`  <sub>:17</sub>
    - `final Future<Set<String>> Function()? load;`  <sub>:18</sub>
    - `bool ready = false;`  <sub>:20</sub>
    - `bool loadFailed = false;` — A failed read locks editing until an explicit retry succeeds, so a  <sub>:24</sub>
    - `void dispose() {…}`  <sub>:31</sub>
    - `void notifyListeners() {…}`  <sub>:37</sub>
    - `bool hidden(String system, String id) => _hidden.contains(_key(system, id));`  <sub>:50</sub>
    - `Future<void> restore() => _restoring ??= _restore();`  <sub>:52</sub>
    - `Future<void> retryRestore() {…}` — Explicit retry after a failed read. Re-opens the restore path and applies  <sub>:56</sub>
    - `Future<void> setHidden(String system, String id, bool hidden) {…}`  <sub>:102</sub>
- `class CourseVisibilityScope extends StatefulWidget`
  <sub>class · features/schedule/course_visibility.dart:138</sub>
    - `const CourseVisibilityScope( {…}`  <sub>:139</sub>
    - `static CourseVisibility? of(BuildContext context) => context .dependOnInheritedWidgetOfExactType<_CourseVisibilityScope>()`  <sub>:146</sub>
    - `State<CourseVisibilityScope> createState() => _CourseVisibilityScopeState();`  <sub>:150</sub>
- `class CourseRangePage extends StatelessWidget`
  <sub>class · features/schedule/course_visibility.dart:176</sub>
    - `const CourseRangePage( {…}`  <sub>:177</sub>
    - `Widget build(BuildContext context) => ListenableBuilder( listenable: preferences, build … trailing: CupertinoSwitch( key: ValueKey('course-range-$ {…}`  <sub>:187</sub>

## features/schedule/schedule_controls.dart

- `class ScheduleControls extends StatelessWidget` — Term and week pickers shown above the schedule content.
  <sub>class · features/schedule/schedule_controls.dart:14</sub>
    - `const ScheduleControls( {…}`  <sub>:15</sub>
    - `final Future<void> Function(String termId) onSelectTerm;`  <sub>:30</sub>
    - `final void Function(int week) onSelectWeek;`  <sub>:31</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:34</sub>

## features/schedule/schedule_course_detail.dart

- `class ScheduleCourseDetailPage extends StatelessWidget` — The pushed course detail page.
  <sub>class · features/schedule/schedule_course_detail.dart:12</sub>
    - `const ScheduleCourseDetailPage( {…}`  <sub>:13</sub>
    - `Widget build(BuildContext context) => CupertinoPageScaffold( backgroundColor: Cupertino … ay - 1], ), ScheduleDetailLine( label: '节次', value: '第 $ {…}`  <sub>:28</sub>

## features/schedule/schedule_day_strip.dart

- `class ScheduleDayStrip extends StatelessWidget`
  <sub>class · features/schedule/schedule_day_strip.dart:5</sub>
    - `const ScheduleDayStrip( {…}`  <sub>:6</sub>
    - `Widget build(BuildContext context) => SizedBox( key: const Key('schedule-day-strip'), h … .horizontal, itemCount: 7, itemBuilder: (context, index) {…}`  <sub>:18</sub>

## features/schedule/schedule_grid.dart

- `class ScheduleGrid extends StatefulWidget` — Seven-day timetable grid. Course blocks span their section range and open
  <sub>class · features/schedule/schedule_grid.dart:16</sub>
    - `const ScheduleGrid( {…}`  <sub>:17</sub>
    - `State<ScheduleGrid> createState() => _ScheduleGridState();`  <sub>:28</sub>

## features/schedule/schedule_grid_course_block.dart

- `class ScheduleGridCourseBlock extends StatelessWidget` — One course block inside the timetable grid.
  <sub>class · features/schedule/schedule_grid_course_block.dart:10</sub>
    - `const ScheduleGridCourseBlock( {…}`  <sub>:11</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:20</sub>

## features/schedule/schedule_grid_layout.dart

- `class ScheduleGridLayout` — Where each course sits inside its day column, plus the section times.
  <sub>class · features/schedule/schedule_grid_layout.dart:21</sub>
    - `const ScheduleGridLayout( {…}`  <sub>:22</sub>

## features/schedule/schedule_page.dart

- `class SchedulePage extends StatefulWidget`
  <sub>class · features/schedule/schedule_page.dart:16</sub>
    - `const SchedulePage( {…}`  <sub>:17</sub>
    - `State<SchedulePage> createState() => _SchedulePageState();`  <sub>:20</sub>

## features/schedule/schedule_views.dart

- `class ScheduleCourseBrowser extends StatelessWidget` — The courses of the confirmed week: a search field plus either the weekly
  <sub>class · features/schedule/schedule_views.dart:13</sub>
    - `const ScheduleCourseBrowser( {…}`  <sub>:14</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:39</sub>
- `class ScheduleSemesterWeeks extends StatelessWidget` — The teaching weeks of the term.
  <sub>class · features/schedule/schedule_views.dart:129</sub>
    - `const ScheduleSemesterWeeks( {…}`  <sub>:130</sub>
    - `Widget build(BuildContext context) => ScheduleSection( title: '学期周次', children: [ if (w … ) ScheduleChevronRow( key: Key('schedule-semester-week-$ {…}`  <sub>:139</sub>
- `class ScheduleExamList extends StatelessWidget` — The exam schedule of the term.
  <sub>class · features/schedule/schedule_views.dart:171</sub>
    - `const ScheduleExamList( {…}`  <sub>:172</sub>
    - `Widget build(BuildContext context) => ScheduleSection( title: '考试安排', children: [ if (e … dary(context)), if (exam.examSeatNo != null) Text( '座位 $ {…}`  <sub>:176</sub>

## features/schedule/schedule_week_strip.dart

- `class ScheduleWeekStrip extends StatefulWidget` — Owns week-chip measurement, scrolling and post-layout synchronization.
  <sub>class · features/schedule/schedule_week_strip.dart:7</sub>
    - `const ScheduleWeekStrip( {…}`  <sub>:8</sub>
    - `State<ScheduleWeekStrip> createState() => _ScheduleWeekStripState();`  <sub>:18</sub>

## features/schedule/schedule_widgets.dart

- `enum ScheduleViewMode` — How the schedule page presents the confirmed snapshot.
  <sub>enum · features/schedule/schedule_widgets.dart:14</sub>
- `class ScheduleCourseRow extends StatelessWidget` — One course in the day list. Large type stacks the time above the content;
  <sub>class · features/schedule/schedule_widgets.dart:47</sub>
    - `const ScheduleCourseRow( {…}`  <sub>:48</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:53</sub>
- `class ScheduleDetailLine extends StatelessWidget` — One label/value line in the pushed course detail page.
  <sub>class · features/schedule/schedule_widgets.dart:140</sub>
    - `const ScheduleDetailLine( {…}`  <sub>:141</sub>
    - `Widget build(BuildContext context) => Padding( padding: const EdgeInsets.all(16), child … ntext)), const SizedBox(height: 5), Text(value), ], ), ), );`  <sub>:148</sub>
- `class ScheduleChevronRow extends StatelessWidget` — A tappable row that reveals the next screen, with a trailing chevron.
  <sub>class · features/schedule/schedule_widgets.dart:165</sub>
    - `const ScheduleChevronRow( {…}`  <sub>:166</sub>
    - `Widget build(BuildContext context) => CupertinoButton( padding: const EdgeInsets.symmet … ertinoColors.tertiaryLabel.resolveFrom(context), ), ], ), );`  <sub>:175</sub>
- `class ScheduleSection extends StatelessWidget` — A group of rows under an optional section title.
  <sub>class · features/schedule/schedule_widgets.dart:200</sub>
    - `const ScheduleSection( {…}`  <sub>:201</sub>
    - `Widget build(BuildContext context) => AppleSection( header: title == null ? null : Text(title!), footer: footer, children: children, );`  <sub>:212</sub>
- `class ScheduleEmptySection extends StatelessWidget` — A section that reports an empty or failed result.
  <sub>class · features/schedule/schedule_widgets.dart:220</sub>
    - `const ScheduleEmptySection( {…}`  <sub>:221</sub>
    - `Widget build(BuildContext context) => AppleSection( children: [ AppleEmptyState( title: … , action: action, onAction: onAction, error: error, ), ], );`  <sub>:236</sub>
- `class ScheduleLoadingSection extends StatelessWidget` — A section that reports the first load of a snapshot.
  <sub>class · features/schedule/schedule_widgets.dart:250</sub>
    - `const ScheduleLoadingSection( {…}`  <sub>:251</sub>
    - `Widget build(BuildContext context) => AppleSection(children: [GinkgoLoadingView(label: label)]);`  <sub>:255</sub>
