# 共享呈现组件（flutter/lib/widgets）

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
设计系统之上的可复用组件。

## 目录

- [widgets/apple_controls.dart](#widgetsapplecontrolsdart) (2)
- [widgets/apple_navigation.dart](#widgetsapplenavigationdart) (2)
- [widgets/apple_surfaces.dart](#widgetsapplesurfacesdart) (4)
- [widgets/collection_toolbar.dart](#widgetscollectiontoolbardart) (3)
- [widgets/day_scroll_physics.dart](#widgetsdayscrollphysicsdart) (1)
- [widgets/diagnostic_hints.dart](#widgetsdiagnostichintsdart) (1)
- [widgets/loading_widgets.dart](#widgetsloadingwidgetsdart) (5)
- [widgets/long_page_scroll.dart](#widgetslongpagescrolldart) (1)
- [widgets/reminder_badge.dart](#widgetsreminderbadgedart) (1)
- [widgets/resource_meter.dart](#widgetsresourcemeterdart) (1)

## widgets/apple_controls.dart

- `class AppleGlassButton extends StatefulWidget`
  <sub>class · widgets/apple_controls.dart:147</sub>
    - `const AppleGlassButton( {…}`  <sub>:148</sub>
    - `State<AppleGlassButton> createState() => _AppleGlassButtonState();`  <sub>:158</sub>
- `class ApplePickerTile<T> extends StatelessWidget`
  <sub>class · widgets/apple_controls.dart:260</sub>
    - `const ApplePickerTile( {…}`  <sub>:261</sub>
    - `final String Function(T) label;`  <sub>:273</sub>
    - `final void Function(T) onSelected;`  <sub>:274</sub>
    - `Widget build(BuildContext context) => Builder( builder: (anchorContext) => AppleListTil … olors.inactiveGray, ), onTap: !enabled ? null : () async {…}`  <sub>:277</sub>

## widgets/apple_navigation.dart

- `class AppleContentTransition extends StatelessWidget` — macOS reference uses 180–200ms easeInOut for content/state changes.
  <sub>class · widgets/apple_navigation.dart:8</sub>
    - `const AppleContentTransition( {…}`  <sub>:9</sub>
    - `Widget build(BuildContext context) => TweenAnimationBuilder<double>( key: ValueKey(iden … ) => Opacity(opacity: value, child: child), child: child, );`  <sub>:17</sub>
- `class AppleNavigationItem extends StatefulWidget` — A persistent desktop destination with pointer, focus and selection feedback.
  <sub>class · widgets/apple_navigation.dart:28</sub>
    - `const AppleNavigationItem( {…}`  <sub>:29</sub>
    - `State<AppleNavigationItem> createState() => _AppleNavigationItemState();`  <sub>:43</sub>

## widgets/apple_surfaces.dart

- `class ApplePageHeader extends StatelessWidget` — Phone pages keep the native collapsing title. Wide windows use the same
  <sub>class · widgets/apple_surfaces.dart:9</sub>
    - `const ApplePageHeader( {…}`  <sub>:10</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:32</sub>
- `class AppleEmptyState extends StatelessWidget`
  <sub>class · widgets/apple_surfaces.dart:130</sub>
    - `const AppleEmptyState( {…}`  <sub>:131</sub>
    - `Widget build(BuildContext context) => Padding( padding: const EdgeInsets.symmetric(vert … oButton(onPressed: onAction, child: Text(action!)), ], ), );`  <sub>:146</sub>
- `class AppleSection extends StatelessWidget` — Modern inset groups use a continuous corner, a quiet content surface and
  <sub>class · widgets/apple_surfaces.dart:182</sub>
    - `const AppleSection( {…}`  <sub>:183</sub>
    - `Widget build(BuildContext context) => Padding( padding: EdgeInsets.only(top: AppleDesig … abel.resolveFrom(context), ), child: footer!, ), ), ], ), );`  <sub>:194</sub>
- `class AppleListTile extends StatelessWidget`
  <sub>class · widgets/apple_surfaces.dart:275</sub>
    - `const AppleListTile( {…}`  <sub>:276</sub>
    - `Widget build(BuildContext context) => ConstrainedBox( constraints: BoxConstraints(minHe … : 10, ), leadingToTitle: 12, leadingSize: leadingSize, ), );`  <sub>:293</sub>

## widgets/collection_toolbar.dart

- `class CollectionToolbar extends StatelessWidget` — Reusable navigation for large result sets. Query controls stay above it in
  <sub>class · widgets/collection_toolbar.dart:10</sub>
    - `const CollectionToolbar( {…}`  <sub>:11</sub>
    - `Widget build(BuildContext context) => Padding( padding: const EdgeInsets.symmetric(hori … lexible( child: Text( window.count == 0 ? '0 $unit' : '$ {…}`  <sub>:30</sub>
- `class CollectionQuerySurface extends StatelessWidget` — Opaque separation keeps moving rows from competing with query controls.
  <sub>class · widgets/collection_toolbar.dart:137</sub>
    - `const CollectionQuerySurface( {…}`  <sub>:138</sub>
    - `Widget build(BuildContext context) => DecoratedBox( decoration: BoxDecoration( color: C … .resolveFrom(context), width: 0.5, ), ), ), child: child, );`  <sub>:141</sub>
- `class CollectionAnchor` — A non-pinned marker gives page/filter changes a stable start of results.
  <sub>class · widgets/collection_toolbar.dart:157</sub>
    - `Widget get sliver => SliverToBoxAdapter(child: SizedBox(key: _key));`  <sub>:159</sub>
    - `void reveal(ScrollController controller) {…}`  <sub>:161</sub>

## widgets/day_scroll_physics.dart

- `class DayScrollPhysics extends ScrollPhysics` — Touch flings settle on a day boundary, while wheel and thumb movement remain
  <sub>class · widgets/day_scroll_physics.dart:5</sub>
    - `const DayScrollPhysics( {…}`  <sub>:6</sub>
    - `DayScrollPhysics applyTo(ScrollPhysics? ancestor) => DayScrollPhysics(dayWidth: dayWidth, parent: buildParent(ancestor));`  <sub>:10</sub>
    - `Simulation? createBallisticSimulation( ScrollMetrics position, double velocity, ) {…}`  <sub>:14</sub>

## widgets/diagnostic_hints.dart

- `class DiagnosticHintOverlay extends StatelessWidget`
  <sub>class · widgets/diagnostic_hints.dart:6</sub>
    - `const DiagnosticHintOverlay( {…}`  <sub>:7</sub>
    - `Widget build(BuildContext context) => ListenableBuilder( listenable: DiagnosticLog.shared, builder: (context, _) {…}`  <sub>:10</sub>

## widgets/loading_widgets.dart

- `class GinkgoActivity extends StatefulWidget` — A small ginkgo fan breathes without suggesting a measured percentage.
  <sub>class · widgets/loading_widgets.dart:10</sub>
    - `const GinkgoActivity( {…}`  <sub>:11</sub>
    - `State<GinkgoActivity> createState() => _GinkgoActivityState();`  <sub>:15</sub>
- `class GinkgoLoadingView extends StatelessWidget` — Unified first-load feedback: a branded leaf plus one stable live-region
  <sub>class · widgets/loading_widgets.dart:102</sub>
    - `const GinkgoLoadingView( {…}`  <sub>:103</sub>
    - `Widget build(BuildContext context) => Semantics( liveRegion: true, label: detail == nul … gn.statusInactive.resolveFrom(context), ), ), ], ], ), ), );`  <sub>:115</sub>
- `class SectionFeedback extends StatelessWidget` — Stable, inline status: stale content stays in place during refresh/failure.
  <sub>class · widgets/loading_widgets.dart:156</sub>
    - `const SectionFeedback( {…}`  <sub>:157</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:171</sub>
- `class SectionReveal extends StatelessWidget` — Fade only on first insertion; later refreshes keep layout and content steady.
  <sub>class · widgets/loading_widgets.dart:218</sub>
    - `const SectionReveal( {…}`  <sub>:219</sub>
    - `Widget build(BuildContext context) => TweenAnimationBuilder<double>( tween: Tween(begin … ) => Opacity(opacity: value, child: child), child: child, );`  <sub>:223</sub>
- `class PageRefreshShortcut extends StatelessWidget` — Desktop refresh lives in the focused page, including its search fields.
  <sub>class · widgets/loading_widgets.dart:232</sub>
    - `const PageRefreshShortcut( {…}`  <sub>:233</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:238</sub>

## widgets/long_page_scroll.dart

- `class LongPageScroll extends StatelessWidget` — Shared long-page navigation without rebuilding the list on each scroll tick.
  <sub>class · widgets/long_page_scroll.dart:7</sub>
    - `const LongPageScroll( {…}`  <sub>:8</sub>
    - `Widget build(BuildContext context) => Stack( children: [ CupertinoScrollbar( controller … tedBuilder( animation: controller, builder: (context, _) {…}`  <sub>:17</sub>

## widgets/reminder_badge.dart

- `class ReminderBadge extends StatelessWidget` — iOS-style unread capsule: semantic label, no color-only meaning.
  <sub>class · widgets/reminder_badge.dart:4</sub>
    - `const ReminderBadge( {…}`  <sub>:5</sub>
    - `Widget build(BuildContext context) => Stack( clipBehavior: Clip.none, children: [ child … tSize: 10, fontWeight: FontWeight.w600, ), ), ), ), ), ], );`  <sub>:9</sub>

## widgets/resource_meter.dart

- `class ResourceMeter extends StatelessWidget` — A resource snapshot. A free fraction is not a booking guarantee; unknown
  <sub>class · widgets/resource_meter.dart:7</sub>
    - `const ResourceMeter( {…}`  <sub>:8</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:23</sub>
