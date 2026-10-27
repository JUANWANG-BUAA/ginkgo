# Flutter 功能域：schedule

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。

`flutter/lib/features/schedule/` 的页面、域内组件与模型。

## CourseVisibility (class)

- `class CourseVisibility extends ChangeNotifier {` — User classification, isolated by account and upstream system. SPOC and  
  <sub>features/schedule/course_visibility.dart:14</sub>
    - `final Future<void> Function(Set<String>)? save;`  <sub>:17</sub>
    - `final Future<Set<String>> Function()? load;`  <sub>:18</sub>
    - `bool ready = false;`  <sub>:20</sub>
    - `bool loadFailed = false;` — A failed read locks editing until an explicit retry succeeds, so a  <sub>:24</sub>
    - `void dispose() { _disposed = true; super.dispose(); }`  <sub>:31</sub>
    - `void notifyListeners() { if (!_disposed) super.notifyListeners(); }`  <sub>:37</sub>
    - `bool hidden(String system, String id) => _hidden.contains(_key(system, id));`  <sub>:50</sub>
    - `Future<void> restore() => _restoring ??= _restore();`  <sub>:52</sub>
    - `Future<void> retryRestore() { if (!loadFailed \|\| _disposed) return Future.value(); loadFailed = false; error = null; _restoring = null; return restor…` — Explicit retry after a failed read. Re-opens the restore path and applies  <sub>:56</sub>
    - `Future<void> setHidden(String system, String id, bool hidden) { if (loadFailed \|\| _disposed) return Future.value(); final key = _key(system, id); if …`  <sub>:102</sub>

## CourseVisibilityScope (class)

- `class CourseVisibilityScope extends StatefulWidget {`  
  <sub>features/schedule/course_visibility.dart:138</sub>
    - `const CourseVisibilityScope({ super.key, required this.account, required this.child, });`  <sub>:139</sub>
    - `static CourseVisibility? of(BuildContext context) => context .dependOnInheritedWidgetOfExactType<_CourseVisibilityScope>()`  <sub>:146</sub>
    - `State<CourseVisibilityScope> createState() => _CourseVisibilityScopeState();`  <sub>:150</sub>

## CourseRangePage (class)

- `class CourseRangePage extends StatelessWidget {`  
  <sub>features/schedule/course_visibility.dart:176</sub>
    - `const CourseRangePage({ super.key, required this.preferences, required this.system, required this.courses, });`  <sub>:177</sub>
    - `Widget build(BuildContext context) => ListenableBuilder( listenable: preferences, builder: (context, _) => CupertinoPageScaffold( navigationBar: cons…`  <sub>:187</sub>

## ScheduleControls (class)

- `class ScheduleControls extends StatelessWidget {` — Term and week pickers shown above the schedule content.  
  <sub>features/schedule/schedule_controls.dart:14</sub>
    - `const ScheduleControls({ super.key, required this.snapshot, required this.terms, required this.weeks, required this.selectedTerm, required this.selec…`  <sub>:15</sub>
    - `final Future<void> Function(String termId) onSelectTerm;`  <sub>:30</sub>
    - `final void Function(int week) onSelectWeek;`  <sub>:31</sub>
    - `Widget build(BuildContext context) { final termPicker = Builder( builder: (anchor) => ScheduleChevronRow( key: const Key('schedule-term-picker'), onT…`  <sub>:34</sub>

## ScheduleCourseDetailPage (class)

- `class ScheduleCourseDetailPage extends StatelessWidget {` — The pushed course detail page.  
  <sub>features/schedule/schedule_course_detail.dart:12</sub>
    - `const ScheduleCourseDetailPage({ super.key, required this.course, required this.termName, required this.weekNumber, required this.week, required this…`  <sub>:13</sub>
    - `Widget build(BuildContext context) => CupertinoPageScaffold( backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom( context, ), naviga…`  <sub>:28</sub>

## ScheduleGrid (class)

- `class ScheduleGrid extends StatefulWidget {` — Seven-day timetable grid. Course blocks span their section range and open  
  <sub>features/schedule/schedule_grid.dart:16</sub>
    - `const ScheduleGrid({ super.key, required this.courses, required this.onCourseTap, this.weekStart, });`  <sub>:17</sub>
    - `State<ScheduleGrid> createState() => _ScheduleGridState();`  <sub>:28</sub>

## ScheduleGridCourseBlock (class)

- `class ScheduleGridCourseBlock extends StatelessWidget {` — One course block inside the timetable grid.  
  <sub>features/schedule/schedule_grid_course_block.dart:10</sub>
    - `const ScheduleGridCourseBlock({ super.key, required this.course, required this.onTap, });`  <sub>:11</sub>
    - `Widget build(BuildContext context) { final color = courseColor(context, course.color, course.name); return Semantics( button: true, label: '${course.…`  <sub>:20</sub>

## ScheduleGridLayout (class)

- `class ScheduleGridLayout {` — Where each course sits inside its day column, plus the section times.  
  <sub>features/schedule/schedule_grid_layout.dart:21</sub>
    - `const ScheduleGridLayout({required this.placements, required this.times});`  <sub>:22</sub>

## SchedulePage (class)

- `class SchedulePage extends StatefulWidget {`  
  <sub>features/schedule/schedule_page.dart:16</sub>
    - `const SchedulePage({super.key, required this.service});`  <sub>:17</sub>
    - `State<SchedulePage> createState() => _SchedulePageState();`  <sub>:20</sub>

## ScheduleCourseBrowser (class)

- `class ScheduleCourseBrowser extends StatelessWidget {` — The courses of the confirmed week: a search field plus either the weekly  
  <sub>features/schedule/schedule_views.dart:12</sub>
    - `const ScheduleCourseBrowser({ super.key, required this.snapshot, required this.courses, required this.days, required this.weeks, required this.mode, …`  <sub>:13</sub>
    - `Widget build(BuildContext context) { final weekStart = weeks[snapshot.weekNumber]?.startDate; final largeText = MediaQuery.textScalerOf(context).scal…`  <sub>:34</sub>

## ScheduleSemesterWeeks (class)

- `class ScheduleSemesterWeeks extends StatelessWidget {` — The teaching weeks of the term.  
  <sub>features/schedule/schedule_views.dart:108</sub>
    - `const ScheduleSemesterWeeks({ super.key, required this.weeks, required this.onSelected, });`  <sub>:109</sub>
    - `Widget build(BuildContext context) => ScheduleSection( title: '学期周次', children: [ if (weeks.isEmpty) const AppleEmptyState( title: '暂无学期周次', descript…`  <sub>:118</sub>

## ScheduleExamList (class)

- `class ScheduleExamList extends StatelessWidget {` — The exam schedule of the term.  
  <sub>features/schedule/schedule_views.dart:150</sub>
    - `const ScheduleExamList({super.key, required this.exams});`  <sub>:151</sub>
    - `Widget build(BuildContext context) => ScheduleSection( title: '考试安排', children: [ if (exams.isEmpty) const AppleEmptyState( title: '本学期暂无考试安排', descr…`  <sub>:155</sub>

## ScheduleWeekStrip (class)

- `class ScheduleWeekStrip extends StatefulWidget {` — Owns week-chip measurement, scrolling and post-layout synchronization.  
  <sub>features/schedule/schedule_week_strip.dart:7</sub>
    - `const ScheduleWeekStrip({ super.key, required this.weeks, required this.selectedWeek, required this.onSelected, });`  <sub>:8</sub>
    - `State<ScheduleWeekStrip> createState() => _ScheduleWeekStripState();`  <sub>:18</sub>

## ScheduleViewMode (enum)

- `enum ScheduleViewMode {` — How the schedule page presents the confirmed snapshot.  
  <sub>features/schedule/schedule_widgets.dart:14</sub>

## ScheduleCourseRow (class)

- `class ScheduleCourseRow extends StatelessWidget {` — One course in the day list. Large type stacks the time above the content;  
  <sub>features/schedule/schedule_widgets.dart:47</sub>
    - `const ScheduleCourseRow({super.key, required this.course, this.onTap});`  <sub>:48</sub>
    - `Widget build(BuildContext context) { final large = MediaQuery.textScalerOf(context).scale(16) > 22; final time = Column( crossAxisAlignment: CrossAxi…`  <sub>:53</sub>

## ScheduleDetailLine (class)

- `class ScheduleDetailLine extends StatelessWidget {` — One label/value line in the pushed course detail page.  
  <sub>features/schedule/schedule_widgets.dart:140</sub>
    - `const ScheduleDetailLine({ super.key, required this.label, required this.value, });`  <sub>:141</sub>
    - `Widget build(BuildContext context) => Padding( padding: const EdgeInsets.all(16), child: Align( alignment: Alignment.centerLeft, child: Column( cross…`  <sub>:148</sub>

## ScheduleChevronRow (class)

- `class ScheduleChevronRow extends StatelessWidget {` — A tappable row that reveals the next screen, with a trailing chevron.  
  <sub>features/schedule/schedule_widgets.dart:165</sub>
    - `const ScheduleChevronRow({ super.key, required this.child, required this.onTap, });`  <sub>:166</sub>
    - `Widget build(BuildContext context) => CupertinoButton( padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), minimumSize: const Size(48, …`  <sub>:175</sub>

## ScheduleSection (class)

- `class ScheduleSection extends StatelessWidget {` — A group of rows under an optional section title.  
  <sub>features/schedule/schedule_widgets.dart:201</sub>
    - `const ScheduleSection({ super.key, required this.children, this.title, this.footer, });`  <sub>:202</sub>
    - `Widget build(BuildContext context) => AppleSection( header: title == null ? null : Text(title!), footer: footer, children: children, );`  <sub>:213</sub>

## ScheduleEmptySection (class)

- `class ScheduleEmptySection extends StatelessWidget {` — A section that reports an empty or failed result.  
  <sub>features/schedule/schedule_widgets.dart:221</sub>
    - `const ScheduleEmptySection({ super.key, required this.title, required this.description, this.action, this.onAction, this.error = false, });`  <sub>:222</sub>
    - `Widget build(BuildContext context) => AppleSection( children: [ AppleEmptyState( title: title, description: description, action: action, onAction: on…`  <sub>:237</sub>

## ScheduleLoadingSection (class)

- `class ScheduleLoadingSection extends StatelessWidget {` — A section that reports the first load of a snapshot.  
  <sub>features/schedule/schedule_widgets.dart:251</sub>
    - `const ScheduleLoadingSection({super.key, this.label = '正在读取课表…'});`  <sub>:252</sub>
    - `Widget build(BuildContext context) => AppleSection(children: [GinkgoLoadingView(label: label)]);`  <sub>:256</sub>
