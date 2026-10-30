# Flutter 功能域：graduate

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
`flutter/lib/features/graduate/` 的页面、域内组件与模型。

## features/graduate/graduate_course_controls.dart

- `class GraduateCourseControls extends StatelessWidget` — Search, filters and the result count of the course list. The page owns
  <sub>class · features/graduate/graduate_course_controls.dart:9</sub>
    - `const GraduateCourseControls({ super.key, required this.search, required this.category, required this.categories, required this.filter, required this.resultCount, required this.hasCourses, required this.onSearchChanged, required this.onCategoryChanged, required this.onFilterChanged, required this.onClearFilters, });`  <sub>:10</sub>
    - `Widget build(BuildContext context) => …`  <sub>:38</sub>

## features/graduate/graduate_course_widgets.dart

- `class GraduateCourseBadges extends StatelessWidget` — The credit and completion badges of one course.
  <sub>class · features/graduate/graduate_course_widgets.dart:10</sub>
    - `const GraduateCourseBadges({super.key, required this.row});`  <sub>:11</sub>
    - `Widget build(BuildContext context) => …`  <sub>:14</sub>
- `class GraduateCourseCard extends StatelessWidget` — One course of the cultivation plan. Tapping it opens the school record.
  <sub>class · features/graduate/graduate_course_widgets.dart:44</sub>
    - `const GraduateCourseCard({super.key, required this.entry});`  <sub>:45</sub>
    - `Widget build(BuildContext context) => …`  <sub>:50</sub>
- `class GraduateCourseDetails extends StatelessWidget` — The school record of one cultivation-plan course.
  <sub>class · features/graduate/graduate_course_widgets.dart:113</sub>
    - `const GraduateCourseDetails({super.key, required this.entry});`  <sub>:114</sub>
    - `Widget build(BuildContext context) => …`  <sub>:117</sub>

## features/graduate/graduate_credit_map_page.dart

- `Future<void> refreshGraduateCreditMap( RefreshSection<GraduateCreditMapRead> target, GraduateCreditMapGateway? gateway, { bool force = false, }) {…}`
  <sub>function · features/graduate/graduate_credit_map_page.dart:12</sub>
- `class GraduateCreditMapView extends StatelessWidget`
  <sub>class · features/graduate/graduate_credit_map_page.dart:47</sub>
    - `const GraduateCreditMapView({ super.key, required this.report, required this.supported, });`  <sub>:48</sub>
    - `List<Widget> children(BuildContext context) {…}`  <sub>:57</sub>
    - `Widget build(BuildContext context) => …`  <sub>:96</sub>
- `class GraduateCreditMapPage extends StatefulWidget` — Parent supplies an account-scoped gateway and identity. This page never
  <sub>class · features/graduate/graduate_credit_map_page.dart:101</sub>
    - `const GraduateCreditMapPage({ super.key, required this.service, this.accountId, });`  <sub>:102</sub>
    - `State<GraduateCreditMapPage> createState() => …`  <sub>:110</sub>

## features/graduate/graduate_credit_map_widgets.dart

- `class GraduateCreditMapNotice extends StatelessWidget`
  <sub>class · features/graduate/graduate_credit_map_widgets.dart:10</sub>
    - `const GraduateCreditMapNotice(this.text, {super.key, this.warning = false});`  <sub>:11</sub>
    - `Widget build(BuildContext context) => …`  <sub>:15</sub>
- `class GraduateCreditMapNodeCard extends StatelessWidget` — One node of the credit map: its progress and the rows the school listed
  <sub>class · features/graduate/graduate_credit_map_widgets.dart:30</sub>
    - `const GraduateCreditMapNodeCard({ super.key, required this.node, this.summary = false, });`  <sub>:31</sub>
    - `Widget build(BuildContext context) => …`  <sub>:39</sub>

## features/graduate/graduate_page.dart

- `typedef GraduateLoader = Future<GraduateRead> Function(`
  <sub>typedef · features/graduate/graduate_page.dart:20</sub>
- `class GraduatePage extends StatefulWidget`
  <sub>class · features/graduate/graduate_page.dart:25</sub>
    - `const GraduatePage({ super.key, this.loader, this.service, this.creditMapGateway, this.initialView = GraduateView.credits, });`  <sub>:26</sub>
    - `State<GraduatePage> createState() => …`  <sub>:40</sub>

## features/graduate/graduate_sections.dart

- `class GraduateViewSwitcher extends StatelessWidget` — The three lenses on the graduate page: credit map, course list and the
  <sub>class · features/graduate/graduate_sections.dart:13</sub>
    - `const GraduateViewSwitcher({ super.key, required this.view, required this.onChanged, });`  <sub>:14</sub>
    - `Widget build(BuildContext context) => …`  <sub>:24</sub>
- `class GraduatePartNotices extends StatelessWidget` — Loading, error and notice lines for one academic part. The student record
  <sub>class · features/graduate/graduate_sections.dart:59</sub>
    - `const GraduatePartNotices({ super.key, required this.title, required this.loading, required this.hasSections, required this.error, required this.notice, required this.onRetry, });`  <sub>:60</sub>
    - `Widget build(BuildContext context) => …`  <sub>:76</sub>
- `class GraduateOverview extends StatelessWidget` — Credit progress and the category groups of the school execution report.
  <sub>class · features/graduate/graduate_sections.dart:108</sub>
    - `const GraduateOverview({ super.key, required this.sections, required this.expandedSections, required this.onExpanded, required this.onOpenCategory, required this.reportDataExpanded, required this.onReportDataExpanded, });`  <sub>:109</sub>
    - `final void Function(String title, bool expanded) onExpanded;`  <sub>:123</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:129</sub>
- `class GraduateProfileSection extends StatelessWidget` — The student record fields the school returned.
  <sub>class · features/graduate/graduate_sections.dart:173</sub>
    - `const GraduateProfileSection({super.key, required this.section});`  <sub>:174</sub>
    - `Widget build(BuildContext context) => …`  <sub>:179</sub>
- `class GraduateProfileView extends StatelessWidget` — The student record lens: the notices, the fields the school returned and
  <sub>class · features/graduate/graduate_sections.dart:190</sub>
    - `const GraduateProfileView({ super.key, required this.sections, required this.loading, required this.hasSections, required this.error, required this.notice, required this.onRetry, });`  <sub>:191</sub>
    - `Widget build(BuildContext context) => …`  <sub>:207</sub>

## features/graduate/graduate_widgets.dart

- `String graduateCreditLabel(num? value) => …` — Credit values the school did not provide stay "未确认"; they never read as
  <sub>function · features/graduate/graduate_widgets.dart:11</sub>
- `class GraduateStat` — One labeled statistic in a quiet row. A value may keep its own weight and
  <sub>class · features/graduate/graduate_widgets.dart:16</sub>
    - `const GraduateStat(this.label, this.value, {this.weight, this.color});`  <sub>:17</sub>
- `class GraduateStatRow extends StatelessWidget` — A wrapping row of labeled statistics.
  <sub>class · features/graduate/graduate_widgets.dart:25</sub>
    - `const GraduateStatRow( this.stats, { super.key, this.spacing = 12, this.runSpacing = 5, });`  <sub>:26</sub>
    - `Widget build(BuildContext context) => …`  <sub>:37</sub>
- `class GraduateCreditBar extends StatelessWidget` — Credit ratio bar: the recognized portion over an optional pending portion,
  <sub>class · features/graduate/graduate_widgets.dart:56</sub>
    - `const GraduateCreditBar({ super.key, required this.value, this.pendingValue = 0, this.valueColor, this.pendingColor, this.height = 5, this.borderRadius = 3, this.semanticLabel, });`  <sub>:57</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:78</sub>
- `class GraduateCreditProgress extends StatelessWidget` — Numeric fields are projected by Rust; pending credits never reduce the gap.
  <sub>class · features/graduate/graduate_widgets.dart:125</sub>
    - `const GraduateCreditProgress({super.key, required this.progress});`  <sub>:126</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:129</sub>
- `class GraduateDisclosure extends StatefulWidget` — A collapsible block. The page owns the expanded state so a reload can
  <sub>class · features/graduate/graduate_widgets.dart:190</sub>
    - `const GraduateDisclosure({ super.key, required this.title, this.subtitle, this.summary, this.initiallyExpanded = false, this.onExpanded, required this.children, });`  <sub>:191</sub>
    - `State<GraduateDisclosure> createState() => …`  <sub>:207</sub>
- `class GraduateCategoryRow extends StatelessWidget` — One category of the execution report: its credit position and the way into
  <sub>class · features/graduate/graduate_widgets.dart:259</sub>
    - `const GraduateCategoryRow({ super.key, required this.section, required this.onCourses, required this.expanded, required this.onExpanded, });`  <sub>:260</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:272</sub>
