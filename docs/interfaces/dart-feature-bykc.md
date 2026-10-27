# Flutter 功能域：bykc

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。

`flutter/lib/features/bykc/` 的页面、域内组件与模型。

## BykcCourseTile (class)

- `class BykcCourseTile extends StatelessWidget {` — 博雅课程列表项。  
  <sub>features/bykc/bykc_course_tile.dart:14</sub>
    - `const BykcCourseTile({ super.key, required this.course, required this.onTap, this.record, });`  <sub>:15</sub>
    - `Widget build(BuildContext context) { final details = course.details ?? BykcCourseDetails.empty(); return AppleListTile( key: ValueKey( record != null…`  <sub>:49</sub>

## BykcDetailPage (class)

- `class BykcDetailPage extends StatelessWidget {` — A projection of the fetched snapshot. Opening it sends no new request.  
  <sub>features/bykc/bykc_detail_page.dart:8</sub>
    - `const BykcDetailPage({super.key, required this.course, this.chosenRecord});`  <sub>:9</sub>
    - `Widget build(BuildContext context) { final details = course.details; Widget field(String label, String value) => AppleListTile( title: Text( label, s…`  <sub>:13</sub>

## BykcSemester (class)

- `class BykcSemester {`  
  <sub>features/bykc/bykc_models.dart:8</sub>

## BykcCourseDetails (class)

- `class BykcCourseDetails {` — Course enrollment details. Absent values stay null; they are never  
  <sub>features/bykc/bykc_models.dart:21</sub>

## BykcCourse (class)

- `class BykcCourse {`  
  <sub>features/bykc/bykc_models.dart:54</sub>
    - `String get categoryLabel { for (final value in [subcategory, category]) { if (value != null && value.trim().isNotEmpty) return value; } return '未分类';…` — Subcategory wins when present; an empty chain stays unclassified.  <sub>:81</sub>

## BykcCatalog (class)

- `class BykcCatalog {` — Catalog view flattened by core: `terms`, `courses` and the projected  
  <sub>features/bykc/bykc_models.dart:91</sub>

## BykcChosenRecord (class)

- `class BykcChosenRecord {`  
  <sub>features/bykc/bykc_models.dart:105</sub>
    - `String get attendanceLabel => switch (checkin) { 1 => '已签到', null => '签到待确认', final value => '考勤 $value', };`  <sub>:122</sub>
    - `String get resultLabel => switch (passed) { 1 => '已通过', 0 => '未通过', null => '通过待确认', final value => '通过状态 $value', };`  <sub>:128</sub>

## BykcChosenCourses (class)

- `class BykcChosenCourses {`  
  <sub>features/bykc/bykc_models.dart:136</sub>

## BykcStatisticsEntry (class)

- `class BykcStatisticsEntry {`  
  <sub>features/bykc/bykc_models.dart:153</sub>
    - `bool get complete => requiredCount > 0 && completed >= requiredCount;`  <sub>:163</sub>

## BykcStatistics (class)

- `class BykcStatistics {`  
  <sub>features/bykc/bykc_models.dart:166</sub>

## BykcLoader (typedef)

- `typedef BykcLoader = Future<live.ReadOnlyResponse> Function({`  
  <sub>features/bykc/bykc_page.dart:15</sub>

## BykcPage (class)

- `class BykcPage extends StatefulWidget {`  
  <sub>features/bykc/bykc_page.dart:20</sub>
    - `const BykcPage({super.key, this.demo = false, this.loader, this.service});`  <sub>:21</sub>
    - `State<BykcPage> createState() => _BykcPageState();`  <sub>:26</sub>

## BykcStatisticsView (class)

- `class BykcStatisticsView extends StatelessWidget {` — 学习进度统计视图。  
  <sub>features/bykc/bykc_statistics_view.dart:12</sub>
    - `const BykcStatisticsView({super.key, required this.data});`  <sub>:13</sub>
    - `Widget build(BuildContext context) { final rows = _groupedRows(data.entries); return SliverMainAxisGroup( slivers: [ SliverToBoxAdapter( child: Apple…`  <sub>:18</sub>

## BykcLabel (class)

- `class BykcLabel extends StatelessWidget {` — A compact tag used for course categories, enrollment and results.  
  <sub>features/bykc/bykc_widgets.dart:6</sub>
    - `const BykcLabel({ super.key, required this.text, this.positive = false, this.tint, });`  <sub>:7</sub>
    - `Widget build(BuildContext context) { final color = tint ?? (positive ? CupertinoColors.systemGreen.resolveFrom(context) : CupertinoColors.secondaryLa…`  <sub>:17</sub>

## BykcMetadata (class)

- `class BykcMetadata extends StatelessWidget {` — One metadata line of a course card, such as its time or its classroom.  
  <sub>features/bykc/bykc_widgets.dart:44</sub>
    - `const BykcMetadata({ super.key, required this.icon, required this.text, this.prominent = false, this.auxiliary = false, });`  <sub>:45</sub>
    - `Widget build(BuildContext context) => Row( crossAxisAlignment: CrossAxisAlignment.start, children: [ Padding( padding: const EdgeInsets.only(top: 2),…`  <sub>:56</sub>

## BykcSectionHeading (class)

- `class BykcSectionHeading extends StatelessWidget {` — The heading of one BYKC section, with an optional explanatory line.  
  <sub>features/bykc/bykc_widgets.dart:85</sub>
    - `const BykcSectionHeading({super.key, required this.title, this.detail});`  <sub>:86</sub>
    - `Widget build(BuildContext context) => Padding( padding: const EdgeInsets.fromLTRB(24, 24, 24, 12), child: Column( crossAxisAlignment: CrossAxisAlignm…`  <sub>:90</sub>

## BykcCardRow (class)

- `class BykcCardRow extends StatelessWidget {` — One row of a rounded BYKC card group. The group keeps a continuous  
  <sub>features/bykc/bykc_widgets.dart:116</sub>
    - `const BykcCardRow({ super.key, required this.child, this.first = false, this.last = false, });`  <sub>:117</sub>
    - `Widget build(BuildContext context) => Padding( padding: const EdgeInsets.symmetric(horizontal: 16), child: ClipRSuperellipse( borderRadius: BorderRad…`  <sub>:135</sub>

## BykcStatisticsCard (class)

- `class BykcStatisticsCard extends StatelessWidget {` — Progress of one required category reported by the school.  
  <sub>features/bykc/bykc_widgets.dart:167</sub>
    - `const BykcStatisticsCard({super.key, required this.entry});`  <sub>:168</sub>
    - `Widget build(BuildContext context) { final required = entry.requiredCount; final completed = entry.completed; final complete = entry.complete; final …`  <sub>:171</sub>
