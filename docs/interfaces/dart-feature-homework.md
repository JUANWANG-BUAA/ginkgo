# Flutter 功能域：homework

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。

`flutter/lib/features/homework/` 的页面、域内组件与模型。

## HomeworkDetailPage (class)

- `class HomeworkDetailPage extends StatefulWidget {`  
  <sub>features/homework/homework_detail_page.dart:18</sub>
    - `const HomeworkDetailPage({ super.key, required this.item, required this.service, this.taskService, this.storageRoot, this.openTaskOnLinked = true, });`  <sub>:19</sub>
    - `State<HomeworkDetailPage> createState() => _HomeworkDetailPageState();`  <sub>:33</sub>

## HomeworkFilesPanel (class)

- `class HomeworkFilesPanel extends StatefulWidget {`  
  <sub>features/homework/homework_files_panel.dart:12</sub>
    - `const HomeworkFilesPanel({ super.key, required this.assignmentId, required this.title, required this.course, required this.gateway, this.onSubmitted,…`  <sub>:13</sub>
    - `State<HomeworkFilesPanel> createState() => _HomeworkFilesPanelState();`  <sub>:29</sub>

## HomeworkSubmitSummary (class)

- `class HomeworkSubmitSummary extends StatelessWidget {` — 作业提交方式与次数摘要。  
  <sub>features/homework/homework_files_widgets.dart:51</sub>
    - `const HomeworkSubmitSummary({super.key, required this.data});`  <sub>:52</sub>
    - `Widget build(BuildContext context) => Column( children: [ CupertinoListTile( title: const Text('提交方式'), subtitle: Text( data.methods.isEmpty ? '未知' :…`  <sub>:57</sub>

## HomeworkAttachmentList (class)

- `class HomeworkAttachmentList extends StatelessWidget {` — 作业附件列表，每项提供保存入口。  
  <sub>features/homework/homework_files_widgets.dart:78</sub>
    - `const HomeworkAttachmentList({ super.key, required this.attachments, required this.busy, required this.onDownload, });`  <sub>:79</sub>
    - `Widget build(BuildContext context) => Column( children: [ for (final attachment in attachments) CupertinoListTile( title: Text(attachment.name, maxLi…`  <sub>:91</sub>

## HomeworkCapabilityNotes (class)

- `class HomeworkCapabilityNotes extends StatelessWidget {` — 不可用的提交能力说明。能力不可用时必须说明原因，避免用户反复重试。  
  <sub>features/homework/homework_files_widgets.dart:107</sub>
    - `const HomeworkCapabilityNotes({ super.key, required this.capabilities, required this.methods, });`  <sub>:108</sub>
    - `Widget build(BuildContext context) { final notes = capabilities.where( (c) => c.state != 'available' && (methods.contains( const { 'textSubmit': 'tex…`  <sub>:118</sub>

## HomeworkSubmitActions (class)

- `class HomeworkSubmitActions extends StatelessWidget {` — 个人文件作答的上传与提交操作区。  
  <sub>features/homework/homework_files_widgets.dart:154</sub>
    - `const HomeworkSubmitActions({ super.key, required this.limitBytes, required this.receipt, required this.uncertain, required this.busy, required this.…`  <sub>:155</sub>
    - `Widget build(BuildContext context) { final disabled = busy \|\| blocked; return Column( children: [ Padding( padding: const EdgeInsets.all(16), child: …`  <sub>:175</sub>

## HomeworkPendingSubmissionNotice (class)

- `class HomeworkPendingSubmissionNotice extends StatelessWidget {` — 本机待确认提交的提示与回查入口。  
  <sub>features/homework/homework_files_widgets.dart:213</sub>
    - `const HomeworkPendingSubmissionNotice({ super.key, required this.count, required this.busy, required this.onReconcile, });`  <sub>:214</sub>
    - `Widget build(BuildContext context) => Column( children: [ const Padding( padding: EdgeInsets.all(16), child: Text( '发现本机待确认提交。记录仅用于回查，不保存文件内容；确认结果前禁止…`  <sub>:226</sub>

## HomeworkFeedbackNote (class)

- `class HomeworkFeedbackNote extends StatelessWidget {` — 作业的教师评语与退回说明。  
  <sub>features/homework/homework_files_widgets.dart:244</sub>
    - `const HomeworkFeedbackNote({ super.key, required this.data, });`  <sub>:245</sub>
    - `Widget build(BuildContext context) => Column( children: [ if (data.returned) const CupertinoListTile(title: Text('作业已退回，请查看教师要求')), if (data.text?.is…`  <sub>:253</sub>

## HomeworkBlockedNote (class)

- `class HomeworkBlockedNote extends StatelessWidget {` — 作业提交被阻断时的原因说明。  
  <sub>features/homework/homework_files_widgets.dart:269</sub>
    - `const HomeworkBlockedNote({ super.key, required this.blockedReason, required this.canSubmit, });`  <sub>:270</sub>
    - `Widget build(BuildContext context) => Column( children: [ if (blockedReason != null) Padding( padding: const EdgeInsets.all(16), child: Text(blockedR…`  <sub>:280</sub>

## HomeworkPage (class)

- `class HomeworkPage extends StatefulWidget {`  
  <sub>features/homework/homework_page.dart:19</sub>
    - `const HomeworkPage({ super.key, required this.service, this.initialFilter = 0, this.now, });`  <sub>:20</sub>
    - `State<HomeworkPage> createState() => _HomeworkPageState();`  <sub>:30</sub>

## HomeworkDeadlineStatus (enum)

- `enum HomeworkDeadlineStatus {` — Orthogonal deadline status derived on the client; never mutates upstream  
  <sub>features/homework/homework_projection.dart:23</sub>

## HomeworkSummaryMetrics (class)

- `class HomeworkSummaryMetrics extends StatelessWidget {` — 顶部三项统计（待完成 / 已提交 / 已截止）。  
  <sub>features/homework/homework_widgets.dart:20</sub>
    - `const HomeworkSummaryMetrics({ super.key, required this.pending, required this.submitted, required this.overdue, });`  <sub>:21</sub>
    - `Widget build(BuildContext context) => Padding( padding: const EdgeInsets.all(16), child: LayoutBuilder( builder: (context, constraints) => Wrap( spac…`  <sub>:33</sub>

## HomeworkQuickFilter (class)

- `class HomeworkQuickFilter extends StatelessWidget {` — 状态快捷筛选按钮；再次点击同一项即回到「全部」。  
  <sub>features/homework/homework_widgets.dart:78</sub>
    - `const HomeworkQuickFilter({ super.key, required this.value, required this.label, required this.tint, required this.selected, required this.onPressed,…`  <sub>:79</sub>
    - `Widget build(BuildContext context) => CupertinoButton( padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), color: tint.resolveFrom(cont…`  <sub>:95</sub>

## HomeworkStatusBadge (class)

- `class HomeworkStatusBadge extends StatelessWidget {` — 作业状态徽标。已提交用成功色，已截止用危险色，待确认保留不确定色。  
  <sub>features/homework/homework_widgets.dart:108</sub>
    - `const HomeworkStatusBadge({ super.key, required this.status, required this.dueAt, required this.clock, });`  <sub>:109</sub>
    - `Widget build(BuildContext context) { final (label, color) = switch (status) { HomeworkStatus.submitted => ( '已提交', AppleDesign.statusSuccess.resolveF…`  <sub>:121</sub>

## HomeworkDeadlineText (class)

- `class HomeworkDeadlineText extends StatelessWidget {` — 单条作业的截止时间与倒计时描述。  
  <sub>features/homework/homework_widgets.dart:153</sub>
    - `const HomeworkDeadlineText({ super.key, required this.item, required this.clock, });`  <sub>:154</sub>
    - `Widget build(BuildContext context) { final late = item.status == HomeworkStatus.pending && isHomeworkOverdue(item.dueAt, clock); final relative = ite…`  <sub>:164</sub>

## HomeworkItemTile (class)

- `class HomeworkItemTile extends StatelessWidget {` — 作业列表项：标题、截止信息、课程与教师。  
  <sub>features/homework/homework_widgets.dart:208</sub>
    - `const HomeworkItemTile({ super.key, required this.item, required this.clock, required this.onTap, });`  <sub>:209</sub>
    - `Widget build(BuildContext context) => AppleListTile( key: Key('homework-${item.id}'), onTap: onTap, trailing: const CupertinoListTileChevron(), title…`  <sub>:221</sub>
