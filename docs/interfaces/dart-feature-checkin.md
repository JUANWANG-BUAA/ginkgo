# Flutter 功能域：checkin

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
`flutter/lib/features/checkin/` 的页面、域内组件与模型。

## features/checkin/checkin_loading.dart

- `class CheckInLoading extends StatefulWidget` — Polls local progress only; never sends another authentication/read request.
  <sub>class · features/checkin/checkin_loading.dart:11</sub>
    - `const CheckInLoading({ super.key, required this.isDemo, required this.service, });`  <sub>:12</sub>
    - `State<CheckInLoading> createState() => …`  <sub>:20</sub>

## features/checkin/checkin_models.dart

- `class CheckinProgressTelemetry` — Optional iClass progress telemetry attached to a check-in read. Local hint
  <sub>class · features/checkin/checkin_models.dart:5</sub>
- `CheckinProgressTelemetry? checkinProgress(String payload) {…}`
  <sub>function · features/checkin/checkin_models.dart:14</sub>

## features/checkin/checkin_page.dart

- `class CheckInPage extends StatefulWidget` — Confirmed per-course submission with a subsequent status read.
  <sub>class · features/checkin/checkin_page.dart:22</sub>
    - `const CheckInPage({ super.key, required this.service, this.history = false, this.clock, });`  <sub>:23</sub>
    - `final DateTime Function()? clock;`  <sub>:31</sub>
    - `State<CheckInPage> createState() => …`  <sub>:33</sub>

## features/checkin/checkin_widgets.dart

- `class CheckinCourseRow extends StatelessWidget` — One course with its sign-in status, merged-record notes and the single
  <sub>class · features/checkin/checkin_widgets.dart:11</sub>
    - `const CheckinCourseRow({ super.key, required this.course, required this.windowOpen, required this.canSubmit, required this.submitting, required this.awaitingVerification, required this.onSubmit, });`  <sub>:12</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:32</sub>
- `class CheckinStatusSummary extends StatelessWidget` — Day totals: count tile, proportional status meter and readable legend.
  <sub>class · features/checkin/checkin_widgets.dart:149</sub>
    - `const CheckinStatusSummary({ super.key, required this.dateLabel, required this.scopeLabel, required this.signed, required this.notSigned, required this.unknown, required this.fetchedAt, });`  <sub>:150</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:166</sub>
