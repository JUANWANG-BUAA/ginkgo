# Flutter 功能域：classroom

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
`flutter/lib/features/classroom/` 的页面、域内组件与模型。

## features/classroom/classroom_detail.dart

- `class ClassroomDetail extends StatelessWidget`
  <sub>class · features/classroom/classroom_detail.dart:8</sub>
    - `const ClassroomDetail( {…}`  <sub>:9</sub>
    - `Widget build(BuildContext context) => CupertinoPageScaffold( backgroundColor: Cupertino … Tile( title: const Text('空闲节次'), additionalInfo: Text('$ {…}`  <sub>:17</sub>

## features/classroom/classroom_models.dart

- `typedef ClassroomRoomRow = ({String building, ClassroomRow room});` — One matched room together with the building it belongs to.
  <sub>typedef · features/classroom/classroom_models.dart:4</sub>
- `class ClassroomFilters` — Filter and sort selection of one classroom query. The page owns the
  <sub>class · features/classroom/classroom_models.dart:8</sub>
    - `bool get isActive => section != 0 \|\|` — Whether the current selection narrows the published result.  <sub>:21</sub>
    - `void reset() {…}`  <sub>:27</sub>

## features/classroom/classroom_page.dart

- `class ClassroomPage extends StatefulWidget`
  <sub>class · features/classroom/classroom_page.dart:20</sub>
    - `const ClassroomPage( {…}`  <sub>:21</sub>
    - `State<ClassroomPage> createState() => _ClassroomPageState();`  <sub>:24</sub>

## features/classroom/classroom_results.dart

- `class ClassroomResultList extends StatelessWidget` — Windowed list of matched rooms. The building name heads the first row of
  <sub>class · features/classroom/classroom_results.dart:13</sub>
    - `const ClassroomResultList( {…}`  <sub>:14</sub>
    - `Widget build(BuildContext context) => SliverList.builder( itemCount: window.end - window.start, findChildIndexCallback: (key) {…}`  <sub>:23</sub>
- `class ClassroomEmptyResults extends StatelessWidget` — Empty state of a finished query that matched no room.
  <sub>class · features/classroom/classroom_results.dart:55</sub>
    - `const ClassroomEmptyResults( {…}`  <sub>:56</sub>
    - `Widget build(BuildContext context) => const SliverToBoxAdapter( child: AppleSection( an … e: '没有符合条件的空教室', description: '请调整日期、楼栋、节次或筛选条件。'), ], ), );`  <sub>:59</sub>

## features/classroom/classroom_sections.dart

- `class ClassroomScopeSection extends StatelessWidget` — Campus, day and the query entry point. The school date is read once by
  <sub>class · features/classroom/classroom_sections.dart:13</sub>
    - `const ClassroomScopeSection( {…}`  <sub>:14</sub>
    - `Future<void> pickDate(BuildContext context) async {…}`  <sub>:36</sub>
    - `Widget build(BuildContext context) => AppleSection( animateSize: false, header: const T … ue: campus, values: const [1, 2, 3], label: (n) => const {…}`  <sub>:46</sub>
- `class ClassroomFilterSection extends StatelessWidget` — Collapsible filter and sort panel. The page owns the applied selection and
  <sub>class · features/classroom/classroom_sections.dart:126</sub>
    - `const ClassroomFilterSection( {…}`  <sub>:127</sub>
    - `Widget build(BuildContext context) => AppleSection( animateSize: false, footer: hasFilt … : (n) => n == 0 ? '任意节次' : '第 $n 节', onSelected: (value) {…}`  <sub>:145</sub>
- `class ClassroomResultSummarySection extends StatelessWidget` — Provenance of the shown results: when they were read, how many rooms they
  <sub>class · features/classroom/classroom_sections.dart:210</sub>
    - `const ClassroomResultSummarySection( {…}`  <sub>:211</sub>
    - `Widget build(BuildContext context) => AppleSection( animateSize: false, children: [ if … tionalInfo: Semantics( liveRegion: true, child: Text( '$ {…}`  <sub>:223</sub>
- `class ClassroomFooterNote extends StatelessWidget` — Closing note of the page: the data source boundary and the shared rule
  <sub>class · features/classroom/classroom_sections.dart:266</sub>
    - `const ClassroomFooterNote( {…}`  <sub>:267</sub>
    - `Widget build(BuildContext context) => Column( children: [ Padding( padding: const EdgeI … onst SizedBox(height: 24), const SizedBox(height: 96), ], );`  <sub>:276</sub>

## features/classroom/classroom_status.dart

- `class ClassroomNoticeTile extends StatelessWidget` — Stale-result notice shown when a previous snapshot is still displayed.
  <sub>class · features/classroom/classroom_status.dart:8</sub>
    - `const ClassroomNoticeTile( {…}`  <sub>:9</sub>
    - `Widget build(BuildContext context) => AppleSection( animateSize: false, children: [ App … ors.systemOrange, size: 20, ), title: Text(notice), ), ], );`  <sub>:13</sub>
- `class ClassroomMessageState extends StatelessWidget` — Message panel used for failures and for the state before the first query.
  <sub>class · features/classroom/classroom_status.dart:31</sub>
    - `const ClassroomMessageState( {…}`  <sub>:32</sub>
    - `Widget build(BuildContext context) => AppleSection( animateSize: false, children: [ App … , error: error, action: action, onAction: onAction, ), ], );`  <sub>:46</sub>
- `class ClassroomLoadingState extends StatelessWidget` — First read of the page. The detail line names the step that is running.
  <sub>class · features/classroom/classroom_status.dart:61</sub>
    - `const ClassroomLoadingState( {…}`  <sub>:62</sub>
    - `Widget build(BuildContext context) => AppleSection( animateSize: false, children: [ Gin … 在读取空教室…', detail: initializing ? '正在读取学校日期' : null, ), ], );`  <sub>:66</sub>
- `class ClassroomRefreshingState extends StatelessWidget` — Refresh on top of an existing result. The previous snapshot stays visible
  <sub>class · features/classroom/classroom_status.dart:79</sub>
    - `const ClassroomRefreshingState( {…}`  <sub>:80</sub>
    - `Widget build(BuildContext context) => AppleSection( animateSize: false, children: [ Pad … const SizedBox(width: 10), Text('正在刷新空教室…'), ], ), ), ], );`  <sub>:83</sub>

## features/classroom/classroom_widgets.dart

- `class ClassroomResultsHeader extends StatelessWidget` — Pinned controls above the classroom results: search, building filter,
  <sub>class · features/classroom/classroom_widgets.dart:11</sub>
    - `const ClassroomResultsHeader( {…}`  <sub>:12</sub>
    - `Widget build(BuildContext context) => CollectionQuerySurface( child: Column( children: … oom-building-picker'), onPressed: busy ? null : () async {…}`  <sub>:38</sub>
- `class ClassroomResultTile extends StatelessWidget` — One room in the result list. The building name is only rendered as a
  <sub>class · features/classroom/classroom_widgets.dart:128</sub>
    - `const ClassroomResultTile( {…}`  <sub>:129</sub>
    - `Widget build(BuildContext context) => Padding( padding: const EdgeInsets.symmetric(hori … tyle(fontWeight: FontWeight.w500), ), subtitle: Text( '$ {…}`  <sub>:142</sub>
- `class ClassroomSectionStates extends StatelessWidget` — Availability of every section of one room. The grid mirrors what the
  <sub>class · features/classroom/classroom_widgets.dart:193</sub>
    - `const ClassroomSectionStates( {…}`  <sub>:194</sub>
    - `Widget build(BuildContext context) => Padding( padding: const EdgeInsets.all(12), child: LayoutBuilder( builder: (context, constraints) {…}`  <sub>:198</sub>
- `class ClassroomShortcutButton extends StatelessWidget` — Shortcut to today or tomorrow. Disabled until the school date is known.
  <sub>class · features/classroom/classroom_widgets.dart:271</sub>
    - `const ClassroomShortcutButton( {…}`  <sub>:272</sub>
    - `Widget build(BuildContext context) => CupertinoButton.tinted( key: Key('classroom-short … child: Text(title, style: const TextStyle(fontSize: 17)), );`  <sub>:285</sub>
- `class ClassroomFilterPicker<T> extends StatelessWidget` — One filter row backed by a picker sheet. The page applies the value and
  <sub>class · features/classroom/classroom_widgets.dart:297</sub>
    - `const ClassroomFilterPicker( {…}`  <sub>:298</sub>
    - `final String Function(T) label;`  <sub>:309</sub>
    - `Widget build(BuildContext context) => ApplePickerTile<T>( title: title, value: value, values: values, label: label, onSelected: onSelected, );`  <sub>:313</sub>
