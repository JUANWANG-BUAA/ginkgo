# Flutter 功能域：homework

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
`flutter/lib/features/homework/` 的页面、域内组件与模型。

## features/homework/homework_detail_page.dart

- `class HomeworkDetailPage extends StatefulWidget`
  <sub>class · features/homework/homework_detail_page.dart:19</sub>
    - `const HomeworkDetailPage({ super.key, required this.item, required this.service, this.taskService, this.storageRoot, this.openTaskOnLinked = true, });`  <sub>:20</sub>
    - `State<HomeworkDetailPage> createState() => …`  <sub>:34</sub>

## features/homework/homework_files_panel.dart

- `class HomeworkFilesPanel extends StatefulWidget`
  <sub>class · features/homework/homework_files_panel.dart:12</sub>
    - `const HomeworkFilesPanel({ super.key, required this.assignmentId, required this.title, required this.course, required this.gateway, this.onSubmitted, this.pickFile = pickHomeworkFile, this.saveFile, });`  <sub>:13</sub>
    - `State<HomeworkFilesPanel> createState() => …`  <sub>:29</sub>

## features/homework/homework_files_widgets.dart

- `String homeworkSubmitMethodLabel(String method) => …` — 学校提交方式的中文名。未识别的取值原样保留，便于排查协议变化。
  <sub>function · features/homework/homework_files_widgets.dart:6</sub>
- `String homeworkAttachmentKindLabel(String kind) => …` — 附件种类的中文名。
  <sub>function · features/homework/homework_files_widgets.dart:17</sub>
- `String homeworkCapabilityLabel(String capability) => …` — 提交能力的中文名。
  <sub>function · features/homework/homework_files_widgets.dart:28</sub>
- `String homeworkCapabilityStateLabel(String state) => …` — 提交能力状态的中文名。
  <sub>function · features/homework/homework_files_widgets.dart:40</sub>
- `class HomeworkSubmitSummary extends StatelessWidget` — 作业提交方式与次数摘要。
  <sub>class · features/homework/homework_files_widgets.dart:51</sub>
    - `const HomeworkSubmitSummary({super.key, required this.data});`  <sub>:52</sub>
    - `Widget build(BuildContext context) => …`  <sub>:57</sub>
- `class HomeworkAttachmentList extends StatelessWidget` — 作业附件列表，每项提供保存入口。
  <sub>class · features/homework/homework_files_widgets.dart:78</sub>
    - `const HomeworkAttachmentList({ super.key, required this.attachments, required this.busy, required this.onDownload, });`  <sub>:79</sub>
    - `Widget build(BuildContext context) => …`  <sub>:91</sub>
- `class HomeworkCapabilityNotes extends StatelessWidget` — 不可用的提交能力说明。能力不可用时必须说明原因，避免用户反复重试。
  <sub>class · features/homework/homework_files_widgets.dart:107</sub>
    - `const HomeworkCapabilityNotes({ super.key, required this.capabilities, required this.methods, });`  <sub>:108</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:118</sub>
- `class HomeworkSubmitActions extends StatelessWidget` — 个人文件作答的上传与提交操作区。
  <sub>class · features/homework/homework_files_widgets.dart:154</sub>
    - `const HomeworkSubmitActions({ super.key, required this.limitBytes, required this.receipt, required this.uncertain, required this.busy, required this.blocked, required this.onUpload, required this.onSubmit, });`  <sub>:155</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:175</sub>
- `class HomeworkPendingSubmissionNotice extends StatelessWidget` — 本机待确认提交的提示与回查入口。
  <sub>class · features/homework/homework_files_widgets.dart:213</sub>
    - `const HomeworkPendingSubmissionNotice({ super.key, required this.count, required this.busy, required this.onReconcile, });`  <sub>:214</sub>
    - `Widget build(BuildContext context) => …`  <sub>:226</sub>
- `class HomeworkFeedbackNote extends StatelessWidget` — 作业的教师评语与退回说明。
  <sub>class · features/homework/homework_files_widgets.dart:242</sub>
    - `const HomeworkFeedbackNote({super.key, required this.data});`  <sub>:243</sub>
    - `Widget build(BuildContext context) => …`  <sub>:248</sub>
- `class HomeworkBlockedNote extends StatelessWidget` — 作业提交被阻断时的原因说明。
  <sub>class · features/homework/homework_files_widgets.dart:263</sub>
    - `const HomeworkBlockedNote({ super.key, required this.blockedReason, required this.canSubmit, });`  <sub>:264</sub>
    - `Widget build(BuildContext context) => …`  <sub>:274</sub>

## features/homework/homework_page.dart

- `class HomeworkPage extends StatefulWidget`
  <sub>class · features/homework/homework_page.dart:21</sub>
    - `const HomeworkPage({ super.key, required this.service, this.initialFilter = 0, this.now, });`  <sub>:22</sub>
    - `State<HomeworkPage> createState() => …`  <sub>:32</sub>

## features/homework/homework_projection.dart

- `enum HomeworkDeadlineStatus`
  <sub>enum · features/homework/homework_projection.dart:8</sub>
- `HomeworkDeadlineStatus classifyHomeworkDeadline( String? dueAt, [ DateTime? beijingNow, ]) {…}` — Classify a homework deadline against Beijing wall clock time.
  <sub>function · features/homework/homework_projection.dart:29</sub>
- `bool isHomeworkOverdue(String? dueAt, [DateTime? beijingNow]) => …` — Helper to test if a deadline is strictly classified as overdue.
  <sub>function · features/homework/homework_projection.dart:61</sub>
- `String? homeworkRelativeDeadline(String? dueAt, [DateTime? beijingNow]) {…}` — Returns an intuitive relative deadline countdown with 00:00 midnight warning.
  <sub>function · features/homework/homework_projection.dart:72</sub>
- `String homeworkCompactDeadline(String? dueAt, [DateTime? beijingNow]) {…}` — Produces a strict single-line, unambiguous deadline string (under 22 chars).
  <sub>function · features/homework/homework_projection.dart:138</sub>
- `CupertinoDynamicColor homeworkDeadlineTint( String? dueAt, [ DateTime? beijingNow, ]) {…}` — Color for the deadline status:
  <sub>function · features/homework/homework_projection.dart:213</sub>

## features/homework/homework_widgets.dart

- `String homeworkFilterLabel(int value) => …` — 作业状态筛选文案。取值与 [HomeworkPage] 的筛选器一一对应。
  <sub>function · features/homework/homework_widgets.dart:11</sub>
- `class HomeworkSummaryMetrics extends StatelessWidget` — 顶部三项统计（待完成 / 已提交 / 已截止）。
  <sub>class · features/homework/homework_widgets.dart:20</sub>
    - `const HomeworkSummaryMetrics({ super.key, required this.pending, required this.submitted, required this.overdue, });`  <sub>:21</sub>
    - `Widget build(BuildContext context) => …`  <sub>:33</sub>
- `class HomeworkQuickFilter extends StatelessWidget` — 状态快捷筛选按钮；再次点击同一项即回到「全部」。
  <sub>class · features/homework/homework_widgets.dart:80</sub>
    - `const HomeworkQuickFilter({ super.key, required this.value, required this.label, required this.tint, required this.selected, required this.onPressed, });`  <sub>:81</sub>
    - `Widget build(BuildContext context) => …`  <sub>:97</sub>
- `class HomeworkStatusBadge extends StatelessWidget` — 作业状态徽标。已提交用成功色，已截止用危险色，待确认保留不确定色。
  <sub>class · features/homework/homework_widgets.dart:110</sub>
    - `const HomeworkStatusBadge({ super.key, required this.status, required this.dueAt, required this.clock, });`  <sub>:111</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:123</sub>
- `class HomeworkDeadlineText extends StatelessWidget` — 单条作业的截止时间与倒计时描述。
  <sub>class · features/homework/homework_widgets.dart:159</sub>
    - `const HomeworkDeadlineText({ super.key, required this.item, required this.clock, });`  <sub>:160</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:170</sub>
- `class HomeworkItemTile extends StatelessWidget` — 作业列表项：标题、截止信息、课程与教师。
  <sub>class · features/homework/homework_widgets.dart:211</sub>
    - `const HomeworkItemTile({ super.key, required this.item, required this.clock, required this.onTap, });`  <sub>:212</sub>
    - `Widget build(BuildContext context) => …`  <sub>:224</sub>
