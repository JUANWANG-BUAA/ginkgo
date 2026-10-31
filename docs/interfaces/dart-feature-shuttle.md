# Flutter 功能域：shuttle

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
`flutter/lib/features/shuttle/` 的页面、域内组件与模型。

## features/shuttle/shuttle_page.dart

- `class ShuttlePage extends StatefulWidget` — Official shuttle timetable. Only the published page is shown: the app does
  <sub>class · features/shuttle/shuttle_page.dart:18</sub>
    - `const ShuttlePage({super.key, required this.service, this.now});`  <sub>:19</sub>
    - `State<ShuttlePage> createState() => …`  <sub>:26</sub>

## features/shuttle/shuttle_widgets.dart

- `String shuttleCapacityLabel(String capacity) => …` — The capacity the school printed for a run. A missing number stays
  <sub>function · features/shuttle/shuttle_widgets.dart:11</sub>
- `class ShuttlePlanSection extends StatelessWidget` — Next departure and at most two follow-ups, derived only from the
  <sub>class · features/shuttle/shuttle_widgets.dart:17</sub>
    - `const ShuttlePlanSection({ super.key, required this.runs, required this.clock, });`  <sub>:18</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:28</sub>
- `class ShuttlePlanNext extends StatelessWidget` — The next departure, shown large because it is the one to catch.
  <sub>class · features/shuttle/shuttle_widgets.dart:70</sub>
    - `const ShuttlePlanNext({super.key, required this.run});`  <sub>:71</sub>
    - `Widget build(BuildContext context) => …`  <sub>:76</sub>
- `class ShuttlePlanFollowing extends StatelessWidget` — A departure after the next one.
  <sub>class · features/shuttle/shuttle_widgets.dart:124</sub>
    - `const ShuttlePlanFollowing({ super.key, required this.run, required this.index, });`  <sub>:125</sub>
    - `Widget build(BuildContext context) => …`  <sub>:135</sub>
- `class ShuttleTableSection extends StatelessWidget` — One dated section of a published table: both directions and their runs.
  <sub>class · features/shuttle/shuttle_widgets.dart:188</sub>
    - `const ShuttleTableSection({ super.key, required this.section, required this.leftName, required this.rightName, required this.nowMinute, });`  <sub>:189</sub>
    - `Widget build(BuildContext context) => …`  <sub>:202</sub>
- `class ShuttleDirectionRuns extends StatelessWidget` — One direction of a published table and the runs printed under it.
  <sub>class · features/shuttle/shuttle_widgets.dart:255</sub>
    - `const ShuttleDirectionRuns({ super.key, required this.name, required this.runs, required this.nowMinute, });`  <sub>:256</sub>
    - `Widget build(BuildContext context) => …`  <sub>:268</sub>
- `class ShuttleRunChip extends StatelessWidget` — One published run. Departed runs fall back to a quiet fill so the
  <sub>class · features/shuttle/shuttle_widgets.dart:293</sub>
    - `const ShuttleRunChip({super.key, required this.run, required this.departed});`  <sub>:294</sub>
    - `Widget build(BuildContext context) => …`  <sub>:300</sub>
