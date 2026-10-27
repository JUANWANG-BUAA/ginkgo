# Flutter 功能域：homework

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。

`flutter/lib/features/homework/` 的页面、域内组件与模型。

## features/homework/homework_detail_page.dart

- `class HomeworkDetailPage extends StatefulWidget`  
  <sub>class · features/homework/homework_detail_page.dart:18</sub>
    - `const HomeworkDetailPage( {…}`  <sub>:19</sub>
    - `State<HomeworkDetailPage> createState() => _HomeworkDetailPageState();`  <sub>:33</sub>

## features/homework/homework_files_panel.dart

- `class HomeworkFilesPanel extends StatefulWidget`  
  <sub>class · features/homework/homework_files_panel.dart:12</sub>
    - `const HomeworkFilesPanel( {…}`  <sub>:13</sub>
    - `State<HomeworkFilesPanel> createState() => _HomeworkFilesPanelState();`  <sub>:29</sub>

## features/homework/homework_files_widgets.dart

- `class HomeworkSubmitSummary extends StatelessWidget` — 作业提交方式与次数摘要。  
  <sub>class · features/homework/homework_files_widgets.dart:51</sub>
    - `const HomeworkSubmitSummary( {…}`  <sub>:52</sub>
    - `Widget build(BuildContext context) => Column( children: [ CupertinoListTile( title: con … tTile( title: const Text('提交次数'), subtitle: Text( '已提交 $ {…}`  <sub>:57</sub>
- `class HomeworkAttachmentList extends StatelessWidget` — 作业附件列表，每项提供保存入口。  
  <sub>class · features/homework/homework_files_widgets.dart:78</sub>
    - `const HomeworkAttachmentList( {…}`  <sub>:79</sub>
    - `Widget build(BuildContext context) => Column( children: [ for (final attachment in atta … onDownload(attachment), child: const Text('保存'), ), ), ], );`  <sub>:91</sub>
- `class HomeworkCapabilityNotes extends StatelessWidget` — 不可用的提交能力说明。能力不可用时必须说明原因，避免用户反复重试。  
  <sub>class · features/homework/homework_files_widgets.dart:107</sub>
    - `const HomeworkCapabilityNotes( {…}`  <sub>:108</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:118</sub>
- `class HomeworkSubmitActions extends StatelessWidget` — 个人文件作答的上传与提交操作区。  
  <sub>class · features/homework/homework_files_widgets.dart:154</sub>
    - `const HomeworkSubmitActions( {…}`  <sub>:155</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:175</sub>
- `class HomeworkPendingSubmissionNotice extends StatelessWidget` — 本机待确认提交的提示与回查入口。  
  <sub>class · features/homework/homework_files_widgets.dart:213</sub>
    - `const HomeworkPendingSubmissionNotice( {…}`  <sub>:214</sub>
    - `Widget build(BuildContext context) => Column( children: [ const Padding( padding: EdgeI … null : () => onReconcile(index), child: Text('回查待确认提交 $ {…}`  <sub>:226</sub>
- `class HomeworkFeedbackNote extends StatelessWidget` — 作业的教师评语与退回说明。  
  <sub>class · features/homework/homework_files_widgets.dart:244</sub>
    - `const HomeworkFeedbackNote( {…}`  <sub>:245</sub>
    - `Widget build(BuildContext context) => Column( children: [ if (data.returned) const Cupe … ng( padding: const EdgeInsets.all(16), child: Text('评语：$ {…}`  <sub>:253</sub>
- `class HomeworkBlockedNote extends StatelessWidget` — 作业提交被阻断时的原因说明。  
  <sub>class · features/homework/homework_files_widgets.dart:269</sub>
    - `const HomeworkBlockedNote( {…}`  <sub>:270</sub>
    - `Widget build(BuildContext context) => Column( children: [ if (blockedReason != null) Pa … l(16), child: Text('当前作业个人文件提交条件尚未确认或不支持，请在官网核对。'), ), ], );`  <sub>:280</sub>

## features/homework/homework_page.dart

- `class HomeworkPage extends StatefulWidget`  
  <sub>class · features/homework/homework_page.dart:19</sub>
    - `const HomeworkPage( {…}`  <sub>:20</sub>
    - `State<HomeworkPage> createState() => _HomeworkPageState();`  <sub>:30</sub>

## features/homework/homework_projection.dart

- `enum HomeworkDeadlineStatus` — Orthogonal deadline status derived on the client; never mutates upstream  
  <sub>enum · features/homework/homework_projection.dart:23</sub>

## features/homework/homework_widgets.dart

- `class HomeworkSummaryMetrics extends StatelessWidget` — 顶部三项统计（待完成 / 已提交 / 已截止）。  
  <sub>class · features/homework/homework_widgets.dart:20</sub>
    - `const HomeworkSummaryMetrics( {…}`  <sub>:21</sub>
    - `Widget build(BuildContext context) => Padding( padding: const EdgeInsets.all(16), child … overdue), ]) SizedBox( key: ValueKey('homework-summary-$ {…}`  <sub>:33</sub>
- `class HomeworkQuickFilter extends StatelessWidget` — 状态快捷筛选按钮；再次点击同一项即回到「全部」。  
  <sub>class · features/homework/homework_widgets.dart:78</sub>
    - `const HomeworkQuickFilter( {…}`  <sub>:79</sub>
    - `Widget build(BuildContext context) => CupertinoButton( padding: const EdgeInsets.symmet … Style(fontSize: 14, color: tint.resolveFrom(context)), ), );`  <sub>:95</sub>
- `class HomeworkStatusBadge extends StatelessWidget` — 作业状态徽标。已提交用成功色，已截止用危险色，待确认保留不确定色。  
  <sub>class · features/homework/homework_widgets.dart:108</sub>
    - `const HomeworkStatusBadge( {…}`  <sub>:109</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:121</sub>
- `class HomeworkDeadlineText extends StatelessWidget` — 单条作业的截止时间与倒计时描述。  
  <sub>class · features/homework/homework_widgets.dart:153</sub>
    - `const HomeworkDeadlineText( {…}`  <sub>:154</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:164</sub>
- `class HomeworkItemTile extends StatelessWidget` — 作业列表项：标题、截止信息、课程与教师。  
  <sub>class · features/homework/homework_widgets.dart:208</sub>
    - `const HomeworkItemTile( {…}`  <sub>:209</sub>
    - `Widget build(BuildContext context) => AppleListTile( key: Key('homework-$ {…}`  <sub>:221</sub>
