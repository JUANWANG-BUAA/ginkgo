# Flutter 功能域：shuttle

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。

`flutter/lib/features/shuttle/` 的页面、域内组件与模型。

## ShuttleRun (class)

- `class ShuttleRun {` — One scheduled departure as printed by the school.  
  <sub>features/shuttle/shuttle_models.dart:7</sub>
    - `int? get minuteOfDay { final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(time); if (match == null) return null; final hour = int.parse(match[1]…` — Minutes past midnight, or null when the printed time is not `H:mm`.  <sub>:15</sub>

## ShuttleSection (class)

- `class ShuttleSection {` — One direction pair under a validity label such as "星期一至星期五".  
  <sub>features/shuttle/shuttle_models.dart:26</sub>
    - `bool appliesToday(int weekday) { final text = label.replaceAll(' ', ''); if (text.isEmpty) return true; if (text.contains('每天') \|\| text.contains('每日'…` — Published validity labels name weekdays rather than dates. Only labels  <sub>:43</sub>

## ShuttleTable (class)

- `class ShuttleTable {` — One published table: two directions plus their dated sections.  
  <sub>features/shuttle/shuttle_models.dart:86</sub>

## ShuttleTimetable (class)

- `class ShuttleTimetable {`  
  <sub>features/shuttle/shuttle_models.dart:99</sub>
    - `List<ShuttleDeparture> todayRuns(DateTime clock) { final runs = <ShuttleDeparture>[]; final seen = <String>{}; for (final table in tables) { final di…` — Flattens every published run that applies today. Duplicate rows across  <sub>:108</sub>

## ShuttleDeparture (class)

- `class ShuttleDeparture {` — A today-applicable departure with its direction resolved from the table.  
  <sub>features/shuttle/shuttle_models.dart:145</sub>
    - `const ShuttleDeparture({ required this.direction, required this.time, required this.minutes, required this.capacity, });`  <sub>:146</sub>

## ShuttlePage (class)

- `class ShuttlePage extends StatefulWidget {` — Official shuttle timetable. Only the published page is shown: the app does  
  <sub>features/shuttle/shuttle_page.dart:17</sub>
    - `const ShuttlePage({super.key, required this.service, this.now});`  <sub>:18</sub>
    - `State<ShuttlePage> createState() => _ShuttlePageState();`  <sub>:25</sub>

## ShuttlePlanSection (class)

- `class ShuttlePlanSection extends StatelessWidget {` — Next departure and at most two follow-ups, derived only from the  
  <sub>features/shuttle/shuttle_widgets.dart:17</sub>
    - `const ShuttlePlanSection({ super.key, required this.runs, required this.clock, });`  <sub>:18</sub>
    - `Widget build(BuildContext context) { final nowMinute = clock.hour * 60 + clock.minute; final upcoming = runs .where((run) => run.minutes >= nowMinute…`  <sub>:28</sub>

## ShuttlePlanNext (class)

- `class ShuttlePlanNext extends StatelessWidget {` — The next departure, shown large because it is the one to catch.  
  <sub>features/shuttle/shuttle_widgets.dart:72</sub>
    - `const ShuttlePlanNext({super.key, required this.run});`  <sub>:73</sub>
    - `Widget build(BuildContext context) => MergeSemantics( child: Container( width: double.infinity, key: const Key('shuttle-plan-next'), padding: const E…`  <sub>:78</sub>

## ShuttlePlanFollowing (class)

- `class ShuttlePlanFollowing extends StatelessWidget {` — A departure after the next one.  
  <sub>features/shuttle/shuttle_widgets.dart:126</sub>
    - `const ShuttlePlanFollowing({ super.key, required this.run, required this.index, });`  <sub>:127</sub>
    - `Widget build(BuildContext context) => MergeSemantics( child: Container( width: double.infinity, key: Key('shuttle-plan-following-$index'), padding: c…`  <sub>:137</sub>

## ShuttleTableSection (class)

- `class ShuttleTableSection extends StatelessWidget {` — One dated section of a published table: both directions and their runs.  
  <sub>features/shuttle/shuttle_widgets.dart:190</sub>
    - `const ShuttleTableSection({ super.key, required this.section, required this.leftName, required this.rightName, required this.nowMinute, });`  <sub>:191</sub>
    - `Widget build(BuildContext context) => AppleSection( header: Text(section.label.isEmpty ? '公开时刻表' : section.label), children: [ Padding( padding: cons…`  <sub>:204</sub>

## ShuttleDirectionRuns (class)

- `class ShuttleDirectionRuns extends StatelessWidget {` — One direction of a published table and the runs printed under it.  
  <sub>features/shuttle/shuttle_widgets.dart:257</sub>
    - `const ShuttleDirectionRuns({ super.key, required this.name, required this.runs, required this.nowMinute, });`  <sub>:258</sub>
    - `Widget build(BuildContext context) => Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Text( name, style: const TextStyle(fontSize: …`  <sub>:270</sub>

## ShuttleRunChip (class)

- `class ShuttleRunChip extends StatelessWidget {` — One published run. Departed runs fall back to a quiet fill so the  
  <sub>features/shuttle/shuttle_widgets.dart:296</sub>
    - `const ShuttleRunChip({super.key, required this.run, required this.departed});`  <sub>:297</sub>
    - `Widget build(BuildContext context) => Container( padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration( color: d…`  <sub>:303</sub>
