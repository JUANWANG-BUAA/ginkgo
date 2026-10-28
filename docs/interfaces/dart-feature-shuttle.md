# Flutter 功能域：shuttle

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
`flutter/lib/features/shuttle/` 的页面、域内组件与模型。

## features/shuttle/shuttle_models.dart

- `class ShuttleRun` — One scheduled departure as printed by the school.
  <sub>class · features/shuttle/shuttle_models.dart:7</sub>
    - `int? get minuteOfDay {…}` — Minutes past midnight, or null when the printed time is not `H:mm`.  <sub>:15</sub>
- `class ShuttleSection` — One direction pair under a validity label such as "星期一至星期五".
  <sub>class · features/shuttle/shuttle_models.dart:26</sub>
    - `bool appliesToday(int weekday) {…}` — Published validity labels name weekdays rather than dates. Only labels  <sub>:43</sub>
- `class ShuttleTable` — One published table: two directions plus their dated sections.
  <sub>class · features/shuttle/shuttle_models.dart:86</sub>
- `class ShuttleTimetable`
  <sub>class · features/shuttle/shuttle_models.dart:99</sub>
    - `List<ShuttleDeparture> todayRuns(DateTime clock) {…}` — Flattens every published run that applies today. Duplicate rows across  <sub>:108</sub>
- `class ShuttleDeparture` — A today-applicable departure with its direction resolved from the table.
  <sub>class · features/shuttle/shuttle_models.dart:145</sub>
    - `const ShuttleDeparture( {…}`  <sub>:146</sub>

## features/shuttle/shuttle_page.dart

- `class ShuttlePage extends StatefulWidget` — Official shuttle timetable. Only the published page is shown: the app does
  <sub>class · features/shuttle/shuttle_page.dart:17</sub>
    - `const ShuttlePage( {…}`  <sub>:18</sub>
    - `State<ShuttlePage> createState() => _ShuttlePageState();`  <sub>:25</sub>

## features/shuttle/shuttle_widgets.dart

- `class ShuttlePlanSection extends StatelessWidget` — Next departure and at most two follow-ups, derived only from the
  <sub>class · features/shuttle/shuttle_widgets.dart:17</sub>
    - `const ShuttlePlanSection( {…}`  <sub>:18</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:28</sub>
- `class ShuttlePlanNext extends StatelessWidget` — The next departure, shown large because it is the one to catch.
  <sub>class · features/shuttle/shuttle_widgets.dart:72</sub>
    - `const ShuttlePlanNext( {…}`  <sub>:73</sub>
    - `Widget build(BuildContext context) => MergeSemantics( child: Container( width: double.i … statusInactive.resolveFrom(context), ), ), ], ), ], ), ), );`  <sub>:78</sub>
- `class ShuttlePlanFollowing extends StatelessWidget` — A departure after the next one.
  <sub>class · features/shuttle/shuttle_widgets.dart:126</sub>
    - `const ShuttlePlanFollowing( {…}`  <sub>:127</sub>
    - `Widget build(BuildContext context) => MergeSemantics( child: Container( width: double.i … olors.secondaryLabel.resolveFrom(context), ), ), ], ), ), );`  <sub>:137</sub>
- `class ShuttleTableSection extends StatelessWidget` — One dated section of a published table: both directions and their runs.
  <sub>class · features/shuttle/shuttle_widgets.dart:190</sub>
    - `const ShuttleTableSection( {…}`  <sub>:191</sub>
    - `Widget build(BuildContext context) => AppleSection( header: Text(section.label.isEmpty … ), child: LayoutBuilder( builder: (context, constraints) {…}`  <sub>:204</sub>
- `class ShuttleDirectionRuns extends StatelessWidget` — One direction of a published table and the runs printed under it.
  <sub>class · features/shuttle/shuttle_widgets.dart:257</sub>
    - `const ShuttleDirectionRuns( {…}`  <sub>:258</sub>
    - `Widget build(BuildContext context) => Column( crossAxisAlignment: CrossAxisAlignment.st … fDay != null && run.minuteOfDay! < nowMinute, ), ], ), ], );`  <sub>:270</sub>
- `class ShuttleRunChip extends StatelessWidget` — One published run. Departed runs fall back to a quiet fill so the
  <sub>class · features/shuttle/shuttle_widgets.dart:296</sub>
    - `const ShuttleRunChip( {…}`  <sub>:297</sub>
    - `Widget build(BuildContext context) => Container( padding: const EdgeInsets.symmetric(ho … 8), ), child: Text( run.capacity.isEmpty ? run.time : '$ {…}`  <sub>:303</sub>
