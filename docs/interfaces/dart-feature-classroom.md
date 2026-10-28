# Flutter 功能域：classroom

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
`flutter/lib/features/classroom/` 的页面、域内组件与模型。

## features/classroom/classroom_detail.dart

- `class ClassroomDetail extends StatelessWidget`
  <sub>class · features/classroom/classroom_detail.dart:8</sub>
    - `const ClassroomDetail({ super.key, required this.room, required this.building, });`  <sub>:9</sub>
    - `Widget build(BuildContext context) => …`  <sub>:17</sub>

## features/classroom/classroom_models.dart

- `typedef ClassroomRoomRow = ({String building, ClassroomRow room});` — One matched room together with the building it belongs to.
  <sub>typedef · features/classroom/classroom_models.dart:4</sub>
- `class ClassroomFilters` — Filter and sort selection of one classroom query. The page owns the
  <sub>class · features/classroom/classroom_models.dart:8</sub>
    - `bool get isActive => …` — Whether the current selection narrows the published result.  <sub>:21</sub>
    - `void reset() {…}`  <sub>:27</sub>

## features/classroom/classroom_page.dart

- `class ClassroomPage extends StatefulWidget`
  <sub>class · features/classroom/classroom_page.dart:20</sub>
    - `const ClassroomPage({super.key, required this.service});`  <sub>:21</sub>
    - `State<ClassroomPage> createState() => …`  <sub>:24</sub>

## features/classroom/classroom_results.dart

- `class ClassroomResultList extends StatelessWidget` — Windowed list of matched rooms. The building name heads the first row of
  <sub>class · features/classroom/classroom_results.dart:13</sub>
    - `const ClassroomResultList({ super.key, required this.rows, required this.window, });`  <sub>:14</sub>
    - `Widget build(BuildContext context) => …`  <sub>:23</sub>
- `class ClassroomEmptyResults extends StatelessWidget` — Empty state of a finished query that matched no room.
  <sub>class · features/classroom/classroom_results.dart:55</sub>
    - `const ClassroomEmptyResults({super.key});`  <sub>:56</sub>
    - `Widget build(BuildContext context) => …`  <sub>:59</sub>

## features/classroom/classroom_sections.dart

- `class ClassroomScopeSection extends StatelessWidget` — Campus, day and the query entry point. The school date is read once by
  <sub>class · features/classroom/classroom_sections.dart:13</sub>
    - `const ClassroomScopeSection({ super.key, required this.campus, required this.date, required this.today, required this.tomorrow, required this.busy, required this.initializing, required this.isDemo, required this.onCampusChanged, required this.onDateChanged, required this.onShortcutDate, required this.onQuery, });`  <sub>:14</sub>
    - `Future<void> pickDate(BuildContext context) async {…}`  <sub>:36</sub>
    - `Widget build(BuildContext context) => …`  <sub>:46</sub>
- `class ClassroomFilterSection extends StatelessWidget` — Collapsible filter and sort panel. The page owns the applied selection and
  <sub>class · features/classroom/classroom_sections.dart:126</sub>
    - `const ClassroomFilterSection({ super.key, required this.filters, required this.expanded, required this.hasFilters, required this.queried, required this.roomCount, required this.onToggle, required this.onChanged, });`  <sub>:127</sub>
    - `Widget build(BuildContext context) => …`  <sub>:145</sub>
- `class ClassroomResultSummarySection extends StatelessWidget` — Provenance of the shown results: when they were read, how many rooms they
  <sub>class · features/classroom/classroom_sections.dart:210</sub>
    - `const ClassroomResultSummarySection({ super.key, required this.result, required this.isDemo, required this.hasFilters, required this.onClearFilters, });`  <sub>:211</sub>
    - `Widget build(BuildContext context) => …`  <sub>:223</sub>
- `class ClassroomFooterNote extends StatelessWidget` — Closing note of the page: the data source boundary and the shared rule
  <sub>class · features/classroom/classroom_sections.dart:266</sub>
    - `const ClassroomFooterNote({ super.key, required this.isDemo, required this.onOpenRules, });`  <sub>:267</sub>
    - `Widget build(BuildContext context) => …`  <sub>:276</sub>
- `Future<DateTime?> showClassroomDatePicker( BuildContext context, DateTime initial, ) async {…}` — Picks one day inside the supported range. The picked day is reported to
  <sub>function · features/classroom/classroom_sections.dart:300</sub>

## features/classroom/classroom_status.dart

- `class ClassroomNoticeTile extends StatelessWidget` — Stale-result notice shown when a previous snapshot is still displayed.
  <sub>class · features/classroom/classroom_status.dart:8</sub>
    - `const ClassroomNoticeTile({super.key, required this.notice});`  <sub>:9</sub>
    - `Widget build(BuildContext context) => …`  <sub>:13</sub>
- `class ClassroomMessageState extends StatelessWidget` — Message panel used for failures and for the state before the first query.
  <sub>class · features/classroom/classroom_status.dart:31</sub>
    - `const ClassroomMessageState({ super.key, required this.title, required this.description, this.error = false, this.action, this.onAction, });`  <sub>:32</sub>
    - `Widget build(BuildContext context) => …`  <sub>:46</sub>
- `class ClassroomLoadingState extends StatelessWidget` — First read of the page. The detail line names the step that is running.
  <sub>class · features/classroom/classroom_status.dart:61</sub>
    - `const ClassroomLoadingState({super.key, required this.initializing});`  <sub>:62</sub>
    - `Widget build(BuildContext context) => …`  <sub>:66</sub>
- `class ClassroomRefreshingState extends StatelessWidget` — Refresh on top of an existing result. The previous snapshot stays visible
  <sub>class · features/classroom/classroom_status.dart:79</sub>
    - `const ClassroomRefreshingState({super.key});`  <sub>:80</sub>
    - `Widget build(BuildContext context) => …`  <sub>:83</sub>

## features/classroom/classroom_widgets.dart

- `class ClassroomResultsHeader extends StatelessWidget` — Pinned controls above the classroom results: search, building filter,
  <sub>class · features/classroom/classroom_widgets.dart:11</sub>
    - `const ClassroomResultsHeader({ super.key, required this.search, required this.buildings, required this.window, required this.busy, required this.onSearch, required this.onClear, required this.onBuilding, required this.onFilters, required this.onPage, this.selectedBuilding, this.error, this.onRetry, });`  <sub>:12</sub>
    - `Widget build(BuildContext context) => …`  <sub>:38</sub>
- `class ClassroomResultTile extends StatelessWidget` — One room in the result list. The building name is only rendered as a
  <sub>class · features/classroom/classroom_widgets.dart:128</sub>
    - `const ClassroomResultTile({ super.key, required this.room, required this.building, required this.heading, required this.onTap, });`  <sub>:129</sub>
    - `Widget build(BuildContext context) => …`  <sub>:142</sub>
- `class ClassroomSectionStates extends StatelessWidget` — Availability of every section of one room. The grid mirrors what the
  <sub>class · features/classroom/classroom_widgets.dart:193</sub>
    - `const ClassroomSectionStates({super.key, required this.states});`  <sub>:194</sub>
    - `Widget build(BuildContext context) => …`  <sub>:198</sub>
- `class ClassroomShortcutButton extends StatelessWidget` — Shortcut to today or tomorrow. Disabled until the school date is known.
  <sub>class · features/classroom/classroom_widgets.dart:271</sub>
    - `const ClassroomShortcutButton({ super.key, required this.title, required this.value, required this.onSelected, this.enabled = true, });`  <sub>:272</sub>
    - `Widget build(BuildContext context) => …`  <sub>:285</sub>
- `class ClassroomFilterPicker<T> extends StatelessWidget` — One filter row backed by a picker sheet. The page applies the value and
  <sub>class · features/classroom/classroom_widgets.dart:297</sub>
    - `const ClassroomFilterPicker({ super.key, required this.title, required this.value, required this.values, required this.label, required this.onSelected, });`  <sub>:298</sub>
    - `final String Function(T) label;`  <sub>:309</sub>
    - `Widget build(BuildContext context) => …`  <sub>:313</sub>
