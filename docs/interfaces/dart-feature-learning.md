# Flutter 功能域：learning

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。

`flutter/lib/features/learning/` 的页面、域内组件与模型。

## features/learning/learning_announcement_page.dart

- `class LearningAnnouncementPage extends StatefulWidget`  
  <sub>class · features/learning/learning_announcement_page.dart:13</sub>
    - `const LearningAnnouncementPage( {…}`  <sub>:14</sub>
    - `final bool Function() isCurrent;`  <sub>:27</sub>
    - `State<LearningAnnouncementPage> createState() => LearningAnnouncementPageState();`  <sub>:30</sub>
- `class LearningAnnouncementPageState extends State<LearningAnnouncementPage>`  
  <sub>class · features/learning/learning_announcement_page.dart:33</sub>
    - `final detail = RefreshSection<CourseAnnouncementDetail>();`  <sub>:34</sub>
    - `void initState() {…}`  <sub>:36</sub>
    - `void dispose() {…}`  <sub>:78</sub>
    - `Widget build(BuildContext context) => CupertinoPageScaffold( backgroundColor: Cupertino … .saveFile, isCurrent: widget.isCurrent, contextToken: '$ {…}`  <sub>:84</sub>

## features/learning/learning_course_page.dart

- `class LearningCoursePage extends StatefulWidget`  
  <sub>class · features/learning/learning_course_page.dart:16</sub>
    - `const LearningCoursePage( {…}`  <sub>:17</sub>
    - `final bool Function()? isOwnerCurrent;`  <sub>:29</sub>
    - `State<LearningCoursePage> createState() => _LearningCoursePageState();`  <sub>:31</sub>

## features/learning/learning_page.dart

- `class LearningPage extends StatefulWidget`  
  <sub>class · features/learning/learning_page.dart:13</sub>
    - `const LearningPage( {…}`  <sub>:14</sub>
    - `State<LearningPage> createState() => _LearningPageState();`  <sub>:24</sub>

## features/learning/learning_resource_section.dart

- `class LearningResourceSection extends StatelessWidget` — 课程资料的目录浏览区：面包屑、当前页筛选、条目列表与分页。  
  <sub>class · features/learning/learning_resource_section.dart:14</sub>
    - `const LearningResourceSection( {…}`  <sub>:15</sub>
    - `final void Function(List<CourseResource> nextPath, int nextPage) onNavigate;`  <sub>:43</sub>
    - `final Future<LearningDownload> Function(CourseResource item) onDownload;`  <sub>:45</sub>
    - `final bool Function() isCurrent;`  <sub>:46</sub>
    - `Widget build(BuildContext context) => AppleSection( header: const Text('课程资料'), footer: … gate(path.take(index + 1).toList(), 1), child: Text('/ $ {…}`  <sub>:49</sub>

## features/learning/learning_snapshots_page.dart

- `class LearningSnapshotsPage extends StatefulWidget`  
  <sub>class · features/learning/learning_snapshots_page.dart:7</sub>
    - `const LearningSnapshotsPage( {…}`  <sub>:8</sub>
    - `State<LearningSnapshotsPage> createState() => _LearningSnapshotsPageState();`  <sub>:11</sub>

## features/learning/learning_widgets.dart

- `class LearningFileButton extends StatefulWidget`  
  <sub>class · features/learning/learning_widgets.dart:11</sub>
    - `const LearningFileButton( {…}`  <sub>:12</sub>
    - `final Future<LearningDownload> Function() download;`  <sub>:19</sub>
    - `final bool Function() isCurrent;`  <sub>:21</sub>
    - `State<LearningFileButton> createState() => LearningFileButtonState();`  <sub>:24</sub>
- `class LearningFileButtonState extends State<LearningFileButton>`  
  <sub>class · features/learning/learning_widgets.dart:27</sub>
    - `bool busy = false;`  <sub>:28</sub>
    - `int epoch = 0;`  <sub>:31</sub>
    - `bool current(int e) => mounted &&`  <sub>:32</sub>
    - `void didUpdateWidget(covariant LearningFileButton oldWidget) {…}`  <sub>:38</sub>
    - `Future<void> save() async {…}`  <sub>:48</sub>
    - `Future<void> open() async {…}`  <sub>:78</sub>
    - `void dispose() {…}`  <sub>:89</sub>
    - `Widget build(BuildContext context) => SizedBox( width: 150, child: Column( children: [ … xt(message!, style: const TextStyle(fontSize: 12)), ], ), );`  <sub>:95</sub>
- `class LearningReadStatus<T> extends StatelessWidget`  
  <sub>class · features/learning/learning_widgets.dart:112</sub>
    - `const LearningReadStatus( {…}`  <sub>:113</sub>
    - `Widget build(BuildContext context) => Column( crossAxisAlignment: CrossAxisAlignment.st … onst LearningText('旧缓存 · 可能不是最新结果', warning: true), ], ], );`  <sub>:125</sub>
- `class LearningText extends StatelessWidget`  
  <sub>class · features/learning/learning_widgets.dart:156</sub>
    - `const LearningText(this.text, {…}`  <sub>:157</sub>
    - `Widget build(BuildContext context) => Padding( padding: const EdgeInsets.symmetric(hori … Design.statusUncertain.resolveFrom(context) : null, ), ), );`  <sub>:161</sub>
