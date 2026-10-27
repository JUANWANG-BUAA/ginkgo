# Flutter 功能域：learning

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。

`flutter/lib/features/learning/` 的页面、域内组件与模型。

## LearningAnnouncementPage (class)

- `class LearningAnnouncementPage extends StatefulWidget {`  
  <sub>features/learning/learning_announcement_page.dart:13</sub>
    - `const LearningAnnouncementPage({ super.key, required this.service, required this.course, required this.announcement, required this.isCurrent, this.co…`  <sub>:14</sub>
    - `final bool Function() isCurrent;`  <sub>:27</sub>
    - `State<LearningAnnouncementPage> createState() => LearningAnnouncementPageState();`  <sub>:30</sub>

## LearningAnnouncementPageState (class)

- `class LearningAnnouncementPageState extends State<LearningAnnouncementPage> {`  
  <sub>features/learning/learning_announcement_page.dart:33</sub>
    - `final detail = RefreshSection<CourseAnnouncementDetail>();`  <sub>:34</sub>
    - `void initState() { super.initState(); detail.addListener(_changed); _load(); }`  <sub>:36</sub>
    - `void dispose() { detail.dispose(); super.dispose(); }`  <sub>:78</sub>
    - `Widget build(BuildContext context) => CupertinoPageScaffold( backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom( context, ), naviga…`  <sub>:84</sub>

## LearningCoursePage (class)

- `class LearningCoursePage extends StatefulWidget {`  
  <sub>features/learning/learning_course_page.dart:16</sub>
    - `const LearningCoursePage({ super.key, required this.course, required this.service, this.accountId, this.saveFile = saveLearningFile, this.isOwnerCurr…`  <sub>:17</sub>
    - `final bool Function()? isOwnerCurrent;`  <sub>:29</sub>
    - `State<LearningCoursePage> createState() => _LearningCoursePageState();`  <sub>:31</sub>

## LearningPage (class)

- `class LearningPage extends StatefulWidget {`  
  <sub>features/learning/learning_page.dart:13</sub>
    - `const LearningPage({ super.key, required this.service, this.accountId, this.saveFile = saveLearningFile, });`  <sub>:14</sub>
    - `State<LearningPage> createState() => _LearningPageState();`  <sub>:24</sub>

## LearningResourceSection (class)

- `class LearningResourceSection extends StatelessWidget {` — 课程资料的目录浏览区：面包屑、当前页筛选、条目列表与分页。  
  <sub>features/learning/learning_resource_section.dart:14</sub>
    - `const LearningResourceSection({ super.key, required this.path, required this.page, required this.items, required this.resourceQuery, required this.re…`  <sub>:15</sub>
    - `final void Function(List<CourseResource> nextPath, int nextPage) onNavigate;`  <sub>:43</sub>
    - `final Future<LearningDownload> Function(CourseResource item) onDownload;`  <sub>:45</sub>
    - `final bool Function() isCurrent;`  <sub>:46</sub>
    - `Widget build(BuildContext context) => AppleSection( header: const Text('课程资料'), footer: const Text('只列当前目录的当前页；筛选不跨页。下载由你主动发起，不会批量保存。'), children: [ …`  <sub>:49</sub>

## LearningSnapshotsPage (class)

- `class LearningSnapshotsPage extends StatefulWidget {`  
  <sub>features/learning/learning_snapshots_page.dart:7</sub>
    - `const LearningSnapshotsPage({super.key, required this.gateway});`  <sub>:8</sub>
    - `State<LearningSnapshotsPage> createState() => _LearningSnapshotsPageState();`  <sub>:11</sub>

## LearningFileButton (class)

- `class LearningFileButton extends StatefulWidget {`  
  <sub>features/learning/learning_widgets.dart:11</sub>
    - `const LearningFileButton({ super.key, required this.download, required this.saveFile, required this.isCurrent, required this.contextToken, });`  <sub>:12</sub>
    - `final Future<LearningDownload> Function() download;`  <sub>:19</sub>
    - `final bool Function() isCurrent;`  <sub>:21</sub>
    - `State<LearningFileButton> createState() => LearningFileButtonState();`  <sub>:24</sub>

## LearningFileButtonState (class)

- `class LearningFileButtonState extends State<LearningFileButton> {`  
  <sub>features/learning/learning_widgets.dart:27</sub>
    - `bool busy = false;`  <sub>:28</sub>
    - `int epoch = 0;`  <sub>:31</sub>
    - `bool current(int e) => mounted &&`  <sub>:32</sub>
    - `void didUpdateWidget(covariant LearningFileButton oldWidget) { super.didUpdateWidget(oldWidget); if (oldWidget.contextToken != widget.contextToken) {…`  <sub>:38</sub>
    - `Future<void> save() async { if (busy \|\| !current(epoch)) return; final saver = widget.saveFile; if (saver == null) { setState(() => message = '当前平台保存…`  <sub>:48</sub>
    - `Future<void> open() async { final e = epoch, file = saved; if (file == null \|\| !current(e)) return; try { await file.open(); } catch (_) { if (curren…`  <sub>:78</sub>
    - `void dispose() { epoch++; super.dispose(); }`  <sub>:89</sub>
    - `Widget build(BuildContext context) => SizedBox( width: 150, child: Column( children: [ CupertinoButton( onPressed: busy ? null : save, child: Text(bu…`  <sub>:95</sub>

## LearningReadStatus (class)

- `class LearningReadStatus<T> extends StatelessWidget {`  
  <sub>features/learning/learning_widgets.dart:112</sub>
    - `const LearningReadStatus({ super.key, required this.title, required this.section, required this.supported, required this.onRefresh, });`  <sub>:113</sub>
    - `Widget build(BuildContext context) => Column( crossAxisAlignment: CrossAxisAlignment.stretch, children: [ if (!supported) LearningText('当前服务暂不支持$titl…`  <sub>:125</sub>

## LearningText (class)

- `class LearningText extends StatelessWidget {`  
  <sub>features/learning/learning_widgets.dart:156</sub>
    - `const LearningText(this.text, {super.key, this.heading = false, this.warning = false});`  <sub>:157</sub>
    - `Widget build(BuildContext context) => Padding( padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), child: Text( text, style: TextStyle…`  <sub>:161</sub>
