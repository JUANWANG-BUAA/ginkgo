# Flutter 功能域：shuttle

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
`flutter/lib/features/shuttle/` 的页面、域内组件与模型。

## features/shuttle/shuttle_page.dart

- `class ShuttlePage extends StatefulWidget` — Official shuttle timetable. Only the published page is shown: the app does
  <sub>class · features/shuttle/shuttle_page.dart:17</sub>
    - `const ShuttlePage({super.key, required this.service, this.now});`  <sub>:18</sub>
    - `State<ShuttlePage> createState() => …`  <sub>:25</sub>

## features/shuttle/shuttle_widgets.dart

- `String shuttleCapacityLabel(String capacity) => …` — The capacity the school printed for a run. A missing number stays
  <sub>function · features/shuttle/shuttle_widgets.dart:11</sub>
- `class ShuttlePlanSection extends StatelessWidget` — Next departure and at most two follow-ups, derived only from the
  <sub>class · features/shuttle/shuttle_widgets.dart:17</sub>
    - `const ShuttlePlanSection({ super.key, required this.runs, required this.clock, });`  <sub>:18</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:28</sub>
- `class ShuttlePlanNext extends StatelessWidget` — The next departure, shown large because it is the one to catch.
  <sub>class · features/shuttle/shuttle_widgets.dart:72</sub>
    - `const ShuttlePlanNext({super.key, required this.run});`  <sub>:73</sub>
    - `Widget build(BuildContext context) => …`  <sub>:78</sub>
- `class ShuttlePlanFollowing extends StatelessWidget` — A departure after the next one.
  <sub>class · features/shuttle/shuttle_widgets.dart:126</sub>
    - `const ShuttlePlanFollowing({ super.key, required this.run, required this.index, });`  <sub>:127</sub>
    - `Widget build(BuildContext context) => …`  <sub>:137</sub>
- `class ShuttleTableSection extends StatelessWidget` — One dated section of a published table: both directions and their runs.
  <sub>class · features/shuttle/shuttle_widgets.dart:190</sub>
    - `const ShuttleTableSection({ super.key, required this.section, required this.leftName, required this.rightName, required this.nowMinute, });`  <sub>:191</sub>
    - `Widget build(BuildContext context) => …`  <sub>:204</sub>
- `class ShuttleDirectionRuns extends StatelessWidget` — One direction of a published table and the runs printed under it.
  <sub>class · features/shuttle/shuttle_widgets.dart:257</sub>
    - `const ShuttleDirectionRuns({ super.key, required this.name, required this.runs, required this.nowMinute, });`  <sub>:258</sub>
    - `Widget build(BuildContext context) => …`  <sub>:270</sub>
- `class ShuttleRunChip extends StatelessWidget` — One published run. Departed runs fall back to a quiet fill so the
  <sub>class · features/shuttle/shuttle_widgets.dart:295</sub>
    - `const ShuttleRunChip({super.key, required this.run, required this.departed});`  <sub>:296</sub>
    - `Widget build(BuildContext context) => …`  <sub>:302</sub>
