# Flutter 功能域：bykc

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
`flutter/lib/features/bykc/` 的页面、域内组件与模型。

## features/bykc/bykc_course_tile.dart

- `class BykcCourseTile extends StatelessWidget` — 博雅课程列表项。
  <sub>class · features/bykc/bykc_course_tile.dart:14</sub>
    - `const BykcCourseTile({ super.key, required this.course, required this.onTap, this.record, });`  <sub>:15</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:48</sub>

## features/bykc/bykc_detail_page.dart

- `class BykcDetailPage extends StatelessWidget` — A projection of the fetched snapshot. Opening it sends no new request.
  <sub>class · features/bykc/bykc_detail_page.dart:9</sub>
    - `const BykcDetailPage({super.key, required this.course, this.chosenRecord});`  <sub>:10</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:14</sub>

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
    - `String get attendanceLabel => …`  <sub>:122</sub>
    - `String get resultLabel => …`  <sub>:128</sub>
- `class BykcChosenCourses`
  <sub>class · features/bykc/bykc_models.dart:136</sub>
- `class BykcStatisticsEntry`
  <sub>class · features/bykc/bykc_models.dart:153</sub>
    - `bool get complete => …`  <sub>:163</sub>
- `class BykcStatistics`
  <sub>class · features/bykc/bykc_models.dart:166</sub>
- `BykcCatalog bykcCatalog(String payload) => …`
  <sub>function · features/bykc/bykc_models.dart:178</sub>
- `BykcChosenCourses bykcChosenCourses(String payload) => …`
  <sub>function · features/bykc/bykc_models.dart:181</sub>
- `BykcStatistics bykcStatistics(String payload) => …`
  <sub>function · features/bykc/bykc_models.dart:184</sub>

## features/bykc/bykc_page.dart

- `typedef BykcLoader = Future<live.ReadOnlyResponse> Function(`
  <sub>typedef · features/bykc/bykc_page.dart:17</sub>
- `class BykcPage extends StatefulWidget`
  <sub>class · features/bykc/bykc_page.dart:22</sub>
    - `const BykcPage({super.key, this.demo = false, this.loader, this.service});`  <sub>:23</sub>
    - `State<BykcPage> createState() => …`  <sub>:28</sub>

## features/bykc/bykc_statistics_view.dart

- `class BykcStatisticsView extends StatelessWidget` — 学习进度统计视图。
  <sub>class · features/bykc/bykc_statistics_view.dart:12</sub>
    - `const BykcStatisticsView({super.key, required this.data});`  <sub>:13</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:18</sub>

## features/bykc/bykc_widgets.dart

- `class BykcLabel extends StatelessWidget` — A compact tag used for course categories, enrollment and results.
  <sub>class · features/bykc/bykc_widgets.dart:8</sub>
    - `const BykcLabel({ super.key, required this.text, this.positive = false, this.tint, });`  <sub>:9</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:19</sub>
- `class BykcMetadata extends StatelessWidget` — One metadata line of a course card, such as its time or its classroom.
  <sub>class · features/bykc/bykc_widgets.dart:46</sub>
    - `const BykcMetadata({ super.key, required this.icon, required this.text, this.prominent = false, this.auxiliary = false, });`  <sub>:47</sub>
    - `Widget build(BuildContext context) => …`  <sub>:58</sub>
- `class BykcSectionHeading extends StatelessWidget` — The heading of one BYKC section, with an optional explanatory line.
  <sub>class · features/bykc/bykc_widgets.dart:87</sub>
    - `const BykcSectionHeading({super.key, required this.title, this.detail});`  <sub>:88</sub>
    - `Widget build(BuildContext context) => …`  <sub>:92</sub>
- `class BykcCardRow extends StatelessWidget` — One row of a rounded BYKC card group. The group keeps a continuous
  <sub>class · features/bykc/bykc_widgets.dart:118</sub>
    - `const BykcCardRow({ super.key, required this.child, this.first = false, this.last = false, });`  <sub>:119</sub>
    - `Widget build(BuildContext context) => …`  <sub>:137</sub>
- `class BykcStatisticsCard extends StatelessWidget` — Progress of one required category reported by the school.
  <sub>class · features/bykc/bykc_widgets.dart:169</sub>
    - `const BykcStatisticsCard({super.key, required this.entry});`  <sub>:170</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:173</sub>
