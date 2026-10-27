# Flutter 功能域：bykc

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。

`flutter/lib/features/bykc/` 的页面、域内组件与模型。

## features/bykc/bykc_course_tile.dart

- `class BykcCourseTile extends StatelessWidget` — 博雅课程列表项。  
  <sub>class · features/bykc/bykc_course_tile.dart:14</sub>
    - `const BykcCourseTile( {…}`  <sub>:15</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:49</sub>

## features/bykc/bykc_detail_page.dart

- `class BykcDetailPage extends StatelessWidget` — A projection of the fetched snapshot. Opening it sends no new request.  
  <sub>class · features/bykc/bykc_detail_page.dart:8</sub>
    - `const BykcDetailPage( {…}`  <sub>:9</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:13</sub>

## features/bykc/bykc_models.dart

- `class BykcSemester`  
  <sub>class · features/bykc/bykc_models.dart:8</sub>
- `class BykcCourseDetails` — Course enrollment details. Absent values stay null; they are never  
  <sub>class · features/bykc/bykc_models.dart:21</sub>
- `class BykcCourse`  
  <sub>class · features/bykc/bykc_models.dart:54</sub>
    - `String get categoryLabel {…}` — Subcategory wins when present; an empty chain stays unclassified.  <sub>:81</sub>
- `class BykcCatalog` — Catalog view flattened by core: `terms`, `courses` and the projected  
  <sub>class · features/bykc/bykc_models.dart:91</sub>
- `class BykcChosenRecord`  
  <sub>class · features/bykc/bykc_models.dart:105</sub>
    - `String get attendanceLabel => switch (checkin) {…}`  <sub>:122</sub>
    - `String get resultLabel => switch (passed) {…}`  <sub>:128</sub>
- `class BykcChosenCourses`  
  <sub>class · features/bykc/bykc_models.dart:136</sub>
- `class BykcStatisticsEntry`  
  <sub>class · features/bykc/bykc_models.dart:153</sub>
    - `bool get complete => requiredCount > 0 && completed >= requiredCount;`  <sub>:163</sub>
- `class BykcStatistics`  
  <sub>class · features/bykc/bykc_models.dart:166</sub>

## features/bykc/bykc_page.dart

- `typedef BykcLoader = Future<live.ReadOnlyResponse> Function(`  
  <sub>typedef · features/bykc/bykc_page.dart:15</sub>
- `class BykcPage extends StatefulWidget`  
  <sub>class · features/bykc/bykc_page.dart:20</sub>
    - `const BykcPage( {…}`  <sub>:21</sub>
    - `State<BykcPage> createState() => _BykcPageState();`  <sub>:26</sub>

## features/bykc/bykc_statistics_view.dart

- `class BykcStatisticsView extends StatelessWidget` — 学习进度统计视图。  
  <sub>class · features/bykc/bykc_statistics_view.dart:12</sub>
    - `const BykcStatisticsView( {…}`  <sub>:13</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:18</sub>

## features/bykc/bykc_widgets.dart

- `class BykcLabel extends StatelessWidget` — A compact tag used for course categories, enrollment and results.  
  <sub>class · features/bykc/bykc_widgets.dart:6</sub>
    - `const BykcLabel( {…}`  <sub>:7</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:17</sub>
- `class BykcMetadata extends StatelessWidget` — One metadata line of a course card, such as its time or its classroom.  
  <sub>class · features/bykc/bykc_widgets.dart:44</sub>
    - `const BykcMetadata( {…}`  <sub>:45</sub>
    - `Widget build(BuildContext context) => Row( crossAxisAlignment: CrossAxisAlignment.start … noColors.secondaryLabel.resolveFrom(context), ), ), ), ], );`  <sub>:56</sub>
- `class BykcSectionHeading extends StatelessWidget` — The heading of one BYKC section, with an optional explanatory line.  
  <sub>class · features/bykc/bykc_widgets.dart:85</sub>
    - `const BykcSectionHeading( {…}`  <sub>:86</sub>
    - `Widget build(BuildContext context) => Padding( padding: const EdgeInsets.fromLTRB(24, 2 … olors.secondaryLabel.resolveFrom(context), ), ), ], ], ), );`  <sub>:90</sub>
- `class BykcCardRow extends StatelessWidget` — One row of a rounded BYKC card group. The group keeps a continuous  
  <sub>class · features/bykc/bykc_widgets.dart:116</sub>
    - `const BykcCardRow( {…}`  <sub>:117</sub>
    - `Widget build(BuildContext context) => Padding( padding: const EdgeInsets.symmetric(hori … eFrom(context) .withValues(alpha: 0.2), ), ), ], ), ), ), );`  <sub>:135</sub>
- `class BykcStatisticsCard extends StatelessWidget` — Progress of one required category reported by the school.  
  <sub>class · features/bykc/bykc_widgets.dart:167</sub>
    - `const BykcStatisticsCard( {…}`  <sub>:168</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:171</sub>
