# 共享呈现组件（flutter/lib/widgets）

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
设计系统之上的可复用组件。

## 目录

- [widgets/academic_widgets.dart](#widgetsacademicwidgetsdart) (5)
- [widgets/apple_controls.dart](#widgetsapplecontrolsdart) (2)
- [widgets/apple_navigation.dart](#widgetsapplenavigationdart) (2)
- [widgets/apple_page_chrome.dart](#widgetsapplepagechromedart) (2)
- [widgets/apple_surfaces.dart](#widgetsapplesurfacesdart) (4)
- [widgets/collection_toolbar.dart](#widgetscollectiontoolbardart) (3)
- [widgets/day_scroll_physics.dart](#widgetsdayscrollphysicsdart) (1)
- [widgets/diagnostic_hints.dart](#widgetsdiagnostichintsdart) (1)
- [widgets/ginkgo_mark.dart](#widgetsginkgomarkdart) (1)
- [widgets/ginkgo_visuals.dart](#widgetsginkgovisualsdart) (2)
- [widgets/loading_widgets.dart](#widgetsloadingwidgetsdart) (5)
- [widgets/long_page_scroll.dart](#widgetslongpagescrolldart) (1)
- [widgets/mutation_dialog.dart](#widgetsmutationdialogdart) (1)
- [widgets/public_information_page.dart](#widgetspublicinformationpagedart) (1)
- [widgets/release_notes_view.dart](#widgetsreleasenotesviewdart) (11)
- [widgets/reminder_badge.dart](#widgetsreminderbadgedart) (1)
- [widgets/resource_meter.dart](#widgetsresourcemeterdart) (1)
- [widgets/status_chip.dart](#widgetsstatuschipdart) (3)
- [widgets/summary_strip.dart](#widgetssummarystripdart) (5)

## widgets/academic_widgets.dart

- `String academicNumber(num? value) => …`
  <sub>function · widgets/academic_widgets.dart:5</sub>
- `class AcademicBadge extends StatelessWidget` — Quiet semantic labels that wrap with text size; color never carries status
  <sub>class · widgets/academic_widgets.dart:13</sub>
    - `const AcademicBadge(this.label, {super.key, this.tint, this.icon});`  <sub>:14</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:20</sub>
- `class AcademicFactRow extends StatelessWidget` — Readable label/value alignment, stacking before large text gets squeezed.
  <sub>class · widgets/academic_widgets.dart:54</sub>
    - `const AcademicFactRow({super.key, required this.label, required this.value});`  <sub>:55</sub>
    - `Widget build(BuildContext context) => …`  <sub>:60</sub>
- `class AcademicMetric extends StatelessWidget`
  <sub>class · widgets/academic_widgets.dart:102</sub>
    - `const AcademicMetric({ super.key, required this.label, required this.value, this.prominent = false, });`  <sub>:103</sub>
    - `Widget build(BuildContext context) => …`  <sub>:112</sub>
- `class AcademicMetricGrid extends StatelessWidget`
  <sub>class · widgets/academic_widgets.dart:137</sub>
    - `const AcademicMetricGrid({ super.key, required this.children, this.maxColumns, });`  <sub>:138</sub>
    - `Widget build(BuildContext context) => …`  <sub>:146</sub>

## widgets/apple_controls.dart

- `class AppleToolbarButton extends StatelessWidget`
  <sub>class · widgets/apple_controls.dart:149</sub>
    - `const AppleToolbarButton({ super.key, required this.child, required this.onPressed, required this.label, this.busy = false, });`  <sub>:150</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:162</sub>
- `class ApplePickerTile<T> extends StatelessWidget`
  <sub>class · widgets/apple_controls.dart:235</sub>
    - `const ApplePickerTile({ super.key, required this.title, required this.value, required this.values, required this.label, required this.onSelected, this.enabled = true, this.useWheel = false, });`  <sub>:236</sub>
    - `final String Function(T) label;`  <sub>:249</sub>
    - `final void Function(T) onSelected;`  <sub>:250</sub>
    - `Widget build(BuildContext context) => …`  <sub>:254</sub>

## widgets/apple_navigation.dart

- `class AppleContentTransition extends StatelessWidget` — macOS reference uses 180–200ms easeInOut for content/state changes.
  <sub>class · widgets/apple_navigation.dart:8</sub>
    - `const AppleContentTransition({ super.key, required this.identity, required this.child, });`  <sub>:9</sub>
    - `Widget build(BuildContext context) => …`  <sub>:17</sub>
- `class AppleNavigationItem extends StatefulWidget` — A persistent desktop destination with pointer, focus and selection feedback.
  <sub>class · widgets/apple_navigation.dart:28</sub>
    - `const AppleNavigationItem({ super.key, required this.title, required this.icon, required this.selected, required this.onPressed, this.unreadCount = 0, });`  <sub>:29</sub>
    - `State<AppleNavigationItem> createState() => …`  <sub>:43</sub>

## widgets/apple_page_chrome.dart

- `class AppleRefreshPageHeader extends StatelessWidget`
  <sub>class · widgets/apple_page_chrome.dart:7</sub>
    - `const AppleRefreshPageHeader({ super.key, required this.title, required this.subtitle, required this.icon, this.leading, this.section = '空间资源', this.refreshLabel, this.busy = false, this.onRefresh, this.refreshKey, });`  <sub>:8</sub>
    - `final Future<void> Function()? onRefresh;`  <sub>:28</sub>
    - `Widget build(BuildContext context) => …`  <sub>:35</sub>
- `class AppleStatusSection extends StatelessWidget`
  <sub>class · widgets/apple_page_chrome.dart:56</sub>
    - `const AppleStatusSection({ super.key, required this.title, required this.description, this.action, this.onAction, this.error = false, this.animateSize = true, });`  <sub>:57</sub>
    - `Widget build(BuildContext context) => …`  <sub>:75</sub>

## widgets/apple_surfaces.dart

- `class ApplePageHeader extends StatelessWidget` — Phone pages keep the native collapsing title. Wide windows use the same
  <sub>class · widgets/apple_surfaces.dart:9</sub>
    - `const ApplePageHeader({ super.key, required this.largeTitle, this.trailing, this.leading, this.previousPageTitle, this.border, this.section, this.subtitle, this.icon, });`  <sub>:10</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:34</sub>
- `class AppleEmptyState extends StatelessWidget`
  <sub>class · widgets/apple_surfaces.dart:137</sub>
    - `const AppleEmptyState({ super.key, required this.title, required this.description, this.action, this.onAction, this.error = false, this.icon, });`  <sub>:138</sub>
    - `Widget build(BuildContext context) => …`  <sub>:153</sub>
- `class AppleSection extends StatelessWidget` — Modern inset groups use a continuous corner, a quiet content surface and
  <sub>class · widgets/apple_surfaces.dart:189</sub>
    - `const AppleSection({ super.key, required this.children, this.header, this.footer, this.animateSize = true, });`  <sub>:190</sub>
    - `Widget build(BuildContext context) => …`  <sub>:201</sub>
- `class AppleListTile extends StatelessWidget`
  <sub>class · widgets/apple_surfaces.dart:294</sub>
    - `const AppleListTile({ super.key, required this.title, this.subtitle, this.additionalInfo, this.leading, this.trailing, this.onTap, this.minimumHeight = AppleDesign.rowHeight, this.leadingSize = 30, });`  <sub>:295</sub>
    - `Widget build(BuildContext context) => …`  <sub>:312</sub>

## widgets/collection_toolbar.dart

- `class CollectionToolbar extends StatelessWidget` — Reusable navigation for large result sets. Query controls stay above it in
  <sub>class · widgets/collection_toolbar.dart:10</sub>
    - `const CollectionToolbar({ super.key, required this.window, required this.onPageChanged, required this.unit, this.busy = false, this.error, this.onRetry, this.statusKey, });`  <sub>:11</sub>
    - `Widget build(BuildContext context) => …`  <sub>:30</sub>
- `class CollectionQuerySurface extends StatelessWidget` — Opaque separation keeps moving rows from competing with query controls.
  <sub>class · widgets/collection_toolbar.dart:137</sub>
    - `const CollectionQuerySurface({super.key, required this.child});`  <sub>:138</sub>
    - `Widget build(BuildContext context) => …`  <sub>:141</sub>
- `class CollectionAnchor` — A non-pinned marker gives page/filter changes a stable start of results.
  <sub>class · widgets/collection_toolbar.dart:157</sub>
    - `Widget get sliver => …`  <sub>:159</sub>
    - `void reveal(ScrollController controller) {…}`  <sub>:161</sub>

## widgets/day_scroll_physics.dart

- `class DayScrollPhysics extends ScrollPhysics` — Touch flings settle on a day boundary, while wheel and thumb movement remain
  <sub>class · widgets/day_scroll_physics.dart:5</sub>
    - `const DayScrollPhysics({required this.dayWidth, super.parent});`  <sub>:6</sub>
    - `DayScrollPhysics applyTo(ScrollPhysics? ancestor) => …`  <sub>:10</sub>
    - `Simulation? createBallisticSimulation( ScrollMetrics position, double velocity, ) {…}`  <sub>:14</sub>

## widgets/diagnostic_hints.dart

- `class DiagnosticHintOverlay extends StatelessWidget`
  <sub>class · widgets/diagnostic_hints.dart:6</sub>
    - `const DiagnosticHintOverlay({super.key, required this.child});`  <sub>:7</sub>
    - `Widget build(BuildContext context) => …`  <sub>:10</sub>

## widgets/ginkgo_mark.dart

- `class GinkgoMark extends StatelessWidget` — Ginkgo 品牌标记：银杏叶的矢量绘制，与 Android 启动图标、主页 logo 同源。
  <sub>class · widgets/ginkgo_mark.dart:9</sub>
    - `const GinkgoMark({ super.key, this.size = 96, this.color, this.progress = 1, this.veinColor, });`  <sub>:10</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:31</sub>

## widgets/ginkgo_visuals.dart

- `class GinkgoIconTile extends StatelessWidget` — A rounded tinted base for a single glyph. The glyph follows text scaling
  <sub>class · widgets/ginkgo_visuals.dart:7</sub>
    - `const GinkgoIconTile({ super.key, required this.icon, this.size = 44, this.iconSize, this.selected = false, this.color, this.semanticLabel, });`  <sub>:8</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:26</sub>
- `class GinkgoBadge extends StatelessWidget` — A compact tinted label. The text always carries the meaning; color is only
  <sub>class · widgets/ginkgo_visuals.dart:68</sub>
    - `const GinkgoBadge({ super.key, required this.label, this.icon, this.color, this.compact = false, });`  <sub>:69</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:83</sub>

## widgets/loading_widgets.dart

- `class GinkgoActivity extends StatefulWidget` — A small ginkgo fan breathes without suggesting a measured percentage.
  <sub>class · widgets/loading_widgets.dart:10</sub>
    - `const GinkgoActivity({super.key, this.size = 22});`  <sub>:11</sub>
    - `State<GinkgoActivity> createState() => …`  <sub>:15</sub>
- `class GinkgoLoadingView extends StatelessWidget` — Unified first-load feedback: a branded leaf plus one stable live-region
  <sub>class · widgets/loading_widgets.dart:107</sub>
    - `const GinkgoLoadingView({ super.key, required this.label, this.detail, this.compact = false, });`  <sub>:108</sub>
    - `Widget build(BuildContext context) => …`  <sub>:120</sub>
- `class SectionFeedback extends StatelessWidget` — Stable, inline status: stale content stays in place during refresh/failure.
  <sub>class · widgets/loading_widgets.dart:161</sub>
    - `const SectionFeedback({ super.key, required this.loading, required this.label, required this.hasData, this.error, this.onRetry, });`  <sub>:162</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:176</sub>
- `class SectionReveal extends StatelessWidget` — Fade only on first insertion; later refreshes keep layout and content steady.
  <sub>class · widgets/loading_widgets.dart:223</sub>
    - `const SectionReveal({super.key, required this.child});`  <sub>:224</sub>
    - `Widget build(BuildContext context) => …`  <sub>:228</sub>
- `class PageRefreshShortcut extends StatelessWidget` — Desktop refresh lives in the focused page, including its search fields.
  <sub>class · widgets/loading_widgets.dart:237</sub>
    - `const PageRefreshShortcut({super.key, required this.child, this.onRefresh});`  <sub>:238</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:243</sub>

## widgets/long_page_scroll.dart

- `class LongPageScroll extends StatelessWidget` — Shared long-page navigation without rebuilding the list on each scroll tick.
  <sub>class · widgets/long_page_scroll.dart:7</sub>
    - `const LongPageScroll({ super.key, required this.controller, required this.child, });`  <sub>:8</sub>
    - `Widget build(BuildContext context) => …`  <sub>:17</sub>

## widgets/mutation_dialog.dart

- `Future<bool> confirmMutation( BuildContext context, { required String title, required String detail, required String action, bool destructive = false, }) async => …`
  <sub>function · widgets/mutation_dialog.dart:3</sub>

## widgets/public_information_page.dart

- `class PublicInformationPage<T, Q> extends StatefulWidget`
  <sub>class · widgets/public_information_page.dart:8</sub>
    - `const PublicInformationPage({ super.key, required this.service, required this.initialQuery, required this.read, required this.queryBuilder, required this.contentBuilder, required this.scrollKey, required this.title, required this.subtitle, required this.icon, required this.refreshLabel, required this.loadingLabel, required this.unsupportedTitle, this.section = '资讯与就业', });`  <sub>:9</sub>
    - `final Future<SectionResult<T>> Function(Q query, bool forceRefresh) read;`  <sub>:30</sub>
    - `final Widget Function( BuildContext context, Q query, bool loading, ValueChanged<Q> select, )`  <sub>:31</sub>
    - `final Widget Function(BuildContext context, T data) contentBuilder;`  <sub>:38</sub>
    - `State<PublicInformationPage<T, Q>> createState() => …`  <sub>:49</sub>

## widgets/release_notes_view.dart

- `sealed class NotesBlock`
  <sub>class · widgets/release_notes_view.dart:19</sub>
    - `const NotesBlock();`  <sub>:20</sub>
- `class NotesHeading extends NotesBlock`
  <sub>class · widgets/release_notes_view.dart:23</sub>
    - `const NotesHeading(this.level, this.spans);`  <sub>:24</sub>
- `class NotesBullet extends NotesBlock`
  <sub>class · widgets/release_notes_view.dart:29</sub>
    - `const NotesBullet(this.spans);`  <sub>:30</sub>
- `class NotesParagraph extends NotesBlock`
  <sub>class · widgets/release_notes_view.dart:34</sub>
    - `const NotesParagraph(this.spans);`  <sub>:35</sub>
- `sealed class NotesSpan`
  <sub>class · widgets/release_notes_view.dart:39</sub>
    - `const NotesSpan();`  <sub>:40</sub>
- `class NotesText extends NotesSpan`
  <sub>class · widgets/release_notes_view.dart:43</sub>
    - `const NotesText(this.text, {this.bold = false});`  <sub>:44</sub>
- `class NotesLink extends NotesSpan` — [url] is `null` when the destination failed the allow-list, which renders
  <sub>class · widgets/release_notes_view.dart:51</sub>
    - `const NotesLink(this.text, this.url);`  <sub>:52</sub>
- `bool openableReleaseLink(String url) {…}` — Only the project's own GitHub pages may be opened from remote release copy.
  <sub>function · widgets/release_notes_view.dart:64</sub>
- `List<NotesSpan> parseNotesInline(String input) {…}`
  <sub>function · widgets/release_notes_view.dart:90</sub>
- `List<NotesBlock> parseReleaseNotes(String source) {…}`
  <sub>function · widgets/release_notes_view.dart:136</sub>
- `class ReleaseNotesView extends StatelessWidget` — Renders parsed release notes.
  <sub>class · widgets/release_notes_view.dart:185</sub>
    - `const ReleaseNotesView({super.key, required this.source});`  <sub>:186</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:291</sub>

## widgets/reminder_badge.dart

- `class ReminderBadge extends StatelessWidget` — iOS-style unread capsule: semantic label, no color-only meaning.
  <sub>class · widgets/reminder_badge.dart:4</sub>
    - `const ReminderBadge({super.key, required this.count, required this.child});`  <sub>:5</sub>
    - `Widget build(BuildContext context) => …`  <sub>:9</sub>

## widgets/resource_meter.dart

- `class ResourceMeter extends StatelessWidget` — A resource snapshot. A free fraction is not a booking guarantee; unknown
  <sub>class · widgets/resource_meter.dart:7</sub>
    - `const ResourceMeter({ super.key, required this.label, required this.available, required this.total, required this.unit, this.detail, this.onTap, });`  <sub>:8</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:23</sub>

## widgets/status_chip.dart

- `enum StatusTone { neutral, accent, success, pending, danger, uncertain }` — The tone of a value or a status. Color only reinforces a word that is
  <sub>enum · widgets/status_chip.dart:8</sub>
- `Color statusToneColor(BuildContext context, StatusTone tone) {…}`
  <sub>function · widgets/status_chip.dart:10</sub>
- `class StatusChip extends StatelessWidget` — A status is always three things: a word, an icon and a color. The word
  <sub>class · widgets/status_chip.dart:32</sub>
    - `const StatusChip({ super.key, required this.label, required this.icon, this.tone = StatusTone.neutral, this.compact = false, });`  <sub>:33</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:67</sub>

## widgets/summary_strip.dart

- `class SummaryItem` — One label/value pair. The value answers the page's question; the label
  <sub>class · widgets/summary_strip.dart:8</sub>
    - `const SummaryItem(this.label, this.value, {this.icon, this.tone, this.key});`  <sub>:9</sub>
- `class SummaryStrip extends StatelessWidget` — A quiet summary surface: label on the left, value aligned right.
  <sub>class · widgets/summary_strip.dart:40</sub>
    - `const SummaryStrip({super.key, required this.items, this.note});`  <sub>:41</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:49</sub>
- `Color summaryValueColor(BuildContext context, StatusTone tone) {…}` — The colour of a summary value.
  <sub>function · widgets/summary_strip.dart:336</sub>
- `class SummaryLine extends StatelessWidget` — A single label/value line for the top of a section.
  <sub>class · widgets/summary_strip.dart:348</sub>
    - `const SummaryLine( this.label, this.value, { super.key, this.icon, this.tone = StatusTone.neutral, });`  <sub>:349</sub>
    - `Widget build(BuildContext context) => …`  <sub>:363</sub>
- `class MetricValue extends StatelessWidget` — A right aligned number that acts as the visual anchor of one row.
  <sub>class · widgets/summary_strip.dart:497</sub>
    - `const MetricValue( this.value, { super.key, this.prominent = false, this.tone = StatusTone.neutral, this.suffix, });`  <sub>:498</sub>
    - `Widget build(BuildContext context) => …`  <sub>:512</sub>
