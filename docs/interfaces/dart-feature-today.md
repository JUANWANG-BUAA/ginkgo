# Flutter 功能域：today

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。

`flutter/lib/features/today/` 的页面、域内组件与模型。

## TodayActionRow (class)

- `class TodayActionRow extends StatelessWidget {` — Dashboard action rows reflow naturally and retain a 48dp minimum target.  
  <sub>features/today/today_action_row.dart:6</sub>
    - `const TodayActionRow({ super.key, required this.title, this.subtitle, this.status, this.statusColor, this.onTap, this.emphasized = false, this.summar…`  <sub>:7</sub>
    - `Widget build(BuildContext context) { final accent = CupertinoTheme.of(context).primaryColor; final isDark = CupertinoTheme.of(context).brightness == …`  <sub>:29</sub>

## TodayCourseWindow (class)

- `class TodayCourseWindow {` — Presentation-only interpretation of the existing Today clock range.  
  <sub>features/today/today_course_focus.dart:11</sub>
    - `const TodayCourseWindow(this.starts, this.ends);`  <sub>:12</sub>
    - `static TodayCourseWindow? parse(String date, String? time) { final day = todayDate(date); final match = RegExp(r'^(\d{1,2}):(\d{2})\s*[-–—~～]\s*(\d{1…`  <sub>:15</sub>
    - `String status(DateTime now) => now.isBefore(starts) ? '尚未开始'`  <sub>:31</sub>

## TodayCourseFocus (class)

- `class TodayCourseFocus extends StatelessWidget {`  
  <sub>features/today/today_course_focus.dart:38</sub>
    - `const TodayCourseFocus({ super.key, required this.data, required this.now, this.onOpen, this.stale = false, });`  <sub>:39</sub>
    - `Widget build(BuildContext context) { final dated = todayDate(data.date); if (dated == null \|\| DateTime.utc(now.year, now.month, now.day) != dated) { …`  <sub>:52</sub>

## TodayCourseRow (class)

- `class TodayCourseRow extends StatelessWidget {` — Keep course times on a visible axis, like the native Today views. At large  
  <sub>features/today/today_course_list.dart:10</sub>
    - `const TodayCourseRow({super.key, required this.course, required this.status});`  <sub>:11</sub>
    - `Widget build(BuildContext context) { final times = RegExp(r'^(\d{1,2}:\d{2})\s*[-–—~～]\s*(\d{1,2}:\d{2})$') .firstMatch(course.time?.trim() ?? ''); f…`  <sub>:16</sub>

## TodayCourseEmpty (class)

- `class TodayCourseEmpty extends StatelessWidget {` — Empty / unconfirmed course state. Large type stacks the identity above the  
  <sub>features/today/today_course_list.dart:109</sub>
    - `const TodayCourseEmpty({ super.key, required this.error, required this.onOpenSchedule, });`  <sub>:110</sub>
    - `Widget build(BuildContext context) { final accent = CupertinoTheme.of(context).primaryColor; final isLargeText = MediaQuery.textScalerOf(context).sca…`  <sub>:120</sub>

## TodayCourseEmptyBadge (class)

- `class TodayCourseEmptyBadge extends StatelessWidget {` — The icon tile that marks an empty or unconfirmed course list.  
  <sub>features/today/today_course_list.dart:239</sub>
    - `const TodayCourseEmptyBadge({ super.key, required this.icon, required this.accent, required this.failed, required this.size, required this.iconSize, …`  <sub>:240</sub>
    - `Widget build(BuildContext context) { final isDark = CupertinoTheme.of(context).brightness == Brightness.dark; return Container( width: size, height: …`  <sub>:256</sub>

## TodayCoursePlaceholder (class)

- `class TodayCoursePlaceholder extends StatelessWidget {` — Shown until the first course payload lands. The section keeps the same  
  <sub>features/today/today_course_section.dart:15</sub>
    - `const TodayCoursePlaceholder({ super.key, required this.loading, required this.error, required this.onRetry, });`  <sub>:16</sub>
    - `Widget build(BuildContext context) => TodayVisualSection( header: const Text('今日课程'), children: [ SectionFeedback( loading: loading, label: '正在读取今天课程…`  <sub>:28</sub>

## TodayCourseSection (class)

- `class TodayCourseSection extends StatelessWidget {` — The loaded "today's courses" section: heading, focus card, the expandable  
  <sub>features/today/today_course_section.dart:44</sub>
    - `const TodayCourseSection({ super.key, required this.data, required this.now, required this.loading, required this.error, required this.expanded, requ…`  <sub>:45</sub>
    - `Widget build(BuildContext context) { final date = DateTime.tryParse(data.date); final dateLabel = date == null ? data.date : schoolDateWeekdayLabel(d…`  <sub>:71</sub>

## TodayHomeworkSection (class)

- `class TodayHomeworkSection extends StatelessWidget {` — A separate read can finish before or after today's timetable.  
  <sub>features/today/today_homework_section.dart:13</sub>
    - `const TodayHomeworkSection({ super.key, required this.section, required this.onRetry, this.onOpen, this.onOpenItem, this.now, });`  <sub>:14</sub>
    - `Widget build(BuildContext context) { final data = section.value; final personal = personalHomeworkItems( data?.items ?? [], CourseVisibilityScope.of(…`  <sub>:31</sub>

## TodayPage (class)

- `class TodayPage extends StatefulWidget {`  
  <sub>features/today/today_page.dart:21</sub>
    - `const TodayPage({ super.key, required this.service, this.accountName, this.accountId, this.storageRoot, this.now, this.onAccountAction, this.director…`  <sub>:22</sub>
    - `final DateTime Function()? now;` — An instant, converted to Beijing wall time for presentation.  <sub>:47</sub>
    - `final Future<void> Function()? onAccountAction;`  <sub>:48</sub>
    - `State<TodayPage> createState() => _TodayPageState();`  <sub>:50</sub>

## TodayNavigator (class)

- `class TodayNavigator {` — Opens the pages the today dashboard links to. Only one route may be  
  <sub>features/today/today_page_actions.dart:12</sub>
    - `bool get opening => _opening;` — True while a linked page is being opened.  <sub>:16</sub>
    - `Future<void> openTasks( BuildContext context, { required MirrorService service, required String? storageRoot, required String? taskId, required bool …`  <sub>:18</sub>
    - `Future<void> openHomework( BuildContext context, { required MirrorService service, required String? storageRoot, required HomeworkItem item, required…`  <sub>:53</sub>

## TodayPageHeader (class)

- `class TodayPageHeader extends StatelessWidget {` — The today header carries the account / settings shortcut and the refresh  
  <sub>features/today/today_page_header.dart:9</sub>
    - `const TodayPageHeader({ super.key, required this.title, required this.busy, required this.onRefresh, this.onOpenSettings, this.onAccountAction, this.…`  <sub>:10</sub>
    - `Widget build(BuildContext context) => ApplePageHeader( largeTitle: Text(title), border: null, section: '工作台', subtitle: '从今日课程开始安排一天', icon: Cupertin…`  <sub>:28</sub>

## TodayVisualDivider (class)

- `class TodayVisualDivider extends StatelessWidget {` — A quiet inset rule for rows nested inside a reveal animation.  
  <sub>features/today/today_presentation.dart:16</sub>
    - `const TodayVisualDivider({super.key});`  <sub>:17</sub>
    - `Widget build(BuildContext context) => Padding( padding: GinkgoSpacing.edgeInsetsPage, child: ColoredBox( color: CupertinoColors.separator .resolveFro…`  <sub>:20</sub>

## TodayVisualSection (class)

- `class TodayVisualSection extends StatelessWidget {` — Today-only typography and spacing; the shared section keeps its behavior.  
  <sub>features/today/today_presentation.dart:32</sub>
    - `const TodayVisualSection({ super.key, required this.children, this.header, this.footer, });`  <sub>:33</sub>
    - `Widget build(BuildContext context) => Padding( padding: EdgeInsets.only(top: AppleDesign.desktop(context) ? 4 : 0), child: AppleSection( header: head…`  <sub>:44</sub>

## TodaySectionHeader (class)

- `class TodaySectionHeader extends StatelessWidget {` — A structured section header with theme icon, bold title, count capsule badge,  
  <sub>features/today/today_presentation.dart:71</sub>
    - `const TodaySectionHeader({ super.key, required this.title, this.icon, this.badge, this.actionLabel, this.onAction, });`  <sub>:72</sub>
    - `Widget build(BuildContext context) { final accent = CupertinoTheme.of(context).primaryColor; final action = (actionLabel != null && onAction != null)…`  <sub>:88</sub>

## TodayTasksSnapshot (class)

- `class TodayTasksSnapshot {`  
  <sub>features/today/today_tasks_section.dart:11</sub>
    - `const TodayTasksSnapshot(this.items, this.loadedAt);`  <sub>:12</sub>

## TodayTasksSection (class)

- `class TodayTasksSection extends StatelessWidget {`  
  <sub>features/today/today_tasks_section.dart:17</sub>
    - `const TodayTasksSection({ super.key, required this.section, required this.now, required this.onRetry, required this.onOpen, });`  <sub>:18</sub>
    - `Widget build(BuildContext context) { final data = section.value; final all = data?.items ?? <LocalTaskRecord>[]; // Homework-derived to-dos are shown…`  <sub>:31</sub>
