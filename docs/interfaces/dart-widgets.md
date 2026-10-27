# 共享呈现组件（flutter/lib/widgets）

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。

设计系统之上的可复用组件。

## AppleGlassButton (class)

- `class AppleGlassButton extends StatefulWidget {`  
  <sub>widgets/apple_controls.dart:147</sub>
    - `const AppleGlassButton({ super.key, required this.child, required this.onPressed, required this.label, });`  <sub>:148</sub>
    - `State<AppleGlassButton> createState() => _AppleGlassButtonState();`  <sub>:158</sub>

## ApplePickerTile (class)

- `class ApplePickerTile<T> extends StatelessWidget {`  
  <sub>widgets/apple_controls.dart:260</sub>
    - `const ApplePickerTile({ super.key, required this.title, required this.value, required this.values, required this.label, required this.onSelected, thi…`  <sub>:261</sub>
    - `final String Function(T) label;`  <sub>:273</sub>
    - `final void Function(T) onSelected;`  <sub>:274</sub>
    - `Widget build(BuildContext context) => Builder( builder: (anchorContext) => AppleListTile( title: Text(title), subtitle: Text( label(value), style: Te…`  <sub>:277</sub>

## AppleContentTransition (class)

- `class AppleContentTransition extends StatelessWidget {` — macOS reference uses 180–200ms easeInOut for content/state changes.  
  <sub>widgets/apple_navigation.dart:8</sub>
    - `const AppleContentTransition({ super.key, required this.identity, required this.child, });`  <sub>:9</sub>
    - `Widget build(BuildContext context) => TweenAnimationBuilder<double>( key: ValueKey(identity), tween: Tween(begin: 0, end: 1), duration: AppleDesign.d…`  <sub>:17</sub>

## AppleNavigationItem (class)

- `class AppleNavigationItem extends StatefulWidget {` — A persistent desktop destination with pointer, focus and selection feedback.  
  <sub>widgets/apple_navigation.dart:28</sub>
    - `const AppleNavigationItem({ super.key, required this.title, required this.icon, required this.selected, required this.onPressed, this.unreadCount = 0…`  <sub>:29</sub>
    - `State<AppleNavigationItem> createState() => _AppleNavigationItemState();`  <sub>:43</sub>

## ApplePageHeader (class)

- `class ApplePageHeader extends StatelessWidget {` — Phone pages keep the native collapsing title. Wide windows use the same  
  <sub>widgets/apple_surfaces.dart:9</sub>
    - `const ApplePageHeader({ super.key, required this.largeTitle, this.trailing, this.previousPageTitle, this.border, this.section, this.subtitle, this.ic…`  <sub>:10</sub>
    - `Widget build(BuildContext context) { if (!AppleDesign.desktop(context)) { return CupertinoSliverNavigationBar( largeTitle: largeTitle, previousPageTi…`  <sub>:32</sub>

## AppleEmptyState (class)

- `class AppleEmptyState extends StatelessWidget {`  
  <sub>widgets/apple_surfaces.dart:130</sub>
    - `const AppleEmptyState({ super.key, required this.title, required this.description, this.action, this.onAction, this.error = false, this.icon, });`  <sub>:131</sub>
    - `Widget build(BuildContext context) => Padding( padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16), child: Column( children: [ Icon( ic…`  <sub>:146</sub>

## AppleSection (class)

- `class AppleSection extends StatelessWidget {` — Modern inset groups use a continuous corner, a quiet content surface and  
  <sub>widgets/apple_surfaces.dart:182</sub>
    - `const AppleSection({ super.key, required this.children, this.header, this.footer, this.animateSize = true, });`  <sub>:183</sub>
    - `Widget build(BuildContext context) => Padding( padding: EdgeInsets.only(top: AppleDesign.desktop(context) ? 20 : 24), child: Column( crossAxisAlignme…`  <sub>:194</sub>

## AppleListTile (class)

- `class AppleListTile extends StatelessWidget {`  
  <sub>widgets/apple_surfaces.dart:275</sub>
    - `const AppleListTile({ super.key, required this.title, this.subtitle, this.additionalInfo, this.leading, this.trailing, this.onTap, this.minimumHeight…`  <sub>:276</sub>
    - `Widget build(BuildContext context) => ConstrainedBox( constraints: BoxConstraints(minHeight: minimumHeight), child: CupertinoListTile( title: _wrapTe…`  <sub>:293</sub>

## CollectionToolbar (class)

- `class CollectionToolbar extends StatelessWidget {` — Reusable navigation for large result sets. Query controls stay above it in  
  <sub>widgets/collection_toolbar.dart:10</sub>
    - `const CollectionToolbar({ super.key, required this.window, required this.onPageChanged, required this.unit, this.busy = false, this.error, this.onRet…`  <sub>:11</sub>
    - `Widget build(BuildContext context) => Padding( padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: Column( crossAxisAlignment: C…`  <sub>:30</sub>

## CollectionQuerySurface (class)

- `class CollectionQuerySurface extends StatelessWidget {` — Opaque separation keeps moving rows from competing with query controls.  
  <sub>widgets/collection_toolbar.dart:137</sub>
    - `const CollectionQuerySurface({super.key, required this.child});`  <sub>:138</sub>
    - `Widget build(BuildContext context) => DecoratedBox( decoration: BoxDecoration( color: CupertinoColors.systemGroupedBackground.resolveFrom(context), b…`  <sub>:141</sub>

## CollectionAnchor (class)

- `class CollectionAnchor {` — A non-pinned marker gives page/filter changes a stable start of results.  
  <sub>widgets/collection_toolbar.dart:157</sub>
    - `Widget get sliver => SliverToBoxAdapter(child: SizedBox(key: _key));`  <sub>:159</sub>
    - `void reveal(ScrollController controller) { WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(controller)); }`  <sub>:161</sub>

## DayScrollPhysics (class)

- `class DayScrollPhysics extends ScrollPhysics {` — Touch flings settle on a day boundary, while wheel and thumb movement remain  
  <sub>widgets/day_scroll_physics.dart:5</sub>
    - `const DayScrollPhysics({required this.dayWidth, super.parent});`  <sub>:6</sub>
    - `DayScrollPhysics applyTo(ScrollPhysics? ancestor) => DayScrollPhysics(dayWidth: dayWidth, parent: buildParent(ancestor));`  <sub>:10</sub>
    - `Simulation? createBallisticSimulation( ScrollMetrics position, double velocity, ) { if (position.outOfRange) { return super.createBallisticSimulation…`  <sub>:14</sub>

## DiagnosticHintOverlay (class)

- `class DiagnosticHintOverlay extends StatelessWidget {`  
  <sub>widgets/diagnostic_hints.dart:6</sub>
    - `const DiagnosticHintOverlay({super.key, required this.child});`  <sub>:7</sub>
    - `Widget build(BuildContext context) => ListenableBuilder( listenable: DiagnosticLog.shared, builder: (context, _) { final entry = DiagnosticLog.shared…`  <sub>:10</sub>

## GinkgoActivity (class)

- `class GinkgoActivity extends StatefulWidget {` — A small ginkgo fan breathes without suggesting a measured percentage.  
  <sub>widgets/loading_widgets.dart:10</sub>
    - `const GinkgoActivity({super.key, this.size = 22});`  <sub>:11</sub>
    - `State<GinkgoActivity> createState() => _GinkgoActivityState();`  <sub>:15</sub>

## GinkgoLoadingView (class)

- `class GinkgoLoadingView extends StatelessWidget {` — Unified first-load feedback: a branded leaf plus one stable live-region  
  <sub>widgets/loading_widgets.dart:102</sub>
    - `const GinkgoLoadingView({ super.key, required this.label, this.detail, this.compact = false, });`  <sub>:103</sub>
    - `Widget build(BuildContext context) => Semantics( liveRegion: true, label: detail == null ? label : '$label，$detail', excludeSemantics: true, child: P…`  <sub>:115</sub>

## SectionFeedback (class)

- `class SectionFeedback extends StatelessWidget {` — Stable, inline status: stale content stays in place during refresh/failure.  
  <sub>widgets/loading_widgets.dart:156</sub>
    - `const SectionFeedback({ super.key, required this.loading, required this.label, required this.hasData, this.error, this.onRetry, });`  <sub>:157</sub>
    - `Widget build(BuildContext context) { if (!loading && error == null) return const SizedBox.shrink(); return Semantics( liveRegion: true, child: Paddin…`  <sub>:171</sub>

## SectionReveal (class)

- `class SectionReveal extends StatelessWidget {` — Fade only on first insertion; later refreshes keep layout and content steady.  
  <sub>widgets/loading_widgets.dart:218</sub>
    - `const SectionReveal({super.key, required this.child});`  <sub>:219</sub>
    - `Widget build(BuildContext context) => TweenAnimationBuilder<double>( tween: Tween(begin: 0, end: 1), duration: AppleDesign.duration(context, 180), bu…`  <sub>:223</sub>

## PageRefreshShortcut (class)

- `class PageRefreshShortcut extends StatelessWidget {` — Desktop refresh lives in the focused page, including its search fields.  
  <sub>widgets/loading_widgets.dart:232</sub>
    - `const PageRefreshShortcut({super.key, required this.child, this.onRefresh});`  <sub>:233</sub>
    - `Widget build(BuildContext context) { if (!AppleDesign.desktop(context)) return child; void refresh() => onRefresh?.call(); return CallbackShortcuts( …`  <sub>:238</sub>

## LongPageScroll (class)

- `class LongPageScroll extends StatelessWidget {` — Shared long-page navigation without rebuilding the list on each scroll tick.  
  <sub>widgets/long_page_scroll.dart:7</sub>
    - `const LongPageScroll({ super.key, required this.controller, required this.child, });`  <sub>:8</sub>
    - `Widget build(BuildContext context) => Stack( children: [ CupertinoScrollbar( controller: controller, thumbVisibility: AppleDesign.desktop(context), t…`  <sub>:17</sub>

## ReminderBadge (class)

- `class ReminderBadge extends StatelessWidget {` — iOS-style unread capsule: semantic label, no color-only meaning.  
  <sub>widgets/reminder_badge.dart:4</sub>
    - `const ReminderBadge({super.key, required this.count, required this.child});`  <sub>:5</sub>
    - `Widget build(BuildContext context) => Stack( clipBehavior: Clip.none, children: [ child, if (count > 0) Positioned( right: -9, top: -7, child: Semant…`  <sub>:9</sub>

## ResourceMeter (class)

- `class ResourceMeter extends StatelessWidget {` — A resource snapshot. A free fraction is not a booking guarantee; unknown  
  <sub>widgets/resource_meter.dart:7</sub>
    - `const ResourceMeter({ super.key, required this.label, required this.available, required this.total, required this.unit, this.detail, this.onTap, });`  <sub>:8</sub>
    - `Widget build(BuildContext context) { final free = available; final capacity = total; final known = free != null && capacity != null; final countsLabe…`  <sub>:23</sub>
