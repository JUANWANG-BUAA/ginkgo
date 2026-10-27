# Flutter 功能域：graduate

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。

`flutter/lib/features/graduate/` 的页面、域内组件与模型。

## features/graduate/graduate_course_controls.dart

- `class GraduateCourseControls extends StatelessWidget` — Search, filters and the result count of the course list. The page owns  
  <sub>class · features/graduate/graduate_course_controls.dart:9</sub>
    - `const GraduateCourseControls( {…}`  <sub>:10</sub>
    - `Widget build(BuildContext context) => Column( crossAxisAlignment: CrossAxisAlignment.st … es ? '清除筛选' : null, onAction: onClearFilters, ), ], ), ], );`  <sub>:38</sub>

## features/graduate/graduate_course_widgets.dart

- `class GraduateCourseBadges extends StatelessWidget` — The credit and completion badges of one course.  
  <sub>class · features/graduate/graduate_course_widgets.dart:10</sub>
    - `const GraduateCourseBadges( {…}`  <sub>:11</sub>
    - `Widget build(BuildContext context) => Wrap( spacing: 8, runSpacing: 8, children: [ AcademicBadge( row.credit == null ? '学分未提供' : '$ {…}`  <sub>:14</sub>
- `class GraduateCourseCard extends StatelessWidget` — One course of the cultivation plan. Tapping it opens the school record.  
  <sub>class · features/graduate/graduate_course_widgets.dart:44</sub>
    - `const GraduateCourseCard( {…}`  <sub>:45</sub>
    - `Widget build(BuildContext context) => Padding( padding: const EdgeInsets.fromLTRB(16, 0 … secondaryLabel.resolveFrom(context), ), ), ], ), ), ), ), );`  <sub>:50</sub>
- `class GraduateCourseDetails extends StatelessWidget` — The school record of one cultivation-plan course.  
  <sub>class · features/graduate/graduate_course_widgets.dart:113</sub>
    - `const GraduateCourseDetails( {…}`  <sub>:114</sub>
    - `Widget build(BuildContext context) => CupertinoPageScaffold( backgroundColor: Cupertino … try.row.detail)], ), const SizedBox(height: 24), ], ), ), );`  <sub>:117</sub>

## features/graduate/graduate_credit_map_page.dart

- `class GraduateCreditMapView extends StatelessWidget`  
  <sub>class · features/graduate/graduate_credit_map_page.dart:47</sub>
    - `const GraduateCreditMapView( {…}`  <sub>:48</sub>
    - `List<Widget> children(BuildContext context) {…}`  <sub>:57</sub>
    - `Widget build(BuildContext context) => Column(children: children(context));`  <sub>:94</sub>
- `class GraduateCreditMapPage extends StatefulWidget` — Parent supplies an account-scoped gateway and identity. This page never  
  <sub>class · features/graduate/graduate_credit_map_page.dart:99</sub>
    - `const GraduateCreditMapPage( {…}`  <sub>:100</sub>
    - `State<GraduateCreditMapPage> createState() => _GraduateCreditMapPageState();`  <sub>:108</sub>

## features/graduate/graduate_credit_map_widgets.dart

- `class GraduateCreditMapNotice extends StatelessWidget`  
  <sub>class · features/graduate/graduate_credit_map_widgets.dart:10</sub>
    - `const GraduateCreditMapNotice(this.text, {…}`  <sub>:11</sub>
    - `Widget build(BuildContext context) => Padding( padding: const EdgeInsets.symmetric(hori … upertinoColors.secondaryLabel.resolveFrom(context), ), ), );`  <sub>:15</sub>
- `class GraduateCreditMapNodeCard extends StatelessWidget` — One node of the credit map: its progress and the rows the school listed  
  <sub>class · features/graduate/graduate_credit_map_widgets.dart:30</sub>
    - `const GraduateCreditMapNodeCard( {…}`  <sub>:31</sub>
    - `Widget build(BuildContext context) => AppleSection( key: ValueKey('credit-node-$ {…}`  <sub>:39</sub>

## features/graduate/graduate_models.dart

- `class GraduateRow` — Presentation values projected by Rust; no upstream fields or status inference.  
  <sub>class · features/graduate/graduate_models.dart:4</sub>
- `class GraduateProgress` — Credit requirement projection (camelCase). Absent values stay null;  
  <sub>class · features/graduate/graduate_models.dart:22</sub>
    - `double? get earnedRatio {…}` — Recognized share of the requirement. Null while either side is unknown:  <sub>:32</sub>
    - `double get pendingRatio {…}` — Pending share of the requirement. Pending credits are never counted as  <sub>:41</sub>
    - `num? get remaining {…}` — Credits still missing; null while either side is unknown.  <sub>:49</sub>
- `class GraduateSection`  
  <sub>class · features/graduate/graduate_models.dart:57</sub>
- `class GraduateCourseEntry`  
  <sub>class · features/graduate/graduate_models.dart:72</sub>
    - `const GraduateCourseEntry(this.section, this.row);`  <sub>:73</sub>
- `enum GraduateCourseFilter`  
  <sub>enum · features/graduate/graduate_models.dart:78</sub>
    - `const GraduateCourseFilter(this.label);`  <sub>:84</sub>
    - `bool accepts(GraduateRow row) => switch (this) {…}`  <sub>:87</sub>
- `enum GraduateView { credits, courses, profile }` — The three lenses on the graduate page.  
  <sub>enum · features/graduate/graduate_models.dart:96</sub>
- `class GraduateReport` — Full report envelope: sections plus the school's own notice line.  
  <sub>class · features/graduate/graduate_models.dart:99</sub>

## features/graduate/graduate_page.dart

- `typedef GraduateLoader = Future<live.ReadOnlyResponse> Function(`  
  <sub>typedef · features/graduate/graduate_page.dart:19</sub>
- `class GraduatePage extends StatefulWidget`  
  <sub>class · features/graduate/graduate_page.dart:24</sub>
    - `const GraduatePage( {…}`  <sub>:25</sub>
    - `State<GraduatePage> createState() => _GraduatePageState();`  <sub>:37</sub>

## features/graduate/graduate_sections.dart

- `class GraduateViewSwitcher extends StatelessWidget` — The three lenses on the graduate page: credit map, course list and the  
  <sub>class · features/graduate/graduate_sections.dart:12</sub>
    - `const GraduateViewSwitcher( {…}`  <sub>:13</sub>
    - `Widget build(BuildContext context) => Padding( padding: const EdgeInsets.fromLTRB(16, 1 … Control<GraduateView>( groupValue: view, children: const {…}`  <sub>:23</sub>
- `class GraduatePartNotices extends StatelessWidget` — Loading, error and notice lines for one academic part. The student record  
  <sub>class · features/graduate/graduate_sections.dart:58</sub>
    - `const GraduatePartNotices( {…}`  <sub>:59</sub>
    - `Widget build(BuildContext context) => Column( crossAxisAlignment: CrossAxisAlignment.st … daryLabel.resolveFrom(context), fontSize: 14, ), ), ), ], );`  <sub>:75</sub>
- `class GraduateOverview extends StatelessWidget` — Credit progress and the category groups of the school execution report.  
  <sub>class · features/graduate/graduate_sections.dart:107</sub>
    - `const GraduateOverview( {…}`  <sub>:108</sub>
    - `final void Function(String title, bool expanded) onExpanded;`  <sub>:122</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:128</sub>
- `class GraduateProfileSection extends StatelessWidget` — The student record fields the school returned.  
  <sub>class · features/graduate/graduate_sections.dart:172</sub>
    - `const GraduateProfileSection( {…}`  <sub>:173</sub>
    - `Widget build(BuildContext context) => AppleSection( header: Text(section.title), childr … AcademicFactRow(label: row.title, value: row.detail), ], );`  <sub>:178</sub>
- `class GraduateProfileView extends StatelessWidget` — The student record lens: the notices, the fields the school returned and  
  <sub>class · features/graduate/graduate_sections.dart:189</sub>
    - `const GraduateProfileView( {…}`  <sub>:190</sub>
    - `Widget build(BuildContext context) => Column( crossAxisAlignment: CrossAxisAlignment.st … title: '暂无学籍信息', description: '学校未返回可展示的学籍字段。'), ], ), ], );`  <sub>:206</sub>

## features/graduate/graduate_widgets.dart

- `class GraduateStat` — One labeled statistic in a quiet row. A value may keep its own weight and  
  <sub>class · features/graduate/graduate_widgets.dart:16</sub>
    - `const GraduateStat(this.label, this.value, {…}`  <sub>:17</sub>
- `class GraduateStatRow extends StatelessWidget` — A wrapping row of labeled statistics.  
  <sub>class · features/graduate/graduate_widgets.dart:25</sub>
    - `const GraduateStatRow( this.stats, {…}`  <sub>:26</sub>
    - `Widget build(BuildContext context) => Wrap( spacing: spacing, runSpacing: runSpacing, children: [ for (final stat in stats) Text( '$ {…}`  <sub>:37</sub>
- `class GraduateCreditBar extends StatelessWidget` — Credit ratio bar: the recognized portion over an optional pending portion,  
  <sub>class · features/graduate/graduate_widgets.dart:56</sub>
    - `const GraduateCreditBar( {…}`  <sub>:57</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:78</sub>
- `class GraduateCreditProgress extends StatelessWidget` — Numeric fields are projected by Rust; pending credits never reduce the gap.  
  <sub>class · features/graduate/graduate_widgets.dart:125</sub>
    - `const GraduateCreditProgress( {…}`  <sub>:126</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:129</sub>
- `class GraduateDisclosure extends StatefulWidget` — A collapsible block. The page owns the expanded state so a reload can  
  <sub>class · features/graduate/graduate_widgets.dart:190</sub>
    - `const GraduateDisclosure( {…}`  <sub>:191</sub>
    - `State<GraduateDisclosure> createState() => _GraduateDisclosureState();`  <sub>:207</sub>
- `class GraduateCategoryRow extends StatelessWidget` — One category of the execution report: its credit position and the way into  
  <sub>class · features/graduate/graduate_widgets.dart:256</sub>
    - `const GraduateCategoryRow( {…}`  <sub>:257</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:269</sub>
