# Flutter 功能域：classroom

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。

`flutter/lib/features/classroom/` 的页面、域内组件与模型。

## ClassroomDetail (class)

- `class ClassroomDetail extends StatelessWidget {`  
  <sub>features/classroom/classroom_detail.dart:8</sub>
    - `const ClassroomDetail({ super.key, required this.room, required this.building, });`  <sub>:9</sub>
    - `Widget build(BuildContext context) => CupertinoPageScaffold( backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom( context, ), naviga…`  <sub>:17</sub>

## ClassroomRoomRow (typedef)

- `typedef ClassroomRoomRow = ({String building, ClassroomRow room});` — One matched room together with the building it belongs to.  
  <sub>features/classroom/classroom_models.dart:4</sub>

## ClassroomFilters (class)

- `class ClassroomFilters {` — Filter and sort selection of one classroom query. The page owns the  
  <sub>features/classroom/classroom_models.dart:8</sub>
    - `bool get isActive => section != 0 \|\|` — Whether the current selection narrows the published result.  <sub>:21</sub>
    - `void reset() { section = 0; minimumFree = 0; minimumConsecutive = 0; sort = ClassroomSort.name; }`  <sub>:27</sub>

## ClassroomPage (class)

- `class ClassroomPage extends StatefulWidget {`  
  <sub>features/classroom/classroom_page.dart:20</sub>
    - `const ClassroomPage({super.key, required this.service});`  <sub>:21</sub>
    - `State<ClassroomPage> createState() => _ClassroomPageState();`  <sub>:24</sub>

## ClassroomResultList (class)

- `class ClassroomResultList extends StatelessWidget {` — Windowed list of matched rooms. The building name heads the first row of  
  <sub>features/classroom/classroom_results.dart:13</sub>
    - `const ClassroomResultList({ super.key, required this.rows, required this.window, });`  <sub>:14</sub>
    - `Widget build(BuildContext context) => SliverList.builder( itemCount: window.end - window.start, findChildIndexCallback: (key) { if (key is! ValueKey<…`  <sub>:23</sub>

## ClassroomEmptyResults (class)

- `class ClassroomEmptyResults extends StatelessWidget {` — Empty state of a finished query that matched no room.  
  <sub>features/classroom/classroom_results.dart:55</sub>
    - `const ClassroomEmptyResults({super.key});`  <sub>:56</sub>
    - `Widget build(BuildContext context) => const SliverToBoxAdapter( child: AppleSection( animateSize: false, children: [ AppleEmptyState(title: '没有符合条件的空…`  <sub>:59</sub>

## ClassroomScopeSection (class)

- `class ClassroomScopeSection extends StatelessWidget {` — Campus, day and the query entry point. The school date is read once by  
  <sub>features/classroom/classroom_sections.dart:13</sub>
    - `const ClassroomScopeSection({ super.key, required this.campus, required this.date, required this.today, required this.tomorrow, required this.busy, r…`  <sub>:14</sub>
    - `Future<void> pickDate(BuildContext context) async { final selected = await showClassroomDatePicker( context, DateTime.parse(date), ); if (!context.mo…`  <sub>:36</sub>
    - `Widget build(BuildContext context) => AppleSection( animateSize: false, header: const Text('查询范围'), footer: Text( isDemo ? '结果在 5 分钟内优先复用本机样例缓存。' : '…`  <sub>:46</sub>

## ClassroomFilterSection (class)

- `class ClassroomFilterSection extends StatelessWidget {` — Collapsible filter and sort panel. The page owns the applied selection and  
  <sub>features/classroom/classroom_sections.dart:126</sub>
    - `const ClassroomFilterSection({ super.key, required this.filters, required this.expanded, required this.hasFilters, required this.queried, required th…`  <sub>:127</sub>
    - `Widget build(BuildContext context) => AppleSection( animateSize: false, footer: hasFilters && queried ? Text('筛选后共 $roomCount 间教室。') : null, children…`  <sub>:145</sub>

## ClassroomResultSummarySection (class)

- `class ClassroomResultSummarySection extends StatelessWidget {` — Provenance of the shown results: when they were read, how many rooms they  
  <sub>features/classroom/classroom_sections.dart:210</sub>
    - `const ClassroomResultSummarySection({ super.key, required this.result, required this.isDemo, required this.hasFilters, required this.onClearFilters, …`  <sub>:211</sub>
    - `Widget build(BuildContext context) => AppleSection( animateSize: false, children: [ if (result.fetchedAt != null) AppleListTile( title: const Text('查…`  <sub>:223</sub>

## ClassroomFooterNote (class)

- `class ClassroomFooterNote extends StatelessWidget {` — Closing note of the page: the data source boundary and the shared rule  
  <sub>features/classroom/classroom_sections.dart:266</sub>
    - `const ClassroomFooterNote({ super.key, required this.isDemo, required this.onOpenRules, });`  <sub>:267</sub>
    - `Widget build(BuildContext context) => Column( children: [ Padding( padding: const EdgeInsets.fromLTRB(32, 24, 32, 0), child: Text( isDemo ? '离线合成样例，不…`  <sub>:276</sub>

## ClassroomNoticeTile (class)

- `class ClassroomNoticeTile extends StatelessWidget {` — Stale-result notice shown when a previous snapshot is still displayed.  
  <sub>features/classroom/classroom_status.dart:8</sub>
    - `const ClassroomNoticeTile({super.key, required this.notice});`  <sub>:9</sub>
    - `Widget build(BuildContext context) => AppleSection( animateSize: false, children: [ AppleListTile( key: const Key('classroom-stale-notice'), leading:…`  <sub>:13</sub>

## ClassroomMessageState (class)

- `class ClassroomMessageState extends StatelessWidget {` — Message panel used for failures and for the state before the first query.  
  <sub>features/classroom/classroom_status.dart:31</sub>
    - `const ClassroomMessageState({ super.key, required this.title, required this.description, this.error = false, this.action, this.onAction, });`  <sub>:32</sub>
    - `Widget build(BuildContext context) => AppleSection( animateSize: false, children: [ AppleEmptyState( title: title, description: description, error: e…`  <sub>:46</sub>

## ClassroomLoadingState (class)

- `class ClassroomLoadingState extends StatelessWidget {` — First read of the page. The detail line names the step that is running.  
  <sub>features/classroom/classroom_status.dart:61</sub>
    - `const ClassroomLoadingState({super.key, required this.initializing});`  <sub>:62</sub>
    - `Widget build(BuildContext context) => AppleSection( animateSize: false, children: [ GinkgoLoadingView( label: '正在读取空教室…', detail: initializing ? '正在读…`  <sub>:66</sub>

## ClassroomRefreshingState (class)

- `class ClassroomRefreshingState extends StatelessWidget {` — Refresh on top of an existing result. The previous snapshot stays visible  
  <sub>features/classroom/classroom_status.dart:79</sub>
    - `const ClassroomRefreshingState({super.key});`  <sub>:80</sub>
    - `Widget build(BuildContext context) => AppleSection( animateSize: false, children: [ Padding( key: const Key('classroom-refreshing'), padding: const E…`  <sub>:83</sub>

## ClassroomResultsHeader (class)

- `class ClassroomResultsHeader extends StatelessWidget {` — Pinned controls above the classroom results: search, building filter,  
  <sub>features/classroom/classroom_widgets.dart:11</sub>
    - `const ClassroomResultsHeader({ super.key, required this.search, required this.buildings, required this.window, required this.busy, required this.onSe…`  <sub>:12</sub>
    - `Widget build(BuildContext context) => CollectionQuerySurface( child: Column( children: [ Padding( padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), c…`  <sub>:38</sub>

## ClassroomResultTile (class)

- `class ClassroomResultTile extends StatelessWidget {` — One room in the result list. The building name is only rendered as a  
  <sub>features/classroom/classroom_widgets.dart:128</sub>
    - `const ClassroomResultTile({ super.key, required this.room, required this.building, required this.heading, required this.onTap, });`  <sub>:129</sub>
    - `Widget build(BuildContext context) => Padding( padding: const EdgeInsets.symmetric(horizontal: 16), child: Column( crossAxisAlignment: CrossAxisAlign…`  <sub>:142</sub>

## ClassroomSectionStates (class)

- `class ClassroomSectionStates extends StatelessWidget {` — Availability of every section of one room. The grid mirrors what the  
  <sub>features/classroom/classroom_widgets.dart:193</sub>
    - `const ClassroomSectionStates({super.key, required this.states});`  <sub>:194</sub>
    - `Widget build(BuildContext context) => Padding( padding: const EdgeInsets.all(12), child: LayoutBuilder( builder: (context, constraints) { final textS…`  <sub>:198</sub>

## ClassroomShortcutButton (class)

- `class ClassroomShortcutButton extends StatelessWidget {` — Shortcut to today or tomorrow. Disabled until the school date is known.  
  <sub>features/classroom/classroom_widgets.dart:271</sub>
    - `const ClassroomShortcutButton({ super.key, required this.title, required this.value, required this.onSelected, this.enabled = true, });`  <sub>:272</sub>
    - `Widget build(BuildContext context) => CupertinoButton.tinted( key: Key('classroom-shortcut-$title'), padding: const EdgeInsets.symmetric(horizontal: …`  <sub>:285</sub>

## ClassroomFilterPicker (class)

- `class ClassroomFilterPicker<T> extends StatelessWidget {` — One filter row backed by a picker sheet. The page applies the value and  
  <sub>features/classroom/classroom_widgets.dart:297</sub>
    - `const ClassroomFilterPicker({ super.key, required this.title, required this.value, required this.values, required this.label, required this.onSelecte…`  <sub>:298</sub>
    - `final String Function(T) label;`  <sub>:309</sub>
    - `Widget build(BuildContext context) => ApplePickerTile<T>( title: title, value: value, values: values, label: label, onSelected: onSelected, );`  <sub>:313</sub>
