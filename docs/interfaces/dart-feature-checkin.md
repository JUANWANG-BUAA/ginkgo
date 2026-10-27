# Flutter 功能域：checkin

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。

`flutter/lib/features/checkin/` 的页面、域内组件与模型。

## CheckInLoading (class)

- `class CheckInLoading extends StatefulWidget {` — Polls local progress only; never sends another authentication/read request.  
  <sub>features/checkin/checkin_loading.dart:11</sub>
    - `const CheckInLoading({ super.key, required this.isDemo, required this.service, });`  <sub>:12</sub>
    - `State<CheckInLoading> createState() => _CheckInLoadingState();`  <sub>:20</sub>

## CheckinProgressTelemetry (class)

- `class CheckinProgressTelemetry {` — Optional iClass progress telemetry attached to a check-in read. Local hint  
  <sub>features/checkin/checkin_models.dart:5</sub>

## CheckInPage (class)

- `class CheckInPage extends StatefulWidget {` — Confirmed per-course submission with a subsequent status read.  
  <sub>features/checkin/checkin_page.dart:20</sub>
    - `const CheckInPage({ super.key, required this.service, this.history = false, this.clock, });`  <sub>:21</sub>
    - `final DateTime Function()? clock;`  <sub>:29</sub>
    - `State<CheckInPage> createState() => _CheckInPageState();`  <sub>:31</sub>

## CheckinCourseRow (class)

- `class CheckinCourseRow extends StatelessWidget {` — One course with its sign-in status, merged-record notes and the single  
  <sub>features/checkin/checkin_widgets.dart:11</sub>
    - `const CheckinCourseRow({ super.key, required this.course, required this.windowOpen, required this.canSubmit, required this.submitting, required this.…`  <sub>:12</sub>
    - `Widget build(BuildContext context) { final (icon, semanticColor, label) = switch (course.status) { CheckInStatus.signed => ( CupertinoIcons.checkmark…`  <sub>:32</sub>

## CheckinStatusSummary (class)

- `class CheckinStatusSummary extends StatelessWidget {` — Day totals: count tile, proportional status meter and readable legend.  
  <sub>features/checkin/checkin_widgets.dart:149</sub>
    - `const CheckinStatusSummary({ super.key, required this.dateLabel, required this.scopeLabel, required this.signed, required this.notSigned, required th…`  <sub>:150</sub>
    - `Widget build(BuildContext context) { return AppleSection( header: Text(dateLabel), children: [ AppleListTile( title: Text(scopeLabel), subtitle: Text…`  <sub>:166</sub>
