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
- [widgets/date_tile.dart](#widgetsdatetiledart) (1)
- [widgets/day_scroll_physics.dart](#widgetsdayscrollphysicsdart) (1)
- [widgets/diagnostic_hints.dart](#widgetsdiagnostichintsdart) (1)
- [widgets/feature_intro.dart](#widgetsfeatureintrodart) (2)
- [widgets/ginkgo_mark.dart](#widgetsginkgomarkdart) (1)
- [widgets/ginkgo_visuals.dart](#widgetsginkgovisualsdart) (2)
- [widgets/liquid_vial_gauge.dart](#widgetsliquidvialgaugedart) (2)
- [widgets/loading_widgets.dart](#widgetsloadingwidgetsdart) (5)
- [widgets/long_page_scroll.dart](#widgetslongpagescrolldart) (1)
- [widgets/maintenance_scaffold.dart](#widgetsmaintenancescaffolddart) (1)
- [widgets/mutation_dialog.dart](#widgetsmutationdialogdart) (1)
- [widgets/press_feedback.dart](#widgetspressfeedbackdart) (1)
- [widgets/public_information_page.dart](#widgetspublicinformationpagedart) (1)
- [widgets/release_notes_view.dart](#widgetsreleasenotesviewdart) (11)
- [widgets/reminder_badge.dart](#widgetsreminderbadgedart) (1)
- [widgets/resource_meter.dart](#widgetsresourcemeterdart) (1)
- [widgets/school_links.dart](#widgetsschoollinksdart) (3)
- [widgets/status_chip.dart](#widgetsstatuschipdart) (3)
- [widgets/summary_strip.dart](#widgetssummarystripdart) (5)
- [widgets/telemetry_instrument_card.dart](#widgetstelemetryinstrumentcarddart) (1)
- [widgets/telemetry_primitives.dart](#widgetstelemetryprimitivesdart) (5)
- [widgets/top_bounce_scroll_physics.dart](#widgetstopbouncescrollphysicsdart) (1)
- [widgets/verified_route_label.dart](#widgetsverifiedroutelabeldart) (1)
- [widgets/visual_section.dart](#widgetsvisualsectiondart) (3)

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
  <sub>class · widgets/academic_widgets.dart:140</sub>
    - `const AcademicMetricGrid({ super.key, required this.children, this.maxColumns, });`  <sub>:141</sub>
    - `Widget build(BuildContext context) => …`  <sub>:149</sub>

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
  <sub>class · widgets/apple_surfaces.dart:10</sub>
    - `const ApplePageHeader({ super.key, required this.largeTitle, this.trailing, this.leading, this.previousPageTitle, this.border, this.section, this.subtitle, this.icon, });`  <sub>:11</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:35</sub>
- `class AppleEmptyState extends StatelessWidget`
  <sub>class · widgets/apple_surfaces.dart:155</sub>
    - `const AppleEmptyState({ super.key, required this.title, required this.description, this.action, this.onAction, this.error = false, this.icon, });`  <sub>:156</sub>
    - `Widget build(BuildContext context) => …`  <sub>:171</sub>
- `class AppleSection extends StatelessWidget` — Modern inset groups use a continuous corner, a quiet content surface and
  <sub>class · widgets/apple_surfaces.dart:207</sub>
    - `const AppleSection({ super.key, required this.children, this.header, this.footer, this.animateSize = true, });`  <sub>:208</sub>
    - `Widget build(BuildContext context) => …`  <sub>:219</sub>
- `class AppleListTile extends StatelessWidget`
  <sub>class · widgets/apple_surfaces.dart:312</sub>
    - `const AppleListTile({ super.key, required this.title, this.subtitle, this.additionalInfo, this.leading, this.trailing, this.onTap, this.minimumHeight = AppleDesign.rowHeight, this.leadingSize = 30, });`  <sub>:313</sub>
    - `Widget build(BuildContext context) => …`  <sub>:330</sub>

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

## widgets/date_tile.dart

- `class DateTile extends StatelessWidget` — A calendar anchor for an explicit ISO date; unknown formats stay textual.
  <sub>class · widgets/date_tile.dart:5</sub>
    - `const DateTile(this.value, {super.key});`  <sub>:6</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:9</sub>

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

## widgets/feature_intro.dart

- `class FeatureIntro extends StatelessWidget` — A compact feature identity with a clear task, separate from live status.
  <sub>class · widgets/feature_intro.dart:6</sub>
    - `const FeatureIntro({ super.key, required this.icon, required this.title, required this.description, this.color, this.prominent = false, });`  <sub>:7</sub>
    - `Widget build(BuildContext context) => …`  <sub>:21</sub>
- `class FeatureSectionTitle extends StatelessWidget` — Section heading with an explicit semantic icon; no inferred business state.
  <sub>class · widgets/feature_intro.dart:56</sub>
    - `const FeatureSectionTitle( this.title, { super.key, required this.icon, this.color, });`  <sub>:57</sub>
    - `Widget build(BuildContext context) => …`  <sub>:67</sub>

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

## widgets/liquid_vial_gauge.dart

- `enum LiquidPalette` — Color themes for the 3D glass liquid column inside [LiquidVialWell].
  <sub>enum · widgets/liquid_vial_gauge.dart:9</sub>
    - `const LiquidPalette({ required this.bottom, required this.middle, required this.top, required this.meniscus, required this.rim, });`  <sub>:46</sub>
- `class LiquidVialWell extends StatelessWidget` — Tactile recessed instrument well housing a 3D glass test-tube gauge,
  <sub>class · widgets/liquid_vial_gauge.dart:63</sub>
    - `const LiquidVialWell({ super.key, required this.code, required this.readout, required this.fillRatio, this.palette = LiquidPalette.cobalt, this.scaleTicks = const ['75%', '50%', '25%'], this.footer, this.semanticLabel, this.frosted = false, });`  <sub>:64</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:107</sub>

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
    - `const SectionFeedback({ super.key, required this.loading, required this.label, required this.hasData, this.error, this.onRetry, this.retryKey, this.quietWhenRefreshing = false, });`  <sub>:162</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:180</sub>
- `class SectionReveal extends StatelessWidget` — Fade only on first insertion; later refreshes keep layout and content steady.
  <sub>class · widgets/loading_widgets.dart:255</sub>
    - `const SectionReveal({super.key, required this.child});`  <sub>:256</sub>
    - `Widget build(BuildContext context) => …`  <sub>:260</sub>
- `class PageRefreshShortcut extends StatelessWidget` — Desktop refresh lives in the focused page, including its search fields.
  <sub>class · widgets/loading_widgets.dart:269</sub>
    - `const PageRefreshShortcut({super.key, required this.child, this.onRefresh});`  <sub>:270</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:275</sub>

## widgets/long_page_scroll.dart

- `class LongPageScroll extends StatelessWidget` — Shared long-page navigation without rebuilding the list on each scroll tick.
  <sub>class · widgets/long_page_scroll.dart:7</sub>
    - `const LongPageScroll({ super.key, required this.controller, required this.child, });`  <sub>:8</sub>
    - `Widget build(BuildContext context) => …`  <sub>:17</sub>

## widgets/maintenance_scaffold.dart

- `class MaintenanceScaffold extends StatelessWidget`
  <sub>class · widgets/maintenance_scaffold.dart:5</sub>
    - `const MaintenanceScaffold({ super.key, required this.title, required this.children, this.onRefresh, this.busy = false, this.section, this.subtitle, this.icon, });`  <sub>:6</sub>
    - `final Future<void> Function()? onRefresh;`  <sub>:18</sub>
    - `Widget build(BuildContext context) => …`  <sub>:23</sub>

## widgets/mutation_dialog.dart

- `Future<bool> confirmMutation( BuildContext context, { required String title, required String detail, required String action, bool destructive = false, String cancelLabel = '返回', }) async => …`
  <sub>function · widgets/mutation_dialog.dart:3</sub>

## widgets/press_feedback.dart

- `class PressFeedback extends StatefulWidget` — Adds a small touch compression without replacing a control's gestures,
  <sub>class · widgets/press_feedback.dart:7</sub>
    - `const PressFeedback({super.key, required this.child, this.enabled = true});`  <sub>:8</sub>
    - `State<PressFeedback> createState() => …`  <sub>:13</sub>

## widgets/public_information_page.dart

- `class PublicInformationPage<T, Q> extends StatefulWidget`
  <sub>class · widgets/public_information_page.dart:9</sub>
    - `const PublicInformationPage({ super.key, required this.service, required this.initialQuery, required this.read, required this.queryBuilder, required this.contentBuilder, required this.scrollKey, required this.title, required this.subtitle, required this.icon, required this.refreshLabel, required this.loadingLabel, required this.unsupportedTitle, this.section = '资讯与就业', });`  <sub>:10</sub>
    - `final Future<SectionResult<T>> Function(Q query, bool forceRefresh) read;`  <sub>:31</sub>
    - `final Widget Function( BuildContext context, Q query, bool loading, ValueChanged<Q> select, )`  <sub>:32</sub>
    - `final Widget Function(BuildContext context, T data) contentBuilder;`  <sub>:39</sub>
    - `State<PublicInformationPage<T, Q>> createState() => …`  <sub>:50</sub>

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
  <sub>class · widgets/resource_meter.dart:9</sub>
    - `const ResourceMeter({ super.key, required this.label, required this.available, required this.total, required this.unit, this.detail, this.onTap, });`  <sub>:10</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:34</sub>

## widgets/school_links.dart

- `class ExternalLinkScope extends InheritedWidget` — The application root provides the platform capability to every route.
  <sub>class · widgets/school_links.dart:8</sub>
    - `const ExternalLinkScope({ super.key, required this.launcher, required super.child, });`  <sub>:9</sub>
    - `static ExternalLinkLauncher? maybeLauncherOf(BuildContext context) => …`  <sub>:17</sub>
    - `bool updateShouldNotify(ExternalLinkScope oldWidget) => …`  <sub>:21</sub>
- `Future<bool> openSchoolLink(BuildContext context, String value) async {…}`
  <sub>function · widgets/school_links.dart:25</sub>
- `Future<void> showSchoolLinkError(BuildContext context) => …`
  <sub>function · widgets/school_links.dart:31</sub>

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
  <sub>function · widgets/summary_strip.dart:338</sub>
- `class SummaryLine extends StatelessWidget` — A single label/value line for the top of a section.
  <sub>class · widgets/summary_strip.dart:350</sub>
    - `const SummaryLine( this.label, this.value, { super.key, this.icon, this.tone = StatusTone.neutral, });`  <sub>:351</sub>
    - `Widget build(BuildContext context) => …`  <sub>:365</sub>
- `class MetricValue extends StatelessWidget` — A right aligned number that acts as the visual anchor of one row.
  <sub>class · widgets/summary_strip.dart:499</sub>
    - `const MetricValue( this.value, { super.key, this.prominent = false, this.tone = StatusTone.neutral, this.suffix, });`  <sub>:500</sub>
    - `Widget build(BuildContext context) => …`  <sub>:514</sub>

## widgets/telemetry_instrument_card.dart

- `class TelemetryInstrumentCard extends StatelessWidget` — Composite tactile telemetry instrument card:
  <sub>class · widgets/telemetry_instrument_card.dart:13</sub>
    - `const TelemetryInstrumentCard({ super.key, required this.vial, required this.title, required this.statusLabel, this.statusTone = StatusTone.neutral, required this.headline, this.subheadline, this.segments = const [], this.barLeadingCaption, this.barTrailingCaption, this.sectionTitle, this.sectionBadge, this.sectionBadgeTone = StatusTone.success, this.switcher, this.meters = const [], });`  <sub>:14</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:61</sub>

## widgets/telemetry_primitives.dart

- `class BarSegment` — One colored segment inside [SegmentedCapsuleBar].
  <sub>class · widgets/telemetry_primitives.dart:7</sub>
    - `const BarSegment({ required this.fraction, required this.startColor, required this.endColor, });`  <sub>:8</sub>
- `class TelemetryMeterData` — One horizontal meter row inside `TelemetryInstrumentCard`
  <sub>class · widgets/telemetry_primitives.dart:21</sub>
    - `const TelemetryMeterData({ required this.label, required this.trailing, this.ratio, this.startColor = const Color(0xFF0B68F5), this.endColor = const Color(0xFF38BDF8), });`  <sub>:22</sub>
- `class TelemetryPill extends StatelessWidget` — Glowing dot + crisp label pill used in telemetry card headers.
  <sub>class · widgets/telemetry_primitives.dart:40</sub>
    - `const TelemetryPill({ super.key, required this.label, this.tone = StatusTone.neutral, this.dotColor, });`  <sub>:41</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:62</sub>
- `class SegmentedCapsuleBar extends StatelessWidget` — Recessed multi-segment rounded capsule bar.
  <sub>class · widgets/telemetry_primitives.dart:125</sub>
    - `const SegmentedCapsuleBar({ super.key, required this.segments, this.height = 7.5, });`  <sub>:126</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:136</sub>
- `class TelemetryModeSwitcher extends StatelessWidget` — Compact pill switcher for multi-mode telemetry panels.
  <sub>class · widgets/telemetry_primitives.dart:191</sub>
    - `const TelemetryModeSwitcher({ super.key, required this.labels, required this.selectedIndex, required this.onSelected, });`  <sub>:192</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:211</sub>

## widgets/top_bounce_scroll_physics.dart

- `class TopBounceScrollPhysics extends BouncingScrollPhysics` — Bounces only past the top edge (so pull-to-refresh keeps working) and clamps
  <sub>class · widgets/top_bounce_scroll_physics.dart:9</sub>
    - `const TopBounceScrollPhysics({super.parent});`  <sub>:10</sub>
    - `TopBounceScrollPhysics applyTo(ScrollPhysics? ancestor) => …`  <sub>:13</sub>
    - `double applyBoundaryConditions(ScrollMetrics position, double value) {…}`  <sub>:17</sub>
    - `Simulation? createBallisticSimulation( ScrollMetrics position, double velocity, ) {…}`  <sub>:32</sub>

## widgets/verified_route_label.dart

- `class VerifiedRouteLabel extends StatefulWidget` — Reads an in-process identity snapshot, never probes school connectivity.
  <sub>class · widgets/verified_route_label.dart:8</sub>
    - `const VerifiedRouteLabel({ super.key, required this.gateway, this.revision = 0, });`  <sub>:9</sub>
    - `State<VerifiedRouteLabel> createState() => …`  <sub>:18</sub>

## widgets/visual_section.dart

- `class TodayVisualDivider extends StatelessWidget` — A quiet inset rule for rows nested inside a reveal animation.
  <sub>class · widgets/visual_section.dart:7</sub>
    - `const TodayVisualDivider({super.key});`  <sub>:8</sub>
    - `Widget build(BuildContext context) => …`  <sub>:11</sub>
- `class TodayVisualSection extends StatelessWidget` — Shared structured section wrapper with secondary header and muted footer.
  <sub>class · widgets/visual_section.dart:26</sub>
    - `const TodayVisualSection({ super.key, required this.children, this.header, this.footer, });`  <sub>:27</sub>
    - `Widget build(BuildContext context) => …`  <sub>:38</sub>
- `class TodaySectionHeader extends StatelessWidget` — A structured section header with theme icon, bold title, count capsule badge,
  <sub>class · widgets/visual_section.dart:68</sub>
    - `const TodaySectionHeader({ super.key, required this.title, this.icon, this.badge, this.actionLabel, this.actionKey, this.onAction, });`  <sub>:69</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:87</sub>
