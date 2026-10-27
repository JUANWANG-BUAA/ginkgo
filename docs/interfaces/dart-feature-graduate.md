# Flutter 功能域：graduate

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。

`flutter/lib/features/graduate/` 的页面、域内组件与模型。

## GraduateCourseControls (class)

- `class GraduateCourseControls extends StatelessWidget {` — Search, filters and the result count of the course list. The page owns  
  <sub>features/graduate/graduate_course_controls.dart:9</sub>
    - `const GraduateCourseControls({ super.key, required this.search, required this.category, required this.categories, required this.filter, required this…`  <sub>:10</sub>
    - `Widget build(BuildContext context) => Column( crossAxisAlignment: CrossAxisAlignment.stretch, children: [ Padding( padding: const EdgeInsets.fromLTRB…`  <sub>:38</sub>

## GraduateCourseBadges (class)

- `class GraduateCourseBadges extends StatelessWidget {` — The credit and completion badges of one course.  
  <sub>features/graduate/graduate_course_widgets.dart:10</sub>
    - `const GraduateCourseBadges({super.key, required this.row});`  <sub>:11</sub>
    - `Widget build(BuildContext context) => Wrap( spacing: 8, runSpacing: 8, children: [ AcademicBadge( row.credit == null ? '学分未提供' : '${academicNumber(ro…`  <sub>:14</sub>

## GraduateCourseCard (class)

- `class GraduateCourseCard extends StatelessWidget {` — One course of the cultivation plan. Tapping it opens the school record.  
  <sub>features/graduate/graduate_course_widgets.dart:44</sub>
    - `const GraduateCourseCard({super.key, required this.entry});`  <sub>:45</sub>
    - `Widget build(BuildContext context) => Padding( padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: DecoratedBox( decoration: BoxDecoration( colo…`  <sub>:50</sub>

## GraduateCourseDetails (class)

- `class GraduateCourseDetails extends StatelessWidget {` — The school record of one cultivation-plan course.  
  <sub>features/graduate/graduate_course_widgets.dart:113</sub>
    - `const GraduateCourseDetails({super.key, required this.entry});`  <sub>:114</sub>
    - `Widget build(BuildContext context) => CupertinoPageScaffold( backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom( context, ), naviga…`  <sub>:117</sub>

## GraduateCreditMapPage (class)

- `class GraduateCreditMapPage extends StatefulWidget {` — Parent supplies an account-scoped gateway and identity. This page never  
  <sub>features/graduate/graduate_credit_map_page.dart:13</sub>
    - `const GraduateCreditMapPage({ super.key, required this.service, this.accountId, });`  <sub>:14</sub>
    - `State<GraduateCreditMapPage> createState() => _GraduateCreditMapPageState();`  <sub>:22</sub>

## GraduateCreditMapNotice (class)

- `class GraduateCreditMapNotice extends StatelessWidget {`  
  <sub>features/graduate/graduate_credit_map_widgets.dart:10</sub>
    - `const GraduateCreditMapNotice(this.text, {super.key, this.warning = false});`  <sub>:11</sub>
    - `Widget build(BuildContext context) => Padding( padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), child: Text( text, style: TextStyle…`  <sub>:15</sub>

## GraduateCreditMapNodeCard (class)

- `class GraduateCreditMapNodeCard extends StatelessWidget {` — One node of the credit map: its progress and the rows the school listed  
  <sub>features/graduate/graduate_credit_map_widgets.dart:30</sub>
    - `const GraduateCreditMapNodeCard({ super.key, required this.node, this.summary = false, });`  <sub>:31</sub>
    - `Widget build(BuildContext context) => AppleSection( key: ValueKey('credit-node-${node.sourceIndex}'), header: Text(summary ? '培养方案总览' : node.title), …`  <sub>:39</sub>

## GraduateRow (class)

- `class GraduateRow {` — Presentation values projected by Rust; no upstream fields or status inference.  
  <sub>features/graduate/graduate_models.dart:4</sub>

## GraduateProgress (class)

- `class GraduateProgress {` — Credit requirement projection (camelCase). Absent values stay null;  
  <sub>features/graduate/graduate_models.dart:22</sub>
    - `double? get earnedRatio { final required = requiredCredits; final value = earned; if (required == null \|\| required <= 0 \|\| value == null) return null…` — Recognized share of the requirement. Null while either side is unknown:  <sub>:32</sub>
    - `double get pendingRatio { final required = requiredCredits; final value = pending; if (required == null \|\| required <= 0 \|\| value == null) return 0; …` — Pending share of the requirement. Pending credits are never counted as  <sub>:41</sub>
    - `num? get remaining { final required = requiredCredits; final value = earned; if (required == null \|\| value == null) return null; return (required - v…` — Credits still missing; null while either side is unknown.  <sub>:49</sub>

## GraduateSection (class)

- `class GraduateSection {`  
  <sub>features/graduate/graduate_models.dart:57</sub>

## GraduateCourseEntry (class)

- `class GraduateCourseEntry {`  
  <sub>features/graduate/graduate_models.dart:72</sub>
    - `const GraduateCourseEntry(this.section, this.row);`  <sub>:73</sub>

## GraduateCourseFilter (enum)

- `enum GraduateCourseFilter {`  
  <sub>features/graduate/graduate_models.dart:78</sub>
    - `const GraduateCourseFilter(this.label);`  <sub>:84</sub>
    - `bool accepts(GraduateRow row) => switch (this) { all => true, incomplete => row.completed == false, completed => row.completed == true, unknown => ro…`  <sub>:87</sub>

## GraduateView (enum)

- `enum GraduateView { credits, courses, profile }` — The three lenses on the graduate page.  
  <sub>features/graduate/graduate_models.dart:96</sub>

## GraduateReport (class)

- `class GraduateReport {` — Full report envelope: sections plus the school's own notice line.  
  <sub>features/graduate/graduate_models.dart:99</sub>

## GraduateLoader (typedef)

- `typedef GraduateLoader = Future<live.ReadOnlyResponse> Function({`  
  <sub>features/graduate/graduate_page.dart:16</sub>

## GraduatePage (class)

- `class GraduatePage extends StatefulWidget {`  
  <sub>features/graduate/graduate_page.dart:21</sub>
    - `const GraduatePage({super.key, this.demo = false, this.loader, this.service});`  <sub>:22</sub>
    - `State<GraduatePage> createState() => _GraduatePageState();`  <sub>:27</sub>

## GraduateViewSwitcher (class)

- `class GraduateViewSwitcher extends StatelessWidget {` — The three lenses on the graduate page: credit map, course list and the  
  <sub>features/graduate/graduate_sections.dart:12</sub>
    - `const GraduateViewSwitcher({ super.key, required this.view, required this.onChanged, });`  <sub>:13</sub>
    - `Widget build(BuildContext context) => Padding( padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: LayoutBuilder( builder: (context, constraint…`  <sub>:23</sub>

## GraduatePartNotices (class)

- `class GraduatePartNotices extends StatelessWidget {` — Loading, error and notice lines for one academic part. The student record  
  <sub>features/graduate/graduate_sections.dart:58</sub>
    - `const GraduatePartNotices({ super.key, required this.title, required this.loading, required this.hasSections, required this.error, required this.noti…`  <sub>:59</sub>
    - `Widget build(BuildContext context) => Column( crossAxisAlignment: CrossAxisAlignment.stretch, children: [ if (loading \|\| error != null) AppleSection(…`  <sub>:75</sub>

## GraduateOverview (class)

- `class GraduateOverview extends StatelessWidget {` — Credit progress and the category groups of the school execution report.  
  <sub>features/graduate/graduate_sections.dart:107</sub>
    - `const GraduateOverview({ super.key, required this.sections, required this.expandedSections, required this.onExpanded, required this.onOpenCategory, r…`  <sub>:108</sub>
    - `final void Function(String title, bool expanded) onExpanded;`  <sub>:122</sub>
    - `Widget build(BuildContext context) { if (sections.isEmpty) return const SizedBox.shrink(); final summary = sections.first; return Column( crossAxisAl…`  <sub>:128</sub>

## GraduateProfileSection (class)

- `class GraduateProfileSection extends StatelessWidget {` — The student record fields the school returned.  
  <sub>features/graduate/graduate_sections.dart:172</sub>
    - `const GraduateProfileSection({super.key, required this.section});`  <sub>:173</sub>
    - `Widget build(BuildContext context) => AppleSection( header: Text(section.title), children: [ for (final row in section.rows) AcademicFactRow(label: r…`  <sub>:178</sub>

## GraduateProfileView (class)

- `class GraduateProfileView extends StatelessWidget {` — The student record lens: the notices, the fields the school returned and  
  <sub>features/graduate/graduate_sections.dart:189</sub>
    - `const GraduateProfileView({ super.key, required this.sections, required this.loading, required this.hasSections, required this.error, required this.n…`  <sub>:190</sub>
    - `Widget build(BuildContext context) => Column( crossAxisAlignment: CrossAxisAlignment.stretch, children: [ GraduatePartNotices( title: '学籍信息', loading…`  <sub>:206</sub>

## GraduateStat (class)

- `class GraduateStat {` — One labeled statistic in a quiet row. A value may keep its own weight and  
  <sub>features/graduate/graduate_widgets.dart:16</sub>
    - `const GraduateStat(this.label, this.value, {this.weight, this.color});`  <sub>:17</sub>

## GraduateStatRow (class)

- `class GraduateStatRow extends StatelessWidget {` — A wrapping row of labeled statistics.  
  <sub>features/graduate/graduate_widgets.dart:25</sub>
    - `const GraduateStatRow( this.stats, { super.key, this.spacing = 12, this.runSpacing = 5, });`  <sub>:26</sub>
    - `Widget build(BuildContext context) => Wrap( spacing: spacing, runSpacing: runSpacing, children: [ for (final stat in stats) Text( '${stat.label} ${st…`  <sub>:37</sub>

## GraduateCreditBar (class)

- `class GraduateCreditBar extends StatelessWidget {` — Credit ratio bar: the recognized portion over an optional pending portion,  
  <sub>features/graduate/graduate_widgets.dart:56</sub>
    - `const GraduateCreditBar({ super.key, required this.value, this.pendingValue = 0, this.valueColor, this.pendingColor, this.height = 5, this.borderRadi…`  <sub>:57</sub>
    - `Widget build(BuildContext context) { final bar = ClipRRect( borderRadius: BorderRadius.circular(borderRadius), child: SizedBox( width: double.infinit…`  <sub>:78</sub>

## GraduateCreditProgress (class)

- `class GraduateCreditProgress extends StatelessWidget {` — Numeric fields are projected by Rust; pending credits never reduce the gap.  
  <sub>features/graduate/graduate_widgets.dart:125</sub>
    - `const GraduateCreditProgress({super.key, required this.progress});`  <sub>:126</sub>
    - `Widget build(BuildContext context) { final required = progress.requiredCredits; final earned = progress.earned; final pending = progress.pending; fin…`  <sub>:129</sub>

## GraduateDisclosure (class)

- `class GraduateDisclosure extends StatefulWidget {` — A collapsible block. The page owns the expanded state so a reload can  
  <sub>features/graduate/graduate_widgets.dart:193</sub>
    - `const GraduateDisclosure({ super.key, required this.title, this.subtitle, this.summary, this.initiallyExpanded = false, this.onExpanded, required thi…`  <sub>:194</sub>
    - `State<GraduateDisclosure> createState() => _GraduateDisclosureState();`  <sub>:210</sub>

## GraduateCategoryRow (class)

- `class GraduateCategoryRow extends StatelessWidget {` — One category of the execution report: its credit position and the way into  
  <sub>features/graduate/graduate_widgets.dart:259</sub>
    - `const GraduateCategoryRow({ super.key, required this.section, required this.onCourses, required this.expanded, required this.onExpanded, });`  <sub>:260</sub>
    - `Widget build(BuildContext context) { final progress = section.progress; final required = progress?.requiredCredits; final earned = progress?.earned; …`  <sub>:272</sub>
